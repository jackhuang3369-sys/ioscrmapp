struct AppServices {
    let authService: any AuthServicing
    let meService: any MeServicing
    let notificationService: any NotificationServicing
    let splashAdService: any SplashAdServicing
    let configuration: AppServiceConfiguration

    init(configuration: AppServiceConfiguration = AppConfig.current.serviceConfiguration) {
        self.configuration = configuration

        switch configuration.mode {
        case .mock:
            authService = MockAuthService()
            meService = MockMeService()
            notificationService = MockNotificationService()
            splashAdService = MockSplashAdService()
        case .remote:
            authService = RemoteAuthService(serverURL: configuration.serverURL)
            meService = MockMeService()
            notificationService = RemoteNotificationService(serverURL: configuration.serverURL)
            splashAdService = RemoteSplashAdService(serverURL: configuration.serverURL)
        }
    }
}
