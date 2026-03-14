import Foundation

#if canImport(UIKit)
import UIKit
#endif

struct NetworkContextBuilder: Sendable {
    func parameters(includeDeviceInfo: Bool) -> [String: Any] {
        var parameters: [String: Any] = [
            "appVersion": appVersion,
            "osVersion": osVersion,
            "platform": "iOS",
            "lang": languageCode,
            "serialNo": UUID().uuidString.replacingOccurrences(of: "-", with: ""),
            "longitude": defaultLongitude,
            "latitude": defaultLatitude
        ]

        guard includeDeviceInfo else {
            return parameters
        }

        parameters["osName"] = osName
        parameters["deviceType"] = deviceType
        parameters["deviceName"] = deviceName
        parameters["deviceId"] = DeviceIdentityProvider().deviceID()
        return parameters
    }

    func headers(requiresAuthorization: Bool) -> [String: String] {
        _ = requiresAuthorization
        return ["timeZoneCode": timeZoneCode]
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    private var osVersion: String {
        #if canImport(UIKit)
        return UIDevice.current.systemVersion
        #else
        return ProcessInfo.processInfo.operatingSystemVersionString
        #endif
    }

    private var languageCode: String {
        Locale.preferredLanguages.first ?? Locale.current.identifier
    }

    private var timeZoneCode: String {
        TimeZone.current.identifier
    }

    private var defaultLatitude: Double { 25.2048 }
    private var defaultLongitude: Double { 55.2708 }

    private var osName: String {
        #if canImport(UIKit)
        return UIDevice.current.systemName
        #else
        return "iOS"
        #endif
    }

    private var deviceType: String {
        #if canImport(UIKit)
        return UIDevice.current.model
        #else
        return "iPhone"
        #endif
    }

    private var deviceName: String {
        #if canImport(UIKit)
        return UIDevice.current.name
        #else
        return "iPhone"
        #endif
    }
}
