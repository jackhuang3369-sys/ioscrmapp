import Foundation

enum MallAPI {
    static let home = HTTPClient.Endpoint(
        path: "ser-query/api/mall/home",
        method: .get,
        requiresAuthorization: true
    )

    static let searchBootstrap = HTTPClient.Endpoint(
        path: "ser-query/api/mall/search/bootstrap",
        method: .get,
        requiresAuthorization: true
    )

    static let searchResults = HTTPClient.Endpoint(
        path: "ser-query/api/mall/search/results",
        method: .get,
        requiresAuthorization: true
    )

    static let deleteSearchHistory = HTTPClient.Endpoint(
        path: "ser-query/api/mall/search/history/delete",
        method: .post,
        requiresAuthorization: true
    )

    static let clearSearchHistory = HTTPClient.Endpoint(
        path: "ser-query/api/mall/search/history/clear",
        method: .post,
        requiresAuthorization: true
    )
}
