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

struct UserSession: Equatable {
    let displayName: String
    let phoneNumber: String
    let greetingKey: String
    let balanceAmount: String
}

struct OTPSendResult: Equatable {
    let resendAvailableAt: Date
    let expiresAt: Date
    let demoCode: String
}

enum AuthError: Error, Equatable {
    case invalidPhone
    case invalidPasswordFormat
    case invalidOTPFormat
    case invalidCredentials(remainingAttempts: Int)
    case otpExpired
    case otpCooldown(secondsRemaining: Int)
    case accountLocked(until: Date)
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
        case .otpExpired:
            return .key("auth.error.otpExpired")
        case let .otpCooldown(secondsRemaining):
            return .key("auth.error.otpCooldown", arguments: ["\(secondsRemaining)"])
        case .accountLocked:
            return .key("auth.error.accountLocked")
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
    nonisolated static let demoPhone = "+971 52 123 4567"
    nonisolated static let demoPassword = "111"
    nonisolated static let demoOTP = "111"

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
        guard !localDigits.isEmpty else {
            return ""
        }
        return countryCode + localDigits
    }

    nonisolated static func formattedPhone(_ value: String) -> String {
        let localDigits = localPhoneDigits(value)
        guard localDigits.count == localPhoneLength else {
            return localDigits.isEmpty ? "+\(countryCode)" : "+\(countryCode) \(localDigits)"
        }

        let prefix = localDigits.prefix(2)
        let middle = localDigits.dropFirst(2).prefix(3)
        let suffix = localDigits.suffix(4)
        return "+\(countryCode) \(prefix) \(middle) \(suffix)"
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
}
