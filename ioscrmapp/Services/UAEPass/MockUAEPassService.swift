import Foundation
import os

private let uaePassLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "ioscrmapp",
    category: "UAEPass"
)

/// 模拟 UAE Pass 服务（前端独立模拟，不依赖后端）
/// 默认使用此实现
actor MockUAEPassService: UAEPassServicing {
    private let tokenStore: KeychainAuthTokenStore

    init(tokenStore: KeychainAuthTokenStore = KeychainAuthTokenStore()) {
        self.tokenStore = tokenStore
    }

    func getConfig() async throws -> UAEPassConfig {
        try await Task.sleep(nanoseconds: 400_000_000)
        return UAEPassConfig(
            authorizeURL: "https://stg-id.uaepass.ae/authorize",
            clientId: "mock-client-id",
            redirectUri: "duapp://uaepass/callback",
            language: "en",
            environment: "staging",
            scope: "openid profile urn:uaepass:profile",
            installedFlowAcrValues: "urn:digitalid:authentication:flow:mobileondevice",
            fallbackFlowAcrValues: "urn:safelayer:tws:policies:authentication:level:low",
            state: "mock-state-\(UUID().uuidString)"
        )
    }

    func loginWithCode(code: String, state: String, requestId: String) async throws -> CustSubInfo {
        try await Task.sleep(nanoseconds: 800_000_000)
        _ = code; _ = state; _ = requestId

        try persistMockTokens(for: "uaepass-user")

        uaePassLogger.info("Mock UAE Pass login successful")
        return CustSubInfo(
            displayName: "UAE Pass User",
            phoneNumber: "+971501234567",
            greeting: "Good Morning",
            balanceText: "200.00 AED",
            userID: "mock-uaepass-user",
            serviceNumber: "971501234567",
            subscriberKey: nil
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
}