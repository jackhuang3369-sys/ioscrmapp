import SwiftUI

struct DIYOfferBuilderView: View {
    @Environment(\.duTheme) private var theme
    @EnvironmentObject private var languageStore: AppLanguageStore
    @ObservedObject var viewModel: DIYOfferViewModel
    let onViewOrders: () -> Void
    let onBackToOffers: () -> Void

    @State private var isPriceDetailPresented = false

    var body: some View {
        Group {
            switch viewModel.screenState {
            case .idle, .loading:
                loadingState
            case let .failed(message):
                errorState(message)
            case .loaded:
                content
            }
        }
        .navigationTitle(localized("offers.diy.title"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadIfNeeded()
        }
        .sheet(isPresented: $isPriceDetailPresented) {
            DIYOfferPriceDetailSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isConfirmSheetPresented) {
            DIYOfferConfirmSheet(viewModel: viewModel)
        }
        .fullScreenCover(item: $viewModel.successResult) { result in
            DIYOfferAcceptedResultView(
                result: result,
                onViewOrders: {
                    viewModel.dismissSuccessResult()
                    onViewOrders()
                },
                onBack: {
                    viewModel.dismissSuccessResult()
                }
            )
        }
        .fullScreenCover(item: $viewModel.failureResult) { result in
            DIYOfferFailureResultView(
                result: result,
                onBack: {
                    viewModel.dismissFailureResult()
                },
                onViewOrders: {
                    viewModel.dismissFailureResult()
                    onViewOrders()
                }
            )
        }
    }

    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: DUSpacing.lg) {
                heroSection

                if let bannerMessage = viewModel.bannerMessage {
                    bannerView(message: bannerMessage)
                }

                periodSection
                pricingSection
            }
            .padding(DUSpacing.lg)
            .padding(.bottom, DUSpacing.xxxl)
        }
        .background(theme.colors.background.canvas.ignoresSafeArea())
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: DUSpacing.md) {
            Text(localized("offers.diy.hero.eyebrow"))
                .font(.du(.bodySmallEmphasized))
                .foregroundColor(.white.opacity(0.78))
            Text(localized("offers.diy.hero.title"))
                .font(.du(.headlineStrong))
                .foregroundColor(.white)
            Text(localized("offers.diy.hero.subtitle"))
                .font(.du(.bodySmall))
                .foregroundColor(.white.opacity(0.88))

            HStack(spacing: DUSpacing.md) {
                factPill(
                    title: localized("offers.orders.detail.number"),
                    value: viewModel.serviceNumberText
                )
                factPill(
                    title: localized("offers.diy.confirm.effective"),
                    value: localized("offers.effective.immediate")
                )
            }

            HStack(spacing: DUSpacing.md) {
                DUButton(
                    title: localized("offers.diy.viewOrders"),
                    style: .primary,
                    height: 40,
                    cornerRadius: DURadius.md,
                    textStyle: .labelEmphasized
                ) {
                    onViewOrders()
                }
            }
        }
        .padding(DUSpacing.xl)
        .background(theme.colors.gradient.brand)
        .clipShape(RoundedRectangle(cornerRadius: DURadius.sheetLarge, style: .continuous))
        .shadow(
            color: theme.colors.brand.primary.opacity(0.22),
            radius: DUElevation.showcase.radius,
            x: DUElevation.showcase.x,
            y: DUElevation.showcase.y
        )
    }

    private var periodSection: some View {
        DUSectionCard(title: localized("offers.diy.periods.title")) {
            VStack(alignment: .leading, spacing: DUSpacing.md) {
                Text(localized("offers.diy.periods.subtitle"))
                    .font(.du(.label))
                    .foregroundColor(theme.colors.text.secondary)

                periodChips

                if let switchNotice = viewModel.switchNotice {
                    Text(localized(switchNotice))
                        .font(.du(.bodySmallStrong))
                        .foregroundColor(theme.colors.status.warning)
                        .padding(DUSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.colors.status.warningBackground)
                        .clipShape(RoundedRectangle(cornerRadius: DURadius.lg, style: .continuous))
                }

                if viewModel.isEmptyState {
                    emptyState
                } else {
                    VStack(spacing: DUSpacing.md) {
                        ForEach(viewModel.activeResources) { resource in
                            resourceCard(resource)
                        }
                    }
                }
            }
        }
    }

    private var periodChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DUSpacing.sm) {
                ForEach(viewModel.allPeriods) { period in
                    Button {
                        viewModel.selectPeriod(period)
                    } label: {
                        Text(period.title)
                            .font(.du(.labelEmphasized))
                            .foregroundColor(viewModel.activePeriodID == period.id ? .white : theme.colors.text.secondary)
                            .padding(.horizontal, DUSpacing.lg)
                            .frame(height: 36)
                            .background(
                                Group {
                                    if viewModel.activePeriodID == period.id {
                                        theme.colors.gradient.brand
                                    } else {
                                        theme.colors.surface.card
                                    }
                                }
                            )
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(viewModel.activePeriodID == period.id ? .clear : theme.colors.border.default, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: DUSpacing.md) {
            Text(localized("offers.diy.empty.title"))
                .font(.du(.titleSmallStrong))
                .foregroundColor(theme.colors.text.primary)
            Text(localized("offers.diy.empty.subtitle"))
                .font(.du(.bodySmall))
                .foregroundColor(theme.colors.text.secondary)

            HStack(spacing: DUSpacing.md) {
                DUButton(title: localized("offers.diy.viewOrders"), style: .primary) {
                    onViewOrders()
                }
                DUButton(title: localized("offers.diy.backToOffers"), style: .secondary) {
                    onBackToOffers()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DUSpacing.lg)
        .background(theme.colors.background.canvas)
        .clipShape(RoundedRectangle(cornerRadius: DURadius.control, style: .continuous))
    }

    private func resourceCard(_ resource: DIYOfferResource) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.md) {
            HStack(alignment: .top, spacing: DUSpacing.md) {
                VStack(alignment: .leading, spacing: DUSpacing.xs) {
                    Text(resource.attrName)
                        .font(.du(.bodyLargeStrong))
                        .foregroundColor(theme.colors.text.primary)
                    Text(resource.attrCode)
                        .font(.du(.bodySmallStrong))
                        .foregroundColor(theme.colors.text.tertiary)
                }
                Spacer()
                Text(resource.unit)
                    .font(.du(.captionEmphasized))
                    .foregroundColor(theme.colors.brand.primary)
                    .padding(.horizontal, DUSpacing.md)
                    .frame(height: 28)
                    .background(theme.colors.action.primaryBackground)
                    .clipShape(Capsule())
            }

            DUTextField(
                title: localized("offers.diy.value.label"),
                placeholder: "\(resource.defaultValue)",
                text: Binding(
                    get: { viewModel.inputText(for: resource) },
                    set: { viewModel.updateValue($0, for: resource) }
                ),
                error: localized(viewModel.validationMessage(for: resource)),
                keyboardType: .numberPad
            )

            Slider(
                value: Binding(
                    get: { Double(viewModel.numericValue(for: resource)) },
                    set: { viewModel.updateValue(String(Int($0.rounded())), for: resource) }
                ),
                in: Double(resource.minValue)...Double(resource.maxValue),
                step: 1
            )
            .tint(theme.colors.brand.primary)

            HStack {
                Text(localized("offers.diy.range.min", arguments: ["\(resource.minValue)", resource.unit]))
                Spacer()
                Text(localized("offers.diy.range.max", arguments: ["\(resource.maxValue)", resource.unit]))
            }
            .font(.du(.captionStrong))
            .foregroundColor(theme.colors.text.tertiary)
        }
        .padding(DUSpacing.lg)
        .background(theme.colors.background.canvas)
        .clipShape(RoundedRectangle(cornerRadius: DURadius.control, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DURadius.control, style: .continuous)
                .stroke(theme.colors.border.subtle, lineWidth: 1)
        )
    }

    private var pricingSection: some View {
        VStack(alignment: .leading, spacing: DUSpacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: DUSpacing.xs) {
                    Text(localized("offers.diy.pricing.title"))
                        .font(.du(.bodyEmphasized))
                        .foregroundColor(.white.opacity(0.82))
                    Text(viewModel.totalDisplayText)
                        .font(.du(.heroStrong))
                        .foregroundColor(.white)
                }
                Spacer()
                Text(viewModel.isPricingLoading ? localized("offers.diy.pricing.loading") : localized("offers.diy.pricing.debounce"))
                    .font(.du(.captionEmphasized))
                    .foregroundColor(.white)
                    .padding(.horizontal, DUSpacing.md)
                    .frame(height: 28)
                    .background(Color.white.opacity(0.14))
                    .clipShape(Capsule())
            }

            VStack(spacing: DUSpacing.sm) {
                ForEach(viewModel.pricing?.items ?? []) { item in
                    HStack {
                        Text("\(item.title) · \(item.quantity) \(item.unit)")
                        Spacer()
                        Text("\(item.subtotalAmount) \(viewModel.bootstrap?.currencyName ?? "")")
                    }
                    .font(.du(.bodySmallStrong))
                    .foregroundColor(.white)
                }
            }

            HStack(spacing: DUSpacing.md) {
                DUButton(
                    title: localized("offers.diy.priceDetail"),
                    style: .secondary,
                    height: 40,
                    cornerRadius: DURadius.md,
                    textStyle: .labelEmphasized
                ) {
                    isPriceDetailPresented = true
                }
                DUButton(
                    title: localized("offers.diy.submit"),
                    style: .primary,
                    isEnabled: viewModel.canSubmit
                ) {
                    viewModel.openConfirmation()
                }
            }
        }
        .padding(DUSpacing.xl)
        .background(theme.colors.gradient.brand)
        .clipShape(RoundedRectangle(cornerRadius: DURadius.sheet, style: .continuous))
        .shadow(
            color: theme.colors.brand.primary.opacity(0.2),
            radius: DUElevation.spotlight.radius,
            x: DUElevation.spotlight.x,
            y: DUElevation.spotlight.y
        )
    }

    private var loadingState: some View {
        VStack(spacing: DUSpacing.md) {
            ProgressView()
            Text(localized("offers.state.loadingTitle"))
                .font(.du(.body))
                .foregroundColor(theme.colors.text.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.colors.background.canvas.ignoresSafeArea())
    }

    private func errorState(_ message: LocalizedTextValue) -> some View {
        DUStateView(
            systemImage: "wifi.exclamationmark",
            iconColor: theme.colors.status.error,
            title: localized("offers.state.errorTitle"),
            subtitle: localized(message),
            actionTitle: localized("common.retry")
        ) {
            Task { await viewModel.reload() }
        }
        .background(theme.colors.background.canvas.ignoresSafeArea())
    }

    private func bannerView(message: LocalizedTextValue) -> some View {
        HStack(alignment: .top, spacing: DUSpacing.md) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(theme.colors.status.warning)
            VStack(alignment: .leading, spacing: DUSpacing.xs) {
                Text(localized("offers.failure.title"))
                    .font(.du(.bodySmallEmphasized))
                    .foregroundColor(theme.colors.text.primary)
                Text(localized(message))
                    .font(.du(.label))
                    .foregroundColor(theme.colors.text.secondary)
            }
            Spacer()
            Button(localized("common.ok")) {
                viewModel.dismissBanner()
            }
            .font(.du(.bodySmallEmphasized))
            .foregroundColor(theme.colors.brand.primary)
        }
        .padding(DUSpacing.lg)
        .background(theme.colors.status.warningBackground)
        .clipShape(RoundedRectangle(cornerRadius: DURadius.control, style: .continuous))
    }

    private func factPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.xs) {
            Text(title)
                .font(.du(.captionStrong))
                .foregroundColor(.white.opacity(0.72))
            Text(value)
                .font(.du(.bodySmallEmphasized))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DUSpacing.md)
        .background(Color.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: DURadius.lg, style: .continuous))
    }

    private func localized(_ key: String, arguments: [String] = []) -> String {
        languageStore.string(key, arguments: arguments)
    }

    private func localized(_ value: LocalizedTextValue?) -> String {
        languageStore.string(value)
    }
}

private struct DIYOfferPriceDetailSheet: View {
    @Environment(\.duTheme) private var theme
    @EnvironmentObject private var languageStore: AppLanguageStore
    @ObservedObject var viewModel: DIYOfferViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: DUSpacing.md) {
                    ForEach(viewModel.pricing?.items ?? []) { item in
                        DUSectionCard(title: item.title) {
                            VStack(spacing: DUSpacing.sm) {
                                detailRow("offers.diy.detail.quantity", "\(item.quantity) \(item.unit)")
                                detailRow("offers.diy.detail.unitPrice", "\(item.unitPriceAmount) \(viewModel.bootstrap?.currencyName ?? "")")
                                detailRow("offers.diy.detail.subtotal", "\(item.subtotalAmount) \(viewModel.bootstrap?.currencyName ?? "")")
                            }
                        }
                    }
                }
                .padding(DUSpacing.lg)
            }
            .navigationTitle(localized("offers.diy.priceDetail"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localized("common.ok")) {
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func detailRow(_ key: String, _ value: String) -> some View {
        HStack {
            Text(localized(key))
                .font(.du(.labelStrong))
                .foregroundColor(theme.colors.text.secondary)
            Spacer()
            Text(value)
                .font(.du(.labelEmphasized))
                .foregroundColor(theme.colors.text.primary)
        }
    }

    private func localized(_ key: String) -> String {
        languageStore.string(key)
    }
}

private struct DIYOfferConfirmSheet: View {
    @Environment(\.duTheme) private var theme
    @EnvironmentObject private var languageStore: AppLanguageStore
    @ObservedObject var viewModel: DIYOfferViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: DUSpacing.lg) {
                DUSectionCard(title: localized("offers.diy.confirm.title")) {
                    VStack(spacing: DUSpacing.sm) {
                        ForEach(viewModel.confirmSummaryRows, id: \.0) { row in
                            HStack {
                                Text(localized(row.0))
                                    .font(.du(.labelStrong))
                                    .foregroundColor(theme.colors.text.secondary)
                                Spacer()
                                Text(row.1.hasPrefix("offers.") ? localized(row.1) : row.1)
                                    .font(.du(.labelEmphasized))
                                    .foregroundColor(theme.colors.text.primary)
                            }
                        }
                    }
                }

                DUSectionCard(title: localized("offers.diy.detail.title")) {
                    VStack(spacing: DUSpacing.sm) {
                        ForEach(viewModel.pricing?.items ?? []) { item in
                            HStack {
                                Text(item.title)
                                    .font(.du(.labelStrong))
                                    .foregroundColor(theme.colors.text.primary)
                                Spacer()
                                Text("\(item.quantity) \(item.unit)")
                                    .font(.du(.labelEmphasized))
                                    .foregroundColor(theme.colors.text.secondary)
                            }
                        }
                    }
                }

                Spacer(minLength: 0)

                DUButton(
                    title: localized("offers.diy.submit"),
                    style: .primary,
                    isLoading: viewModel.isSubmitting
                ) {
                    Task { await viewModel.submit() }
                }

                DUButton(title: localized("common.cancel"), style: .secondary) {
                    dismiss()
                }
            }
            .padding(DUSpacing.lg)
            .navigationTitle(localized("offers.diy.confirm.title"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
    }

    private func localized(_ key: String) -> String {
        languageStore.string(key)
    }
}

private struct DIYOfferAcceptedResultView: View {
    @Environment(\.duTheme) private var theme
    @EnvironmentObject private var languageStore: AppLanguageStore
    let result: OfferAcceptedResult
    let onViewOrders: () -> Void
    let onBack: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: DUSpacing.lg) {
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .font(.du(.resultDisplay))
                    .foregroundColor(theme.colors.status.success)
                Text(languageStore.string("offers.accepted.subscribe.title"))
                    .font(.du(.headline))
                    .foregroundColor(theme.colors.text.primary)
                Text(languageStore.string("offers.diy.accepted.subtitle"))
                    .font(.du(.bodySmall))
                    .foregroundColor(theme.colors.text.secondary)
                    .multilineTextAlignment(.center)

                DUSectionCard(title: languageStore.string("offers.accepted.title")) {
                    VStack(spacing: DUSpacing.sm) {
                        acceptedFact("offers.accepted.orderId", result.orderId)
                        acceptedFact("offers.accepted.offerName", result.offerName)
                        acceptedFact("offers.accepted.operationType", languageStore.string(result.operationType.titleKey))
                    }
                }

                Spacer()

                DUButton(title: languageStore.string("offers.diy.viewOrders"), style: .primary, action: onViewOrders)
                DUButton(title: languageStore.string("offers.diy.backToDIY"), style: .secondary, action: onBack)
            }
            .padding(DUSpacing.lg)
            .background(theme.colors.background.canvas.ignoresSafeArea())
        }
        .navigationViewStyle(.stack)
    }

    private func acceptedFact(_ key: String, _ value: String) -> some View {
        HStack {
            Text(languageStore.string(key))
                .font(.du(.labelStrong))
                .foregroundColor(theme.colors.text.secondary)
            Spacer()
            Text(value)
                .font(.du(.labelEmphasized))
                .foregroundColor(theme.colors.text.primary)
        }
    }
}

private struct DIYOfferFailureResultView: View {
    @Environment(\.duTheme) private var theme
    @EnvironmentObject private var languageStore: AppLanguageStore
    let result: DIYOfferFailureResult
    let onBack: () -> Void
    let onViewOrders: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: DUSpacing.lg) {
                Spacer()
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.du(.resultDisplay))
                    .foregroundColor(theme.colors.status.error)
                Text(languageStore.string("offers.failure.title"))
                    .font(.du(.headline))
                    .foregroundColor(theme.colors.text.primary)
                Text(result.message)
                    .font(.du(.bodySmall))
                    .foregroundColor(theme.colors.text.secondary)
                    .multilineTextAlignment(.center)

                DUSectionCard(title: languageStore.string("offers.failure.title")) {
                    VStack(spacing: DUSpacing.sm) {
                        if let traceId = result.traceId, !traceId.isEmpty {
                            acceptedFact("offers.orders.detail.traceId", traceId)
                        }
                        acceptedFact("offers.failure.reason", result.message)
                    }
                }

                Spacer()

                DUButton(title: languageStore.string("offers.diy.backToDIY"), style: .primary, action: onBack)
                DUButton(title: languageStore.string("offers.diy.viewOrders"), style: .secondary, action: onViewOrders)
            }
            .padding(DUSpacing.lg)
            .background(theme.colors.background.canvas.ignoresSafeArea())
        }
        .navigationViewStyle(.stack)
    }

    private func acceptedFact(_ key: String, _ value: String) -> some View {
        HStack {
            Text(languageStore.string(key))
                .font(.du(.labelStrong))
                .foregroundColor(theme.colors.text.secondary)
            Spacer()
            Text(value)
                .font(.du(.labelEmphasized))
                .foregroundColor(theme.colors.text.primary)
                .multilineTextAlignment(.trailing)
        }
    }
}
