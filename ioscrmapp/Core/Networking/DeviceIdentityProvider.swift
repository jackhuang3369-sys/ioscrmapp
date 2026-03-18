import Foundation
import Security

struct DeviceIdentityProvider {
    private let service = "com.yourapp.device"
    private let account = "stableDeviceID"

    func deviceID() -> String {
        if let existing = loadFromKeychain() {
            return existing
        }

        let newID = UUID().uuidString.lowercased()
        saveToKeychain(newID)
        return newID
    }
}

// MARK: - Keychain
private extension DeviceIdentityProvider {

    func loadFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data,
              let string = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return string
    }

    func saveToKeychain(_ value: String) {
        let data = value.data(using: .utf8)!

        // 先删旧的（避免重复）
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ] as CFDictionary)

        // 再写入
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]

        SecItemAdd(query as CFDictionary, nil)
    }
}
