import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore

    let session: UserSession
    @ObservedObject var sessionStore: SessionStore
    let meService: any MeServicing

    @State private var placeholderMessage: LocalizedTextValue?
    @State private var selectedTab: HomeTab = .home
    @State private var selectedBannerIndex = 0

    private let pageHorizontalPadding: CGFloat = DUSpacing.md
    private let bannerTimer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()
    private let quickActions: [HomeItem] = [
        .init(title: .key("home.quick.recharge"), assetName: "QuickRechargeIcon"),
        .init(title: .key("home.quick.plans"), assetName: "QuickPlansIcon"),
        .init(title: .key("home.quick.offers"), assetName: "QuickOffersIcon"),
        .init(title: .key("home.quick.mall"), assetName: "QuickMallIcon")
    ]

    private let services: [HomeItem] = [
        .init(title: .key("home.service.dataPack"), assetName: "ServiceDataPackIcon"),
        .init(title: .key("home.service.voicePack"), assetName: "ServiceVoicePackIcon"),
        .init(title: .key("home.service.roaming"), assetName: "ServiceRoamingIcon"),
        .init(title: .key("home.service.tickets"), assetName: "ServiceTicketsIcon"),
        .init(title: .key("home.service.bills"), assetName: "ServiceBillsIcon"),
        .init(title: .key("home.service.points"), assetName: "ServicePointsIcon"),
        .init(title: .key("home.service.mail"), assetName: "ServiceMailIcon"),
        .init(title: .key("home.service.support"), assetName: "ServiceSupportIcon")
    ]

    private let products: [HomeProduct] = [
        .init(
            name: .key("home.product.iphone.name"),
            price: .key("home.product.iphone.price"),
            oldPrice: .key("home.product.iphone.oldPrice"),
            assetName: "ProductIPhoneImage"
        ),
        .init(
            name: .key("home.product.airpods.name"),
            price: .key("home.product.airpods.price"),
            oldPrice: nil,
            assetName: "ProductAirPodsImage"
        ),
        .init(
            name: .key("home.product.watch.name"),
            price: .key("home.product.watch.price"),
            oldPrice: nil,
            assetName: "ProductWatchImage"
        )
    ]

    private let usageItems: [UsageItem] = [
        .init(title: .key("home.usage.data.title"), value: .key("home.usage.data.value"), progress: 0.85),
        .init(title: .key("home.usage.voice.title"), value: .key("home.usage.voice.value"), progress: 0.78),
        .init(title: .key("home.usage.sms.title"), value: .key("home.usage.sms.value"), progress: 0.90)
    ]

    private let banners: [HomeBanner] = [
        .init(
            title: .key("home.banner.newCustomer.title"),
            subtitle: .key("home.banner.newCustomer.subtitle"),
            colors: [DUTheme.cyanLight, DUTheme.blueLight]
        ),
        .init(
            title: .key("home.banner.weekendData.title"),
            subtitle: .key("home.banner.weekendData.subtitle"),
            colors: [DUTheme.blueLight, DUTheme.indigo]
        ),
        .init(
            title: .key("home.banner.mallFlash.title"),
            subtitle: .key("home.banner.mallFlash.subtitle"),
            colors: [DUTheme.indigo, DUTheme.magenta]
        )
    ]

    var body: some View {
        TabView(selection: $selectedTab) {
            homeDashboard
                .tabItem {
                    Image(HomeTab.home.assetName)
                        .renderingMode(.original)
                    Text(localized(HomeTab.home.title))
                }
                .tag(HomeTab.home)

            FeaturePlaceholderView(
                title: HomeTab.service.title,
                icon: HomeTab.service.emoji,
                message: .key("home.feature.service.message")
            )
            .tabItem {
                Image(HomeTab.service.assetName)
                    .renderingMode(.original)
                Text(localized(HomeTab.service.title))
            }
            .tag(HomeTab.service)

            FeaturePlaceholderView(
                title: HomeTab.mall.title,
                icon: HomeTab.mall.emoji,
                message: .key("home.feature.mall.message")
            )
            .tabItem {
                Image(HomeTab.mall.assetName)
                    .renderingMode(.original)
                Text(localized(HomeTab.mall.title))
            }
            .tag(HomeTab.mall)

            FeaturePlaceholderView(
                title: HomeTab.video.title,
                icon: HomeTab.video.emoji,
                message: .key("home.feature.video.message")
            )
            .tabItem {
                Image(HomeTab.video.assetName)
                    .renderingMode(.original)
                Text(localized(HomeTab.video.title))
            }
            .tag(HomeTab.video)

            MeContainerView(
                session: session,
                meService: meService,
                onSignOut: {
                    sessionStore.signOut()
                }
            )
            .tabItem {
                Image(HomeTab.me.assetName)
                    .renderingMode(.original)
                Text(localized(HomeTab.me.title))
            }
            .tag(HomeTab.me)
        }
        .background(DUTheme.background.ignoresSafeArea())
        .alert(isPresented: placeholderAlertIsPresented) {
            Alert(
                title: Text(localized("common.comingSoon.title")),
                message: Text(localized(placeholderMessage)),
                dismissButton: .default(Text(localized("common.ok"))) {
                    placeholderMessage = nil
                }
            )
        }
    }

    private var homeDashboard: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: DUSpacing.md) {
                    header(topInset: proxy.safeAreaInsets.top)
                    quickActionsSection
                    bannerCarousel
                    servicesSection
                    productsSection
                }
                .padding(.bottom, DUSpacing.xl)
            }
            .ignoresSafeArea(edges: .top)
            .background(DUTheme.background.ignoresSafeArea())
        }
    }

    private func header(topInset: CGFloat) -> some View {
        VStack(spacing: DUSpacing.lg) {
            HStack {
                HStack(spacing: DUSpacing.md) {
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.white)
                        )

                    VStack(alignment: .leading, spacing: DUSpacing.xs) {
                        Text(localized(session.greetingKey))
                            .font(.du(11, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))

                        Text(session.displayName)
                            .font(.du(16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                Spacer()

                HStack(spacing: DUSpacing.sm) {
                    CircleAction(symbol: "magnifyingglass") {
                        placeholderMessage = .key("home.placeholder.search")
                    }
                    CircleAction(symbol: "bell.fill") {
                        placeholderMessage = .key("home.placeholder.notifications")
                    }
                }
            }

            VStack(spacing: DUSpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: DUSpacing.xs) {
                        Text(localized("home.header.balanceTitle"))
                            .font(.du(11, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))

                        Text(localized("home.header.balanceAmount", arguments: [session.balanceAmount]))
                            .font(.du(26, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    Button(localized("home.header.recharge")) {
                        showComingSoon(for: .key("home.quick.recharge"))
                    }
                    .font(.du(13, weight: .semibold))
                    .foregroundColor(DUTheme.ink)
                    .padding(.horizontal, DUSpacing.lg)
                    .frame(height: 36)
                    .background(Color.white.opacity(0.95))
                    .clipShape(Capsule())
                }

                HStack(spacing: DUSpacing.lg) {
                    ForEach(usageItems) { item in
                        VStack(alignment: .leading, spacing: DUSpacing.xs) {
                            Text(localized(item.title))
                                .font(.du(10, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))

                            Text(localized(item.value))
                                .font(.du(13, weight: .semibold))
                                .foregroundColor(.white)

                            ProgressView(value: item.progress)
                                .tint(.white)
                        }
                    }
                }
            }
            .padding(DUSpacing.lg)
            .background(Color.white.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .padding(.horizontal, DUSpacing.lg)
        .padding(.top, max(topInset, DUSpacing.xl) + DUSpacing.md)
        .padding(.bottom, DUSpacing.xxl)
        .background(DUTheme.brandGradient)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var quickActionsSection: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: DUSpacing.md), count: 4),
            spacing: DUSpacing.md
        ) {
            ForEach(quickActions) { item in
                Button {
                    showComingSoon(for: item.title)
                } label: {
                    VStack(spacing: DUSpacing.sm) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(DUTheme.backgroundSecondary)
                                .frame(height: 64)

                            Image(item.assetName)
                                .renderingMode(.original)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 48, height: 48)
                        }

                        Text(localized(item.title))
                            .font(.du(12, weight: .medium))
                            .foregroundColor(DUTheme.ink)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DUSpacing.lg)
        .duCardStyle()
        .padding(.horizontal, pageHorizontalPadding)
        .offset(y: -8)
        .padding(.bottom, -8)
    }

    private var bannerCarousel: some View {
        VStack(spacing: DUSpacing.sm) {
            TabView(selection: $selectedBannerIndex) {
                ForEach(Array(banners.enumerated()), id: \.offset) { index, banner in
                    Button {
                        showComingSoon(for: banner.title)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: DUSpacing.sm) {
                                Text("✨ \(localized(banner.title))")
                                    .font(.du(17, weight: .bold))
                                    .foregroundColor(.white)

                                Text(localized(banner.subtitle))
                                    .font(.du(12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.92))
                                    .multilineTextAlignment(.leading)
                            }

                            Spacer(minLength: DUSpacing.md)
                        }
                        .padding(.horizontal, DUSpacing.lg)
                        .padding(.vertical, DUSpacing.xl)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: banner.colors),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 132)

            HStack(spacing: DUSpacing.xs) {
                ForEach(banners.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == selectedBannerIndex ? DUTheme.cyan : DUTheme.inkDisabled.opacity(0.45))
                        .frame(width: index == selectedBannerIndex ? 18 : 6, height: 6)
                }
            }
        }
        .padding(.horizontal, pageHorizontalPadding)
        .onReceive(bannerTimer) { _ in
            selectedBannerIndex = (selectedBannerIndex + 1) % banners.count
        }
    }

    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: DUSpacing.lg) {
            sectionHeader(title: .key("home.section.popularServices"))

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: DUSpacing.md), count: 4),
                spacing: DUSpacing.md
            ) {
                ForEach(services) { item in
                    Button {
                        showComingSoon(for: item.title)
                    } label: {
                        VStack(spacing: DUSpacing.sm) {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(DUTheme.backgroundSecondary)
                                .frame(height: 64)
                                .overlay(
                                    Image(item.assetName)
                                        .renderingMode(.original)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 48, height: 48)
                                )

                            Text(localized(item.title))
                                .font(.du(11, weight: .medium))
                                .foregroundColor(DUTheme.ink)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(DUSpacing.lg)
        .duCardStyle()
        .padding(.horizontal, pageHorizontalPadding)
    }

    private var productsSection: some View {
        VStack(alignment: .leading, spacing: DUSpacing.lg) {
            sectionHeader(title: .key("home.section.trendingProducts"))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DUSpacing.md) {
                    ForEach(products) { product in
                        Button {
                            showComingSoon(for: product.name)
                        } label: {
                            VStack(alignment: .leading, spacing: DUSpacing.md) {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(DUTheme.backgroundSecondary)
                                    .frame(height: 116)
                                    .overlay(
                                        Image(product.assetName)
                                            .renderingMode(.original)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 76, height: 76)
                                    )

                                VStack(alignment: .leading, spacing: DUSpacing.sm) {
                                    Text(localized(product.name))
                                        .font(.du(14, weight: .semibold))
                                        .foregroundColor(DUTheme.ink)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)

                                    HStack(spacing: DUSpacing.sm) {
                                        Text(localized(product.price))
                                            .font(.du(15, weight: .bold))
                                            .foregroundColor(DUTheme.cyan)

                                        if let oldPrice = product.oldPrice {
                                            Text(localized(oldPrice))
                                                .font(.du(12, weight: .medium))
                                                .foregroundColor(DUTheme.inkDisabled)
                                                .strikethrough()
                                        }
                                    }
                                }
                            }
                            .padding(DUSpacing.lg)
                            .frame(width: 196, alignment: .leading)
                            .background(DUTheme.panel)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(DUTheme.lineLight, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DUSpacing.lg)
                .padding(.vertical, 1)
            }
        }
        .padding(.vertical, DUSpacing.lg)
        .duCardStyle()
        .padding(.horizontal, pageHorizontalPadding)
    }

    private func sectionHeader(title: LocalizedTextValue) -> some View {
        HStack {
            Text(localized(title))
                .font(.du(17, weight: .bold))
                .foregroundColor(DUTheme.ink)

            Spacer()

            Button(localized("home.section.viewAll")) {
                showComingSoon(for: title)
            }
            .font(.du(12, weight: .semibold))
            .foregroundColor(DUTheme.cyan)
        }
        .padding(.horizontal, DUSpacing.lg)
    }

    private var placeholderAlertIsPresented: Binding<Bool> {
        Binding(
            get: { placeholderMessage != nil },
            set: { isPresented in
                if !isPresented {
                    placeholderMessage = nil
                }
            }
        )
    }

    private func showComingSoon(for title: LocalizedTextValue) {
        placeholderMessage = .key("common.placeholder.feature", arguments: [localized(title)])
    }

    private func localized(_ key: String, arguments: [String] = []) -> String {
        languageStore.string(key, arguments: arguments)
    }

    private func localized(_ value: LocalizedTextValue?) -> String {
        languageStore.string(value)
    }
}

private enum HomeTab: Hashable {
    case home
    case service
    case mall
    case video
    case me

    var emoji: String {
        switch self {
        case .home:
            return "🏠"
        case .service:
            return "📱"
        case .mall:
            return "🛒"
        case .video:
            return "🎬"
        case .me:
            return "👤"
        }
    }

    var assetName: String {
        switch self {
        case .home:
            return "TabHomeIcon"
        case .service:
            return "TabServiceIcon"
        case .mall:
            return "TabMallIcon"
        case .video:
            return "TabVideoIcon"
        case .me:
            return "TabMeIcon"
        }
    }

    var title: LocalizedTextValue {
        switch self {
        case .home:
            return .key("home.tab.home")
        case .service:
            return .key("home.tab.service")
        case .mall:
            return .key("home.tab.mall")
        case .video:
            return .key("home.tab.video")
        case .me:
            return .key("home.tab.me")
        }
    }
}

private struct HomeItem: Identifiable {
    let id = UUID()
    let title: LocalizedTextValue
    let assetName: String
}

private struct HomeProduct: Identifiable {
    let id = UUID()
    let name: LocalizedTextValue
    let price: LocalizedTextValue
    let oldPrice: LocalizedTextValue?
    let assetName: String
}

private struct HomeBanner {
    let title: LocalizedTextValue
    let subtitle: LocalizedTextValue
    let colors: [Color]
}

private struct UsageItem: Identifiable {
    let id = UUID()
    let title: LocalizedTextValue
    let value: LocalizedTextValue
    let progress: Double
}

private struct CircleAction: View {
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(.white.opacity(0.16))
                .frame(width: 38, height: 38)
                .overlay(
                    Image(systemName: symbol)
                        .font(.du(15, weight: .semibold))
                        .foregroundColor(.white)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct FeaturePlaceholderView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore

    let title: LocalizedTextValue
    let icon: String
    let message: LocalizedTextValue

    var body: some View {
        VStack(spacing: DUSpacing.lg) {
            Text(icon)
                .font(.du(48))

            Text(languageStore.string(title))
                .font(.du(24, weight: .bold))
                .foregroundColor(DUTheme.ink)

            Text(languageStore.string(message))
                .font(.du(15, weight: .medium))
                .foregroundColor(DUTheme.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, DUSpacing.xxl)
        .background(DUTheme.background.ignoresSafeArea())
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(
            session: UserSession(
                displayName: "Ahmed Mohammed",
                phoneNumber: AuthValidator.demoPhone,
                greetingKey: "home.greeting.morning",
                balanceAmount: "128.50"
            ),
            sessionStore: SessionStore.previewAuthenticated,
            meService: MockMeService()
        )
        .environmentObject(AppLanguageStore(initialLanguage: .english))
    }
}
