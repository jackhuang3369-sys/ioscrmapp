import Foundation

enum NotificationAPI {
    static let query = HTTPClient.Endpoint(
        path: "/ser-query/api/notification/query",
        method: .post,
        includeCommonParameters: true,
        includeDeviceInfo: false,
        requiresAuthorization: true
    )

    static let markRead = HTTPClient.Endpoint(
        path: "/ser-business/api/notification/markRead",
        method: .post,
        includeCommonParameters: true,
        includeDeviceInfo: false,
        requiresAuthorization: true
    )

    static let markDelete = HTTPClient.Endpoint(
        path: "/ser-business/api/notification/markDelete",
        method: .post,
        includeCommonParameters: true,
        includeDeviceInfo: false,
        requiresAuthorization: true
    )

    static let batchMarkRead = HTTPClient.Endpoint(
        path: "/ser-business/api/notification/markReadBatch",
        method: .post,
        includeCommonParameters: true,
        includeDeviceInfo: false,
        requiresAuthorization: true
    )

    static let batchMarkDelete = HTTPClient.Endpoint(
        path: "/ser-business/api/notification/markDeleteBatch",
        method: .post,
        includeCommonParameters: true,
        includeDeviceInfo: false,
        requiresAuthorization: true
    )
}
