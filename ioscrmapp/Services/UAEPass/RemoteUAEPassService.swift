import Foundation

/// 真实 UAE Pass 服务（调用后端 API）
actor RemoteUAEPassService: UAEPassServicing {
    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    func getConfig() async throws -> UAEPassConfig {
        let data = try await client.post(AuthAPI.uaePassConfig, body: [:])
        guard
            let dict = data.objectValue,
            let authorizeURL = ResponseDataValue.string(in: dict, keys: ["authorizeUrl"]),
            let clientId = ResponseDataValue.string(in: dict, keys: ["clientId"]),
            let redirectUri = ResponseDataValue.string(in: dict, keys: ["redirectUri"]),
            let language = ResponseDataValue.string(in: dict, keys: ["language"]),
            let environment = ResponseDataValue.string(in: dict, keys: ["environment"]),
            let scope = ResponseDataValue.string(in: dict, keys: ["scope"]),
            let installedFlowAcrValues = ResponseDataValue.string(in: dict, keys: ["installedFlowAcrValues"]),
            let fallbackFlowAcrValues = ResponseDataValue.string(in: dict, keys: ["fallbackFlowAcrValues"]),
            let state = ResponseDataValue.string(in: dict, keys: ["state"])
        else {
            throw UAEPassAuthError.configFetchFailed
        }

        return UAEPassConfig(
            authorizeURL: authorizeURL,
            clientId: clientId,
            redirectUri: redirectUri,
            language: language,
            environment: environment,
            scope: scope,
            installedFlowAcrValues: installedFlowAcrValues,
            fallbackFlowAcrValues: fallbackFlowAcrValues,
            state: state
        )
    }

    func loginWithCode(code: String, state: String, requestId: String) async throws -> CustSubInfo {
        let responseData = try await client.post(
            AuthAPI.uaePassExchangeCode,
            body: [
                "code": code,
                "platform": "ios",
                "state": state,
                "requestId": requestId
            ]
        )

        let loginResponse = try LoginResponseMapper.map(
            from: responseData,
            fallbackPhone: ""
        )

        try KeychainAuthTokenStore().save(loginResponse.tokens)
        return loginResponse.custSubInfo
    }
}