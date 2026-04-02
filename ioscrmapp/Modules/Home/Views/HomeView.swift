import SwiftUI
import WebKit

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
    @State private var isSigningOut = false
    @State private var signOutFailureMessageKey: String?

    private let pageHorizontalPadding: CGFloat = DUSpacing.md
    private let quickActions: [HomeItem] = [
        .init(title: .key("home.quick.recharge"), assetName: "QuickRechargeIcon", action: .recharge),
        .init(title: .key("home.quick.payBill"), assetName: "ServiceBillsIcon", action: .billing),
        .init(title: .key("home.quick.offers"), assetName: "QuickOffersIcon", action: .offers),
        .init(title: .key("home.quick.mall"), assetName: "QuickMallIcon", action: .mall),
    ]

    private let services: [HomeItem] = [
        .init(title: .key("home.service.dataPack"), assetName: "ServiceDataPackIcon"),
        .init(title: .key("home.service.voicePack"), assetName: "ServiceVoicePackIcon"),
        .init(title: .key("home.service.roaming"), assetName: "ServiceRoamingIcon"),
        .init(title: .key("home.service.tickets"), assetName: "ServiceTicketsIcon", action: .tickets),
        .init(title: .key("home.service.bills"), assetName: "ServiceBillsIcon", action: .billing),
        .init(title: .key("home.service.points"), assetName: "ServicePointsIcon"),
        .init(title: .key("home.service.mail"), assetName: "ServiceMailIcon"),
        .init(title: .key("home.service.support"), assetName: "ServiceSupportIcon"),
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
        ),
    ]

    private let featuredCarouselAssetNames: [String] = [
        "HomeCarouselGreenHills",
        "HomeCarouselGoldenValley",
        "HomeCarouselSnowMountains",
        "HomeCarouselCliffDawn",
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
    }

    var body: some View {
        ZStack {
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
                videoService: videoService
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
        .task {
            await viewModel.loadIfNeeded()
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

            // Custom AI Assistant Premium Floating Card Popup
            if isAIChatPresented {
                GeometryReader { proxy in
                    let availableWidth = max(proxy.size.width - 32, 240)
                    let availableHeight = max(proxy.size.height - 48, 320)
                    let cardWidth = min(availableWidth, 380)
                    let preferredHeight = min(availableHeight * 0.9, 620)
                    let cardHeight = min(max(preferredHeight, 420), availableHeight)

                    ZStack(alignment: .center) {
                        // Extreme deep blur background for premium feel
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
                        .frame(
                            width: cardWidth,
                            height: cardHeight
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 36, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                        )
                        .shadow(color: DUTheme.magenta.opacity(0.2), radius: 40, x: 0, y: 20)
                        .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 10)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .zIndex(100)
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        } // End of ZStack body
    }

    @ViewBuilder
    private var homeDashboard: some View {
        if let dashboard = viewModel.dashboard {
            GeometryReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: DUSpacing.md) {
                        header(
                            topInset: proxy.safeAreaInsets.top,
                            dashboard: dashboard
                        )

                        if let bannerMessage = viewModel.bannerMessage {
                            inlineBanner(bannerMessage)
                        }

                        quickActionsSection
                        featuredCarouselSection
                        servicesSection
                        productsSection
                    }
                    .padding(.bottom, DUSpacing.xl)
                }
                .refreshable {
                    await viewModel.refresh()
                }
                .ignoresSafeArea(edges: .top)
                .background(DUTheme.background.ignoresSafeArea())
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
            .background(DUTheme.background.ignoresSafeArea())
        case .idle, .loading, .loaded:
            VStack(spacing: DUSpacing.lg) {
                ProgressView()
                    .progressViewStyle(.circular)
                Text(localized("home.state.loadingTitle"))
                    .font(.du(15, weight: .semibold))
                    .foregroundColor(DUTheme.inkSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DUTheme.background.ignoresSafeArea())
        }
    }

    private func header(
        topInset: CGFloat,
        dashboard: HomeDashboardSnapshot
    ) -> some View {
        VStack(spacing: DUSpacing.lg) {
            HStack(alignment: .top) {
                HStack(spacing: DUSpacing.md) {
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.white)
                        )

                    VStack(alignment: .leading, spacing: DUSpacing.xs) {
                        Text(localized("home.greeting.morning"))
                            .font(.du(11, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))

                        Text(dashboard.profile.displayName)
                            .font(.du(18, weight: .bold))
                            .foregroundColor(.white)

                        if let packageName = localizedPackageName(for: dashboard.profile.packageName) {
                            Text(packageName)
                                .font(.du(12, weight: .medium))
                                .foregroundColor(.white.opacity(0.92))
                        }

                        Text(profileMetadata(for: dashboard.profile))
                            .font(.du(11, weight: .medium))
                            .foregroundColor(.white.opacity(0.78))
                    }
                }

                Spacer()

                HStack(spacing: DUSpacing.sm) {
                    CircleAction(symbol: "magnifyingglass") {
                        placeholderMessage = .key("home.placeholder.search")
                    }
                    AIHeaderAction {
                        isAIChatPresented = true
                    }
                    CircleAction(symbol: "bell.fill") {
                        isMessageCenterPresented = true
                    }
                }
            }

            dashboardCard(
                summary: dashboard.summary,
                usage: dashboard.usage
            )
        }
        .padding(.horizontal, DUSpacing.lg)
        .padding(.top, max(topInset, DUSpacing.xl) + DUSpacing.md)
        .padding(.bottom, DUSpacing.xxl)
        .background(DUTheme.brandGradient)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func dashboardCard(
        summary: HomeSummarySection,
        usage: HomeUsageSection
    ) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.md) {
            HStack(alignment: .top, spacing: DUSpacing.md) {
                VStack(alignment: .leading, spacing: DUSpacing.xs) {
                    Text(localized(summary.primaryTitleKey))
                        .font(.du(11, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))

                    metricValueText(
                        summary.primaryValue,
                        amountFontSize: 28,
                        amountWeight: .bold,
                        amountColor: .white,
                        currencyFontSize: 17,
                        currencyWeight: .semibold,
                        currencyColor: .white.opacity(0.72)
                    )
                }

                Spacer()

                dashboardActions(for: summary)
            }

            summarySecondaryDetails(summary)

            if let creditLimit = summary.creditLimit {
                creditLimitSection(creditLimit)
            }

            if let inlineMessage = summary.inlineMessage {
                inlineMessageText(inlineMessage)
            }

            Divider()
                .overlay(.white.opacity(0.12))
                .padding(.top, 2)
                .padding(.bottom, 2)

            VStack(alignment: .leading, spacing: DUSpacing.md) {
                HStack(spacing: DUSpacing.lg) {
                    ForEach(usage.cards) { card in
                        usageMetric(card)
                    }
                }

                if let inlineMessage = usage.inlineMessage {
                    inlineMessageText(inlineMessage)
                }
            }
            .padding(.top, -DUSpacing.xs)
        }
        .padding(DUSpacing.lg)
        .background(Color.white.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder
    private func summarySecondaryDetails(
        _ summary: HomeSummarySection
    ) -> some View {
        switch summary.paymentType {
        case .prepaid, .unknown:
            EmptyView()
        case .postpaid:
            HStack(spacing: DUSpacing.lg) {
                summaryMetric(
                    titleKey: "home.header.dueDateTitle",
                    value: summary.dueDateValue
                )
            }
        case .hybrid:
            HStack(spacing: DUSpacing.lg) {
                summaryMetric(
                    titleKey: "home.header.currentBillTitle",
                    value: summary.currentBillValue
                )
                summaryMetric(
                    titleKey: "home.header.dueDateTitle",
                    value: summary.dueDateValue
                )
            }
        }
    }

    private func summaryMetric(
        titleKey: String,
        value: LocalizedTextValue
    ) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.xs) {
            Text(localized(titleKey))
                .font(.du(10, weight: .medium))
                .foregroundColor(.white.opacity(0.7))

            metricValueText(
                value,
                amountFontSize: 13,
                amountWeight: .semibold,
                amountColor: .white,
                currencyFontSize: 11,
                currencyWeight: .medium,
                currencyColor: .white.opacity(0.72)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func creditLimitSection(
        _ creditLimit: HomeCreditLimitSection
    ) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.sm) {
            Text(localized("home.header.creditLimitTitle"))
                .font(.du(11, weight: .medium))
                .foregroundColor(.white.opacity(0.78))

            HStack(spacing: DUSpacing.md) {
                creditLimitMetric(
                    titleKey: "home.header.creditTotalTitle",
                    value: creditLimit.totalValue
                )
                creditLimitMetric(
                    titleKey: "home.header.creditUsedTitle",
                    value: creditLimit.usedValue
                )
                creditLimitMetric(
                    titleKey: "home.header.creditRemainingTitle",
                    value: creditLimit.remainingValue
                )
            }
        }
    }

    private func creditLimitMetric(
        titleKey: String,
        value: LocalizedTextValue
    ) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.xs) {
            Text(localized(titleKey))
                .font(.du(10, weight: .medium))
                .foregroundColor(.white.opacity(0.7))

            metricValueText(
                value,
                amountFontSize: 13,
                amountWeight: .semibold,
                amountColor: .white,
                currencyFontSize: 11,
                currencyWeight: .medium,
                currencyColor: .white.opacity(0.68)
            )
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .padding(DUSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func usageMetric(_ card: HomeUsageCard) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.xs) {
            Text(localized(card.title))
                .font(.du(10, weight: .medium))
                .foregroundColor(.white.opacity(0.7))

            Text(localized(card.value))
                .font(.du(13, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)

            ProgressView(value: card.progress)
                .tint(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func inlineMessageText(
        _ value: LocalizedTextValue
    ) -> some View {
        Text(localized(value))
            .font(.du(11, weight: .medium))
            .foregroundColor(.white.opacity(0.82))
    }

    private func inlineBanner(
        _ message: LocalizedTextValue
    ) -> some View {
        HStack(spacing: DUSpacing.sm) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.du(13, weight: .semibold))
                .foregroundColor(DUTheme.cyan)

            Text(localized(message))
                .font(.du(12, weight: .medium))
                .foregroundColor(DUTheme.inkSecondary)

            Spacer()
        }
        .padding(.horizontal, DUSpacing.lg)
        .padding(.vertical, DUSpacing.md)
        .background(DUTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(DUTheme.lineLight, lineWidth: 1)
        )
        .padding(.horizontal, pageHorizontalPadding)
    }

    private var quickActionsSection: some View {
        DUSectionCard(title: nil, spacing: 0) {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: DUSpacing.md), count: 4),
                spacing: DUSpacing.md
            ) {
                ForEach(filteredQuickActions) { item in
                    Button {
                        handleAction(item)
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
        }
        .padding(.horizontal, pageHorizontalPadding)
        .offset(y: -8)
        .padding(.bottom, -8)
    }

    private var featuredCarouselSection: some View {
        // 婵☆偓绲鹃悧鐘诲Υ婢舵劕鐭楁い蹇撳闊剟寮堕埡鍌滄噰闁革綁顥撶槐鎾诲冀閵娿儳鐟╅柡澶屽剱閸犳骞愰柆宥呯闁告繂瀚崑銉╂煥濞戞瑧顬兼い銉ユ瀹曟粓顢旈崶鑸电秺閻庣懓澹婇崰鎾诲焵椤戞寧绁伴柛銈嗙矒瀹曟繈濡搁妸褎鐎梺鍦檸閸樺ジ骞忔导鏉戠閻庯綆浜滈埣銏ゆ煕濮橆厽鍊愭俊缁㈠櫍閺屽牓鎸婃径灞绢唸闁荤喍绀侀幊搴★耿?Home 濠碘槅鍨埀顒冩珪閸嬨儵鎮橀悙鈺佷壕闂備緡鍠撻崝搴ｅ垝瀹ュ棛顩烽柡鍫滅祷閸橆剟鏌?
        HomeFeatureCarouselView(assetNames: featuredCarouselAssetNames)
            // 婵炴垶鎸堕崐鎾诲疾閸洖纭€闁挎稑瀚。濠氭⒒閸ワ絽浜鹃柣鐔告磻閼宠泛煤閸ф绠抽柕澶堝妼閸ㄩ亶鏌涢幒鎾寸凡妞ゆ梹鍔欏畷鎶藉Ω閵娧呭骄缂傚倸鍊归敃顐ゆ濠靛鐐婇柣妯诲墯閸斿啴寮堕埡鍌滄噰闁革綁鏀辩粙澶婎吋閸涱厽娅冩俊顐ゅ缁诲倿藝缂佹ɑ娅犻柣鎰絻椤絿鈧綊娼荤粻鎴ｃ亹閹间焦鍋╂繛鍡樺灦椤忋倝鏌?
            .padding(.vertical, DUSpacing.lg)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(DUTheme.lineLight, lineWidth: 1)
            )
            .duCardStyle()
            .padding(.horizontal, pageHorizontalPadding)
    }

    private var servicesSection: some View {
        DUSectionCard(
            title: localized("home.section.popularServices"),
            trailingTitle: localized("home.section.viewAll"),
            trailingAction: {
                showComingSoon(for: .key("home.section.popularServices"))
            }
        ) {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: DUSpacing.md), count: 4),
                spacing: DUSpacing.md
            ) {
                ForEach(services) { item in
                    Button {
                        handleAction(item)
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
        .padding(.horizontal, pageHorizontalPadding)
    }

    private var productsSection: some View {
        DUSectionCard(
            title: localized("home.section.trendingProducts"),
            trailingTitle: localized("home.section.viewAll"),
            trailingAction: {
                showComingSoon(for: .key("home.section.trendingProducts"))
            }
        ) {
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
                .padding(.vertical, 1)
            }
        }
        .padding(.horizontal, pageHorizontalPadding)
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

    private func profileMetadata(
        for profile: HomeProfileSection
    ) -> String {
        let networkValue = localized(profile.networkStatus?.textValue ?? HomeDisplayValue.unavailable)
        return "\(profile.serviceNumber)  闂? \(networkValue)"
    }

    private func showComingSoon(for title: LocalizedTextValue) {
        placeholderMessage = .key("common.placeholder.feature", arguments: [localized(title)])
    }

    @ViewBuilder
    private func dashboardActions(for summary: HomeSummarySection) -> some View {
        HStack(spacing: DUSpacing.sm) {
            if summary.paymentType == .prepaid {
                Button(localized("home.header.recharge")) {
                    isRechargePresented = true
                }
                .font(.du(13, weight: .semibold))
                .foregroundColor(DUTheme.ink)
                .padding(.horizontal, DUSpacing.lg)
                .frame(height: 36)
                .background(Color.white.opacity(0.95))
                .clipShape(Capsule())
            }

            if summary.paymentType == .postpaid || summary.paymentType == .hybrid {
                Button(localized("home.header.payBill")) {
                    isBillingPresented = true
                }
                .font(.du(13, weight: .semibold))
                .foregroundColor(DUTheme.cyan)
                .padding(.horizontal, DUSpacing.lg)
                .frame(height: 36)
                .background(Color.white)
                .clipShape(Capsule())
            }
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
                    .font(.du(amountFontSize, weight: amountWeight))
                    .foregroundColor(amountColor)

                Text(moneyParts.currency)
                    .font(.du(currencyFontSize, weight: currencyWeight))
                    .foregroundColor(currencyColor)
            }
            .environment(\.layoutDirection, .leftToRight)
        } else {
            Text(resolvedValue)
                .font(.du(amountFontSize, weight: amountWeight))
                .foregroundColor(amountColor)
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
            return "濡絽鍟紞?
        case .service:
            return "濡絽鍟幊?
        case .mall:
            return "濡絽鍟壕?
        case .video:
            return "濡絽鍟粻?
        case .me:
            return "濡絽鍟崳?
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

private struct HomeProduct: Identifiable {
    let id = UUID()
    let name: LocalizedTextValue
    let price: LocalizedTextValue
    let oldPrice: LocalizedTextValue?
    let assetName: String
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

private struct AIHeaderAction: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                let rotation = Angle.degrees((time * 52).truncatingRemainder(dividingBy: 360) * 1.0)
                let pulse = 0.92 + 0.08 * sin(time * 2.4)

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 42, height: 42)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.34),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 2,
                                endRadius: 20
                            )
                        )
                        .scaleEffect(pulse)
                        .blur(radius: 2)

                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [
                                    Color.cyan.opacity(0.95),
                                    Color.white.opacity(0.9),
                                    Color.pink.opacity(0.92),
                                    Color.cyan.opacity(0.95)
                                ],
                                center: .center,
                                angle: rotation
                            ),
                            lineWidth: 1.4
                        )
                        .frame(width: 38, height: 38)

                    orbitDots(time: time)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.98),
                                    Color.white.opacity(0.08)
                                ],
                                center: .topLeading,
                                startRadius: 1,
                                endRadius: 16
                            )
                        )
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.15, green: 0.82, blue: 0.95),
                                            Color(red: 0.22, green: 0.43, blue: 0.96),
                                            Color(red: 0.83, green: 0.23, blue: 0.84)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .padding(1.5)
                        )
                        .overlay(
                            Image(systemName: "sparkles")
                                .font(.du(11, weight: .bold))
                                .foregroundColor(.white)
                                .scaleEffect(0.94 + 0.06 * sin(time * 2.1 + 0.6))
                        )

                    aiBadge
                        .offset(x: 10, y: 12)
                }
                .frame(width: 46, height: 46)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("AI Assistant")
    }

    @ViewBuilder
    private func orbitDots(time: TimeInterval) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                let phase = time * 1.3 + Double(index) * 2.1
                let radius: CGFloat = index == 1 ? 11 : 9
                let size: CGFloat = index == 2 ? 4.5 : 3.5
                let x = cos(phase) * radius
                let y = sin(phase) * radius

                Circle()
                    .fill(index == 0 ? Color.cyan : (index == 1 ? Color.white : Color.pink.opacity(0.95)))
                    .frame(width: size, height: size)
                    .offset(x: x, y: y)
                    .shadow(color: Color.white.opacity(0.35), radius: 3, x: 0, y: 0)
            }
        }
    }

    private var aiBadge: some View {
        Text("AI")
            .font(.du(8, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .frame(height: 14)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.16, green: 0.77, blue: 0.96),
                                Color(red: 0.61, green: 0.25, blue: 0.88)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.55), lineWidth: 0.6)
            )
            .shadow(color: Color.black.opacity(0.14), radius: 4, x: 0, y: 2)
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
