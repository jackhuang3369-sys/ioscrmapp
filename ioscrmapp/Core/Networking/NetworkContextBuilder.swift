import Foundation

#if canImport(UIKit)
import UIKit
#endif

struct NetworkContextBuilder: Sendable {
    private static let sharedTokenStore = KeychainAuthTokenStore()
    private static let sharedRefreshCoordinator = AuthRefreshCoordinator(tokenStore: sharedTokenStore)

    private let tokenStore: KeychainAuthTokenStore
    private let refreshCoordinator: AuthRefreshCoordinator

    init(
        tokenStore: KeychainAuthTokenStore = NetworkContextBuilder.sharedTokenStore,
        refreshCoordinator: AuthRefreshCoordinator? = nil
    ) {
        self.tokenStore = tokenStore
        if let refreshCoordinator {
            self.refreshCoordinator = refreshCoordinator
        } else if tokenStore == NetworkContextBuilder.sharedTokenStore {
            self.refreshCoordinator = NetworkContextBuilder.sharedRefreshCoordinator
        } else {
            self.refreshCoordinator = AuthRefreshCoordinator(tokenStore: tokenStore)
        }
    }

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

    func loginParameters() -> [String: String] {
        [
            "loginPlatform": "iOS",
            "osVersion": osVersion,
            "deviceBrand": deviceBrand,
            "deviceModel": deviceModel,
            "loginLatitude": coordinateLatitude,
            "loginLongitude": coordinateLongitude,
            "appVersion": appVersion,
            "privacyVersion": privacyVersion,
            "networkType": networkType,
            "deviceId": DeviceIdentityProvider().deviceID()
        ]
    }

    func otpParameters() -> [String: String] {
        [
            "platform": "iOS",
            "osVersion": osVersion,
            "appVersion": appVersion,
            "lang": languageCode,
            "loginLatitude": coordinateLatitude,
            "loginLongitude": coordinateLongitude
        ]
    }

    func authCommonContext() -> [String: String] {
        [
            "platform": "iOS",
            "osVersion": osVersion,
            "appVersion": appVersion,
            "lang": languageCode,
            "deviceId": DeviceIdentityProvider().deviceID()
        ]
    }

    func otpContextIncludingDevice() -> [String: String] {
        var parameters = otpParameters()
        parameters["deviceId"] = DeviceIdentityProvider().deviceID()
        return parameters
    }

    func headers(requiresAuthorization: Bool) -> [String: String] {
        var headers = ["timeZoneCode": timeZoneCode]

        if
            requiresAuthorization,
            let accessToken = tokenStore.loadTokens()?.currentAuthorizationToken(),
            !accessToken.isEmpty
        {
            headers["Authorization"] = "Bearer \(accessToken)"
        }

        return headers
    }

    func shouldRenewAuthentication(for trigger: AuthSessionRenewalTrigger) -> Bool {
        tokenStore.loadTokens()?.shouldRenewAuthentication(for: trigger) ?? false
    }

    func hasUsableAuthentication() -> Bool {
        tokenStore.loadTokens()?.hasUsableAuthentication() ?? false
    }

    func renewAuthenticationIfNeeded(
        for trigger: AuthSessionRenewalTrigger,
        baseURL: URL,
        session: URLSession
    ) async throws -> Bool {
        guard shouldRenewAuthentication(for: trigger) else {
            return false
        }

        // 启动恢复登录态和请求前主动续约都通过这里复用同一套判断与刷新请求。
        _ = try await refreshTokens(baseURL: baseURL, session: session)
        return true
    }

    func refreshTokens(baseURL: URL, session: URLSession) async throws -> AuthSessionTokens {
        try await refreshCoordinator.refreshTokens(
            baseURL: baseURL,
            session: session,
            contextBuilder: self
        )
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

    private var coordinateLatitude: String {
        String(defaultLatitude)
    }

    private var coordinateLongitude: String {
        String(defaultLongitude)
    }

    private var privacyVersion: String {
        "1.0"
    }

    private var networkType: String {
        "UNKNOWN"
    }

    private var deviceBrand: String {
        "Apple"
    }

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

    private var deviceModel: String {
        deviceType
    }

    private var deviceName: String {
        #if canImport(UIKit)
        return UIDevice.current.name
        #else
        return "iPhone"
        #endif
    }
}
