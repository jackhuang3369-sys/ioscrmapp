import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

#if canImport(QuickLook)
import QuickLook
#endif

struct BillingContainerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.duTheme) private var theme
    @EnvironmentObject private var languageStore: AppLanguageStore
    @StateObject private var viewModel: BillingViewModel
    private let session: CustSubInfo
    private let aiChatService: any AIChatServicing
    private let onAIChatNavigation: (AIChatNavigationTarget) -> Void

    init(
        session: CustSubInfo,
        billingService: any BillingServicing,
        aiChatService: any AIChatServicing,
        onAIChatNavigation: @escaping (AIChatNavigationTarget) -> Void = { _ in }
    ) {
        self.session = session
        _viewModel = StateObject(
            wrappedValue: BillingViewModel(session: session, billingService: billingService)
        )
        self.aiChatService = aiChatService
        self.onAIChatNavigation = onAIChatNavigation
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                tabPicker

                Group {
                    switch viewModel.selectedTab {
                    case .summary:
                        summaryContent
                    case .list:
                        listContent
                    }
                }
                .background(theme.colors.background.canvas.ignoresSafeArea())
            }
            .background(navigationLinks)
            .navigationTitle(localized("billing.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(localized("common.cancel")) {
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .task {
            await viewModel.loadIfNeeded()
        }
        .task(id: viewModel.selectedTab) {
            if viewModel.selectedTab == .list {
                await viewModel.loadListIfNeeded()
            }
        }
        .sheet(item: $viewModel.previewDocument) { document in
            BillingPreviewController(document: document)
        }
        .fullScreenCover(item: $viewModel.submissionFeedback) { submission in
            BillingSubmissionView(
                statusText: submission.statusText,
                onContinue: {
                    viewModel.didDismissSubmissionFeedback()
                }
            )
        }
        .alert(isPresented: Binding(
            get: { viewModel.toastMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.dismissToast()
                }
            }
        )) {
            Alert(
                title: Text(localized("billing.toast.title")),
                message: Text(localized(viewModel.toastMessage)),
                dismissButton: .default(Text(localized("common.ok"))) {
                    viewModel.dismissToast()
                }
            )
        }
        .businessAIAssistant(
            session: session,
            aiChatService: aiChatService,
            onNavigate: handleAIChatNavigation(_:)
        )
    }

    private var navigationLinks: some View {
        Group {
            invoiceNavigationLink
            unbilledNavigationLink
        }
    }

    private var invoiceNavigationLink: some View {
        NavigationLink(
            destination: presentedInvoiceDestination,
            isActive: Binding(
                get: { viewModel.presentedInvoice != nil },
                set: { isActive in
                    if !isActive {
                        viewModel.presentedInvoice = nil
                    }
                }
            )
        ) {
            EmptyView()
        }
        .hidden()
    }

    private var unbilledNavigationLink: some View {
        NavigationLink(
            destination: presentedUnbilledDestination,
            isActive: Binding(
                get: { viewModel.presentedUnbilledEstimate != nil },
                set: { isActive in
                    if !isActive {
                        viewModel.presentedUnbilledEstimate = nil
                    }
                }
            )
        ) {
            EmptyView()
        }
        .hidden()
    }

    @ViewBuilder
    private var presentedInvoiceDestination: some View {
        if let invoice = viewModel.presentedInvoice {
            BillingDetailView(viewModel: viewModel, invoice: invoice)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private var presentedUnbilledDestination: some View {
        if let estimate = viewModel.presentedUnbilledEstimate {
            BillingUnbilledDetailView(estimate: estimate)
        } else {
            EmptyView()
        }
    }

    private var tabPicker: some View {
        Picker("", selection: $viewModel.selectedTab) {
            ForEach(BillingTab.allCases) { tab in
                Text(localized(tab.titleKey)).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, DUSpacing.lg)
        .padding(.top, DUSpacing.md)
        .padding(.bottom, DUSpacing.sm)
    }

    @ViewBuilder
    private var summaryContent: some View {
        switch viewModel.summaryState {
        case .idle, .loading:
            billingLoadingState
        case let .failed(message):
            billingErrorState(message: message) {
                Task { await viewModel.refreshSummary() }
            }
        case .loaded:
            if let snapshot = viewModel.summarySnapshot {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: DUSpacing.lg) {
                        billingHeaderSubtitle(
                            title: localized("billing.title")
                        )
                        summaryHero(snapshot.summary)
                        amountSection(
                            titleKey: "billing.amount.title",
                            fullAmountText: snapshot.summary.totalDueAmountRaw,
                            amountText: $viewModel.summaryAmountText
                        )
                        paymentMethodSection
                        payButton(
                            title: localized("billing.pay.button"),
                            isEnabled: !viewModel.isSummaryPayDisabled,
                            isLoading: viewModel.isSubmittingSummaryPayment
                        ) {
                            Task {
                                await viewModel.submitSummaryPayment()
                            }
                        }
                    }
                    .padding(DUSpacing.lg)
                    .padding(.bottom, DUSpacing.xxxl)
                }
                .refreshable {
                    await viewModel.refreshSummary()
                }
            } else {
                billingEmptyState
            }
        }
    }

    @ViewBuilder
    private var listContent: some View {
        switch viewModel.listState {
        case .idle:
            billingLoadingState
        case .loading:
            billingLoadingState
        case let .failed(message):
            billingErrorState(message: message) {
                Task { await viewModel.refreshList() }
            }
        case .loaded:
            if viewModel.billListInvoices.isEmpty {
                billingEmptyState
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: DUSpacing.md) {
                        billingHeaderSubtitle(
                            title: localized("billing.tab.list")
                        )
                        ForEach(viewModel.billListInvoices) { invoice in
                            billCard(invoice)
                        }
                    }
                    .padding(DUSpacing.lg)
                    .padding(.bottom, DUSpacing.xxxl)
                }
                .refreshable {
                    await viewModel.refreshList()
                }
            }
        }
    }

    private func summaryHero(_ summary: BillingSummary) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.lg) {
            Text(localized("billing.summary.outstanding"))
                .font(.du(.bodySmallStrong))
                .foregroundColor(.white.opacity(0.78))

            Text(summary.totalDueAmountText)
                .font(.du(.screenTitle))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            HStack(spacing: DUSpacing.md) {
                summaryMetric(titleKey: "billing.summary.dueDate", value: summary.dueDateText)
                supportMetricActionCard(
                    title: localized("billing.summary.unbilled"),
                    value: summary.unbilledAmountText,
                    heroStyle: true
                ) {
                    viewModel.openUnbilledEstimate()
                }
            }

            HStack(spacing: DUSpacing.md) {
                supportMetricCard(
                    title: localized("billing.summary.remainingCredit"),
                    value: summary.remainingCreditText,
                    heroStyle: true
                )
                supportMetricCard(
                    title: localized("billing.summary.totalUsage"),
                    value: summary.totalUsageText,
                    heroStyle: true
                )
            }
        }
        .padding(DUSpacing.xl)
        .background(theme.colors.gradient.brand)
        .clipShape(RoundedRectangle(cornerRadius: theme.components.card.cornerRadius, style: .continuous))
    }

    private func summaryMetric(titleKey: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.xs) {
            Text(localized(titleKey))
                .font(.du(.caption))
                .foregroundColor(.white.opacity(0.7))
            Text(value)
                .font(.du(.bodySmallStrong))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DUSpacing.md)
        .background(Color.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: DURadius.lg, style: .continuous))
    }

    private func supportMetricCard(title: String, value: String, heroStyle: Bool) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.smd) {
            Text(title)
                .font(.du(.caption))
                .foregroundColor(heroStyle ? .white.opacity(0.72) : theme.colors.text.tertiary)
            Text(value)
                .font(.du(.labelEmphasized))
                .foregroundColor(heroStyle ? .white : theme.colors.text.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DUSpacing.md)
        .background(heroStyle ? Color.white.opacity(0.12) : theme.colors.surface.card)
        .clipShape(RoundedRectangle(cornerRadius: DURadius.lg, style: .continuous))
    }

    private func supportMetricActionCard(
        title: String,
        value: String,
        heroStyle: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: DUSpacing.sm) {
                VStack(alignment: .leading, spacing: DUSpacing.smd) {
                    Text(title)
                        .font(.du(.caption))
                        .foregroundColor(heroStyle ? .white.opacity(0.72) : theme.colors.text.tertiary)
                    HStack(alignment: .center, spacing: DUSpacing.sm) {
                        Text(value)
                            .font(.du(.labelEmphasized))
                            .foregroundColor(heroStyle ? .white : theme.colors.text.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.right")
                            .font(.du(.bodySmallEmphasized))
                            .foregroundColor(heroStyle ? .white.opacity(0.76) : theme.colors.text.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DUSpacing.md)
                .background(heroStyle ? Color.white.opacity(0.12) : theme.colors.surface.card)
                .clipShape(RoundedRectangle(cornerRadius: DURadius.lg, style: .continuous))
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func amountSection(
        titleKey: String,
        fullAmountText: String,
        amountText: Binding<String>
    ) -> some View {
        DUSectionCard(title: localized(titleKey), spacing: DUSpacing.md) {
            VStack(alignment: .leading, spacing: DUSpacing.sm) {
                quickAmountRow(amountText: amountText, fullAmountText: fullAmountText)

                HStack(spacing: DUSpacing.sm) {
                    Image(systemName: "square.and.pencil")
                        .font(.du(.bodySmallEmphasized))
                        .foregroundColor(theme.colors.brand.primary)

                    TextField("0.00", text: amountText)
                        .keyboardType(.decimalPad)
                        .font(.du(.titleStrong))
                        .foregroundColor(theme.colors.text.primary)

                    Text("AED")
                        .font(.du(.bodySmallEmphasized))
                        .foregroundColor(theme.colors.text.tertiary)
                }
                .padding(.horizontal, DUSpacing.lg)
                .frame(height: 58)
                .background(theme.colors.background.secondary)
                .clipShape(RoundedRectangle(cornerRadius: DURadius.control, style: .continuous))
            }
        }
    }

    private func quickAmountRow(amountText: Binding<String>, fullAmountText: String) -> some View {
        let normalizedFullAmount = BillingNumberParser.normalized(fullAmountText) ?? "0"
        let options = ["50", "100", normalizedFullAmount]

        return HStack(spacing: DUSpacing.sm) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                let isSelected = BillingNumberParser.normalized(amountText.wrappedValue) == BillingNumberParser.normalized(option)
                Button {
                    amountText.wrappedValue = option
                } label: {
                    Text("\(option) AED")
                        .font(.du(.bodySmallEmphasized))
                    .foregroundColor(isSelected ? .white : theme.colors.text.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
                    .background(isSelected ? theme.colors.brand.primary : theme.colors.background.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: DURadius.lg, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var paymentMethodSection: some View {
        DUSectionCard(title: localized("billing.payment.title"), spacing: DUSpacing.md) {
            VStack(spacing: DUSpacing.sm) {
                ForEach(BillingPaymentMethod.allCases) { method in
                    Button {
                        viewModel.selectedPaymentMethod = method
                    } label: {
                        HStack(spacing: DUSpacing.md) {
                            RoundedRectangle(cornerRadius: DURadius.md, style: .continuous)
                                .fill(methodAccentColor(method))
                                .frame(width: 40, height: 40)
                                .overlay {
                                    Image(systemName: methodIcon(method))
                                        .font(.du(.bodyLargeStrong))
                                        .foregroundColor(.white)
                                }

                            VStack(alignment: .leading, spacing: DUSpacing.xxs) {
                                Text(localized(method.titleKey))
                                    .font(.du(.bodySmallStrong))
                                    .foregroundColor(theme.colors.text.primary)
                                Text(methodDescription(method))
                                    .font(.du(.caption))
                                    .foregroundColor(theme.colors.text.tertiary)
                            }

                            Spacer()

                            ZStack {
                                Circle()
                                    .strokeBorder(
                                        viewModel.selectedPaymentMethod == method ? theme.colors.brand.primary : theme.colors.border.default,
                                        lineWidth: 2
                                    )
                                    .background(
                                        Circle()
                                            .fill(viewModel.selectedPaymentMethod == method ? theme.colors.brand.primary : .clear)
                                    )
                                    .frame(width: 22, height: 22)

                                if viewModel.selectedPaymentMethod == method {
                                    Image(systemName: "checkmark")
                                        .font(.du(.captionEmphasized))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .padding(.horizontal, DUSpacing.lg)
                        .frame(height: 62)
                        .background(theme.colors.background.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: DURadius.control, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func methodIcon(_ method: BillingPaymentMethod) -> String {
        switch method {
        case .creditCard:
            return "creditcard.fill"
        case .applePay:
            return "apple.logo"
        case .samsungPay:
            return "wave.3.right.circle.fill"
        }
    }

    private func methodAccentColor(_ method: BillingPaymentMethod) -> Color {
        switch method {
        case .creditCard:
            return theme.colors.brand.primary
        case .applePay:
            return theme.colors.text.primary
        case .samsungPay:
            return theme.colors.brand.secondary
        }
    }

    private func methodDescription(_ method: BillingPaymentMethod) -> String {
        switch method {
        case .creditCard:
            return "Visa, Mastercard, AMEX"
        case .applePay:
            return "Fast & secure payment"
        case .samsungPay:
            return "Same order as recharge"
        }
    }

    private func billingHeaderSubtitle(title: String, subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.xs) {
            Text(title)
                .font(.du(.headline))
                .foregroundColor(theme.colors.text.primary)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.du(.label))
                    .foregroundColor(theme.colors.text.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func billCard(_ invoice: BillingInvoice) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.md) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: DUSpacing.xs) {
                    Text(displayBillCycle(invoice))
                        .font(.du(.titleSmall))
                        .foregroundColor(theme.colors.text.primary)

                    let metaText = invoiceMetaText(invoice)
                    if !metaText.isEmpty {
                        Text(metaText)
                            .font(.du(.bodySmall))
                            .foregroundColor(theme.colors.text.secondary)
                    }
                }

                Spacer()

                statusBadge(invoice.status)
            }

            HStack(spacing: DUSpacing.md) {
                invoiceMetric(titleKey: "billing.invoice.totalAmount", value: invoice.invoiceAmountText)
                invoiceMetric(titleKey: "billing.invoice.openAmount", value: invoice.openAmountText)
            }

            HStack(spacing: DUSpacing.sm) {
                if invoice.isPayable {
                    DUButton(
                        title: localized("billing.invoice.pay"),
                        style: .primary,
                        isEnabled: !viewModel.disabledInvoiceIDs.contains(invoice.id),
                        height: 40,
                        textStyle: .labelEmphasized
                    ) {
                        viewModel.openInvoice(invoice)
                    }
                }

                DUButton(
                    title: localized("billing.invoice.viewDetail"),
                    style: .secondary,
                    height: 40,
                    textStyle: .labelEmphasized
                ) {
                    viewModel.openInvoice(invoice)
                }

                DUButton(
                    title: localized("billing.invoice.previewPdf"),
                    style: .secondary,
                    height: 40,
                    textStyle: .labelEmphasized
                ) {
                    Task {
                        await viewModel.previewPDF(for: invoice)
                    }
                }
            }
        }
        .padding(DUSpacing.lg)
        .duCardStyle()
    }

    private func displayBillCycle(_ invoice: BillingInvoice) -> String {
        if let formatted = BillingCycleFormatter.displayTitle(from: invoice.billCycleID) {
            return formatted
        }
        return "\(localized("billing.invoice.cycle")) \(invoice.billCycleID)"
    }

    private func invoiceMetaText(_ invoice: BillingInvoice) -> String {
        ""
    }

    private func invoiceMetric(titleKey: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.xs) {
            Text(localized(titleKey))
                .font(.du(.caption))
                .foregroundColor(theme.colors.text.tertiary)
            Text(value)
                .font(.du(.bodySmallEmphasized))
                .foregroundColor(theme.colors.text.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DUSpacing.md)
        .background(theme.colors.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: DURadius.lg, style: .continuous))
    }

    private func statusBadge(_ status: BillingInvoiceStatus) -> some View {
        Text(localized(status.titleKey))
            .font(.du(.captionStrong))
            .foregroundColor(status == .completed ? theme.colors.status.success : theme.colors.status.warning)
            .padding(.horizontal, DUSpacing.md)
            .frame(height: 28)
            .background(
                status == .completed ? theme.colors.status.successBackground : theme.colors.status.warningBackground
            )
            .clipShape(Capsule())
    }

    private func payButton(title: String, isEnabled: Bool, isLoading: Bool = false, action: @escaping () -> Void) -> some View {
        DUButton(
            title: isLoading ? localized("billing.pay.submitting") : title,
            style: .primary,
            isEnabled: isEnabled && !isLoading,
            action: action
        )
    }

    private var billingLoadingState: some View {
        VStack(spacing: DUSpacing.lg) {
            ProgressView()
            Text(localized("billing.state.loadingTitle"))
                .font(.du(.bodyStrong))
                .foregroundColor(theme.colors.text.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.colors.background.canvas.ignoresSafeArea())
    }

    private var billingEmptyState: some View {
        DUStateView(
            systemImage: "doc.text.magnifyingglass",
            iconColor: theme.colors.brand.primary,
            title: localized("billing.empty.title"),
            subtitle: localized("billing.empty.subtitle"),
            actionTitle: localized("common.reload"),
            footer: nil
        ) {
            Task {
                await viewModel.refreshCurrentTab()
            }
        }
    }

    private func billingErrorState(message: LocalizedTextValue, action: @escaping () -> Void) -> some View {
        DUStateView(
            systemImage: "wifi.exclamationmark",
            iconColor: theme.colors.status.error,
            title: localized("billing.state.errorTitle"),
            subtitle: localized(message),
            actionTitle: localized("common.retry"),
            footer: nil,
            action: action
        )
    }

    private func localized(_ key: String, arguments: [String] = []) -> String {
        languageStore.string(key, arguments: arguments)
    }

    private func localized(_ value: LocalizedTextValue?) -> String {
        switch value {
        case let .localized(key, arguments):
            return localized(key, arguments: arguments)
        case let .literal(text):
            return text
        case nil:
            return ""
        }
    }

    private func handleAIChatNavigation(_ target: AIChatNavigationTarget) {
        guard shouldForwardAIChatNavigation(target) else {
            return
        }

        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onAIChatNavigation(target)
        }
    }

    private func shouldForwardAIChatNavigation(_ target: AIChatNavigationTarget) -> Bool {
        switch target {
        case .billing, .external:
            return false
        default:
            return true
        }
    }
}

private struct BillingDetailView: View {
    @Environment(\.duTheme) private var theme
    @EnvironmentObject private var languageStore: AppLanguageStore
    @ObservedObject var viewModel: BillingViewModel

    let invoice: BillingInvoice

    @State private var amountText: String

    init(viewModel: BillingViewModel, invoice: BillingInvoice) {
        self.viewModel = viewModel
        self.invoice = invoice
        _amountText = State(initialValue: viewModel.paymentAmountText(for: invoice))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: DUSpacing.lg) {
                invoiceHeader
                visualBillSection
                detailFacts

                if invoice.isPayable {
                    amountSection
                    paymentMethodSection
                    HStack(spacing: DUSpacing.sm) {
                        DUButton(
                            title: localized("billing.invoice.previewPdf"),
                            style: .secondary
                        ) {
                            Task {
                                await viewModel.previewPDF(for: invoice)
                            }
                        }
                        DUButton(
                            title: viewModel.submittingInvoiceIDs.contains(invoice.id)
                                ? localized("billing.pay.submitting")
                                : localized("billing.pay.button"),
                            style: .primary,
                            isEnabled: !viewModel.disabledInvoiceIDs.contains(invoice.id) && !viewModel.submittingInvoiceIDs.contains(invoice.id)
                        ) {
                            Task {
                                await viewModel.submitInvoicePayment(invoice: invoice, amountText: amountText)
                                if viewModel.submissionFeedback != nil {
                                    viewModel.presentedInvoice = nil
                                }
                            }
                        }
                    }
                } else {
                    pdfOnlySection
                }
            }
            .padding(DUSpacing.lg)
            .padding(.bottom, DUSpacing.xxxl)
        }
        .background(theme.colors.background.canvas.ignoresSafeArea())
        .navigationTitle(localized("billing.detail.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var invoiceHeader: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DUSpacing.md), count: 2), spacing: DUSpacing.md) {
            detailKPI(title: localized("billing.invoice.cycle"), value: invoice.billCycleID)
            detailKPI(title: localized("billing.statusLabel"), value: localized(invoice.status.titleKey))
            detailKPI(title: localized("billing.summary.dueDate"), value: invoice.dueDateText)
            detailKPI(title: localized("billing.invoice.totalAmount"), value: invoice.invoiceAmountText)
        }
    }

    private func detailKPI(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.xs) {
            Text(title)
                .font(.du(.caption))
                .foregroundColor(theme.colors.text.tertiary)
            Text(value)
                .font(.du(.bodyLargeStrong))
                .foregroundColor(theme.colors.text.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DUSpacing.lg)
        .background(theme.colors.surface.card)
        .clipShape(RoundedRectangle(cornerRadius: DURadius.control, style: .continuous))
    }

    private var visualBillSection: some View {
        let breakdown = viewModel.visualBreakdown(for: invoice)

        return DUSectionCard(title: localized("billing.detail.visualBill"), spacing: DUSpacing.md) {
            VStack(spacing: DUSpacing.md) {
                HStack(spacing: DUSpacing.md) {
                    visualMetric(titleKey: "billing.visual.monthlyFee", value: breakdown.monthlyFeeText, tint: theme.colors.brand.primary)
                    visualMetric(titleKey: "billing.visual.otherCharges", value: breakdown.otherChargesText, tint: theme.colors.brand.secondary)
                }

                RoundedRectangle(cornerRadius: DURadius.control, style: .continuous)
                    .fill(theme.colors.background.secondary)
                    .frame(height: 18)
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            HStack(spacing: 0) {
                                RoundedRectangle(cornerRadius: DURadius.control, style: .continuous)
                                    .fill(theme.colors.brand.primary)
                                    .frame(width: proxy.size.width * 0.68)
                                RoundedRectangle(cornerRadius: DURadius.control, style: .continuous)
                                    .fill(theme.colors.brand.secondaryLight)
                            }
                        }
                    }
            }
        }
    }

    private func visualMetric(titleKey: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.xs) {
            Text(localized(titleKey))
                .font(.du(.caption))
                .foregroundColor(theme.colors.text.tertiary)
            Text(value)
                .font(.du(.bodySmallEmphasized))
                .foregroundColor(theme.colors.text.primary)
            Capsule()
                .fill(tint)
                .frame(width: 22, height: 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DUSpacing.md)
        .background(theme.colors.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: DURadius.lg, style: .continuous))
    }

    private var detailFacts: some View {
        DUSectionCard(title: localized("billing.detail.facts"), spacing: DUSpacing.md) {
            VStack(spacing: DUSpacing.md) {
                factRow(titleKey: "billing.invoice.invoiceDate", value: invoice.invoiceDateText)
                factRow(titleKey: "billing.summary.dueDate", value: invoice.dueDateText)
                factRow(titleKey: "billing.invoice.totalAmount", value: invoice.invoiceAmountText)
                factRow(titleKey: "billing.invoice.openAmount", value: invoice.openAmountText)
                factRow(titleKey: "billing.invoice.taxAmount", value: invoice.taxAmountText)
            }
        }
    }

    private var amountSection: some View {
        DUSectionCard(title: localized("billing.amount.title"), spacing: DUSpacing.md) {
            VStack(alignment: .leading, spacing: DUSpacing.sm) {
                HStack(spacing: DUSpacing.sm) {
                    Image(systemName: "square.and.pencil")
                        .font(.du(.bodySmallEmphasized))
                        .foregroundColor(theme.colors.brand.primary)

                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.du(.titleStrong))
                        .foregroundColor(theme.colors.text.primary)

                    Text("AED")
                        .font(.du(.bodySmallEmphasized))
                        .foregroundColor(theme.colors.text.tertiary)
                }
                .padding(.horizontal, DUSpacing.lg)
                .frame(height: 58)
                .background(theme.colors.background.secondary)
                .clipShape(RoundedRectangle(cornerRadius: DURadius.control, style: .continuous))
            }
        }
    }

    private var paymentMethodSection: some View {
        DUSectionCard(title: localized("billing.payment.title"), spacing: DUSpacing.md) {
            VStack(spacing: DUSpacing.sm) {
                ForEach(BillingPaymentMethod.allCases) { method in
                    Button {
                        viewModel.selectedPaymentMethod = method
                    } label: {
                        HStack(spacing: DUSpacing.md) {
                            RoundedRectangle(cornerRadius: DURadius.md, style: .continuous)
                                .fill(detailMethodAccentColor(method))
                                .frame(width: 40, height: 40)
                                .overlay {
                                    Image(systemName: detailMethodIcon(method))
                                        .font(.du(.bodyLargeStrong))
                                        .foregroundColor(.white)
                                }

                            VStack(alignment: .leading, spacing: DUSpacing.xxs) {
                                Text(localized(method.titleKey))
                                    .font(.du(.bodySmallStrong))
                                    .foregroundColor(theme.colors.text.primary)
                                Text(detailMethodDescription(method))
                                    .font(.du(.caption))
                                    .foregroundColor(theme.colors.text.tertiary)
                            }

                            Spacer()

                            ZStack {
                                Circle()
                                    .strokeBorder(
                                        viewModel.selectedPaymentMethod == method ? theme.colors.brand.primary : theme.colors.border.default,
                                        lineWidth: 2
                                    )
                                    .background(
                                        Circle()
                                            .fill(viewModel.selectedPaymentMethod == method ? theme.colors.brand.primary : .clear)
                                    )
                                    .frame(width: 22, height: 22)

                                if viewModel.selectedPaymentMethod == method {
                                    Image(systemName: "checkmark")
                                        .font(.du(.captionEmphasized))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .padding(.horizontal, DUSpacing.lg)
                        .frame(height: 62)
                        .background(theme.colors.background.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: DURadius.control, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func detailMethodIcon(_ method: BillingPaymentMethod) -> String {
        switch method {
        case .creditCard:
            return "creditcard.fill"
        case .applePay:
            return "apple.logo"
        case .samsungPay:
            return "wave.3.right.circle.fill"
        }
    }

    private func detailMethodAccentColor(_ method: BillingPaymentMethod) -> Color {
        switch method {
        case .creditCard:
            return theme.colors.brand.primary
        case .applePay:
            return theme.colors.text.primary
        case .samsungPay:
            return theme.colors.brand.secondary
        }
    }

    private func detailMethodDescription(_ method: BillingPaymentMethod) -> String {
        switch method {
        case .creditCard:
            return "Default static selection from recharge flow"
        case .applePay:
            return "Fast checkout for iPhone users"
        case .samsungPay:
            return "Reusable with recharge method order"
        }
    }

    private var pdfOnlySection: some View {
        DUSectionCard(title: localized("billing.pdf.title"), spacing: DUSpacing.md) {
            DUButton(title: localized("billing.invoice.previewPdf"), style: .secondary) {
                Task {
                    await viewModel.previewPDF(for: invoice)
                }
            }
        }
    }

    private func factRow(titleKey: String, value: String) -> some View {
        HStack {
            Text(localized(titleKey))
                .font(.du(.label))
                .foregroundColor(theme.colors.text.secondary)
            Spacer()
            Text(value)
                .font(.du(.labelStrong))
                .foregroundColor(theme.colors.text.primary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func localized(_ key: String, arguments: [String] = []) -> String {
        languageStore.string(key, arguments: arguments)
    }
}

private struct BillingUnbilledDetailView: View {
    @Environment(\.duTheme) private var theme
    @EnvironmentObject private var languageStore: AppLanguageStore

    let estimate: BillingUnbilledEstimate

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: DUSpacing.lg) {
                pageHeader
                heroCard
                chargeSection
                usageSection
            }
            .padding(DUSpacing.lg)
            .padding(.bottom, DUSpacing.xxxl)
        }
        .background(theme.colors.background.canvas.ignoresSafeArea())
        .navigationTitle(localized("billing.unbilledDetail.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: DUSpacing.xs) {
            Text(localized("billing.unbilledDetail.title"))
                .font(.du(.headline))
                .foregroundColor(theme.colors.text.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: DUSpacing.lg) {
            Text(localized("billing.unbilledDetail.estimatedAmount"))
                .font(.du(.bodySmallStrong))
                .foregroundColor(.white.opacity(0.78))

            Text(estimate.estimatedAmountText)
                .font(.du(.screenTitle))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: DUSpacing.md), count: 2),
                spacing: DUSpacing.md
            ) {
                heroMetric(
                    title: localized("billing.unbilledDetail.expectedBillDate"),
                    value: estimate.expectedBillDateText
                )
                heroMetric(
                    title: localized("billing.unbilledDetail.currentCycle"),
                    value: estimate.currentCycleText
                )
                heroMetric(
                    title: localized("billing.unbilledDetail.lastUpdated"),
                    value: estimate.lastUpdatedText
                )
            }
        }
        .padding(DUSpacing.xl)
        .background(theme.colors.gradient.brand)
        .clipShape(RoundedRectangle(cornerRadius: theme.components.card.cornerRadius, style: .continuous))
    }

    private func heroMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.xs) {
            Text(title)
                .font(.du(.caption))
                .foregroundColor(.white.opacity(0.72))
            Text(value)
                .font(.du(.bodySmallStrong))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DUSpacing.md)
        .background(Color.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: DURadius.lg, style: .continuous))
    }

    private var chargeSection: some View {
        DUSectionCard(title: localized("billing.unbilledDetail.charge.title"), spacing: DUSpacing.md) {
            VStack(spacing: DUSpacing.md) {
                ForEach(estimate.chargeItems) { item in
                    HStack {
                        Text(localized(item.titleKey))
                            .font(.du(.label))
                            .foregroundColor(theme.colors.text.secondary)
                        Spacer()
                        Text(item.amountText)
                            .font(.du(.bodySmallEmphasized))
                            .foregroundColor(theme.colors.text.primary)
                    }
                }
            }
        }
    }

    private var usageSection: some View {
        DUSectionCard(title: localized("billing.unbilledDetail.usage.title"), spacing: DUSpacing.md) {
            VStack(spacing: DUSpacing.md) {
                ForEach(estimate.usageItems) { item in
                    VStack(alignment: .leading, spacing: DUSpacing.xs) {
                        HStack {
                            Text(localized(item.titleKey))
                                .font(.du(.labelStrong))
                                .foregroundColor(theme.colors.text.primary)
                            Spacer()
                            Text(item.valueText)
                                .font(.du(.bodySmall))
                                .foregroundColor(theme.colors.text.secondary)
                        }

                        ProgressView(value: item.progress)
                            .tint(theme.colors.brand.primary)
                    }
                }
            }
        }
    }
    private func localized(_ key: String, arguments: [String] = []) -> String {
        languageStore.string(key, arguments: arguments)
    }
}

private struct BillingSubmissionView: View {
    @Environment(\.duTheme) private var theme
    @EnvironmentObject private var languageStore: AppLanguageStore

    let statusText: String
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: DUSpacing.xxl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(theme.colors.status.successBackground)
                    .frame(width: 110, height: 110)
                Image(systemName: "paperplane.fill")
                    .font(.du(.featureHero))
                    .foregroundColor(theme.colors.status.success)
            }

            VStack(spacing: DUSpacing.sm) {
                Text(statusText)
                    .font(.du(.hero))
                    .foregroundColor(theme.colors.text.primary)
                    .multilineTextAlignment(.center)

                Text(localized("billing.submission.subtitle"))
                    .font(.du(.bodySmall))
                    .foregroundColor(theme.colors.text.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, DUSpacing.xl)
            .frame(maxWidth: 380)

            Spacer()

            DUButton(title: localized("billing.submission.continue"), style: .primary, action: onContinue)
                .padding(.horizontal, DUSpacing.lg)
                .padding(.bottom, DUSpacing.xxxl)
        }
        .background(theme.colors.background.canvas.ignoresSafeArea())
    }

    private func localized(_ key: String, arguments: [String] = []) -> String {
        languageStore.string(key, arguments: arguments)
    }
}

private struct BillingPreviewController: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageStore: AppLanguageStore
    @State private var isExportPresented = false

    let document: BillingPreviewDocument

    var body: some View {
        NavigationView {
            Group {
                #if canImport(QuickLook)
                QuickLookPreview(url: document.url)
                #else
                Text(document.url.lastPathComponent)
                #endif
            }
            .navigationTitle(localized("billing.pdf.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(localized("common.cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localized("common.save")) {
                        isExportPresented = true
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $isExportPresented) {
            BillingExportController(items: [document.url])
        }
    }

    private func localized(_ key: String, arguments: [String] = []) -> String {
        languageStore.string(key, arguments: arguments)
    }
}

private enum BillingCycleFormatter {
    private static let calendar = Calendar(identifier: .gregorian)

    static func displayTitle(from rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 6 else {
            return nil
        }

        let yearString = String(trimmed.prefix(4))
        let monthStart = trimmed.index(trimmed.startIndex, offsetBy: 4)
        let monthEnd = trimmed.index(monthStart, offsetBy: 2)
        let monthString = String(trimmed[monthStart..<monthEnd])

        guard
            let year = Int(yearString),
            let month = Int(monthString),
            (1...12).contains(month),
            let date = calendar.date(from: DateComponents(year: year, month: month, day: 1))
        else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }
}

struct BillingContainerView_Previews: PreviewProvider {
    static var previews: some View {
        BillingContainerView(
            session: CustSubInfo(
                displayName: "Ahmed Mohammed",
                phoneNumber: AuthValidator.demoPhone,
                greeting: "Good Morning",
                balanceText: "128.50 AED",
                userID: "preview-user",
                serviceNumber: AuthValidator.demoPhone
            ),
            billingService: MockBillingService(),
            aiChatService: MockAIChatService()
        )
        .environmentObject(AppLanguageStore(initialLanguage: .english))
    }
}

#if canImport(QuickLook)
private struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        context.coordinator.url = url
        uiViewController.reloadData()
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var url: URL

        init(url: URL) {
            self.url = url
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}
#endif

#if canImport(UIKit)
struct BillingExportController: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
