struct AppServices {
    let authService: any AuthServicing
    let homeService: any HomeServicing
    let mallService: any MallServicing
    let offersService: any OffersServicing
    let billingService: any BillingServicing
    let rechargeService: any RechargeServicing
    let meService: any MeServicing
    let badgeCenterService: any BadgeCenterServicing
    let notificationService: any NotificationServicing
    let splashAdService: any SplashAdServicing
    let configuration: AppServiceConfiguration

    init(configuration: AppServiceConfiguration = AppConfig.current.serviceConfiguration) {
        self.configuration = configuration

        switch configuration.mode {
        case .mock:
            authService = MockAuthService()
            homeService = MockHomeService()
            mallService = MockMallService()
            offersService = MockOffersService()
            billingService = MockBillingService()
            rechargeService = MockRechargeService()
            meService = MockMeService()
            badgeCenterService = MockBadgeCenterService()
            notificationService = MockNotificationService()
            splashAdService = MockSplashAdService()
        case .remote:
            authService = RemoteAuthService(serverURL: configuration.serverURL)
            homeService = RemoteHomeService(serverURL: configuration.serverURL)
            mallService = RemoteMallService(serverURL: configuration.serverURL)
            offersService = RemoteOffersService(serverURL: configuration.serverURL)
            billingService = RemoteBillingService(serverURL: configuration.serverURL)
            rechargeService = RemoteRechargeService(serverURL: configuration.serverURL)
            let remoteBadgeCenterService = RemoteBadgeCenterService(serverURL: configuration.serverURL)
            badgeCenterService = remoteBadgeCenterService
            meService = RemoteMeService(badgeCenterService: remoteBadgeCenterService)
            notificationService = RemoteNotificationService(serverURL: configuration.serverURL)
            splashAdService = RemoteSplashAdService(serverURL: configuration.serverURL)
        }
    }
}
