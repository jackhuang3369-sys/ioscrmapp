import AuthenticationServices
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
    private let uaePassService: UAEPassServicing
    private let sessionStore: SessionStore
    private var countdownTask: Task<Void, Never>?
    private var uaePassSession: ASWebAuthenticationSession?
    private var uaePassPresentationProvider: AuthPresentationContextProvider?

    init(authService: any AuthServicing, uaePassService: UAEPassServicing = MockUAEPassService(), sessionStore: SessionStore) {
        self.authService = authService
        self.uaePassService = uaePassService
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
                    loginMode: selectedMode,
                    authType: LoginAuthType(loginMode: selectedMode)
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

    func loginWithUAEPass() {
        clearMessages()
        isLoading = true

        Task {
            do {
                let config = try await uaePassService.getConfig()
                let fullURL = try buildUAEPassAuthorizeURL(from: config)
                let code = try await presentAuthSession(url: fullURL, scheme: "duapp")

                isLoading = true
                bannerTone = .info
                bannerMessage = .key("auth.uaepass.exchanging")

                let session = try await uaePassService.loginWithCode(
                    code: code,
                    state: config.state,
                    requestId: UUID().uuidString
                )

                sessionStore.signIn(
                    with: session,
                    rememberCredentials: false,
                    phone: session.phoneNumber,
                    password: nil,
                    loginMode: .password,
                    authType: .uaePass
                )
            } catch let error as UAEPassAuthError {
                applyUAEPassError(error)
                isLoading = false
            } catch let error as AuthError {
                apply(error: error)
                isLoading = false
            } catch {
                bannerTone = .error
                bannerMessage = .key("auth.error.networkUnavailable")
                isLoading = false
            }
        }
    }

    private func buildUAEPassAuthorizeURL(from config: UAEPassConfig) throws -> URL {
        guard var components = URLComponents(string: config.authorizeURL) else {
            throw UAEPassAuthError.configFetchFailed
        }
        components.queryItems = [
            URLQueryItem(name: "client_id", value: config.clientId),
            URLQueryItem(name: "redirect_uri", value: config.redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: config.scope),
            URLQueryItem(name: "state", value: config.state),
            URLQueryItem(name: "acr_values", value: config.installedFlowAcrValues),
            URLQueryItem(name: "language", value: config.language)
        ]
        guard let url = components.url else {
            throw UAEPassAuthError.configFetchFailed
        }
        return url
    }

    private func presentAuthSession(url: URL, scheme: String) async throws -> String {
        uaePassPresentationProvider = AuthPresentationContextProvider()

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: scheme
            ) { [weak self] callbackURL, error in
                self?.uaePassPresentationProvider = nil
                self?.uaePassSession = nil

                if let error = error as? ASWebAuthenticationSessionError {
                    switch error.code {
                    case .canceledLogin:
                        continuation.resume(throwing: UAEPassAuthError.userCancelled)
                    default:
                        continuation.resume(throwing: UAEPassAuthError.authSessionFailed(error.localizedDescription))
                    }
                    return
                }

                guard let callbackURL = callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let codeItem = components.queryItems?.first(where: { $0.name == "code" }),
                      let code = codeItem.value,
                      !code.isEmpty
                else {
                    continuation.resume(throwing: UAEPassAuthError.noAuthCode)
                    return
                }

                continuation.resume(returning: code)
            }

            session.prefersEphemeralWebBrowserSession = true
            session.presentationContextProvider = uaePassPresentationProvider

            uaePassSession = session
            session.start()
        }
    }

    private func applyUAEPassError(_ error: UAEPassAuthError) {
        bannerTone = .error
        switch error {
        case .userCancelled:
            bannerMessage = nil
        case .configFetchFailed, .networkUnavailable:
            bannerMessage = .key("auth.error.networkUnavailable")
        default:
            bannerMessage = .literal(error.localizedDescription)
        }
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

    func applyForgotPasswordResult(_ result: ForgotPasswordFlowResult) {
        clearMessages()

        switch result {
        case let .completed(phoneNumber):
            self.phoneNumber = AuthValidator.normalizedPhone(phoneNumber)
            password = ""
            otp = ""
            selectedMode = .password
            sessionStore.updatePreferredLoginMode(.password)
            bannerTone = .success
            bannerMessage = .key("auth.forgot.banner.completed")
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
        case .deviceNotUnique, .featureUnavailable, .tooManyRequests, .networkUnavailable, .phoneAlreadyRegistered, .phoneNotRegistered, .registrationPasswordFormat, .passwordMismatch, .passwordHistoryConflict, .verificationTokenExpired, .sessionInvalidated, .backend:
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
    private var challengeID: String?
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
            && challengeID != nil
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
                challengeID = result.challengeID
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

        guard validatePhone(), validateRegistrationOTP(), let challengeID else {
            return
        }

        isLoading = true
        logger.info("Registration OTP verify requested")

        Task {
            do {
                let eligibility = try await authService.checkRegistrationEligibility(phone: phoneNumber)
                let verification = try await authService.verifyRegistrationOTP(
                    phone: eligibility.phoneNumber,
                    challengeID: challengeID,
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
        case .invalidPasswordFormat, .invalidCredentials, .accountLocked, .deviceNotUnique, .phoneNotRegistered, .passwordHistoryConflict, .verificationTokenExpired, .sessionInvalidated, .backend, .featureUnavailable, .tooManyRequests, .networkUnavailable:
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

@MainActor
final class AuthForgotPasswordViewModel: ObservableObject {
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
    @Published private(set) var isLoading = false
    @Published private(set) var verifiedContext: ForgotPasswordVerifiedContext?

    private let authService: any AuthServicing
    private var challengeID: String?
    private var otpExpiresAt: Date?
    private var countdownTask: Task<Void, Never>?
    private var completionTask: Task<Void, Never>?
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "ioscrmapp",
        category: "ForgotPasswordFlow"
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
            && challengeID != nil
            && AuthValidator.isValidPhone(phoneNumber)
            && AuthValidator.isValidRegistrationOTP(otp)
    }

    var canSubmitPasswordReset: Bool {
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
            return .key("auth.forgot.otp.expiryFallback")
        }

        let remainingSeconds = max(60, Int(otpExpiresAt.timeIntervalSinceNow.rounded(.up)))
        let remainingMinutes = max(1, Int(ceil(Double(remainingSeconds) / 60)))
        return .key("auth.forgot.otp.expiryDynamic", arguments: ["\(remainingMinutes)"])
    }

    func logFlowOpened() {
        logger.info("Forgot password screen opened")
    }

    func sendOTP() {
        clearVerifyMessages()

        guard validatePhone() else {
            return
        }

        isLoading = true
        logger.info("Forgot password otp send requested")

        Task {
            do {
                let checkedPhone = try await authService.checkForgotPasswordUser(phone: phoneNumber)
                let result = try await authService.sendForgotPasswordOTP(to: checkedPhone.phoneNumber)
                phoneNumber = result.phoneNumber
                challengeID = result.challengeID
                otpExpiresAt = result.expiresAt ?? Date().addingTimeInterval(Self.otpValiditySeconds)
                otp = ""
                otpError = nil
                let seconds = max(0, Int(result.resendAvailableAt.timeIntervalSinceNow.rounded(.up)))
                startCountdown(from: seconds)
                bannerTone = .success
                bannerMessage = .key("auth.forgot.banner.otpSent")
            } catch {
                apply(error: error, stage: .verify)
            }
            isLoading = false
        }
    }

    func verifyAndContinue(onSuccess: @escaping (ForgotPasswordVerifiedContext) -> Void) {
        clearVerifyMessages()

        guard validatePhone(), validateOTP(), let challengeID else {
            return
        }

        isLoading = true
        logger.info("Forgot password otp verify requested")

        Task {
            do {
                let checkedPhone = try await authService.checkForgotPasswordUser(phone: phoneNumber)
                let result = try await authService.verifyForgotPasswordOTP(
                    phone: checkedPhone.phoneNumber,
                    challengeID: challengeID,
                    code: otp
                )

                let context = ForgotPasswordVerifiedContext(
                    phoneNumber: result.verifiedPhoneNumber,
                    verificationToken: result.verificationToken
                )
                verifiedContext = context
                password = ""
                confirmPassword = ""
                bannerMessage = nil
                onSuccess(context)
            } catch {
                apply(error: error, stage: .verify)
            }
            isLoading = false
        }
    }

    func restorePasswordStep(with context: ForgotPasswordVerifiedContext) {
        verifiedContext = context
        passwordError = nil
        confirmPasswordError = nil
        bannerMessage = nil
    }

    func resetPassword(onSuccess: @escaping (ForgotPasswordFlowResult) -> Void) {
        clearPasswordMessages()

        guard let verifiedContext else {
            return
        }
        guard validatePassword(), validateConfirmPassword() else {
            return
        }

        isLoading = true
        logger.info("Forgot password submit requested")

        Task {
            do {
                let result = try await authService.resetForgotPassword(
                    input: ForgotPasswordResetInput(
                        phoneNumber: verifiedContext.phoneNumber,
                        verificationToken: verifiedContext.verificationToken,
                        password: password,
                        confirmPassword: confirmPassword
                    )
                )

                bannerTone = .success
                bannerMessage = .key("auth.forgot.banner.completed")

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
                apply(error: error, stage: .password)
                isLoading = false
            }
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

    private func validateOTP() -> Bool {
        guard AuthValidator.isValidRegistrationOTP(otp) else {
            otpError = AuthError.invalidOTPFormat.textValue
            return false
        }
        otpError = nil
        return true
    }

    private func validatePassword() -> Bool {
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

    private func clearVerifyMessages() {
        phoneError = nil
        otpError = nil
        bannerMessage = nil
    }

    private func clearPasswordMessages() {
        passwordError = nil
        confirmPasswordError = nil
        bannerMessage = nil
    }

    private func apply(error: Error, stage: ForgotPasswordStage) {
        let authError = (error as? AuthError) ?? .networkUnavailable
        bannerTone = .error
        bannerMessage = authError.textValue

        switch authError {
        case .invalidPhone, .phoneNotRegistered:
            phoneError = authError.textValue
        case .invalidOTPFormat, .otpInvalid, .otpExpired, .verificationTokenExpired:
            otpError = stage == .verify ? authError.textValue : nil
        case let .otpCooldown(secondsRemaining):
            otpCooldownRemaining = secondsRemaining
            startCountdown(from: secondsRemaining)
        case .registrationPasswordFormat:
            passwordError = authError.textValue
        case .passwordMismatch:
            confirmPasswordError = authError.textValue
        case .passwordHistoryConflict:
            passwordError = authError.textValue
        case .invalidPasswordFormat, .invalidCredentials, .accountLocked, .deviceNotUnique, .phoneAlreadyRegistered, .sessionInvalidated, .backend, .featureUnavailable, .tooManyRequests, .networkUnavailable:
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

private enum ForgotPasswordStage {
    case verify
    case password
}

private final class AuthPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let window = scene.windows.first(where: { $0.isKeyWindow })
        else {
            return UIWindow()
        }
        return window
    }
}
