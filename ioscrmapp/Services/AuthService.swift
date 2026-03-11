import Foundation
#if canImport(UIKit)
import UIKit
#endif

protocol AuthServicing: Sendable {
    func loginWithPassword(phone: String, password: String) async throws -> UserSession
    func sendOTP(to phone: String) async throws -> OTPSendResult
    func loginWithOTP(phone: String, otp: String) async throws -> UserSession

    func checkRegistrationEligibility(phone: String) async throws
    func sendRegistrationOTP(to phone: String) async throws -> OTPSendResult
    func verifyRegistrationOTP(phone: String, otp: String) async throws
    func register(phone: String, otp: String, password: String) async throws
}

struct RemoteAuthService: AuthServicing {
    let serverURL: URL
    private let session: URLSession

    init(serverURL: URL, session: URLSession = .shared) {
        self.serverURL = serverURL
        self.session = session
    }

    func loginWithPassword(phone: String, password: String) async throws -> UserSession {
        throw AuthError.featureUnavailable(message: "Remote auth service is not configured yet.")
    }

    func sendOTP(to phone: String) async throws -> OTPSendResult {
        throw AuthError.featureUnavailable(message: "Remote OTP service is not configured yet.")
    }

    func loginWithOTP(phone: String, otp: String) async throws -> UserSession {
        throw AuthError.featureUnavailable(message: "Remote auth service is not configured yet.")
    }

    func checkRegistrationEligibility(phone: String) async throws {
        let request = try makeRequest(
            path: RemoteRegistrationConfiguration.registrationEligibilityPath,
            body: metadataDictionary(merging: [
                "serviceNumber": AuthValidator.localPhoneDigits(phone)
            ]),
            timeoutInterval: 20
        )
        let envelope = try await send(request)
        try validate(envelope, endpoint: .eligibility)
    }

    func sendRegistrationOTP(to phone: String) async throws -> OTPSendResult {
        let request = try makeRequest(
            path: RemoteRegistrationConfiguration.registrationOTPSendPath,
            body: metadataDictionary(merging: [
                "type": "Mobile",
                "phoneNumber": AuthValidator.localPhoneDigits(phone)
            ]),
            timeoutInterval: 20
        )
        let envelope = try await send(request)
        try validate(envelope, endpoint: .otpSend)

        let now = Date()
        return OTPSendResult(
            resendAvailableAt: now.addingTimeInterval(60),
            expiresAt: now.addingTimeInterval(300),
            demoCode: ""
        )
    }

    func verifyRegistrationOTP(phone: String, otp: String) async throws {
        let request = try makeRequest(
            path: RemoteRegistrationConfiguration.registrationOTPVerifyPath,
            body: metadataDictionary(merging: [
                "type": "Mobile",
                "phoneNumber": AuthValidator.localPhoneDigits(phone),
                "code": otp
            ]),
            timeoutInterval: 20
        )
        let envelope = try await send(request)
        try validate(envelope, endpoint: .otpVerify)
    }

    func register(phone: String, otp: String, password: String) async throws {
        var requestBody = metadataDictionary(merging: [
            "mobileNumber": AuthValidator.localPhoneDigits(phone),
            "password": password,
            "code": otp
        ])
        requestBody["osName"] = DeviceMetadata.osName
        requestBody["deviceType"] = DeviceMetadata.deviceType
        requestBody["deviceName"] = DeviceMetadata.deviceName

        let request = try makeRequest(
            path: RemoteRegistrationConfiguration.registrationSubmitPath,
            body: requestBody,
            timeoutInterval: 20
        )
        let envelope = try await send(request)
        try validate(envelope, endpoint: .register)
    }

    private func makeRequest(
        path: String,
        body: [String: Any],
        timeoutInterval: TimeInterval
    ) throws -> URLRequest {
        let trimmedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let url = serverURL.appendingPathComponent(trimmedPath)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeoutInterval
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func send(_ request: URLRequest) async throws -> BackendEnvelope {
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
                throw AuthError.networkUnavailable
            }
            return try JSONDecoder().decode(BackendEnvelope.self, from: data)
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.networkUnavailable
        }
    }

    private func validate(_ envelope: BackendEnvelope, endpoint: RemoteRegistrationEndpoint) throws {
        guard envelope.code == 20_000 else {
            throw mapBusinessError(envelope, endpoint: endpoint)
        }
    }

    private func mapBusinessError(_ envelope: BackendEnvelope, endpoint: RemoteRegistrationEndpoint) -> AuthError {
        switch endpoint {
        case .eligibility:
            if
                envelope.code == RemoteRegistrationConfiguration.alreadyRegisteredCode ||
                envelope.msg.localizedCaseInsensitiveContains("registered") ||
                envelope.msg.localizedCaseInsensitiveContains("exist") ||
                envelope.msg.contains("已注册")
            {
                return .accountAlreadyRegistered
            }
        case .otpVerify:
            if envelope.code == 50_002 {
                return .otpIncorrect
            }
            if envelope.code == 50_003 {
                return .otpExpired
            }
        case .register:
            if envelope.msg.localizedCaseInsensitiveContains("password") {
                return .invalidRegistrationPassword
            }
        case .otpSend:
            break
        }

        return .backendMessage(envelope.msg)
    }

    private func metadataDictionary(merging fields: [String: Any]) -> [String: Any] {
        var payload: [String: Any] = [
            "appVersion": DeviceMetadata.appVersion,
            "osVersion": DeviceMetadata.osVersion,
            "platform": "3",
            "lang": DeviceMetadata.language,
            "serialNo": DeviceMetadata.serialNo(),
            "latitude": DeviceMetadata.latitude,
            "longitude": DeviceMetadata.longitude
        ]

        fields.forEach { payload[$0.key] = $0.value }
        return payload
    }
}

actor MockAuthService: AuthServicing {
    enum RegistrationMode: Sendable {
        case standard
    }

    private struct OTPRecord {
        let code: String
        let resendAvailableAt: Date
        let expiresAt: Date
    }

    private let fallbackPassword = AuthValidator.demoPassword
    private let loginOTPCode = AuthValidator.demoOTP
    private let registrationOTPCode = AuthValidator.demoRegistrationOTP
    private let cooldownSeconds = 60
    private let expirySeconds = 300
    private let lockThreshold = 5
    private let lockDurationSeconds = 15 * 60

    private var loginOTPByPhone: [String: OTPRecord] = [:]
    private var registrationOTPByPhone: [String: OTPRecord] = [:]
    private var failuresByPhone: [String: Int] = [:]
    private var lockUntilByPhone: [String: Date] = [:]
    private var passwordByPhone: [String: String] = [
        AuthValidator.normalizedPhone(AuthValidator.demoPhone): AuthValidator.demoPassword,
        AuthValidator.normalizedPhone("559999999"): AuthValidator.demoRegistrationPassword
    ]

    func loginWithPassword(phone: String, password: String) async throws -> UserSession {
        try await Task.sleep(nanoseconds: 700_000_000)
        let normalizedPhone = AuthValidator.normalizedPhone(phone)
        try checkLock(for: normalizedPhone)
        try maybeSimulateNetworkFailure(phone: normalizedPhone)

        let validPassword = passwordByPhone[normalizedPhone] ?? fallbackPassword
        guard password == validPassword else {
            throw registerFailure(for: normalizedPhone)
        }

        clearFailures(for: normalizedPhone)
        return demoSession(phone: phone)
    }

    func sendOTP(to phone: String) async throws -> OTPSendResult {
        try await Task.sleep(nanoseconds: 500_000_000)
        let normalizedPhone = AuthValidator.normalizedPhone(phone)
        try checkLock(for: normalizedPhone)
        try maybeSimulateNetworkFailure(phone: normalizedPhone)

        if let current = loginOTPByPhone[normalizedPhone], current.resendAvailableAt > Date() {
            throw AuthError.otpCooldown(secondsRemaining: max(1, Int(current.resendAvailableAt.timeIntervalSinceNow.rounded(.up))))
        }

        let record = makeOTPRecord(code: loginOTPCode)
        loginOTPByPhone[normalizedPhone] = record

        return OTPSendResult(
            resendAvailableAt: record.resendAvailableAt,
            expiresAt: record.expiresAt,
            demoCode: record.code
        )
    }

    func loginWithOTP(phone: String, otp: String) async throws -> UserSession {
        try await Task.sleep(nanoseconds: 700_000_000)
        let normalizedPhone = AuthValidator.normalizedPhone(phone)
        try checkLock(for: normalizedPhone)
        try maybeSimulateNetworkFailure(phone: normalizedPhone)

        guard let record = loginOTPByPhone[normalizedPhone] else {
            throw AuthError.otpExpired
        }

        guard record.expiresAt > Date() else {
            loginOTPByPhone.removeValue(forKey: normalizedPhone)
            throw AuthError.otpExpired
        }

        guard otp == record.code else {
            throw registerFailure(for: normalizedPhone)
        }

        clearFailures(for: normalizedPhone)
        loginOTPByPhone.removeValue(forKey: normalizedPhone)
        return demoSession(phone: phone)
    }

    func checkRegistrationEligibility(phone: String) async throws {
        try await Task.sleep(nanoseconds: 300_000_000)
        let normalizedPhone = AuthValidator.normalizedPhone(phone)
        try maybeSimulateNetworkFailure(phone: normalizedPhone)

        if passwordByPhone[normalizedPhone] != nil {
            throw AuthError.accountAlreadyRegistered
        }
    }

    func sendRegistrationOTP(to phone: String) async throws -> OTPSendResult {
        try await Task.sleep(nanoseconds: 500_000_000)
        let normalizedPhone = AuthValidator.normalizedPhone(phone)
        try maybeSimulateNetworkFailure(phone: normalizedPhone)

        if let current = registrationOTPByPhone[normalizedPhone], current.resendAvailableAt > Date() {
            throw AuthError.otpCooldown(secondsRemaining: max(1, Int(current.resendAvailableAt.timeIntervalSinceNow.rounded(.up))))
        }

        let record = makeOTPRecord(code: registrationOTPCode)
        registrationOTPByPhone[normalizedPhone] = record

        return OTPSendResult(
            resendAvailableAt: record.resendAvailableAt,
            expiresAt: record.expiresAt,
            demoCode: record.code
        )
    }

    func verifyRegistrationOTP(phone: String, otp: String) async throws {
        try await Task.sleep(nanoseconds: 500_000_000)
        let normalizedPhone = AuthValidator.normalizedPhone(phone)
        try maybeSimulateNetworkFailure(phone: normalizedPhone)

        guard let record = registrationOTPByPhone[normalizedPhone] else {
            throw AuthError.otpExpired
        }

        guard record.expiresAt > Date() else {
            registrationOTPByPhone.removeValue(forKey: normalizedPhone)
            throw AuthError.otpExpired
        }

        guard otp == record.code else {
            throw AuthError.otpIncorrect
        }
    }

    func register(phone: String, otp: String, password: String) async throws {
        try await Task.sleep(nanoseconds: 700_000_000)
        let normalizedPhone = AuthValidator.normalizedPhone(phone)
        try maybeSimulateNetworkFailure(phone: normalizedPhone)

        if passwordByPhone[normalizedPhone] != nil {
            throw AuthError.accountAlreadyRegistered
        }

        guard let record = registrationOTPByPhone[normalizedPhone] else {
            throw AuthError.otpExpired
        }

        guard record.expiresAt > Date() else {
            registrationOTPByPhone.removeValue(forKey: normalizedPhone)
            throw AuthError.otpExpired
        }

        guard otp == record.code else {
            throw AuthError.otpIncorrect
        }

        guard AuthValidator.isValidRegistrationPassword(password) else {
            throw AuthError.invalidRegistrationPassword
        }

        passwordByPhone[normalizedPhone] = password
        registrationOTPByPhone.removeValue(forKey: normalizedPhone)
    }

    private func makeOTPRecord(code: String) -> OTPRecord {
        let now = Date()
        return OTPRecord(
            code: code,
            resendAvailableAt: now.addingTimeInterval(TimeInterval(cooldownSeconds)),
            expiresAt: now.addingTimeInterval(TimeInterval(expirySeconds))
        )
    }

    private func demoSession(phone: String) -> UserSession {
        UserSession(
            displayName: "Ahmed Mohammed",
            phoneNumber: AuthValidator.formattedPhone(phone),
            greeting: "Good Morning",
            balanceText: "128.50 AED"
        )
    }

    private func checkLock(for phone: String) throws {
        if let lockUntil = lockUntilByPhone[phone], lockUntil > Date() {
            throw AuthError.accountLocked(until: lockUntil)
        }
        if let lockUntil = lockUntilByPhone[phone], lockUntil <= Date() {
            lockUntilByPhone.removeValue(forKey: phone)
            failuresByPhone[phone] = 0
        }
    }

    private func clearFailures(for phone: String) {
        failuresByPhone[phone] = 0
        lockUntilByPhone.removeValue(forKey: phone)
    }

    private func registerFailure(for phone: String) -> AuthError {
        let currentFailures = (failuresByPhone[phone] ?? 0) + 1
        failuresByPhone[phone] = currentFailures

        if currentFailures >= lockThreshold {
            let lockUntil = Date().addingTimeInterval(TimeInterval(lockDurationSeconds))
            lockUntilByPhone[phone] = lockUntil
            return .accountLocked(until: lockUntil)
        }

        return .invalidCredentials(remainingAttempts: lockThreshold - currentFailures)
    }

    private func maybeSimulateNetworkFailure(phone: String) throws {
        if phone.hasSuffix("0000") {
            throw AuthError.networkUnavailable
        }
    }
}

private enum RemoteRegistrationEndpoint {
    case eligibility
    case otpSend
    case otpVerify
    case register
}

private enum RemoteRegistrationConfiguration {
    private enum Keys {
        static let eligibilityPath = "IOSCRMAPP_REGISTER_ELIGIBILITY_PATH"
        static let otpSendPath = "IOSCRMAPP_REGISTER_OTP_SEND_PATH"
        static let otpVerifyPath = "IOSCRMAPP_REGISTER_OTP_VERIFY_PATH"
        static let registerPath = "IOSCRMAPP_REGISTER_SUBMIT_PATH"
        static let alreadyRegisteredCode = "IOSCRMAPP_REGISTER_ALREADY_REGISTERED_CODE"
    }

    static let registrationEligibilityPath = ProcessInfo.processInfo.environment[Keys.eligibilityPath] ?? "/api/auth/register/check"
    static let registrationOTPSendPath = ProcessInfo.processInfo.environment[Keys.otpSendPath] ?? "/api/auth/register/otp/send"
    static let registrationOTPVerifyPath = ProcessInfo.processInfo.environment[Keys.otpVerifyPath] ?? "/api/auth/register/otp/verify"
    static let registrationSubmitPath = ProcessInfo.processInfo.environment[Keys.registerPath] ?? "/api/auth/register"
    static let alreadyRegisteredCode = Int(ProcessInfo.processInfo.environment[Keys.alreadyRegisteredCode] ?? "") ?? 31_002
}

private struct BackendEnvelope: Decodable {
    let code: Int
    let msg: String
    let data: JSONValue?
    let traceId: String
}

private enum JSONValue: Decodable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }
}

private enum DeviceMetadata {
    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    static var osVersion: String {
        #if canImport(UIKit)
        return UIDevice.current.systemVersion
        #else
        return "iOS"
        #endif
    }

    static var osName: String {
        #if canImport(UIKit)
        return "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
        #else
        return "iOS"
        #endif
    }

    static var deviceType: String {
        #if canImport(UIKit)
        return UIDevice.current.userInterfaceIdiom == .phone ? "iphone" : "ios"
        #else
        return "iphone"
        #endif
    }

    static var deviceName: String {
        #if canImport(UIKit)
        return UIDevice.current.name
        #else
        return "iphone"
        #endif
    }

    static var language: String {
        Locale.preferredLanguages.first.flatMap { String($0.prefix(2)) } ?? "en"
    }

    static var latitude: String { "0" }
    static var longitude: String { "0" }

    static func serialNo() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }
}
