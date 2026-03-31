import Combine
import Foundation

/// 多个并发请求共享同一个续约任务，避免 refresh token 轮换时互相覆盖。
actor AuthRefreshCoordinator {
    private let tokenStore: KeychainAuthTokenStore
    private var refreshTask: Task<AuthSessionTokens, Error>?

    init(tokenStore: KeychainAuthTokenStore = KeychainAuthTokenStore()) {
        self.tokenStore = tokenStore
    }

    func refreshTokens(
        baseURL: URL,
        session: URLSession,
        contextBuilder: NetworkContextBuilder,
        invalidateSessionOnFailure: Bool = true
    ) async throws -> AuthSessionTokens {
        if let refreshTask {
            return try await refreshTask.value
        }

        let task = Task<AuthSessionTokens, Error> {
            guard
                let storedTokens = tokenStore.loadTokens(),
                let refreshToken = storedTokens.refreshToken,
                refreshToken.isValid(),
                !refreshToken.token.isEmpty
            else {
                throw HTTPClient.ClientError.invalidResponse
            }

            // 启动恢复和请求失败后的重试都走同一个续约协调器，
            // 这样 token 轮换、持久化和单飞行为才能保持一致。
            let client = HTTPClient(
                baseURL: baseURL,
                session: session,
                contextBuilder: contextBuilder
            )
            let tokens = try await client.refreshAuthTokens(refreshToken: refreshToken.token)
            try tokenStore.save(tokens)
            return tokens
        }

        refreshTask = task
        defer { refreshTask = nil }

        do {
            return try await task.value
        } catch {
            if invalidateSessionOnFailure {
                try? tokenStore.clear()
                NotificationCenter.default.post(name: .authSessionInvalidated, object: nil)
            }
            throw error
        }
    }
}

/// 在安全存储和普通存储之上协调内存态登录信息，统一管理会话生命周期。
@MainActor
final class SessionStore: ObservableObject {
    @Published var custSubInfo: CustSubInfo?
    @Published private(set) var rememberedPhone: String
    @Published private(set) var rememberedPassword: String
    @Published private(set) var preferredLoginMode: LoginMode
    @Published private(set) var currentAuthType: LoginAuthType
    @Published private(set) var isRestoringAuthentication = false

    private let tokenStore: KeychainAuthTokenStore
    private let rememberedCredentialsStore: KeychainRememberedCredentialsStore
    private let defaultsStore: SessionUserDefaultsStore
    private let contextBuilder: NetworkContextBuilder
    private var cancellables: Set<AnyCancellable> = []
    private var authExpiryTask: Task<Void, Never>?

    init(
        defaults: UserDefaults = .standard,
        tokenStore: KeychainAuthTokenStore = KeychainAuthTokenStore(),
        rememberedCredentialsStore: KeychainRememberedCredentialsStore = KeychainRememberedCredentialsStore()
    ) {
        self.tokenStore = tokenStore
        self.rememberedCredentialsStore = rememberedCredentialsStore
        defaultsStore = SessionUserDefaultsStore(defaults: defaults)
        let refreshCoordinator = AuthRefreshCoordinator(tokenStore: tokenStore)
        contextBuilder = NetworkContextBuilder(
            tokenStore: tokenStore,
            refreshCoordinator: refreshCoordinator
        )

        let rememberedCredentials = SessionStore.loadRememberedCredentials(
            defaultsStore: defaultsStore,
            rememberedCredentialsStore: rememberedCredentialsStore
        )
        rememberedPhone = rememberedCredentials?.phoneNumber ?? ""
        rememberedPassword = rememberedCredentials?.password ?? ""
        preferredLoginMode = defaultsStore.loadPreferredLoginMode()
        currentAuthType = defaultsStore.loadPersistedAuthType() ?? .password
        custSubInfo = defaultsStore.loadPersistedCustSubInfo()

        NotificationCenter.default.publisher(for: .authSessionInvalidated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.clearSession(clearTokens: false)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .authTokensDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.syncSessionFromPersistence(clearExpiredTokens: true)
            }
            .store(in: &cancellables)

        syncSessionFromPersistence(clearExpiredTokens: true)
    }

    deinit {
        authExpiryTask?.cancel()
    }

    var isAuthenticated: Bool {
        custSubInfo != nil && (tokenStore.loadTokens()?.hasUsableAuthentication() ?? false)
    }

    var authenticatedCustSubInfo: CustSubInfo? {
        isAuthenticated ? custSubInfo : nil
    }

    var hasRememberedCredentials: Bool {
        !rememberedPhone.isEmpty || !rememberedPassword.isEmpty
    }

    var shouldRestoreAuthenticationOnLaunch: Bool {
        contextBuilder.shouldRenewAuthentication(for: .startupRestore)
    }

    func signIn(
        with custSubInfo: CustSubInfo,
        rememberCredentials: Bool,
        phone: String,
        password: String?,
        loginMode: LoginMode,
        authType: LoginAuthType
    ) {
        // 登录成功后，先把内存态与非敏感持久化状态一次性对齐。
        self.custSubInfo = custSubInfo
        defaultsStore.savePersistedCustSubInfo(custSubInfo)
        preferredLoginMode = loginMode
        defaultsStore.savePreferredLoginMode(loginMode)
        currentAuthType = authType
        defaultsStore.savePersistedAuthType(authType)

        if rememberCredentials {
            let storedCredentials = RememberedCredentials(
                phoneNumber: phone,
                password: loginMode == .password ? (password ?? "") : ""
            )
            rememberedPhone = storedCredentials.phoneNumber
            rememberedPassword = storedCredentials.password
            try? rememberedCredentialsStore.save(storedCredentials)
        } else {
            clearRememberedCredentials()
        }

        syncSessionFromPersistence(clearExpiredTokens: true)
    }

    func signOut() {
        // 退出登录同时清理展示态和 token，避免后续请求继续带上旧凭证。
        clearSession(clearTokens: false)
        try? tokenStore.clear()
    }

    func updatePreferredLoginMode(_ loginMode: LoginMode) {
        preferredLoginMode = loginMode
        defaultsStore.savePreferredLoginMode(loginMode)
    }

    func updateSubscriberKey(_ subscriberKey: String?) {
        guard let custSubInfo else {
            return
        }

        let normalizedSubscriberKey = subscriberKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedSubscriberKey = normalizedSubscriberKey?.isEmpty == false ? normalizedSubscriberKey : nil

        guard custSubInfo.subscriberKey != resolvedSubscriberKey else {
            return
        }

        let updatedSession = CustSubInfo(
            displayName: custSubInfo.displayName,
            phoneNumber: custSubInfo.phoneNumber,
            greeting: custSubInfo.greeting,
            balanceText: custSubInfo.balanceText,
            userID: custSubInfo.userID,
            serviceNumber: custSubInfo.serviceNumber,
            subscriberKey: resolvedSubscriberKey
        )

        self.custSubInfo = updatedSession
        defaultsStore.savePersistedCustSubInfo(updatedSession)
    }

    func restoreAuthenticationIfNeeded(
        baseURL: URL?,
        session urlSession: URLSession = .shared
    ) async {
        syncSessionFromPersistence(clearExpiredTokens: true)

        guard let baseURL else {
            return
        }

        guard contextBuilder.shouldRenewAuthentication(for: .startupRestore) else {
            return
        }

        isRestoringAuthentication = true
        defer {
            isRestoringAuthentication = false
            syncSessionFromPersistence(clearExpiredTokens: true)
        }

        do {
            // 启动恢复登录态与请求前主动续约共用同一套判断和刷新入口，
            // 这样两条路径对“何时刷新、如何刷新”的口径始终一致。
            _ = try await contextBuilder.renewAuthenticationIfNeeded(
                for: .startupRestore,
                baseURL: baseURL,
                session: urlSession
            )
        } catch {
            return
        }
    }

    private func syncSessionFromPersistence(clearExpiredTokens: Bool) {
        authExpiryTask?.cancel()

        let storedTokens = tokenStore.loadTokens()
        guard storedTokens?.hasUsableAuthentication() == true else {
            clearSession(clearTokens: clearExpiredTokens && storedTokens != nil)
            return
        }

        if custSubInfo == nil {
            custSubInfo = defaultsStore.loadPersistedCustSubInfo()
        }

        guard let authExpiryDate = storedTokens?.authenticationExpiryDate else {
            return
        }

        let timeInterval = authExpiryDate.timeIntervalSinceNow
        guard timeInterval > 0 else {
            clearSession(clearTokens: clearExpiredTokens)
            return
        }

        authExpiryTask = Task { [weak self] in
            // 不做轮询，而是按 token 的最近失效时间安排一次性同步，减少无意义唤醒。
            let nanoseconds = UInt64(max(0, timeInterval) * 1_000_000_000)
            do {
                try await Task.sleep(nanoseconds: nanoseconds)
            } catch {
                return
            }

            await MainActor.run {
                self?.syncSessionFromPersistence(clearExpiredTokens: true)
            }
        }
    }

    private func clearSession(clearTokens: Bool) {
        authExpiryTask?.cancel()
        custSubInfo = nil
        currentAuthType = .password
        defaultsStore.clearPersistedCustSubInfo()
        defaultsStore.clearPersistedAuthType()
        if clearTokens {
            try? tokenStore.clear()
        }
    }

    private func clearRememberedCredentials() {
        rememberedPhone = ""
        rememberedPassword = ""
        defaultsStore.clearLegacyRememberedPhone()
        try? rememberedCredentialsStore.clear()
    }

    private static func loadRememberedCredentials(
        defaultsStore: SessionUserDefaultsStore,
        rememberedCredentialsStore: KeychainRememberedCredentialsStore
    ) -> RememberedCredentials? {
        if let storedCredentials = rememberedCredentialsStore.loadCredentials() {
            return storedCredentials
        }

        guard let legacyPhone = defaultsStore.loadLegacyRememberedPhone(), !legacyPhone.isEmpty else {
            return nil
        }

        let migratedCredentials = RememberedCredentials(phoneNumber: legacyPhone, password: "")
        try? rememberedCredentialsStore.save(migratedCredentials)
        defaultsStore.clearLegacyRememberedPhone()
        return migratedCredentials
    }
}

extension SessionStore {
    static var previewAuthenticated: SessionStore {
        let defaults = UserDefaults(suiteName: "preview.auth") ?? .standard
        let tokenStore = KeychainAuthTokenStore(
            service: "com.ioscrmapp.preview.auth",
            account: "session.tokens",
            memoryOnly: true
        )
        try? tokenStore.save(
            AuthSessionTokens(
                accessToken: AuthToken(
                    token: "preview-access-token",
                    expirationTime: "2099-01-01 00:00:00",
                    renewal: nil
                ),
                refreshToken: AuthToken(
                    token: "preview-refresh-token",
                    expirationTime: "2099-01-08 00:00:00",
                    renewal: nil
                )
            )
        )

        let store = SessionStore(
            defaults: defaults,
            tokenStore: tokenStore,
            rememberedCredentialsStore: KeychainRememberedCredentialsStore(
                service: "com.ioscrmapp.preview.auth",
                account: "remembered.credentials",
                memoryOnly: true
            )
        )
        store.custSubInfo = CustSubInfo(
            displayName: "Ahmed Mohammed",
            phoneNumber: AuthValidator.demoPhone,
            greeting: "Good Morning",
            balanceText: "128.50 AED",
            userID: "preview-user",
            serviceNumber: AuthValidator.demoPhone,
            subscriberKey: "preview-subscriber-key"
        )
        store.currentAuthType = .password
        return store
    }
}
