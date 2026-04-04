import SwiftUI
import WebKit
#if canImport(UIKit)
import UIKit
#endif

struct HomeView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore

    let custSubInfo: CustSubInfo
    @ObservedObject var sessionStore: SessionStore
    let authService: any AuthServicing
    let aiChatService: any AIChatServicing
    let billingService: any BillingServicing
    let rechargeService: any RechargeServicing
    let ticketsService: any TicketsServicing
    let badgeCenterService: any BadgeCenterServicing
    let meService: any MeServicing
    let mallService: any MallServicing
    let videoService: any VideoServicing
    let offersService: any OffersServicing
    let notificationService: any NotificationServicing

    @StateObject private var viewModel: HomeViewModel
    @State private var placeholderMessage: LocalizedTextValue?
    @State private var selectedTab: HomeTab = .home
    @State private var isMessageCenterPresented = false
    @State private var isAIChatPresented = false
    @State private var isBillingPresented = false
    @State private var isRechargePresented = false
    @State private var isOffersPresented = false
    @State private var isTicketsPresented = false
    @State private var isWeatherPresented = false
    @State private var requestedVideoID: String?
    @State private var isSigningOut = false
    @State private var isCreditLimitExpanded = false
    @State private var signOutFailureMessageKey: String?
    @State private var isParallaxCarouselDraggingHorizontally = false

    private let pageHorizontalPadding: CGFloat = 8

    private let quickActions: [HomeItem] = [
        .init(title: .key("home.quick.recharge"), assetName: "HomeQuickRechargeDesignIcon", action: .recharge),
        .init(title: .key("home.quick.payBill"), assetName: "HomeQuickPayBillDesignIcon", action: .billing),
        .init(title: .key("home.quick.offers"), assetName: "HomeQuickOffersDesignIcon", action: .offers),
        .init(title: .key("home.quick.mall"), assetName: "HomeQuickMallDesignIcon", action: .mall),
    ]

    private let services: [HomeItem] = [
        .init(title: .key("home.service.dataPack"), assetName: "HomeServiceDataPackDesignIcon"),
        .init(title: .key("home.service.tickets"), assetName: "HomeServiceTicketsDesignIcon", action: .tickets),
        .init(title: .key("home.service.roaming"), assetName: "HomeServiceRoamingDesignIcon"),
        .init(title: .key("home.service.voicePack"), assetName: "HomeServiceVoicePackDesignIcon"),
    ]

    private let featuredCarouselItems: [HomeFeatureCarouselItem] = [
        .init(
            assetName: "HomeCarouselTelecomEco",
            title: .key("home.carousel.telecomEco")
        ),
        .init(
            assetName: "HomeCarouselWeather3D",
            title: .key("home.carousel.movie3D"),
            action: .tickets
        ),
        .init(
            assetName: "HomeCarouselWeatherForecast",
            title: .key("home.carousel.weatherForecast"),
            action: .weather
        ),
        .init(
            assetName: "HomeCarouselIPhone17",
            title: .key("home.carousel.iPhone17"),
            action: .mall
        ),
        .init(
            assetName: "HomeCarouselSpiderMovie",
            title: .key("home.carousel.spiderBrandNewDay"),
            action: .videoDetail("spiderman_2026")
        ),
    ]

    init(
        custSubInfo: CustSubInfo,
        sessionStore: SessionStore,
        authService: any AuthServicing,
        aiChatService: any AIChatServicing,
        homeService: any HomeServicing,
        mallService: any MallServicing,
        videoService: any VideoServicing,
        offersService: any OffersServicing,
        billingService: any BillingServicing,
        rechargeService: any RechargeServicing,
        ticketsService: any TicketsServicing,
        badgeCenterService: any BadgeCenterServicing,
        meService: any MeServicing,
        notificationService: any NotificationServicing
    ) {
        self.custSubInfo = custSubInfo
        self.sessionStore = sessionStore
        self.authService = authService
        self.aiChatService = aiChatService
        self.billingService = billingService
        self.rechargeService = rechargeService
        self.ticketsService = ticketsService
        self.badgeCenterService = badgeCenterService
        self.mallService = mallService
        self.videoService = videoService
        self.offersService = offersService
        self.meService = meService
        self.notificationService = notificationService
        _viewModel = StateObject(
            wrappedValue: HomeViewModel(
                session: custSubInfo,
                homeService: homeService,
                didResolveSubscriberKey: { subscriberKey in
                    sessionStore.updateSubscriberKey(subscriberKey)
                }
            )
        )
#if canImport(UIKit)
        UITabBar.appearance().isHidden = true
#endif
    }

    var body: some View {
        ZStack {
            tabScaffold
                .task {
                    await viewModel.loadIfNeeded()
                }
                .background(homePageBackground.ignoresSafeArea())
                .alert(isPresented: placeholderAlertIsPresented) {
                    Alert(
                        title: Text(localized("common.comingSoon.title")),
                        message: Text(localized(placeholderMessage)),
                        dismissButton: .default(Text(localized("common.ok"))) {
                            placeholderMessage = nil
                        }
                    )
                }
                .fullScreenCover(isPresented: $isMessageCenterPresented) {
                    MessageCenterView(
                        session: custSubInfo,
                        notificationService: notificationService
                    )
                }
                .fullScreenCover(isPresented: $isBillingPresented) {
                    BillingContainerView(session: custSubInfo, billingService: billingService)
                }
                .fullScreenCover(isPresented: $isRechargePresented) {
                    RechargeContainerView(session: custSubInfo, rechargeService: rechargeService)
                }
                .fullScreenCover(isPresented: $isOffersPresented) {
                    OffersContainerView(session: custSubInfo, offersService: offersService)
                }
                .fullScreenCover(isPresented: $isTicketsPresented) {
                    TicketsModalContainerView(ticketsService: ticketsService)
                }
                .fullScreenCover(isPresented: $isWeatherPresented) {
                    WeatherMainView()
                }
                .confirmationDialog(
                    localized("me.signOut.failure.title"),
                    isPresented: signOutFailureDialogPresented,
                    titleVisibility: .visible
                ) {
                    Button(localized("common.retry")) {
                        startSignOut()
                    }
                    Button(localized("me.signOut.failure.localOnly"), role: .destructive) {
                        sessionStore.signOut()
                    }
                    Button(localized("common.cancel"), role: .cancel) {
                        signOutFailureMessageKey = nil
                    }
                } message: {
                    Text(localized(signOutFailureMessageKey))
                }

            if isAIChatPresented {
                GeometryReader { proxy in
                    let topInset = max(proxy.safeAreaInsets.top + 14, 28)
                    let bottomSafeArea = proxy.safeAreaInsets.bottom
                    let sheetHeight = max(proxy.size.height - topInset + bottomSafeArea, 620)

                    ZStack(alignment: .bottom) {
                        Color.black.opacity(0.3)
                            .background(.ultraThinMaterial)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    isAIChatPresented = false
                                }
                            }

                        AIChatView(
                            custSubInfo: custSubInfo,
                            language: languageStore.currentLanguage,
                            aiChatService: aiChatService
                        ) { target in
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                isAIChatPresented = false
                            }
                            handleAIChatNavigation(target)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: sheetHeight)
                        .background(
                            ZStack {
                                LinearGradient(
                                    colors: [
                                        Color(hex: 0x0E5CB7),
                                        Color(hex: 0x780BAA)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )

                                Image("AIChatBottomWave")
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                                    .clipped()
                            }
                        )
                        .clipShape(TopRoundedRectangle(radius: 36))
                        .overlay(
                            TopRoundedRectangle(radius: 36)
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.45), .white.opacity(0.08), .white.opacity(0.25)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.5
                                )
                        )
                        .shadow(color: Color(hex: 0x1E3A8A).opacity(0.4), radius: 50, x: 0, y: -12)
                        .shadow(color: Color.black.opacity(0.25), radius: 20, x: 0, y: -5)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea(edges: .bottom)
                }
                .zIndex(100)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !isAIChatPresented {
                homeTabBar
            }
        }
        .background(homePageBackground.ignoresSafeArea())
    }

    @ViewBuilder
    private var tabScaffold: some View {
        if #available(iOS 16.0, *) {
            rootTabView
                .toolbar(.hidden, for: .tabBar)
        } else {
            rootTabView
        }
    }

    private var rootTabView: some View {
        TabView(selection: $selectedTab) {
            homeDashboard
                .tabItem {
                    Image(HomeTab.home.assetName)
                        .renderingMode(.original)
                    Text(localized(HomeTab.home.title))
                }
                .tag(HomeTab.home)

            DUFeaturePlaceholderView(
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

            MallContainerView(
                session: custSubInfo,
                mallService: mallService
            )
            .tabItem {
                Image(HomeTab.mall.assetName)
                    .renderingMode(.original)
                Text(localized(HomeTab.mall.title))
            }
            .tag(HomeTab.mall)

            VideoContainerView(
                session: custSubInfo,
                videoService: videoService,
                requestedVideoID: $requestedVideoID,
                isActive: selectedTab == .video
            )
            .tabItem {
                Image(HomeTab.video.assetName)
                    .renderingMode(.original)
                Text(localized(HomeTab.video.title))
            }
            .tag(HomeTab.video)

            MeContainerView(
                session: custSubInfo,
                billingService: billingService,
                rechargeService: rechargeService,
                badgeCenterService: badgeCenterService,
                meService: meService,
                showRechargeEntry: showsRechargeEntryInMe,
                isSigningOut: isSigningOut,
                onSignOut: {
                    startSignOut()
                }
            )
            .tabItem {
                Image(HomeTab.me.assetName)
                    .renderingMode(.original)
                Text(localized(HomeTab.me.title))
            }
            .tag(HomeTab.me)
        }
    }

    @ViewBuilder
    private var homeDashboard: some View {
        if let dashboard = viewModel.dashboard {
            GeometryReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        header(
                            topInset: proxy.safeAreaInsets.top,
                            dashboard: dashboard
                        )

                        VStack(spacing: 12) {
                            if let bannerMessage = viewModel.bannerMessage {
                                inlineBanner(bannerMessage)
                            }

                            quickActionsSection
                            featuredCarouselSection
                            parallaxCarouselSection
                            //servicesSection
                            Color.clear
                                .frame(height: homeDashboardBottomPlaceholderHeight)
                                .accessibilityHidden(true)
                        }
                    }
                    .padding(.bottom, DUSpacing.lg)
                }
                .homeScrollDisabled(isParallaxCarouselDraggingHorizontally)
                .refreshable {
                    await viewModel.refresh()
                }
                .ignoresSafeArea(edges: .top)
                .background(homePageBackground.ignoresSafeArea())
            }
        } else {
            homeLoadingState
        }
    }

    @ViewBuilder
    private var homeLoadingState: some View {
        switch viewModel.screenState {
        case let .failed(message):
            DUStateView(
                systemImage: "wifi.exclamationmark",
                iconColor: DUTheme.magenta,
                title: localized("home.state.errorTitle"),
                subtitle: localized(message),
                actionTitle: localized("common.reload"),
                footer: nil
            ) {
                Task {
                    await viewModel.reload()
                }
            }
            .background(homePageBackground.ignoresSafeArea())
        case .idle, .loading, .loaded:
            VStack(spacing: DUSpacing.lg) {
                ProgressView()
                    .progressViewStyle(.circular)
                Text(localized("home.state.loadingTitle"))
                    .font(homeFont(15, weight: .semibold))
                    .foregroundColor(DUTheme.inkSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(homePageBackground.ignoresSafeArea())
        }
    }

    private func header(
        topInset: CGFloat,
        dashboard: HomeDashboardSnapshot
    ) -> some View {
        VStack(spacing: 14) {
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Image(systemName: "sun.max.fill")
                        .font(homeFont(13, weight: .semibold))
                        .foregroundColor(Color(hex: 0xFFD351))
                        .shadow(color: Color(hex: 0xFFD351, opacity: 0.34), radius: 6)

                    Text(localized("home.greeting.morning"))
                        .font(homeFont(13, weight: .medium))
                        .foregroundColor(.white.opacity(0.86))
                }

                Spacer()

                HStack(spacing: 10) {
                    HomeHeaderActionButton(assetName: "HomeSearchButtonIcon") {
                        placeholderMessage = .key("home.placeholder.search")
                    }
                    HomeHeaderActionButton(assetName: "HomeNotificationButtonIcon") {
                        isMessageCenterPresented = true
                    }
                }
            }

            HStack(alignment: .center, spacing: 12) {
                HStack(spacing: 12) {
                    Image("HomeHeroAvatar")
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 0) {
                        Text(dashboard.profile.displayName)
                            .font(homeFont(15, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            if let packageName = localizedPackageName(for: dashboard.profile.packageName) {
                                Text(packageName)
                                    .lineLimit(1)
                            }

                            if localizedPackageName(for: dashboard.profile.packageName) != nil,
                               profilePointsText != nil {
                                Text("|")
                                    .opacity(0.62)
                            }

                            if let profilePointsText {
                                Text(profilePointsText)
                                    .lineLimit(1)
                            }
                        }
                        .font(homeFont(11, weight: .medium))
                        .foregroundColor(.white.opacity(0.84))
                        .padding(.top, 5)

                        HStack(spacing: 8) {
                            Text(dashboard.profile.serviceNumber)
                                .font(homeFont(10, weight: .medium))
                                .foregroundColor(.white.opacity(0.92))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(.white.opacity(0.14))
                                )

                            if let networkStatus = dashboard.profile.networkStatus {
                                Text(localized(networkStatus.textValue))
                                    .font(homeFont(10, weight: .medium))
                                    .foregroundColor(.white.opacity(0.72))
                                    .lineLimit(1)
                            }
                        }
                        .padding(.top, 8)
                    }
                }

                Spacer(minLength: 8)

                HStack(spacing: 6) {
                    Image("HomeHeroBadgeIcon")
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)

                    Text(localized("home.profile.advanced"))
                        .font(homeFont(9, weight: .medium))
                        .foregroundColor(.white.opacity(0.82))
                }
            }

            accountCard(
                summary: dashboard.summary,
                usage: dashboard.usage
            )
        }
        .padding(.horizontal, 14)
        .padding(.top, max(topInset, 8) + 6)
        .padding(.bottom, 18)
    }

    private func accountCard(
        summary: HomeSummarySection,
        usage: HomeUsageSection
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(localized("home.header.accountBalanceTitle"))
                        .font(homeFont(12, weight: .semibold))
                        .foregroundColor(Color(hex: 0x4C5A75))

                    metricValueText(
                        summary.balanceValue,
                        amountFontSize: 20,
                        amountWeight: .bold,
                        amountColor: Color(hex: 0x167DFF),
                        currencyFontSize: 12,
                        currencyWeight: .semibold,
                        currencyColor: Color(hex: 0x6F7F99)
                    )
                }

                Spacer()

                accountActionButton(for: summary)
            }

            if summary.showsPostpaidDetails || summary.creditLimit != nil {
                HStack(alignment: .top, spacing: 12) {
                    billMeta(
                        titleKey: "home.header.currentBillTitle",
                        value: summary.currentBillValue
                    )

                    billMeta(
                        titleKey: "home.header.dueDateTitle",
                        value: summary.dueDateValue
                    )

                    if summary.creditLimit != nil {
                        Button {
                            withAnimation(
                                isCreditLimitExpanded
                                ? homeCreditLimitCollapseAnimation
                                : homeCreditLimitExpandAnimation
                            ) {
                                isCreditLimitExpanded.toggle()
                            }
                        } label: {
                            Circle()
                                .fill(.white.opacity(0.18))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle()
                                        .stroke(.white.opacity(0.5), lineWidth: 1)
                                )
                                .overlay(
                                    Image(systemName: "chevron.down")
                                        .font(homeFont(10, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.92))
                                        .rotationEffect(.degrees(isCreditLimitExpanded ? 180 : 0))
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 12)
                        .accessibilityLabel(localized("home.header.creditLimitTitle"))
                    }
                }
                .padding(.top, 10)
            }

            if let creditLimit = summary.creditLimit {
                creditLimitSection(creditLimit)
                    .padding(.top, isCreditLimitExpanded ? 10 : 0)
                    .frame(maxHeight: isCreditLimitExpanded ? 120 : 0, alignment: .top)
                    .opacity(isCreditLimitExpanded ? 1 : 0)
                    .scaleEffect(y: isCreditLimitExpanded ? 1 : 0.92, anchor: .top)
                    .clipped()
                    .allowsHitTesting(isCreditLimitExpanded)
            }

            usageMetricsRow(usage.cards)
                .padding(.top, 12)
        }
        .padding(.top, 15)
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 232 / 255, green: 236 / 255, blue: 255 / 255, opacity: 0.88),
                    Color.white.opacity(0.96)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: Color(red: 29 / 255, green: 46 / 255, blue: 122 / 255, opacity: 0.18), radius: 15, x: 0, y: 10)
        .animation(
            isCreditLimitExpanded
            ? homeCreditLimitExpandAnimation
            : homeCreditLimitCollapseAnimation,
            value: isCreditLimitExpanded
        )
    }

    private func creditLimitSection(
        _ creditLimit: HomeCreditLimitSection
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localized("home.header.creditLimitTitle"))
                .font(homeFont(11, weight: .semibold))
                .foregroundColor(Color(hex: 0x50596D))

            HStack(spacing: 8) {
                creditLimitCard(
                    titleKey: "home.header.creditTotalTitle",
                    value: creditLimit.totalValue,
                    backgroundColor: Color(red: 199 / 255, green: 219 / 255, blue: 255 / 255, opacity: 0.76)
                )
                creditLimitCard(
                    titleKey: "home.header.creditUsedTitle",
                    value: creditLimit.usedValue,
                    backgroundColor: Color(red: 245 / 255, green: 214 / 255, blue: 224 / 255, opacity: 0.82)
                )
                creditLimitCard(
                    titleKey: "home.header.creditRemainingTitle",
                    value: creditLimit.remainingValue,
                    backgroundColor: Color(red: 208 / 255, green: 236 / 255, blue: 229 / 255, opacity: 0.84)
                )
            }
        }
    }

    private func billMeta(
        titleKey: String,
        value: LocalizedTextValue
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(localized(titleKey))
                .font(homeFont(11, weight: .regular))
                .foregroundColor(Color(hex: 0x7F89A3))

            Text(normalizedMetricValue(localized(value)))
                .font(homeFont(12, weight: .semibold))
                .foregroundColor(Color(hex: 0x414A5C))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func creditLimitCard(
        titleKey: String,
        value: LocalizedTextValue,
        backgroundColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(localized(titleKey))
                .font(homeFont(10, weight: .regular))
                .foregroundColor(Color(hex: 0x7D88A2))

            metricValueText(
                value,
                amountFontSize: 11,
                amountWeight: .bold,
                amountColor: Color(hex: 0x3F4857),
                currencyFontSize: 11,
                currencyWeight: .semibold,
                currencyColor: Color(hex: 0x3F4857)
            )
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func usageMetricsRow(_ cards: [HomeUsageCard]) -> some View {
        HStack(spacing: 12) {
            ForEach(cards) { card in
                usageMetric(card)
            }
        }
        .padding(.top, 12)
        .overlay(alignment: .top) {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0),
                            Color.white,
                            Color.white.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
                .padding(.horizontal, 2)
        }
    }

    private func usageMetric(_ card: HomeUsageCard) -> some View {
        let design = usageDesign(for: card.kind)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: design.systemName)
                    .font(homeFont(13, weight: .semibold))
                    .foregroundColor(design.tintColor)

                Text(localized(card.title))
                    .font(homeFont(11, weight: .medium))
                    .foregroundColor(Color(hex: 0x67748F))
            }

            usageValueText(
                card.value,
                primaryColor: Color(hex: 0x435065),
                secondaryColor: Color(hex: 0x74839E)
            )
            .padding(.top, 5)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(hex: 0xE0E7F1))

                    Capsule()
                        .fill(design.tintColor)
                        .frame(width: proxy.size.width * min(max(card.progress, 0), 1))
                }
            }
            .frame(height: 4)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func inlineMessageText(
        _ value: LocalizedTextValue
    ) -> some View {
        Text(localized(value))
            .font(homeFont(11, weight: .medium))
            .foregroundColor(Color(hex: 0x6E7B97))
    }

    private func inlineBanner(
        _ message: LocalizedTextValue
    ) -> some View {
        HStack(spacing: DUSpacing.sm) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(homeFont(13, weight: .semibold))
                .foregroundColor(Color(hex: 0x2B80FF))

            Text(localized(message))
                .font(homeFont(12, weight: .medium))
                .foregroundColor(Color(hex: 0x4A5568))

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(hex: 0xE8EEF4), lineWidth: 1)
        )
        .padding(.horizontal, pageHorizontalPadding)
    }

    private var quickActionsSection: some View {
        VStack {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 4),
                spacing: 2
            ) {
                ForEach(filteredQuickActions) { item in
                    HomeIconGridButton(
                        title: localized(item.title),
                        assetName: item.assetName,
                        iconSize: 48,
                        titleFontSize: 11,
                        titleWeight: .semibold
                    ) {
                        handleAction(item)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 8)
        .padding(.horizontal, pageHorizontalPadding)
    }

    private var featuredCarouselSection: some View {
        HomeFeatureCarouselView(items: featuredCarouselItems) { item in
            handleFeaturedCarouselSelection(item)
        }
            .padding(.horizontal, 12)
            .padding(.top, 16)
            .padding(.bottom, 14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 8)
            .padding(.horizontal, pageHorizontalPadding)
    }

    private var parallaxCarouselSection: some View {
        HomeParallaxCarouselView(
            items: featuredCarouselItems,
            onSelectItem: handleFeaturedCarouselSelection,
            isParentScrollLocked: $isParallaxCarouselDraggingHorizontally
        )
            .padding(.top, 6)
            .padding(.bottom, 10)
    }

    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(localized("home.section.popularServices"))
                    .font(homeFont(15, weight: .bold))
                    .foregroundColor(Color(hex: 0x485064))

                Spacer()

                Button {
                    selectedTab = .service
                } label: {
                    Text(localized("home.section.viewAll"))
                        .font(homeFont(11, weight: .semibold))
                        .foregroundColor(Color(hex: 0x549EFF))
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                spacing: 8
            ) {
                ForEach(services) { item in
                    HomeIconGridButton(
                        title: localized(item.title),
                        assetName: item.assetName,
                        iconSize: 46,
                        titleFontSize: 10,
                        titleWeight: .medium
                    ) {
                        handleAction(item)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 8)
        .padding(.horizontal, pageHorizontalPadding)
    }

    private var homeTabBar: some View {
        GeometryReader { proxy in
            let sideCornerRadius: CGFloat = 34
            let bumpRadius: CGFloat = 36
            let bumpProtrusionHeight: CGFloat = 21
            let baseBarHeight: CGFloat = sideCornerRadius * 2
            let containerHeight: CGFloat = baseBarHeight + bumpProtrusionHeight
            let contentHorizontalPadding: CGFloat = 16
            let barVerticalOffset: CGFloat = 14
            let barWidth = max(proxy.size.width - 20, 320)
            let agentSlotWidth: CGFloat = 104
            let sideWidth = max(
                ((barWidth - (contentHorizontalPadding * 2)) - agentSlotWidth) / 4,
                56
            )
            let barShape = HomeBottomTabBarShape(
                sideRadius: sideCornerRadius,
                bumpRadius: bumpRadius,
                bumpProtrusionHeight: bumpProtrusionHeight,
                baseHeight: baseBarHeight
            )

            ZStack(alignment: .bottom) {
                barShape
                    .fill(Color.white)
                    .overlay(
                        barShape
                            .fill(DUTheme.homeTabBarBackgroundGradient)
                    )
                    .overlay(
                        barShape
                            .stroke(Color.white.opacity(0.60), lineWidth: 1)
                    )
                    .overlay(
                        HomeOrbitingBorderEffect(
                            sideRadius: sideCornerRadius,
                            bumpRadius: bumpRadius,
                            bumpProtrusionHeight: bumpProtrusionHeight,
                            baseHeight: baseBarHeight
                        )
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 10)
                    .frame(width: barWidth, height: containerHeight)

                HStack(spacing: 0) {
                    HomeBottomTabBarButton(
                        title: localized(HomeTab.home.title),
                        inactiveAssetName: "HomeTabHomeDesignIcon",
                        activeAssetName: "HomeTabHomeActiveDesignIcon",
                        isActive: selectedTab == .home
                    ) {
                        selectedTab = .home
                    }
                    .frame(width: sideWidth, height: baseBarHeight)

                    HomeBottomTabBarButton(
                        title: localized(HomeTab.service.title),
                        inactiveAssetName: "HomeTabServiceDesignIcon",
                        activeAssetName: "HomeTabServiceActiveDesignIcon",
                        isActive: selectedTab == .service
                    ) {
                        selectedTab = .service
                    }
                    .frame(width: sideWidth, height: baseBarHeight)

                    Spacer(minLength: agentSlotWidth)

                    HomeBottomTabBarButton(
                        title: localized(HomeTab.video.title),
                        inactiveAssetName: "HomeTabVideoDesignIcon",
                        activeAssetName: "HomeTabVideoActiveDesignIcon",
                        isActive: selectedTab == .video
                    ) {
                        selectedTab = .video
                    }
                    .frame(width: sideWidth, height: baseBarHeight)

                    HomeBottomTabBarButton(
                        title: localized(HomeTab.me.title),
                        inactiveAssetName: "HomeTabMeDesignIcon",
                        activeAssetName: "HomeTabMeActiveDesignIcon",
                        isActive: selectedTab == .me
                    ) {
                        selectedTab = .me
                    }
                    .frame(width: sideWidth, height: baseBarHeight)
                }
                .padding(.horizontal, contentHorizontalPadding)
                .frame(width: barWidth, height: baseBarHeight)

                HomeAIAgentTabButton(
                    title: localized("home.tab.aiAgent"),
                    labelBottomPadding: (baseBarHeight - 40) / 2
                ) {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                        isAIChatPresented = true
                    }
                }
                .frame(width: agentSlotWidth, height: containerHeight, alignment: .bottom)
            }
            .offset(y: barVerticalOffset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: 112)
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

    private func localizedPackageName(
        for packageName: HomePackageName?
    ) -> String? {
        guard let packageName else {
            return nil
        }

        let resolved = packageName.localizedName(for: languageStore.currentLanguage)
        return resolved.isEmpty ? nil : resolved
    }

    private var profilePointsText: String? {
        let pointsValue = localized("me.value.points")
        guard !pointsValue.isEmpty else {
            return nil
        }

        return localized("home.profile.pointsLabel", arguments: [pointsValue])
    }

    private func showComingSoon(for title: LocalizedTextValue) {
        placeholderMessage = .key("common.placeholder.feature", arguments: [localized(title)])
    }

    @ViewBuilder
    private func accountActionButton(for summary: HomeSummarySection) -> some View {
        switch summary.paymentType {
        case .prepaid:
            Button(localized("home.header.recharge")) {
                isRechargePresented = true
            }
            .buttonStyle(HomePrimaryPillButtonStyle())
        case .postpaid, .hybrid, .unknown:
            Button(localized("home.header.payBill")) {
                isBillingPresented = true
            }
            .buttonStyle(HomePrimaryPillButtonStyle())
        }
    }

    private func handleAction(_ item: HomeItem) {
        switch item.action {
        case .placeholder:
            showComingSoon(for: item.title)
        case .mall:
            selectedTab = .mall
        case .billing:
            isBillingPresented = true
        case .recharge:
            isRechargePresented = true
        case .offers:
            isOffersPresented = true
        case .tickets:
            isTicketsPresented = true
        }
    }

    private func handleFeaturedCarouselSelection(_ item: HomeFeatureCarouselItem) {
        switch item.action {
        case .none:
            return
        case .tickets:
            isTicketsPresented = true
        case .mall:
            selectedTab = .mall
        case let .videoDetail(videoID):
            selectedTab = .video
            requestedVideoID = videoID
        case .weather:
            isWeatherPresented = true
        }
    }

    private func handleAIChatNavigation(_ target: AIChatNavigationTarget) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            switch target {
            case .home:
                selectedTab = .home
            case .service:
                selectedTab = .service
            case .mall:
                selectedTab = .mall
            case .offers:
                isOffersPresented = true
            case .billing:
                isBillingPresented = true
            case .recharge:
                isRechargePresented = true
            case .me:
                selectedTab = .me
            case .external:
                break
            }
        }
    }

    private var filteredQuickActions: [HomeItem] {
        guard let paymentType = viewModel.dashboard?.summary.paymentType else {
            return quickActions
        }

        switch paymentType {
        case .prepaid:
            return quickActions.filter { $0.action != .billing }
        case .postpaid:
            return quickActions.filter { $0.action != .recharge }
        case .hybrid, .unknown:
            return quickActions
        }
    }

    private var showsRechargeEntryInMe: Bool {
        guard let paymentType = viewModel.dashboard?.summary.paymentType else {
            return false
        }
        return paymentType != .postpaid
    }

    private func localized(_ key: String, arguments: [String] = []) -> String {
        languageStore.string(key, arguments: arguments)
    }

    private func localized(_ value: LocalizedTextValue?) -> String {
        languageStore.string(value)
    }

    @ViewBuilder
    private func metricValueText(
        _ value: LocalizedTextValue,
        amountFontSize: CGFloat,
        amountWeight: Font.Weight,
        amountColor: Color,
        currencyFontSize: CGFloat,
        currencyWeight: Font.Weight,
        currencyColor: Color
    ) -> some View {
        let resolvedValue = normalizedMetricValue(localized(value))

        if let moneyParts = splitMoneyValue(resolvedValue) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(moneyParts.amount)
                    .font(homeFont(amountFontSize, weight: amountWeight))
                    .foregroundColor(amountColor)

                Text(moneyParts.currency)
                    .font(homeFont(currencyFontSize, weight: currencyWeight))
                    .foregroundColor(currencyColor)
            }
            .environment(\.layoutDirection, .leftToRight)
        } else {
            Text(resolvedValue)
                .font(homeFont(amountFontSize, weight: amountWeight))
                .foregroundColor(amountColor)
        }
    }

    @ViewBuilder
    private func usageValueText(
        _ value: LocalizedTextValue,
        primaryColor: Color,
        secondaryColor: Color
    ) -> some View {
        let resolvedValue = normalizedMetricValue(localized(value))

        if let usageParts = splitUsageValue(resolvedValue) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(usageParts.primary)
                    .font(homeFont(15, weight: .bold))
                    .foregroundColor(primaryColor)

                Text(usageParts.secondary)
                    .font(homeFont(11, weight: .semibold))
                    .foregroundColor(secondaryColor)
            }
            .environment(\.layoutDirection, .leftToRight)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        } else {
            Text(resolvedValue)
                .font(homeFont(15, weight: .bold))
                .foregroundColor(primaryColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private func normalizedMetricValue(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\u{2066}", with: "")
            .replacingOccurrences(of: "\u{2069}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func splitMoneyValue(_ value: String) -> (amount: String, currency: String)? {
        let components = value.split(separator: " ")
        guard
            components.count >= 2,
            let lastComponent = components.last,
            lastComponent.allSatisfy({ $0.isLetter }),
            lastComponent.count <= 5
        else {
            return nil
        }

        let currency = String(lastComponent)
        let amount = components.dropLast().joined(separator: " ")
        guard !amount.isEmpty else {
            return nil
        }

        return (amount, currency)
    }

    private func splitUsageValue(_ value: String) -> (primary: String, secondary: String)? {
        let normalized = value
            .replacingOccurrences(of: " / ", with: "/")
            .replacingOccurrences(of: " /", with: "/")
            .replacingOccurrences(of: "/ ", with: "/")

        guard let slashIndex = normalized.firstIndex(of: "/") else {
            return nil
        }

        let primary = String(normalized[..<slashIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        var secondary = String(normalized[slashIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if !secondary.hasPrefix("/") {
            secondary = "/\(secondary)"
        }

        guard !primary.isEmpty, !secondary.isEmpty else {
            return nil
        }

        return (primary, secondary)
    }

    private func usageDesign(
        for kind: HomeUsageCard.Kind
    ) -> HomeUsageMetricDesign {
        switch kind {
        case .data:
            return .init(systemName: "waveform.path.ecg", tintColor: Color(hex: 0x177DFF))
        case .voice:
            return .init(systemName: "phone.fill", tintColor: Color(hex: 0xFF8B1A))
        case .sms:
            return .init(systemName: "envelope.fill", tintColor: Color(hex: 0x27B654))
        }
    }

    private func localized(_ key: String?) -> String {
        guard let key else {
            return ""
        }
        return languageStore.string(key)
    }

    private var signOutFailureDialogPresented: Binding<Bool> {
        Binding(
            get: { signOutFailureMessageKey != nil },
            set: { isPresented in
                if !isPresented {
                    signOutFailureMessageKey = nil
                }
            }
        )
    }

    private func startSignOut() {
        guard !isSigningOut else {
            return
        }

        signOutFailureMessageKey = nil
        isSigningOut = true

        Task {
            do {
                try await authService.logout(authType: sessionStore.currentAuthType)
                await MainActor.run {
                    isSigningOut = false
                    sessionStore.signOut()
                }
            } catch {
                await MainActor.run {
                    isSigningOut = false
                    let authError = (error as? AuthError) ?? .networkUnavailable
                    switch authError {
                    case .sessionInvalidated:
                        signOutFailureMessageKey = "me.signOut.failure.sessionInvalidated"
                    default:
                        signOutFailureMessageKey = "me.signOut.failure.remote"
                    }
                }
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func homeScrollDisabled(_ disabled: Bool) -> some View {
        if #available(iOS 16.0, *) {
            scrollDisabled(disabled)
        } else {
            self
        }
    }
}

private let homeCreditLimitExpandAnimation = Animation.easeOut(duration: 0.4)
private let homeCreditLimitCollapseAnimation = Animation.easeInOut(duration: 0.4)
private let homeDashboardBottomPlaceholderHeight: CGFloat = 48

private var homePageBackground: some View {
    HomePageBackground()
}

private func homeFont(
    _ size: CGFloat,
    weight: Font.Weight = .regular
) -> Font {
    .custom(homeFontName(for: weight), size: size)
}

private func homeFontName(for weight: Font.Weight) -> String {
    switch weight {
    case .bold, .semibold, .heavy, .black:
        return "PingFangSC-Semibold"
    case .medium:
        return "PingFangSC-Medium"
    case .light, .thin, .ultraLight:
        return "PingFangSC-Light"
    default:
        return "PingFangSC-Regular"
    }
}

private struct HomePageBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Color(hex: 0xEFF7FF)

                Image("HomeHeroBackground")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .saturation(1.04)
                    .contrast(1.12)
                    .overlay {
                        LinearGradient(
                            colors: [
                                Color(hex: 0x1032FF, opacity: 0.18),
                                Color(hex: 0x5E47FF, opacity: 0.10),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottom
                        )
                        .blendMode(.softLight)
                    }
                    .overlay {
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.16),
                                Color.clear,
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .blendMode(.screen)
                    }
                    .frame(width: proxy.size.width, alignment: .top)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                LinearGradient(
                    colors: [
                        Color(hex: 0x173BFA, opacity: 0.24),
                        Color(hex: 0x2D4DF7, opacity: 0.14),
                        Color(hex: 0x7457F5, opacity: 0.10),
                        Color(hex: 0xEFF7FF, opacity: 0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottom
                )
                .frame(height: max(500, proxy.size.height * 0.62))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                LinearGradient(
                    colors: [
                        Color.clear,
                        Color(hex: 0xEFF7FF, opacity: 0.10),
                        Color(hex: 0xEFF7FF, opacity: 0.72),
                        Color(hex: 0xEFF7FF)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }
}

private struct HomeHeaderActionButton: View {
    let assetName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(.white.opacity(0.18))
                .frame(width: 34, height: 34)
                .overlay(
                    Image(assetName)
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 17, height: 17)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct HomeIconGridButton: View {
    let title: String
    let assetName: String
    let iconSize: CGFloat
    let titleFontSize: CGFloat
    let titleWeight: Font.Weight
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: iconSize >= 48 ? 8 : 7) {
                Image(assetName)
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)

                Text(title)
                    .font(homeFont(titleFontSize, weight: titleWeight))
                    .foregroundColor(Color(hex: 0x4D5568))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

private struct HomeBottomTabBarButton: View {
    let title: String
    let inactiveAssetName: String
    let activeAssetName: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        let contentSize = CGSize(width: isActive ? 62 : 60, height: 40)

        Button(action: action) {
            ZStack {
                if isActive {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: 0x1E9BFF),
                                    Color(hex: 0x0E7BFF)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: contentSize.width, height: contentSize.height)
                        .shadow(color: Color(hex: 0x1176FF, opacity: 0.28), radius: 14, x: 0, y: 8)
                }

                VStack(spacing: 4) {
                    Image(isActive ? activeAssetName : inactiveAssetName)
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)

                    Text(title)
                        .font(homeFont(10, weight: .medium))
                        .foregroundColor(isActive ? .white : Color(hex: 0x7D8DB9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .frame(width: contentSize.width, height: contentSize.height)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .buttonStyle(.plain)
    }
}

private struct HomeAIAgentTabButton: View {
    let title: String
    let labelBottomPadding: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    HomeAIAgentOrbitalIcon()
                        .scaleEffect(0.84)
                        .frame(width: 60, height: 60)

                    Spacer(minLength: 0)
                }

                Text(title)
                    .font(homeFont(10, weight: .medium))
                    .foregroundColor(Color(hex: 0x7D8DB9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .padding(.bottom, labelBottomPadding)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .buttonStyle(.plain)
    }
}

private struct HomeAIAgentOrbitalIcon: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let colorRotation = Angle.degrees((time * 58).truncatingRemainder(dividingBy: 360))
            let whiteRotation = Angle.degrees((time * -72).truncatingRemainder(dividingBy: 360))

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: 0xAB7BFF, opacity: 0.28),
                                Color(hex: 0xAB7BFF, opacity: 0)
                            ],
                            center: .center,
                            startRadius: 6,
                            endRadius: 38
                        )
                    )
                    .frame(width: 72, height: 72)

                Circle()
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(
                                colors: [
                                    Color(hex: 0x2ED8FF),
                                    Color(hex: 0x7A72FF),
                                    Color(hex: 0xFF6FE5),
                                    Color(hex: 0xFFD05E),
                                    Color(hex: 0x2ED8FF)
                                ]
                            ),
                            center: .center
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(colorRotation)
                    .shadow(color: Color(hex: 0x7A72FF, opacity: 0.22), radius: 4)

                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.92), lineWidth: 2)
                        .frame(width: 44, height: 44)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                        .shadow(color: Color.white.opacity(0.75), radius: 10)
                        .offset(y: -22)
                        .rotationEffect(whiteRotation)
                }

                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    .white,
                                    Color(hex: 0x79DFFF),
                                    Color(hex: 0x5B9DFF),
                                    Color(hex: 0x7D65FF),
                                    Color(hex: 0xFF7BDF)
                                ],
                                center: .init(x: 0.35, y: 0.3),
                                startRadius: 2,
                                endRadius: 28
                            )
                        )
                        .frame(width: 54, height: 54)
                        .shadow(color: Color(hex: 0x6E68FF, opacity: 0.34), radius: 12, x: 0, y: 8)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    .white,
                                    Color(hex: 0xB9F0FF),
                                    Color(hex: 0x8DD2FF),
                                    Color(hex: 0xB874FF),
                                    Color(hex: 0xFF96E8)
                                ],
                                center: .init(x: 0.32, y: 0.28),
                                startRadius: 2,
                                endRadius: 20
                            )
                        )
                        .frame(width: 34, height: 34)

                    ForEach(0..<3, id: \.self) { index in
                        let phase = time * 2.2 + Double(index) * 0.75
                        Text("✦")
                            .font(homeFont(starSize(for: index), weight: .semibold))
                            .foregroundColor(.white)
                            .shadow(color: Color.white.opacity(0.85), radius: 12)
                            .opacity(0.35 + (0.65 * max(0, sin(phase))))
                            .scaleEffect(0.75 + (0.4 * max(0, sin(phase))))
                            .offset(starOffset(for: index))
                    }
                }
            }
        }
    }

    private func starSize(for index: Int) -> CGFloat {
        switch index {
        case 0:
            return 9
        case 1:
            return 11
        default:
            return 8
        }
    }

    private func starOffset(for index: Int) -> CGSize {
        switch index {
        case 0:
            return CGSize(width: -9, height: -13)
        case 1:
            return CGSize(width: 10, height: -5)
        default:
            return CGSize(width: -1, height: 13)
        }
    }
}

private struct HomePrimaryPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(homeFont(13, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .frame(height: 40)
            .background(
                LinearGradient(
                    colors: [
                        Color(hex: 0x48A9FF),
                        Color(hex: 0x2B80FF)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(.white.opacity(0.65), lineWidth: 1)
            )
            .shadow(color: Color(hex: 0x287FFF, opacity: configuration.isPressed ? 0.22 : 0.38), radius: 10, x: 0, y: 8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct TopRoundedRectangle: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + radius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct HomeBottomTabBarShape: Shape {
    let sideRadius: CGFloat
    let bumpRadius: CGFloat
    let bumpProtrusionHeight: CGFloat
    let baseHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        HomeBottomTabBarOutline(
            rect: rect,
            sideRadius: sideRadius,
            bumpRadius: bumpRadius,
            bumpProtrusionHeight: bumpProtrusionHeight,
            baseHeight: baseHeight
        ).path
    }
}

private struct HomeBottomTabBarOutline {
    let rect: CGRect
    let sideRadius: CGFloat
    let bumpRadius: CGFloat
    let bumpProtrusionHeight: CGFloat
    let baseHeight: CGFloat

    private var resolvedSideRadius: CGFloat {
        min(sideRadius, baseHeight / 2, rect.width / 4)
    }

    private var resolvedBumpRadius: CGFloat {
        min(bumpRadius, rect.width / 5, rect.height / 2)
    }

    private var topY: CGFloat {
        rect.maxY - baseHeight
    }

    private var leftCapCenter: CGPoint {
        CGPoint(x: rect.minX + resolvedSideRadius, y: topY + resolvedSideRadius)
    }

    private var rightCapCenter: CGPoint {
        CGPoint(x: rect.maxX - resolvedSideRadius, y: topY + resolvedSideRadius)
    }

    private var bumpCenter: CGPoint {
        CGPoint(x: rect.midX, y: resolvedBumpRadius)
    }

    private var bumpChordHalfWidth: CGFloat {
        let verticalOffset = max(0, bumpCenter.y - topY)
        return sqrt(max(0, (resolvedBumpRadius * resolvedBumpRadius) - (verticalOffset * verticalOffset)))
    }

    private var bumpLeftPoint: CGPoint {
        CGPoint(x: rect.midX - bumpChordHalfWidth, y: topY)
    }

    private var bumpRightPoint: CGPoint {
        CGPoint(x: rect.midX + bumpChordHalfWidth, y: topY)
    }

    private var bumpStartAngle: CGFloat {
        atan2(bumpLeftPoint.y - bumpCenter.y, bumpLeftPoint.x - bumpCenter.x)
    }

    private var bumpEndAngle: CGFloat {
        atan2(bumpRightPoint.y - bumpCenter.y, bumpRightPoint.x - bumpCenter.x)
    }

    private var topLeftLineLength: CGFloat {
        max(0, bumpLeftPoint.x - (rect.minX + resolvedSideRadius))
    }

    private var topRightLineLength: CGFloat {
        max(0, (rect.maxX - resolvedSideRadius) - bumpRightPoint.x)
    }

    private var bottomLineLength: CGFloat {
        max(0, rect.width - (resolvedSideRadius * 2))
    }

    private var sideArcLength: CGFloat {
        .pi * resolvedSideRadius
    }

    private var bumpArcLength: CGFloat {
        resolvedBumpRadius * (bumpEndAngle - bumpStartAngle)
    }

    private var totalLength: CGFloat {
        topLeftLineLength + topRightLineLength + bottomLineLength + (sideArcLength * 2) + bumpArcLength
    }

    var path: Path {
        let sideRadius = resolvedSideRadius
        let leftTop = CGPoint(x: rect.minX + sideRadius, y: topY)
        let rightTop = CGPoint(x: rect.maxX - sideRadius, y: topY)
        let leftBottom = CGPoint(x: rect.minX + sideRadius, y: rect.maxY)

        var path = Path()
        path.move(to: leftTop)
        path.addLine(to: bumpLeftPoint)
        path.addArc(
            center: bumpCenter,
            radius: resolvedBumpRadius,
            startAngle: .radians(Double(bumpStartAngle)),
            endAngle: .radians(Double(bumpEndAngle)),
            clockwise: false
        )
        path.addLine(to: rightTop)
        path.addArc(
            center: rightCapCenter,
            radius: sideRadius,
            startAngle: .degrees(-90),
            endAngle: .degrees(90),
            clockwise: false
        )
        path.addLine(to: leftBottom)
        path.addArc(
            center: leftCapCenter,
            radius: sideRadius,
            startAngle: .degrees(90),
            endAngle: .degrees(-90),
            clockwise: false
        )
        path.closeSubpath()

        return path
    }

    func point(at progress: Double) -> CGPoint {
        guard totalLength > 0 else {
            return CGPoint(x: rect.midX, y: rect.midY)
        }

        let normalizedProgress = progress - floor(progress)
        var remaining = CGFloat(normalizedProgress) * totalLength

        if remaining <= topLeftLineLength {
            return CGPoint(x: rect.minX + resolvedSideRadius + remaining, y: topY)
        }
        remaining -= topLeftLineLength

        if remaining <= bumpArcLength {
            let angle = bumpStartAngle + (remaining / resolvedBumpRadius)
            return CGPoint(
                x: bumpCenter.x + (cos(angle) * resolvedBumpRadius),
                y: bumpCenter.y + (sin(angle) * resolvedBumpRadius)
            )
        }
        remaining -= bumpArcLength

        if remaining <= topRightLineLength {
            return CGPoint(x: bumpRightPoint.x + remaining, y: topY)
        }
        remaining -= topRightLineLength

        if remaining <= sideArcLength {
            let angle = (-.pi / 2) + (remaining / resolvedSideRadius)
            return CGPoint(
                x: rightCapCenter.x + (cos(angle) * resolvedSideRadius),
                y: rightCapCenter.y + (sin(angle) * resolvedSideRadius)
            )
        }
        remaining -= sideArcLength

        if remaining <= bottomLineLength {
            return CGPoint(x: rect.maxX - resolvedSideRadius - remaining, y: rect.maxY)
        }
        remaining -= bottomLineLength

        let angle = (.pi / 2) + (remaining / resolvedSideRadius)
        return CGPoint(
            x: leftCapCenter.x + (cos(angle) * resolvedSideRadius),
            y: leftCapCenter.y + (sin(angle) * resolvedSideRadius)
        )
    }
}

private struct HomeOrbitingBorderEffect: View {
    let sideRadius: CGFloat
    let bumpRadius: CGFloat
    let bumpProtrusionHeight: CGFloat
    let baseHeight: CGFloat

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                let progress = (time * 0.072).truncatingRemainder(dividingBy: 1)
                let rect = CGRect(origin: .zero, size: proxy.size).insetBy(dx: 1, dy: 1)
                let outline = HomeBottomTabBarOutline(
                    rect: rect,
                    sideRadius: sideRadius,
                    bumpRadius: bumpRadius,
                    bumpProtrusionHeight: bumpProtrusionHeight,
                    baseHeight: baseHeight
                )

                Canvas { graphicsContext, _ in
                    let trailSegments = 20
                    let trailStep = 0.009

                    for index in 0..<trailSegments {
                        let start = outline.point(at: progress - (Double(index) * trailStep))
                        let end = outline.point(at: progress - (Double(index + 1) * trailStep))
                        let lineWidth = max(0.35, 3.2 - (CGFloat(index) * 0.15))
                        let opacity = max(0.04, 0.50 - (Double(index) * 0.022))

                        var segment = Path()
                        segment.move(to: start)
                        segment.addLine(to: end)

                        graphicsContext.stroke(
                            segment,
                            with: .color(.white.opacity(opacity)),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                        )
                    }

                    let headPoint = outline.point(at: progress)
                    let glowRect = CGRect(x: headPoint.x - 4, y: headPoint.y - 4, width: 8, height: 8)
                    let dotRect = CGRect(x: headPoint.x - 2.8, y: headPoint.y - 2.8, width: 5.6, height: 5.6)

                    graphicsContext.fill(
                        Path(ellipseIn: glowRect),
                        with: .color(.white.opacity(0.26))
                    )
                    graphicsContext.fill(
                        Path(ellipseIn: dotRect),
                        with: .color(.white)
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct HomeUsageMetricDesign {
    let systemName: String
    let tintColor: Color
}

private struct TicketsModalContainerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageStore: AppLanguageStore

    let ticketsService: any TicketsServicing

    var body: some View {
        NavigationView {
            TicketsContainerView(ticketsService: ticketsService)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(languageStore.string("common.cancel")) {
                            dismiss()
                        }
                    }
                }
        }
        .navigationViewStyle(.stack)
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
            return "H"
        case .service:
            return "S"
        case .mall:
            return "M"
        case .video:
            return "V"
        case .me:
            return "ME"
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
    enum Action {
        case placeholder
        case mall
        case billing
        case recharge
        case offers
        case tickets
    }

    let id = UUID()
    let title: LocalizedTextValue
    let assetName: String
    let action: Action

    init(title: LocalizedTextValue, assetName: String, action: Action = .placeholder) {
        self.title = title
        self.assetName = assetName
        self.action = action
    }
}

private struct TicketsContainerView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    @Environment(\.dismiss) private var dismiss

    let ticketsService: any TicketsServicing

    @StateObject private var viewModel: TicketsViewModel

    init(ticketsService: any TicketsServicing) {
        self.ticketsService = ticketsService
        _viewModel = StateObject(
            wrappedValue: TicketsViewModel(ticketsService: ticketsService)
        )
    }

    var body: some View {
        Group {
            switch viewModel.phase {
            case .idle, .resolvingConfig:
                loadingView
            case let .browsing(load):
                ZStack {
                    TicketsWebView(
                        load: load,
                        onFirstContentVisible: { loadID in
                            viewModel.markContentVisible(for: loadID)
                        },
                        onLoadFailed: { loadID in
                            viewModel.markLoadFailed(for: loadID)
                        }
                    )

                    if !viewModel.isCurrentLoadVisible {
                        loadingOverlay
                    }
                }
                .background(DUTheme.background.ignoresSafeArea())
            case let .failed(allowsBackHome):
                failureView(allowsBackHome: allowsBackHome)
            }
        }
        .navigationTitle(languageStore.string("home.service.tickets"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    private var loadingView: some View {
        loadingOverlay
            .background(DUTheme.background.ignoresSafeArea())
    }

    private var loadingOverlay: some View {
        VStack {
            ProgressView()
                .progressViewStyle(.circular)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DUTheme.background.opacity(0.92).ignoresSafeArea())
    }

    private func failureView(allowsBackHome: Bool) -> some View {
        DUStateView(
            systemImage: "wifi.exclamationmark",
            iconColor: DUTheme.magenta,
            title: languageStore.string("tickets.state.errorTitle"),
            subtitle: languageStore.string("tickets.state.errorSubtitle"),
            actionTitle: languageStore.string("common.reload"),
            footer: allowsBackHome
                ? AnyView(
                    DUButton(
                        title: languageStore.string("tickets.action.backHome"),
                        style: .secondary,
                        height: 46,
                        fontSize: 15,
                        horizontalPadding: DUSpacing.xxl
                    ) {
                        dismiss()
                    }
                  )
                : nil
        ) {
            Task {
                await viewModel.reload()
            }
        }
        .background(DUTheme.background.ignoresSafeArea())
    }
}

@MainActor
private final class TicketsViewModel: ObservableObject {
    enum Phase {
        case idle
        case resolvingConfig
        case browsing(TicketsPageLoad)
        case failed(allowsBackHome: Bool)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var isCurrentLoadVisible = false

    private let ticketsService: any TicketsServicing
    private var hasLoaded = false
    private var currentLoadID: UUID?
    private var webFailureCount = 0

    init(ticketsService: any TicketsServicing) {
        self.ticketsService = ticketsService
    }

    func loadIfNeeded() async {
        guard !hasLoaded else {
            return
        }

        await reload()
    }

    func reload() async {
        phase = .resolvingConfig
        isCurrentLoadVisible = false

        do {
            let url = try await ticketsService.fetchTicketURL()
            let load = TicketsPageLoad(url: url)
            currentLoadID = load.id
            hasLoaded = true
            phase = .browsing(load)
        } catch {
            phase = .failed(allowsBackHome: webFailureCount >= 3)
        }
    }

    func markContentVisible(for loadID: UUID) {
        guard currentLoadID == loadID else {
            return
        }

        isCurrentLoadVisible = true
        webFailureCount = 0
    }

    func markLoadFailed(for loadID: UUID) {
        guard currentLoadID == loadID else {
            return
        }

        isCurrentLoadVisible = false
        webFailureCount += 1
        phase = .failed(allowsBackHome: webFailureCount >= 3)
    }
}

private struct TicketsPageLoad: Equatable {
    let id = UUID()
    let url: URL
}

private struct TicketsWebView: UIViewRepresentable {
    let load: TicketsPageLoad
    let onFirstContentVisible: @MainActor @Sendable (UUID) -> Void
    let onLoadFailed: @MainActor @Sendable (UUID) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onFirstContentVisible: onFirstContentVisible,
            onLoadFailed: onLoadFailed
        )
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.pageZoom = 1.0
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        context.coordinator.startLoad(load, in: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.startLoad(load, in: webView)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let onFirstContentVisible: @MainActor @Sendable (UUID) -> Void
        private let onLoadFailed: @MainActor @Sendable (UUID) -> Void

        private var currentLoadID: UUID?
        private var timeoutWorkItem: DispatchWorkItem?
        private var hasResolvedAttempt = false

        init(
            onFirstContentVisible: @escaping @MainActor @Sendable (UUID) -> Void,
            onLoadFailed: @escaping @MainActor @Sendable (UUID) -> Void
        ) {
            self.onFirstContentVisible = onFirstContentVisible
            self.onLoadFailed = onLoadFailed
        }

        deinit {
            timeoutWorkItem?.cancel()
        }

        func startLoad(_ load: TicketsPageLoad, in webView: WKWebView) {
            guard currentLoadID != load.id else {
                return
            }

            currentLoadID = load.id
            hasResolvedAttempt = false
            timeoutWorkItem?.cancel()

            let request = URLRequest(
                url: load.url,
                cachePolicy: .useProtocolCachePolicy,
                timeoutInterval: 30
            )
            webView.load(request)

            let workItem = DispatchWorkItem { [weak self, weak webView] in
                guard let self, self.currentLoadID == load.id, !self.hasResolvedAttempt else {
                    return
                }

                webView?.stopLoading()
                self.resolveFailure(for: load.id)
            }

            timeoutWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: workItem)
        }

        func webView(
            _ webView: WKWebView,
            didCommit navigation: WKNavigation!
        ) {
            guard let currentLoadID, !hasResolvedAttempt else {
                return
            }

            hasResolvedAttempt = true
            timeoutWorkItem?.cancel()

            Task { @MainActor in
                onFirstContentVisible(currentLoadID)
            }
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            guard shouldReportFailure(for: error) else {
                return
            }

            resolveFailure(for: currentLoadID)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            guard shouldReportFailure(for: error) else {
                return
            }

            resolveFailure(for: currentLoadID)
        }

        private func shouldReportFailure(for error: Error) -> Bool {
            guard !hasResolvedAttempt else {
                return false
            }

            let nsError = error as NSError
            return nsError.code != NSURLErrorCancelled
        }

        private func resolveFailure(for loadID: UUID?) {
            guard let loadID, currentLoadID == loadID, !hasResolvedAttempt else {
                return
            }

            hasResolvedAttempt = true
            timeoutWorkItem?.cancel()

            Task { @MainActor in
                onLoadFailed(loadID)
            }
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(
            custSubInfo: CustSubInfo(
                displayName: "Ahmed Mohammed",
                phoneNumber: AuthValidator.demoPhone,
                greeting: "Good Morning",
                balanceText: "128.50 AED",
                userID: "preview-user",
                serviceNumber: AuthValidator.demoPhone,
                subscriberKey: "preview-subscriber-key"
            ),
            sessionStore: SessionStore.previewAuthenticated,
            authService: MockAuthService(),
            aiChatService: MockAIChatService(),
            homeService: MockHomeService(),
            mallService: MockMallService(),
            videoService: MockVideoService(),
            offersService: MockOffersService(),
            billingService: MockBillingService(),
            rechargeService: MockRechargeService(),
            ticketsService: MockTicketsService(),
            badgeCenterService: MockBadgeCenterService(),
            meService: MockMeService(),
            notificationService: MockNotificationService()
        )
        .environmentObject(AppLanguageStore(initialLanguage: .english))
    }
}
