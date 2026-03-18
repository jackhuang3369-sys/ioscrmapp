import Foundation

private final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    static var lastRegisterBody = Data()

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            fatalError("Missing request handler")
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {
    }
}

private final class RequestCounter {
    private let lock = NSLock()
    private var refreshRequests = 0
    private var protectedSuccesses = 0

    func incrementRefreshRequests() {
        lock.lock()
        refreshRequests += 1
        lock.unlock()
    }

    func incrementProtectedSuccesses() {
        lock.lock()
        protectedSuccesses += 1
        lock.unlock()
    }

    func snapshot() -> (refreshRequests: Int, protectedSuccesses: Int) {
        lock.lock()
        let snapshot = (refreshRequests, protectedSuccesses)
        lock.unlock()
        return snapshot
    }
}

@main
struct RegistrationClientSmokeTests {
    private static let tokenStore = KeychainAuthTokenStore(memoryOnly: true)

    static func main() async throws {
        try? tokenStore.clear()
        defer { try? tokenStore.clear() }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let service = RemoteAuthService(
            serverURL: URL(string: "https://example.com")!,
            session: session,
            contextBuilder: NetworkContextBuilder(tokenStore: tokenStore),
            tokenStore: tokenStore
        )

        try await testPasswordLoginEncryptsPasswordAndStoresToken(service: service, session: session)
        try await testAuthorizedRequestsRefreshExpiringTokenBeforeNetworkCall(session: session)
        try await testConcurrentProtectedRequestsRefreshTokenOnlyOnce(session: session)
        try await testGateway401RefreshesTokenAndRetriesRequest(session: session)
        try await testLoginOTPHappyPathSkipsVerify(service: service)
        try await testLoginErrorMapping(service: service)
        try await testVerifyResponseParsing(service: service)
        try await testOtpMetadataParsing(service: service)
        try await testRegisterRequestEncryptsPasswordField(service: service)
        try await testRegistrationErrorMapping(service: service)
        try await testForgotPasswordFlowParsesChallengeAndVerificationToken(service: service)
        try await testForgotPasswordErrorMapping(service: service)
        try await testSessionStorePersistsSessionAndRememberedCredentials()
        try await testSessionStorePersistsExplicitAuthTypeAndDefaultsLegacySession()
        try await testSessionStoreRestoresExpiredAccessTokenWithRefreshToken()
        try await testSessionStoreClearsExpiredSessionOnLaunch()
        try await testLogoutRefreshesAndSendsPersistedAuthType(service: service)
        try await testLogoutRefreshFailurePreservesLocalTokens(service: service)
        try await testLogoutMapsUnauthorizedToSessionInvalidated(service: service)
        try await testResendOTPResetsInputAndKeepsFiveMinuteValidity()
        print("Auth and registration client smoke tests passed")
    }

    private static func testPasswordLoginEncryptsPasswordAndStoresToken(
        service: RemoteAuthService,
        session: URLSession
    ) async throws {
        try? tokenStore.clear()

        MockURLProtocol.lastRegisterBody = Data()
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!

            switch request.url?.path {
            case "/ser-user-auth/api/auth/login":
                MockURLProtocol.lastRegisterBody = bodyData(from: request)
                return (response, try wrappedResponse(data: loginResponsePayload()))
            case "/protected":
                try require(
                    request.value(forHTTPHeaderField: "Authorization") == "Bearer access-login-token",
                    "protected request should include bearer token after login"
                )
                return (response, try wrappedResponse(data: NSNull()))
            default:
                return (response, try wrappedResponse(data: NSNull()))
            }
        }

        let userSession = try await service.loginWithPassword(phone: "521234567", password: "DuPass9A")
        try require(userSession.displayName == "Ahmed Mohammed", "login should map user display name")
        try require(userSession.phoneNumber == "971521234567", "login should keep backend phone number")

        let requestBody = try requireJSONObject(MockURLProtocol.lastRegisterBody)
        try require(requestBody["authType"] as? String == "1", "password login should send authType 1")
        try require(requestBody["serviceNumber"] as? String == "521234567", "password login should send local phone digits")
        try require((requestBody["loginPlatform"] as? String) == "iOS", "password login should send loginPlatform")
        try require((requestBody["deviceId"] as? String)?.isEmpty == false, "password login should include deviceId")

        guard let encryptedPassword = requestBody["password"] as? String else {
            try require(false, "password login should include encrypted password")
            return
        }
        try require(encryptedPassword != "DuPass9A", "password login should not send plaintext password")

        let client = HTTPClient(
            baseURL: URL(string: "https://example.com")!,
            session: session,
            contextBuilder: NetworkContextBuilder(tokenStore: tokenStore)
        )

        _ = try await client.get(
            HTTPClient.Endpoint(
                path: "/protected",
                method: .get,
                includeCommonParameters: false,
                includeDeviceInfo: false,
                requiresAuthorization: true
            )
        )
    }

    private static func testLoginOTPHappyPathSkipsVerify(service: RemoteAuthService) async throws {
        var paths: [String] = []
        var otpSendBody = Data()
        var otpLoginBody = Data()

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let path = request.url?.path ?? ""
            paths.append(path)

            switch path {
            case "/ser-user-auth/api/auth/code":
                otpSendBody = bodyData(from: request)
                return (response, try wrappedResponse(data: ["resendSeconds": 30, "otpValidSeconds": 180]))
            case "/ser-user-auth/api/auth/login":
                otpLoginBody = bodyData(from: request)
                return (response, try wrappedResponse(data: loginResponsePayload()))
            default:
                return (response, try wrappedResponse(data: NSNull()))
            }
        }

        let sendResult = try await service.sendOTP(to: "521234567")
        try require(
            (29 ... 30).contains(Int(sendResult.resendAvailableAt.timeIntervalSinceNow.rounded(.up))),
            "login otp resend seconds should come from wrapper data"
        )
        try require(
            (179 ... 180).contains(Int(sendResult.expiresAt.timeIntervalSinceNow.rounded(.up))),
            "login otp expiry should come from wrapper data"
        )

        _ = try await service.loginWithOTP(phone: "521234567", otp: "654321")

        try require(
            paths == ["/ser-user-auth/api/auth/code", "/ser-user-auth/api/auth/login"],
            "otp login happy path should call code then login"
        )
        try require(
            !paths.contains("/ser-user-auth/api/auth/verify"),
            "otp login happy path should not call verify"
        )

        let sendBody = try requireJSONObject(otpSendBody)
        try require(sendBody["type"] as? String == "Mobile", "otp send should target mobile channel")
        try require(sendBody["phoneNumber"] as? String == "521234567", "otp send should send local phone digits")

        let loginBody = try requireJSONObject(otpLoginBody)
        try require(loginBody["authType"] as? String == "2", "otp login should send authType 2")
        try require(loginBody["phonenumber"] as? String == "521234567", "otp login should send local phone digits")
        try require(loginBody["smsCode"] as? String == "654321", "otp login should keep submitted otp")
    }

    private static func testAuthorizedRequestsRefreshExpiringTokenBeforeNetworkCall(
        session: URLSession
    ) async throws {
        try? tokenStore.clear()
        try tokenStore.save(
            AuthSessionTokens(
                accessToken: AuthToken(
                    token: "soon-expiring-access-token",
                    expirationTime: tokenDateString(after: 30),
                    renewal: nil
                ),
                refreshToken: AuthToken(
                    token: "refresh-login-token",
                    expirationTime: tokenDateString(after: 24 * 60 * 60),
                    renewal: nil
                )
            )
        )

        let counter = RequestCounter()

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!

            switch request.url?.path {
            case "/ser-user-auth/api/auth/refresh":
                counter.incrementRefreshRequests()
                return (response, try wrappedResponse(data: refreshedTokenPayload()))
            case "/protected":
                try require(
                    request.value(forHTTPHeaderField: "Authorization") == "Bearer refreshed-access-token",
                    "protected request should proactively use refreshed token"
                )
                counter.incrementProtectedSuccesses()
                return (response, try wrappedResponse(data: ["ok": true]))
            default:
                return (response, try wrappedResponse(data: NSNull()))
            }
        }

        let client = HTTPClient(
            baseURL: URL(string: "https://example.com")!,
            session: session,
            contextBuilder: NetworkContextBuilder(tokenStore: tokenStore)
        )

        _ = try await client.get(
            HTTPClient.Endpoint(
                path: "/protected",
                method: .get,
                includeCommonParameters: false,
                includeDeviceInfo: false,
                requiresAuthorization: true
            )
        )

        let snapshot = counter.snapshot()
        try require(snapshot.refreshRequests == 1, "expiring access token should refresh before the request is sent")
        try require(snapshot.protectedSuccesses == 1, "protected request should succeed after proactive refresh")
    }

    private static func testConcurrentProtectedRequestsRefreshTokenOnlyOnce(
        session: URLSession
    ) async throws {
        try? tokenStore.clear()
        try tokenStore.save(
            AuthSessionTokens(
                accessToken: AuthToken(token: "expired-access-token", expirationTime: nil, renewal: nil),
                refreshToken: AuthToken(token: "refresh-login-token", expirationTime: nil, renewal: nil)
            )
        )

        let counter = RequestCounter()

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!

            switch request.url?.path {
            case "/ser-user-auth/api/auth/refresh":
                counter.incrementRefreshRequests()
                let refreshBody = try requireJSONObject(bodyData(from: request))
                try require(
                    refreshBody["refreshToken"] as? String == "refresh-login-token",
                    "refresh endpoint should receive stored refresh token"
                )
                return (response, try wrappedResponse(data: refreshedTokenPayload()))
            case "/protected":
                let authorization = request.value(forHTTPHeaderField: "Authorization")
                if authorization == "Bearer expired-access-token" {
                    let expiredData = try JSONSerialization.data(
                        withJSONObject: [
                            "code": 40_015,
                            "msg": "Token has expired",
                            "data": NSNull(),
                            "traceId": "trace-expired"
                        ]
                    )
                    return (response, expiredData)
                }

                try require(
                    authorization == "Bearer refreshed-access-token",
                    "retried protected request should use refreshed token"
                )
                counter.incrementProtectedSuccesses()
                return (response, try wrappedResponse(data: ["ok": true]))
            default:
                return (response, try wrappedResponse(data: NSNull()))
            }
        }

        let client = HTTPClient(
            baseURL: URL(string: "https://example.com")!,
            session: session,
            contextBuilder: NetworkContextBuilder(tokenStore: tokenStore)
        )

        async let first = client.get(
            HTTPClient.Endpoint(
                path: "/protected",
                method: .get,
                includeCommonParameters: false,
                includeDeviceInfo: false,
                requiresAuthorization: true
            )
        )
        async let second = client.get(
            HTTPClient.Endpoint(
                path: "/protected",
                method: .get,
                includeCommonParameters: false,
                includeDeviceInfo: false,
                requiresAuthorization: true
            )
        )

        _ = try await (first, second)

        let snapshot = counter.snapshot()

        try require(snapshot.refreshRequests == 1, "concurrent protected requests should share a single refresh call")
        try require(snapshot.protectedSuccesses == 2, "protected requests should both succeed after refresh")
        try require(
            tokenStore.loadTokens()?.accessToken.token == "refreshed-access-token",
            "token store should persist refreshed access token"
        )
    }

    private static func testGateway401RefreshesTokenAndRetriesRequest(
        session: URLSession
    ) async throws {
        try? tokenStore.clear()
        try tokenStore.save(
            AuthSessionTokens(
                accessToken: AuthToken(
                    token: "gateway-expired-access-token",
                    expirationTime: tokenDateString(after: 60 * 60),
                    renewal: nil
                ),
                refreshToken: AuthToken(
                    token: "refresh-login-token",
                    expirationTime: tokenDateString(after: 24 * 60 * 60),
                    renewal: nil
                )
            )
        )

        let counter = RequestCounter()

        MockURLProtocol.requestHandler = { request in
            let path = request.url?.path ?? ""

            switch path {
            case "/ser-user-auth/api/auth/refresh":
                counter.incrementRefreshRequests()
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, try wrappedResponse(data: refreshedTokenPayload()))
            case "/protected":
                let authorization = request.value(forHTTPHeaderField: "Authorization")
                if authorization == "Bearer gateway-expired-access-token" {
                    let response = HTTPURLResponse(
                        url: request.url!,
                        statusCode: 401,
                        httpVersion: nil,
                        headerFields: nil
                    )!
                    return (response, Data())
                }

                try require(
                    authorization == "Bearer refreshed-access-token",
                    "gateway 401 retry should use refreshed token"
                )
                counter.incrementProtectedSuccesses()
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, try wrappedResponse(data: ["ok": true]))
            default:
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, try wrappedResponse(data: NSNull()))
            }
        }

        let client = HTTPClient(
            baseURL: URL(string: "https://example.com")!,
            session: session,
            contextBuilder: NetworkContextBuilder(tokenStore: tokenStore)
        )

        _ = try await client.get(
            HTTPClient.Endpoint(
                path: "/protected",
                method: .get,
                includeCommonParameters: false,
                includeDeviceInfo: false,
                requiresAuthorization: true
            )
        )

        let snapshot = counter.snapshot()
        try require(snapshot.refreshRequests == 1, "gateway 401 should trigger exactly one refresh")
        try require(snapshot.protectedSuccesses == 1, "gateway 401 retry should succeed after refresh")
    }

    private static func testLoginErrorMapping(service: RemoteAuthService) async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!

            let data = try JSONSerialization.data(
                withJSONObject: [
                    "code": 41_003,
                    "msg": "The user have logged in on another device",
                    "data": NSNull(),
                    "traceId": "trace-device"
                ]
            )
            return (response, data)
        }

        do {
            _ = try await service.loginWithPassword(phone: "521234567", password: "DuPass9A")
            try require(false, "password login should throw when backend returns device conflict")
        } catch let error as AuthError {
            try require(error == .deviceNotUnique, "device conflict should map to localized device error")
        }

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!

            let data = try JSONSerialization.data(
                withJSONObject: [
                    "code": 50_003,
                    "msg": "OTP code has expired",
                    "data": NSNull(),
                    "traceId": "trace-otp-expired"
                ]
            )
            return (response, data)
        }

        do {
            _ = try await service.loginWithOTP(phone: "521234567", otp: "654321")
            try require(false, "otp login should throw when backend returns expired otp")
        } catch let error as AuthError {
            try require(error == .otpExpired, "otp expired should map to otpExpired")
        }
    }

    private static func testVerifyResponseParsing(service: RemoteAuthService) async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = try wrappedResponse(data: true)
            return (response, data)
        }

        let result = try await service.verifyRegistrationOTP(
            phone: "521234567",
            challengeID: "challenge-001",
            code: "123456"
        )
        try require(result.verifiedPhoneNumber == "971521234567", "verify should return normalized phone")
        try require(result.otpCode == "123456", "verify should keep submitted otp code")
    }

    private static func testOtpMetadataParsing(service: RemoteAuthService) async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = try wrappedResponse(
                data: [
                    "challengeId": "challenge-001",
                    "resendSeconds": 45,
                    "otpValidSeconds": 120
                ]
            )
            return (response, data)
        }

        let result = try await service.sendRegistrationOTP(to: "521234567")
        try require(result.challengeID == "challenge-001", "registration otp send should parse challenge id")
        let resendSeconds = Int(result.resendAvailableAt.timeIntervalSinceNow.rounded(.up))
        let expirySeconds = Int(result.expiresAt?.timeIntervalSinceNow.rounded(.up) ?? 0)
        try require((44 ... 45).contains(resendSeconds), "otp resend seconds should come from wrapper data")
        try require((119 ... 120).contains(expirySeconds), "otp expiry seconds should come from wrapper data")
    }

    private static func testForgotPasswordFlowParsesChallengeAndVerificationToken(
        service: RemoteAuthService
    ) async throws {
        var requestBodies: [String: [String: Any]] = [:]

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let path = request.url?.path ?? ""
            requestBodies[path] = try requireJSONObject(bodyData(from: request))

            switch path {
            case "/ser-user-auth/api/auth/checkUserExist":
                return (response, try wrappedResponse(data: true))
            case "/ser-user-auth/api/auth/code":
                return (response, try wrappedResponse(data: [
                    "challengeId": "forgot-challenge-001",
                    "resendSeconds": 30,
                    "otpValidSeconds": 300
                ]))
            case "/ser-user-auth/api/auth/verify":
                return (response, try wrappedResponse(data: [
                    "verificationToken": "forgot-token-001"
                ]))
            case "/ser-user-auth/api/auth/forgetModifyPass":
                return (response, try wrappedResponse(data: NSNull()))
            default:
                return (response, try wrappedResponse(data: NSNull()))
            }
        }

        let checkResult = try await service.checkForgotPasswordUser(phone: "521234567")
        try require(checkResult.phoneNumber == "971521234567", "forgot password check should normalize phone")

        let sendResult = try await service.sendForgotPasswordOTP(to: "521234567")
        try require(sendResult.challengeID == "forgot-challenge-001", "forgot password otp send should parse challenge id")

        let verifyResult = try await service.verifyForgotPasswordOTP(
            phone: "521234567",
            challengeID: sendResult.challengeID,
            code: "123456"
        )
        try require(verifyResult.verificationToken == "forgot-token-001", "forgot password verify should parse verification token")

        let resetResult = try await service.resetForgotPassword(
            input: ForgotPasswordResetInput(
                phoneNumber: "521234567",
                verificationToken: verifyResult.verificationToken,
                password: "DuPass9A",
                confirmPassword: "DuPass9A"
            )
        )
        try require(resetResult.phoneNumber == "971521234567", "forgot password reset should return normalized phone")

        try require(
            requestBodies["/ser-user-auth/api/auth/checkUserExist"]?["deviceId"] as? String != nil,
            "forgot password check should include deviceId"
        )
        try require(
            requestBodies["/ser-user-auth/api/auth/checkUserExist"]?["phoneNumber"] as? String == "521234567",
            "forgot password check should send local phone digits without country code"
        )
        try require(
            requestBodies["/ser-user-auth/api/auth/verify"]?["challengeId"] as? String == "forgot-challenge-001",
            "forgot password verify should forward challengeId"
        )
        try require(
            requestBodies["/ser-user-auth/api/auth/forgetModifyPass"]?["verificationToken"] as? String == "forgot-token-001",
            "forgot password reset should forward verification token"
        )
        try require(
            requestBodies["/ser-user-auth/api/auth/forgetModifyPass"]?["confirmPass"] as? String != "DuPass9A",
            "forgot password reset should encrypt confirm password"
        )
    }

    private static func testRegisterRequestEncryptsPasswordField(service: RemoteAuthService) async throws {
        MockURLProtocol.lastRegisterBody = Data()
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!

            if request.url?.path == "/ser-user-auth/api/auth/register" {
                MockURLProtocol.lastRegisterBody = bodyData(from: request)
                return (response, try wrappedResponse(data: NSNull()))
            }

            return (response, try wrappedResponse(data: NSNull()))
        }

        _ = try await service.register(
            input: RegistrationSubmitInput(
                phoneNumber: "521234567",
                otpCode: "123456",
                password: "DuPass9A"
            )
        )

        let requestBody = try requireJSONObject(MockURLProtocol.lastRegisterBody)
        try require(requestBody["mobile"] as? String == "521234567", "register request should submit local phone digits")
        try require(requestBody["otpCode"] as? String == "123456", "register request should keep otp code")

        guard let encryptedPassword = requestBody["password"] as? String else {
            try require(false, "register request should contain encrypted password")
            return
        }
        try require(!encryptedPassword.isEmpty, "register password should not be empty")
        try require(encryptedPassword != "DuPass9A", "register request should not expose plaintext password")
    }

    private static func testRegistrationErrorMapping(service: RemoteAuthService) async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!

            let data = try JSONSerialization.data(
                withJSONObject: [
                    "code": 40_017,
                    "msg": "The user password does not comply with the rules",
                    "data": NSNull(),
                    "traceId": "trace-password"
                ]
            )
            return (response, data)
        }

        do {
            _ = try await service.register(
                input: RegistrationSubmitInput(
                    phoneNumber: "521234567",
                    otpCode: "123456",
                    password: "DuPass9A"
                )
            )
            try require(false, "register should throw when backend returns password-rule error")
        } catch let error as AuthError {
            try require(error == .registrationPasswordFormat, "business code 40017 should map to registration password error")
        }
    }

    private static func testForgotPasswordErrorMapping(service: RemoteAuthService) async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!

            let data = try JSONSerialization.data(
                withJSONObject: [
                    "code": 40_015,
                    "msg": "Token has expired",
                    "data": NSNull(),
                    "traceId": "trace-token-expired"
                ]
            )
            return (response, data)
        }

        do {
            _ = try await service.resetForgotPassword(
                input: ForgotPasswordResetInput(
                    phoneNumber: "521234567",
                    verificationToken: "expired-token",
                    password: "DuPass9A",
                    confirmPassword: "DuPass9A"
                )
            )
            try require(false, "forgot password reset should throw when token is expired")
        } catch let error as AuthError {
            try require(error == .verificationTokenExpired, "business code 40015 should map to verificationTokenExpired")
        }
    }

    @MainActor
    private static func testSessionStorePersistsSessionAndRememberedCredentials() async throws {
        let suiteName = "session.store.persist.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)

        let localTokenStore = KeychainAuthTokenStore(
            service: "com.ioscrmapp.tests.persist",
            account: "session.tokens",
            memoryOnly: true
        )
        let credentialsStore = KeychainRememberedCredentialsStore(
            service: "com.ioscrmapp.tests.persist",
            account: "remembered.credentials",
            memoryOnly: true
        )
        try? localTokenStore.clear()
        try? credentialsStore.clear()

        try localTokenStore.save(
            AuthSessionTokens(
                accessToken: AuthToken(
                    token: "restorable-access-token",
                    expirationTime: tokenDateString(after: 60 * 60),
                    renewal: nil
                ),
                refreshToken: AuthToken(
                    token: "restorable-refresh-token",
                    expirationTime: tokenDateString(after: 7 * 24 * 60 * 60),
                    renewal: nil
                )
            )
        )

        let persistedSession = CustSubInfo(
            displayName: "Persisted User",
            phoneNumber: "971521234567",
            greeting: "Good Morning",
            balanceText: "88.00 AED"
        )

        let store = SessionStore(
            defaults: defaults,
            tokenStore: localTokenStore,
            rememberedCredentialsStore: credentialsStore
        )
        store.signIn(
            with: persistedSession,
            rememberCredentials: true,
            phone: persistedSession.phoneNumber,
            password: "DuPass9A",
            loginMode: .password,
            authType: .password
        )

        let restoredStore = SessionStore(
            defaults: defaults,
            tokenStore: localTokenStore,
            rememberedCredentialsStore: credentialsStore
        )

        try require(restoredStore.authenticatedCustSubInfo == persistedSession, "session store should restore persisted user session")
        try require(restoredStore.rememberedPhone == persistedSession.phoneNumber, "remembered phone should come from keychain")
        try require(restoredStore.rememberedPassword == "DuPass9A", "remembered password should come from keychain")
        try require(restoredStore.isAuthenticated, "restored session should stay authenticated while tokens are usable")
    }

    @MainActor
    private static func testSessionStoreRestoresExpiredAccessTokenWithRefreshToken() async throws {
        let suiteName = "session.store.restore.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)

        let localTokenStore = KeychainAuthTokenStore(
            service: "com.ioscrmapp.tests.restore",
            account: "session.tokens",
            memoryOnly: true
        )
        let credentialsStore = KeychainRememberedCredentialsStore(
            service: "com.ioscrmapp.tests.restore",
            account: "remembered.credentials",
            memoryOnly: true
        )
        try? localTokenStore.clear()
        try? credentialsStore.clear()

        try localTokenStore.save(
            AuthSessionTokens(
                accessToken: AuthToken(
                    token: "expired-access-token",
                    expirationTime: tokenDateString(after: -60),
                    renewal: nil
                ),
                refreshToken: AuthToken(
                    token: "refresh-login-token",
                    expirationTime: tokenDateString(after: 24 * 60 * 60),
                    renewal: nil
                )
            )
        )

        let persistedSession = CustSubInfo(
            displayName: "Refreshable User",
            phoneNumber: "971522222222",
            greeting: "Good Morning",
            balanceText: "66.00 AED"
        )
        defaults.set(try JSONEncoder().encode(persistedSession), forKey: "auth.userSession")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!

            switch request.url?.path {
            case "/ser-user-auth/api/auth/refresh":
                return (response, try wrappedResponse(data: refreshedTokenPayload()))
            default:
                return (response, try wrappedResponse(data: NSNull()))
            }
        }

        let store = SessionStore(
            defaults: defaults,
            tokenStore: localTokenStore,
            rememberedCredentialsStore: credentialsStore
        )

        try require(store.shouldRestoreAuthenticationOnLaunch, "expired access token with valid refresh token should trigger startup restore")

        await store.restoreAuthenticationIfNeeded(
            baseURL: URL(string: "https://example.com")!,
            session: session
        )

        try require(store.authenticatedCustSubInfo == persistedSession, "startup restore should keep the persisted session and go home")
        try require(localTokenStore.loadTokens()?.accessToken.token == "refreshed-access-token", "startup restore should persist refreshed access token")
    }

    @MainActor
    private static func testSessionStorePersistsExplicitAuthTypeAndDefaultsLegacySession() async throws {
        let suiteName = "session.store.authType.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)

        let localTokenStore = KeychainAuthTokenStore(
            service: "com.ioscrmapp.tests.authType.\(UUID().uuidString)",
            account: "session.tokens",
            memoryOnly: true
        )
        try localTokenStore.save(
            AuthSessionTokens(
                accessToken: AuthToken(
                    token: "auth-type-access-token",
                    expirationTime: tokenDateString(after: 30 * 60),
                    renewal: nil
                ),
                refreshToken: AuthToken(
                    token: "auth-type-refresh-token",
                    expirationTime: tokenDateString(after: 24 * 60 * 60),
                    renewal: nil
                )
            )
        )

        let store = SessionStore(
            defaults: defaults,
            tokenStore: localTokenStore,
            rememberedCredentialsStore: KeychainRememberedCredentialsStore(
                service: "com.ioscrmapp.tests.authType.\(UUID().uuidString)",
                account: "remembered.credentials",
                memoryOnly: true
            )
        )
        store.signIn(
            with: CustSubInfo(
                displayName: "Ahmed Mohammed",
                phoneNumber: "971521234567",
                greeting: "Good Morning",
                balanceText: "99.00 AED"
            ),
            rememberCredentials: false,
            phone: "971521234567",
            password: nil,
            loginMode: .otp,
            authType: .otp
        )

        let restoredStore = SessionStore(
            defaults: defaults,
            tokenStore: localTokenStore,
            rememberedCredentialsStore: KeychainRememberedCredentialsStore(
                service: "com.ioscrmapp.tests.authType.\(UUID().uuidString)",
                account: "remembered.credentials",
                memoryOnly: true
            )
        )
        try require(restoredStore.currentAuthType == .otp, "restored session should keep persisted authType")

        defaults.removeObject(forKey: "auth.sessionAuthType")

        let legacyStore = SessionStore(
            defaults: defaults,
            tokenStore: localTokenStore,
            rememberedCredentialsStore: KeychainRememberedCredentialsStore(
                service: "com.ioscrmapp.tests.authType.\(UUID().uuidString)",
                account: "remembered.credentials",
                memoryOnly: true
            )
        )
        try require(legacyStore.currentAuthType == .password, "legacy session without authType should default to password authType")
    }

    private static func testLogoutRefreshesAndSendsPersistedAuthType(
        service: RemoteAuthService
    ) async throws {
        try? tokenStore.clear()
        try tokenStore.save(
            AuthSessionTokens(
                accessToken: AuthToken(
                    token: "stale-access-token",
                    expirationTime: tokenDateString(after: 30),
                    renewal: nil
                ),
                refreshToken: AuthToken(
                    token: "refresh-before-logout-token",
                    expirationTime: tokenDateString(after: 24 * 60 * 60),
                    renewal: nil
                )
            )
        )

        var paths: [String] = []
        var logoutBody = Data()

        MockURLProtocol.requestHandler = { request in
            let path = request.url?.path ?? ""
            paths.append(path)

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!

            switch path {
            case "/ser-user-auth/api/auth/refresh":
                return (response, try wrappedResponse(data: refreshedTokenPayload()))
            case "/ser-user-auth/api/auth/logout":
                logoutBody = bodyData(from: request)
                try require(
                    request.value(forHTTPHeaderField: "Authorization") == "Bearer refreshed-access-token",
                    "logout should use the refreshed access token"
                )
                return (response, try wrappedResponse(data: true))
            default:
                return (response, try wrappedResponse(data: NSNull()))
            }
        }

        try await service.logout(authType: .otp)

        try require(
            paths == ["/ser-user-auth/api/auth/refresh", "/ser-user-auth/api/auth/logout"],
            "logout should refresh first and then call logout"
        )

        let requestBody = try requireJSONObject(logoutBody)
        try require(requestBody["authType"] as? String == "2", "logout should send persisted otp authType")
        try require(requestBody["loginPlatform"] as? String == "iOS", "logout should include login platform")
        try require((requestBody["deviceId"] as? String)?.isEmpty == false, "logout should include deviceId")
    }

    private static func testLogoutRefreshFailurePreservesLocalTokens(
        service: RemoteAuthService
    ) async throws {
        try? tokenStore.clear()
        try tokenStore.save(
            AuthSessionTokens(
                accessToken: AuthToken(
                    token: "expiring-access-token",
                    expirationTime: tokenDateString(after: 30),
                    renewal: nil
                ),
                refreshToken: AuthToken(
                    token: "refresh-fails-token",
                    expirationTime: tokenDateString(after: 24 * 60 * 60),
                    renewal: nil
                )
            )
        )

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!

            if request.url?.path == "/ser-user-auth/api/auth/refresh" {
                return (response, Data())
            }

            return (response, try wrappedResponse(data: NSNull()))
        }

        do {
            try await service.logout(authType: .password)
            try require(false, "logout should fail when refresh fails")
        } catch let error as AuthError {
            try require(error == .networkUnavailable, "refresh failure should surface as remote logout failure")
        }

        let storedTokens = tokenStore.loadTokens()
        try require(storedTokens?.accessToken.token == "expiring-access-token", "logout refresh failure should not clear local tokens")
        try require(storedTokens?.refreshToken?.token == "refresh-fails-token", "logout refresh failure should preserve refresh token")
    }

    private static func testLogoutMapsUnauthorizedToSessionInvalidated(
        service: RemoteAuthService
    ) async throws {
        try? tokenStore.clear()
        try tokenStore.save(
            AuthSessionTokens(
                accessToken: AuthToken(
                    token: "valid-access-token",
                    expirationTime: tokenDateString(after: 30 * 60),
                    renewal: nil
                ),
                refreshToken: AuthToken(
                    token: "valid-refresh-token",
                    expirationTime: tokenDateString(after: 24 * 60 * 60),
                    renewal: nil
                )
            )
        )

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!

            if request.url?.path == "/ser-user-auth/api/auth/logout" {
                return (response, Data())
            }

            return (response, try wrappedResponse(data: NSNull()))
        }

        do {
            try await service.logout(authType: .password)
            try require(false, "logout should fail when backend returns 401")
        } catch let error as AuthError {
            try require(error == .sessionInvalidated, "logout 401 should map to session invalidated")
        }
    }

    @MainActor
    private static func testSessionStoreClearsExpiredSessionOnLaunch() async throws {
        let suiteName = "session.store.expired.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)

        let expiredTokenStore = KeychainAuthTokenStore(
            service: "com.ioscrmapp.tests.expired",
            account: "session.tokens",
            memoryOnly: true
        )
        let credentialsStore = KeychainRememberedCredentialsStore(
            service: "com.ioscrmapp.tests.expired",
            account: "remembered.credentials",
            memoryOnly: true
        )
        try? expiredTokenStore.clear()
        try? credentialsStore.clear()

        let expiredSession = CustSubInfo(
            displayName: "Expired User",
            phoneNumber: "971500000000",
            greeting: "Good Morning",
            balanceText: "0.00 AED"
        )
        defaults.set(try JSONEncoder().encode(expiredSession), forKey: "auth.userSession")

        try expiredTokenStore.save(
            AuthSessionTokens(
                accessToken: AuthToken(
                    token: "expired-access-token",
                    expirationTime: tokenDateString(after: -60),
                    renewal: nil
                ),
                refreshToken: AuthToken(
                    token: "expired-refresh-token",
                    expirationTime: tokenDateString(after: -30),
                    renewal: nil
                )
            )
        )

        let store = SessionStore(
            defaults: defaults,
            tokenStore: expiredTokenStore,
            rememberedCredentialsStore: credentialsStore
        )

        try require(store.authenticatedCustSubInfo == nil, "expired tokens should not restore authenticated session")
        try require(defaults.data(forKey: "auth.userSession") == nil, "expired launch should clear persisted session from defaults")
        try require(expiredTokenStore.loadTokens() == nil, "expired launch should clear expired tokens")
    }

    @MainActor
    private static func testResendOTPResetsInputAndKeepsFiveMinuteValidity() async throws {
        let viewModel = AuthRegistrationViewModel(
            authService: MockAuthService(),
            initialPhone: "521111111"
        )

        viewModel.otp = "112052"
        viewModel.otpError = .key("auth.error.otpExpired")

        viewModel.sendOTP()
        try await Task.sleep(nanoseconds: 800_000_000)

        try require(viewModel.otp.isEmpty, "resending otp should clear previous input")
        try require(viewModel.otpError == nil, "resending otp should clear previous otp errors")
        try require(
            viewModel.otpHelperText == .key("auth.registration.otp.expiryDynamic", arguments: ["5"]),
            "otp helper should continue showing five-minute validity after resend"
        )
    }

    private static func wrappedResponse(data: Any) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: [
                "code": 20_000,
                "msg": "Success",
                "data": data,
                "traceId": "trace-smoke"
            ]
        )
    }

    private static func loginResponsePayload() -> [String: Any] {
        [
            "user": [
                "userId": "user-1",
                "username": "Ahmed Mohammed",
                "mobile": "521234567",
                "isFirstLogin": "0"
            ],
            "device": [
                "deviceId": "device-1",
                "isBindDevice": "1",
                "isBiometricLoginEnabled": "0",
                "isSecondDevice": "0"
            ],
            "token": [
                "accessToken": [
                    "token": "access-login-token",
                    "expTime": tokenDateString(after: 30 * 60),
                    "renewal": 1_800_000
                ],
                "refreshToken": [
                    "token": "refresh-login-token",
                    "expTime": tokenDateString(after: 7 * 24 * 60 * 60),
                    "renewal": 604_800_000
                ]
            ],
            "cust": NSNull(),
            "sessionType": "0"
        ]
    }

    private static func refreshedTokenPayload() -> [String: Any] {
        [
            "accessToken": [
                "token": "refreshed-access-token",
                "expTime": tokenDateString(after: 60 * 60),
                "renewal": 3_600_000
            ],
            "refreshToken": [
                "token": "refresh-login-token-next",
                "expTime": tokenDateString(after: 7 * 24 * 60 * 60 + 60 * 60),
                "renewal": 608_400_000
            ]
        ]
    }

    private static func tokenDateString(after seconds: TimeInterval) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: Date().addingTimeInterval(seconds))
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() {
            throw NSError(domain: "RegistrationClientSmokeTests", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    private static func requireJSONObject(_ data: Data) throws -> [String: Any] {
        guard
            let value = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw NSError(
                domain: "RegistrationClientSmokeTests",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "request body should be json object"]
            )
        }
        return value
    }

    private static func bodyData(from request: URLRequest) -> Data {
        if let body = request.httpBody {
            return body
        }

        guard let stream = request.httpBodyStream else {
            return Data()
        }

        stream.open()
        defer { stream.close() }

        let bufferSize = 4096
        var data = Data()
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while stream.hasBytesAvailable {
            let readCount = stream.read(buffer, maxLength: bufferSize)
            if readCount <= 0 {
                break
            }
            data.append(buffer, count: readCount)
        }

        return data
    }
}
