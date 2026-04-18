import SwiftUI
import WebKit
#if canImport(UIKit)
import UIKit
#endif

final class HomeChromeState: ObservableObject {
    // 用页面标识追踪底部导航隐藏请求，避免 A 页面隐藏、B 页面继续隐藏时互相覆盖。
    @Published private var bottomTabBarHiddenKeys: Set<String> = []

    var isBottomTabBarHidden: Bool {
        !bottomTabBarHiddenKeys.isEmpty
    }

    func hideBottomTabBar(for key: String) {
        bottomTabBarHiddenKeys.insert(key)
    }

    func showBottomTabBar(for key: String) {
        bottomTabBarHiddenKeys.remove(key)
    }
}

struct HomeView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    @Environment(\.duTheme) private var theme

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
    @State private var isBadgeCenterPresented = false
    @State private var requestedVideoID: String?
    @State private var isSigningOut = false
    @State private var isCreditLimitExpanded = false
    @State private var signOutFailureMessageKey: String?
    @State private var isParallaxCarouselDraggingHorizontally = false
    @State private var tabBarBounceTarget: HomeTab?
    @State private var tabBarBounceToken = 0
    @StateObject private var chromeState = HomeChromeState()

    private let pageHorizontalPadding: CGFloat = DUSpacing.sm
    private let headerContentHorizontalPadding: CGFloat = DUSpacing.compact
    private let accountCardBottomSpacingScale: CGFloat = 0.85 * 0.7 * 0.85
    private let parallaxReelTopSpacingScale: CGFloat = 0.8
    private var homeDashboardSectionSpacing: CGFloat { DUSpacing.md * accountCardBottomSpacingScale }
    private var headerBottomPadding: CGFloat { 18 * accountCardBottomSpacingScale }
    private var parallaxReelTopSpacing: CGFloat { DUSpacing.md * parallaxReelTopSpacingScale }
    private var homePalette: HomePalette { HomePalette(theme: theme) }

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
                .environmentObject(chromeState)
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
                        notificationService: notificationService,
                        aiChatService: aiChatService,
                        onAIChatNavigation: handleAIChatNavigation(_:)
                    )
                }
                .fullScreenCover(isPresented: $isBillingPresented) {
                    BillingContainerView(
                        session: custSubInfo,
                        billingService: billingService,
                        aiChatService: aiChatService,
                        onAIChatNavigation: handleAIChatNavigation(_:)
                    )
                }
                .fullScreenCover(isPresented: $isRechargePresented) {
                    RechargeContainerView(
                        session: custSubInfo,
                        rechargeService: rechargeService,
                        aiChatService: aiChatService,
                        onAIChatNavigation: handleAIChatNavigation(_:)
                    )
                }
                .fullScreenCover(isPresented: $isOffersPresented) {
                    OffersContainerView(
                        session: custSubInfo,
                        offersService: offersService,
                        aiChatService: aiChatService,
                        onAIChatNavigation: handleAIChatNavigation(_:)
                    )
                }
                .fullScreenCover(isPresented: $isTicketsPresented) {
                    TicketsModalContainerView(
                        session: custSubInfo,
                        ticketsService: ticketsService,
                        aiChatService: aiChatService,
                        onAIChatNavigation: handleAIChatNavigation(_:)
                    )
                }
                .fullScreenCover(isPresented: $isWeatherPresented) {
                    WeatherMainView(
                        session: custSubInfo,
                        aiChatService: aiChatService,
                        onAIChatNavigation: handleAIChatNavigation(_:)
                    )
                }
                .fullScreenCover(isPresented: $isBadgeCenterPresented) {
                    BadgeCenterContainerView(
                        session: custSubInfo,
                        badgeCenterService: badgeCenterService,
                        aiChatService: aiChatService,
                        onAIChatNavigation: handleAIChatNavigation(_:)
                    )
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
                AIAssistantChatOverlay(
                    isPresented: $isAIChatPresented,
                    custSubInfo: custSubInfo,
                    language: languageStore.currentLanguage,
                    aiChatService: aiChatService,
                    offersService: offersService,
                    onNavigate: handleAIChatNavigation(_:)
                )
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !isAIChatPresented && !chromeState.isBottomTabBarHidden {
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
                mallService: mallService,
                onBackToAppHome: {
                    selectedTab = .home
                }
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
                aiChatService: aiChatService,
                meService: meService,
                showRechargeEntry: showsRechargeEntryInMe,
                isSigningOut: isSigningOut,
                onSignOut: {
                    startSignOut()
                },
                onAIChatNavigation: handleAIChatNavigation(_:)
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
                    VStack(spacing: homeDashboardSectionSpacing) {
                        header(
                            topInset: proxy.safeAreaInsets.top,
                            dashboard: dashboard
                        )

                        VStack(spacing: DUSpacing.md) {
                            if let bannerMessage = viewModel.bannerMessage {
                                inlineBanner(bannerMessage)
                            }

                            VStack(spacing: parallaxReelTopSpacing) {
                                quickActionsSection
                                parallaxReelSection
                            }
                            //featuredCarouselSection
                            //parallaxCarouselSection
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
                iconColor: homePalette.errorAccent,
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
                    .font(.du(.bodyStrong))
                    .foregroundColor(theme.colors.text.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(homePageBackground.ignoresSafeArea())
        }
    }

    private func header(
        topInset: CGFloat,
        dashboard: HomeDashboardSnapshot
    ) -> some View {
        VStack(spacing: DUSpacing.compact) {
            VStack(spacing: DUSpacing.compact) {
                HStack(alignment: .center) {
                    HStack(spacing: DUSpacing.smd) {
                        Image(systemName: "sun.max.fill")
                            .font(.du(.labelStrong))
                            .foregroundColor(homePalette.heroSunAccent)
                            .shadow(
                                color: homePalette.heroSunShadow,
                                radius: DUElevation.control.radius,
                                x: DUElevation.control.x,
                                y: DUElevation.control.y
                            )

                        Text(localized("home.greeting.morning"))
                            .font(.du(.label))
                            .foregroundColor(.white.opacity(0.86))
                    }

                    Spacer()

                    HStack(spacing: DUSpacing.base) {
                        HomeHeaderActionButton(assetName: "HomeSearchButtonIcon") {
                            placeholderMessage = .key("home.placeholder.search")
                        }
                        HomeHeaderActionButton(assetName: "HomeNotificationButtonIcon") {
                            isMessageCenterPresented = true
                        }
                    }
                }

                HStack(alignment: .center, spacing: DUSpacing.md) {
                    HStack(spacing: DUSpacing.md) {
                        Image("HomeHeroAvatar")
                            .renderingMode(.original)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 0) {
                            Text(dashboard.profile.displayName)
                                .font(.du(.bodyStrong))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            HStack(spacing: DUSpacing.smd) {
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
                            .font(.du(.caption))
                            .foregroundColor(.white.opacity(0.84))
                            .padding(.top, DUSpacing.xs + 1)

                            HStack(spacing: DUSpacing.sm) {
                                Text(dashboard.profile.serviceNumber)
                                    .font(.du(.tiny))
                                    .foregroundColor(.white.opacity(0.92))
                                    .padding(.horizontal, DUSpacing.sm - 1)
                                    .padding(.vertical, DUSpacing.xxs)
                                    .background(
                                        Capsule()
                                            .fill(.white.opacity(0.14))
                                    )

                                if let networkStatus = dashboard.profile.networkStatus {
                                    Text(localized(networkStatus.textValue))
                                        .font(.du(.tiny))
                                        .foregroundColor(.white.opacity(0.72))
                                        .lineLimit(1)
                                }
                            }
                            .padding(.top, DUSpacing.sm)
                        }
                    }

                    Spacer(minLength: 8)

                    Button {
                        isBadgeCenterPresented = true
                    } label: {
                        HStack(spacing: DUSpacing.smd) {
                            Image("HomeHeroBadgeIcon")
                                .renderingMode(.original)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)

                            Text(localized("home.profile.advanced"))
                                .font(.du(.micro))
                                .foregroundColor(.white.opacity(0.82))
                        }
                        .padding(.horizontal, DUSpacing.sm)
                        .padding(.vertical, DUSpacing.xs + 1)
                        .background(
                            Capsule()
                                .fill(.white.opacity(0.12))
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("home.badgeCenter.entry")
                }
            }
            .padding(.horizontal, headerContentHorizontalPadding)

            accountCard(
                summary: dashboard.summary,
                usage: dashboard.usage
            )
            .padding(.horizontal, pageHorizontalPadding)
        }
        .padding(.top, max(topInset, DUSpacing.sm) + DUSpacing.smd)
        .padding(.bottom, headerBottomPadding)
    }

    private func accountCard(
        summary: HomeSummarySection,
        usage: HomeUsageSection
    ) -> some View {
        let palette = homePalette

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: DUSpacing.base) {
                VStack(alignment: .leading, spacing: DUSpacing.xs) {
                    Text(localized("home.header.accountBalanceTitle"))
                        .font(.du(.metaStrong))
                        .foregroundColor(palette.accountTitle)

                    metricValueText(
                        summary.balanceValue,
                        amountStyle: .title,
                        amountColor: palette.balanceAmount,
                        currencyStyle: .metaStrong,
                        currencyColor: palette.balanceCurrency
                    )
                }

                Spacer()

                accountActionButton(for: summary)
            }

            if summary.showsPostpaidDetails || summary.creditLimit != nil {
                HStack(alignment: .top, spacing: DUSpacing.md) {
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
                                .fill(palette.heroChromeFill)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle()
                                        .stroke(palette.heroChromeBorder, lineWidth: 1)
                                )
                                .overlay(
                                    Image(systemName: "chevron.down")
                                        .font(.du(.tinyStrong))
                                        .foregroundColor(palette.heroChromeForeground)
                                        .rotationEffect(.degrees(isCreditLimitExpanded ? 180 : 0))
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(.top, DUSpacing.md)
                        .accessibilityLabel(localized("home.header.creditLimitTitle"))
                    }
                }
                .padding(.top, DUSpacing.base)
            }

            if let creditLimit = summary.creditLimit {
                creditLimitSection(
                    creditLimit,
                    palette: palette
                )
                    .padding(.top, isCreditLimitExpanded ? DUSpacing.base : 0)
                    .frame(maxHeight: isCreditLimitExpanded ? 120 : 0, alignment: .top)
                    .opacity(isCreditLimitExpanded ? 1 : 0)
                    .scaleEffect(y: isCreditLimitExpanded ? 1 : 0.92, anchor: .top)
                    .clipped()
                    .allowsHitTesting(isCreditLimitExpanded)
            }

            usageMetricsRow(usage.cards)
                .padding(.top, DUSpacing.md)
        }
        .padding(.top, DUSpacing.compact + 1)
        .padding(.horizontal, DUSpacing.compact)
        .padding(.bottom, DUSpacing.compact)
        .background(palette.accountCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DURadius.hero, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DURadius.hero, style: .continuous)
                .stroke(palette.accountCardBorder, lineWidth: 1)
        )
        .shadow(
            color: palette.accountCardShadow,
            radius: DUElevation.hero.radius,
            x: DUElevation.hero.x,
            y: DUElevation.hero.y
        )
        .animation(
            isCreditLimitExpanded
            ? homeCreditLimitExpandAnimation
            : homeCreditLimitCollapseAnimation,
            value: isCreditLimitExpanded
        )
    }

    private func creditLimitSection(
        _ creditLimit: HomeCreditLimitSection,
        palette: HomePalette
    ) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.sm) {
            Text(localized("home.header.creditLimitTitle"))
                .font(.du(.captionStrong))
                .foregroundColor(palette.sectionPrimaryText)

            HStack(spacing: DUSpacing.sm) {
                creditLimitCard(
                    titleKey: "home.header.creditTotalTitle",
                    value: creditLimit.totalValue,
                    backgroundColor: palette.creditLimitTotalBackground
                )
                creditLimitCard(
                    titleKey: "home.header.creditUsedTitle",
                    value: creditLimit.usedValue,
                    backgroundColor: palette.creditLimitUsedBackground
                )
                creditLimitCard(
                    titleKey: "home.header.creditRemainingTitle",
                    value: creditLimit.remainingValue,
                    backgroundColor: palette.creditLimitRemainingBackground
                )
            }
        }
    }

    private func billMeta(
        titleKey: String,
        value: LocalizedTextValue
    ) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.xs) {
            Text(localized(titleKey))
                .font(.du(.captionRegular))
                .foregroundColor(homePalette.sectionSecondaryText)

            Text(normalizedMetricValue(localized(value)))
                .font(.du(.metaStrong))
                .foregroundColor(homePalette.sectionPrimaryText)
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
        VStack(alignment: .leading, spacing: DUSpacing.xs + 1) {
            Text(localized(titleKey))
                .font(.du(.tinyRegular))
                .foregroundColor(homePalette.sectionSecondaryText)

            metricValueText(
                value,
                amountStyle: .captionEmphasized,
                amountColor: homePalette.sectionPrimaryText,
                currencyStyle: .captionStrong,
                currencyColor: homePalette.sectionPrimaryText
            )
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, DUSpacing.base)
        .padding(.vertical, DUSpacing.base - 1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: DURadius.sm, style: .continuous))
    }

    private func usageMetricsRow(_ cards: [HomeUsageCard]) -> some View {
        HStack(spacing: DUSpacing.md) {
            ForEach(cards) { card in
                usageMetric(card)
            }
        }
        .padding(.top, DUSpacing.md)
        .overlay(alignment: .top) {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            homePalette.cardDivider.opacity(0),
                            homePalette.cardDivider,
                            homePalette.cardDivider.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
                .padding(.horizontal, DUSpacing.xxs)
        }
    }

    private func usageMetric(_ card: HomeUsageCard) -> some View {
        let design = usageDesign(for: card.kind)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: DUSpacing.xs) {
                Image(systemName: design.systemName)
                    .font(.du(.labelStrong))
                    .foregroundColor(design.tintColor)

                Text(localized(card.title))
                    .font(.du(.caption))
                    .foregroundColor(homePalette.sectionSecondaryText)
            }

            usageValueText(
                card.value,
                primaryColor: homePalette.sectionPrimaryText,
                secondaryColor: homePalette.usageSecondaryText
            )
            .padding(.top, DUSpacing.xs + 1)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(homePalette.usageTrack)

                    Capsule()
                        .fill(design.tintColor)
                        .frame(width: proxy.size.width * min(max(card.progress, 0), 1))
                }
            }
            .frame(height: 4)
            .padding(.top, DUSpacing.smd)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func inlineMessageText(
        _ value: LocalizedTextValue
    ) -> some View {
        Text(localized(value))
            .font(.du(.caption))
            .foregroundColor(theme.colors.text.secondary)
    }

    private func inlineBanner(
        _ message: LocalizedTextValue
    ) -> some View {
        HStack(spacing: DUSpacing.sm) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.du(.labelStrong))
                .foregroundColor(homePalette.bannerIcon)

            Text(localized(message))
                .font(.du(.meta))
                .foregroundColor(homePalette.bannerText)

            Spacer()
        }
        .padding(.horizontal, DUSpacing.lg)
        .padding(.vertical, DUSpacing.md)
        .background(homePalette.bannerBackground)
        .clipShape(RoundedRectangle(cornerRadius: DURadius.control, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DURadius.control, style: .continuous)
                .stroke(homePalette.bannerBorder, lineWidth: 1)
        )
        .padding(.horizontal, pageHorizontalPadding)
    }

    private var quickActionsSection: some View {
        DUSectionCard(
            spacing: 0,
            horizontalPadding: DUSpacing.base,
            verticalPadding: DUSpacing.md
        ) {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: DUSpacing.xxs), count: 4),
                spacing: DUSpacing.xxs
            ) {
                ForEach(filteredQuickActions) { item in
                    HomeIconGridButton(
                        title: localized(item.title),
                        assetName: item.assetName,
                        iconSize: 48,
                        titleTextStyle: .captionStrong
                    ) {
                        handleAction(item)
                    }
                }
            }
        }
        .padding(.horizontal, pageHorizontalPadding)
    }

    private var parallaxReelSection: some View {
        HomeParallaxReelSectionView(items: featuredCarouselItems) { item in
            handleFeaturedCarouselSelection(item)
        }
    }

    private var servicesSection: some View {
        DUSectionCard(
            title: localized("home.section.popularServices"),
            trailingTitle: localized("home.section.viewAll"),
            spacing: DUSpacing.compact,
            horizontalPadding: DUSpacing.compact,
            verticalPadding: DUSpacing.lg,
            trailingAction: {
                selectedTab = .service
            }
        ) {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: DUSpacing.sm), count: 4),
                spacing: DUSpacing.sm
            ) {
                ForEach(services) { item in
                    HomeIconGridButton(
                        title: localized(item.title),
                        assetName: item.assetName,
                        iconSize: 46,
                        titleTextStyle: .tiny
                    ) {
                        handleAction(item)
                    }
                }
            }
        }
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
                    .fill(homePalette.tabBarFill)
                    .overlay(
                        barShape
                            .fill(theme.colors.gradient.homeTabBarBackground)
                    )
                    .overlay(
                        barShape
                            .stroke(homePalette.tabBarStroke, lineWidth: 1)
                    )
                    .overlay(
                        HomeOrbitingBorderEffect(
                            sideRadius: sideCornerRadius,
                            bumpRadius: bumpRadius,
                            bumpProtrusionHeight: bumpProtrusionHeight,
                            baseHeight: baseBarHeight
                        )
                    )
                    .shadow(
                        color: homePalette.tabBarShadow,
                        radius: DUElevation.spotlight.radius,
                        x: DUElevation.spotlight.x,
                        y: DUElevation.spotlight.y
                    )
                    .frame(width: barWidth, height: containerHeight)

                HStack(spacing: 0) {
                    HomeBottomTabBarButton(
                        title: localized(HomeTab.home.title),
                        inactiveAssetName: "HomeTabHomeDesignIcon",
                        activeAssetName: "HomeTabHomeActiveDesignIcon",
                        isActive: selectedTab == .home,
                        bounceToken: tabBarBounceTarget == .home ? tabBarBounceToken : 0
                    ) {
                        selectHomeTab(.home)
                    }
                    .frame(width: sideWidth, height: baseBarHeight)

                    HomeBottomTabBarButton(
                        title: localized(HomeTab.service.title),
                        inactiveAssetName: "HomeTabServiceDesignIcon",
                        activeAssetName: "HomeTabServiceActiveDesignIcon",
                        isActive: selectedTab == .service,
                        bounceToken: tabBarBounceTarget == .service ? tabBarBounceToken : 0
                    ) {
                        selectHomeTab(.service)
                    }
                    .frame(width: sideWidth, height: baseBarHeight)

                    Spacer(minLength: agentSlotWidth)

                    HomeBottomTabBarButton(
                        title: localized(HomeTab.video.title),
                        inactiveAssetName: "HomeTabVideoDesignIcon",
                        activeAssetName: "HomeTabVideoActiveDesignIcon",
                        isActive: selectedTab == .video,
                        bounceToken: tabBarBounceTarget == .video ? tabBarBounceToken : 0
                    ) {
                        selectHomeTab(.video)
                    }
                    .frame(width: sideWidth, height: baseBarHeight)

                    HomeBottomTabBarButton(
                        title: localized(HomeTab.me.title),
                        inactiveAssetName: "HomeTabMeDesignIcon",
                        activeAssetName: "HomeTabMeActiveDesignIcon",
                        isActive: selectedTab == .me,
                        bounceToken: tabBarBounceTarget == .me ? tabBarBounceToken : 0
                    ) {
                        selectHomeTab(.me)
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

    private func selectHomeTab(_ tab: HomeTab) {
        selectedTab = tab
        tabBarBounceTarget = tab
        tabBarBounceToken += 1
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
        DispatchQueue.main.async {
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
        amountStyle: DUTextStyle,
        amountColor: Color,
        currencyStyle: DUTextStyle,
        currencyColor: Color
    ) -> some View {
        let resolvedValue = normalizedMetricValue(localized(value))

        if let moneyParts = splitMoneyValue(resolvedValue) {
            HStack(alignment: .firstTextBaseline, spacing: DUSpacing.xs) {
                Text(moneyParts.amount)
                    .font(.du(amountStyle))
                    .foregroundColor(amountColor)

                Text(moneyParts.currency)
                    .font(.du(currencyStyle))
                    .foregroundColor(currencyColor)
            }
            .environment(\.layoutDirection, .leftToRight)
        } else {
            Text(resolvedValue)
                .font(.du(amountStyle))
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
                    .font(.du(.bodyEmphasized))
                    .foregroundColor(primaryColor)

                Text(usageParts.secondary)
                    .font(.du(.captionStrong))
                    .foregroundColor(secondaryColor)
            }
            .environment(\.layoutDirection, .leftToRight)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        } else {
            Text(resolvedValue)
                .font(.du(.bodyEmphasized))
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
            return .init(systemName: "waveform.path.ecg", tintColor: theme.colors.brand.secondary)
        case .voice:
            return .init(systemName: "phone.fill", tintColor: theme.colors.status.warning)
        case .sms:
            return .init(systemName: "envelope.fill", tintColor: theme.colors.status.success)
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

private struct HomePageBackground: View {
    @Environment(\.duTheme) private var theme

    var body: some View {
        let palette = HomePalette(theme: theme)

        GeometryReader { proxy in
            ZStack(alignment: .top) {
                palette.pageBase

                Image("HomeHeroBackground")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .saturation(1.04)
                    .contrast(1.12)
                    .overlay {
                        LinearGradient(
                            colors: [
                                palette.pageImageTintPrimary,
                                palette.pageImageTintSecondary,
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
                        palette.pageOverlayPrimary,
                        palette.pageOverlaySecondary,
                        palette.pageOverlayTertiary,
                        palette.pageBase.opacity(0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottom
                )
                .frame(height: max(500, proxy.size.height * 0.62))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                LinearGradient(
                    colors: [
                        Color.clear,
                        palette.pageFadeStart,
                        palette.pageFadeMid,
                        palette.pageFadeEnd
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
    @Environment(\.duTheme) private var theme

    let title: String
    let assetName: String
    let iconSize: CGFloat
    let titleTextStyle: DUTextStyle
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
                    .font(.du(titleTextStyle))
                    .foregroundColor(theme.colors.text.primary)
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
    @Environment(\.duTheme) private var theme

    let title: String
    let inactiveAssetName: String
    let activeAssetName: String
    let isActive: Bool
    let bounceToken: Int
    let action: () -> Void

    @State private var dropletScaleX: CGFloat = 1
    @State private var dropletScaleY: CGFloat = 1
    @State private var dropletOffsetY: CGFloat = 0
    @State private var innerRippleScale: CGFloat = 0.82
    @State private var innerRippleOpacity: CGFloat = 0
    @State private var outerRippleScale: CGFloat = 0.88
    @State private var outerRippleOpacity: CGFloat = 0

    var body: some View {
        let palette = HomePalette(theme: theme)
        let contentSize = CGSize(width: isActive ? 62 : 60, height: 40)

        Button(action: action) {
            ZStack {
                if isActive {
                    RoundedRectangle(cornerRadius: DURadius.card, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    palette.activeTabStart,
                                    palette.activeTabEnd
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: contentSize.width, height: contentSize.height)
                        .overlay {
                            ZStack {
                                Capsule()
                                    .stroke(Color.white.opacity(innerRippleOpacity), lineWidth: 1.6)
                                    .scaleEffect(innerRippleScale)

                                Capsule()
                                    .stroke(Color.white.opacity(outerRippleOpacity), lineWidth: 1.2)
                                    .scaleEffect(outerRippleScale)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: DURadius.card, style: .continuous))
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: DURadius.card, style: .continuous)
                                .stroke(palette.activeTabBorder, lineWidth: 1)
                        )
                        .shadow(
                            color: palette.activeTabShadow,
                            radius: DUElevation.lifted.radius,
                            x: DUElevation.lifted.x,
                            y: DUElevation.lifted.y
                        )
                        .scaleEffect(x: dropletScaleX, y: dropletScaleY, anchor: .center)
                        .offset(y: dropletOffsetY)
                }

                VStack(spacing: DUSpacing.xs) {
                    Image(isActive ? activeAssetName : inactiveAssetName)
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)

                    Text(title)
                        .font(.du(.tiny))
                        .foregroundColor(isActive ? palette.activeTabLabel : palette.inactiveTabLabel)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .frame(width: contentSize.width, height: contentSize.height)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .buttonStyle(.plain)
        .onChange(of: bounceToken) { _ in
            guard isActive else {
                return
            }
            playDropletBounce()
        }
    }

    private func playDropletBounce() {
        dropletScaleX = 1
        dropletScaleY = 1
        dropletOffsetY = 0
        innerRippleScale = 0.82
        innerRippleOpacity = 0
        outerRippleScale = 0.88
        outerRippleOpacity = 0

        withAnimation(.spring(response: 0.14, dampingFraction: 0.56)) {
            dropletScaleX = 1.23
            dropletScaleY = 0.79
            dropletOffsetY = -4
            innerRippleScale = 0.95
            innerRippleOpacity = 0.40
            outerRippleScale = 1.02
            outerRippleOpacity = 0.20
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.52)) {
                dropletScaleX = 0.93
                dropletScaleY = 1.14
                dropletOffsetY = 1.5
                innerRippleScale = 1.10
                innerRippleOpacity = 0.18
                outerRippleScale = 1.24
                outerRippleOpacity = 0.24
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeOut(duration: 0.18)) {
                innerRippleScale = 1.26
                innerRippleOpacity = 0
                outerRippleScale = 1.46
                outerRippleOpacity = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.76)) {
                dropletScaleX = 1
                dropletScaleY = 1
                dropletOffsetY = 0
            }
        }
    }
}

private struct HomeAIAgentTabButton: View {
    @Environment(\.duTheme) private var theme

    let title: String
    let labelBottomPadding: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    AIAssistantOrbitalIcon()
                        .scaleEffect(0.84)
                        .frame(width: 60, height: 60)

                    Spacer(minLength: 0)
                }

                Text(title)
                    .font(.du(.tiny))
                    .foregroundColor(HomePalette(theme: theme).inactiveTabLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .padding(.bottom, labelBottomPadding)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .buttonStyle(.plain)
    }
}

private struct HomePrimaryPillButtonStyle: ButtonStyle {
    @Environment(\.duTheme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        let palette = HomePalette(theme: theme)

        configuration.label
            .font(.du(.labelStrong))
            .foregroundColor(.white)
            .padding(.horizontal, DUSpacing.section)
            .frame(height: 40)
            .background(
                LinearGradient(
                    colors: [
                        palette.pillStart,
                        palette.pillEnd
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(palette.pillBorder, lineWidth: 1)
            )
            .shadow(
                color: palette.pillShadow.opacity(configuration.isPressed ? 0.22 : 0.38),
                radius: DUElevation.primaryButton.radius,
                x: DUElevation.primaryButton.x,
                y: DUElevation.primaryButton.y
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
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

private struct HomePalette {
    let theme: DUTheme

    private var isDark: Bool {
        theme.resolvedColorScheme == .dark
    }

    var pageBase: Color {
        isDark ? theme.colors.background.canvas : Color(hex: 0xEFF7FF)
    }

    var pageImageTintPrimary: Color {
        isDark ? theme.colors.brand.secondary.opacity(0.22) : Color(hex: 0x1032FF, opacity: 0.18)
    }

    var pageImageTintSecondary: Color {
        isDark ? theme.colors.brand.indigo.opacity(0.14) : Color(hex: 0x5E47FF, opacity: 0.10)
    }

    var pageOverlayPrimary: Color {
        isDark ? theme.colors.brand.secondary.opacity(0.24) : Color(hex: 0x173BFA, opacity: 0.24)
    }

    var pageOverlaySecondary: Color {
        isDark ? theme.colors.brand.indigo.opacity(0.16) : Color(hex: 0x2D4DF7, opacity: 0.14)
    }

    var pageOverlayTertiary: Color {
        isDark ? theme.colors.brand.magenta.opacity(0.10) : Color(hex: 0x7457F5, opacity: 0.10)
    }

    var pageFadeStart: Color {
        pageBase.opacity(isDark ? 0.12 : 0.10)
    }

    var pageFadeMid: Color {
        pageBase.opacity(isDark ? 0.84 : 0.72)
    }

    var pageFadeEnd: Color {
        pageBase
    }

    var errorAccent: Color {
        theme.colors.brand.magenta
    }

    var accountCardBackground: LinearGradient {
        LinearGradient(
            colors: isDark
                ? [
                    theme.colors.surface.raised,
                    theme.colors.surface.card
                ]
                : [
                    Color(red: 232 / 255, green: 236 / 255, blue: 255 / 255, opacity: 0.88),
                    Color.white.opacity(0.96)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var accountCardBorder: Color {
        isDark ? theme.colors.border.default.opacity(0.92) : Color.white.opacity(0.22)
    }

    var accountCardShadow: Color {
        isDark
            ? Color.black.opacity(0.32)
            : Color(red: 29 / 255, green: 46 / 255, blue: 122 / 255, opacity: 0.18)
    }

    var accountTitle: Color {
        isDark ? theme.colors.text.secondary : Color(hex: 0x4C5A75)
    }

    var balanceAmount: Color {
        isDark ? theme.colors.brand.primaryLight : Color(hex: 0x167DFF)
    }

    var balanceCurrency: Color {
        isDark ? theme.colors.text.tertiary : Color(hex: 0x6F7F99)
    }

    var sectionPrimaryText: Color {
        theme.colors.text.primary
    }

    var sectionSecondaryText: Color {
        theme.colors.text.secondary
    }

    var usageSecondaryText: Color {
        isDark ? theme.colors.text.tertiary : Color(hex: 0x74839E)
    }

    var usageTrack: Color {
        isDark ? theme.colors.border.default : Color(hex: 0xE0E7F1)
    }

    var cardDivider: Color {
        isDark ? theme.colors.border.default.opacity(0.82) : Color.white
    }

    var creditLimitTotalBackground: Color {
        isDark
            ? theme.colors.brand.primaryBackground
            : Color(red: 199 / 255, green: 219 / 255, blue: 255 / 255, opacity: 0.76)
    }

    var creditLimitUsedBackground: Color {
        isDark
            ? theme.colors.status.warningBackground
            : Color(red: 245 / 255, green: 214 / 255, blue: 224 / 255, opacity: 0.82)
    }

    var creditLimitRemainingBackground: Color {
        isDark
            ? theme.colors.status.successBackground
            : Color(red: 208 / 255, green: 236 / 255, blue: 229 / 255, opacity: 0.84)
    }

    var bannerBackground: Color {
        isDark ? theme.colors.surface.raised : theme.colors.surface.card
    }

    var bannerBorder: Color {
        theme.colors.border.subtle
    }

    var bannerText: Color {
        theme.colors.text.primary
    }

    var bannerIcon: Color {
        theme.colors.action.primary
    }

    var tabBarFill: Color {
        isDark ? theme.colors.surface.raised : theme.colors.surface.card
    }

    var tabBarStroke: Color {
        isDark ? theme.colors.border.default.opacity(0.78) : Color.white.opacity(0.60)
    }

    var tabBarShadow: Color {
        isDark ? Color.black.opacity(0.42) : Color.black.opacity(0.08)
    }

    var inactiveTabLabel: Color {
        theme.colors.text.secondary
    }

    var activeTabLabel: Color {
        .white
    }

    var activeTabStart: Color {
        isDark ? theme.colors.brand.primary : Color(hex: 0x1E9BFF)
    }

    var activeTabEnd: Color {
        isDark ? theme.colors.brand.secondary : Color(hex: 0x0E7BFF)
    }

    var activeTabBorder: Color {
        isDark ? theme.colors.border.default.opacity(0.44) : Color.white.opacity(0.30)
    }

    var activeTabShadow: Color {
        (isDark ? theme.colors.brand.secondary : Color(hex: 0x1176FF)).opacity(isDark ? 0.34 : 0.28)
    }

    var pillStart: Color {
        isDark ? theme.colors.brand.primary : Color(hex: 0x48A9FF)
    }

    var pillEnd: Color {
        isDark ? theme.colors.brand.secondary : Color(hex: 0x2B80FF)
    }

    var pillBorder: Color {
        isDark ? theme.colors.border.default.opacity(0.64) : Color.white.opacity(0.65)
    }

    var pillShadow: Color {
        isDark ? theme.colors.brand.secondary : Color(hex: 0x287FFF)
    }

    var heroChromeFill: Color {
        Color.white.opacity(isDark ? 0.16 : 0.18)
    }

    var heroChromeBorder: Color {
        Color.white.opacity(isDark ? 0.38 : 0.50)
    }

    var heroChromeForeground: Color {
        Color.white.opacity(0.92)
    }

    var heroSunAccent: Color {
        isDark ? theme.colors.status.warning : Color(hex: 0xFFD351)
    }

    var heroSunShadow: Color {
        heroSunAccent.opacity(isDark ? 0.26 : 0.34)
    }
}

private struct TicketsModalContainerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageStore: AppLanguageStore

    let session: CustSubInfo
    let ticketsService: any TicketsServicing
    let aiChatService: any AIChatServicing
    let onAIChatNavigation: (AIChatNavigationTarget) -> Void

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
        .businessAIAssistant(
            session: session,
            aiChatService: aiChatService,
            onNavigate: handleAIChatNavigation(_:)
        )
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
    @Environment(\.duTheme) private var theme

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
                .background(theme.colors.background.canvas.ignoresSafeArea())
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
            .background(theme.colors.background.canvas.ignoresSafeArea())
    }

    private var loadingOverlay: some View {
        VStack {
            ProgressView()
                .progressViewStyle(.circular)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.colors.background.canvas.opacity(0.92).ignoresSafeArea())
    }

    private func failureView(allowsBackHome: Bool) -> some View {
        DUStateView(
            systemImage: "wifi.exclamationmark",
            iconColor: theme.colors.brand.magenta,
            title: languageStore.string("tickets.state.errorTitle"),
            subtitle: languageStore.string("tickets.state.errorSubtitle"),
            actionTitle: languageStore.string("common.reload"),
            footer: allowsBackHome
                ? AnyView(
                    DUButton(
                        title: languageStore.string("tickets.action.backHome"),
                        style: .secondary,
                        height: 46,
                        textStyle: .bodyEmphasized,
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
        .background(theme.colors.background.canvas.ignoresSafeArea())
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
