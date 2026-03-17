import Foundation

struct SplashAdManifest: Codable, Equatable, Sendable {
    let id: String
    let startsAt: Date
    let endsAt: Date?
    let bucketName: String
    let objectName: String
    let localFileName: String
    let updatedAt: Date
}

struct SplashAdRemoteConfiguration: Equatable, Sendable {
    let id: String
    let isEnabled: Bool
    let startsAt: Date
    let endsAt: Date?
    let bucketName: String
    let objectName: String

    var isCacheable: Bool {
        guard isEnabled else {
            return false
        }
        guard bucketName.isEmpty == false, objectName.isEmpty == false else {
            return false
        }
        if let endsAt, endsAt <= startsAt {
            return false
        }
        return true
    }
}

struct SplashAdPlayable: Equatable, Sendable {
    let id: String
    let fileURL: URL
    let startsAt: Date
    let endsAt: Date?
}

enum SplashAdFinishReason: Equatable, Sendable {
    case playbackCompleted
    case skipped
    case loadingFailed
}
