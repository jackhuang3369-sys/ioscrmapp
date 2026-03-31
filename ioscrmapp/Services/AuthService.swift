import Foundation
import os

private let authLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "ioscrmapp",
    category: "Auth"
)

protocol AuthServicing: Sendable {
    func loginWithPassword(phone: String, password: String) async throws -> CustSubInfo
    func sendOTP(to phone: String) async throws -> OTPSendResult
    func loginWithOTP(phone: String, otp: String) async throws -> CustSubInfo
    func logout(authType: LoginAuthType) async throws
    func checkRegistrationEligibility(phone: String) async throws -> RegistrationEligibilityResult
    func sendRegistrationOTP(to phone: String) async throws -> RegistrationOTPSendResult
    func verifyRegistrationOTP(phone: String, challengeID: String, code: String) async throws -> RegistrationOTPVerificationResult
    func register(input: RegistrationSubmitInput) async throws -> RegistrationCompletionResult
    func checkForgotPasswordUser(phone: String) async throws -> ForgotPasswordUserCheckResult
    func sendForgotPasswordOTP(to phone: String) async throws -> ForgotPasswordOTPSendResult
    func verifyForgotPasswordOTP(phone: String, challengeID: String, code: String) async throws -> ForgotPasswordOTPVerificationResult
    func resetForgotPassword(input: ForgotPasswordResetInput) async throws -> ForgotPasswordCompletionResult
}

struct RemoteAuthService: AuthServicing {
    private let serverURL: URL
    private let session: URLSession
    private let contextBuilder: NetworkContextBuilder
    private let client: HTTPClient
    private let registrationRequestEncryptor: RegistrationRequestEncryptor
    private let tokenStore: KeychainAuthTokenStore
    private let loginRequestBuilder: LoginRequestBuilder

    init(
        serverURL: URL,
        session: URLSession = .shared,
        contextBuilder: NetworkContextBuilder = NetworkContextBuilder(),
        tokenStore: KeychainAuthTokenStore = KeychainAuthTokenStore()
    ) {
        self.serverURL = serverURL
        self.session = session
        self.contextBuilder = contextBuilder
        client = HTTPClient(
            baseURL: serverURL,
            session: session,
            contextBuilder: contextBuilder
        )
        registrationRequestEncryptor = RegistrationRequestEncryptor()
        self.tokenStore = tokenStore
        loginRequestBuilder = LoginRequestBuilder(contextBuilder: contextBuilder)
    }

    func loginWithPassword(phone: String, password: String) async throws -> CustSubInfo {
        do {
            // 密码登录先加密密码，再按后端约定的字段组装 `/api/auth/login` 请求。
            let encryptedPassword = try await registrationRequestEncryptor.encryptPassword(password)
            let responseData = try await client.post(
                AuthAPI.login,
                body: loginRequestBuilder.passwordLoginPayload(
                    phone: phone,
                    encryptedPassword: encryptedPassword
                )
            )
            let loginResponse = try LoginResponseMapper.map(
                from: responseData,
                fallbackPhone: AuthValidator.normalizedPhone(phone)
            )
            // 登录成功后立即落库存储 token，后续受保护接口和启动恢复都依赖这份凭证。
            try tokenStore.save(loginResponse.tokens)
            return loginResponse.custSubInfo
        } catch let error as HTTPClient.ClientError {
            throw mapLoginClientError(error)
        } catch let error as KeychainAuthTokenStoreError {
            authLogger.error("Failed to persist login tokens status=\(String(describing: error), privacy: .public)")
            throw AuthError.networkUnavailable
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.networkUnavailable
        }
    }

    func logout(authType: LoginAuthType) async throws {
        do {
            if contextBuilder.shouldRenewAuthentication(for: .protectedRequest) {
                _ = try await contextBuilder.refreshTokens(
                    baseURL: serverURL,
                    session: session,
                    invalidateSessionOnFailure: false
                )
            }

            guard
                let accessToken = tokenStore.loadTokens()?.currentAuthorizationToken(),
                !accessToken.isEmpty
            else {
                throw AuthError.sessionInvalidated
            }

            _ = try await client.post(
                AuthAPI.logout(authorizationToken: accessToken),
                body: loginRequestBuilder.logoutPayload(authType: authType)
            )
        } catch let error as HTTPClient.ClientError {
            throw mapLogoutClientError(error)
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.networkUnavailable
        }
    }

    func sendOTP(to phone: String) async throws -> OTPSendResult {
        let now = Date()

        do {
            // 发送登录验证码只负责取回冷却和过期信息，页面倒计时统一基于这里的结果驱动。
            let data = try await client.post(
                AuthAPI.sendLoginOTP,
                body: loginRequestBuilder.loginOTPSendPayload(phone: phone)
            )
            let resendSeconds = max(1, ResponseDataValue.int(in: data, keys: [
                "resendSeconds",
                "resendInterval",
                "cooldownSeconds"
            ]) ?? 60)
            let expiresAt: Date
            if let expirySeconds = ResponseDataValue.int(in: data, keys: [
                "expireSeconds",
                "expiresIn",
                "otpValidSeconds",
                "ttl"
            ]) {
                expiresAt = now.addingTimeInterval(TimeInterval(expirySeconds))
            } else if let rawTimestamp = ResponseDataValue.double(in: data, keys: [
                "expiresAt",
                "otpExpiresAt"
            ]) {
                expiresAt = ResponseDataValue.date(fromTimestamp: rawTimestamp)
            } else {
                expiresAt = now.addingTimeInterval(5 * 60)
            }

            return OTPSendResult(
                resendAvailableAt: now.addingTimeInterval(TimeInterval(resendSeconds)),
                expiresAt: expiresAt,
                demoCode: ""
            )
        } catch let error as HTTPClient.ClientError {
            throw mapLoginClientError(error)
        } catch {
            throw AuthError.networkUnavailable
        }
    }

    func loginWithOTP(phone: String, otp: String) async throws -> CustSubInfo {
        do {
            // OTP 登录 happy path 直接走 `/api/auth/login`，不再额外调用 verify 接口。
            let responseData = try await client.post(
                AuthAPI.login,
                body: loginRequestBuilder.otpLoginPayload(phone: phone, otp: otp)
            )
            let loginResponse = try LoginResponseMapper.map(
                from: responseData,
                fallbackPhone: AuthValidator.normalizedPhone(phone)
            )
            try tokenStore.save(loginResponse.tokens)
            return loginResponse.custSubInfo
        } catch let error as HTTPClient.ClientError {
            throw mapLoginClientError(error)
        } catch let error as KeychainAuthTokenStoreError {
            authLogger.error("Failed to persist login tokens status=\(String(describing: error), privacy: .public)")
            throw AuthError.networkUnavailable
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.networkUnavailable
        }
    }

    func checkRegistrationEligibility(phone: String) async throws -> RegistrationEligibilityResult {
        // 注册第一步只校验手机号是否可注册，后续流程都复用标准化后的手机号。
        _ = try await postRegistrationRequest(
            AuthAPI.checkRegistrationEligibility,
            payload: ["mobile": AuthValidator.localPhoneDigits(phone)]
        )
        return RegistrationEligibilityResult(phoneNumber: AuthValidator.normalizedPhone(phone))
    }

    func sendRegistrationOTP(to phone: String) async throws -> RegistrationOTPSendResult {
        let now = Date()
        // 注册验证码与登录验证码接口不同，但冷却/过期时间的解析策略保持一致。
        let data = try await postRegistrationRequest(
            AuthAPI.sendRegistrationOTP,
            payload: ["mobile": AuthValidator.localPhoneDigits(phone)]
        )

        let resendSeconds = max(1, ResponseDataValue.int(in: data, keys: [
            "resendSeconds",
            "resendInterval",
            "cooldownSeconds"
        ]) ?? 60)

        let expiresAt: Date?
        if let expirySeconds = ResponseDataValue.int(in: data, keys: [
            "expireSeconds",
            "expiresIn",
            "otpValidSeconds",
            "ttl"
        ]) {
            expiresAt = now.addingTimeInterval(TimeInterval(expirySeconds))
        } else if let rawTimestamp = ResponseDataValue.double(in: data, keys: [
            "expiresAt",
            "otpExpiresAt"
        ]) {
            expiresAt = ResponseDataValue.date(fromTimestamp: rawTimestamp)
        } else {
            expiresAt = nil
        }

        guard let challengeID = ResponseDataValue.string(in: data, keys: ["challengeId"]) else {
            throw AuthError.networkUnavailable
        }

        return RegistrationOTPSendResult(
            challengeID: challengeID,
            resendAvailableAt: now.addingTimeInterval(TimeInterval(resendSeconds)),
            expiresAt: expiresAt,
            demoCode: ""
        )
    }

    func verifyRegistrationOTP(
        phone: String,
        challengeID: String,
        code: String
    ) async throws -> RegistrationOTPVerificationResult {
        // 注册流程要求先完成验证码校验，成功后才允许进入最终注册提交。
        let data = try await postRegistrationRequest(
            AuthAPI.verifyRegistrationOTP,
            payload: [
                "mobile": AuthValidator.localPhoneDigits(phone),
                "otpCode": code,
                "challengeId": challengeID
            ]
        )
        guard let isVerified = data.boolValue else {
            throw AuthError.networkUnavailable
        }
        guard isVerified else {
            throw AuthError.otpInvalid
        }

        return RegistrationOTPVerificationResult(
            verifiedPhoneNumber: AuthValidator.normalizedPhone(phone),
            otpCode: code
        )
    }

    func checkForgotPasswordUser(phone: String) async throws -> ForgotPasswordUserCheckResult {
        do {
            let data = try await client.post(
                AuthAPI.checkForgotPasswordUser,
                body: loginRequestBuilder.forgotPasswordCheckPayload(phone: phone)
            )
            guard let exists = data.boolValue else {
                throw AuthError.networkUnavailable
            }
            guard exists else {
                throw AuthError.phoneNotRegistered
            }
            return ForgotPasswordUserCheckResult(phoneNumber: AuthValidator.normalizedPhone(phone))
        } catch let error as HTTPClient.ClientError {
            throw mapForgotPasswordClientError(error)
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.networkUnavailable
        }
    }

    func sendForgotPasswordOTP(to phone: String) async throws -> ForgotPasswordOTPSendResult {
        let now = Date()

        do {
            let data = try await client.post(
                AuthAPI.sendForgotPasswordOTP,
                body: loginRequestBuilder.forgotPasswordOTPSendPayload(phone: phone)
            )

            guard let challengeID = ResponseDataValue.string(in: data, keys: ["challengeId"]) else {
                throw AuthError.networkUnavailable
            }

            let resendSeconds = max(1, ResponseDataValue.int(in: data, keys: [
                "resendSeconds",
                "resendInterval",
                "cooldownSeconds"
            ]) ?? 60)

            let expiresAt: Date?
            if let expirySeconds = ResponseDataValue.int(in: data, keys: [
                "expireSeconds",
                "expiresIn",
                "otpValidSeconds",
                "ttl"
            ]) {
                expiresAt = now.addingTimeInterval(TimeInterval(expirySeconds))
            } else if let rawTimestamp = ResponseDataValue.double(in: data, keys: [
                "expiresAt",
                "otpExpiresAt"
            ]) {
                expiresAt = ResponseDataValue.date(fromTimestamp: rawTimestamp)
            } else {
                expiresAt = nil
            }

            return ForgotPasswordOTPSendResult(
                phoneNumber: AuthValidator.normalizedPhone(phone),
                challengeID: challengeID,
                resendAvailableAt: now.addingTimeInterval(TimeInterval(resendSeconds)),
                expiresAt: expiresAt
            )
        } catch let error as HTTPClient.ClientError {
            throw mapForgotPasswordClientError(error)
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.networkUnavailable
        }
    }

    func verifyForgotPasswordOTP(
        phone: String,
        challengeID: String,
        code: String
    ) async throws -> ForgotPasswordOTPVerificationResult {
        do {
            let data = try await client.post(
                AuthAPI.verifyForgotPasswordOTP,
                body: loginRequestBuilder.forgotPasswordOTPVerifyPayload(
                    phone: phone,
                    challengeID: challengeID,
                    code: code
                )
            )

            guard let verificationToken = ResponseDataValue.string(in: data, keys: ["verificationToken"]) else {
                throw AuthError.networkUnavailable
            }

            return ForgotPasswordOTPVerificationResult(
                verifiedPhoneNumber: AuthValidator.normalizedPhone(phone),
                verificationToken: verificationToken
            )
        } catch let error as HTTPClient.ClientError {
            throw mapForgotPasswordClientError(error)
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.networkUnavailable
        }
    }

    func resetForgotPassword(input: ForgotPasswordResetInput) async throws -> ForgotPasswordCompletionResult {
        do {
            let encryptedPassword = try await registrationRequestEncryptor.encryptPassword(input.password)
            let encryptedConfirmPassword = try await registrationRequestEncryptor.encryptPassword(input.confirmPassword)
            _ = try await client.post(
                AuthAPI.resetForgotPassword,
                body: loginRequestBuilder.forgotPasswordResetPayload(
                    phone: input.phoneNumber,
                    verificationToken: input.verificationToken,
                    encryptedPassword: encryptedPassword,
                    encryptedConfirmPassword: encryptedConfirmPassword
                )
            )
            return ForgotPasswordCompletionResult(phoneNumber: AuthValidator.normalizedPhone(input.phoneNumber))
        } catch let error as HTTPClient.ClientError {
            throw mapForgotPasswordClientError(error)
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.networkUnavailable
        }
    }

    func register(input: RegistrationSubmitInput) async throws -> RegistrationCompletionResult {
        do {
            // 注册提交阶段仍然只上传加密后的密码，避免明文密码进入传输层。
            let encryptedPassword = try await registrationRequestEncryptor.encryptPassword(input.password)
            _ = try await client.post(
                AuthAPI.register,
                body: [
                    "mobile": AuthValidator.localPhoneDigits(input.phoneNumber),
                    "otpCode": input.otpCode,
                    "password": encryptedPassword
                ]
            )
        } catch let error as HTTPClient.ClientError {
            throw mapClientError(error)
        } catch {
            throw AuthError.networkUnavailable
        }

        return RegistrationCompletionResult(phoneNumber: AuthValidator.normalizedPhone(input.phoneNumber))
    }

    private func postRegistrationRequest(
        _ endpoint: HTTPClient.Endpoint,
        payload: [String: Any]
    ) async throws -> HTTPClient.ResponseData {
        do {
            // 注册相关接口统一复用这一层，保证错误映射和网络异常处理口径一致。
            return try await client.post(endpoint, body: payload)
        } catch let error as HTTPClient.ClientError {
            throw mapClientError(error)
        } catch {
            throw AuthError.networkUnavailable
        }
    }

    private func mapClientError(_ error: HTTPClient.ClientError) -> AuthError {
        switch error {
        case let .business(code, message, traceID):
            return RegistrationRemoteErrorMapper.map(code: code, message: message, traceID: traceID)
        case .httpStatus, .invalidJSON, .invalidResponse, .networkUnavailable:
            return .networkUnavailable
        }
    }

    private func mapLoginClientError(_ error: HTTPClient.ClientError) -> AuthError {
        switch error {
        case let .business(code, message, traceID):
            return LoginRemoteErrorMapper.map(code: code, message: message, traceID: traceID)
        case .httpStatus, .invalidJSON, .invalidResponse, .networkUnavailable:
            return .networkUnavailable
        }
    }

    private func mapForgotPasswordClientError(_ error: HTTPClient.ClientError) -> AuthError {
        switch error {
        case let .business(code, message, traceID):
            return ForgotPasswordRemoteErrorMapper.map(code: code, message: message, traceID: traceID)
        case .httpStatus, .invalidJSON, .invalidResponse, .networkUnavailable:
            return .networkUnavailable
        }
    }

    private func mapLogoutClientError(_ error: HTTPClient.ClientError) -> AuthError {
        switch error {
        case .httpStatus(401):
            return .sessionInvalidated
        case let .business(code, message, traceID):
            if code == 40_014 || code == 40_015 {
                return .sessionInvalidated
            }
            return .backend(message: message, traceID: traceID)
        case .httpStatus, .invalidJSON, .invalidResponse, .networkUnavailable:
            return .networkUnavailable
        }
    }
}

actor MockAuthService: AuthServicing {
    private struct OTPRecord {
        let challengeID: String
        let code: String
        let resendAvailableAt: Date
        let expiresAt: Date
    }

    private struct MockAccount {
        let password: String
        let displayName: String
    }

    private let cooldownSeconds = 60
    private let expirySeconds = 300
    private let lockThreshold = 5
    private let lockDurationSeconds = 15 * 60
    private let tokenStore: KeychainAuthTokenStore

    private var loginOTPByPhone: [String: OTPRecord] = [:]
    private var registrationOTPByPhone: [String: OTPRecord] = [:]
    private var forgotPasswordOTPByPhone: [String: OTPRecord] = [:]
    private var forgotPasswordVerificationTokenByPhone: [String: String] = [:]
    private var failuresByPhone: [String: Int] = [:]
    private var lockUntilByPhone: [String: Date] = [:]
    private var accountsByPhone: [String: MockAccount] = [
        "971521234567": MockAccount(password: AuthValidator.demoPassword, displayName: "Ahmed Mohammed"),
        "971555551111": MockAccount(password: "DuPass1!", displayName: "Mariam Al Suwaidi")
    ]

    init(tokenStore: KeychainAuthTokenStore = KeychainAuthTokenStore()) {
        self.tokenStore = tokenStore
    }

    func loginWithPassword(phone: String, password: String) async throws -> CustSubInfo {
        try await Task.sleep(nanoseconds: 700_000_000)
        let normalizedPhone = AuthValidator.normalizedPhone(phone)
        try checkLock(for: normalizedPhone)
        try maybeSimulateNetworkFailure(phone: normalizedPhone)

        guard let account = accountsByPhone[normalizedPhone], account.password == password else {
            throw registerFailure(for: normalizedPhone)
        }

        clearFailures(for: normalizedPhone)
        do {
            try persistMockTokens(for: normalizedPhone)
        } catch {
            authLogger.error("Failed to persist mock login tokens status=\(String(describing: error), privacy: .public)")
            throw AuthError.networkUnavailable
        }
        return demoSession(phone: normalizedPhone, displayName: account.displayName)
    }

    func sendOTP(to phone: String) async throws -> OTPSendResult {
        try await Task.sleep(nanoseconds: 500_000_000)
        let normalizedPhone = AuthValidator.normalizedPhone(phone)
        try checkLock(for: normalizedPhone)
        try maybeSimulateNetworkFailure(phone: normalizedPhone)

        if let current = loginOTPByPhone[normalizedPhone], current.resendAvailableAt > Date() {
            throw AuthError.otpCooldown(
                secondsRemaining: max(1, Int(current.resendAvailableAt.timeIntervalSinceNow.rounded(.up)))
            )
        }

        let now = Date()
        let record = OTPRecord(
            challengeID: UUID().uuidString,
            code: AuthValidator.demoOTP,
            resendAvailableAt: now.addingTimeInterval(TimeInterval(cooldownSeconds)),
            expiresAt: now.addingTimeInterval(TimeInterval(expirySeconds))
        )
        loginOTPByPhone[normalizedPhone] = record

        return OTPSendResult(
            resendAvailableAt: record.resendAvailableAt,
            expiresAt: record.expiresAt,
            demoCode: record.code
        )
    }

    func loginWithOTP(phone: String, otp: String) async throws -> CustSubInfo {
        try await Task.sleep(nanoseconds: 700_000_000)
        let normalizedPhone = AuthValidator.normalizedPhone(phone)
        try checkLock(for: normalizedPhone)
        try maybeSimulateNetworkFailure(phone: normalizedPhone)

        guard accountsByPhone[normalizedPhone] != nil else {
            throw registerFailure(for: normalizedPhone)
        }
        guard let record = loginOTPByPhone[normalizedPhone] else {
            throw AuthError.otpExpired
        }
        guard record.expiresAt > Date() else {
            loginOTPByPhone.removeValue(forKey: normalizedPhone)
            throw AuthError.otpExpired
        }
        guard otp == record.code else {
            throw registerFailure(for: normalizedPhone)
        }

        clearFailures(for: normalizedPhone)
        loginOTPByPhone.removeValue(forKey: normalizedPhone)
        do {
            try persistMockTokens(for: normalizedPhone)
        } catch {
            authLogger.error("Failed to persist mock login tokens status=\(String(describing: error), privacy: .public)")
            throw AuthError.networkUnavailable
        }
        return demoSession(
            phone: normalizedPhone,
            displayName: accountsByPhone[normalizedPhone]?.displayName ?? "Ahmed Mohammed"
        )
    }

    func logout(authType: LoginAuthType) async throws {
        _ = authType
        try await Task.sleep(nanoseconds: 300_000_000)
    }

    func checkRegistrationEligibility(phone: String) async throws -> RegistrationEligibilityResult {
        try await Task.sleep(nanoseconds: 350_000_000)
        let normalizedPhone = AuthValidator.normalizedPhone(phone)
        try maybeSimulateNetworkFailure(phone: normalizedPhone)

        if accountsByPhone[normalizedPhone] != nil {
            throw AuthError.phoneAlreadyRegistered
        }

        return RegistrationEligibilityResult(phoneNumber: normalizedPhone)
    }

    func sendRegistrationOTP(to phone: String) async throws -> RegistrationOTPSendResult {
        try await Task.sleep(nanoseconds: 500_000_000)
        let normalizedPhone = AuthValidator.normalizedPhone(phone)
        try maybeSimulateNetworkFailure(phone: normalizedPhone)

        if let current = registrationOTPByPhone[normalizedPhone], current.resendAvailableAt > Date() {
            throw AuthError.otpCooldown(
                secondsRemaining: max(1, Int(current.resendAvailableAt.timeIntervalSinceNow.rounded(.up)))
            )
        }

        let now = Date()
        let record = OTPRecord(
            challengeID: UUID().uuidString,
            code: AuthValidator.demoRegistrationOTP,
            resendAvailableAt: now.addingTimeInterval(TimeInterval(cooldownSeconds)),
            expiresAt: now.addingTimeInterval(TimeInterval(expirySeconds))
        )
        registrationOTPByPhone[normalizedPhone] = record

        return RegistrationOTPSendResult(
            challengeID: record.challengeID,
            resendAvailableAt: record.resendAvailableAt,
            expiresAt: nil,
            demoCode: record.code
        )
    }

    func verifyRegistrationOTP(
        phone: String,
        challengeID: String,
        code: String
    ) async throws -> RegistrationOTPVerificationResult {
        try await Task.sleep(nanoseconds: 600_000_000)
        let normalizedPhone = AuthValidator.normalizedPhone(phone)
        try maybeSimulateNetworkFailure(phone: normalizedPhone)

        guard let record = registrationOTPByPhone[normalizedPhone] else {
            throw AuthError.otpExpired
        }
        if normalizedPhone.hasSuffix("3333") {
            registrationOTPByPhone.removeValue(forKey: normalizedPhone)
            throw AuthError.otpExpired
        }
        guard record.expiresAt > Date() else {
            registrationOTPByPhone.removeValue(forKey: normalizedPhone)
            throw AuthError.otpExpired
        }
        guard record.challengeID == challengeID else {
            throw AuthError.otpInvalid
        }
        guard code == record.code else {
            throw AuthError.otpInvalid
        }

        return RegistrationOTPVerificationResult(
            verifiedPhoneNumber: normalizedPhone,
            otpCode: code
        )
    }

    func checkForgotPasswordUser(phone: String) async throws -> ForgotPasswordUserCheckResult {
        try await Task.sleep(nanoseconds: 350_000_000)
        let normalizedPhone = AuthValidator.normalizedPhone(phone)
        try maybeSimulateNetworkFailure(phone: normalizedPhone)

        guard accountsByPhone[normalizedPhone] != nil else {
            throw AuthError.phoneNotRegistered
        }

        return ForgotPasswordUserCheckResult(phoneNumber: normalizedPhone)
    }

    func sendForgotPasswordOTP(to phone: String) async throws -> ForgotPasswordOTPSendResult {
        try await Task.sleep(nanoseconds: 500_000_000)
        let normalizedPhone = AuthValidator.normalizedPhone(phone)
        try maybeSimulateNetworkFailure(phone: normalizedPhone)

        guard accountsByPhone[normalizedPhone] != nil else {
            throw AuthError.phoneNotRegistered
        }

        if let current = forgotPasswordOTPByPhone[normalizedPhone], current.resendAvailableAt > Date() {
            throw AuthError.otpCooldown(
                secondsRemaining: max(1, Int(current.resendAvailableAt.timeIntervalSinceNow.rounded(.up)))
            )
        }

        let now = Date()
        let record = OTPRecord(
            challengeID: UUID().uuidString,
            code: AuthValidator.demoRegistrationOTP,
            resendAvailableAt: now.addingTimeInterval(TimeInterval(cooldownSeconds)),
            expiresAt: now.addingTimeInterval(TimeInterval(expirySeconds))
        )
        forgotPasswordOTPByPhone[normalizedPhone] = record

        return ForgotPasswordOTPSendResult(
            phoneNumber: normalizedPhone,
            challengeID: record.challengeID,
            resendAvailableAt: record.resendAvailableAt,
            expiresAt: record.expiresAt
        )
    }

    func verifyForgotPasswordOTP(
        phone: String,
        challengeID: String,
        code: String
    ) async throws -> ForgotPasswordOTPVerificationResult {
        try await Task.sleep(nanoseconds: 600_000_000)
        let normalizedPhone = AuthValidator.normalizedPhone(phone)
        try maybeSimulateNetworkFailure(phone: normalizedPhone)

        guard let record = forgotPasswordOTPByPhone[normalizedPhone] else {
            throw AuthError.otpExpired
        }
        guard record.expiresAt > Date() else {
            forgotPasswordOTPByPhone.removeValue(forKey: normalizedPhone)
            throw AuthError.otpExpired
        }
        guard record.challengeID == challengeID else {
            throw AuthError.otpInvalid
        }
        guard record.code == code else {
            throw AuthError.otpInvalid
        }

        let verificationToken = "verification-\(UUID().uuidString)"
        forgotPasswordVerificationTokenByPhone[normalizedPhone] = verificationToken
        return ForgotPasswordOTPVerificationResult(
            verifiedPhoneNumber: normalizedPhone,
            verificationToken: verificationToken
        )
    }

    func resetForgotPassword(input: ForgotPasswordResetInput) async throws -> ForgotPasswordCompletionResult {
        try await Task.sleep(nanoseconds: 700_000_000)
        let normalizedPhone = AuthValidator.normalizedPhone(input.phoneNumber)
        try maybeSimulateNetworkFailure(phone: normalizedPhone)

        guard accountsByPhone[normalizedPhone] != nil else {
            throw AuthError.phoneNotRegistered
        }
        guard AuthValidator.isValidRegistrationPassword(input.password) else {
            throw AuthError.registrationPasswordFormat
        }
        guard input.password == input.confirmPassword else {
            throw AuthError.passwordMismatch
        }
        guard forgotPasswordVerificationTokenByPhone[normalizedPhone] == input.verificationToken else {
            throw AuthError.verificationTokenExpired
        }

        if let account = accountsByPhone[normalizedPhone], account.password == input.password {
            throw AuthError.passwordHistoryConflict
        }

        accountsByPhone[normalizedPhone] = MockAccount(
            password: input.password,
            displayName: accountsByPhone[normalizedPhone]?.displayName ?? "Ahmed Mohammed"
        )
        forgotPasswordVerificationTokenByPhone.removeValue(forKey: normalizedPhone)
        forgotPasswordOTPByPhone.removeValue(forKey: normalizedPhone)
        return ForgotPasswordCompletionResult(phoneNumber: normalizedPhone)
    }

    func register(input: RegistrationSubmitInput) async throws -> RegistrationCompletionResult {
        try await Task.sleep(nanoseconds: 700_000_000)
        let normalizedPhone = AuthValidator.normalizedPhone(input.phoneNumber)
        try maybeSimulateNetworkFailure(phone: normalizedPhone)

        guard accountsByPhone[normalizedPhone] == nil else {
            throw AuthError.phoneAlreadyRegistered
        }
        guard AuthValidator.isValidRegistrationPassword(input.password) else {
            throw AuthError.registrationPasswordFormat
        }
        guard let record = registrationOTPByPhone[normalizedPhone] else {
            throw AuthError.otpExpired
        }
        guard record.expiresAt > Date() else {
            registrationOTPByPhone.removeValue(forKey: normalizedPhone)
            throw AuthError.otpExpired
        }
        guard input.otpCode == record.code else {
            throw AuthError.otpInvalid
        }

        accountsByPhone[normalizedPhone] = MockAccount(
            password: input.password,
            displayName: "New DU User"
        )
        registrationOTPByPhone.removeValue(forKey: normalizedPhone)
        authLogger.info("Mock registration success phone=\(normalizedPhone, privacy: .private(mask: .hash))")

        return RegistrationCompletionResult(phoneNumber: normalizedPhone)
    }

    private func demoSession(phone: String, displayName: String) -> CustSubInfo {
        CustSubInfo(
            displayName: displayName,
            phoneNumber: AuthValidator.formattedPhone(phone),
            greeting: "Good Morning",
            balanceText: "128.50 AED",
            userID: "mock-\(phone)",
            serviceNumber: AuthValidator.normalizedPhone(phone)
        )
    }

    private func persistMockTokens(for phone: String) throws {
        let accessToken = AuthToken(
            token: "mock-access-\(phone)-\(UUID().uuidString)",
            expirationTime: mockExpirationString(after: 24 * 60 * 60),
            renewal: nil
        )
        let refreshToken = AuthToken(
            token: "mock-refresh-\(phone)-\(UUID().uuidString)",
            expirationTime: mockExpirationString(after: 7 * 24 * 60 * 60),
            renewal: nil
        )
        try tokenStore.save(
            AuthSessionTokens(accessToken: accessToken, refreshToken: refreshToken)
        )
    }

    private func mockExpirationString(after timeInterval: TimeInterval) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: Date().addingTimeInterval(timeInterval))
    }

    private func checkLock(for phone: String) throws {
        if let lockUntil = lockUntilByPhone[phone], lockUntil > Date() {
            throw AuthError.accountLocked(until: lockUntil)
        }
        if let lockUntil = lockUntilByPhone[phone], lockUntil <= Date() {
            lockUntilByPhone.removeValue(forKey: phone)
            failuresByPhone[phone] = 0
        }
    }

    private func clearFailures(for phone: String) {
        failuresByPhone[phone] = 0
        lockUntilByPhone.removeValue(forKey: phone)
    }

    private func registerFailure(for phone: String) -> AuthError {
        let currentFailures = (failuresByPhone[phone] ?? 0) + 1
        failuresByPhone[phone] = currentFailures

        if currentFailures >= lockThreshold {
            let lockUntil = Date().addingTimeInterval(TimeInterval(lockDurationSeconds))
            lockUntilByPhone[phone] = lockUntil
            return .accountLocked(until: lockUntil)
        }

        return .invalidCredentials(remainingAttempts: lockThreshold - currentFailures)
    }

    private func maybeSimulateNetworkFailure(phone: String) throws {
        if phone.hasSuffix("0000") {
            throw AuthError.networkUnavailable
        }
    }
}

private enum RegistrationRemoteErrorMapper {
    static func map(code: Int, message: String, traceID: String?) -> AuthError {
        switch code {
        case 40_004:
            return .phoneAlreadyRegistered
        case 40_017:
            return .registrationPasswordFormat
        case 50_002:
            return .otpInvalid
        case 50_003:
            return .otpExpired
        default:
            let lowered = message.lowercased()
            if lowered.contains("registered") || message.contains("已注册") {
                return .phoneAlreadyRegistered
            }
            return .backend(
                message: message.isEmpty ? "Registration request failed." : message,
                traceID: traceID
            )
        }
    }
}

private enum ForgotPasswordRemoteErrorMapper {
    static func map(code: Int, message: String, traceID: String?) -> AuthError {
        switch code {
        case 40_001:
            return .phoneNotRegistered
        case 40_010:
            return .passwordMismatch
        case 40_011:
            return .passwordHistoryConflict
        case 40_014, 40_015:
            return .verificationTokenExpired
        case 40_017:
            return .registrationPasswordFormat
        case 50_002, 50_004, 50_013:
            return .otpInvalid
        case 50_003:
            return .otpExpired
        default:
            let lowered = message.lowercased()
            if lowered.contains("not exist") || lowered.contains("not found") {
                return .phoneNotRegistered
            }
            if lowered.contains("expired") && lowered.contains("token") {
                return .verificationTokenExpired
            }
            return .backend(
                message: message.isEmpty ? "Forgot password request failed." : message,
                traceID: traceID
            )
        }
    }
}

private struct LoginRequestBuilder {
    private let contextBuilder: NetworkContextBuilder

    init(contextBuilder: NetworkContextBuilder) {
        self.contextBuilder = contextBuilder
    }

    func passwordLoginPayload(phone: String, encryptedPassword: String) -> [String: Any] {
        // 密码登录使用 `authType = 1`，手机号按后端要求传本地号段。
        var payload: [String: Any] = [
            "authType": "1",
            "serviceNumber": AuthValidator.localPhoneDigits(phone),
            "password": encryptedPassword
        ]
        payload.merge(contextBuilder.loginParameters(), uniquingKeysWith: { _, new in new })
        return payload
    }

    func otpLoginPayload(phone: String, otp: String) -> [String: Any] {
        // 验证码登录使用 `authType = 2`，字段名保持和现有后端契约一致。
        var payload: [String: Any] = [
            "authType": "2",
            "phonenumber": AuthValidator.localPhoneDigits(phone),
            "smsCode": otp
        ]
        payload.merge(contextBuilder.loginParameters(), uniquingKeysWith: { _, new in new })
        return payload
    }

    func logoutPayload(authType: LoginAuthType) -> [String: Any] {
        var payload: [String: Any] = [
            "authType": authType.rawValue
        ]
        payload.merge(contextBuilder.loginParameters(), uniquingKeysWith: { _, new in new })
        return payload
    }

    func loginOTPSendPayload(phone: String) -> [String: Any] {
        // 发送登录 OTP 只放业务字段，公共环境参数统一由 context builder 注入。
        var payload: [String: Any] = [
            "type": "Mobile",
            "phoneNumber": AuthValidator.localPhoneDigits(phone)
        ]
        payload.merge(contextBuilder.otpParameters(), uniquingKeysWith: { _, new in new })
        return payload
    }

    func forgotPasswordCheckPayload(phone: String) -> [String: Any] {
        var payload: [String: Any] = [
            "phoneNumber": AuthValidator.localPhoneDigits(phone)
        ]
        payload.merge(contextBuilder.authCommonContext(), uniquingKeysWith: { _, new in new })
        return payload
    }

    func forgotPasswordOTPSendPayload(phone: String) -> [String: Any] {
        var payload: [String: Any] = [
            "type": "Mobile",
            "bizType": "FORGOT_PASSWORD",
            "phoneNumber": AuthValidator.localPhoneDigits(phone)
        ]
        payload.merge(contextBuilder.otpParameters(), uniquingKeysWith: { _, new in new })
        return payload
    }

    func forgotPasswordOTPVerifyPayload(
        phone: String,
        challengeID: String,
        code: String
    ) -> [String: Any] {
        var payload: [String: Any] = [
            "type": "Mobile",
            "bizType": "FORGOT_PASSWORD",
            "phoneNumber": AuthValidator.localPhoneDigits(phone),
            "challengeId": challengeID,
            "code": code
        ]
        payload.merge(contextBuilder.otpContextIncludingDevice(), uniquingKeysWith: { _, new in new })
        return payload
    }

    func forgotPasswordResetPayload(
        phone: String,
        verificationToken: String,
        encryptedPassword: String,
        encryptedConfirmPassword: String
    ) -> [String: Any] {
        var payload: [String: Any] = [
            "phonenumber": AuthValidator.localPhoneDigits(phone),
            "verificationToken": verificationToken,
            "newPass": encryptedPassword,
            "confirmPass": encryptedConfirmPassword
        ]
        payload["deviceId"] = DeviceIdentityProvider().deviceID()
        return payload
    }
}

private struct ParsedLoginResponse {
    let custSubInfo: CustSubInfo
    let tokens: AuthSessionTokens
}

private enum LoginResponseMapper {
    static func map(from responseData: HTTPClient.ResponseData, fallbackPhone: String) throws -> ParsedLoginResponse {
        guard let dictionary = responseData.objectValue else {
            throw HTTPClient.ClientError.invalidResponse
        }
        guard let user = dictionary["user"]?.objectValue else {
            throw HTTPClient.ClientError.invalidResponse
        }
        guard
            let tokenDictionary = dictionary["token"]?.objectValue,
            let accessToken = parseToken(tokenDictionary["accessToken"])
        else {
            throw HTTPClient.ClientError.invalidResponse
        }

        // 登录接口返回的 `user` 和 `token` 在这里收敛成应用内部统一的会话模型。
        let displayName = ResponseDataValue.string(in: user, keys: ["username"]) ?? fallbackPhone
        let phoneNumber = ResponseDataValue.string(in: user, keys: ["mobile"]) ?? fallbackPhone
        let custSubInfo = CustSubInfo(
            displayName: displayName,
            phoneNumber: AuthValidator.formattedPhone(phoneNumber),
            greeting: "Good Morning",
            balanceText: "0.00 AED",
            userID: ResponseDataValue.string(in: user, keys: ["userId"]),
            serviceNumber: AuthValidator.normalizedPhone(phoneNumber),
            subscriberKey: nil
        )

        return ParsedLoginResponse(
            custSubInfo: custSubInfo,
            tokens: AuthSessionTokens(
                accessToken: accessToken,
                refreshToken: parseToken(tokenDictionary["refreshToken"])
            )
        )
    }

    private static func parseToken(_ responseData: HTTPClient.ResponseData?) -> AuthToken? {
        guard
            let dictionary = responseData?.objectValue,
            let token = ResponseDataValue.string(in: dictionary, keys: ["token"]),
            !token.isEmpty
        else {
            return nil
        }

        // 续约逻辑依赖 `expTime` 和 `renewal` 来判断 access/refresh token 的有效期。
        let renewal = ResponseDataValue.int(in: dictionary, keys: ["renewal"]).map(Int64.init)
        return AuthToken(
            token: token,
            expirationTime: ResponseDataValue.string(in: dictionary, keys: ["expTime"]),
            renewal: renewal
        )
    }
}

private enum LoginRemoteErrorMapper {
    static func map(code: Int, message: String, traceID: String?) -> AuthError {
        switch code {
        case 40_001, 40_005:
            return .invalidCredentials(remainingAttempts: 0)
        case 40_002, 40_013:
            return .accountLocked(until: Date())
        case 41_003, 703:
            return .deviceNotUnique
        case 50_002, 50_004:
            return .otpInvalid
        case 50_003:
            return .otpExpired
        default:
            let lowered = message.lowercased()
            if lowered.contains("locked") {
                return .accountLocked(until: Date())
            }
            if lowered.contains("another device") {
                return .deviceNotUnique
            }
            if lowered.contains("otp") && lowered.contains("expire") {
                return .otpExpired
            }
            if lowered.contains("otp") {
                return .otpInvalid
            }
            if lowered.contains("password") || lowered.contains("user") {
                return .invalidCredentials(remainingAttempts: 0)
            }
            return .backend(
                message: message.isEmpty ? "Login request failed." : message,
                traceID: traceID
            )
        }
    }
}

private enum ResponseDataValue {
    static func int(in responseData: HTTPClient.ResponseData, keys: [String]) -> Int? {
        guard let dictionary = responseData.objectValue else {
            return nil
        }
        return int(in: dictionary, keys: keys)
    }

    static func int(in dictionary: [String: HTTPClient.ResponseData], keys: [String]) -> Int? {
        for key in keys {
            if let value = dictionary[key]?.intValue {
                return value
            }
            if let stringValue = dictionary[key]?.stringValue, let value = Int(stringValue) {
                return value
            }
        }
        return nil
    }

    static func double(in responseData: HTTPClient.ResponseData, keys: [String]) -> Double? {
        guard let dictionary = responseData.objectValue else {
            return nil
        }
        return double(in: dictionary, keys: keys)
    }

    static func double(in dictionary: [String: HTTPClient.ResponseData], keys: [String]) -> Double? {
        for key in keys {
            if let value = dictionary[key]?.doubleValue {
                return value
            }
            if let stringValue = dictionary[key]?.stringValue, let value = Double(stringValue) {
                return value
            }
        }
        return nil
    }

    static func string(in responseData: HTTPClient.ResponseData, keys: [String]) -> String? {
        guard let dictionary = responseData.objectValue else {
            return nil
        }
        return string(in: dictionary, keys: keys)
    }

    static func string(in dictionary: [String: HTTPClient.ResponseData], keys: [String]) -> String? {
        for key in keys {
            if let value = dictionary[key]?.stringValue, !value.isEmpty {
                return value
            }
        }
        return nil
    }

    static func date(fromTimestamp timestamp: Double) -> Date {
        timestamp > 1_000_000_000_000
            ? Date(timeIntervalSince1970: timestamp / 1_000)
            : Date(timeIntervalSince1970: timestamp)
    }
}
