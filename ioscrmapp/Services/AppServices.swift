import Foundation

struct AppServices {
    let aiChatService: any AIChatServicing
    let authService: any AuthServicing
    let uaePassService: UAEPassServicing
    let homeService: any HomeServicing
    let mallService: any MallServicing
    let videoService: any VideoServicing
    let offersService: any OffersServicing
    let billingService: any BillingServicing
    let rechargeService: any RechargeServicing
    let ticketsService: any TicketsServicing
    let meService: any MeServicing
    let badgeCenterService: any BadgeCenterServicing
    let notificationService: any NotificationServicing
    let splashAdService: any SplashAdServicing
    let intentRecognitionService: any IntentRecognitionServicing
    let configuration: AppServiceConfiguration

    init(configuration: AppServiceConfiguration = AppConfig.current.serviceConfiguration) {
        self.configuration = configuration
        switch configuration.mode {
        case .mock:
            let mockBadgeCenterService = MockBadgeCenterService()
            aiChatService = MockAIChatService()
            authService = MockAuthService()
            uaePassService = MockUAEPassService()
            homeService = MockHomeService()
            mallService = MockMallService()
            videoService = MockVideoService()
            offersService = MockOffersService()
            billingService = MockBillingService()
            rechargeService = MockRechargeService()
            ticketsService = MockTicketsService()
            meService = MockMeService(badgeCenterService: mockBadgeCenterService)
            badgeCenterService = mockBadgeCenterService
            notificationService = MockNotificationService()
            splashAdService = MockSplashAdService()
            intentRecognitionService = Self.makeIntentRecognitionService(
                aiChatService: aiChatService,
                configuration: configuration
            )
        case .remote:
            aiChatService = RemoteAIChatService()
            authService = RemoteAuthService(serverURL: configuration.serverURL)
            uaePassService = RemoteUAEPassService(client: HTTPClient(baseURL: configuration.serverURL))
            homeService = RemoteHomeService(serverURL: configuration.serverURL)
            mallService = RemoteMallService(serverURL: configuration.serverURL)
            //videoService = RemoteVideoService(serverURL: configuration.serverURL)
            videoService = MockVideoService()
            offersService = RemoteOffersService(serverURL: configuration.serverURL)
            billingService = RemoteBillingService(serverURL: configuration.serverURL)
            rechargeService = RemoteRechargeService(serverURL: configuration.serverURL)
            ticketsService = RemoteTicketsService(serverURL: configuration.serverURL)
            let remoteBadgeCenterService = RemoteBadgeCenterService(serverURL: configuration.serverURL)
            badgeCenterService = remoteBadgeCenterService
            meService = RemoteMeService(badgeCenterService: remoteBadgeCenterService)
            notificationService = RemoteNotificationService(serverURL: configuration.serverURL)
            splashAdService = RemoteSplashAdService(serverURL: configuration.serverURL)
            intentRecognitionService = Self.makeIntentRecognitionService(
                aiChatService: aiChatService,
                configuration: configuration
            )
        }
    }

    static func makeIntentRecognitionService(
        aiChatService: any AIChatServicing,
        configuration: AppServiceConfiguration = AppConfig.current.serviceConfiguration
    ) -> any IntentRecognitionServicing {
        let intentConfiguration = IntentClassifierConfiguration.current(serviceMode: configuration.mode)
        let classifier = CoreMLIntentClassifier(
            modelProvider: BundleIntentModelProvider(),
            minimumAcceptedConfidence: intentConfiguration.minimumAcceptedCoreMLConfidence
        )

        // Create ONB persona classifier and fusion service
        let onbClassifier = CoreMLONBPersonaClassifier()
        let onbFusionService = ONBIntentFusionService(personaClassifier: onbClassifier)

        return DefaultIntentRecognitionService(
            aiChatService: aiChatService,
            classifier: classifier,
            configuration: intentConfiguration,
            onbFusionService: onbFusionService
        )
    }
}

protocol TicketsServicing: Sendable {
    func fetchTicketURL() async throws -> URL
}

enum TicketsServiceError: Error {
    case missingURL
    case invalidURL
    case networkUnavailable
}

actor MockTicketsService: TicketsServicing {
    func fetchTicketURL() async throws -> URL {
        guard let url = URL(string: "http://10.110.141.169:18301/") else {
            throw TicketsServiceError.invalidURL
        }
        return url
    }
}

struct RemoteTicketsService: TicketsServicing {
    private static let queryConfigEndpoint = HTTPClient.Endpoint(
        path: "ser-query/api/sysparamter/query",
        method: .post,
        requiresAuthorization: true
    )

    private let client: HTTPClient

    init(
        serverURL: URL,
        session: URLSession = .shared,
        contextBuilder: NetworkContextBuilder = NetworkContextBuilder()
    ) {
        client = HTTPClient(
            baseURL: serverURL,
            session: session,
            contextBuilder: contextBuilder
        )
    }

    func fetchTicketURL() async throws -> URL {
        do {
            let responseData = try await client.post(
                Self.queryConfigEndpoint,
                body: ["paramCode": "VIDEO_TICKET_URL"]
            )

            guard
                let object = responseData.objectValue,
                let rawValue = string(in: object, key: "paramValue")?.trimmingCharacters(in: .whitespacesAndNewlines),
                !rawValue.isEmpty
            else {
                throw TicketsServiceError.missingURL
            }

            guard
                let url = URL(string: rawValue),
                let scheme = url.scheme?.lowercased(),
                ["http", "https"].contains(scheme),
                url.host?.isEmpty == false
            else {
                throw TicketsServiceError.invalidURL
            }

            return url
        } catch let error as TicketsServiceError {
            throw error
        } catch let error as HTTPClient.ClientError {
            throw mapClientError(error)
        } catch {
            throw TicketsServiceError.networkUnavailable
        }
    }

    private func mapClientError(_ error: HTTPClient.ClientError) -> TicketsServiceError {
        switch error {
        case .invalidResponse, .invalidJSON, .httpStatus, .tooManyRequests, .networkUnavailable, .business:
            return .networkUnavailable
        }
    }

    private func string(in object: [String: HTTPClient.ResponseData], key: String) -> String? {
        object[key]?.stringValue
    }
}
