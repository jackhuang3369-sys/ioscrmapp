import Foundation
import os

#if canImport(UIKit)
import UIKit
#endif

private let authLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "ioscrmapp",
    category: "Auth"
)

protocol AuthServicing: Sendable {
    func loginWithPassword(phone: String, password: String) async throws -> UserSession
    func sendOTP(to phone: String) async throws -> OTPSendResult
    func loginWithOTP(phone: String, otp: String) async throws -> UserSession
    func checkRegistrationEligibility(phone: String) async throws -> RegistrationEligibilityResult
    func sendRegistrationOTP(to phone: String) async throws -> RegistrationOTPSendResult
    func verifyRegistrationOTP(phone: String, code: String) async throws -> RegistrationOTPVerificationResult
    func register(input: RegistrationSubmitInput) async throws -> RegistrationCompletionResult
}

struct RemoteAuthService: AuthServicing {
    let serverURL: URL

    func loginWithPassword(phone: String, password: String) async throws -> UserSession {
        throw AuthError.featureUnavailable(message: "Remote auth service is not configured yet.")
    }

    func sendOTP(to phone: String) async throws -> OTPSendResult {
        throw AuthError.featureUnavailable(message: "Remote OTP service is not configured yet.")
    }

    func loginWithOTP(phone: String, otp: String) async throws -> UserSession {
        throw AuthError.featureUnavailable(message: "Remote auth service is not configured yet.")
    }

    func checkRegistrationEligibility(phone: String) async throws -> RegistrationEligibilityResult {
        let localPhone = AuthValidator.localPhoneDigits(phone)
        _ = try await postRegistrationRequest(
            path: "api/auth/register/eligibility",
            payload: ["mobile": localPhone],
            includeDeviceInfo: false
        )
        return RegistrationEligibilityResult(phoneNumber: AuthValidator.normalizedPhone(phone))
    }

    func sendRegistrationOTP(to phone: String) async throws -> RegistrationOTPSendResult {
        let now = Date()
        let localPhone = AuthValidator.localPhoneDigits(phone)
        let data = try await postRegistrationRequest(
            path: "api/auth/register/otp/send",
            payload: ["mobile": localPhone],
            includeDeviceInfo: false
        )

        let resendSeconds = max(1, RegistrationPayloadValue.int(in: data, keys: [
            "resendSeconds",
            "resendInterval",
            "cooldownSeconds"
        ]) ?? 60)

        let expiresAt: Date?
        if let expirySeconds = RegistrationPayloadValue.int(in: data, keys: [
            "expireSeconds",
            "expiresIn",
            "otpValidSeconds",
            "ttl"
        ]) {
            expiresAt = now.addingTimeInterval(TimeInterval(expirySeconds))
        } else if let rawTimestamp = RegistrationPayloadValue.double(in: data, keys: [
            "expiresAt",
            "otpExpiresAt"
        ]) {
            expiresAt = RegistrationPayloadValue.date(fromTimestamp: rawTimestamp)
        } else {
            expiresAt = nil
        }

        return RegistrationOTPSendResult(
            resendAvailableAt: now.addingTimeInterval(TimeInterval(resendSeconds)),
            expiresAt: expiresAt,
            demoCode: ""
        )
    }

    func verifyRegistrationOTP(phone: String, code: String) async throws -> RegistrationOTPVerificationResult {
        let localPhone = AuthValidator.localPhoneDigits(phone)
        _ = try await postRegistrationRequest(
            path: "api/auth/register/otp/verify",
            payload: [
                "mobile": localPhone,
                "otpCode": code
            ],
            includeDeviceInfo: false
        )

        return RegistrationOTPVerificationResult(
            verifiedPhoneNumber: AuthValidator.normalizedPhone(phone),
            otpCode: code
        )
    }

    func register(input: RegistrationSubmitInput) async throws -> RegistrationCompletionResult {
        let localPhone = AuthValidator.localPhoneDigits(input.phoneNumber)
        _ = try await postRegistrationRequest(
            path: "api/auth/register",
            payload: [
                "mobile": localPhone,
                "otpCode": input.otpCode,
                "password": input.password
            ],
            includeDeviceInfo: true
        )

        return RegistrationCompletionResult(phoneNumber: AuthValidator.normalizedPhone(input.phoneNumber))
    }

    private func postRegistrationRequest(
        path: String,
        payload: [String: Any],
        includeDeviceInfo: Bool
    ) async throws -> [String: Any] {
        let metadata = RegistrationRequestMetadataBuilder.payload(includeDeviceInfo: includeDeviceInfo)
        var body = payload
        body.merge(metadata, uniquingKeysWith: { _, new in new })

        var request = URLRequest(url: serverURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthError.networkUnavailable
            }
            guard (200 ... 299).contains(httpResponse.statusCode) else {
                authLogger.error("Registration request failed with HTTP status \(httpResponse.statusCode, privacy: .public) for \(path, privacy: .public)")
                throw AuthError.networkUnavailable
            }

            let jsonObject = try JSONSerialization.jsonObject(with: data)
            guard let payload = jsonObject as? [String: Any] else {
                throw AuthError.networkUnavailable
            }

            let code = RegistrationPayloadValue.int(in: payload, keys: ["code"]) ?? -1
            let message = RegistrationPayloadValue.string(in: payload, keys: ["msg"]) ?? ""
            let traceID = RegistrationPayloadValue.string(in: payload, keys: ["traceId"])

            guard code == 20_000 else {
                authLogger.error(
                    "Registration business error path=\(path, privacy: .public) code=\(code, privacy: .public) traceId=\(traceID ?? "-", privacy: .public)"
                )
                throw RegistrationRemoteErrorMapper.map(code: code, message: message, traceID: traceID)
            }

            return (payload["data"] as? [String: Any]) ?? [:]
        } catch let error as AuthError {
            throw error
        } catch {
            authLogger.error("Registration network error path=\(path, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
            throw AuthError.networkUnavailable
        }
    }
}

actor MockAuthService: AuthServicing {
    private struct OTPRecord {
        let code: String
        let resendAvailableAt: Date
        let expiresAt: Date
    }

    private struct MockAccount {
        let password: String
        let displayName: String
    }

    private let cooldownSeconds = 60
    private let expirySeconds = 300
    private let lockThreshold = 5
    private let lockDurationSeconds = 15 * 60

    private var loginOTPByPhone: [String: OTPRecord] = [:]
    private var registrationOTPByPhone: [String: OTPRecord] = [:]
    private var failuresByPhone: [String: Int] = [:]
    private var lockUntilByPhone: [String: Date] = [:]
    private var accountsByPhone: [String: MockAccount] = [
        "971521234567": MockAccount(password: AuthValidator.demoPassword, displayName: "Ahmed Mohammed"),
        "971555551111": MockAccount(password: "DuPass1!", displayName: "Mariam Al Suwaidi")
    ]

    func loginWithPassword(phone: String, password: String) async throws -> UserSession {
        try await Task.sleep(nanoseconds: 700_000_000)
        let normalizedPhone = AuthValidator.normalizedPhone(phone)
        try checkLock(for: normalizedPhone)
        try maybeSimulateNetworkFailure(phone: normalizedPhone)

        guard let account = accountsByPhone[normalizedPhone], account.password == password else {
            throw registerFailure(for: normalizedPhone)
        }

        clearFailures(for: normalizedPhone)
        return demoSession(phone: normalizedPhone, displayName: account.displayName)
    }

    func sendOTP(to phone: String) async throws -> OTPSendResult {
        try await Task.sleep(nanoseconds: 500_000_000)
        let normalizedPhone = AuthValidator.normalizedPhone(phone)
        try checkLock(for: normalizedPhone)
        try maybeSimulateNetworkFailure(phone: normalizedPhone)

        if let current = loginOTPByPhone[normalizedPhone], current.resendAvailableAt > Date() {
            throw AuthError.otpCooldown(
                secondsRemaining: max(1, Int(current.resendAvailableAt.timeIntervalSinceNow.rounded(.up)))
            )
        }

        let now = Date()
        let record = OTPRecord(
            code: AuthValidator.demoOTP,
            resendAvailableAt: now.addingTimeInterval(TimeInterval(cooldownSeconds)),
            expiresAt: now.addingTimeInterval(TimeInterval(expirySeconds))
        )
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

        guard accountsByPhone[normalizedPhone] != nil else {
            throw registerFailure(for: normalizedPhone)
        }
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
        return demoSession(
            phone: normalizedPhone,
            displayName: accountsByPhone[normalizedPhone]?.displayName ?? "Ahmed Mohammed"
        )
    }

    func checkRegistrationEligibility(phone: String) async throws -> RegistrationEligibilityResult {
        try await Task.sleep(nanoseconds: 350_000_000)
        let normalizedPhone = AuthValidator.normalizedPhone(phone)
        try maybeSimulateNetworkFailure(phone: normalizedPhone)

        if accountsByPhone[normalizedPhone] != nil {
            throw AuthError.phoneAlreadyRegistered
        }

        return RegistrationEligibilityResult(phoneNumber: normalizedPhone)
    }

    func sendRegistrationOTP(to phone: String) async throws -> RegistrationOTPSendResult {
        try await Task.sleep(nanoseconds: 500_000_000)
        let normalizedPhone = AuthValidator.normalizedPhone(phone)
        try maybeSimulateNetworkFailure(phone: normalizedPhone)

        if let current = registrationOTPByPhone[normalizedPhone], current.resendAvailableAt > Date() {
            throw AuthError.otpCooldown(
                secondsRemaining: max(1, Int(current.resendAvailableAt.timeIntervalSinceNow.rounded(.up)))
            )
        }

        let now = Date()
        let record = OTPRecord(
            code: AuthValidator.demoRegistrationOTP,
            resendAvailableAt: now.addingTimeInterval(TimeInterval(cooldownSeconds)),
            expiresAt: now.addingTimeInterval(TimeInterval(expirySeconds))
        )
        registrationOTPByPhone[normalizedPhone] = record

        return RegistrationOTPSendResult(
            resendAvailableAt: record.resendAvailableAt,
            expiresAt: nil,
            demoCode: record.code
        )
    }

    func verifyRegistrationOTP(phone: String, code: String) async throws -> RegistrationOTPVerificationResult {
        try await Task.sleep(nanoseconds: 600_000_000)
        let normalizedPhone = AuthValidator.normalizedPhone(phone)
        try maybeSimulateNetworkFailure(phone: normalizedPhone)

        guard let record = registrationOTPByPhone[normalizedPhone] else {
            throw AuthError.otpExpired
        }
        if normalizedPhone.hasSuffix("3333") {
            registrationOTPByPhone.removeValue(forKey: normalizedPhone)
            throw AuthError.otpExpired
        }
        guard record.expiresAt > Date() else {
            registrationOTPByPhone.removeValue(forKey: normalizedPhone)
            throw AuthError.otpExpired
        }
        guard code == record.code else {
            throw AuthError.otpInvalid
        }

        return RegistrationOTPVerificationResult(
            verifiedPhoneNumber: normalizedPhone,
            otpCode: code
        )
    }

    func register(input: RegistrationSubmitInput) async throws -> RegistrationCompletionResult {
        try await Task.sleep(nanoseconds: 700_000_000)
        let normalizedPhone = AuthValidator.normalizedPhone(input.phoneNumber)
        try maybeSimulateNetworkFailure(phone: normalizedPhone)

        guard accountsByPhone[normalizedPhone] == nil else {
            throw AuthError.phoneAlreadyRegistered
        }
        guard AuthValidator.isValidRegistrationPassword(input.password) else {
            throw AuthError.registrationPasswordFormat
        }
        guard let record = registrationOTPByPhone[normalizedPhone] else {
            throw AuthError.otpExpired
        }
        guard record.expiresAt > Date() else {
            registrationOTPByPhone.removeValue(forKey: normalizedPhone)
            throw AuthError.otpExpired
        }
        guard input.otpCode == record.code else {
            throw AuthError.otpInvalid
        }

        accountsByPhone[normalizedPhone] = MockAccount(
            password: input.password,
            displayName: "New DU User"
        )
        registrationOTPByPhone.removeValue(forKey: normalizedPhone)
        authLogger.info("Mock registration success phone=\(normalizedPhone, privacy: .private(mask: .hash))")

        return RegistrationCompletionResult(phoneNumber: normalizedPhone)
    }

    private func demoSession(phone: String, displayName: String) -> UserSession {
        UserSession(
            displayName: displayName,
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

private enum RegistrationRemoteErrorMapper {
    static func map(code: Int, message: String, traceID: String?) -> AuthError {
        switch code {
        case 50_002:
            return .otpInvalid
        case 50_003:
            return .otpExpired
        default:
            let lowered = message.lowercased()
            if lowered.contains("registered") || message.contains("已注册") {
                return .phoneAlreadyRegistered
            }
            return .backend(
                message: message.isEmpty ? "Registration request failed." : message,
                traceID: traceID
            )
        }
    }
}

private enum RegistrationPayloadValue {
    static func string(in dictionary: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = dictionary[key] as? String, !value.isEmpty {
                return value
            }
        }
        return nil
    }

    static func int(in dictionary: [String: Any], keys: [String]) -> Int? {
        for key in keys {
            if let value = dictionary[key] as? Int {
                return value
            }
            if let value = dictionary[key] as? NSNumber {
                return value.intValue
            }
            if let stringValue = dictionary[key] as? String, let value = Int(stringValue) {
                return value
            }
        }
        return nil
    }

    static func double(in dictionary: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            if let value = dictionary[key] as? Double {
                return value
            }
            if let value = dictionary[key] as? NSNumber {
                return value.doubleValue
            }
            if let stringValue = dictionary[key] as? String, let value = Double(stringValue) {
                return value
            }
        }
        return nil
    }

    static func date(fromTimestamp timestamp: Double) -> Date {
        timestamp > 1_000_000_000_000
            ? Date(timeIntervalSince1970: timestamp / 1_000)
            : Date(timeIntervalSince1970: timestamp)
    }
}

private enum RegistrationRequestMetadataBuilder {
    static func payload(includeDeviceInfo: Bool) -> [String: Any] {
        var payload: [String: Any] = [
            "appVersion": appVersion,
            "osVersion": osVersion,
            "platform": "iOS",
            "lang": languageCode,
            "serialNo": UUID().uuidString.replacingOccurrences(of: "-", with: ""),
            "longitude": defaultLongitude,
            "latitude": defaultLatitude
        ]

        guard includeDeviceInfo else {
            return payload
        }

        payload["osName"] = osName
        payload["deviceType"] = deviceType
        payload["deviceName"] = deviceName
        return payload
    }

    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    private static var osVersion: String {
        #if canImport(UIKit)
        return UIDevice.current.systemVersion
        #else
        return ProcessInfo.processInfo.operatingSystemVersionString
        #endif
    }

    private static var languageCode: String {
        Locale.preferredLanguages.first ?? Locale.current.identifier
    }

    private static var defaultLatitude: Double { 25.2048 }
    private static var defaultLongitude: Double { 55.2708 }

    private static var osName: String {
        #if canImport(UIKit)
        return UIDevice.current.systemName
        #else
        return "iOS"
        #endif
    }

    private static var deviceType: String {
        #if canImport(UIKit)
        return UIDevice.current.model
        #else
        return "iPhone"
        #endif
    }

    private static var deviceName: String {
        #if canImport(UIKit)
        return UIDevice.current.name
        #else
        return "iPhone"
        #endif
    }
}
