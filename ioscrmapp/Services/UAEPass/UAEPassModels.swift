import Foundation

// MARK: - UAE Pass Configuration

struct UAEPassConfig: Codable, Equatable, Sendable {
    let authorizeURL: String
    let clientId: String
    let redirectUri: String
    let language: String
    let environment: String
    let scope: String
    let installedFlowAcrValues: String
    let fallbackFlowAcrValues: String
    let state: String
}

// MARK: - Authentication State

enum UAEPassAuthState: Equatable, Sendable {
    case idle
    case configLoading
    case configReady(UAEPassConfig)
    case authenticating
    case authCodeReceived(String)
    case exchangePending
    case signedIn(CustSubInfo)
    case cancelled
    case failed(UAEPassAuthError)
}

// MARK: - Authentication Error

enum UAEPassAuthError: Error, Equatable, Sendable {
    case configFetchFailed
    case authSessionFailed(String)
    case noAuthCode
    case exchangeFailed(String)
    case userCancelled
    case uaePassAppRequired
    case networkUnavailable

    var localizedDescription: String {
        switch self {
        case .configFetchFailed:
            return "Failed to fetch UAE Pass configuration."
        case let .authSessionFailed(message):
            return message
        case .noAuthCode:
            return "No authorization code received."
        case let .exchangeFailed(message):
            return message
        case .userCancelled:
            return "Authentication was cancelled."
        case .uaePassAppRequired:
            return "UAE Pass app is required for authentication."
        case .networkUnavailable:
            return "Service is temporarily unavailable."
        }
    }
}