import Foundation

enum OffersAPI {
    static let primaryOffer = HTTPClient.Endpoint(
        path: "ser-query/api/offer/queryPrimaryOfferDetail",
        method: .post,
        requiresAuthorization: true
    )

    static let subscribedOffers = HTTPClient.Endpoint(
        path: "ser-query/api/offer/querySubscriberSupplementaryOfferList",
        method: .post,
        requiresAuthorization: true
    )

    static let categories = HTTPClient.Endpoint(
        path: "ser-query/api/offer/getOfferCategory",
        method: .post,
        requiresAuthorization: true
    )

    static let eligibleOffers = HTTPClient.Endpoint(
        path: "ser-query/api/offer/queryAvailableSupplementaryOfferList",
        method: .post,
        requiresAuthorization: true
    )

    static let orderPage = HTTPClient.Endpoint(
        path: "ser-query/api/task/queryChangeSuppOfferTaskPage",
        method: .post,
        requiresAuthorization: true
    )

    static let changeOffer = HTTPClient.Endpoint(
        path: "ser-business/api/offer/changeSupplementaryOffer",
        method: .post,
        includeDeviceInfo: true,
        requiresAuthorization: true
    )
}
