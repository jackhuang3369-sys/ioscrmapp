import Combine
import Foundation

@MainActor
final class SessionStore: ObservableObject {
    @Published var session: UserSession?
    @Published private(set) var rememberedPhone: String
    @Published private(set) var preferredLoginMode: LoginMode

    private let defaults: UserDefaults
    private let rememberedPhoneKey = "auth.rememberedPhone"
    private let preferredModeKey = "auth.preferredMode"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        rememberedPhone = defaults.string(forKey: rememberedPhoneKey) ?? ""
        preferredLoginMode = LoginMode(rawValue: defaults.string(forKey: preferredModeKey) ?? "") ?? .password
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
            greetingKey: "home.greeting.morning",
            balanceAmount: "128.50"
        )
        return store
    }
}
