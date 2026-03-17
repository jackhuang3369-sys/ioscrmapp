import Foundation

enum AdvertisementAPI {
    static let splashMaterialDownload = HTTPClient.Endpoint(
        path: "/ser-thirdparty/api/file/download",
        method: .post,
        parameterEncoding: .queryString,
        includeCommonParameters: false,
        includeDeviceInfo: false,
        requiresAuthorization: false
    )

    static let currentSplashAdvertisement = HTTPClient.Endpoint(
        path: "/ser-query/api/advertisement/current",
        method: .get,
        includeCommonParameters: false,
        includeDeviceInfo: false,
        requiresAuthorization: false
    )
}
