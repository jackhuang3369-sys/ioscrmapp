import Foundation

@MainActor
final class AuthRegistrationViewModel: ObservableObject {
    enum VerificationResult {
        case stay
        case advanceToPassword
    }

    @Published var phoneNumber: String {
        didSet {
            if oldValue != phoneNumber {
                phoneError = nil
                bannerMessage = nil
                showGoToLoginAction = false
            }
        }
    }
    @Published var otp = "" {
        didSet {
            if oldValue != otp {
                otpError = nil
                bannerMessage = nil
                showGoToLoginAction = false
            }
        }
    }
    @Published var password = "" {
        didSet {
            if oldValue != password {
                passwordError = nil
                confirmPasswordError = nil
                bannerMessage = nil
            }
        }
    }
    @Published var confirmPassword = "" {
        didSet {
            if oldValue != confirmPassword {
                confirmPasswordError = nil
                bannerMessage = nil
            }
        }
    }
    @Published var isLoading = false
    @Published var phoneError: String?
    @Published var otpError: String?
    @Published var passwordError: String?
    @Published var confirmPasswordError: String?
    @Published var bannerMessage: String?
    @Published var bannerTone: AuthBannerTone = .info
    @Published var otpCooldownRemaining = 0
    @Published var otpExpiryDescription = "OTP valid for 5 minutes."
    @Published var showGoToLoginAction = false

    private let authService: any AuthServicing
    private var countdownTask: Task<Void, Never>?
    private var verifiedPhoneNumber = ""
    private var verifiedOTP = ""

    init(authService: any AuthServicing, initialPhone: String = "") {
        self.authService = authService
        phoneNumber = AuthValidator.localPhoneDigits(initialPhone)
    }

    deinit {
        countdownTask?.cancel()
    }

    var otpButtonTitle: String {
        otpCooldownRemaining > 0 ? "Resend in \(otpCooldownRemaining)s" : "Send OTP"
    }

    var isSendOTPEnabled: Bool {
        AuthValidator.isValidLocalPhone(phoneNumber) && otpCooldownRemaining == 0 && !isLoading
    }

    var isVerifyEnabled: Bool {
        AuthValidator.isValidLocalPhone(phoneNumber) && AuthValidator.isValidRegistrationOTP(otp) && !isLoading
    }

    var isRegisterEnabled: Bool {
        !password.isEmpty && !confirmPassword.isEmpty && !isLoading
    }

    var verifiedPhoneSummary: String {
        AuthValidator.formattedPhone(verifiedPhoneNumber.isEmpty ? phoneNumber : verifiedPhoneNumber)
    }

    var currentPhoneForLogin: String {
        AuthValidator.localPhoneDigits(verifiedPhoneNumber.isEmpty ? phoneNumber : verifiedPhoneNumber)
    }

    func sendOTP() {
        clearVerificationMessages()
        guard validatePhone() else {
            return
        }

        isLoading = true
        Task {
            do {
                let result = try await authService.sendRegistrationOTP(to: phoneNumber)
                let seconds = max(60, Int(result.resendAvailableAt.timeIntervalSinceNow.rounded(.up)))
                startCountdown(from: seconds)
                otpExpiryDescription = "OTP valid for 5 minutes."
                bannerTone = .success
                bannerMessage = "OTP sent successfully."
            } catch {
                apply(error: error)
            }
            isLoading = false
        }
    }

    func verifyForPasswordSetup() async -> VerificationResult {
        clearVerificationMessages()

        guard validatePhone() else {
            return .stay
        }
        guard validateRegistrationOTP() else {
            return .stay
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await authService.checkRegistrationEligibility(phone: phoneNumber)
            try await authService.verifyRegistrationOTP(phone: phoneNumber, otp: otp)
            verifiedPhoneNumber = AuthValidator.localPhoneDigits(phoneNumber)
            verifiedOTP = otp
            bannerMessage = nil
            showGoToLoginAction = false
            return .advanceToPassword
        } catch {
            apply(error: error)
            return .stay
        }
    }

    func submitRegistration() async -> Bool {
        clearPasswordMessages()

        guard validateRegistrationPassword() else {
            return false
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await authService.register(phone: verifiedPhoneNumber, otp: verifiedOTP, password: password)
            bannerTone = .success
            bannerMessage = "Registration successful."
            return true
        } catch {
            apply(error: error)
            return false
        }
    }

    private func validatePhone() -> Bool {
        guard AuthValidator.isValidLocalPhone(phoneNumber) else {
            phoneError = AuthError.invalidPhone.errorDescription
            return false
        }
        phoneError = nil
        return true
    }

    private func validateRegistrationOTP() -> Bool {
        guard AuthValidator.isValidRegistrationOTP(otp) else {
            otpError = AuthError.invalidOTPFormat.errorDescription
            return false
        }
        otpError = nil
        return true
    }

    private func validateRegistrationPassword() -> Bool {
        guard AuthValidator.isValidRegistrationPassword(password) else {
            passwordError = AuthError.invalidRegistrationPassword.errorDescription
            return false
        }

        guard password == confirmPassword else {
            confirmPasswordError = AuthError.passwordMismatch.errorDescription
            return false
        }

        passwordError = nil
        confirmPasswordError = nil
        return true
    }

    private func clearVerificationMessages() {
        phoneError = nil
        otpError = nil
        bannerMessage = nil
        showGoToLoginAction = false
    }

    private func clearPasswordMessages() {
        passwordError = nil
        confirmPasswordError = nil
        bannerMessage = nil
    }

    private func apply(error: Error) {
        let authError = (error as? AuthError) ?? .networkUnavailable
        bannerTone = .error
        bannerMessage = authError.errorDescription

        switch authError {
        case .invalidPhone:
            phoneError = authError.errorDescription
        case .invalidOTPFormat, .otpExpired, .otpIncorrect:
            otpError = authError.errorDescription
        case .invalidRegistrationPassword:
            passwordError = authError.errorDescription
        case .passwordMismatch:
            confirmPasswordError = authError.errorDescription
        case .accountAlreadyRegistered:
            showGoToLoginAction = true
        case let .otpCooldown(secondsRemaining):
            startCountdown(from: secondsRemaining)
        case .invalidPasswordFormat, .invalidCredentials, .accountLocked, .backendMessage, .featureUnavailable, .networkUnavailable:
            break
        }
    }

    private func startCountdown(from seconds: Int) {
        countdownTask?.cancel()
        otpCooldownRemaining = seconds

        countdownTask = Task {
            while !Task.isCancelled, otpCooldownRemaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    otpCooldownRemaining = max(0, otpCooldownRemaining - 1)
                }
            }
        }
    }
}
