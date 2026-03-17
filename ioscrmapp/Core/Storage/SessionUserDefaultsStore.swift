import Foundation

/// Persists only non-sensitive auth shell state in `UserDefaults`.
struct SessionUserDefaultsStore {
    private let defaults: UserDefaults
    private let preferredModeKey: String
    private let persistedCustSubInfoKey: String
    private let legacyRememberedPhoneKey: String

    init(
        defaults: UserDefaults = .standard,
        preferredModeKey: String = "auth.preferredMode",
        persistedCustSubInfoKey: String = "auth.userSession",
        legacyRememberedPhoneKey: String = "auth.rememberedPhone"
    ) {
        self.defaults = defaults
        self.preferredModeKey = preferredModeKey
        self.persistedCustSubInfoKey = persistedCustSubInfoKey
        self.legacyRememberedPhoneKey = legacyRememberedPhoneKey
    }

    func loadPreferredLoginMode() -> LoginMode {
        LoginMode(rawValue: defaults.string(forKey: preferredModeKey) ?? "") ?? .password
    }

    func savePreferredLoginMode(_ loginMode: LoginMode) {
        defaults.set(loginMode.rawValue, forKey: preferredModeKey)
    }

    func loadPersistedCustSubInfo() -> CustSubInfo? {
        guard let data = defaults.data(forKey: persistedCustSubInfoKey) else {
            return nil
        }
        return try? JSONDecoder().decode(CustSubInfo.self, from: data)
    }

    func savePersistedCustSubInfo(_ custSubInfo: CustSubInfo) {
        guard let data = try? JSONEncoder().encode(custSubInfo) else {
            return
        }
        defaults.set(data, forKey: persistedCustSubInfoKey)
    }

    func clearPersistedCustSubInfo() {
        defaults.removeObject(forKey: persistedCustSubInfoKey)
    }

    func loadLegacyRememberedPhone() -> String? {
        defaults.string(forKey: legacyRememberedPhoneKey)
    }

    func clearLegacyRememberedPhone() {
        defaults.removeObject(forKey: legacyRememberedPhoneKey)
    }
}
