import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore

    let custSubInfo: CustSubInfo
    @ObservedObject var sessionStore: SessionStore
    let authService: any AuthServicing
    let billingService: any BillingServicing
    let rechargeService: any RechargeServicing
    let meService: any MeServicing
    let mallService: any MallServicing
    let notificationService: any NotificationServicing

    @StateObject private var viewModel: HomeViewModel
    @State private var placeholderMessage: LocalizedTextValue?
    @State private var selectedTab: HomeTab = .home
    @State private var selectedBannerIndex = 0
    @State private var isMessageCenterPresented = false
    @State private var isBillingPresented = false
    @State private var isRechargePresented = false
    @State private var isSigningOut = false
    @State private var signOutFailureMessageKey: String?

    private let pageHorizontalPadding: CGFloat = DUSpacing.md
    private let bannerTimer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()
    private let quickActions: [HomeItem] = [
        .init(title: .key("home.quick.recharge"), assetName: "QuickRechargeIcon", action: .recharge),
        .init(title: .key("home.quick.payBill"), assetName: "ServiceBillsIcon", action: .billing),
        .init(title: .key("home.quick.offers"), assetName: "QuickOffersIcon"),
        .init(title: .key("home.quick.mall"), assetName: "QuickMallIcon", action: .mall),
    ]

    private let services: [HomeItem] = [
        .init(title: .key("home.service.dataPack"), assetName: "ServiceDataPackIcon"),
        .init(title: .key("home.service.voicePack"), assetName: "ServiceVoicePackIcon"),
        .init(title: .key("home.service.roaming"), assetName: "ServiceRoamingIcon"),
        .init(title: .key("home.service.tickets"), assetName: "ServiceTicketsIcon"),
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
        ),
    ]

    init(
        custSubInfo: CustSubInfo,
        sessionStore: SessionStore,
        authService: any AuthServicing,
        homeService: any HomeServicing,
        mallService: any MallServicing,
        billingService: any BillingServicing,
        rechargeService: any RechargeServicing,
        meService: any MeServicing,
        notificationService: any NotificationServicing
    ) {
        self.custSubInfo = custSubInfo
        self.sessionStore = sessionStore
        self.authService = authService
        self.billingService = billingService
        self.rechargeService = rechargeService
        self.mallService = mallService
        self.meService = meService
        self.notificationService = notificationService
        _viewModel = StateObject(
            wrappedValue: HomeViewModel(
                session: custSubInfo,
                homeService: homeService
            )
        )
    }

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
                session: custSubInfo,
                billingService: billingService,
                rechargeService: rechargeService,
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
                        bannerCarousel
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
        return "\(profile.serviceNumber)  •  \(networkValue)"
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
    enum Action {
        case placeholder
        case mall
        case billing
        case recharge
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

private struct HomeBanner {
    let title: LocalizedTextValue
    let subtitle: LocalizedTextValue
    let colors: [Color]
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
            custSubInfo: CustSubInfo(
                displayName: "Ahmed Mohammed",
                phoneNumber: AuthValidator.demoPhone,
                greeting: "Good Morning",
                balanceText: "128.50 AED",
                userID: "preview-user",
                serviceNumber: AuthValidator.demoPhone
            ),
            sessionStore: SessionStore.previewAuthenticated,
            authService: MockAuthService(),
            homeService: MockHomeService(),
            mallService: MockMallService(),
            billingService: MockBillingService(),
            rechargeService: MockRechargeService(),
            meService: MockMeService(),
            notificationService: MockNotificationService()
        )
        .environmentObject(AppLanguageStore(initialLanguage: .english))
    }
}
