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

@main
struct RegistrationClientSmokeTests {
    static func main() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let service = RemoteAuthService(
            serverURL: URL(string: "https://example.com")!,
            session: session
        )

        try await testVerifyResponseParsing(service: service)
        try await testOtpMetadataParsing(service: service)
        try await testRegisterRequestEncryptsPasswordField(service: service)
        try await testRegistrationErrorMapping(service: service)
        try await testResendOTPResetsInputAndKeepsFiveMinuteValidity()
        print("Registration client smoke tests passed")
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
