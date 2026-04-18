import SwiftUI

struct OffersLandingView: View {
    @Environment(\.duTheme) private var theme
    @EnvironmentObject private var languageStore: AppLanguageStore
    @ObservedObject var viewModel: OffersViewModel
    let onOpenDIY: () -> Void

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
                    .background(theme.colors.background.canvas.ignoresSafeArea())
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
                .font(.du(.hero))
                .foregroundColor(theme.colors.text.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func primaryOfferCard(_ offer: PrimaryOfferSummary) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.md) {
            HStack(alignment: .top, spacing: DUSpacing.md) {
                VStack(alignment: .leading, spacing: DUSpacing.xs) {
                    Text(localized("offers.primary.title"))
                        .font(.du(.labelStrong))
                        .foregroundColor(.white.opacity(0.74))
                    Text(offer.offerName)
                        .font(.du(.titleStrong))
                        .foregroundColor(.white)
                }
                Spacer(minLength: DUSpacing.md)
                Text("Data")
                    .font(.du(.captionEmphasized))
                    .foregroundColor(theme.colors.brand.primary)
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
        .background(theme.colors.gradient.brand)
        .clipShape(RoundedRectangle(cornerRadius: DURadius.sheet, style: .continuous))
        .shadow(
            color: theme.colors.brand.primary.opacity(0.18),
            radius: DUElevation.spotlight.radius,
            x: DUElevation.spotlight.x,
            y: DUElevation.spotlight.y
        )
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
                    .font(.du(.bodySmall))
                    .foregroundColor(theme.colors.text.secondary)
            } else if viewModel.isSubscribedExpanded {
                VStack(spacing: DUSpacing.md) {
                    ForEach(offers) { offer in
                        subscribedOfferCard(offer)
                    }
                }
            } else {
                Text(localized("offers.subscribed.summary", arguments: ["\(offers.count)"]))
                    .font(.du(.bodySmall))
                    .foregroundColor(theme.colors.text.secondary)
            }
        }
    }

    private func subscribedOfferCard(_ offer: SubscribedOfferItem) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.md) {
            HStack(alignment: .top, spacing: DUSpacing.md) {
                VStack(alignment: .leading, spacing: DUSpacing.xs) {
                    Text(offer.offerName)
                        .font(.du(.bodyLargeStrong))
                        .foregroundColor(theme.colors.text.primary)
                    Text(offer.offerCategory)
                        .font(.du(.captionEmphasized))
                        .foregroundColor(theme.colors.brand.primary)
                        .padding(.horizontal, DUSpacing.sm)
                        .frame(height: 24)
                        .background(theme.colors.action.primaryBackground)
                        .clipShape(Capsule())
                }
                Spacer()
                if offer.canUnsubscribe {
                    DUButton(
                        title: localized("offers.unsubscribe.cta"),
                        style: .secondary,
                        height: 34,
                        fixedWidth: 120,
                        cornerRadius: DURadius.md,
                        textStyle: .labelEmphasized
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
        .background(theme.colors.background.canvas)
        .clipShape(RoundedRectangle(cornerRadius: DURadius.control, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DURadius.control, style: .continuous)
                .stroke(theme.colors.border.subtle, lineWidth: 1)
        )
    }

    private var subscribeEntry: some View {
        DUSectionCard(title: localized("offers.subscribeEntry.title")) {
            HStack(alignment: .center, spacing: DUSpacing.md) {
                VStack(alignment: .leading, spacing: DUSpacing.md) {
                    DUButton(title: localized("offers.diy.entry"), style: .primary) {
                        onOpenDIY()
                    }

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
                .font(.du(.body))
                .foregroundColor(theme.colors.text.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.colors.background.canvas.ignoresSafeArea())
    }

    private func errorState(message: LocalizedTextValue) -> some View {
        DUStateView(
            systemImage: "wifi.exclamationmark",
            iconColor: theme.colors.status.error,
            title: localized("offers.state.errorTitle"),
            subtitle: localized(message),
            actionTitle: localized("common.retry")
        ) {
            Task { await viewModel.refreshLanding() }
        }
        .background(theme.colors.background.canvas.ignoresSafeArea())
    }

    private var emptyState: some View {
        DUStateView(
            systemImage: "tray",
            iconColor: theme.colors.status.warning,
            title: localized("offers.empty.title"),
            subtitle: localized("offers.empty.subtitle"),
            actionTitle: localized("common.reload")
        ) {
            Task { await viewModel.refreshLanding() }
        }
        .background(theme.colors.background.canvas.ignoresSafeArea())
    }

    private func detailPill(title: String, value: String) -> some View {
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

    private func smallFactCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.xs) {
            Text(title)
                .font(.du(.captionStrong))
                .foregroundColor(theme.colors.text.tertiary)
            Text(value)
                .font(.du(.bodySmallEmphasized))
                .foregroundColor(theme.colors.text.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DUSpacing.md)
        .background(theme.colors.surface.card)
        .clipShape(RoundedRectangle(cornerRadius: DURadius.md, style: .continuous))
    }

    private func localized(_ key: String, arguments: [String] = []) -> String {
        languageStore.string(key, arguments: arguments)
    }

    private func localized(_ value: LocalizedTextValue?) -> String {
        languageStore.string(value)
    }
}

struct OffersPurchaseListView: View {
    @Environment(\.duTheme) private var theme
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
                                iconColor: theme.colors.status.warning,
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
        .background(theme.colors.background.canvas.ignoresSafeArea())
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
        .background(theme.colors.background.canvas)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.colors.border.subtle)
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
                        .font(.du(.bodySmallEmphasized))
                    Text(localized(viewModel.selectedSortOption.titleKey))
                        .font(.du(.labelStrong))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .foregroundColor(theme.colors.text.primary)
                .padding(.horizontal, DUSpacing.md)
                .frame(height: 40)
                .background(theme.colors.surface.card)
                .clipShape(Capsule())
                .fixedSize(horizontal: true, vertical: false)
            }

            Button {
                viewModel.openFilters()
            } label: {
                HStack(spacing: DUSpacing.sm) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.du(.bodySmallEmphasized))
                    Text(localized("offers.filters.button"))
                        .font(.du(.labelStrong))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .foregroundColor(theme.colors.text.primary)
                .padding(.horizontal, DUSpacing.md)
                .frame(height: 40)
                .background(theme.colors.surface.card)
                .clipShape(Capsule())
                .fixedSize(horizontal: true, vertical: false)
            }

            if viewModel.hasActiveLocalFilters {
                DUTextButton(title: localized("offers.filters.reset"), textStyle: .metaEmphasized) {
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
                            .font(.du(.titleSmall))
                            .foregroundColor(theme.colors.text.primary)
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
                                .font(.du(.titleSmallStrong))
                                .foregroundColor(theme.colors.brand.primary)
                                .multilineTextAlignment(.trailing)
                                .environment(\.layoutDirection, .leftToRight)
                        }
                    }
                }

                if let resourceSummary = offer.resourceSummary, !resourceSummary.isEmpty {
                    HStack(spacing: DUSpacing.sm) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.du(.bodySmallEmphasized))
                            .foregroundColor(theme.colors.brand.primary)
                        Text(resourceSummary)
                            .font(.du(.label))
                            .foregroundColor(theme.colors.text.secondary)
                    }
                }

                HStack {
                    Text(localized("offers.purchase.popularRank", arguments: ["\((offer.popularRank ?? offer.originalIndex + 1))"]))
                        .font(.du(.bodySmallStrong))
                        .foregroundColor(theme.colors.text.tertiary)
                    Spacer()
                    HStack(spacing: DUSpacing.xs) {
                        Text(localized("offers.purchase.viewDetail"))
                            .font(.du(.bodySmallStrong))
                            .foregroundColor(theme.colors.text.secondary)
                        Image(systemName: "chevron.forward")
                            .font(.du(.captionEmphasized))
                            .foregroundColor(theme.colors.text.disabled)
                    }
                }
            }
            .padding(DUSpacing.lg)
            .background(theme.colors.surface.card)
            .clipShape(RoundedRectangle(cornerRadius: DURadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DURadius.card, style: .continuous)
                    .stroke(theme.colors.border.subtle, lineWidth: 1)
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
                .font(.du(.body))
                .foregroundColor(theme.colors.text.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.colors.background.canvas.ignoresSafeArea())
    }

    private func purchaseErrorState(message: LocalizedTextValue) -> some View {
        DUStateView(
            systemImage: "wifi.exclamationmark",
            iconColor: theme.colors.status.error,
            title: localized("offers.state.errorTitle"),
            subtitle: localized(message),
            actionTitle: localized("common.retry")
        ) {
            Task { await viewModel.refreshPurchaseList() }
        }
        .background(theme.colors.background.canvas.ignoresSafeArea())
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.du(.labelStrong))
                .foregroundColor(isSelected ? .white : theme.colors.text.primary)
                .padding(.horizontal, DUSpacing.lg)
                .frame(height: 38)
                .background(filterChipBackground(isSelected: isSelected))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : theme.colors.border.subtle, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func compactFilterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.du(.bodySmallStrong))
                .lineLimit(1)
                .foregroundColor(isSelected ? .white : theme.colors.text.primary)
                .padding(.horizontal, DUSpacing.md)
                .frame(height: 34)
                .background(filterChipBackground(isSelected: isSelected))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : theme.colors.border.subtle, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func filterChipBackground(isSelected: Bool) -> some View {
        let shape = Capsule()
        if isSelected {
            shape.fill(theme.colors.gradient.brand)
        } else {
            shape.fill(theme.colors.surface.card)
        }
    }

    private func offerBadge(_ title: String) -> some View {
        Text(title)
            .font(.du(.captionEmphasized))
            .foregroundColor(theme.colors.brand.primary)
            .padding(.horizontal, DUSpacing.sm)
            .frame(height: 24)
            .background(theme.colors.action.primaryBackground)
            .clipShape(Capsule())
    }

    private func subtleBadge(_ title: String) -> some View {
        Text(title)
            .font(.du(.captionEmphasized))
            .foregroundColor(theme.colors.text.secondary)
            .padding(.horizontal, DUSpacing.sm)
            .frame(height: 24)
            .background(theme.colors.background.secondary)
            .clipShape(Capsule())
    }

    private func localized(_ key: String, arguments: [String] = []) -> String {
        languageStore.string(key, arguments: arguments)
    }

    private func localized(_ value: LocalizedTextValue?) -> String {
        languageStore.string(value)
    }
}

struct OffersOrdersView: View {
    @Environment(\.duTheme) private var theme
    @EnvironmentObject private var languageStore: AppLanguageStore
    @ObservedObject var viewModel: OffersViewModel
    @State private var isDateFilterPresented = false
    @State private var draftStartDate = Date()
    @State private var draftEndDate = Date()
    @State private var expandedDateField: OffersOrderDateField?

    var body: some View {
        Group {
            switch viewModel.ordersState {
            case .idle, .loading:
                loadingState
            case let .failed(message):
                errorState(message: message)
            case .loaded:
                content
            }
        }
        .navigationTitle(localized("offers.orders.title"))
        .navigationBarTitleDisplayMode(.inline)
        .background(orderDetailNavigationLink)
        .sheet(isPresented: $viewModel.isOrderFilterPresented) {
            OffersOrdersFilterSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $isDateFilterPresented) {
            OffersOrderDateFilterSheet(
                startDate: $draftStartDate,
                endDate: $draftEndDate,
                expandedDateField: $expandedDateField,
                onReset: {
                    viewModel.applyOrderFilter(
                        OffersOrderFilter(
                            startDate: nil,
                            endDate: nil,
                            subscribeType: viewModel.orderFilter.subscribeType,
                            status: viewModel.orderFilter.status
                        )
                    )
                },
                onApply: {
                    viewModel.applyOrderFilter(
                        OffersOrderFilter(
                            startDate: draftStartDate,
                            endDate: draftEndDate,
                            subscribeType: viewModel.orderFilter.subscribeType,
                            status: viewModel.orderFilter.status
                        )
                    )
                }
            )
        }
        .task {
            await viewModel.loadOrdersIfNeeded()
        }
    }

    private var content: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    VStack(spacing: DUSpacing.lg) {
                        if viewModel.orderEntrySource == .diy {
                            HStack(spacing: DUSpacing.sm) {
                                Image(systemName: "arrowshape.turn.up.forward.fill")
                                    .foregroundColor(theme.colors.brand.primary)
                                Text(localized("offers.orders.entryFromDIY"))
                                    .font(.du(.labelEmphasized))
                                    .foregroundColor(theme.colors.brand.primary)
                                Spacer()
                            }
                            .padding(DUSpacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(theme.colors.action.primaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: DURadius.control, style: .continuous))
                        }

                        if let snapshot = viewModel.ordersSnapshot, snapshot.records.isEmpty {
                            DUStateView(
                                systemImage: "clock.arrow.circlepath",
                                iconColor: theme.colors.status.warning,
                                title: localized("offers.orders.empty.title"),
                                subtitle: localized("offers.orders.empty.subtitle"),
                                actionTitle: localized("offers.filters.reset")
                            ) {
                                viewModel.resetOrderFilter()
                            }
                            .frame(minHeight: 320)
                        } else {
                            LazyVStack(spacing: DUSpacing.md) {
                                ForEach(viewModel.ordersSnapshot?.records ?? []) { record in
                                    orderCard(record)
                                        .onAppear {
                                            Task {
                                                await viewModel.loadMoreOrdersIfNeeded(currentRecord: record)
                                            }
                                        }
                                }

                                if viewModel.isLoadingMoreOrders {
                                    HStack(spacing: DUSpacing.sm) {
                                        ProgressView()
                                        Text(localized("offers.orders.loadingMore"))
                                            .font(.du(.bodySmall))
                                            .foregroundColor(theme.colors.text.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, DUSpacing.md)
                                }
                            }
                        }
                    }
                    .padding(DUSpacing.lg)
                    .padding(.bottom, DUSpacing.xxxl)
                } header: {
                    ordersStickyFilterBar
                }
            }
        }
        .background(theme.colors.background.canvas.ignoresSafeArea())
        .refreshable {
            await viewModel.refreshOrders()
        }
    }

    private var ordersStickyFilterBar: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: DUSpacing.md) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DUSpacing.sm) {
                        statusFilterPill(
                            title: localized("offers.orders.filters.allStatus"),
                            isSelected: viewModel.orderFilter.status == nil
                        ) {
                            applyStatusFilter(nil)
                        }

                        ForEach(OffersOrderStatus.allCases) { status in
                            statusFilterPill(
                                title: localized(status.titleKey),
                                isSelected: viewModel.orderFilter.status == status
                            ) {
                                applyStatusFilter(status)
                            }
                        }
                    }
                }

                HStack(spacing: DUSpacing.sm) {
                    Button {
                        draftStartDate = viewModel.orderFilter.startDate ?? Date()
                        draftEndDate = viewModel.orderFilter.endDate ?? Date()
                        expandedDateField = nil
                        isDateFilterPresented = true
                    } label: {
                        HStack(spacing: DUSpacing.xs) {
                            Image(systemName: "calendar")
                                .font(.du(.bodySmallEmphasized))
                            Text(dateFilterButtonTitle)
                                .font(.du(.bodySmallStrong))
                                .lineLimit(1)
                        }
                        .foregroundColor(theme.colors.brand.primary)
                        .padding(.horizontal, DUSpacing.md)
                        .frame(height: 34)
                        .background(theme.colors.action.primaryBackground)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        viewModel.openOrderFilters()
                    } label: {
                        HStack(spacing: DUSpacing.xs) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.du(.bodySmallEmphasized))
                            Text(localized("offers.orders.filters.button"))
                                .font(.du(.bodySmallStrong))
                                .lineLimit(1)
                        }
                        .foregroundColor(theme.colors.text.primary)
                        .padding(.horizontal, DUSpacing.md)
                        .frame(height: 34)
                        .background(theme.colors.surface.card)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DUSpacing.lg)
            .padding(.vertical, DUSpacing.md)
            .background(theme.colors.background.canvas)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.colors.border.subtle)
                .frame(height: 1)
        }
    }

    private func orderCard(_ record: OffersOrderRecord) -> some View {
        Button {
            viewModel.openOrderDetail(record)
        } label: {
            VStack(alignment: .leading, spacing: DUSpacing.sm) {
                HStack(alignment: .top, spacing: DUSpacing.md) {
                    VStack(alignment: .leading, spacing: DUSpacing.xs) {
                        Text(record.offerName)
                            .font(.du(.bodyLargeStrong))
                            .foregroundColor(theme.colors.text.primary)
                        Text("#\(record.orderId)")
                            .font(.du(.bodySmallStrong))
                            .foregroundColor(theme.colors.text.primary)
                    }

                    Spacer()

                    Text(localized(record.status.titleKey))
                        .font(.du(.captionEmphasized))
                        .foregroundColor(orderStatusTint(record.status))
                        .padding(.horizontal, DUSpacing.md)
                        .frame(height: 28)
                        .background(orderStatusBackground(record.status))
                        .clipShape(Capsule())
                }

                HStack(spacing: DUSpacing.md) {
                    orderFact(
                        title: localized("offers.orders.type"),
                        value: localized(record.subscribeType.titleKey)
                    )
                    orderFact(
                        title: localized("offers.orders.offerType"),
                        value: record.offerType ?? "-"
                    )
                }

                HStack {
                    Text(record.createdTimeText)
                        .font(.du(.bodySmall))
                        .foregroundColor(theme.colors.text.secondary)
                    Spacer()
                    HStack(spacing: DUSpacing.xs) {
                        Text(localized("offers.purchase.viewDetail"))
                            .font(.du(.bodySmallStrong))
                            .foregroundColor(theme.colors.text.secondary)
                        Image(systemName: "chevron.right")
                            .font(.du(.captionEmphasized))
                            .foregroundColor(theme.colors.text.tertiary)
                    }
                }
            }
            .padding(.horizontal, DUSpacing.lg)
            .padding(.vertical, DUSpacing.md)
            .background(theme.colors.surface.card)
            .clipShape(RoundedRectangle(cornerRadius: DURadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DURadius.card, style: .continuous)
                    .stroke(theme.colors.border.subtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func orderFact(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.xs) {
            Text(title)
                .font(.du(.captionStrong))
                .foregroundColor(theme.colors.text.tertiary)
            Text(value)
                .font(.du(.labelEmphasized))
                .foregroundColor(theme.colors.text.primary)
                .environment(\.layoutDirection, .leftToRight)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DUSpacing.md)
        .background(theme.colors.background.canvas)
        .clipShape(RoundedRectangle(cornerRadius: DURadius.lg, style: .continuous))
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

    private func errorState(message: LocalizedTextValue) -> some View {
        DUStateView(
            systemImage: "clock.badge.exclamationmark",
            iconColor: theme.colors.status.error,
            title: localized("offers.state.errorTitle"),
            subtitle: localized(message),
            actionTitle: localized("common.retry")
        ) {
            Task { await viewModel.refreshOrders() }
        }
        .background(theme.colors.background.canvas.ignoresSafeArea())
    }

    private func displayDate(_ date: Date) -> String {
        Self.filterDateFormatter.string(from: date)
    }

    private func effectiveModeText(_ rawValue: String?) -> String {
        guard let rawValue else {
            return "-"
        }

        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "I":
            return localized("offers.effective.immediate")
        default:
            return rawValue
        }
    }

    private func orderStatusTint(_ status: OffersOrderStatus) -> Color {
        switch status {
        case .initial:
            return theme.colors.status.warning
        case .success:
            return theme.colors.status.success
        case .abnormal:
            return theme.colors.status.error
        }
    }

    private func orderStatusBackground(_ status: OffersOrderStatus) -> Color {
        switch status {
        case .initial:
            return theme.colors.status.warningBackground
        case .success:
            return theme.colors.status.successBackground
        case .abnormal:
            return theme.colors.status.errorBackground
        }
    }

    private func applyStatusFilter(_ status: OffersOrderStatus?) {
        viewModel.applyOrderFilter(
            OffersOrderFilter(
                startDate: viewModel.orderFilter.startDate,
                endDate: viewModel.orderFilter.endDate,
                subscribeType: viewModel.orderFilter.subscribeType,
                status: status
            )
        )
    }

    private func statusFilterPill(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.du(.bodySmallStrong))
                .foregroundColor(isSelected ? .white : theme.colors.text.primary)
                .padding(.horizontal, DUSpacing.md)
                .frame(height: 34)
                .background(statusFilterBackground(isSelected: isSelected))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func statusFilterBackground(isSelected: Bool) -> some View {
        let shape = Capsule()
        if isSelected {
            shape.fill(theme.colors.gradient.brand)
        } else {
            shape.fill(theme.colors.surface.card)
        }
    }

    private var dateFilterButtonTitle: String {
        guard let startDate = viewModel.orderFilter.startDate,
              let endDate = viewModel.orderFilter.endDate else {
            return localized("offers.orders.filters.date")
        }

        return "\(Self.filterDateFormatter.string(from: startDate))-\(Self.filterDateFormatter.string(from: endDate))"
    }

    private var orderDetailNavigationLink: some View {
        NavigationLink(
            destination: presentedOrderDetailDestination,
            isActive: Binding(
                get: { viewModel.selectedOrder != nil },
                set: { isActive in
                    if !isActive {
                        viewModel.dismissOrderDetail()
                    }
                }
            )
        ) {
            EmptyView()
        }
        .hidden()
    }

    @ViewBuilder
    private var presentedOrderDetailDestination: some View {
        if let selectedOrder = viewModel.selectedOrder {
            OffersOrderDetailView(viewModel: viewModel, record: selectedOrder)
        } else {
            EmptyView()
        }
    }

    private func localized(_ key: String, arguments: [String] = []) -> String {
        languageStore.string(key, arguments: arguments)
    }

    private func localized(_ value: LocalizedTextValue?) -> String {
        languageStore.string(value)
    }

    private static let filterDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter
    }()
}

private enum OffersOrderDateField {
    case start
    case end
}

struct OffersDetailView: View {
    @Environment(\.duTheme) private var theme
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
                            .font(.du(.bodyEmphasized))
                            .foregroundColor(theme.colors.text.primary)
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
        .background(theme.colors.background.canvas.ignoresSafeArea())
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
                .font(.du(.headline))
                .foregroundColor(.white)
            HStack(spacing: DUSpacing.md) {
                detailFact(title: localized("offers.detail.price"), value: offer.displayPriceText ?? "-")
                detailFact(title: localized("offers.detail.validity"), value: offer.validityRaw ?? "-")
            }
        }
        .padding(DUSpacing.xl)
        .background(theme.colors.gradient.brand)
        .clipShape(RoundedRectangle(cornerRadius: DURadius.sheet, style: .continuous))
    }

    private func detailFact(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.xs) {
            Text(title)
                .font(.du(.captionStrong))
                .foregroundColor(.white.opacity(0.72))
            Text(value)
                .font(.du(.bodyLargeStrong))
                .foregroundColor(.white)
                .environment(\.layoutDirection, .leftToRight)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DUSpacing.md)
        .background(Color.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: DURadius.lg, style: .continuous))
    }

    private func ruleRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.xs) {
            Text(title)
                .font(.du(.labelStrong))
                .foregroundColor(theme.colors.text.primary)
            Text(detail)
                .font(.du(.bodySmall))
                .foregroundColor(theme.colors.text.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func localized(_ key: String, arguments: [String] = []) -> String {
        languageStore.string(key, arguments: arguments)
    }
}

private struct OffersSubscribeConfirmationSheet: View {
    @Environment(\.duTheme) private var theme
    @EnvironmentObject private var languageStore: AppLanguageStore
    @Environment(\.dismiss) private var dismiss

    let offer: EligibleOfferItem
    let onConfirm: () -> Void

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: DUSpacing.lg) {
                VStack(alignment: .leading, spacing: DUSpacing.sm) {
                    Text(localized("offers.subscribe.title"))
                        .font(.du(.headline))
                        .foregroundColor(theme.colors.text.primary)
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
            .padding(.top, DUSpacing.xxxxl)
            .padding(.horizontal, DUSpacing.lg)
            .padding(.bottom, DUSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .top)
            .background(theme.colors.background.canvas.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
        .modifier(OffersCompactSheetModifier())
    }

    private func sheetFact(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.xs) {
            Text(title)
                .font(.du(.bodySmallStrong))
                .foregroundColor(theme.colors.text.tertiary)
            Text(value)
                .font(.du(.bodyEmphasized))
                .foregroundColor(theme.colors.text.primary)
                .environment(\.layoutDirection, .leftToRight)
        }
    }

    private func localized(_ key: String, arguments: [String] = []) -> String {
        languageStore.string(key, arguments: arguments)
    }
}

private struct OffersUnsubscribeConfirmationSheet: View {
    @Environment(\.duTheme) private var theme
    @EnvironmentObject private var languageStore: AppLanguageStore
    @Environment(\.dismiss) private var dismiss

    let offer: SubscribedOfferItem
    let onConfirm: () -> Void

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: DUSpacing.lg) {
                VStack(alignment: .leading, spacing: DUSpacing.sm) {
                    Text(localized("offers.unsubscribe.title"))
                        .font(.du(.headline))
                        .foregroundColor(theme.colors.text.primary)
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
            .padding(.top, DUSpacing.xxxxl)
            .padding(.horizontal, DUSpacing.lg)
            .padding(.bottom, DUSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .top)
            .background(theme.colors.background.canvas.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
        .modifier(OffersCompactSheetModifier())
    }

    private func sheetFact(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.xs) {
            Text(title)
                .font(.du(.bodySmallStrong))
                .foregroundColor(theme.colors.text.tertiary)
            Text(value)
                .font(.du(.bodyEmphasized))
                .foregroundColor(theme.colors.text.primary)
        }
    }

    private func localized(_ key: String, arguments: [String] = []) -> String {
        languageStore.string(key, arguments: arguments)
    }
}

private struct OffersFilterSheet: View {
    @Environment(\.duTheme) private var theme
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
                                        .font(.du(.label))
                                        .foregroundColor(theme.colors.text.secondary)
                                        .padding(DUSpacing.md)
                                }
                            }
                            .padding(DUSpacing.sm)
                            .background(theme.colors.background.canvas)
                            .clipShape(RoundedRectangle(cornerRadius: DURadius.control, style: .continuous))
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
            .background(theme.colors.background.canvas.ignoresSafeArea())
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
                .font(.du(.bodySmallStrong))
                .foregroundColor(theme.colors.text.tertiary)

            HStack(spacing: DUSpacing.sm) {
                TextField("0", text: text)
                    .keyboardType(.decimalPad)
                    .font(.du(.bodyStrong))
                    .foregroundColor(theme.colors.text.primary)
                    .environment(\.layoutDirection, .leftToRight)

                Text("AED")
                    .font(.du(.bodySmallEmphasized))
                    .foregroundColor(theme.colors.text.secondary)
            }
            .padding(.horizontal, DUSpacing.md)
            .frame(height: 48)
            .background(theme.colors.surface.card)
            .clipShape(RoundedRectangle(cornerRadius: DURadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DURadius.lg, style: .continuous)
                    .stroke(theme.colors.border.subtle, lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func validityChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.du(.labelStrong))
                .foregroundColor(isSelected ? .white : theme.colors.text.primary)
                .padding(.horizontal, DUSpacing.md)
                .frame(height: 36)
                .background(validityChipBackground(isSelected: isSelected))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : theme.colors.border.subtle, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func validityChipBackground(isSelected: Bool) -> some View {
        let shape = Capsule()
        if isSelected {
            shape.fill(theme.colors.gradient.brand)
        } else {
            shape.fill(theme.colors.surface.card)
        }
    }

    private func categoryMasterRow(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.du(.labelStrong))
                .foregroundColor(isSelected ? theme.colors.brand.primary : theme.colors.text.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DUSpacing.md)
                .padding(.vertical, DUSpacing.md)
                .background(isSelected ? theme.colors.action.primaryBackground : theme.colors.surface.card)
                .clipShape(RoundedRectangle(cornerRadius: DURadius.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DURadius.lg, style: .continuous)
                        .stroke(isSelected ? theme.colors.brand.primary.opacity(0.35) : theme.colors.border.subtle, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func categoryDetailRow(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DUSpacing.sm) {
                Text(title)
                    .font(.du(.labelStrong))
                    .foregroundColor(theme.colors.text.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.du(.bodyLargeStrong))
                    .foregroundColor(isSelected ? theme.colors.brand.primary : theme.colors.text.disabled)
            }
            .padding(.horizontal, DUSpacing.md)
            .padding(.vertical, DUSpacing.md)
            .background(isSelected ? theme.colors.surface.card : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: DURadius.lg, style: .continuous))
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

private struct OffersOrdersFilterSheet: View {
    @Environment(\.duTheme) private var theme
    @EnvironmentObject private var languageStore: AppLanguageStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: OffersViewModel

    @State private var draftSubscribeType: OffersOrderSubscribeType?

    init(viewModel: OffersViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        _draftSubscribeType = State(initialValue: viewModel.orderFilter.subscribeType)
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: DUSpacing.lg) {
                    DUSectionCard(title: localized("offers.orders.filters.subscribeType")) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: DUSpacing.sm) {
                                orderFilterChip(
                                    title: localized("offers.orders.filters.allTypes"),
                                    isSelected: draftSubscribeType == nil
                                ) {
                                    draftSubscribeType = nil
                                }

                                ForEach(OffersOrderSubscribeType.allCases) { subscribeType in
                                    orderFilterChip(
                                        title: localized(subscribeType.titleKey),
                                        isSelected: draftSubscribeType == subscribeType
                                    ) {
                                        draftSubscribeType = subscribeType
                                    }
                                }
                            }
                        }
                    }

                    HStack(spacing: DUSpacing.md) {
                        DUButton(title: localized("offers.filters.reset"), style: .secondary) {
                            draftSubscribeType = nil
                        }

                        DUButton(title: localized("common.ok"), style: .primary) {
                            viewModel.applyOrderFilter(
                                OffersOrderFilter(
                                    startDate: viewModel.orderFilter.startDate,
                                    endDate: viewModel.orderFilter.endDate,
                                    subscribeType: draftSubscribeType,
                                    status: viewModel.orderFilter.status
                                )
                            )
                            dismiss()
                        }
                    }
                }
                .padding(DUSpacing.lg)
                .padding(.bottom, DUSpacing.xxxl)
            }
            .background(theme.colors.background.canvas.ignoresSafeArea())
            .navigationTitle(localized("offers.orders.filters.title"))
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
    }

    private func orderFilterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.du(.labelStrong))
                .foregroundColor(isSelected ? .white : theme.colors.text.primary)
                .padding(.horizontal, DUSpacing.md)
                .frame(height: 36)
                .background(orderFilterChipBackground(isSelected: isSelected))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : theme.colors.border.subtle, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func orderFilterChipBackground(isSelected: Bool) -> some View {
        let shape = Capsule()
        if isSelected {
            shape.fill(theme.colors.gradient.brand)
        } else {
            shape.fill(theme.colors.surface.card)
        }
    }

    private func localized(_ key: String, arguments: [String] = []) -> String {
        languageStore.string(key, arguments: arguments)
    }
}

private struct OffersOrderDateFilterSheet: View {
    @Environment(\.duTheme) private var theme
    @EnvironmentObject private var languageStore: AppLanguageStore
    @Environment(\.dismiss) private var dismiss

    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var expandedDateField: OffersOrderDateField?

    let onReset: () -> Void
    let onApply: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: DUSpacing.lg) {
                VStack(alignment: .leading, spacing: DUSpacing.md) {
                    Text(localized("offers.orders.filters.date"))
                        .font(.du(.bodyEmphasized))
                        .foregroundColor(theme.colors.text.primary)

                    HStack(spacing: DUSpacing.sm) {
                        dateValueButton(
                            title: Self.filterDateFormatter.string(from: startDate),
                            isExpanded: expandedDateField == .start
                        ) {
                            expandedDateField = expandedDateField == .start ? nil : .start
                        }

                        Text("-")
                            .font(.du(.bodyLargeStrong))
                            .foregroundColor(theme.colors.text.secondary)

                        dateValueButton(
                            title: Self.filterDateFormatter.string(from: endDate),
                            isExpanded: expandedDateField == .end
                        ) {
                            expandedDateField = expandedDateField == .end ? nil : .end
                        }
                    }

                    if let expandedDateField {
                        datePickerCard(
                            title: expandedDateField == .start
                                ? localized("offers.orders.filters.startTime")
                                : localized("offers.orders.filters.endTime"),
                            selection: dateSelectionBinding(for: expandedDateField)
                        )
                    }
                }

                HStack(spacing: DUSpacing.md) {
                    DUButton(title: localized("offers.filters.reset"), style: .secondary) {
                        onReset()
                        dismiss()
                    }

                    DUButton(title: localized("common.ok"), style: .primary) {
                        if endDate < startDate {
                            endDate = startDate
                        }
                        onApply()
                        dismiss()
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(DUSpacing.lg)
            .padding(.bottom, DUSpacing.xxxl)
            .background(theme.colors.background.canvas.ignoresSafeArea())
            .navigationTitle(localized("offers.orders.filters.date"))
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
    }

    private func dateValueButton(
        title: String,
        isExpanded: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: DUSpacing.sm) {
                Text(title)
                    .font(.du(.bodySmallStrong))
                    .foregroundColor(theme.colors.text.primary)
                Spacer(minLength: 0)
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.du(.captionEmphasized))
                    .foregroundColor(theme.colors.text.secondary)
            }
            .padding(.horizontal, DUSpacing.md)
            .frame(height: 44)
            .background(theme.colors.surface.card)
            .clipShape(RoundedRectangle(cornerRadius: DURadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DURadius.lg, style: .continuous)
                    .stroke(isExpanded ? theme.colors.brand.primary : theme.colors.border.subtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func datePickerCard(title: String, selection: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.md) {
            Text(title)
                .font(.du(.labelStrong))
                .foregroundColor(theme.colors.text.secondary)

            OffersOrderNumericDatePicker(selection: selection)
                .padding(DUSpacing.sm)
                .background(theme.colors.surface.card)
                .clipShape(RoundedRectangle(cornerRadius: DURadius.control, style: .continuous))
        }
    }

    private func dateSelectionBinding(for field: OffersOrderDateField) -> Binding<Date> {
        Binding(
            get: { field == .start ? startDate : endDate },
            set: { newValue in
                if field == .start {
                    startDate = newValue
                    if endDate < newValue {
                        endDate = newValue
                    }
                } else {
                    endDate = max(newValue, startDate)
                }
            }
        )
    }

    private func localized(_ key: String, arguments: [String] = []) -> String {
        languageStore.string(key, arguments: arguments)
    }

    private static let filterDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter
    }()
}

private struct OffersOrderNumericDatePicker: View {
    @Binding var selection: Date

    private let calendar = Calendar(identifier: .gregorian)
    private let years = Array(2020...2035)
    private let months = Array(1...12)

    var body: some View {
        HStack(spacing: DUSpacing.sm) {
            pickerColumn(values: years, selection: yearBinding, accessibilityLabel: "Year") { String($0) }
            pickerColumn(values: months, selection: monthBinding, accessibilityLabel: "Month") { String(format: "%02d", $0) }
            pickerColumn(values: days, selection: dayBinding, accessibilityLabel: "Day") { String(format: "%02d", $0) }
        }
        .frame(height: 180)
    }

    private var components: DateComponents {
        calendar.dateComponents([.year, .month, .day], from: selection)
    }

    private var currentYear: Int { components.year ?? 2026 }
    private var currentMonth: Int { components.month ?? 1 }
    private var currentDay: Int { components.day ?? 1 }

    private var days: [Int] {
        let date = calendar.date(from: DateComponents(year: currentYear, month: currentMonth, day: 1)) ?? selection
        let range = calendar.range(of: .day, in: .month, for: date) ?? 1..<32
        return Array(range)
    }

    private var yearBinding: Binding<Int> {
        Binding(
            get: { currentYear },
            set: { updateDate(year: $0, month: currentMonth, day: currentDay) }
        )
    }

    private var monthBinding: Binding<Int> {
        Binding(
            get: { currentMonth },
            set: { updateDate(year: currentYear, month: $0, day: currentDay) }
        )
    }

    private var dayBinding: Binding<Int> {
        Binding(
            get: { min(currentDay, days.last ?? currentDay) },
            set: { updateDate(year: currentYear, month: currentMonth, day: $0) }
        )
    }

    private func pickerColumn(
        values: [Int],
        selection: Binding<Int>,
        accessibilityLabel: String,
        format: @escaping (Int) -> String
    ) -> some View {
        Picker(accessibilityLabel, selection: selection) {
            ForEach(values, id: \.self) { value in
                Text(format(value)).tag(value)
            }
        }
        .labelsHidden()
        .pickerStyle(.wheel)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private func updateDate(year: Int, month: Int, day: Int) {
        let baseDate = calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? selection
        let maxDay = calendar.range(of: .day, in: .month, for: baseDate)?.count ?? 31
        let normalizedDay = min(day, maxDay)
        let newDate = calendar.date(from: DateComponents(year: year, month: month, day: normalizedDay)) ?? selection
        selection = newDate
    }
}

private struct OffersOrderDetailView: View {
    @Environment(\.duTheme) private var theme
    @EnvironmentObject private var languageStore: AppLanguageStore

    @ObservedObject var viewModel: OffersViewModel
    let record: OffersOrderRecord

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: DUSpacing.lg) {
                detailHero
                detailFacts
            }
            .padding(DUSpacing.lg)
            .padding(.bottom, DUSpacing.xxxl)
        }
        .background(theme.colors.background.canvas.ignoresSafeArea())
        .navigationTitle(localized("offers.orders.detail.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var detailHero: some View {
        VStack(alignment: .leading, spacing: DUSpacing.lg) {
            Text(record.offerName)
                .font(.du(.headline))
                .foregroundColor(.white)

            HStack(spacing: DUSpacing.md) {
                detailHeroMetric(
                    title: localized("offers.orders.detail.status"),
                    value: localized(record.status.titleKey)
                )
                detailHeroMetric(
                    title: localized("offers.orders.type"),
                    value: localized(record.subscribeType.titleKey)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DUSpacing.xl)
        .background(theme.colors.gradient.brand)
        .clipShape(RoundedRectangle(cornerRadius: DURadius.hero, style: .continuous))
    }

    private func detailHeroMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.xs) {
            Text(title)
                .font(.du(.tiny))
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

    private var detailFacts: some View {
        DUSectionCard(title: localized("offers.orders.detail.sectionTitle")) {
            VStack(spacing: DUSpacing.md) {
                detailFactRow(title: localized("offers.accepted.orderId"), value: record.orderId)
                detailFactRow(title: localized("offers.accepted.offerName"), value: record.offerName)
                detailFactRow(title: localized("offers.orders.detail.created"), value: record.createdTimeText)
                detailFactRow(title: localized("offers.orders.detail.number"), value: viewModel.serviceNumberText)
                detailFactRow(title: localized("offers.orders.type"), value: localized(record.subscribeType.titleKey))
                detailFactRow(title: localized("offers.orders.detail.status"), value: localized(record.status.titleKey))
                detailFactRow(title: localized("offers.orders.offerType"), value: record.offerType ?? "-")
                detailFactRow(title: localized("offers.orders.effectiveMode"), value: effectiveModeText(record.effectiveMode))
                detailFactRow(title: localized("offers.orders.detail.statusCode"), value: record.statusCode)
            }
        }
    }

    private func detailFactRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: DUSpacing.md) {
            Text(title)
                .font(.du(.bodySmallStrong))
                .foregroundColor(theme.colors.text.secondary)
            Spacer()
            Text(value)
                .font(.du(.bodySmallStrong))
                .foregroundColor(theme.colors.text.primary)
                .multilineTextAlignment(.trailing)
                .environment(\.layoutDirection, .leftToRight)
        }
    }

    private func effectiveModeText(_ rawValue: String?) -> String {
        guard let rawValue else {
            return "-"
        }

        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "I":
            return localized("offers.effective.immediate")
        default:
            return rawValue
        }
    }

    private func localized(_ key: String, arguments: [String] = []) -> String {
        languageStore.string(key, arguments: arguments)
    }
}

struct OffersAcceptedResultView: View {
    @Environment(\.duTheme) private var theme
    @EnvironmentObject private var languageStore: AppLanguageStore

    let result: OfferAcceptedResult
    let onContinue: () -> Void

    var body: some View {
        NavigationView {
            GeometryReader { proxy in
                ZStack {
                    theme.colors.background.canvas.ignoresSafeArea()

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: DUSpacing.lg) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.du(.resultDisplay))
                                .foregroundColor(theme.colors.status.success)

                        Text(localized(result.operationType.acceptedTitleKey))
                            .font(.du(.headline))
                            .foregroundColor(theme.colors.text.primary)

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
                .font(.du(.bodySmallStrong))
                .foregroundColor(theme.colors.text.tertiary)
            Text(value)
                .font(.du(.bodyEmphasized))
                .foregroundColor(theme.colors.text.primary)
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
