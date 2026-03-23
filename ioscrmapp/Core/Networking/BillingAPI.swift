import Foundation

enum BillingAPI {
    static let balanceEnquiry = HTTPClient.Endpoint(
        path: "ser-query/api/bill/balanceEnquiry",
        method: .post,
        requiresAuthorization: true
    )

    static let queryToPayBillList = HTTPClient.Endpoint(
        path: "ser-query/api/bill/queryToPayBillList",
        method: .post,
        requiresAuthorization: true
    )

    static let payBill = HTTPClient.Endpoint(
        path: "ser-business/api/bill/paybill",
        method: .post,
        requiresAuthorization: true
    )

    static let mobileMoneyPay = HTTPClient.Endpoint(
        path: "ser-thirdparty/api/pay/mobileMoney/pay",
        method: .post,
        requiresAuthorization: true
    )

    static let downloadInvoicePdf = HTTPClient.Endpoint(
        path: "ser-query/api/bill/downloadInvoicePdf",
        method: .post,
        requiresAuthorization: true,
        headers: ["Accept": "application/pdf"]
    )
}
