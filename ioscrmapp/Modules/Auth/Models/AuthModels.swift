import Foundation

enum AuthBannerTone {
    case info
    case success
    case error
}

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
    case invalidRegistrationPassword
    case passwordMismatch
    case invalidOTPFormat
    case otpIncorrect
    case invalidCredentials(remainingAttempts: Int)
    case otpExpired
    case otpCooldown(secondsRemaining: Int)
    case accountAlreadyRegistered
    case accountLocked(until: Date)
    case backendMessage(String)
    case featureUnavailable(message: String)
    case networkUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidPhone:
            return "Enter a valid 9-digit phone number."
        case .invalidPasswordFormat:
            return "Enter a valid password."
        case .invalidRegistrationPassword:
            return "Password must be at least 8 characters and include uppercase, lowercase, number, and special character."
        case .passwordMismatch:
            return "Passwords do not match."
        case .invalidOTPFormat:
            return "Enter a valid 6-digit OTP code."
        case .otpIncorrect:
            return "OTP code is incorrect."
        case let .invalidCredentials(remainingAttempts):
            return remainingAttempts > 0
                ? "Incorrect phone number or password. \(remainingAttempts) attempts left."
                : "Incorrect credentials."
        case .otpExpired:
            return "OTP expired. Request a new code and try again."
        case let .otpCooldown(secondsRemaining):
            return "Try again in \(secondsRemaining)s."
        case .accountAlreadyRegistered:
            return "This phone number is already registered."
        case let .accountLocked(until):
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            let lockMessage = formatter.localizedString(for: until, relativeTo: Date())
            return "Account locked until \(lockMessage)."
        case let .backendMessage(message):
            return message
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
    nonisolated static let demoRegistrationOTP = "123456"
    nonisolated static let demoRegistrationPassword = "DuMobile@123"
    nonisolated static let registrationSpecialCharacters = "!@#$%^&*()_+-=[]{}|;:'\",.<>/?`~"

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

    nonisolated static func isValidLocalPhone(_ value: String) -> Bool {
        localPhoneDigits(value).count == localPhoneLength
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
        guard value.count >= 8 else {
            return false
        }

        let containsWhitespace = value.unicodeScalars.contains(where: CharacterSet.whitespacesAndNewlines.contains)
        guard !containsWhitespace else {
            return false
        }

        let containsUppercase = value.contains(where: \.isUppercase)
        let containsLowercase = value.contains(where: \.isLowercase)
        let containsNumber = value.contains(where: \.isNumber)
        let allowedSpecials = Set(registrationSpecialCharacters)
        let containsSpecial = value.contains(where: { allowedSpecials.contains($0) })

        return containsUppercase && containsLowercase && containsNumber && containsSpecial
    }
}
