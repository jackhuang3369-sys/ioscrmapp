import Foundation

enum MallAPI {
    static let home = HTTPClient.Endpoint(
        path: "ser-query/api/mall/home",
        method: .get,
        requiresAuthorization: true
    )

    static let homeProducts = HTTPClient.Endpoint(
        path: "ser-query/api/mall/home/products",
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

    static let productDetail = HTTPClient.Endpoint(
        path: "ser-query/api/mall/products/detail",
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

    static let cart = HTTPClient.Endpoint(
        path: "ser-business/api/mall/cart",
        method: .get,
        requiresAuthorization: true
    )

    static let cartItems = HTTPClient.Endpoint(
        path: "ser-business/api/mall/cart/items",
        method: .post,
        requiresAuthorization: true
    )

    static let cartItemQuantity = HTTPClient.Endpoint(
        path: "ser-business/api/mall/cart/items/quantity",
        method: .post,
        requiresAuthorization: true
    )

    static let cartItemSKU = HTTPClient.Endpoint(
        path: "ser-business/api/mall/cart/items/sku",
        method: .post,
        requiresAuthorization: true
    )

    static let cartItemSelection = HTTPClient.Endpoint(
        path: "ser-business/api/mall/cart/items/selection",
        method: .post,
        requiresAuthorization: true
    )

    static let cartItemDelete = HTTPClient.Endpoint(
        path: "ser-business/api/mall/cart/items/delete",
        method: .post,
        requiresAuthorization: true
    )

    static let cartCheckoutPrepare = HTTPClient.Endpoint(
        path: "ser-business/api/mall/cart/checkout/prepare",
        method: .post,
        requiresAuthorization: true
    )
}
