import Foundation

protocol UAEPassOAuthHandling: Sendable {
    func performOAuth(config: UAEPassConfig) async throws -> CustSubInfo
}

struct OAuthSession: Sendable, Equatable {
    let requestId: String
    let state: String
    let initiatedAt: Date
    let config: UAEPassConfig
}
