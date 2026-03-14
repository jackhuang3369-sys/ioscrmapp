import Foundation

struct DeviceIdentityProvider {
    private let defaults: UserDefaults
    private let deviceIDKey = "network.stableDeviceID"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func deviceID() -> String {
        if let existingDeviceID = defaults.string(forKey: deviceIDKey), !existingDeviceID.isEmpty {
            return existingDeviceID
        }

        let newDeviceID = UUID().uuidString.lowercased()
        defaults.set(newDeviceID, forKey: deviceIDKey)
        return newDeviceID
    }
}
