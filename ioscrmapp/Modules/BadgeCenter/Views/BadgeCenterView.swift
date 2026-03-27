import SwiftUI

struct BadgeCenterContainerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageStore: AppLanguageStore

    @StateObject private var viewModel: BadgeCenterViewModel
    private let session: CustSubInfo

    init(session: CustSubInfo, badgeCenterService: any BadgeCenterServicing) {
        self.session = session
        _viewModel = StateObject(
            wrappedValue: BadgeCenterViewModel(
                session: session,
                badgeCenterService: badgeCenterService
            )
        )
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(DUTheme.background.ignoresSafeArea())

            if let unlockEvent = viewModel.pendingUnlockEvent, !viewModel.isShowingDetail {
                BadgeUnlockPromptView(
                    event: unlockEvent,
                    isLoading: viewModel.isUnlockActionInFlight,
                    onLater: {
                        Task {
                            await viewModel.handleUnlockLater(language: languageStore.currentLanguage)
                        }
                    },
                    onViewNow: {
                        Task {
                            await viewModel.handleUnlockViewNow(language: languageStore.currentLanguage)
                        }
                    },
                    localized: localized(_:arguments:)
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityIdentifier(
            viewModel.isShowingDetail
                ? viewModel.selectedBadge.map { "badgeCenter.detail.\($0.id)" } ?? "badgeCenter.detail.loading"
                : "badgeCenter.list.page"
        )
        .task(id: languageStore.currentLanguage) {
            await viewModel.loadIfNeeded(language: languageStore.currentLanguage)
        }
        .alert(isPresented: alertIsPresented) {
            Alert(
                title: Text(localized("badgeCenter.error.title")),
                message: Text(localized(viewModel.alertMessage)),
                dismissButton: .default(Text(localized("common.ok"))) {
                    viewModel.clearAlert()
                }
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isShowingDetail {
            if viewModel.isDetailLoading {
                detailLoadingState
            } else if let badge = viewModel.selectedBadge {
                BadgeDetailContentView(
                    badge: badge,
                    localized: localized(_:arguments:),
                    localizedText: localized(_:)
                )
            } else {
                failedState(message: .key("badgeCenter.error.detail"))
            }
        } else {
            switch viewModel.screenState {
            case .idle, .loading:
                loadingState
            case let .failed(message):
                failedState(message: message)
            case .loaded:
                if viewModel.hasAnyBadges {
                    listContent
                } else {
                    emptyState
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: DUSpacing.md) {
            Button(action: handleBackAction) {
                HStack(spacing: DUSpacing.sm) {
                    Image(systemName: "chevron.backward")
                        .font(.du(15, weight: .bold))
                    Text(
                        localized(
                            viewModel.isShowingDetail
                                ? "badgeCenter.action.backToList"
                                : "badgeCenter.action.back"
                        )
                    )
                    .font(.du(15, weight: .semibold))
                }
                .foregroundColor(DUTheme.ink)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(
                viewModel.isShowingDetail
                    ? "badgeCenter.detail.backButton"
                    : "badgeCenter.list.backButton"
            )

            Spacer()

            Text(headerTitle)
                .font(.du(20, weight: .bold))
                .foregroundColor(DUTheme.ink)
                .multilineTextAlignment(.center)
                .lineLimit(1)

            Spacer()

            Color.clear
                .frame(width: 82, height: 32)
        }
        .padding(.horizontal, DUSpacing.lg)
        .padding(.top, DUSpacing.md)
        .padding(.bottom, DUSpacing.md)
        .background(DUTheme.panel)
    }

    private var headerTitle: String {
        if viewModel.isShowingDetail {
            return localized("badgeCenter.detail.title")
        }
        return localized("badgeCenter.title")
    }

    private var loadingState: some View {
        VStack(spacing: DUSpacing.lg) {
            ProgressView()
                .tint(DUTheme.cyan)

            Text(localized("badgeCenter.loading"))
                .font(.du(15, weight: .medium))
                .foregroundColor(DUTheme.inkSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var detailLoadingState: some View {
        VStack(spacing: DUSpacing.lg) {
            ProgressView()
                .tint(DUTheme.cyan)

            Text(localized("badgeCenter.detail.loading"))
                .font(.du(15, weight: .medium))
                .foregroundColor(DUTheme.inkSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("badgeCenter.detail.loading")
    }

    private var listContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: DUSpacing.lg) {
                BadgeCenterOverviewCard(
                    displayName: session.displayName,
                    overview: viewModel.snapshot?.overview,
                    totalBadgeCount: viewModel.snapshot?.totalCount ?? 0,
                    localized: localized(_:arguments:)
                )

                filterToolbar

                if viewModel.isAdvancedFiltersPresented {
                    advancedFiltersSection
                }

                if viewModel.isFilteredEmpty {
                    filteredEmptyState
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 108), spacing: DUSpacing.md)],
                        spacing: DUSpacing.md
                    ) {
                        ForEach(viewModel.visibleBadges) { badge in
                            BadgeCardView(
                                badge: badge,
                                localized: localized(_:arguments:),
                                localizedText: localized(_:)
                            ) {
                                Task {
                                    await viewModel.openBadge(badge, language: languageStore.currentLanguage)
                                }
                            }
                        }
                    }
                }
            }
            .padding(DUSpacing.lg)
            .padding(.bottom, DUSpacing.xxxl)
        }
        .refreshable {
            await viewModel.reload(language: languageStore.currentLanguage)
        }
    }

    private var filterToolbar: some View {
        HStack(spacing: DUSpacing.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DUSpacing.sm) {
                    ForEach(BadgeStatusFilter.allCases) { status in
                        BadgeFilterChip(
                            title: localized(status.titleKey),
                            countText: String(viewModel.statusBadgeCount(for: status)),
                            isSelected: viewModel.selectedStatus == status
                        ) {
                            viewModel.selectedStatus = status
                        }
                        .accessibilityIdentifier("badgeCenter.filter.status.\(status.id)")
                    }
                }
                .padding(.vertical, DUSpacing.xs)
            }

            Button {
                viewModel.toggleAdvancedFilters()
            } label: {
                HStack(spacing: DUSpacing.xs) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.du(13, weight: .bold))
                    Text(localized("badgeCenter.filter.button"))
                        .font(.du(13, weight: .semibold))
                    if viewModel.hasAdvancedFiltersApplied {
                        Text(String(viewModel.activeAdvancedFilterCount))
                            .font(.du(11, weight: .bold))
                            .padding(.horizontal, 6)
                            .frame(height: 18)
                            .background(Color.white.opacity(0.22))
                            .clipShape(Capsule())
                    }
                }
                .foregroundColor(viewModel.isAdvancedFiltersPresented ? .white : DUTheme.inkSecondary)
                .padding(.horizontal, DUSpacing.md)
                .frame(height: 36)
                .background(viewModel.isAdvancedFiltersPresented ? DUTheme.ink : Color.white)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(DUTheme.lineLight, lineWidth: viewModel.isAdvancedFiltersPresented ? 0 : 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("badgeCenter.filter.advancedButton")
        }
    }

    private var advancedFiltersSection: some View {
        VStack(alignment: .leading, spacing: DUSpacing.md) {
            advancedFilterRow(
                title: localized("badgeCenter.filter.level.title"),
                items: BadgeLevelFilter.allCases,
                selectedValue: viewModel.selectedLevel,
                accessibilityPrefix: "badgeCenter.filter.level"
            ) { level in
                viewModel.selectedLevel = level
            }

            advancedFilterRow(
                title: localized("badgeCenter.filter.category.title"),
                items: BadgeCategoryFilter.allCases,
                selectedValue: viewModel.selectedCategory,
                accessibilityPrefix: "badgeCenter.filter.category"
            ) { category in
                viewModel.selectedCategory = category
            }
        }
        .padding(DUSpacing.md)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(DUTheme.lineLight, lineWidth: 1)
        )
        .accessibilityIdentifier("badgeCenter.filter.advancedPanel")
    }

    private func advancedFilterRow<Item: Identifiable>(
        title: String,
        items: [Item],
        selectedValue: Item,
        accessibilityPrefix: String,
        onSelect: @escaping (Item) -> Void
    ) -> some View where Item.ID == String, Item: BadgeFilterDisplayable, Item: Equatable {
        VStack(alignment: .leading, spacing: DUSpacing.sm) {
            Text(title)
                .font(.du(13, weight: .bold))
                .foregroundColor(DUTheme.inkSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DUSpacing.sm) {
                    ForEach(items) { item in
                        BadgeFilterChip(
                            title: localized(item.filterDisplayTitleKey),
                            isSelected: item == selectedValue
                        ) {
                            onSelect(item)
                        }
                        .accessibilityIdentifier("\(accessibilityPrefix).\(item.id)")
                    }
                }
                .padding(.vertical, DUSpacing.xs)
            }
        }
    }

    private var emptyState: some View {
        DUStateView(
            systemImage: "rosette",
            iconColor: DUTheme.inkDisabled,
            title: localized("badgeCenter.empty.title"),
            subtitle: localized("badgeCenter.empty.subtitle"),
            actionTitle: localized("common.retry"),
            actionStyle: .secondary
        ) {
            Task {
                await viewModel.reload(language: languageStore.currentLanguage)
            }
        }
    }

    private var filteredEmptyState: some View {
        DUStateView(
            systemImage: "line.3.horizontal.decrease.circle",
            iconColor: DUTheme.warning,
            title: localized("badgeCenter.empty.filteredTitle"),
            subtitle: localized("badgeCenter.empty.filteredSubtitle")
        )
        .frame(maxWidth: .infinity)
    }

    private func failedState(message: LocalizedTextValue) -> some View {
        DUStateView(
            systemImage: "wifi.exclamationmark",
            iconColor: DUTheme.warning,
            title: localized("badgeCenter.error.title"),
            subtitle: localized(message),
            actionTitle: localized("common.retry"),
            actionStyle: .secondary
        ) {
            Task {
                await viewModel.reload(language: languageStore.currentLanguage)
            }
        }
    }

    private var alertIsPresented: Binding<Bool> {
        Binding(
            get: { viewModel.alertMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.clearAlert()
                }
            }
        )
    }

    private func handleBackAction() {
        if viewModel.isShowingDetail {
            viewModel.dismissDetail()
            return
        }
        dismiss()
    }

    private func localized(_ key: String, arguments: [String] = []) -> String {
        languageStore.string(key, arguments: arguments)
    }

    private func localized(_ value: LocalizedTextValue?) -> String {
        languageStore.string(value)
    }
}

struct BadgeCenterContainerView_Previews: PreviewProvider {
    static var previewSession = CustSubInfo(
        displayName: "Ahmed Mohammed",
        phoneNumber: AuthValidator.demoPhone,
        greeting: "Good Morning",
        balanceText: "128.50 AED"
    )

    static var previews: some View {
        Group {
            BadgeCenterContainerView(
                session: previewSession,
                badgeCenterService: MockBadgeCenterService()
            )
            .environmentObject(AppLanguageStore(initialLanguage: .english))
            .previewDisplayName("Badge Center EN")

            BadgeCenterContainerView(
                session: previewSession,
                badgeCenterService: MockBadgeCenterService()
            )
            .environmentObject(AppLanguageStore(initialLanguage: .arabic))
            .previewDisplayName("Badge Center AR")
        }
    }
}
