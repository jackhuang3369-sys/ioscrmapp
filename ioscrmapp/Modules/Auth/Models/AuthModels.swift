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
            return "Password must be at least 8 characters with letters and numbers."
        case .invalidOTPFormat:
            return "Enter the 6-digit OTP code."
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
    nonisolated static let demoPhone = "+971 50 123 4567"
    nonisolated static let demoPassword = "Password123"
    nonisolated static let demoOTP = "246810"

    nonisolated static func normalizedPhone(_ value: String) -> String {
        let digits = value.filter(\.isNumber)
        if digits.hasPrefix("0"), digits.count == 10 {
            return "971" + digits.dropFirst()
        }
        if digits.count == 9, digits.first == "5" {
            return "971" + digits
        }
        return digits
    }

    nonisolated static func isValidPhone(_ value: String) -> Bool {
        let digits = normalizedPhone(value)
        return digits.count == 12 && digits.hasPrefix("9715")
    }

    nonisolated static func isValidPassword(_ value: String) -> Bool {
        guard value.count >= 8 else {
            return false
        }
        let hasLetter = value.range(of: "[A-Za-z]", options: .regularExpression) != nil
        let hasNumber = value.range(of: "[0-9]", options: .regularExpression) != nil
        return hasLetter && hasNumber
    }

    nonisolated static func isValidOTP(_ value: String) -> Bool {
        value.count == 6 && value.allSatisfy(\.isNumber)
    }
}
