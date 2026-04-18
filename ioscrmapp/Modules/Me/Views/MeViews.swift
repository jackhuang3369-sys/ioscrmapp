import SwiftUI

struct MeContainerView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    @AppStorage(AIAssistantPreferences.isBusinessEntryHiddenKey) private var isBusinessAIAssistantHidden = false
    @StateObject private var viewModel: MeViewModel
    @State private var isRechargePresented = false

    private let bottomTabBarClearanceHeight: CGFloat = 70

    private let session: CustSubInfo
    private let billingService: any BillingServicing
    private let rechargeService: any RechargeServicing
    private let badgeCenterService: any BadgeCenterServicing
    private let aiChatService: any AIChatServicing
    private let showRechargeEntry: Bool
    private let isSigningOut: Bool
    private let onSignOut: () -> Void
    private let onAIChatNavigation: (AIChatNavigationTarget) -> Void

    init(
        session: CustSubInfo,
        billingService: any BillingServicing,
        rechargeService: any RechargeServicing,
        badgeCenterService: any BadgeCenterServicing,
        aiChatService: any AIChatServicing,
        meService: any MeServicing,
        showRechargeEntry: Bool = false,
        isSigningOut: Bool = false,
        onSignOut: @escaping () -> Void = {},
        onAIChatNavigation: @escaping (AIChatNavigationTarget) -> Void = { _ in }
    ) {
        self.session = session
        self.billingService = billingService
        self.rechargeService = rechargeService
        self.badgeCenterService = badgeCenterService
        self.aiChatService = aiChatService
        self.showRechargeEntry = showRechargeEntry
        _viewModel = StateObject(
            wrappedValue: MeViewModel(session: session, meService: meService)
        )
        self.isSigningOut = isSigningOut
        self.onSignOut = onSignOut
        self.onAIChatNavigation = onAIChatNavigation
    }

    var body: some View {
        NavigationView {
            ZStack {
                screenContent
                NavigationLink(
                    destination: LanguageSettingsView(),
                    isActive: $viewModel.isLanguageSettingsPresented
                ) {
                    EmptyView()
                }
                .hidden()
                NavigationLink(
                    destination: ThemeSettingsView(),
                    isActive: $viewModel.isThemeSettingsPresented
                ) {
                    EmptyView()
                }
                .hidden()
            }
            .background(DUTheme.background.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .task(id: languageStore.currentLanguage) {
            await viewModel.loadIfNeeded(language: languageStore.currentLanguage)
        }
        .duBottomSheet(
            isPresented: $viewModel.isRevealSheetPresented,
            preferredHeight: 300
        ) {
            phoneRevealSheet
        }
        .alert(isPresented: placeholderAlertIsPresented) {
            Alert(
                title: Text(localized("common.comingSoon.title")),
                message: Text(localized(viewModel.placeholderMessage)),
                dismissButton: .default(Text(localized("common.ok"))) {
                    viewModel.placeholderMessage = nil
                }
            )
        }
        .fullScreenCover(isPresented: $viewModel.isBillingPresented) {
            BillingContainerView(
                session: session,
                billingService: billingService,
                aiChatService: aiChatService,
                onAIChatNavigation: onAIChatNavigation
            )
        }
        .fullScreenCover(isPresented: $isRechargePresented) {
            RechargeContainerView(
                session: session,
                rechargeService: rechargeService,
                aiChatService: aiChatService,
                onAIChatNavigation: onAIChatNavigation
            )
        }
        .fullScreenCover(isPresented: $viewModel.isBadgeCenterPresented) {
            BadgeCenterContainerView(
                session: session,
                badgeCenterService: badgeCenterService,
                aiChatService: aiChatService,
                onAIChatNavigation: onAIChatNavigation
            )
        }
    }

    @ViewBuilder
    private var screenContent: some View {
        switch viewModel.screenState {
        case .idle, .loading:
            loadingState
        case let .failed(message):
            errorState(message: message)
        case let .loaded(content):
            if content.isEffectivelyEmpty {
                emptyState
            } else {
                loadedState(content: content)
            }
        }
    }

    private var loadingState: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 0, style: .continuous)
                        .fill(DUTheme.brandGradient)
                        .frame(height: max(300, proxy.safeAreaInsets.top + 240))
                        .overlay(
                            VStack(spacing: DUSpacing.lg) {
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(width: 80, height: 80)
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.white.opacity(0.18))
                                    .frame(width: 156, height: 18)
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.white.opacity(0.14))
                                    .frame(width: 124, height: 14)
                            }
                            .padding(.top, max(proxy.safeAreaInsets.top, DUSpacing.xl) + DUSpacing.xxl)
                        )

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: DUSpacing.md), count: 4),
                        spacing: DUSpacing.md
                    ) {
                        ForEach(0..<4, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(DUTheme.panel)
                                .frame(height: 108)
                                .redacted(reason: .placeholder)
                        }
                    }
                    .padding(.horizontal, DUSpacing.lg)
                    .offset(y: -22)
                    .padding(.bottom, -2)

                    VStack(spacing: DUSpacing.lg) {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(DUTheme.panel)
                            .frame(height: 138)
                            .redacted(reason: .placeholder)
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(DUTheme.panel)
                            .frame(height: 316)
                            .redacted(reason: .placeholder)
                    }
                    .padding(.horizontal, DUSpacing.lg)
                    .padding(.bottom, bottomTabBarClearanceHeight)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
    }

    private func loadedState(content: MeContent) -> some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    profileHeader(profile: content.profile, topInset: proxy.safeAreaInsets.top)

                    statsGrid(items: content.stats)
                        .padding(.horizontal, DUSpacing.lg)
                        .offset(y: -20)
                        .padding(.bottom, -4)

                    VStack(spacing: DUSpacing.lg) {
                        if showRechargeEntry {
                            rechargeEntryCard
                        }
                        badgesSection(items: content.badges)
                        menuGroupsSection(groups: content.menuGroups)
                        signOutButton
                    }
                    .padding(.horizontal, DUSpacing.lg)
                    .padding(.bottom, bottomTabBarClearanceHeight)
                }
            }
            .background(DUTheme.background.ignoresSafeArea())
            .ignoresSafeArea(edges: .top)
            .refreshable {
                await viewModel.refresh(language: languageStore.currentLanguage)
            }
        }
    }

    private var emptyState: some View {
        DUStateView(
            systemImage: "person.crop.circle.badge.exclamationmark",
            iconColor: DUTheme.cyan,
            title: localized("me.empty.title"),
            subtitle: localized("me.empty.subtitle"),
            actionTitle: localized("common.reload"),
            footer: AnyView(meFooterContent)
        ) {
            Task {
                await viewModel.refresh(language: languageStore.currentLanguage)
            }
        }
    }

    private func errorState(message: LocalizedTextValue) -> some View {
        DUStateView(
            systemImage: "wifi.exclamationmark",
            iconColor: DUTheme.error,
            title: localized("me.error.title"),
            subtitle: localized(message),
            actionTitle: localized("common.retry"),
            footer: AnyView(meFooterContent)
        ) {
            Task {
                await viewModel.refresh(language: languageStore.currentLanguage)
            }
        }
    }

    private func profileHeader(profile: MeProfileSummary, topInset: CGFloat) -> some View {
        VStack(spacing: DUSpacing.md) {
            HStack {
                Spacer()

                Button {
                    viewModel.togglePhoneNumberVisibility()
                } label: {
                    HStack(spacing: DUSpacing.xs) {
                        Image(systemName: viewModel.isPhoneNumberRevealed ? "eye.slash.fill" : "eye.fill")
                        Text(
                            localized(
                                viewModel.isPhoneNumberRevealed
                                    ? "me.profile.hide"
                                    : "me.profile.reveal"
                            )
                        )
                    }
                    .font(.du(12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, DUSpacing.md)
                    .frame(height: 32)
                    .background(Color.white.opacity(0.16))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 82, height: 82)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.24), lineWidth: 3)
                    )
                Text(profile.initials)
                    .font(.du(28, weight: .bold))
                    .foregroundColor(.white)
            }

            Text(profile.displayName)
                .font(.du(22, weight: .bold))
                .foregroundColor(.white)

            Text(viewModel.displayedPhoneNumber)
                .font(.du(14, weight: .medium))
                .foregroundColor(.white.opacity(0.84))

            HStack(spacing: DUSpacing.xs) {
                Image(systemName: "star.fill")
                Text(localized(profile.membershipLabel))
            }
            .font(.du(12, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, DUSpacing.md)
            .frame(height: 30)
            .background(Color.white.opacity(0.16))
            .clipShape(Capsule())
        }
        .padding(.horizontal, DUSpacing.lg)
        .padding(.top, max(topInset, DUSpacing.xl) + DUSpacing.lg)
        .padding(.bottom, DUSpacing.xxxl)
        .frame(maxWidth: .infinity)
        .background(DUTheme.brandGradient)
    }

    private func statsGrid(items: [MeStatItem]) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: DUSpacing.md), count: 4),
            spacing: DUSpacing.md
        ) {
            ForEach(items) { item in
                Button {
                    viewModel.handleAction(item.actionID, localizedTitle: localized(item.title))
                } label: {
                    VStack(spacing: DUSpacing.xs) {
                        Image(item.assetName)
                            .renderingMode(.original)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 34, height: 34)

                        Text(item.value)
                            .font(.du(15, weight: .bold))
                            .foregroundColor(DUTheme.ink)

                        Text(localized(item.title))
                            .font(.du(10, weight: .medium))
                            .foregroundColor(DUTheme.inkTertiary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 110)
                    .padding(.horizontal, DUSpacing.xs)
                }
                .buttonStyle(.plain)
                .duCardStyle()
            }
        }
    }

    private func badgesSection(items: [MeBadgeItem]) -> some View {
        DUSectionCard(
            title: localized("me.section.badges"),
            trailingTitle: localized("me.section.viewAll"),
            trailingAction: {
                viewModel.handleAction(.badges, localizedTitle: localized("me.section.badges"))
            }
        ) {
            if items.isEmpty {
                VStack(spacing: DUSpacing.sm) {
                    Image(systemName: "rosette")
                        .font(.du(24, weight: .semibold))
                        .foregroundColor(DUTheme.inkDisabled)
                    Text(localized("me.badge.emptyTitle"))
                        .font(.du(14, weight: .semibold))
                        .foregroundColor(DUTheme.inkSecondary)
                    Text(localized("me.badge.emptySubtitle"))
                        .font(.du(12, weight: .medium))
                        .foregroundColor(DUTheme.inkTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DUSpacing.xl)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DUSpacing.md) {
                        ForEach(Array(items.prefix(5))) { item in
                            Button {
                                viewModel.handleAction(item.actionID, localizedTitle: localized(item.title))
                            } label: {
                                VStack(spacing: DUSpacing.sm) {
                                    ZStack(alignment: .topTrailing) {
                                        badgePreviewIcon(for: item)

                                        if item.isUnread {
                                            Circle()
                                                .fill(DUTheme.error)
                                                .frame(width: 12, height: 12)
                                                .overlay(
                                                    Circle()
                                                        .stroke(Color.white, lineWidth: 2)
                                                )
                                                .offset(x: 3, y: -3)
                                        }
                                    }

                                    Text(localized(item.title))
                                        .font(.du(10, weight: .medium))
                                        .foregroundColor(DUTheme.inkSecondary)
                                        .multilineTextAlignment(.center)
                                        .frame(width: 68)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, DUSpacing.xs)
                }
            }
        }
    }

    private func badgePreviewIcon(for item: MeBadgeItem) -> some View {
        ZStack {
            Circle()
                .fill(item.accentStyle.gradient)
                .frame(width: 56, height: 56)

            BadgeRemoteIconView(
                assetName: item.iconAssetName ?? item.assetName,
                url: item.remoteIconURL,
                fallbackSystemName: item.fallbackSystemName,
                symbolFont: .du(24, weight: .semibold),
                padding: 9
            )
        }
        .frame(width: 56, height: 56)
    }

    private func menuGroupsSection(groups: [MeMenuGroup]) -> some View {
        VStack(spacing: DUSpacing.lg) {
            if groups.isEmpty {
                VStack(spacing: DUSpacing.sm) {
                    Image(systemName: "square.grid.2x2")
                        .font(.du(24, weight: .semibold))
                        .foregroundColor(DUTheme.inkDisabled)
                    Text(localized("me.menu.empty"))
                        .font(.du(14, weight: .semibold))
                        .foregroundColor(DUTheme.inkSecondary)
                }
                .padding(DUSpacing.xl)
                .frame(maxWidth: .infinity)
                .duCardStyle()
            } else {
                ForEach(groups) { group in
                    menuGroupCard(group)
                }
            }
        }
    }

    private func menuGroupCard(_ group: MeMenuGroup) -> some View {
        DUSectionCard(
            title: nil,
            spacing: 0,
            horizontalPadding: 0,
            verticalPadding: 0
        ) {
            VStack(spacing: 0) {
                ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                    menuGroupRow(item)

                    if item.actionID == .changeTheme {
                        Divider()
                            .padding(.leading, 84)

                        assistantEntryToggleRow

                        if index < group.items.count - 1 {
                            Divider()
                                .padding(.leading, 84)
                        }
                    } else if index < group.items.count - 1 {
                        Divider()
                            .padding(.leading, 84)
                    }
                }
            }
        }
    }

    private func menuGroupRow(_ item: MeMenuItem) -> some View {
        DUListItem(
            title: localized(item.title),
            subtitle: localized(item.subtitle),
            leading: .asset(item.assetName),
            accessory: listItemAccessory(item.accessory)
        ) {
            viewModel.handleAction(item.actionID, localizedTitle: localized(item.title))
        }
    }

    private var assistantEntryToggleRow: some View {
        HStack(spacing: DUSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [DUTheme.cyan.opacity(0.10), DUTheme.magenta.opacity(0.10)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 38, height: 38)

                AIAssistantStaticIcon()
                    .scaleEffect(0.52)
                    .frame(width: 38, height: 38)
            }

            Text(localized("assistant.businessEntry.settings.title"))
                .font(.du(15, weight: .semibold))
                .foregroundColor(DUTheme.ink)

            Spacer()

            Toggle(
                "",
                isOn: Binding(
                    get: { !isBusinessAIAssistantHidden },
                    set: { isBusinessAIAssistantHidden = !$0 }
                )
            )
            .labelsHidden()
            .tint(DUTheme.cyan)
        }
        .padding(.horizontal, DUSpacing.lg)
        .padding(.vertical, DUSpacing.lg)
    }

    private func listItemAccessory(_ accessory: MeMenuAccessory) -> DUListItemAccessory {
        switch accessory {
        case .chevron:
            return .chevron
        case let .badge(text):
            return .badge(localized(text))
        }
    }

    private var phoneRevealSheet: some View {
        VStack(alignment: .leading, spacing: DUSpacing.lg) {
            Text(localized("me.reveal.title"))
                .font(.du(20, weight: .bold))
                .foregroundColor(DUTheme.ink)

            Text(localized("me.reveal.subtitle"))
                .font(.du(14, weight: .medium))
                .foregroundColor(DUTheme.inkSecondary)

            DUTextField(
                title: nil,
                placeholder: localized("me.reveal.placeholder"),
                text: $viewModel.revealPassword,
                error: localized(viewModel.revealErrorMessage),
                isSecure: true
            )

            DUButton(
                title: localized("me.reveal.submit"),
                style: .primary,
                isLoading: viewModel.isValidatingPassword
            ) {
                viewModel.submitRevealPassword()
            }
            .disabled(viewModel.isValidatingPassword)

            Spacer()
        }
        .padding(DUSpacing.xl)
        .background(DUTheme.background)
    }

    private var signOutButton: some View {
        DUButton(
            title: localized("me.signOut.button"),
            style: .danger,
            isLoading: isSigningOut
        ) {
            onSignOut()
        }
        .disabled(isSigningOut)
    }

    private var meFooterContent: some View {
        signOutButton
            .padding(.bottom, bottomTabBarClearanceHeight)
    }

    private var rechargeEntryCard: some View {
        Button {
            isRechargePresented = true
        } label: {
            HStack(spacing: DUSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(DUTheme.cyanBackground)
                        .frame(width: 56, height: 56)

                    Image("QuickRechargeIcon")
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                }

                VStack(alignment: .leading, spacing: DUSpacing.xs) {
                    Text(localized("recharge.title"))
                        .font(.du(16, weight: .bold))
                        .foregroundColor(DUTheme.ink)
                    Text(localized("recharge.meEntry.subtitle"))
                        .font(.du(12, weight: .medium))
                        .foregroundColor(DUTheme.inkSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.du(12, weight: .bold))
                    .foregroundColor(DUTheme.inkTertiary)
            }
            .padding(DUSpacing.lg)
            .background(DUTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(DUTheme.lineLight, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var placeholderAlertIsPresented: Binding<Bool> {
        Binding(
            get: { viewModel.placeholderMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.placeholderMessage = nil
                }
            }
        )
    }

    private func localized(_ key: String, arguments: [String] = []) -> String {
        languageStore.string(key, arguments: arguments)
    }

    private func localized(_ value: LocalizedTextValue?) -> String {
        languageStore.string(value)
    }
}

struct MeContainerView_Previews: PreviewProvider {
    static var previewSession = CustSubInfo(
        displayName: "Ahmed Mohammed",
        phoneNumber: AuthValidator.demoPhone,
        greeting: "Good Morning",
        balanceText: "128.50 AED"
    )

    static var previews: some View {
        Group {
            MeContainerView(session: previewSession, billingService: MockBillingService(), rechargeService: MockRechargeService(), badgeCenterService: MockBadgeCenterService(), aiChatService: MockAIChatService(), meService: MockMeService(), showRechargeEntry: true)
                .previewDisplayName("Loaded")

            MeContainerView(session: previewSession, billingService: MockBillingService(), rechargeService: MockRechargeService(), badgeCenterService: MockBadgeCenterService(), aiChatService: MockAIChatService(), meService: MockMeService(mode: .empty))
                .previewDisplayName("Empty")

            MeContainerView(session: previewSession, billingService: MockBillingService(), rechargeService: MockRechargeService(), badgeCenterService: MockBadgeCenterService(), aiChatService: MockAIChatService(), meService: MockMeService(mode: .failed))
                .previewDisplayName("Error")
        }
        .environmentObject(AppLanguageStore(initialLanguage: .english))
    }
}
