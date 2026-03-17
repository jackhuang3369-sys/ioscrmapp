import Foundation

enum LoginMode: String, CaseIterable, Identifiable {
    case password
    case otp

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .password:
            return "auth.mode.password"
        case .otp:
            return "auth.mode.otp"
        }
    }
}

/// Minimal customer/subscriber snapshot used by the authenticated shell and persistence layer.
struct CustSubInfo: Codable, Equatable {
    let displayName: String
    let phoneNumber: String
    let greeting: String
    let balanceText: String
}

struct AuthToken: Codable, Equatable, Sendable {
    let token: String
    let expirationTime: String?
    let renewal: Int64?
}

struct AuthSessionTokens: Codable, Equatable, Sendable {
    let accessToken: AuthToken
    let refreshToken: AuthToken?
}

enum AuthSessionRenewalTrigger: Sendable {
    case startupRestore
    case protectedRequest
}

extension AuthToken {
    private static let backendDateFormat = "yyyy-MM-dd HH:mm:ss"

    var expirationDate: Date? {
        Self.parseExpirationDate(from: expirationTime)
    }

    func isExpired(now: Date = Date()) -> Bool {
        guard let expirationDate else {
            return false
        }
        return expirationDate <= now
    }

    func isValid(now: Date = Date()) -> Bool {
        !token.isEmpty && !isExpired(now: now)
    }

    func isExpiringSoon(
        threshold: TimeInterval = 5 * 60,
        now: Date = Date()
    ) -> Bool {
        guard let expirationDate else {
            return false
        }
        return expirationDate.timeIntervalSince(now) <= threshold
    }

    private static func parseExpirationDate(from rawValue: String?) -> Date? {
        guard let rawValue, !rawValue.isEmpty else {
            return nil
        }

        if let timestamp = Double(rawValue) {
            return timestamp > 1_000_000_000_000
                ? Date(timeIntervalSince1970: timestamp / 1_000)
                : Date(timeIntervalSince1970: timestamp)
        }

        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso8601Formatter.date(from: rawValue) {
            return date
        }

        iso8601Formatter.formatOptions = [.withInternetDateTime]
        if let date = iso8601Formatter.date(from: rawValue) {
            return date
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = backendDateFormat
        return formatter.date(from: rawValue)
    }
}

extension AuthSessionTokens {
    func hasValidAccessToken(now: Date = Date()) -> Bool {
        accessToken.isValid(now: now)
    }

    func hasValidRefreshToken(now: Date = Date()) -> Bool {
        guard let refreshToken else {
            return false
        }
        return refreshToken.isValid(now: now)
    }

    func hasUsableAuthentication(now: Date = Date()) -> Bool {
        hasValidAccessToken(now: now) || hasValidRefreshToken(now: now)
    }

    func shouldRenewAuthentication(
        for trigger: AuthSessionRenewalTrigger,
        now: Date = Date(),
        requestRefreshThreshold: TimeInterval = 5 * 60
    ) -> Bool {
        guard hasValidRefreshToken(now: now) else {
            return false
        }

        switch trigger {
        case .startupRestore:
            return !hasValidAccessToken(now: now)
        case .protectedRequest:
            return accessToken.token.isEmpty || accessToken.isExpiringSoon(
                threshold: requestRefreshThreshold,
                now: now
            )
        }
    }

    func currentAuthorizationToken(now: Date = Date()) -> String? {
        hasValidAccessToken(now: now) ? accessToken.token : nil
    }

    var authenticationExpiryDate: Date? {
        [accessToken.expirationDate, refreshToken?.expirationDate]
            .compactMap { $0 }
            .max()
    }
}

struct OTPSendResult: Equatable {
    let resendAvailableAt: Date
    let expiresAt: Date
    let demoCode: String
}

struct RegistrationOTPSendResult: Equatable {
    let resendAvailableAt: Date
    let expiresAt: Date?
    let demoCode: String
}

struct RegistrationEligibilityResult: Equatable {
    let phoneNumber: String
}

struct RegistrationOTPVerificationResult: Equatable {
    let verifiedPhoneNumber: String
    let otpCode: String
}

struct RegistrationVerifiedContext: Equatable {
    let phoneNumber: String
    let otpCode: String
}

struct RegistrationSubmitInput: Equatable {
    let phoneNumber: String
    let otpCode: String
    let password: String
}

struct RegistrationCompletionResult: Equatable {
    let phoneNumber: String
}

enum RegistrationFlowResult: Equatable {
    case completed(phoneNumber: String)
    case goToLogin(phoneNumber: String)
}

enum AuthBannerTone {
    case info
    case success
    case error
}

enum AuthError: Error, Equatable {
    case invalidPhone
    case invalidPasswordFormat
    case invalidOTPFormat
    case invalidCredentials(remainingAttempts: Int)
    case otpInvalid
    case otpExpired
    case otpCooldown(secondsRemaining: Int)
    case accountLocked(until: Date)
    case deviceNotUnique
    case phoneAlreadyRegistered
    case registrationPasswordFormat
    case passwordMismatch
    case backend(message: String, traceID: String?)
    case featureUnavailable(message: String)
    case networkUnavailable

    var textValue: LocalizedTextValue {
        switch self {
        case .invalidPhone:
            return .key("auth.error.invalidPhone")
        case .invalidPasswordFormat:
            return .key("auth.error.invalidPasswordFormat")
        case .invalidOTPFormat:
            return .key("auth.error.invalidOTPFormat")
        case let .invalidCredentials(remainingAttempts):
            return remainingAttempts > 0
                ? .key("auth.error.invalidCredentialsRemaining", arguments: ["\(remainingAttempts)"])
                : .key("auth.error.invalidCredentials")
        case .otpInvalid:
            return .key("auth.registration.error.otpInvalid")
        case .otpExpired:
            return .key("auth.error.otpExpired")
        case let .otpCooldown(secondsRemaining):
            return .key("auth.error.otpCooldown", arguments: ["\(secondsRemaining)"])
        case .accountLocked:
            return .key("auth.error.accountLocked")
        case .deviceNotUnique:
            return .key("auth.error.deviceNotUnique")
        case .phoneAlreadyRegistered:
            return .key("auth.registration.error.alreadyRegistered")
        case .registrationPasswordFormat:
            return .key("auth.registration.error.passwordRequirements")
        case .passwordMismatch:
            return .key("auth.registration.error.passwordMismatch")
        case let .backend(message, _):
            return .literal(message)
        case let .featureUnavailable(message):
            return .literal(message)
        case .networkUnavailable:
            return .key("auth.error.networkUnavailable")
        }
    }
}

enum AuthValidator {
    nonisolated static let countryCode = "971"
    nonisolated static let localPhoneLength = 9
    nonisolated static let fullPhoneLength = 12
    nonisolated static let demoPhone = "971521234567"
    nonisolated static let demoPassword = "111"
    nonisolated static let demoOTP = "111"
    nonisolated static let demoRegistrationOTP = "123456"

    nonisolated static func localPhoneDigits(_ value: String) -> String {
        let digits = value.filter(\.isNumber)

        if digits.hasPrefix(countryCode) {
            return String(digits.dropFirst(countryCode.count).prefix(localPhoneLength))
        }

        if digits.hasPrefix("0") {
            return String(digits.dropFirst().prefix(localPhoneLength))
        }

        return String(digits.prefix(localPhoneLength))
    }

    nonisolated static func normalizedPhone(_ value: String) -> String {
        let localDigits = localPhoneDigits(value)
        //guard localDigits.count == localPhoneLength, localDigits.hasPrefix("5") else {
        guard localDigits.count == localPhoneLength else {
            return localDigits
        }
        return countryCode + localDigits
    }

    nonisolated static func formattedPhone(_ value: String) -> String {
        normalizedPhone(value)
    }

    nonisolated static func isValidPhone(_ value: String) -> Bool {
        let digits = normalizedPhone(value)
        return digits.count == fullPhoneLength && digits.hasPrefix(countryCode)
    }

    nonisolated static func isValidPassword(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3
    }

    nonisolated static func isValidOTP(_ value: String) -> Bool {
        value.count >= 3 && value.count <= 6 && value.allSatisfy(\.isNumber)
    }

    nonisolated static func isValidRegistrationOTP(_ value: String) -> Bool {
        value.count == 6 && value.allSatisfy(\.isNumber)
    }

    nonisolated static func isValidRegistrationPassword(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).count >= 8
    }
}
