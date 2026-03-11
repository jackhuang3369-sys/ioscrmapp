import Foundation

enum LoginMode: String, CaseIterable, Identifiable {
    case password
    case otp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .password:
            return "Password"
        case .otp:
            return "OTP"
        }
    }
}

struct UserSession: Equatable {
    let displayName: String
    let phoneNumber: String
    let greeting: String
    let balanceText: String
}

struct OTPSendResult: Equatable {
    let resendAvailableAt: Date
    let expiresAt: Date
    let demoCode: String
}

enum AuthError: Error, LocalizedError, Equatable {
    case invalidPhone
    case invalidPasswordFormat
    case invalidOTPFormat
    case invalidCredentials(remainingAttempts: Int)
    case otpExpired
    case otpCooldown(secondsRemaining: Int)
    case accountLocked(until: Date)
    case featureUnavailable(message: String)
    case networkUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidPhone:
            return "Enter a valid UAE phone number."
        case .invalidPasswordFormat:
            return "Enter a valid password."
        case .invalidOTPFormat:
            return "Enter a valid OTP code."
        case let .invalidCredentials(remainingAttempts):
            return remainingAttempts > 0
                ? "Incorrect phone number or password. \(remainingAttempts) attempts left."
                : "Incorrect credentials."
        case .otpExpired:
            return "OTP expired. Request a new code and try again."
        case let .otpCooldown(secondsRemaining):
            return "Try again in \(secondsRemaining)s."
        case let .accountLocked(until):
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            let lockMessage = formatter.localizedString(for: until, relativeTo: Date())
            return "Account locked until \(lockMessage)."
        case let .featureUnavailable(message):
            return message
        case .networkUnavailable:
            return "Mock service is temporarily unavailable. Please try again."
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
