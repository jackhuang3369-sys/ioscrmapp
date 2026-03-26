import SwiftUI

struct OffersLandingView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    @ObservedObject var viewModel: OffersViewModel

    var body: some View {
        Group {
            switch viewModel.landingState {
            case .idle, .loading:
                loadingState
            case let .failed(message):
                errorState(message: message)
            case .loaded:
                if let snapshot = viewModel.landingSnapshot {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: DUSpacing.lg) {
                            landingHeader
                            primaryOfferCard(snapshot.primaryOffer)
                            subscribedOffersCard(snapshot.subscribedOffers)
                            subscribeEntry
                        }
                        .padding(DUSpacing.lg)
                        .padding(.bottom, DUSpacing.xxxl)
                    }
                    .background(DUTheme.background.ignoresSafeArea())
                    .refreshable {
                        await viewModel.refreshLanding()
                    }
                } else {
                    emptyState
                }
            }
        }
        .sheet(item: $viewModel.pendingUnsubscribeOffer) { offer in
            OffersUnsubscribeConfirmationSheet(
                offer: offer,
                onConfirm: {
                    Task { await viewModel.confirmUnsubscribe(offer) }
                }
            )
        }
    }

    private var landingHeader: some View {
        VStack(alignment: .leading, spacing: DUSpacing.xs) {
            Text(localized("offers.landing.title"))
                .font(.du(28, weight: .bold))
                .foregroundColor(DUTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func primaryOfferCard(_ offer: PrimaryOfferSummary) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.md) {
            HStack(alignment: .top, spacing: DUSpacing.md) {
                VStack(alignment: .leading, spacing: DUSpacing.xs) {
                    Text(localized("offers.primary.title"))
                        .font(.du(13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.74))
                    Text(offer.offerName)
                        .font(.du(22, weight: .bold))
                        .foregroundColor(.white)
                }
                Spacer(minLength: DUSpacing.md)
                Text("Data")
                    .font(.du(11, weight: .bold))
                    .foregroundColor(DUTheme.cyan)
                    .padding(.horizontal, DUSpacing.md)
                    .frame(height: 28)
                    .background(Color.white)
                    .clipShape(Capsule())
            }

            HStack(spacing: DUSpacing.md) {
                detailPill(title: localized("offers.primary.effective"), value: offer.effectiveDate)
                detailPill(title: localized("offers.primary.expiry"), value: offer.expiryDate)
            }
        }
        .padding(DUSpacing.xl)
        .background(DUTheme.brandGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: DUTheme.cyan.opacity(0.18), radius: 18, x: 0, y: 10)
    }

    private func subscribedOffersCard(_ offers: [SubscribedOfferItem]) -> some View {
        DUSectionCard(
            title: localized("offers.subscribed.title"),
            trailingTitle: localized(viewModel.isSubscribedExpanded ? "offers.subscribed.collapse" : "offers.subscribed.expand"),
            trailingAction: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.isSubscribedExpanded.toggle()
                }
            }
        ) {
            if offers.isEmpty {
                Text(localized("offers.subscribed.empty"))
                    .font(.du(14, weight: .medium))
                    .foregroundColor(DUTheme.inkSecondary)
            } else if viewModel.isSubscribedExpanded {
                VStack(spacing: DUSpacing.md) {
                    ForEach(offers) { offer in
                        subscribedOfferCard(offer)
                    }
                }
            } else {
                Text(localized("offers.subscribed.summary", arguments: ["\(offers.count)"]))
                    .font(.du(14, weight: .medium))
                    .foregroundColor(DUTheme.inkSecondary)
            }
        }
    }

    private func subscribedOfferCard(_ offer: SubscribedOfferItem) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.md) {
            HStack(alignment: .top, spacing: DUSpacing.md) {
                VStack(alignment: .leading, spacing: DUSpacing.xs) {
                    Text(offer.offerName)
                        .font(.du(16, weight: .bold))
                        .foregroundColor(DUTheme.ink)
                    Text(offer.offerCategory)
                        .font(.du(11, weight: .bold))
                        .foregroundColor(DUTheme.cyan)
                        .padding(.horizontal, DUSpacing.sm)
                        .frame(height: 24)
                        .background(DUTheme.cyanBackground)
                        .clipShape(Capsule())
                }
                Spacer()
                if offer.canUnsubscribe {
                    DUButton(
                        title: localized("offers.unsubscribe.cta"),
                        style: .secondary,
                        height: 34,
                        fixedWidth: 120,
                        cornerRadius: 14,
                        fontSize: 13
                    ) {
                        viewModel.requestUnsubscribe(offer)
                    }
                }
            }

            HStack(spacing: DUSpacing.md) {
                smallFactCard(
                    title: localized("offers.primary.effective"),
                    value: offer.effectiveDate
                )
                smallFactCard(
                    title: localized("offers.primary.expiry"),
                    value: offer.expiryDate
                )
            }
        }
        .padding(DUSpacing.lg)
        .background(DUTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(DUTheme.lineLight, lineWidth: 1)
        )
    }

    private var subscribeEntry: some View {
        DUSectionCard(title: localized("offers.subscribeEntry.title")) {
            HStack(alignment: .center, spacing: DUSpacing.md) {
                VStack(alignment: .leading, spacing: DUSpacing.md) {
                    Text(localized("offers.subscribeEntry.subtitle"))
                        .font(.du(14, weight: .medium))
                        .foregroundColor(DUTheme.inkSecondary)

                    DUButton(title: localized("offers.subscribeEntry.cta"), style: .primary) {
                        viewModel.openPurchaseList()
                    }

                    DUButton(title: localized("offers.orders.entry"), style: .secondary) {
                        viewModel.openOrderList()
                    }
                }
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: DUSpacing.md) {
            ProgressView()
            Text(localized("offers.state.loadingTitle"))
                .font(.du(15, weight: .medium))
                .foregroundColor(DUTheme.inkSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DUTheme.background.ignoresSafeArea())
    }

    private func errorState(message: LocalizedTextValue) -> some View {
        DUStateView(
            systemImage: "wifi.exclamationmark",
            iconColor: DUTheme.error,
            title: localized("offers.state.errorTitle"),
            subtitle: localized(message),
            actionTitle: localized("common.retry")
        ) {
            Task { await viewModel.refreshLanding() }
        }
        .background(DUTheme.background.ignoresSafeArea())
    }

    private var emptyState: some View {
        DUStateView(
            systemImage: "tray",
            iconColor: DUTheme.warning,
            title: localized("offers.empty.title"),
            subtitle: localized("offers.empty.subtitle"),
            actionTitle: localized("common.reload")
        ) {
            Task { await viewModel.refreshLanding() }
        }
        .background(DUTheme.background.ignoresSafeArea())
    }

    private func detailPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.xs) {
            Text(title)
                .font(.du(11, weight: .semibold))
                .foregroundColor(.white.opacity(0.72))
            Text(value)
                .font(.du(14, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DUSpacing.md)
        .background(Color.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func smallFactCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.xs) {
            Text(title)
                .font(.du(11, weight: .semibold))
                .foregroundColor(DUTheme.inkTertiary)
            Text(value)
                .font(.du(14, weight: .bold))
                .foregroundColor(DUTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DUSpacing.md)
        .background(DUTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func localized(_ key: String, arguments: [String] = []) -> String {
        languageStore.string(key, arguments: arguments)
    }

    private func localized(_ value: LocalizedTextValue?) -> String {
        languageStore.string(value)
    }
}

struct OffersPurchaseListView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    @ObservedObject var viewModel: OffersViewModel

    var body: some View {
        Group {
            switch viewModel.purchaseState {
            case .idle, .loading:
                purchaseLoadingState
            case let .failed(message):
                purchaseErrorState(message: message)
            case .loaded:
                purchaseContent
            }
        }
        .navigationTitle(localized("offers.purchase.title"))
        .navigationBarTitleDisplayMode(.inline)
        .background(detailNavigationLink)
        .sheet(isPresented: $viewModel.isFilterSheetPresented) {
            OffersFilterSheet(viewModel: viewModel)
                .id(viewModel.filterSheetPresentationID)
        }
        .task {
            await viewModel.loadPurchaseIfNeeded()
        }
    }

    private var purchaseContent: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    VStack(spacing: DUSpacing.lg) {
                        if viewModel.filteredEligibleOffers.isEmpty {
                            DUStateView(
                                systemImage: "line.3.horizontal.decrease.circle",
                                iconColor: DUTheme.warning,
                                title: localized("offers.purchase.emptyFiltered.title"),
                                subtitle: localized("offers.purchase.emptyFiltered.subtitle"),
                                actionTitle: localized("offers.filters.reset")
                            ) {
                                viewModel.resetFilters()
                            }
                            .frame(minHeight: 320)
                        } else {
                            LazyVStack(spacing: DUSpacing.md) {
                                ForEach(viewModel.filteredEligibleOffers) { offer in
                                    eligibleOfferCard(offer)
                                }
                            }
                        }
                    }
                    .padding(DUSpacing.lg)
                    .padding(.bottom, DUSpacing.xxxl)
                } header: {
                    purchaseStickyHeader
                }
            }
        }
        .background(DUTheme.background.ignoresSafeArea())
        .refreshable {
            await viewModel.refreshPurchaseList()
        }
    }

    private var resourceTypePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DUSpacing.sm) {
                ForEach(OffersResourceType.allCases) { resourceType in
                    compactFilterChip(
                        title: localized(resourceType.titleKey),
                        isSelected: viewModel.selectedResourceType == resourceType
                    ) {
                        viewModel.selectResourceType(resourceType)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(1)
    }

    private var purchaseStickyHeader: some View {
        HStack(alignment: .center, spacing: DUSpacing.md) {
            resourceTypePicker
            Spacer(minLength: DUSpacing.md)
            actionsBar
        }
        .padding(.horizontal, DUSpacing.lg)
        .padding(.top, DUSpacing.md)
        .padding(.bottom, DUSpacing.md)
        .background(DUTheme.background)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DUTheme.lineLight)
                .frame(height: 1)
        }
    }

    private var actionsBar: some View {
        HStack(spacing: DUSpacing.sm) {
            Menu {
                ForEach(OffersSortOption.allCases) { option in
                    Button(localized(option.titleKey)) {
                        viewModel.selectedSortOption = option
                    }
                }
            } label: {
                HStack(spacing: DUSpacing.sm) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.du(12, weight: .bold))
                    Text(localized(viewModel.selectedSortOption.titleKey))
                        .font(.du(13, weight: .semibold))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .foregroundColor(DUTheme.ink)
                .padding(.horizontal, DUSpacing.md)
                .frame(height: 40)
                .background(DUTheme.panel)
                .clipShape(Capsule())
                .fixedSize(horizontal: true, vertical: false)
            }

            Button {
                viewModel.openFilters()
            } label: {
                HStack(spacing: DUSpacing.sm) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.du(12, weight: .bold))
                    Text(localized("offers.filters.button"))
                        .font(.du(13, weight: .semibold))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .foregroundColor(DUTheme.ink)
                .padding(.horizontal, DUSpacing.md)
                .frame(height: 40)
                .background(DUTheme.panel)
                .clipShape(Capsule())
                .fixedSize(horizontal: true, vertical: false)
            }

            if viewModel.hasActiveLocalFilters {
                DUTextButton(title: localized("offers.filters.reset"), fontSize: 12, weight: .bold) {
                    viewModel.resetFilters()
                }
            }
        }
    }

    private func eligibleOfferCard(_ offer: EligibleOfferItem) -> some View {
        Button {
            viewModel.selectedDetailOffer = offer
        } label: {
            VStack(alignment: .leading, spacing: DUSpacing.md) {
                HStack(alignment: .top, spacing: DUSpacing.md) {
                    VStack(alignment: .leading, spacing: DUSpacing.xs) {
                        Text(offer.offerName)
                            .font(.du(17, weight: .bold))
                            .foregroundColor(DUTheme.ink)
                        HStack(spacing: DUSpacing.sm) {
                            offerBadge(offer.offerType)
                            if let validityRaw = offer.validityRaw, !validityRaw.isEmpty {
                                subtleBadge(validityRaw)
                            }
                        }
                    }
                    Spacer(minLength: DUSpacing.md)
                    VStack(alignment: .trailing, spacing: DUSpacing.xs) {
                        if let priceText = offer.displayPriceText, !priceText.isEmpty {
                            Text(priceText)
                                .font(.du(18, weight: .bold))
                                .foregroundColor(DUTheme.cyan)
                                .multilineTextAlignment(.trailing)
                                .environment(\.layoutDirection, .leftToRight)
                        }
                    }
                }

                if let resourceSummary = offer.resourceSummary, !resourceSummary.isEmpty {
                    HStack(spacing: DUSpacing.sm) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.du(12, weight: .bold))
                            .foregroundColor(DUTheme.cyan)
                        Text(resourceSummary)
                            .font(.du(13, weight: .medium))
                            .foregroundColor(DUTheme.inkSecondary)
                    }
                }

                HStack {
                    Text(localized("offers.purchase.popularRank", arguments: ["\((offer.popularRank ?? offer.originalIndex + 1))"]))
                        .font(.du(12, weight: .semibold))
                        .foregroundColor(DUTheme.inkTertiary)
                    Spacer()
                    HStack(spacing: DUSpacing.xs) {
                        Text(localized("offers.purchase.viewDetail"))
                            .font(.du(12, weight: .semibold))
                            .foregroundColor(DUTheme.inkSecondary)
                        Image(systemName: "chevron.forward")
                            .font(.du(11, weight: .bold))
                            .foregroundColor(DUTheme.inkDisabled)
                    }
                }
            }
            .padding(DUSpacing.lg)
            .background(DUTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(DUTheme.lineLight, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var detailNavigationLink: some View {
        NavigationLink(
            destination: selectedDetailDestination,
            isActive: Binding(
                get: { viewModel.selectedDetailOffer != nil },
                set: { isActive in
                    if !isActive {
                        viewModel.selectedDetailOffer = nil
                    }
                }
            )
        ) {
            EmptyView()
        }
        .hidden()
    }

    @ViewBuilder
    private var selectedDetailDestination: some View {
        if let offer = viewModel.selectedDetailOffer {
            OffersDetailView(viewModel: viewModel, offer: offer)
        } else {
            EmptyView()
        }
    }

    private var purchaseLoadingState: some View {
        VStack(spacing: DUSpacing.md) {
            ProgressView()
            Text(localized("offers.state.loadingTitle"))
                .font(.du(15, weight: .medium))
                .foregroundColor(DUTheme.inkSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DUTheme.background.ignoresSafeArea())
    }

    private func purchaseErrorState(message: LocalizedTextValue) -> some View {
        DUStateView(
            systemImage: "wifi.exclamationmark",
            iconColor: DUTheme.error,
            title: localized("offers.state.errorTitle"),
            subtitle: localized(message),
            actionTitle: localized("common.retry")
        ) {
            Task { await viewModel.refreshPurchaseList() }
        }
        .background(DUTheme.background.ignoresSafeArea())
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.du(13, weight: .semibold))
                .foregroundColor(isSelected ? .white : DUTheme.ink)
                .padding(.horizontal, DUSpacing.lg)
                .frame(height: 38)
                .background(filterChipBackground(isSelected: isSelected))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : DUTheme.lineLight, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func compactFilterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.du(12, weight: .semibold))
                .lineLimit(1)
                .foregroundColor(isSelected ? .white : DUTheme.ink)
                .padding(.horizontal, DUSpacing.md)
                .frame(height: 34)
                .background(filterChipBackground(isSelected: isSelected))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : DUTheme.lineLight, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func filterChipBackground(isSelected: Bool) -> some View {
        let shape = Capsule()
        if isSelected {
            shape.fill(DUTheme.brandGradient)
        } else {
            shape.fill(DUTheme.panel)
        }
    }

    private func offerBadge(_ title: String) -> some View {
        Text(title)
            .font(.du(11, weight: .bold))
            .foregroundColor(DUTheme.cyan)
            .padding(.horizontal, DUSpacing.sm)
            .frame(height: 24)
            .background(DUTheme.cyanBackground)
            .clipShape(Capsule())
    }

    private func subtleBadge(_ title: String) -> some View {
        Text(title)
            .font(.du(11, weight: .bold))
            .foregroundColor(DUTheme.inkSecondary)
            .padding(.horizontal, DUSpacing.sm)
            .frame(height: 24)
            .background(DUTheme.backgroundSecondary)
            .clipShape(Capsule())
    }

    private func localized(_ key: String, arguments: [String] = []) -> String {
        languageStore.string(key, arguments: arguments)
    }

    private func localized(_ value: LocalizedTextValue?) -> String {
        languageStore.string(value)
    }
}

struct OffersDetailView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    @ObservedObject var viewModel: OffersViewModel
    let offer: EligibleOfferItem

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: DUSpacing.lg) {
                detailHero
                if let resourceSummary = offer.resourceSummary, !resourceSummary.isEmpty {
                    DUSectionCard(title: localized("offers.detail.resource")) {
                        Text(resourceSummary)
                            .font(.du(15, weight: .bold))
                            .foregroundColor(DUTheme.ink)
                    }
                }
                DUSectionCard(title: localized("offers.detail.rules")) {
                    VStack(alignment: .leading, spacing: DUSpacing.md) {
                        ruleRow(
                            title: localized("offers.detail.effectiveRule"),
                            detail: localized("offers.rules.effective")
                        )
                        ruleRow(
                            title: localized("offers.detail.changeRule"),
                            detail: localized("offers.rules.change")
                        )
                        ruleRow(
                            title: localized("offers.detail.cancelRule"),
                            detail: localized("offers.rules.cancel")
                        )
                    }
                }
                DUButton(title: localized("offers.subscribe.confirmAction"), style: .primary) {
                    viewModel.requestSubscribe(offer)
                }
            }
            .padding(DUSpacing.lg)
            .padding(.bottom, DUSpacing.xxxl)
        }
        .background(DUTheme.background.ignoresSafeArea())
        .navigationTitle(localized("offers.detail.title"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $viewModel.pendingSubscribeOffer) { selectedOffer in
            OffersSubscribeConfirmationSheet(
                offer: selectedOffer,
                onConfirm: {
                    Task { await viewModel.confirmSubscribe(selectedOffer) }
                }
            )
        }
    }

    private var detailHero: some View {
        VStack(alignment: .leading, spacing: DUSpacing.lg) {
            Text(offer.offerName)
                .font(.du(24, weight: .bold))
                .foregroundColor(.white)
            HStack(spacing: DUSpacing.md) {
                detailFact(title: localized("offers.detail.price"), value: offer.displayPriceText ?? "-")
                detailFact(title: localized("offers.detail.validity"), value: offer.validityRaw ?? "-")
            }
        }
        .padding(DUSpacing.xl)
        .background(DUTheme.brandGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func detailFact(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.xs) {
            Text(title)
                .font(.du(11, weight: .semibold))
                .foregroundColor(.white.opacity(0.72))
            Text(value)
                .font(.du(16, weight: .bold))
                .foregroundColor(.white)
                .environment(\.layoutDirection, .leftToRight)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DUSpacing.md)
        .background(Color.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func ruleRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.xs) {
            Text(title)
                .font(.du(13, weight: .semibold))
                .foregroundColor(DUTheme.ink)
            Text(detail)
                .font(.du(14, weight: .medium))
                .foregroundColor(DUTheme.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func localized(_ key: String, arguments: [String] = []) -> String {
        languageStore.string(key, arguments: arguments)
    }
}

private struct OffersSubscribeConfirmationSheet: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    @Environment(\.dismiss) private var dismiss

    let offer: EligibleOfferItem
    let onConfirm: () -> Void

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: DUSpacing.lg) {
                VStack(alignment: .leading, spacing: DUSpacing.sm) {
                    Text(localized("offers.subscribe.title"))
                        .font(.du(24, weight: .bold))
                        .foregroundColor(DUTheme.ink)
                        .padding(.vertical, DUSpacing.sm)

                    DUSectionCard {
                        VStack(alignment: .leading, spacing: DUSpacing.md) {
                            sheetFact(title: localized("offers.confirmation.offer"), value: offer.offerName)
                            sheetFact(title: localized("offers.confirmation.price"), value: offer.displayPriceText ?? "-")
                            sheetFact(title: localized("offers.confirmation.effective"), value: localized("offers.effective.immediate"))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: DUSpacing.md) {
                    DUButton(title: localized("common.cancel"), style: .secondary) {
                        dismiss()
                    }
                    DUButton(title: localized("offers.subscribe.confirmAction"), style: .primary) {
                        dismiss()
                        onConfirm()
                    }
                }
                .padding(.top, DUSpacing.sm)
            }
            .padding(.top, 40)
            .padding(.horizontal, DUSpacing.lg)
            .padding(.bottom, DUSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .top)
            .background(DUTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
        .modifier(OffersCompactSheetModifier())
    }

    private func sheetFact(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.xs) {
            Text(title)
                .font(.du(12, weight: .semibold))
                .foregroundColor(DUTheme.inkTertiary)
            Text(value)
                .font(.du(15, weight: .bold))
                .foregroundColor(DUTheme.ink)
                .environment(\.layoutDirection, .leftToRight)
        }
    }

    private func localized(_ key: String, arguments: [String] = []) -> String {
        languageStore.string(key, arguments: arguments)
    }
}

private struct OffersUnsubscribeConfirmationSheet: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    @Environment(\.dismiss) private var dismiss

    let offer: SubscribedOfferItem
    let onConfirm: () -> Void

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: DUSpacing.lg) {
                VStack(alignment: .leading, spacing: DUSpacing.sm) {
                    Text(localized("offers.unsubscribe.title"))
                        .font(.du(24, weight: .bold))
                        .foregroundColor(DUTheme.ink)
                        .padding(.vertical, DUSpacing.sm)

                    DUSectionCard {
                        VStack(alignment: .leading, spacing: DUSpacing.md) {
                            sheetFact(title: localized("offers.confirmation.offer"), value: offer.offerName)
                            sheetFact(title: localized("offers.confirmation.category"), value: offer.offerCategory)
                            sheetFact(title: localized("offers.confirmation.effective"), value: localized("offers.effective.immediateExpiry"))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: DUSpacing.md) {
                    DUButton(title: localized("common.cancel"), style: .secondary) {
                        dismiss()
                    }
                    DUButton(title: localized("offers.unsubscribe.confirmAction"), style: .danger) {
                        dismiss()
                        onConfirm()
                    }
                }
                .padding(.top, DUSpacing.sm)
            }
            .padding(.top, 40)
            .padding(.horizontal, DUSpacing.lg)
            .padding(.bottom, DUSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .top)
            .background(DUTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
        .modifier(OffersCompactSheetModifier())
    }

    private func sheetFact(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.xs) {
            Text(title)
                .font(.du(12, weight: .semibold))
                .foregroundColor(DUTheme.inkTertiary)
            Text(value)
                .font(.du(15, weight: .bold))
                .foregroundColor(DUTheme.ink)
        }
    }

    private func localized(_ key: String, arguments: [String] = []) -> String {
        languageStore.string(key, arguments: arguments)
    }
}

private struct OffersFilterSheet: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: OffersViewModel
    @State private var selectedRootCategoryID: String?
    @State private var draftCategoryID: String?

    init(viewModel: OffersViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        let draftCategoryID = viewModel.selectedCategoryID
        _draftCategoryID = State(initialValue: draftCategoryID)
        _selectedRootCategoryID = State(
            initialValue: Self.parentCategoryID(
                for: draftCategoryID,
                categories: viewModel.categories
            ) ?? viewModel.selectedCategoryRootID
        )
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: DUSpacing.lg) {
                    DUSectionCard(title: localized("offers.filters.category")) {
                        HStack(alignment: .top, spacing: DUSpacing.md) {
                            VStack(alignment: .leading, spacing: DUSpacing.sm) {
                                categoryMasterRow(
                                    title: localized("offers.category.all"),
                                    isSelected: draftCategoryID == nil && selectedRootCategoryID == nil
                                ) {
                                    selectedRootCategoryID = nil
                                    draftCategoryID = nil
                                }

                                ForEach(masterCategories) { category in
                                    categoryMasterRow(
                                        title: category.name,
                                        isSelected: selectedRootCategoryID == category.id
                                    ) {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedRootCategoryID = category.id
                                            if Self.parentCategoryID(for: draftCategoryID, categories: viewModel.categories) != category.id {
                                                draftCategoryID = nil
                                            }
                                        }
                                    }
                                }
                            }
                            .frame(width: 148, alignment: .topLeading)

                            VStack(alignment: .leading, spacing: DUSpacing.sm) {
                                if let selectedRootCategoryID {
                                    ForEach(detailCategories(in: selectedRootCategoryID)) { category in
                                        categoryDetailRow(
                                            title: category.name,
                                            isSelected: draftCategoryID == category.id
                                        ) {
                                            draftCategoryID = category.id
                                        }
                                    }
                                } else {
                                    Text(localized("offers.filters.categoryEmpty"))
                                        .font(.du(13, weight: .medium))
                                        .foregroundColor(DUTheme.inkSecondary)
                                        .padding(DUSpacing.md)
                                }
                            }
                            .padding(DUSpacing.sm)
                            .background(DUTheme.background)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                    }

                    DUSectionCard(title: localized("offers.filters.price")) {
                        priceRangeInputs
                    }

                    DUSectionCard(title: localized("offers.filters.validity")) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: DUSpacing.sm) {
                                ForEach(OffersValidityBucket.allCases) { bucket in
                                    validityChip(
                                        title: localized(bucket.titleKey),
                                        isSelected: viewModel.selectedValidityBuckets.contains(bucket)
                                    ) {
                                        viewModel.toggleValidityBucket(bucket)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(DUSpacing.lg)
                .padding(.bottom, DUSpacing.xxxl)
            }
            .background(DUTheme.background.ignoresSafeArea())
            .navigationTitle(localized("offers.filters.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(localized("offers.filters.reset")) {
                        viewModel.resetFilters()
                        selectedRootCategoryID = nil
                        draftCategoryID = nil
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localized("common.ok")) {
                        let committedRootCategoryID = draftCategoryID == nil
                            ? nil
                            : Self.parentCategoryID(for: draftCategoryID, categories: viewModel.categories)
                        if draftCategoryID != viewModel.selectedCategoryID || committedRootCategoryID != viewModel.selectedCategoryRootID {
                            viewModel.selectCategory(
                                draftCategoryID,
                                rootCategoryID: committedRootCategoryID
                            )
                        }
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private var priceRangeInputs: some View {
        HStack(spacing: DUSpacing.md) {
            priceInputField(
                title: localized("offers.filters.minPrice"),
                text: $viewModel.minimumPriceInput
            )
            priceInputField(
                title: localized("offers.filters.maxPrice"),
                text: $viewModel.maximumPriceInput
            )
        }
    }

    private func priceInputField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.sm) {
            Text(title)
                .font(.du(12, weight: .semibold))
                .foregroundColor(DUTheme.inkTertiary)

            HStack(spacing: DUSpacing.sm) {
                TextField("0", text: text)
                    .keyboardType(.decimalPad)
                    .font(.du(15, weight: .semibold))
                    .foregroundColor(DUTheme.ink)
                    .environment(\.layoutDirection, .leftToRight)

                Text("AED")
                    .font(.du(12, weight: .bold))
                    .foregroundColor(DUTheme.inkSecondary)
            }
            .padding(.horizontal, DUSpacing.md)
            .frame(height: 48)
            .background(DUTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(DUTheme.lineLight, lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func validityChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.du(13, weight: .semibold))
                .foregroundColor(isSelected ? .white : DUTheme.ink)
                .padding(.horizontal, DUSpacing.md)
                .frame(height: 36)
                .background(validityChipBackground(isSelected: isSelected))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : DUTheme.lineLight, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func validityChipBackground(isSelected: Bool) -> some View {
        let shape = Capsule()
        if isSelected {
            shape.fill(DUTheme.brandGradient)
        } else {
            shape.fill(DUTheme.panel)
        }
    }

    private func categoryMasterRow(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.du(13, weight: .semibold))
                .foregroundColor(isSelected ? DUTheme.cyan : DUTheme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DUSpacing.md)
                .padding(.vertical, DUSpacing.md)
                .background(isSelected ? DUTheme.cyanBackground : DUTheme.panel)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(isSelected ? DUTheme.cyan.opacity(0.35) : DUTheme.lineLight, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func categoryDetailRow(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DUSpacing.sm) {
                Text(title)
                    .font(.du(13, weight: .semibold))
                    .foregroundColor(DUTheme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.du(16, weight: .bold))
                    .foregroundColor(isSelected ? DUTheme.cyan : DUTheme.inkDisabled)
            }
            .padding(.horizontal, DUSpacing.md)
            .padding(.vertical, DUSpacing.md)
            .background(isSelected ? DUTheme.panel : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func localized(_ key: String, arguments: [String] = []) -> String {
        languageStore.string(key, arguments: arguments)
    }

    private var masterCategories: [OfferCategoryItem] {
        let masterIDs = Set(
            viewModel.categories
                .filter { children(of: $0.id).isEmpty }
                .compactMap(\.parentId)
        )

        return viewModel.categories
            .filter { masterIDs.contains($0.id) }
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder {
                    return (lhs.sortOrder ?? 0) < (rhs.sortOrder ?? 0)
                }
                return lhs.name < rhs.name
            }
    }

    private func detailCategories(in masterID: String) -> [OfferCategoryItem] {
        children(of: masterID)
            .filter { children(of: $0.id).isEmpty }
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder {
                    return (lhs.sortOrder ?? 0) < (rhs.sortOrder ?? 0)
                }
                return lhs.name < rhs.name
            }
    }

    private func children(of parentID: String) -> [OfferCategoryItem] {
        viewModel.categories
            .filter { $0.parentId == parentID }
    }

    private static func parentCategoryID(for categoryID: String?, categories: [OfferCategoryItem]) -> String? {
        guard let categoryID else {
            return nil
        }

        return categories.first(where: { $0.id == categoryID })?.parentId
    }
}

struct OffersAcceptedResultView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore

    let result: OfferAcceptedResult
    let onContinue: () -> Void

    var body: some View {
        NavigationView {
            GeometryReader { proxy in
                ZStack {
                    DUTheme.background.ignoresSafeArea()

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: DUSpacing.lg) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.du(56, weight: .bold))
                                .foregroundColor(DUTheme.success)

                        Text(localized(result.operationType.acceptedTitleKey))
                            .font(.du(24, weight: .bold))
                            .foregroundColor(DUTheme.ink)

                            DUSectionCard(title: localized("offers.accepted.title")) {
                                VStack(alignment: .leading, spacing: DUSpacing.md) {
                                    acceptedFact(title: localized("offers.accepted.orderId"), value: result.orderId)
                                    acceptedFact(title: localized("offers.accepted.offerName"), value: result.offerName)
                                    acceptedFact(title: localized("offers.accepted.operationType"), value: localized(result.operationType.titleKey))
                                    acceptedFact(title: localized("offers.accepted.message"), value: localized(result.operationType.acceptedBodyKey))
                                }
                            }

                            DUButton(title: localized("offers.accepted.back"), style: .primary, action: onContinue)
                        }
                        .padding(DUSpacing.lg)
                        .padding(.bottom, DUSpacing.xxxl)
                        .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .top)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
    }

    private func acceptedFact(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.xs) {
            Text(title)
                .font(.du(12, weight: .semibold))
                .foregroundColor(DUTheme.inkTertiary)
            Text(value)
                .font(.du(15, weight: .bold))
                .foregroundColor(DUTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func localized(_ key: String, arguments: [String] = []) -> String {
        languageStore.string(key, arguments: arguments)
    }
}

private struct OffersCompactSheetModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .presentationDetents([.height(340)])
                .presentationDragIndicator(.visible)
        } else {
            content
        }
    }
}
