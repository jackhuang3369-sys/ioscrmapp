import Combine
import Foundation
import os

@MainActor
final class AuthLoginViewModel: ObservableObject {
    @Published var selectedMode: LoginMode
    @Published var phoneNumber: String
    @Published var password = ""
    @Published var otp = ""
    @Published var rememberMe = true
    @Published var isLoading = false
    @Published var phoneError: LocalizedTextValue?
    @Published var passwordError: LocalizedTextValue?
    @Published var otpError: LocalizedTextValue?
    @Published var bannerMessage: LocalizedTextValue?
    @Published var bannerTone: AuthBannerTone = .info
    @Published var otpCooldownRemaining = 0

    private let authService: any AuthServicing
    private let sessionStore: SessionStore
    private var countdownTask: Task<Void, Never>?

    init(authService: any AuthServicing, sessionStore: SessionStore) {
        self.authService = authService
        self.sessionStore = sessionStore
        selectedMode = sessionStore.preferredLoginMode
        let initialPhone = sessionStore.rememberedPhone.isEmpty ? AuthValidator.demoPhone : sessionStore.rememberedPhone
        phoneNumber = AuthValidator.normalizedPhone(initialPhone)
        password = sessionStore.rememberedPassword
        rememberMe = sessionStore.hasRememberedCredentials
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

    var otpButtonText: LocalizedTextValue {
        otpCooldownRemaining > 0
            ? .key("auth.otp.resend", arguments: ["\(otpCooldownRemaining)"])
            : .key("auth.otp.send")
    }

    var isSendOTPEnabled: Bool {
        AuthValidator.isValidPhone(phoneNumber) && otpCooldownRemaining == 0 && !isLoading
    }

    func select(mode: LoginMode) {
        selectedMode = mode
        sessionStore.updatePreferredLoginMode(mode)
        clearMessages()
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
                bannerTone = .success
                bannerMessage = .key("auth.otp.sent")
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
                let session: CustSubInfo
                switch selectedMode {
                case .password:
                    session = try await authService.loginWithPassword(phone: phoneNumber, password: password)
                case .otp:
                    session = try await authService.loginWithOTP(phone: phoneNumber, otp: otp)
                }

                sessionStore.signIn(
                    with: session,
                    rememberCredentials: rememberMe,
                    phone: phoneNumber,
                    password: selectedMode == .password ? password : nil,
                    loginMode: selectedMode
                )
            } catch {
                apply(error: error)
            }
            isLoading = false
        }
    }

    func showPlaceholderMessage(for key: String) {
        bannerTone = .info
        bannerMessage = .key(key)
    }

    func applyRegistrationResult(_ result: RegistrationFlowResult) {
        clearMessages()

        switch result {
        case let .completed(phoneNumber):
            self.phoneNumber = AuthValidator.normalizedPhone(phoneNumber)
            password = ""
            otp = ""
            selectedMode = .password
            sessionStore.updatePreferredLoginMode(.password)
            bannerTone = .success
            bannerMessage = .key("auth.registration.success.login")
        case let .goToLogin(phoneNumber):
            self.phoneNumber = AuthValidator.normalizedPhone(phoneNumber)
            password = ""
            otp = ""
            selectedMode = .password
            sessionStore.updatePreferredLoginMode(.password)
        }
    }

    private func validatePhone() -> Bool {
        guard AuthValidator.isValidPhone(phoneNumber) else {
            phoneError = AuthError.invalidPhone.textValue
            return false
        }
        phoneError = nil
        return true
    }

    private func validatePassword() -> Bool {
        guard AuthValidator.isValidPassword(password) else {
            passwordError = AuthError.invalidPasswordFormat.textValue
            return false
        }
        passwordError = nil
        return true
    }

    private func validateOTP() -> Bool {
        guard AuthValidator.isValidOTP(otp) else {
            otpError = AuthError.invalidOTPFormat.textValue
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
        bannerMessage = authError.textValue

        switch authError {
        case .invalidPhone:
            phoneError = authError.textValue
        case .invalidPasswordFormat:
            passwordError = authError.textValue
        case .invalidOTPFormat, .otpInvalid, .otpExpired:
            otpError = authError.textValue
        case .invalidCredentials:
            if selectedMode == .password {
                passwordError = authError.textValue
            } else {
                otpError = authError.textValue
            }
        case let .otpCooldown(secondsRemaining):
            otpCooldownRemaining = secondsRemaining
            startCountdown(from: secondsRemaining)
        case .accountLocked:
            passwordError = nil
            otpError = nil
        case .deviceNotUnique, .featureUnavailable, .networkUnavailable, .phoneAlreadyRegistered, .registrationPasswordFormat, .passwordMismatch, .backend:
            break
        }
    }

    private func startCountdown(from seconds: Int) {
        countdownTask?.cancel()
        otpCooldownRemaining = seconds

        countdownTask = Task {
            while !Task.isCancelled, otpCooldownRemaining > 0 {
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                } catch {
                    break
                }
                await MainActor.run {
                    otpCooldownRemaining = max(0, otpCooldownRemaining - 1)
                }
            }
        }
    }
}

@MainActor
final class AuthRegistrationViewModel: ObservableObject {
    private static let otpValiditySeconds: TimeInterval = 5 * 60

    @Published var phoneNumber: String
    @Published var otp = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var phoneError: LocalizedTextValue?
    @Published var otpError: LocalizedTextValue?
    @Published var passwordError: LocalizedTextValue?
    @Published var confirmPasswordError: LocalizedTextValue?
    @Published var bannerMessage: LocalizedTextValue?
    @Published var bannerTone: AuthBannerTone = .info
    @Published var otpCooldownRemaining = 0
    @Published var shouldShowGoToLoginAction = false
    @Published private(set) var isLoading = false
    @Published private(set) var verifiedContext: RegistrationVerifiedContext?

    private let authService: any AuthServicing
    private var otpExpiresAt: Date?
    private var countdownTask: Task<Void, Never>?
    private var completionTask: Task<Void, Never>?
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "ioscrmapp",
        category: "RegistrationFlow"
    )

    init(authService: any AuthServicing, initialPhone: String = "") {
        self.authService = authService
        phoneNumber = AuthValidator.normalizedPhone(initialPhone)
    }

    deinit {
        countdownTask?.cancel()
        completionTask?.cancel()
    }

    var canSendOTP: Bool {
        AuthValidator.isValidPhone(phoneNumber) && otpCooldownRemaining == 0 && !isLoading
    }

    var canVerifyOTP: Bool {
        !isLoading
            && AuthValidator.isValidPhone(phoneNumber)
            && AuthValidator.isValidRegistrationOTP(otp)
    }

    var canSubmitRegistration: Bool {
        !isLoading
            && verifiedContext != nil
            && AuthValidator.isValidRegistrationPassword(password)
            && !confirmPassword.isEmpty
            && password == confirmPassword
    }

    var otpButtonText: LocalizedTextValue {
        otpCooldownRemaining > 0
            ? .key("auth.otp.resend", arguments: ["\(otpCooldownRemaining)"])
            : .key("auth.otp.send")
    }

    var otpHelperText: LocalizedTextValue {
        guard let otpExpiresAt else {
            return .key("auth.registration.otp.expiryFallback")
        }

        let remainingSeconds = max(60, Int(otpExpiresAt.timeIntervalSinceNow.rounded(.up)))
        let remainingMinutes = max(1, Int(ceil(Double(remainingSeconds) / 60)))
        return .key("auth.registration.otp.expiryDynamic", arguments: ["\(remainingMinutes)"])
    }

    func logRegistrationOpened() {
        logger.info("Registration screen opened")
    }

    func sendOTP() {
        bannerMessage = nil
        shouldShowGoToLoginAction = false
        guard validatePhone() else {
            return
        }

        isLoading = true
        logger.info("Registration OTP send requested")

        Task {
            do {
                let result = try await authService.sendRegistrationOTP(to: phoneNumber)
                otpExpiresAt = result.expiresAt ?? Date().addingTimeInterval(Self.otpValiditySeconds)
                otp = ""
                otpError = nil
                let seconds = max(0, Int(result.resendAvailableAt.timeIntervalSinceNow.rounded(.up)))
                startCountdown(from: seconds)
                bannerTone = .success
                bannerMessage = .key("auth.registration.banner.otpSent")
            } catch {
                apply(error: error, stage: .verify)
            }
            isLoading = false
        }
    }

    func verifyAndContinue(onSuccess: @escaping (RegistrationVerifiedContext) -> Void) {
        clearVerificationMessages()
        shouldShowGoToLoginAction = false

        guard validatePhone(), validateRegistrationOTP() else {
            return
        }

        isLoading = true
        logger.info("Registration OTP verify requested")

        Task {
            do {
                let eligibility = try await authService.checkRegistrationEligibility(phone: phoneNumber)
                let verification = try await authService.verifyRegistrationOTP(
                    phone: eligibility.phoneNumber,
                    code: otp
                )

                let context = RegistrationVerifiedContext(
                    phoneNumber: verification.verifiedPhoneNumber,
                    otpCode: verification.otpCode
                )
                verifiedContext = context
                bannerMessage = nil
                otpError = nil
                password = ""
                confirmPassword = ""
                onSuccess(context)
            } catch {
                apply(error: error, stage: .verify)
            }
            isLoading = false
        }
    }

    func restorePasswordStep(with context: RegistrationVerifiedContext) {
        verifiedContext = context
        passwordError = nil
        confirmPasswordError = nil
        bannerMessage = nil
    }

    func register(onSuccess: @escaping (RegistrationFlowResult) -> Void) {
        clearPasswordMessages()

        guard let verifiedContext else {
            return
        }
        guard validateRegistrationPassword(), validateConfirmPassword() else {
            return
        }

        isLoading = true
        logger.info("Registration submit requested")

        Task {
            do {
                let result = try await authService.register(
                    input: RegistrationSubmitInput(
                        phoneNumber: verifiedContext.phoneNumber,
                        otpCode: verifiedContext.otpCode,
                        password: password
                    )
                )

                bannerTone = .success
                bannerMessage = .key("auth.registration.banner.completed")
                logger.info("Registration success")

                completionTask?.cancel()
                completionTask = Task { [weak self] in
                    do {
                        try await Task.sleep(nanoseconds: 900_000_000)
                    } catch {
                        return
                    }
                    await MainActor.run {
                        self?.isLoading = false
                        onSuccess(.completed(phoneNumber: result.phoneNumber))
                    }
                }
            } catch {
                apply(error: error, stage: .register)
                isLoading = false
            }
        }
    }

    func goToLoginResult() -> RegistrationFlowResult {
        .goToLogin(phoneNumber: phoneNumber)
    }

    private func validatePhone() -> Bool {
        guard AuthValidator.isValidPhone(phoneNumber) else {
            phoneError = AuthError.invalidPhone.textValue
            return false
        }
        phoneError = nil
        return true
    }

    private func validateRegistrationOTP() -> Bool {
        guard AuthValidator.isValidRegistrationOTP(otp) else {
            otpError = AuthError.invalidOTPFormat.textValue
            return false
        }
        otpError = nil
        return true
    }

    private func validateRegistrationPassword() -> Bool {
        guard AuthValidator.isValidRegistrationPassword(password) else {
            passwordError = AuthError.registrationPasswordFormat.textValue
            return false
        }
        passwordError = nil
        return true
    }

    private func validateConfirmPassword() -> Bool {
        guard password == confirmPassword, !confirmPassword.isEmpty else {
            confirmPasswordError = AuthError.passwordMismatch.textValue
            return false
        }
        confirmPasswordError = nil
        return true
    }

    private func clearVerificationMessages() {
        phoneError = nil
        otpError = nil
        bannerMessage = nil
    }

    private func clearPasswordMessages() {
        passwordError = nil
        confirmPasswordError = nil
        bannerMessage = nil
    }

    private func apply(error: Error, stage: RegistrationStage) {
        let authError = (error as? AuthError) ?? .networkUnavailable
        bannerTone = .error
        bannerMessage = authError.textValue

        switch authError {
        case .invalidPhone:
            phoneError = authError.textValue
        case .invalidOTPFormat, .otpInvalid, .otpExpired:
            otpError = authError.textValue
        case let .otpCooldown(secondsRemaining):
            otpCooldownRemaining = secondsRemaining
            startCountdown(from: secondsRemaining)
        case .phoneAlreadyRegistered:
            shouldShowGoToLoginAction = true
        case .registrationPasswordFormat:
            passwordError = authError.textValue
        case .passwordMismatch:
            confirmPasswordError = authError.textValue
        case .invalidPasswordFormat, .invalidCredentials, .accountLocked, .deviceNotUnique, .backend, .featureUnavailable, .networkUnavailable:
            if stage == .register {
                passwordError = nil
                confirmPasswordError = nil
            }
        }
    }

    private func startCountdown(from seconds: Int) {
        countdownTask?.cancel()
        otpCooldownRemaining = seconds

        countdownTask = Task {
            while !Task.isCancelled, otpCooldownRemaining > 0 {
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                } catch {
                    break
                }
                await MainActor.run {
                    otpCooldownRemaining = max(0, otpCooldownRemaining - 1)
                }
            }
        }
    }
}

private enum RegistrationStage {
    case verify
    case register
}
