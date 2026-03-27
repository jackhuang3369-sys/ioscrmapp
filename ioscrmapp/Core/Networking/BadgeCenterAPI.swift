import Foundation

enum BadgeCenterAPI {
    static let maxPageSize = 50

    static let badges = HTTPClient.Endpoint(
        path: "/ser-query/api/badges",
        method: .get,
        requiresAuthorization: true
    )

    static let unlockEvents = HTTPClient.Endpoint(
        path: "/ser-query/api/badge-unlock-events",
        method: .get,
        requiresAuthorization: true
    )

    static func detail(badgeID: String) -> HTTPClient.Endpoint {
        HTTPClient.Endpoint(
            path: "/ser-query/api/badges/\(badgeID)",
            method: .get,
            requiresAuthorization: true
        )
    }

    static func markRead(badgeID: String) -> HTTPClient.Endpoint {
        HTTPClient.Endpoint(
            path: "/ser-business/api/badges/\(badgeID)/read",
            method: .post,
            requiresAuthorization: true
        )
    }

    static func handleUnlockEvent(eventID: String) -> HTTPClient.Endpoint {
        HTTPClient.Endpoint(
            path: "/ser-business/api/badge-unlock-events/\(eventID)/handled",
            method: .post,
            requiresAuthorization: true
        )
    }
}
