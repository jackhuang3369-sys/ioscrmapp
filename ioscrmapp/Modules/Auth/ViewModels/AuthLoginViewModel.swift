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
    @Published var bannerTone: AuthBannerTone = .info
    @Published var otpCooldownRemaining = 0
    @Published var otpExpiryDescription = "OTP valid for 5 minutes."
    @Published var isRegistrationPresented = false

    private enum RegistrationDismissal {
        case success(phone: String)
        case goToLogin(phone: String)
    }

    private struct Snapshot {
        let selectedMode: LoginMode
        let phoneNumber: String
        let password: String
        let otp: String
        let rememberMe: Bool
        let phoneError: String?
        let passwordError: String?
        let otpError: String?
        let bannerMessage: String?
        let bannerTone: AuthBannerTone
        let otpCooldownRemaining: Int
        let otpExpiryDescription: String
    }

    private let authService: any AuthServicing
    private let sessionStore: SessionStore
    private var countdownTask: Task<Void, Never>?
    private var registrationSnapshot: Snapshot?
    private var registrationDismissal: RegistrationDismissal?

    init(authService: any AuthServicing, sessionStore: SessionStore) {
        self.authService = authService
        self.sessionStore = sessionStore
        selectedMode = sessionStore.preferredLoginMode
        let initialPhone = sessionStore.rememberedPhone.isEmpty ? AuthValidator.demoPhone : sessionStore.rememberedPhone
        phoneNumber = AuthValidator.normalizedPhone(initialPhone)
        rememberMe = !sessionStore.rememberedPhone.isEmpty
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
    }

    func openRegistration() {
        registrationSnapshot = Snapshot(
            selectedMode: selectedMode,
            phoneNumber: phoneNumber,
            password: password,
            otp: otp,
            rememberMe: rememberMe,
            phoneError: phoneError,
            passwordError: passwordError,
            otpError: otpError,
            bannerMessage: bannerMessage,
            bannerTone: bannerTone,
            otpCooldownRemaining: otpCooldownRemaining,
            otpExpiryDescription: otpExpiryDescription
        )
        registrationDismissal = nil
        isRegistrationPresented = true
    }

    func handleRegistrationSuccess(phone: String) {
        registrationDismissal = .success(phone: phone)
    }

    func handleRegistrationGoToLogin(phone: String) {
        registrationDismissal = .goToLogin(phone: phone)
    }

    func handleRegistrationDismissal() {
        defer {
            registrationSnapshot = nil
            registrationDismissal = nil
        }

        switch registrationDismissal {
        case let .success(phone):
            applyRegistrationResult(
                phone: phone,
                bannerMessage: "Registration successful. Please sign in.",
                showSuccessBanner: true
            )
        case let .goToLogin(phone):
            applyRegistrationResult(phone: phone, bannerMessage: nil, showSuccessBanner: false)
        case .none:
            restoreSnapshot()
        }
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
                bannerMessage = "OTP sent successfully."
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
        case .invalidRegistrationPassword, .passwordMismatch:
            break
        case .invalidOTPFormat, .otpExpired, .otpIncorrect:
            otpError = authError.errorDescription
        case .invalidCredentials:
            if selectedMode == .password {
                passwordError = authError.errorDescription
            } else {
                otpError = authError.errorDescription
            }
        case let .otpCooldown(secondsRemaining):
            otpCooldownRemaining = secondsRemaining
            startCountdown(from: secondsRemaining)
        case .accountLocked:
            passwordError = nil
            otpError = nil
        case .accountAlreadyRegistered:
            break
        case .backendMessage, .featureUnavailable, .networkUnavailable:
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

    private func applyRegistrationResult(phone: String, bannerMessage: String?, showSuccessBanner: Bool) {
        selectedMode = .password
        sessionStore.updatePreferredLoginMode(.password)
        phoneNumber = AuthValidator.normalizedPhone(phone)
        password = ""
        otp = ""
        phoneError = nil
        passwordError = nil
        otpError = nil
        otpCooldownRemaining = 0
        otpExpiryDescription = "OTP valid for 5 minutes."
        countdownTask?.cancel()

        if showSuccessBanner, let bannerMessage {
            bannerTone = .success
            self.bannerMessage = bannerMessage
        } else {
            self.bannerMessage = nil
        }
    }

    private func restoreSnapshot() {
        guard let snapshot = registrationSnapshot else {
            return
        }

        selectedMode = snapshot.selectedMode
        phoneNumber = snapshot.phoneNumber
        password = snapshot.password
        otp = snapshot.otp
        rememberMe = snapshot.rememberMe
        phoneError = snapshot.phoneError
        passwordError = snapshot.passwordError
        otpError = snapshot.otpError
        bannerMessage = snapshot.bannerMessage
        bannerTone = snapshot.bannerTone
        otpExpiryDescription = snapshot.otpExpiryDescription

        if snapshot.otpCooldownRemaining > 0 {
            startCountdown(from: snapshot.otpCooldownRemaining)
        } else {
            otpCooldownRemaining = 0
            countdownTask?.cancel()
        }
    }
}
