import Foundation
import os

private let networkLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "ioscrmapp",
    category: "HTTPClient"
)

struct HTTPClient: Sendable {
    indirect enum ResponseData: Sendable, Equatable {
        case object([String: ResponseData])
        case array([ResponseData])
        case string(String)
        case number(Double)
        case bool(Bool)
        case null

        init(jsonObject: Any) throws {
            switch jsonObject {
            case let value as [String: Any]:
                self = .object(try value.mapValues { try ResponseData(jsonObject: $0) })
            case let value as [Any]:
                self = .array(try value.map { try ResponseData(jsonObject: $0) })
            case let value as Bool:
                self = .bool(value)
            case let value as NSNumber:
                self = .number(value.doubleValue)
            case let value as String:
                self = .string(value)
            case is NSNull:
                self = .null
            default:
                throw ClientError.invalidJSON
            }
        }

        var objectValue: [String: ResponseData]? {
            guard case let .object(value) = self else {
                return nil
            }
            return value
        }

        var arrayValue: [ResponseData]? {
            guard case let .array(value) = self else {
                return nil
            }
            return value
        }

        var stringValue: String? {
            guard case let .string(value) = self else {
                return nil
            }
            return value
        }

        var boolValue: Bool? {
            guard case let .bool(value) = self else {
                return nil
            }
            return value
        }

        var doubleValue: Double? {
            guard case let .number(value) = self else {
                return nil
            }
            return value
        }

        var intValue: Int? {
            guard case let .number(value) = self, value.rounded() == value else {
                return nil
            }
            return Int(value)
        }
    }

    enum Method: String, Sendable {
        case get = "GET"
        case post = "POST"
    }

    enum ParameterEncoding: Sendable {
        case queryString
        case jsonBody
    }

    struct Endpoint: Sendable {
        let path: String
        let method: Method
        let parameterEncoding: ParameterEncoding
        let includeCommonParameters: Bool
        let includeDeviceInfo: Bool
        let requiresAuthorization: Bool
        let headers: [String: String]

        init(
            path: String,
            method: Method,
            parameterEncoding: ParameterEncoding? = nil,
            includeCommonParameters: Bool = true,
            includeDeviceInfo: Bool = false,
            requiresAuthorization: Bool = false,
            headers: [String: String] = [:]
        ) {
            self.path = path
            self.method = method
            self.parameterEncoding = parameterEncoding ?? Endpoint.defaultParameterEncoding(for: method)
            self.includeCommonParameters = includeCommonParameters
            self.includeDeviceInfo = includeDeviceInfo
            self.requiresAuthorization = requiresAuthorization
            self.headers = headers
        }

        private static func defaultParameterEncoding(for method: Method) -> ParameterEncoding {
            switch method {
            case .get:
                return .queryString
            case .post:
                return .jsonBody
            }
        }
    }

    enum ClientError: Error {
        case invalidResponse
        case httpStatus(Int)
        case invalidJSON
        case business(code: Int, message: String, traceID: String?)
        case networkUnavailable(underlying: Error)
    }

    private static let wrapperSuccessCodes: Set<Int> = [200, 201, 204, 205, 206, 207, 208, 209, 211, 212, 20_000]

    private let baseURL: URL
    private let session: URLSession
    private let contextBuilder: NetworkContextBuilder

    init(
        baseURL: URL,
        session: URLSession = .shared,
        contextBuilder: NetworkContextBuilder = NetworkContextBuilder()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.contextBuilder = contextBuilder
    }

    func get(_ endpoint: Endpoint, query: [String: Any] = [:]) async throws -> ResponseData {
        // 受保护接口在真正出网前先检查一次 token，尽量把已知过期请求拦在客户端。
        try await refreshTokenIfNeeded(for: endpoint)
        let request = try await makeRequest(endpoint: endpoint, parameters: query)
        return try await send(request, endpoint: endpoint)
    }

    func post(_ endpoint: Endpoint, body: [String: Any] = [:]) async throws -> ResponseData {
        // `POST` 与 `GET` 共用同一套续约前置逻辑，避免不同请求方法产生行为偏差。
        try await refreshTokenIfNeeded(for: endpoint)
        let request = try await makeRequest(endpoint: endpoint, parameters: body)
        return try await send(request, endpoint: endpoint)
    }

    func download(_ endpoint: Endpoint, parameters: [String: Any] = [:]) async throws -> URL {
        try await refreshTokenIfNeeded(for: endpoint)
        let request = try await makeRequest(endpoint: endpoint, parameters: parameters)
        return try await sendDownload(request, endpoint: endpoint)
    }

    /// 续约请求复用标准响应包装解析，避免和普通接口走出两套传输行为。
    func refreshAuthTokens(refreshToken: String) async throws -> AuthSessionTokens {
        // token 续约也走统一的 HTTPClient 管道，包装解析、错误处理和公共参数行为都保持一致。
        let responseData = try await post(
            AuthAPI.refresh,
            body: ["refreshToken": refreshToken]
        )
        return try Self.parseAuthSessionTokens(from: responseData)
    }

    private func refreshTokenIfNeeded(for endpoint: Endpoint) async throws {
        guard endpoint.requiresAuthorization else {
            return
        }

        // 请求前主动续约与启动恢复登录态共用同一套判断和刷新入口。
        _ = try await contextBuilder.renewAuthenticationIfNeeded(
            for: .protectedRequest,
            baseURL: baseURL,
            session: session
        )
    }

    private func makeRequest(endpoint: Endpoint, parameters: [String: Any]) async throws -> URLRequest {
        let mergedParameters = mergeParameters(endpoint: endpoint, parameters: parameters)
        let url = baseURL.appendingPathComponent(endpoint.path)

        var requestURL = url

        if endpoint.parameterEncoding == .queryString {
            guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                throw ClientError.invalidResponse
            }
            let queryItems = mergedParameters.map { key, value in
                URLQueryItem(name: key, value: stringifyQueryValue(value))
            }
            components.queryItems = queryItems.isEmpty ? nil : queryItems.sorted { $0.name < $1.name }
            guard let resolvedURL = components.url else {
                throw ClientError.invalidResponse
            }
            requestURL = resolvedURL
        }

        var request = URLRequest(url: requestURL)

        if endpoint.parameterEncoding == .jsonBody {
            request.httpBody = try JSONSerialization.data(withJSONObject: mergedParameters)
        }

        request.httpMethod = endpoint.method.rawValue

        // 头信息统一在这里拼装，登录、注册、续约都共享同一套上下文注入规则。
        var headers = contextBuilder.headers(requiresAuthorization: endpoint.requiresAuthorization)
        headers.merge(endpoint.headers, uniquingKeysWith: { _, new in new })

        if endpoint.parameterEncoding == .jsonBody, headers["Content-Type"] == nil {
            headers["Content-Type"] = "application/json"
        }

        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }

        return request
    }

    private func mergeParameters(endpoint: Endpoint, parameters: [String: Any]) -> [String: Any] {
        guard endpoint.includeCommonParameters else {
            return parameters
        }

        var merged = contextBuilder.parameters(includeDeviceInfo: endpoint.includeDeviceInfo)
        merged.merge(parameters, uniquingKeysWith: { _, new in new })
        return merged
    }

    private func send(
        _ request: URLRequest,
        endpoint: Endpoint,
        allowTokenRefresh: Bool = true
    ) async throws -> ResponseData {
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ClientError.invalidResponse
            }

            return try parseResponseBody(
                data,
                httpStatusCode: httpResponse.statusCode,
                path: endpoint.path
            )
        } catch let error as ClientError where shouldRefreshToken(for: error, endpoint: endpoint, allowTokenRefresh: allowTokenRefresh) {
            // 这是“请求失败后”的被动续约路径：先刷新一次 token，
            // 再按原始参数重建请求，并且只重试一次，避免无限循环。
            _ = try await contextBuilder.refreshTokens(baseURL: baseURL, session: session)
            let retryRequest = try await makeRequest(endpoint: endpoint, parameters: parameters(from: request, endpoint: endpoint))
            return try await send(retryRequest, endpoint: endpoint, allowTokenRefresh: false)
        } catch let error as ClientError {
            throw error
        } catch {
            networkLogger.error(
                "Network request failed path=\(endpoint.path, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
            )
            throw ClientError.networkUnavailable(underlying: error)
        }
    }

    private func sendDownload(
        _ request: URLRequest,
        endpoint: Endpoint,
        allowTokenRefresh: Bool = true
    ) async throws -> URL {
        do {
            let (downloadedFileURL, response) = try await session.download(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ClientError.invalidResponse
            }

            if shouldInspectDownloadedBody(response: httpResponse) {
                let data = try Data(contentsOf: downloadedFileURL)
                _ = try parseResponseBody(
                    data,
                    httpStatusCode: httpResponse.statusCode,
                    path: endpoint.path
                )
                throw ClientError.invalidResponse
            }

            guard (200 ... 299).contains(httpResponse.statusCode) else {
                networkLogger.error(
                    "HTTP status error path=\(endpoint.path, privacy: .public) status=\(httpResponse.statusCode, privacy: .public)"
                )
                throw ClientError.httpStatus(httpResponse.statusCode)
            }

            return downloadedFileURL
        } catch let error as ClientError where shouldRefreshToken(for: error, endpoint: endpoint, allowTokenRefresh: allowTokenRefresh) {
            _ = try await contextBuilder.refreshTokens(baseURL: baseURL, session: session)
            let retryRequest = try await makeRequest(endpoint: endpoint, parameters: parameters(from: request, endpoint: endpoint))
            return try await sendDownload(retryRequest, endpoint: endpoint, allowTokenRefresh: false)
        } catch let error as ClientError {
            throw error
        } catch {
            networkLogger.error(
                "Download request failed path=\(endpoint.path, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
            )
            throw ClientError.networkUnavailable(underlying: error)
        }
    }

    private func shouldRefreshToken(
        for error: ClientError,
        endpoint: Endpoint,
        allowTokenRefresh: Bool
    ) -> Bool {
        guard allowTokenRefresh, endpoint.requiresAuthorization else {
            return false
        }

        switch error {
        case .httpStatus(401):
            // 网关可能在包装体生成前就直接返回 401，这里也要走刷新后重试。
            return true
        case let .business(code, _, _):
            return code == 40_014 || code == 40_015
        default:
            return false
        }
    }

    private func parameters(from request: URLRequest, endpoint: Endpoint) -> [String: Any] {
        switch endpoint.parameterEncoding {
        case .queryString:
            guard
                let url = request.url,
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            else {
                return [:]
            }

            return (components.queryItems ?? []).reduce(into: [String: Any]()) { partialResult, item in
                partialResult[item.name] = item.value ?? ""
            }
        case .jsonBody:
            guard let body = request.httpBody else {
                return [:]
            }
            guard let jsonObject = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
                return [:]
            }
            return jsonObject
        }
    }

    private func parseResponseBody(_ data: Data, httpStatusCode: Int, path: String) throws -> ResponseData {
        if data.isEmpty {
            guard (200 ... 299).contains(httpStatusCode) else {
                networkLogger.error(
                    "HTTP status error path=\(path, privacy: .public) status=\(httpStatusCode, privacy: .public)"
                )
                throw ClientError.httpStatus(httpStatusCode)
            }
            return .null
        }

        let jsonObject: Any
        do {
            jsonObject = try JSONSerialization.jsonObject(with: data)
        } catch {
            guard (200 ... 299).contains(httpStatusCode) else {
                networkLogger.error(
                    "HTTP status error path=\(path, privacy: .public) status=\(httpStatusCode, privacy: .public)"
                )
                throw ClientError.httpStatus(httpStatusCode)
            }
            throw ClientError.invalidJSON
        }

        if let payload = jsonObject as? [String: Any] {
            if isResponseWrapper(payload) {
                return try parseResponseWrapper(
                    payload,
                    httpStatusCode: httpStatusCode,
                    path: path
                )
            }
        }

        guard (200 ... 299).contains(httpStatusCode) else {
            networkLogger.error(
                "HTTP status error path=\(path, privacy: .public) status=\(httpStatusCode, privacy: .public)"
            )
            throw ClientError.httpStatus(httpStatusCode)
        }

        return try ResponseData(jsonObject: jsonObject)
    }

    private func isResponseWrapper(_ payload: [String: Any]) -> Bool {
        guard PayloadValue.int(in: payload, keys: ["code"]) != nil else {
            return false
        }

        return payload["msg"] != nil || payload["message"] != nil || payload["traceId"] != nil
    }

    private func parseResponseWrapper(
        _ payload: [String: Any],
        httpStatusCode: Int,
        path: String
    ) throws -> ResponseData {
        guard let code = PayloadValue.int(in: payload, keys: ["code"]) else {
            throw ClientError.invalidResponse
        }

        let message = PayloadValue.string(in: payload, keys: ["msg", "message"]) ?? ""
        let traceID = PayloadValue.string(in: payload, keys: ["traceId"])

        guard Self.wrapperSuccessCodes.contains(code) else {
            networkLogger.error(
                "Business error path=\(path, privacy: .public) httpStatus=\(httpStatusCode, privacy: .public) code=\(code, privacy: .public) traceId=\(traceID ?? "-", privacy: .public)"
            )
            throw ClientError.business(code: code, message: message, traceID: traceID)
        }

        guard let responseData = payload["data"] else {
            return .null
        }

        return try ResponseData(jsonObject: responseData)
    }

    private func shouldInspectDownloadedBody(response: HTTPURLResponse) -> Bool {
        if let mimeType = response.mimeType?.lowercased() {
            if mimeType.contains("json") || mimeType.hasPrefix("text/") {
                return true
            }
        }

        return !(200 ... 299).contains(response.statusCode)
    }

    private func stringifyQueryValue(_ value: Any) -> String {
        if let string = value as? String {
            return string
        }
        if let bool = value as? Bool {
            return bool ? "true" : "false"
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        return String(describing: value)
    }

    private static func parseAuthSessionTokens(from responseData: ResponseData) throws -> AuthSessionTokens {
        guard let payload = responseData.objectValue else {
            throw ClientError.invalidResponse
        }
        guard let accessToken = parseAuthToken(in: payload, key: "accessToken") else {
            throw ClientError.invalidResponse
        }

        return AuthSessionTokens(
            accessToken: accessToken,
            refreshToken: parseAuthToken(in: payload, key: "refreshToken")
        )
    }

    private static func parseAuthToken(in payload: [String: ResponseData], key: String) -> AuthToken? {
        guard
            let tokenPayload = payload[key]?.objectValue,
            let token = payloadString(in: tokenPayload, keys: ["token"]),
            !token.isEmpty
        else {
            return nil
        }

        return AuthToken(
            token: token,
            expirationTime: payloadString(in: tokenPayload, keys: ["expTime"]),
            renewal: payloadInt64(in: tokenPayload, keys: ["renewal"])
        )
    }

    private static func payloadString(in payload: [String: ResponseData], keys: [String]) -> String? {
        for key in keys {
            if let value = payload[key]?.stringValue, !value.isEmpty {
                return value
            }
        }
        return nil
    }

    private static func payloadInt64(in payload: [String: ResponseData], keys: [String]) -> Int64? {
        for key in keys {
            if let value = payload[key]?.intValue {
                return Int64(value)
            }
            if let value = payload[key]?.stringValue, let intValue = Int64(value) {
                return intValue
            }
        }
        return nil
    }
}

private enum PayloadValue {
    static func string(in dictionary: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = dictionary[key] as? String, !value.isEmpty {
                return value
            }
        }
        return nil
    }

    static func int(in dictionary: [String: Any], keys: [String]) -> Int? {
        for key in keys {
            if let value = dictionary[key] as? Int {
                return value
            }
            if let value = dictionary[key] as? NSNumber {
                return value.intValue
            }
            if let stringValue = dictionary[key] as? String, let value = Int(stringValue) {
                return value
            }
        }
        return nil
    }
}
