import Combine
import Foundation
import Security

extension Notification.Name {
    static let authSessionInvalidated = Notification.Name("auth.session.invalidated")
}

struct KeychainAuthTokenStore: Sendable, Equatable {
    private static let memoryStorage = InMemoryAuthTokenStorage()

    private let service: String
    private let account: String
    private let memoryOnly: Bool

    init(
        service: String = "com.ioscrmapp.auth",
        account: String = "session.tokens",
        memoryOnly: Bool = false
    ) {
        self.service = service
        self.account = account
        self.memoryOnly = memoryOnly
    }

    func save(_ tokens: AuthSessionTokens) throws {
        if memoryOnly {
            Self.memoryStorage.save(tokens)
            return
        }

        let encoder = JSONEncoder()
        let data = try encoder.encode(tokens)

        var query = keychainQuery
        query[kSecValueData as String] = data

        SecItemDelete(keychainQuery as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainAuthTokenStoreError.unexpectedStatus(status)
        }
    }

    func loadTokens() -> AuthSessionTokens? {
        if memoryOnly {
            return Self.memoryStorage.load()
        }

        var query = keychainQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status != errSecItemNotFound else {
            return nil
        }
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return try? JSONDecoder().decode(AuthSessionTokens.self, from: data)
    }

    func clear() throws {
        if memoryOnly {
            Self.memoryStorage.clear()
            return
        }

        let status = SecItemDelete(keychainQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainAuthTokenStoreError.unexpectedStatus(status)
        }
    }

    private var keychainQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
    }
}

enum KeychainAuthTokenStoreError: Error {
    case unexpectedStatus(OSStatus)
}

private final class InMemoryAuthTokenStorage: @unchecked Sendable {
    private let lock = NSLock()
    private var tokens: AuthSessionTokens?

    func save(_ tokens: AuthSessionTokens) {
        lock.lock()
        self.tokens = tokens
        lock.unlock()
    }

    func load() -> AuthSessionTokens? {
        lock.lock()
        let value = tokens
        lock.unlock()
        return value
    }

    func clear() {
        lock.lock()
        tokens = nil
        lock.unlock()
    }
}

actor AuthRefreshCoordinator {
    private static let responseWrapperSuccessCodes: Set<Int> = [200, 201, 204, 205, 206, 207, 208, 209, 211, 212, 20_000]

    private let tokenStore: KeychainAuthTokenStore
    private var refreshTask: Task<AuthSessionTokens, Error>?

    init(tokenStore: KeychainAuthTokenStore = KeychainAuthTokenStore()) {
        self.tokenStore = tokenStore
    }

    func refreshTokens(
        baseURL: URL,
        session: URLSession,
        timeZoneCode: String
    ) async throws -> AuthSessionTokens {
        if let refreshTask {
            return try await refreshTask.value
        }

        let task = Task<AuthSessionTokens, Error> {
            guard let refreshToken = tokenStore.loadTokens()?.refreshToken?.token, !refreshToken.isEmpty else {
                throw HTTPClient.ClientError.invalidResponse
            }

            var request = URLRequest(url: baseURL.appendingPathComponent("/ser-user-auth/api/auth/refresh"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(timeZoneCode, forHTTPHeaderField: "timeZoneCode")
            request.httpBody = try JSONSerialization.data(
                withJSONObject: ["refreshToken": refreshToken]
            )

            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw HTTPClient.ClientError.invalidResponse
            }
            guard (200 ... 299).contains(httpResponse.statusCode) else {
                throw HTTPClient.ClientError.httpStatus(httpResponse.statusCode)
            }

            let tokens = try Self.parseTokens(from: data)
            try tokenStore.save(tokens)
            return tokens
        }

        refreshTask = task
        defer { refreshTask = nil }

        do {
            return try await task.value
        } catch {
            try? tokenStore.clear()
            NotificationCenter.default.post(name: .authSessionInvalidated, object: nil)
            throw error
        }
    }

    private static func parseTokens(from data: Data) throws -> AuthSessionTokens {
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        guard let payload = jsonObject as? [String: Any] else {
            throw HTTPClient.ClientError.invalidJSON
        }

        guard let code = payloadInt(in: payload, keys: ["code"]) else {
            throw HTTPClient.ClientError.invalidResponse
        }

        let message = payloadString(in: payload, keys: ["msg", "message"]) ?? ""
        let traceID = payloadString(in: payload, keys: ["traceId"])

        guard responseWrapperSuccessCodes.contains(code) else {
            throw HTTPClient.ClientError.business(code: code, message: message, traceID: traceID)
        }

        guard let tokenPayload = payload["data"] as? [String: Any] else {
            throw HTTPClient.ClientError.invalidResponse
        }
        guard let accessToken = parseToken(in: tokenPayload, key: "accessToken") else {
            throw HTTPClient.ClientError.invalidResponse
        }

        return AuthSessionTokens(
            accessToken: accessToken,
            refreshToken: parseToken(in: tokenPayload, key: "refreshToken")
        )
    }

    private static func parseToken(in payload: [String: Any], key: String) -> AuthToken? {
        guard
            let tokenPayload = payload[key] as? [String: Any],
            let token = payloadString(in: tokenPayload, keys: ["token"]),
            !token.isEmpty
        else {
            return nil
        }

        return AuthToken(
            token: token,
            expirationTime: payloadString(in: tokenPayload, keys: ["expTime"]),
            renewal: payloadInt64(in: tokenPayload, keys: ["renewal"])
        )
    }

    private static func payloadString(in payload: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = payload[key] as? String, !value.isEmpty {
                return value
            }
        }
        return nil
    }

    private static func payloadInt(in payload: [String: Any], keys: [String]) -> Int? {
        for key in keys {
            if let value = payload[key] as? Int {
                return value
            }
            if let value = payload[key] as? NSNumber {
                return value.intValue
            }
            if let value = payload[key] as? String, let intValue = Int(value) {
                return intValue
            }
        }
        return nil
    }

    private static func payloadInt64(in payload: [String: Any], keys: [String]) -> Int64? {
        for key in keys {
            if let value = payload[key] as? Int64 {
                return value
            }
            if let value = payload[key] as? NSNumber {
                return value.int64Value
            }
            if let value = payload[key] as? String, let intValue = Int64(value) {
                return intValue
            }
        }
        return nil
    }
}

@MainActor
final class SessionStore: ObservableObject {
    @Published var session: UserSession?
    @Published private(set) var rememberedPhone: String
    @Published private(set) var preferredLoginMode: LoginMode

    private let defaults: UserDefaults
    private let tokenStore: KeychainAuthTokenStore
    private var cancellables: Set<AnyCancellable> = []
    private let rememberedPhoneKey = "auth.rememberedPhone"
    private let preferredModeKey = "auth.preferredMode"

    init(
        defaults: UserDefaults = .standard,
        tokenStore: KeychainAuthTokenStore = KeychainAuthTokenStore()
    ) {
        self.defaults = defaults
        self.tokenStore = tokenStore
        rememberedPhone = defaults.string(forKey: rememberedPhoneKey) ?? ""
        preferredLoginMode = LoginMode(rawValue: defaults.string(forKey: preferredModeKey) ?? "") ?? .password

        NotificationCenter.default.publisher(for: .authSessionInvalidated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.session = nil
            }
            .store(in: &cancellables)
    }

    var isAuthenticated: Bool {
        session != nil
    }

    func signIn(
        with session: UserSession,
        rememberPhone: Bool,
        phone: String,
        loginMode: LoginMode
    ) {
        self.session = session
        preferredLoginMode = loginMode
        defaults.set(loginMode.rawValue, forKey: preferredModeKey)

        if rememberPhone {
            rememberedPhone = phone
            defaults.set(phone, forKey: rememberedPhoneKey)
        } else {
            rememberedPhone = ""
            defaults.removeObject(forKey: rememberedPhoneKey)
        }
    }

    func signOut() {
        session = nil
        try? tokenStore.clear()
    }

    func updatePreferredLoginMode(_ loginMode: LoginMode) {
        preferredLoginMode = loginMode
        defaults.set(loginMode.rawValue, forKey: preferredModeKey)
    }
}

extension SessionStore {
    static var previewAuthenticated: SessionStore {
        let store = SessionStore(defaults: UserDefaults(suiteName: "preview.auth") ?? .standard)
        store.session = UserSession(
            displayName: "Ahmed Mohammed",
            phoneNumber: AuthValidator.demoPhone,
            greeting: "Good Morning",
            balanceText: "128.50 AED"
        )
        return store
    }
}
