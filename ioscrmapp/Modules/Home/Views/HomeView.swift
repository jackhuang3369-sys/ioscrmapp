import SwiftUI

struct HomeView: View {
    let session: UserSession
    @ObservedObject var sessionStore: SessionStore
    let meService: any MeServicing

    @State private var placeholderMessage: String?
    @State private var selectedTab: HomeTab = .home
    @State private var selectedBannerIndex = 0

    private let pageHorizontalPadding: CGFloat = DUSpacing.md
    private let bannerTimer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()
    private let quickActions: [HomeItem] = [
        .init(title: "Recharge", assetName: "QuickRechargeIcon"),
        .init(title: "Plans", assetName: "QuickPlansIcon"),
        .init(title: "Offers", assetName: "QuickOffersIcon"),
        .init(title: "Mall", assetName: "QuickMallIcon")
    ]

    private let services: [HomeItem] = [
        .init(title: "Data Pack", assetName: "ServiceDataPackIcon"),
        .init(title: "Voice Pack", assetName: "ServiceVoicePackIcon"),
        .init(title: "Roaming", assetName: "ServiceRoamingIcon"),
        .init(title: "Tickets", assetName: "ServiceTicketsIcon"),
        .init(title: "Bills", assetName: "ServiceBillsIcon"),
        .init(title: "Points", assetName: "ServicePointsIcon"),
        .init(title: "Mail", assetName: "ServiceMailIcon"),
        .init(title: "Support", assetName: "ServiceSupportIcon")
    ]

    private let products: [HomeProduct] = [
        .init(name: "iPhone 15 Pro Max 256GB", price: "AED 5,999", oldPrice: "AED 6,999", assetName: "ProductIPhoneImage"),
        .init(name: "AirPods Pro 2", price: "AED 1,299", oldPrice: nil, assetName: "ProductAirPodsImage"),
        .init(name: "Apple Watch S9", price: "AED 2,499", oldPrice: nil, assetName: "ProductWatchImage")
    ]

    private let usageItems: [UsageItem] = [
        .init(title: "Data", value: "8.5 / 10 GB", progress: 0.85),
        .init(title: "Voice", value: "156 / 200 min", progress: 0.78),
        .init(title: "SMS", value: "45 / 50", progress: 0.90)
    ]

    private let banners: [HomeBanner] = [
        .init(
            title: "New customer special",
            subtitle: "Get 50% extra data on your first recharge. Offer ends in 3 days.",
            colors: [DUTheme.cyanLight, DUTheme.blueLight]
        ),
        .init(
            title: "Weekend double data",
            subtitle: "Activate before Friday and enjoy 2× data on selected add-ons.",
            colors: [DUTheme.blueLight, DUTheme.indigo]
        ),
        .init(
            title: "Mall flash offers",
            subtitle: "Hot devices and accessories with limited-time monthly installment deals.",
            colors: [DUTheme.indigo, DUTheme.magenta]
        )
    ]

    var body: some View {
        TabView(selection: $selectedTab) {
            homeDashboard
                .tabItem {
                    Image(HomeTab.home.assetName)
                        .renderingMode(.original)
                    Text(HomeTab.home.title)
                }
                .tag(HomeTab.home)

            FeaturePlaceholderView(
                title: HomeTab.service.title,
                icon: HomeTab.service.emoji,
                message: "Service hub is coming soon."
            )
            .tabItem {
                Image(HomeTab.service.assetName)
                    .renderingMode(.original)
                Text(HomeTab.service.title)
            }
            .tag(HomeTab.service)

            FeaturePlaceholderView(
                title: HomeTab.mall.title,
                icon: HomeTab.mall.emoji,
                message: "Mall is coming soon."
            )
            .tabItem {
                Image(HomeTab.mall.assetName)
                    .renderingMode(.original)
                Text(HomeTab.mall.title)
            }
            .tag(HomeTab.mall)

            FeaturePlaceholderView(
                title: HomeTab.video.title,
                icon: HomeTab.video.emoji,
                message: "Video experiences are coming soon."
            )
            .tabItem {
                Image(HomeTab.video.assetName)
                    .renderingMode(.original)
                Text(HomeTab.video.title)
            }
            .tag(HomeTab.video)

            MeContainerView(session: session, meService: meService)
            .tabItem {
                Image(HomeTab.me.assetName)
                    .renderingMode(.original)
                Text(HomeTab.me.title)
            }
            .tag(HomeTab.me)
        }
        .background(DUTheme.background.ignoresSafeArea())
        .alert(isPresented: placeholderAlertIsPresented) {
            Alert(
                title: Text("Coming Soon"),
                message: Text(placeholderMessage ?? ""),
                dismissButton: .default(Text("OK")) {
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
                        Text(session.greeting)
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
                        placeholderMessage = "Search is coming soon."
                    }
                    CircleAction(symbol: "bell.fill") {
                        placeholderMessage = "Notifications are coming soon."
                    }
                    CircleAction(symbol: "rectangle.portrait.and.arrow.right") {
                        sessionStore.signOut()
                    }
                }
            }

            VStack(spacing: DUSpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: DUSpacing.xs) {
                        Text("Current Balance")
                            .font(.du(11, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))

                        Text(session.balanceText)
                            .font(.du(26, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    Button("Recharge") {
                        placeholderMessage = "Recharge is coming soon."
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
                            Text(item.title)
                                .font(.du(10, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))

                            Text(item.value)
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
                    placeholderMessage = "\(item.title) is coming soon."
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

                        Text(item.title)
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
                        placeholderMessage = "\(banner.title) is coming soon."
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: DUSpacing.sm) {
                                Text("✨ \(banner.title)")
                                    .font(.du(17, weight: .bold))
                                    .foregroundColor(.white)

                                Text(banner.subtitle)
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
            sectionHeader(title: "Popular Services")

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: DUSpacing.md), count: 4),
                spacing: DUSpacing.md
            ) {
                ForEach(services) { item in
                    Button {
                        placeholderMessage = "\(item.title) is coming soon."
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

                            Text(item.title)
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
            sectionHeader(title: "Trending Products")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DUSpacing.md) {
                    ForEach(products) { product in
                        Button {
                            placeholderMessage = "\(product.name) details are coming soon."
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
                                    Text(product.name)
                                        .font(.du(14, weight: .semibold))
                                        .foregroundColor(DUTheme.ink)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)

                                    HStack(spacing: DUSpacing.sm) {
                                        Text(product.price)
                                            .font(.du(15, weight: .bold))
                                            .foregroundColor(DUTheme.cyan)

                                        if let oldPrice = product.oldPrice {
                                            Text(oldPrice)
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

    private func sectionHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(.du(17, weight: .bold))
                .foregroundColor(DUTheme.ink)

            Spacer()

            Button("View all") {
                placeholderMessage = "\(title) is coming soon."
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
            "🏠"
        case .service:
            "📱"
        case .mall:
            "🛒"
        case .video:
            "🎬"
        case .me:
            "👤"
        }
    }

    var assetName: String {
        switch self {
        case .home:
            "TabHomeIcon"
        case .service:
            "TabServiceIcon"
        case .mall:
            "TabMallIcon"
        case .video:
            "TabVideoIcon"
        case .me:
            "TabMeIcon"
        }
    }

    var title: String {
        switch self {
        case .home:
            "Home"
        case .service:
            "Service"
        case .mall:
            "Mall"
        case .video:
            "Video"
        case .me:
            "Me"
        }
    }
}

private struct HomeItem: Identifiable {
    let id = UUID()
    let title: String
    let assetName: String
}

private struct HomeProduct: Identifiable {
    let id = UUID()
    let name: String
    let price: String
    let oldPrice: String?
    let assetName: String
}

private struct HomeBanner {
    let title: String
    let subtitle: String
    let colors: [Color]
}

private struct UsageItem: Identifiable {
    let id = UUID()
    let title: String
    let value: String
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
    let title: String
    let icon: String
    let message: String

    var body: some View {
        VStack(spacing: DUSpacing.lg) {
            Text(icon)
                .font(.du(48))

            Text(title)
                .font(.du(24, weight: .bold))
                .foregroundColor(DUTheme.ink)

            Text(message)
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
                greeting: "Good Morning",
                balanceText: "128.50 AED"
            ),
            sessionStore: SessionStore.previewAuthenticated,
            meService: MockMeService()
        )
    }
}
