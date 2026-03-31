import Foundation

enum VideoAPI {
    static let navigation = HTTPClient.Endpoint(
        path: "ser-query/api/video/navigation",
        method: .get,
        requiresAuthorization: true
    )

    static let carousels = HTTPClient.Endpoint(
        path: "ser-query/api/video/carousels",
        method: .get,
        requiresAuthorization: true
    )

    static let list = HTTPClient.Endpoint(
        path: "ser-query/api/video/list",
        method: .get,
        requiresAuthorization: true
    )

    static let searchBootstrap = HTTPClient.Endpoint(
        path: "ser-query/api/video/search/bootstrap",
        method: .get,
        requiresAuthorization: true
    )

    static let search = HTTPClient.Endpoint(
        path: "ser-query/api/video/search",
        method: .get,
        requiresAuthorization: true
    )

    static let detail = HTTPClient.Endpoint(
        path: "ser-query/api/video/detail",
        method: .get,
        requiresAuthorization: true
    )

    static let deleteSearchHistory = HTTPClient.Endpoint(
        path: "ser-query/api/video/search/history/delete",
        method: .post,
        requiresAuthorization: true
    )

    static let clearSearchHistory = HTTPClient.Endpoint(
        path: "ser-query/api/video/search/history/clear",
        method: .post,
        requiresAuthorization: true
    )

    static let playbackSession = HTTPClient.Endpoint(
        path: "ser-business/api/video/playback/session",
        method: .post,
        requiresAuthorization: true
    )
}
