import Foundation

@MainActor
final class BillingViewModel: ObservableObject {
    enum ScreenState {
        case idle
        case loading
        case loaded
        case failed(LocalizedTextValue)
    }

    @Published private(set) var summaryState: ScreenState = .idle
    @Published private(set) var listState: ScreenState = .idle
    @Published private(set) var summarySnapshot: BillingSummarySnapshot?
    @Published private(set) var listSnapshot: BillingListSnapshot?
    @Published var selectedTab: BillingTab = .summary
    @Published var summaryAmountText = ""
    @Published var selectedPaymentMethod: BillingPaymentMethod = .creditCard
    @Published private(set) var isSummaryPayDisabled = false
    @Published private(set) var isSubmittingSummaryPayment = false
    @Published private(set) var disabledInvoiceIDs: Set<String> = []
    @Published private(set) var submittingInvoiceIDs: Set<String> = []
    @Published var previewDocument: BillingPreviewDocument?
    @Published var submissionFeedback: BillingPaymentSubmission?
    @Published var presentedInvoice: BillingInvoice?
    @Published var presentedUnbilledEstimate: BillingUnbilledEstimate?
    @Published var toastMessage: LocalizedTextValue?

    private let session: CustSubInfo
    private let billingService: any BillingServicing
    private var listRefreshTask: Task<Void, Never>?

    init(session: CustSubInfo, billingService: any BillingServicing) {
        self.session = session
        self.billingService = billingService
    }

    var summaryInvoices: [BillingInvoice] {
        summarySnapshot?.outstandingInvoices ?? []
    }

    var billListInvoices: [BillingInvoice] {
        listSnapshot?.invoices ?? []
    }

    func loadIfNeeded() async {
        guard case .idle = summaryState else {
            return
        }
        await refreshSummary()
    }

    func loadListIfNeeded() async {
        guard case .idle = listState else {
            return
        }
        await refreshList()
    }

    func refreshCurrentTab() async {
        switch selectedTab {
        case .summary:
            await refreshSummary()
        case .list:
            await refreshList()
        }
    }

    func refreshSummary() async {
        let hadLoadedContent = summarySnapshot != nil && {
            if case .loaded = summaryState {
                return true
            }
            return false
        }()

        if !hadLoadedContent {
            summaryState = .loading
        }
        isSummaryPayDisabled = false
        isSubmittingSummaryPayment = false

        do {
            let snapshot = try await billingService.fetchSummary(session: session)
            summarySnapshot = snapshot
            if summaryAmountText.isEmpty {
                summaryAmountText = snapshot.summary.totalDueAmountRaw
            }
            summaryState = .loaded
        } catch {
            if let billingError = error as? BillingServiceError, case .requestCancelled = billingError {
                if hadLoadedContent {
                    summaryState = .loaded
                }
                return
            }
            let message = (error as? BillingServiceError)?.textValue ?? .key("billing.state.errorSubtitle")
            if hadLoadedContent {
                toastMessage = message
                summaryState = .loaded
            } else {
                summaryState = .failed(message)
            }
        }
    }

    func refreshList() async {
        if let listRefreshTask {
            await listRefreshTask.value
            return
        }

        let hadLoadedContent = listSnapshot != nil && {
            if case .loaded = listState {
                return true
            }
            return false
        }()

        if !hadLoadedContent {
            listState = .loading
        }
        disabledInvoiceIDs.removeAll()
        submittingInvoiceIDs.removeAll()

        let session = self.session
        let billingService = self.billingService

        let task = Task { [weak self] in
            guard let self else { return }

            do {
                let snapshot = try await billingService.fetchBillList(
                    session: session,
                    pageIndex: 1,
                    pageSize: 20
                )
                await MainActor.run {
                    self.listSnapshot = snapshot
                    self.listState = .loaded
                    self.listRefreshTask = nil
                }
            } catch {
                await MainActor.run {
                    if let billingError = error as? BillingServiceError, case .requestCancelled = billingError {
                        if hadLoadedContent {
                            self.listState = .loaded
                        }
                        self.listRefreshTask = nil
                        return
                    }

                    let message = (error as? BillingServiceError)?.textValue ?? .key("billing.state.errorSubtitle")
                    if hadLoadedContent {
                        self.toastMessage = message
                        self.listState = .loaded
                    } else {
                        self.listState = .failed(message)
                    }
                    self.listRefreshTask = nil
                }
            }
        }

        listRefreshTask = task
        await task.value
    }

    func openInvoice(_ invoice: BillingInvoice) {
        presentedInvoice = invoice
    }

    func openUnbilledEstimate() {
        guard let summary = summarySnapshot?.summary else {
            return
        }
        presentedUnbilledEstimate = makeUnbilledEstimate(from: summary)
    }

    func previewPDF(for invoice: BillingInvoice) async {
        do {
            let fileURL = try await billingService.downloadInvoicePDF(for: invoice, session: session)
            previewDocument = BillingPreviewDocument(url: fileURL)
        } catch {
            if let billingError = error as? BillingServiceError, case .requestCancelled = billingError {
                return
            }
            toastMessage = (error as? BillingServiceError)?.textValue ?? .key("billing.pdf.error")
        }
    }

    func submitSummaryPayment() async {
        guard !isSummaryPayDisabled, !isSubmittingSummaryPayment else {
            return
        }

        guard
            let oldestInvoice = oldestOutstandingInvoice(),
            let normalizedAmount = normalizedAmount(summaryAmountText)
        else {
            toastMessage = .key("billing.payment.amountInvalid")
            return
        }

        isSubmittingSummaryPayment = true
        do {
            let submission = try await billingService.submitPayment(
                BillingPaymentRequest(
                    context: .summary(oldestInvoice: oldestInvoice),
                    amountText: normalizedAmount,
                    paymentMethod: selectedPaymentMethod
                ),
                session: session
            )
            print("[submitSummaryPayment] --------> submission: ",submission)
            isSubmittingSummaryPayment = false
            isSummaryPayDisabled = true
            submissionFeedback = submission
        } catch {
            isSubmittingSummaryPayment = false
            if let billingError = error as? BillingServiceError, case .requestCancelled = billingError {
                return
            }
            print("[submitSummaryPayment] --------> catch")
            toastMessage = (error as? BillingServiceError)?.textValue ?? .key("billing.state.errorSubtitle")
        }
    }

    func submitInvoicePayment(invoice: BillingInvoice, amountText: String) async {
        guard !disabledInvoiceIDs.contains(invoice.id), !submittingInvoiceIDs.contains(invoice.id) else {
            return
        }

        guard let normalizedAmount = normalizedAmount(amountText) else {
            toastMessage = .key("billing.payment.amountInvalid")
            return
        }

        submittingInvoiceIDs.insert(invoice.id)
        do {
            let submission = try await billingService.submitPayment(
                BillingPaymentRequest(
                    context: .invoice(invoice: invoice),
                    amountText: normalizedAmount,
                    paymentMethod: selectedPaymentMethod
                ),
                session: session
            )
            submittingInvoiceIDs.remove(invoice.id)
            disabledInvoiceIDs.insert(invoice.id)
            submissionFeedback = submission
        } catch {
            submittingInvoiceIDs.remove(invoice.id)
            if let billingError = error as? BillingServiceError, case .requestCancelled = billingError {
                return
            }
            toastMessage = (error as? BillingServiceError)?.textValue ?? .key("billing.state.errorSubtitle")
        }
    }

    func didDismissSubmissionFeedback() {
        guard let feedback = submissionFeedback else {
            return
        }

        presentedInvoice = nil
        submissionFeedback = nil

        Task {
            switch feedback.returnTarget {
            case .summary:
                selectedTab = .summary
                await refreshSummary()
            case .list:
                selectedTab = .list
                await refreshList()
            }
        }
    }

    func dismissToast() {
        toastMessage = nil
    }

    func paymentAmountText(for invoice: BillingInvoice) -> String {
        invoice.openAmountRaw
    }

    func visualBreakdown(for invoice: BillingInvoice) -> BillingVisualBreakdown {
        let baseAmount = BillingNumberParser.decimal(invoice.openAmountRaw)
            ?? BillingNumberParser.decimal(invoice.invoiceAmountRaw)
            ?? 0
        let monthlyFee = (baseAmount * 7) / 10
        let otherCharges = max(Decimal.zero, baseAmount - monthlyFee)

        return BillingVisualBreakdown(
            monthlyFeeText: BillingNumberParser.displayMoney(BillingNumberParser.string(monthlyFee)),
            otherChargesText: BillingNumberParser.displayMoney(BillingNumberParser.string(otherCharges))
        )
    }

    private func oldestOutstandingInvoice() -> BillingInvoice? {
        summaryInvoices
            .sorted {
                let lhsDate = $0.invoiceDateText
                let rhsDate = $1.invoiceDateText
                if lhsDate == rhsDate {
                    return $0.dueDateText < $1.dueDateText
                }
                return lhsDate < rhsDate
            }
            .first
    }

    private func makeUnbilledEstimate(from summary: BillingSummary) -> BillingUnbilledEstimate {
        let total = BillingNumberParser.decimal(summary.unbilledAmountRaw) ?? 0
        let monthlyFee = roundedCurrency(total * Decimal(0.52))
        let addOnPackage = roundedCurrency(total * Decimal(0.20))
        let roaming = roundedCurrency(total * Decimal(0.16))
        let outOfBundle = max(Decimal.zero, total - monthlyFee - addOnPackage - roaming)

        return BillingUnbilledEstimate(
            id: "unbilled-\(summary.accountCode)",
            estimatedAmountText: summary.unbilledAmountText,
            expectedBillDateText: nextBillEstimateDateText(),
            currentCycleText: currentCycleText(),
            lastUpdatedText: lastUpdatedText(),
            chargeItems: [
                BillingUnbilledChargeItem(
                    id: "monthly-fee",
                    titleKey: "billing.unbilledDetail.charge.monthlyFee",
                    amountText: BillingNumberParser.displayMoney(BillingNumberParser.string(monthlyFee))
                ),
                BillingUnbilledChargeItem(
                    id: "add-on-package",
                    titleKey: "billing.unbilledDetail.charge.addOnPackage",
                    amountText: BillingNumberParser.displayMoney(BillingNumberParser.string(addOnPackage))
                ),
                BillingUnbilledChargeItem(
                    id: "international-roaming",
                    titleKey: "billing.unbilledDetail.charge.internationalRoaming",
                    amountText: BillingNumberParser.displayMoney(BillingNumberParser.string(roaming))
                ),
                BillingUnbilledChargeItem(
                    id: "out-of-bundle",
                    titleKey: "billing.unbilledDetail.charge.outOfBundle",
                    amountText: BillingNumberParser.displayMoney(BillingNumberParser.string(outOfBundle))
                )
            ],
            usageItems: [
                BillingUnbilledUsageItem(
                    id: "local-data",
                    titleKey: "billing.unbilledDetail.usage.localData",
                    valueText: "6.2 GB / 10 GB",
                    progress: 0.62
                ),
                BillingUnbilledUsageItem(
                    id: "local-voice",
                    titleKey: "billing.unbilledDetail.usage.localVoice",
                    valueText: "124 min / 200 min",
                    progress: 0.62
                ),
                BillingUnbilledUsageItem(
                    id: "sms",
                    titleKey: "billing.unbilledDetail.usage.sms",
                    valueText: "38 / 100 SMS",
                    progress: 0.38
                )
            ]
        )
    }

    private func roundedCurrency(_ value: Decimal) -> Decimal {
        var value = value
        var rounded = Decimal.zero
        NSDecimalRound(&rounded, &value, 2, .bankers)
        return rounded
    }

    private func currentCycleText() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: Date())
    }

    private func nextBillEstimateDateText() -> String {
        let calendar = Calendar(identifier: .gregorian)
        let startOfCurrentMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: Date())
        ) ?? Date()
        let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: startOfCurrentMonth) ?? Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: nextMonthStart)
    }

    private func lastUpdatedText() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: Date())
    }

    private func normalizedAmount(_ rawValue: String) -> String? {
        guard let normalized = BillingNumberParser.normalized(rawValue), !normalized.isEmpty else {
            return nil
        }

        guard let decimal = Decimal(string: normalized), decimal > 0 else {
            return nil
        }

        return normalized
    }
}

@MainActor
final class RechargeViewModel: ObservableObject {
    enum ScreenState {
        case idle
        case loading
        case loaded
        case failed(LocalizedTextValue)
    }

    @Published private(set) var entryState: ScreenState = .idle
    @Published private(set) var ordersState: ScreenState = .idle
    @Published private(set) var entrySnapshot: RechargeEntrySnapshot?
    @Published private(set) var ordersSnapshot: RechargeOrderPageSnapshot?
    @Published var selectedTab: RechargeTab = .recharge
    @Published var amountText = ""
    @Published var selectedPaymentMethod: RechargePaymentMethod = .creditCard
    @Published var orderFilter: RechargeOrderFilter = .empty
    @Published var isConfirmPresented = false
    @Published private(set) var isSubmitting = false
    @Published private(set) var isLoadingMoreOrders = false
    @Published var acceptedReceipt: RechargeAcceptedReceipt?
    @Published var failureFeedback: RechargeFailureFeedback?
    @Published var selectedOrder: RechargeOrderRecord?
    @Published var toastMessage: LocalizedTextValue?
    private var acceptedReceiptPresentationTask: Task<Void, Never>?

    private let session: CustSubInfo
    private let rechargeService: any RechargeServicing
    private let ordersPageSize = 20

    init(session: CustSubInfo, rechargeService: any RechargeServicing) {
        self.session = session
        self.rechargeService = rechargeService
    }

    var quickAmounts: [Decimal] {
        entrySnapshot?.quickAmounts ?? [10, 20, 50, 100]
    }

    var balanceText: String {
        entrySnapshot?.balanceText ?? BillingNumberParser.displayMoney(session.balanceText)
    }

    var serviceNumberText: String {
        AuthValidator.localPhoneDigits(entrySnapshot?.serviceNumber ?? session.serviceNumber ?? session.phoneNumber)
    }

    var amountError: String? {
        guard !amountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        guard let amount = parsedAmount else {
            return "Enter a valid amount with up to 2 decimals."
        }
        if amount < minimumAmount {
            return "Minimum recharge amount is \(minimumAmountDisplayText)."
        }
        return nil
    }

    var isContinueDisabled: Bool {
        parsedAmount == nil || amountError != nil || entrySnapshot == nil
    }

    var minimumAmountDisplayText: String {
        BillingNumberParser.displayMoney(NSDecimalNumber(decimal: minimumAmount).stringValue)
    }

    private var minimumAmount: Decimal {
        entrySnapshot?.minAmount ?? 10
    }

    private var parsedAmount: Decimal? {
        Self.parseAmount(from: amountText)
    }

    func loadIfNeeded() async {
        guard case .idle = entryState else {
            return
        }
        await refreshEntry()
    }

    func loadOrdersIfNeeded() async {
        guard case .idle = ordersState else {
            return
        }
        await refreshOrders()
    }

    func refreshEntry() async {
        entryState = .loading

        do {
            let snapshot = try await rechargeService.fetchEntrySnapshot(session: session)
            entrySnapshot = snapshot
            entryState = .loaded
        } catch {
            if let rechargeError = error as? RechargeServiceError, case .requestCancelled = rechargeError {
                return
            }
            entryState = .failed((error as? RechargeServiceError)?.textValue ?? .key("recharge.error.generic"))
        }
    }

    func refreshOrders() async {
        ordersState = .loading

        do {
            ordersSnapshot = try await rechargeService.fetchOrders(
                session: session,
                filter: orderFilter,
                pageIndex: 1,
                pageSize: ordersPageSize
            )
            ordersState = .loaded
        } catch {
            if let rechargeError = error as? RechargeServiceError, case .requestCancelled = rechargeError {
                return
            }
            ordersState = .failed((error as? RechargeServiceError)?.textValue ?? .key("recharge.error.generic"))
        }
    }

    func loadMoreOrdersIfNeeded(currentRecord: RechargeOrderRecord) async {
        guard let snapshot = ordersSnapshot,
              snapshot.pageIndex < snapshot.totalPages,
              !isLoadingMoreOrders,
              !snapshot.records.isEmpty,
              snapshot.records.last?.id == currentRecord.id else {
            return
        }

        isLoadingMoreOrders = true
        do {
            let nextPage = snapshot.pageIndex + 1
            let nextSnapshot = try await rechargeService.fetchOrders(
                session: session,
                filter: orderFilter,
                pageIndex: nextPage,
                pageSize: ordersPageSize
            )

            ordersSnapshot = RechargeOrderPageSnapshot(
                records: snapshot.records + nextSnapshot.records,
                pageIndex: nextSnapshot.pageIndex,
                pageSize: nextSnapshot.pageSize,
                totalCount: nextSnapshot.totalCount,
                totalPages: nextSnapshot.totalPages
            )
            isLoadingMoreOrders = false
        } catch {
            if let rechargeError = error as? RechargeServiceError, case .requestCancelled = rechargeError {
                isLoadingMoreOrders = false
                return
            }
            isLoadingMoreOrders = false
            toastMessage = (error as? RechargeServiceError)?.textValue ?? .key("recharge.error.generic")
        }
    }

    func sanitizeAmountInput() {
        amountText = Self.sanitizedAmountInput(amountText)
    }

    func applyQuickAmount(_ value: Decimal) {
        amountText = BillingNumberParser.string(value)
    }

    func openConfirm() {
        guard !isContinueDisabled else {
            return
        }
        isConfirmPresented = true
    }

    func submitRecharge() async {
        guard !isSubmitting else {
            return
        }
        guard let amount = parsedAmount else {
            toastMessage = .key("recharge.error.invalidAmount")
            return
        }

        isSubmitting = true
        do {
            let receipt = try await rechargeService.submitRecharge(
                RechargeSubmissionRequest(
                    amountText: NSDecimalNumber(decimal: amount).stringValue,
                    paymentMethod: selectedPaymentMethod,
                    otpCode: "111111"
                ),
                session: session
            )
            isSubmitting = false
            isConfirmPresented = false
            acceptedReceiptPresentationTask?.cancel()
            acceptedReceiptPresentationTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 350_000_000)
                guard let self, !Task.isCancelled else { return }
                self.acceptedReceipt = receipt
                self.acceptedReceiptPresentationTask = nil
            }
        } catch {
            isSubmitting = false
            isConfirmPresented = false
            acceptedReceiptPresentationTask?.cancel()
            acceptedReceiptPresentationTask = nil
            if let rechargeError = error as? RechargeServiceError, case .requestCancelled = rechargeError {
                return
            }
            failureFeedback = RechargeFailureFeedback(
                titleKey: "recharge.failure.title",
                message: (error as? RechargeServiceError)?.textValue.literalValue ?? "Recharge submission failed."
            )
        }
    }

    func dismissAcceptedReceipt() {
        acceptedReceiptPresentationTask?.cancel()
        acceptedReceiptPresentationTask = nil
        acceptedReceipt = nil
        selectedTab = .orders
        Task {
            await refreshOrders()
        }
    }

    func retrySubmission() {
        failureFeedback = nil
        isConfirmPresented = true
    }

    func dismissFailure() {
        acceptedReceiptPresentationTask?.cancel()
        acceptedReceiptPresentationTask = nil
        failureFeedback = nil
    }

    func openOrderDetail(_ record: RechargeOrderRecord) {
        selectedOrder = record
    }

    func dismissOrderDetail() {
        selectedOrder = nil
    }

    func clearFilters() {
        orderFilter = .empty
    }

    func dismissToast() {
        toastMessage = nil
    }

    private static func parseAmount(from rawValue: String) -> Decimal? {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")

        guard !normalized.isEmpty else {
            return nil
        }
        guard let decimal = Decimal(string: normalized), decimal > 0 else {
            return nil
        }

        var value = decimal
        var rounded = Decimal.zero
        NSDecimalRound(&rounded, &value, 2, .bankers)
        return rounded == decimal ? decimal : nil
    }

    private static func sanitizedAmountInput(_ rawValue: String) -> String {
        let filtered = rawValue.filter { $0.isNumber || $0 == "." }
        let parts = filtered.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count > 1 else {
            return String(filtered.prefix(9))
        }

        let integerPart = String(parts[0].prefix(9))
        let decimalPart = String(parts[1].prefix(2))
        return integerPart + "." + decimalPart
    }
}

private extension LocalizedTextValue {
    var literalValue: String? {
        if case let .literal(value) = self {
            return value
        }
        return nil
    }
}
