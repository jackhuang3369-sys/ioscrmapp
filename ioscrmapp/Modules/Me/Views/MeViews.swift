import SwiftUI

struct MeContainerView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    @StateObject private var viewModel: MeViewModel

    private let session: CustSubInfo
    private let billingService: any BillingServicing
    private let isSigningOut: Bool
    private let onSignOut: () -> Void

    init(
        session: CustSubInfo,
        billingService: any BillingServicing,
        meService: any MeServicing,
        isSigningOut: Bool = false,
        onSignOut: @escaping () -> Void = {}
    ) {
        self.session = session
        self.billingService = billingService
        _viewModel = StateObject(
            wrappedValue: MeViewModel(session: session, meService: meService)
        )
        self.isSigningOut = isSigningOut
        self.onSignOut = onSignOut
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
            }
            .background(DUTheme.background.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .task {
            await viewModel.loadIfNeeded()
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
            BillingContainerView(session: session, billingService: billingService)
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
                    .padding(.bottom, DUSpacing.xxxl)
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
                        badgesSection(items: content.badges)
                        menuGroupsSection(groups: content.menuGroups)
                        signOutButton
                    }
                    .padding(.horizontal, DUSpacing.lg)
                    .padding(.bottom, DUSpacing.xxxl)
                }
            }
            .background(DUTheme.background.ignoresSafeArea())
            .ignoresSafeArea(edges: .top)
            .refreshable {
                await viewModel.refresh()
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
            footer: AnyView(signOutButton)
        ) {
            Task {
                await viewModel.refresh()
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
            footer: AnyView(signOutButton)
        ) {
            Task {
                await viewModel.refresh()
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
                        ForEach(items) { item in
                            Button {
                                viewModel.handleAction(item.actionID, localizedTitle: localized(item.title))
                            } label: {
                                VStack(spacing: DUSpacing.sm) {
                                    Image(item.assetName)
                                        .renderingMode(.original)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 52, height: 52)
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

                    if index < group.items.count - 1 {
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
            MeContainerView(session: previewSession, billingService: MockBillingService(), meService: MockMeService())
                .previewDisplayName("Loaded")

            MeContainerView(session: previewSession, billingService: MockBillingService(), meService: MockMeService(mode: .empty))
                .previewDisplayName("Empty")

            MeContainerView(session: previewSession, billingService: MockBillingService(), meService: MockMeService(mode: .failed))
                .previewDisplayName("Error")
        }
        .environmentObject(AppLanguageStore(initialLanguage: .english))
    }
}
