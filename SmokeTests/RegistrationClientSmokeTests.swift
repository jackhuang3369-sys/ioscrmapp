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
        try await testConcurrentProtectedRequestsRefreshTokenOnlyOnce(session: session)
        try await testLoginOTPHappyPathSkipsVerify(service: service)
        try await testLoginErrorMapping(service: service)
        try await testVerifyResponseParsing(service: service)
        try await testOtpMetadataParsing(service: service)
        try await testRegisterRequestEncryptsPasswordField(service: service)
        try await testRegistrationErrorMapping(service: service)
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

        let result = try await service.verifyRegistrationOTP(phone: "521234567", code: "123456")
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
                    "resendSeconds": 45,
                    "otpValidSeconds": 120
                ]
            )
            return (response, data)
        }

        let result = try await service.sendRegistrationOTP(to: "521234567")
        let resendSeconds = Int(result.resendAvailableAt.timeIntervalSinceNow.rounded(.up))
        let expirySeconds = Int(result.expiresAt?.timeIntervalSinceNow.rounded(.up) ?? 0)
        try require((44 ... 45).contains(resendSeconds), "otp resend seconds should come from wrapper data")
        try require((119 ... 120).contains(expirySeconds), "otp expiry seconds should come from wrapper data")
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
        try require(requestBody["mobile"] as? String == "971521234567", "register request should submit normalized phone")
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
                "mobile": "971521234567",
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
                    "expTime": "2026-03-15T00:00:00Z",
                    "renewal": 1_710_000_000
                ],
                "refreshToken": [
                    "token": "refresh-login-token",
                    "expTime": "2026-03-22T00:00:00Z",
                    "renewal": 1_710_600_000
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
                "expTime": "2026-03-15T01:00:00Z",
                "renewal": 1_710_003_600
            ],
            "refreshToken": [
                "token": "refresh-login-token-next",
                "expTime": "2026-03-22T01:00:00Z",
                "renewal": 1_710_604_000
            ]
        ]
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
