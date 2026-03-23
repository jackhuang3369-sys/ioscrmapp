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
