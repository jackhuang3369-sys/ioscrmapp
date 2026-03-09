import Combine
import Foundation

@MainActor
final class AuthLoginViewModel: ObservableObject {
    @Published var selectedMode: LoginMode
    @Published var phoneNumber: String
    @Published var password = ""
    @Published var otp = ""
    @Published var rememberMe = true
    @Published var isLoading = false
    @Published var phoneError: String?
    @Published var passwordError: String?
    @Published var otpError: String?
    @Published var bannerMessage: String?
    @Published var bannerTone: BannerTone = .info
    @Published var otpCooldownRemaining = 0
    @Published var otpExpiryDescription = "OTP valid for 5 minutes."
    @Published var mockHint = "Mock password: Password123"

    enum BannerTone {
        case info
        case success
        case error
    }

    private let authService: any AuthServicing
    private let sessionStore: SessionStore
    private var countdownTask: Task<Void, Never>?

    init(authService: any AuthServicing, sessionStore: SessionStore) {
        self.authService = authService
        self.sessionStore = sessionStore
        selectedMode = sessionStore.preferredLoginMode
        phoneNumber = sessionStore.rememberedPhone.isEmpty ? AuthValidator.demoPhone : sessionStore.rememberedPhone
        rememberMe = !sessionStore.rememberedPhone.isEmpty
        updateMockHint()
    }

    deinit {
        countdownTask?.cancel()
    }

    var isPrimaryActionEnabled: Bool {
        if isLoading {
            return false
        }
        switch selectedMode {
        case .password:
            return AuthValidator.isValidPhone(phoneNumber) && !password.isEmpty
        case .otp:
            return AuthValidator.isValidPhone(phoneNumber) && AuthValidator.isValidOTP(otp)
        }
    }

    var otpButtonTitle: String {
        otpCooldownRemaining > 0 ? "Resend in \(otpCooldownRemaining)s" : "Send OTP"
    }

    var isSendOTPEnabled: Bool {
        AuthValidator.isValidPhone(phoneNumber) && otpCooldownRemaining == 0 && !isLoading
    }

    func select(mode: LoginMode) {
        selectedMode = mode
        sessionStore.updatePreferredLoginMode(mode)
        clearMessages()
        updateMockHint()
    }

    func sendOTP() {
        clearMessages()
        guard validatePhone() else {
            return
        }

        isLoading = true
        Task {
            do {
                let result = try await authService.sendOTP(to: phoneNumber)
                let seconds = max(0, Int(result.resendAvailableAt.timeIntervalSinceNow.rounded(.up)))
                startCountdown(from: seconds)
                otpExpiryDescription = "OTP valid for 5 minutes."
                bannerTone = .success
                bannerMessage = "Mock OTP sent. Use \(result.demoCode) to continue."
            } catch {
                apply(error: error)
            }
            isLoading = false
        }
    }

    func login() {
        clearMessages()

        guard validatePhone() else {
            return
        }
        switch selectedMode {
        case .password:
            guard validatePassword() else {
                return
            }
        case .otp:
            guard validateOTP() else {
                return
            }
        }

        isLoading = true
        Task {
            do {
                let session: UserSession
                switch selectedMode {
                case .password:
                    session = try await authService.loginWithPassword(phone: phoneNumber, password: password)
                case .otp:
                    session = try await authService.loginWithOTP(phone: phoneNumber, otp: otp)
                }

                sessionStore.signIn(
                    with: session,
                    rememberPhone: rememberMe,
                    phone: phoneNumber,
                    loginMode: selectedMode
                )
            } catch {
                apply(error: error)
            }
            isLoading = false
        }
    }

    func showPlaceholderMessage(for feature: String) {
        bannerTone = .info
        bannerMessage = "\(feature) is coming soon."
    }

    private func validatePhone() -> Bool {
        guard AuthValidator.isValidPhone(phoneNumber) else {
            phoneError = AuthError.invalidPhone.errorDescription
            return false
        }
        phoneError = nil
        return true
    }

    private func validatePassword() -> Bool {
        guard AuthValidator.isValidPassword(password) else {
            passwordError = AuthError.invalidPasswordFormat.errorDescription
            return false
        }
        passwordError = nil
        return true
    }

    private func validateOTP() -> Bool {
        guard AuthValidator.isValidOTP(otp) else {
            otpError = AuthError.invalidOTPFormat.errorDescription
            return false
        }
        otpError = nil
        return true
    }

    private func clearMessages() {
        phoneError = nil
        passwordError = nil
        otpError = nil
        bannerMessage = nil
    }

    private func apply(error: Error) {
        let authError = (error as? AuthError) ?? .networkUnavailable
        bannerTone = .error
        bannerMessage = authError.errorDescription

        switch authError {
        case .invalidPhone:
            phoneError = authError.errorDescription
        case .invalidPasswordFormat:
            passwordError = authError.errorDescription
        case .invalidOTPFormat, .otpExpired:
            otpError = authError.errorDescription
        case .invalidCredentials:
            if selectedMode == .password {
                passwordError = authError.errorDescription
            } else {
                otpError = "Incorrect OTP. Try 246810 for the mock flow."
            }
        case let .otpCooldown(secondsRemaining):
            otpCooldownRemaining = secondsRemaining
            startCountdown(from: secondsRemaining)
        case .accountLocked:
            passwordError = nil
            otpError = nil
        case .featureUnavailable, .networkUnavailable:
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

    private func updateMockHint() {
        mockHint = selectedMode == .password
            ? "Mock password: Password123"
            : "Mock OTP: 246810"
    }
}
