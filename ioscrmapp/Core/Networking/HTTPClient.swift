import Foundation
import os

private let networkLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "ioscrmapp",
    category: "HTTPClient"
)

struct HTTPClient: Sendable {
    enum Method: String, Sendable {
        case get = "GET"
        case post = "POST"
    }

    struct Endpoint: Sendable {
        let path: String
        let method: Method
        let includeCommonParameters: Bool
        let includeDeviceInfo: Bool
        let requiresAuthorization: Bool
        let headers: [String: String]

        init(
            path: String,
            method: Method,
            includeCommonParameters: Bool = true,
            includeDeviceInfo: Bool = false,
            requiresAuthorization: Bool = false,
            headers: [String: String] = [:]
        ) {
            self.path = path
            self.method = method
            self.includeCommonParameters = includeCommonParameters
            self.includeDeviceInfo = includeDeviceInfo
            self.requiresAuthorization = requiresAuthorization
            self.headers = headers
        }
    }

    enum ClientError: Error {
        case invalidResponse
        case httpStatus(Int)
        case invalidJSON
        case business(code: Int, message: String, traceID: String?)
        case networkUnavailable(underlying: Error)
    }

    private static let successCodes: Set<Int> = [200, 201, 204, 205, 206, 207, 208, 209, 211, 212, 20_000]

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

    func get(_ endpoint: Endpoint, query: [String: Any] = [:]) async throws -> [String: Any] {
        let request = try makeRequest(endpoint: endpoint, parameters: query)
        return try await send(request, endpoint: endpoint)
    }

    func post(_ endpoint: Endpoint, body: [String: Any] = [:]) async throws -> [String: Any] {
        let request = try makeRequest(endpoint: endpoint, parameters: body)
        return try await send(request, endpoint: endpoint)
    }

    private func makeRequest(endpoint: Endpoint, parameters: [String: Any]) throws -> URLRequest {
        let mergedParameters = mergeParameters(endpoint: endpoint, parameters: parameters)
        let url = baseURL.appendingPathComponent(endpoint.path)

        var request: URLRequest

        switch endpoint.method {
        case .get:
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
            request = URLRequest(url: resolvedURL)

        case .post:
            request = URLRequest(url: url)
            request.httpBody = try JSONSerialization.data(withJSONObject: mergedParameters)
        }

        request.httpMethod = endpoint.method.rawValue

        var headers = contextBuilder.headers(requiresAuthorization: endpoint.requiresAuthorization)
        headers.merge(endpoint.headers, uniquingKeysWith: { _, new in new })

        if endpoint.method == .post, headers["Content-Type"] == nil {
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

    private func send(_ request: URLRequest, endpoint: Endpoint) async throws -> [String: Any] {
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ClientError.invalidResponse
            }

            guard (200 ... 299).contains(httpResponse.statusCode) else {
                networkLogger.error(
                    "HTTP status error path=\(endpoint.path, privacy: .public) status=\(httpResponse.statusCode, privacy: .public)"
                )
                throw ClientError.httpStatus(httpResponse.statusCode)
            }

            return try parseEnvelope(data, path: endpoint.path)
        } catch let error as ClientError {
            throw error
        } catch {
            networkLogger.error(
                "Network request failed path=\(endpoint.path, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
            )
            throw ClientError.networkUnavailable(underlying: error)
        }
    }

    private func parseEnvelope(_ data: Data, path: String) throws -> [String: Any] {
        let jsonObject = try JSONSerialization.jsonObject(with: data)

        guard let payload = jsonObject as? [String: Any] else {
            throw ClientError.invalidJSON
        }

        guard let code = PayloadValue.int(in: payload, keys: ["code"]) else {
            return payload
        }

        let message = PayloadValue.string(in: payload, keys: ["msg", "message"]) ?? ""
        let traceID = PayloadValue.string(in: payload, keys: ["traceId"])

        guard Self.successCodes.contains(code) else {
            networkLogger.error(
                "Business error path=\(path, privacy: .public) code=\(code, privacy: .public) traceId=\(traceID ?? "-", privacy: .public)"
            )
            throw ClientError.business(code: code, message: message, traceID: traceID)
        }

        return (payload["data"] as? [String: Any]) ?? [:]
    }

    private func stringifyQueryValue(_ value: Any) -> String {
        if let string = value as? String {
            return string
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        return String(describing: value)
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
