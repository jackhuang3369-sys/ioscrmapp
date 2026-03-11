struct AppServices {
    let authService: any AuthServicing
    let meService: any MeServicing
    let configuration: AppServiceConfiguration

    init(configuration: AppServiceConfiguration = AppConfig.current.serviceConfiguration) {
        self.configuration = configuration

        switch configuration.mode {
        case .mock:
            authService = MockAuthService()
            meService = MockMeService()
        case .remote:
            authService = RemoteAuthService(serverURL: configuration.serverURL)
            meService = RemoteMeService(serverURL: configuration.serverURL)
        }
    }
}
