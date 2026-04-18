import SwiftUI

struct BadgeCenterContainerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.duTheme) private var theme
    @EnvironmentObject private var languageStore: AppLanguageStore

    @StateObject private var viewModel: BadgeCenterViewModel
    private let session: CustSubInfo
    private let aiChatService: any AIChatServicing
    private let onAIChatNavigation: (AIChatNavigationTarget) -> Void

    init(
        session: CustSubInfo,
        badgeCenterService: any BadgeCenterServicing,
        aiChatService: any AIChatServicing,
        onAIChatNavigation: @escaping (AIChatNavigationTarget) -> Void = { _ in }
    ) {
        self.session = session
        _viewModel = StateObject(
            wrappedValue: BadgeCenterViewModel(
                session: session,
                badgeCenterService: badgeCenterService
            )
        )
        self.aiChatService = aiChatService
        self.onAIChatNavigation = onAIChatNavigation
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(theme.colors.background.canvas.ignoresSafeArea())

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
        .businessAIAssistant(
            session: session,
            aiChatService: aiChatService,
            onNavigate: handleAIChatNavigation(_:)
        )
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
                        .font(.du(.bodyEmphasized))
                    Text(
                        localized(
                            viewModel.isShowingDetail
                                ? "badgeCenter.action.backToList"
                                : "badgeCenter.action.back"
                        )
                    )
                    .font(.du(.bodyStrong))
                }
                .foregroundColor(theme.colors.text.primary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(
                viewModel.isShowingDetail
                    ? "badgeCenter.detail.backButton"
                    : "badgeCenter.list.backButton"
            )

            Spacer()

            Text(headerTitle)
                .font(.du(.title))
                .foregroundColor(theme.colors.text.primary)
                .multilineTextAlignment(.center)
                .lineLimit(1)

            Spacer()

            DUColorPrimitives.Chrome.transparent
                .frame(width: 82, height: 32)
        }
        .padding(.horizontal, DUSpacing.lg)
        .padding(.top, DUSpacing.md)
        .padding(.bottom, DUSpacing.md)
        .background(theme.colors.surface.card)
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
                .tint(theme.colors.action.primary)

            Text(localized("badgeCenter.loading"))
                .font(.du(.body))
                .foregroundColor(theme.colors.text.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var detailLoadingState: some View {
        VStack(spacing: DUSpacing.lg) {
            ProgressView()
                .tint(theme.colors.action.primary)

            Text(localized("badgeCenter.detail.loading"))
                .font(.du(.body))
                .foregroundColor(theme.colors.text.secondary)
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
                        .font(.du(.labelEmphasized))
                    Text(localized("badgeCenter.filter.button"))
                        .font(.du(.labelStrong))
                    if viewModel.hasAdvancedFiltersApplied {
                        Text(String(viewModel.activeAdvancedFilterCount))
                            .font(.du(.captionEmphasized))
                            .padding(.horizontal, DUSpacing.smd)
                            .frame(height: 18)
                            .background(DUColorPrimitives.Neutral.white.opacity(0.22))
                            .clipShape(Capsule())
                    }
                }
                .foregroundColor(viewModel.isAdvancedFiltersPresented ? DUColorPrimitives.Neutral.white : theme.colors.text.secondary)
                .padding(.horizontal, DUSpacing.md)
                .frame(height: 36)
                .background(viewModel.isAdvancedFiltersPresented ? theme.colors.text.primary : theme.colors.surface.card)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(theme.colors.border.subtle, lineWidth: viewModel.isAdvancedFiltersPresented ? 0 : 1)
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
        .background(theme.colors.surface.card)
        .clipShape(RoundedRectangle(cornerRadius: theme.components.field.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.components.field.cornerRadius, style: .continuous)
                .stroke(theme.colors.border.subtle, lineWidth: 1)
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
                .font(.du(.labelEmphasized))
                .foregroundColor(theme.colors.text.secondary)

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
            iconColor: theme.colors.text.disabled,
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
            iconColor: theme.colors.status.warning,
            title: localized("badgeCenter.empty.filteredTitle"),
            subtitle: localized("badgeCenter.empty.filteredSubtitle")
        )
        .frame(maxWidth: .infinity)
    }

    private func failedState(message: LocalizedTextValue) -> some View {
        DUStateView(
            systemImage: "wifi.exclamationmark",
            iconColor: theme.colors.status.warning,
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
        case .external:
            return false
        default:
            return true
        }
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
                badgeCenterService: MockBadgeCenterService(),
                aiChatService: MockAIChatService()
            )
            .environmentObject(AppLanguageStore(initialLanguage: .english))
            .previewDisplayName("Badge Center EN")

            BadgeCenterContainerView(
                session: previewSession,
                badgeCenterService: MockBadgeCenterService(),
                aiChatService: MockAIChatService()
            )
            .environmentObject(AppLanguageStore(initialLanguage: .arabic))
            .previewDisplayName("Badge Center AR")
        }
    }
}
