import Foundation

enum AuthAPI {
    static let sendLoginOTP = HTTPClient.Endpoint(
        path: "/ser-user-auth/api/auth/code",
        method: .post,
        includeCommonParameters: false,
        includeDeviceInfo: false,
        requiresAuthorization: false
    )

    static let login = HTTPClient.Endpoint(
        path: "/ser-user-auth/api/auth/login",
        method: .post,
        includeCommonParameters: false,
        includeDeviceInfo: false,
        requiresAuthorization: false
    )

    static let refresh = HTTPClient.Endpoint(
        path: "/ser-user-auth/api/auth/refresh",
        method: .post,
        includeCommonParameters: false,
        includeDeviceInfo: false,
        requiresAuthorization: false
    )

    static let checkRegistrationEligibility = HTTPClient.Endpoint(
        path: "/ser-user-auth/api/auth/register/eligibility",
        method: .post,
        includeCommonParameters: true,
        includeDeviceInfo: false,
        requiresAuthorization: false
    )

    static let sendRegistrationOTP = HTTPClient.Endpoint(
        path: "/ser-user-auth/api/auth/register/otp/send",
        method: .post,
        includeCommonParameters: true,
        includeDeviceInfo: false,
        requiresAuthorization: false
    )

    static let verifyRegistrationOTP = HTTPClient.Endpoint(
        path: "/ser-user-auth/api/auth/register/otp/verify",
        method: .post,
        includeCommonParameters: true,
        includeDeviceInfo: false,
        requiresAuthorization: false
    )

    static let register = HTTPClient.Endpoint(
        path: "/ser-user-auth/api/auth/register",
        method: .post,
        includeCommonParameters: true,
        includeDeviceInfo: true,
        requiresAuthorization: false
    )

    static let checkForgotPasswordUser = HTTPClient.Endpoint(
        path: "/ser-user-auth/api/auth/checkUserExist",
        method: .post,
        includeCommonParameters: false,
        includeDeviceInfo: false,
        requiresAuthorization: false
    )

    static let sendForgotPasswordOTP = HTTPClient.Endpoint(
        path: "/ser-user-auth/api/auth/code",
        method: .post,
        includeCommonParameters: false,
        includeDeviceInfo: false,
        requiresAuthorization: false
    )

    static let verifyForgotPasswordOTP = HTTPClient.Endpoint(
        path: "/ser-user-auth/api/auth/verify",
        method: .post,
        includeCommonParameters: false,
        includeDeviceInfo: false,
        requiresAuthorization: false
    )

    static let resetForgotPassword = HTTPClient.Endpoint(
        path: "/ser-user-auth/api/auth/forgetModifyPass",
        method: .post,
        includeCommonParameters: false,
        includeDeviceInfo: false,
        requiresAuthorization: false
    )

    // UAE Pass 登录配置获取接口
    static let uaePassConfig = HTTPClient.Endpoint(
        path: "/ser-user-auth/api/auth/uaepass/config",
        method: .post,
        includeCommonParameters: false,
        includeDeviceInfo: false,
        requiresAuthorization: false
    )

    // UAE Pass 授权码兑换接口（换取访问令牌）
    static let uaePassExchangeCode = HTTPClient.Endpoint(
        path: "/ser-user-auth/api/auth/uaepass/exchange-code",
        method: .post,
        includeCommonParameters: false,
        includeDeviceInfo: false,
        requiresAuthorization: false
    )

    static func logout(authorizationToken: String) -> HTTPClient.Endpoint {
        HTTPClient.Endpoint(
            path: "/ser-user-auth/api/auth/logout",
            method: .post,
            includeCommonParameters: false,
            includeDeviceInfo: false,
            requiresAuthorization: false,
            headers: ["Authorization": "Bearer \(authorizationToken)"]
        )
    }
}
