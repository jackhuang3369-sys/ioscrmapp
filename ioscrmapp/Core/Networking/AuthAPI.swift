import Foundation

enum AuthAPI {
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
}
