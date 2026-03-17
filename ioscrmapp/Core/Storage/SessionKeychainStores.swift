import Foundation
import Security

extension Notification.Name {
    static let authSessionInvalidated = Notification.Name("auth.session.invalidated")
    static let authTokensDidChange = Notification.Name("auth.tokens.didChange")
}

struct RememberedCredentials: Codable, Equatable, Sendable {
    let phoneNumber: String
    let password: String
}

/// Stores token material in Keychain so auth credentials never fall back to `UserDefaults`.
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
            postTokensDidChange()
            return
        }

        let data = try JSONEncoder().encode(tokens)
        var query = keychainQuery
        query[kSecValueData as String] = data

        SecItemDelete(keychainQuery as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainAuthTokenStoreError.unexpectedStatus(status)
        }
        postTokensDidChange()
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
            postTokensDidChange()
            return
        }

        let status = SecItemDelete(keychainQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainAuthTokenStoreError.unexpectedStatus(status)
        }
        postTokensDidChange()
    }

    private var keychainQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
    }

    private func postTokensDidChange() {
        NotificationCenter.default.post(name: .authTokensDidChange, object: nil)
    }
}

enum KeychainAuthTokenStoreError: Error {
    case unexpectedStatus(OSStatus)
}

/// Stores remember-me credentials separately from the session payload, still inside Keychain.
struct KeychainRememberedCredentialsStore: Sendable, Equatable {
    private static let memoryStorage = InMemoryRememberedCredentialsStorage()

    private let service: String
    private let account: String
    private let memoryOnly: Bool

    init(
        service: String = "com.ioscrmapp.auth",
        account: String = "remembered.credentials",
        memoryOnly: Bool = false
    ) {
        self.service = service
        self.account = account
        self.memoryOnly = memoryOnly
    }

    func save(_ credentials: RememberedCredentials) throws {
        if memoryOnly {
            Self.memoryStorage.save(credentials)
            return
        }

        let data = try JSONEncoder().encode(credentials)
        var query = keychainQuery
        query[kSecValueData as String] = data

        SecItemDelete(keychainQuery as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainAuthTokenStoreError.unexpectedStatus(status)
        }
    }

    func loadCredentials() -> RememberedCredentials? {
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

        return try? JSONDecoder().decode(RememberedCredentials.self, from: data)
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

private final class InMemoryRememberedCredentialsStorage: @unchecked Sendable {
    private let lock = NSLock()
    private var credentials: RememberedCredentials?

    func save(_ credentials: RememberedCredentials) {
        lock.lock()
        self.credentials = credentials
        lock.unlock()
    }

    func load() -> RememberedCredentials? {
        lock.lock()
        let value = credentials
        lock.unlock()
        return value
    }

    func clear() {
        lock.lock()
        credentials = nil
        lock.unlock()
    }
}
