import Foundation

enum HomeAPI {
    static let userInfo = HTTPClient.Endpoint(
        path: "ser-query/api/home/userInfo",
        method: .post,
        requiresAuthorization: true
    )

    static let queryBalance = HTTPClient.Endpoint(
        path: "ser-query/api/home/queryBalance",
        method: .post,
        requiresAuthorization: true
    )

    static let queryFreeUnit = HTTPClient.Endpoint(
        path: "ser-query/api/home/queryFreeUnit",
        method: .post,
        requiresAuthorization: true
    )
}
