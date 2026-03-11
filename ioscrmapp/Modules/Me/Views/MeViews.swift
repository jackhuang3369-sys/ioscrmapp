import SwiftUI

struct MeContainerView: View {
    @StateObject private var viewModel: MeViewModel

    init(session: UserSession, meService: any MeServicing) {
        _viewModel = StateObject(
            wrappedValue: MeViewModel(session: session, meService: meService)
        )
    }

    var body: some View {
        screenContent
            .background(DUTheme.background.ignoresSafeArea())
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
                    title: Text("Coming Soon"),
                    message: Text(viewModel.placeholderMessage ?? ""),
                    dismissButton: .default(Text("OK")) {
                        viewModel.placeholderMessage = nil
                    }
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
        VStack(spacing: DUSpacing.lg) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.du(42, weight: .semibold))
                .foregroundColor(DUTheme.cyan)

            Text("Your personal center is almost ready")
                .font(.du(22, weight: .bold))
                .foregroundColor(DUTheme.ink)

            Text("We couldn't find profile modules to display yet. Pull to refresh or try again later.")
                .font(.du(15, weight: .medium))
                .foregroundColor(DUTheme.inkSecondary)
                .multilineTextAlignment(.center)

            Button("Reload") {
                Task {
                    await viewModel.refresh()
                }
            }
            .font(.du(15, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, DUSpacing.xxl)
            .frame(height: 46)
            .background(DUTheme.brandGradient)
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, DUSpacing.xxl)
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: DUSpacing.lg) {
            Image(systemName: "wifi.exclamationmark")
                .font(.du(42, weight: .bold))
                .foregroundColor(DUTheme.error)

            Text("Couldn't load Me")
                .font(.du(22, weight: .bold))
                .foregroundColor(DUTheme.ink)

            Text(message)
                .font(.du(15, weight: .medium))
                .foregroundColor(DUTheme.inkSecondary)
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task {
                    await viewModel.refresh()
                }
            }
            .font(.du(15, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, DUSpacing.xxl)
            .frame(height: 46)
            .background(DUTheme.brandGradient)
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, DUSpacing.xxl)
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
                        Text(viewModel.isPhoneNumberRevealed ? "Hide" : "Reveal")
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
                Text(profile.membershipLabel)
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
                    viewModel.handleAction(named: item.actionTitle)
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

                        Text(item.title)
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
        VStack(alignment: .leading, spacing: DUSpacing.md) {
            HStack {
                Text("My Badges")
                    .font(.du(15, weight: .bold))
                    .foregroundColor(DUTheme.ink)

                Spacer()

                Button("View All") {
                    viewModel.handleAction(named: "My Badges")
                }
                .font(.du(12, weight: .semibold))
                .foregroundColor(DUTheme.cyan)
            }

            if items.isEmpty {
                VStack(spacing: DUSpacing.sm) {
                    Image(systemName: "rosette")
                        .font(.du(24, weight: .semibold))
                        .foregroundColor(DUTheme.inkDisabled)
                    Text("No badges yet")
                        .font(.du(14, weight: .semibold))
                        .foregroundColor(DUTheme.inkSecondary)
                    Text("Your achievements will appear here after new activity.")
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
                                viewModel.handleAction(named: item.actionTitle)
                            } label: {
                                VStack(spacing: DUSpacing.sm) {
                                    Image(item.assetName)
                                        .renderingMode(.original)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 52, height: 52)
                                    Text(item.title)
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
        .padding(DUSpacing.lg)
        .duCardStyle()
    }

    private func menuGroupsSection(groups: [MeMenuGroup]) -> some View {
        VStack(spacing: DUSpacing.lg) {
            if groups.isEmpty {
                VStack(spacing: DUSpacing.sm) {
                    Image(systemName: "square.grid.2x2")
                        .font(.du(24, weight: .semibold))
                        .foregroundColor(DUTheme.inkDisabled)
                    Text("Menu shortcuts will appear soon")
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
        VStack(spacing: 0) {
            ForEach(group.items.indices, id: \.self) { index in
                let item = group.items[index]

                menuGroupRow(item)

                if index < group.items.count - 1 {
                    Divider()
                        .padding(.leading, 84)
                }
            }
        }
        .duCardStyle()
    }

    private func menuGroupRow(_ item: MeMenuItem) -> some View {
        Button {
            viewModel.handleAction(named: item.actionTitle)
        } label: {
            HStack(spacing: DUSpacing.md) {
                Image(item.assetName)
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: DUSpacing.xs) {
                    Text(item.title)
                        .font(.du(15, weight: .semibold))
                        .foregroundColor(DUTheme.ink)
                    Text(item.subtitle)
                        .font(.du(12, weight: .medium))
                        .foregroundColor(DUTheme.inkTertiary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                menuAccessoryView(item.accessory)
            }
            .padding(.horizontal, DUSpacing.lg)
            .padding(.vertical, DUSpacing.lg)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func menuAccessoryView(_ accessory: MeMenuAccessory) -> some View {
        switch accessory {
        case .chevron:
            Image(systemName: "chevron.right")
                .font(.du(12, weight: .bold))
                .foregroundColor(DUTheme.inkDisabled)
        case let .badge(text):
            Text(text)
                .font(.du(10, weight: .bold))
                .foregroundColor(DUTheme.warning)
                .padding(.horizontal, DUSpacing.sm)
                .frame(height: 22)
                .background(DUTheme.warningBackground)
                .clipShape(Capsule())
        }
    }

    private var phoneRevealSheet: some View {
        VStack(alignment: .leading, spacing: DUSpacing.lg) {
            Text("Reveal full number")
                .font(.du(20, weight: .bold))
                .foregroundColor(DUTheme.ink)

            Text("Enter your login password to view the full phone number on this device.")
                .font(.du(14, weight: .medium))
                .foregroundColor(DUTheme.inkSecondary)

            SecureField("Enter password", text: $viewModel.revealPassword)
                .textContentType(.password)
                .font(.du(16, weight: .medium))
                .padding(.horizontal, DUSpacing.lg)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(DUTheme.panel)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(viewModel.revealErrorMessage == nil ? DUTheme.line : DUTheme.error, lineWidth: 1.2)
                )

            if let revealErrorMessage = viewModel.revealErrorMessage {
                Text(revealErrorMessage)
                    .font(.du(12, weight: .medium))
                    .foregroundColor(DUTheme.error)
            }

            Button {
                viewModel.submitRevealPassword()
            } label: {
                HStack {
                    Spacer()
                    if viewModel.isValidatingPassword {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Reveal number")
                            .font(.du(16, weight: .bold))
                    }
                    Spacer()
                }
                .foregroundColor(.white)
                .frame(height: 52)
                .background(DUTheme.brandGradient)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isValidatingPassword)

            Spacer()
        }
        .padding(DUSpacing.xl)
        .background(DUTheme.background)
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
}

struct MeContainerView_Previews: PreviewProvider {
    static var previewSession = UserSession(
        displayName: "Ahmed Mohammed",
        phoneNumber: AuthValidator.demoPhone,
        greeting: "Good Morning",
        balanceText: "128.50 AED"
    )

    static var previews: some View {
        Group {
            MeContainerView(session: previewSession, meService: MockMeService())
                .previewDisplayName("Loaded")

            MeContainerView(session: previewSession, meService: MockMeService(mode: .empty))
                .previewDisplayName("Empty")

            MeContainerView(session: previewSession, meService: MockMeService(mode: .failed))
                .previewDisplayName("Error")
        }
    }
}
