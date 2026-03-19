import Foundation
import os

#if canImport(UIKit)
import UIKit
#endif

private let notificationLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "ioscrmapp",
    category: "Notification"
)

protocol NotificationServicing: Sendable {
    func fetchMessages(session: CustSubInfo) async throws -> [MessageCenterMessage]
    func markMessageRead(messageID: String, session: CustSubInfo) async throws
    func deleteMessage(messageID: String, session: CustSubInfo) async throws
    func markMessagesRead(messageIDs: [String], session: CustSubInfo) async throws -> MessageCenterBatchResult
    func deleteMessages(messageIDs: [String], session: CustSubInfo) async throws -> MessageCenterBatchResult
}

actor MockNotificationService: NotificationServicing {
    private var messages: [MessageCenterMessage]

    init(messages: [MessageCenterMessage] = MockNotificationService.defaultMessages()) {
        self.messages = messages.sorted {
            ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast)
        }
    }

    func fetchMessages(session: CustSubInfo) async throws -> [MessageCenterMessage] {
        try await Task.sleep(nanoseconds: 300_000_000)
        return messages
    }

    func markMessageRead(messageID: String, session: CustSubInfo) async throws {
        try await Task.sleep(nanoseconds: 180_000_000)
        messages = messages.map { message in
            message.id == messageID ? message.markingRead() : message
        }
    }

    func deleteMessage(messageID: String, session: CustSubInfo) async throws {
        try await Task.sleep(nanoseconds: 220_000_000)
        messages.removeAll(where: { $0.id == messageID })
    }

    func markMessagesRead(messageIDs: [String], session: CustSubInfo) async throws -> MessageCenterBatchResult {
        try await Task.sleep(nanoseconds: 260_000_000)
        let requestedIDs = Array(Set(messageIDs))
        let failureIDs = requestedIDs.filter { $0.hasSuffix("fail-read") }
        let successIDs = requestedIDs.filter { !failureIDs.contains($0) }

        let succeededSet = Set(successIDs)
        messages = messages.map { message in
            succeededSet.contains(message.id) ? message.markingRead() : message
        }

        return MessageCenterBatchResult(
            succeededMessageIDs: successIDs,
            failedMessageIDs: failureIDs
        )
    }

    func deleteMessages(messageIDs: [String], session: CustSubInfo) async throws -> MessageCenterBatchResult {
        try await Task.sleep(nanoseconds: 260_000_000)
        let requestedIDs = Array(Set(messageIDs))
        let failureIDs = requestedIDs.filter { $0.hasSuffix("fail-delete") }
        let successIDs = requestedIDs.filter { !failureIDs.contains($0) }
        let succeededSet = Set(successIDs)
        messages.removeAll(where: { succeededSet.contains($0.id) })

        return MessageCenterBatchResult(
            succeededMessageIDs: successIDs,
            failedMessageIDs: failureIDs
        )
    }

    private static func defaultMessages() -> [MessageCenterMessage] {
        let now = Date()
        return [
            MessageCenterMessage(
                id: "message-001",
                sender: "du Support",
                title: "Your roaming pass is ready",
                arabicTitle: "باقة التجوال الخاصة بك جاهزة",
                content: "You can now use your roaming pass in Saudi Arabia and Bahrain.",
                arabicContent: "يمكنك الآن استخدام باقة التجوال الخاصة بك في السعودية والبحرين.",
                category: .system,
                isRead: false,
                createdAt: now.addingTimeInterval(-1_200)
            ),
            MessageCenterMessage(
                id: "message-002-fail-read",
                sender: "du Rewards",
                title: "Double points weekend",
                arabicTitle: "عطلة نهاية أسبوع بنقاط مضاعفة",
                content: "Recharge through the app this weekend to earn double loyalty points.",
                arabicContent: "أعد الشحن عبر التطبيق في عطلة نهاية الأسبوع لتحصل على نقاط ولاء مضاعفة.",
                category: .promotion,
                isRead: false,
                createdAt: now.addingTimeInterval(-7_200)
            ),
            MessageCenterMessage(
                id: "message-003-fail-delete",
                sender: "Billing Team",
                title: "March statement available",
                arabicTitle: "كشف شهر مارس متاح الآن",
                content: "Your latest bill has been generated and is ready to review.",
                arabicContent: "تم إصدار فاتورتك الأخيرة وأصبحت جاهزة للمراجعة.",
                category: .other,
                isRead: true,
                createdAt: now.addingTimeInterval(-86_400)
            )
        ]
    }
}

struct RemoteNotificationService: NotificationServicing {
    private let client: HTTPClient
    private let contextBuilder: NetworkContextBuilder

    init(
        serverURL: URL,
        session: URLSession = .shared,
        contextBuilder: NetworkContextBuilder = NetworkContextBuilder()
    ) {
        client = HTTPClient(
            baseURL: serverURL,
            session: session,
            contextBuilder: contextBuilder
        )
        self.contextBuilder = contextBuilder
    }

    func fetchMessages(session: CustSubInfo) async throws -> [MessageCenterMessage] {
        let identity = try session.notificationIdentity()

        do {
            let responseData = try await client.post(
                NotificationAPI.query,
                body: [
                    "userId": identity.userID,
                    "serviceNumber": identity.serviceNumber,
                    "pageIndex": 1,
                    "pageSize": 100
                ]
            )
            return try NotificationResponseMapper.mapMessages(from: responseData)
        } catch let error as HTTPClient.ClientError {
            notificationLogger.error("Fetch notifications failed with client error: \(String(describing: error), privacy: .public)")
            throw mapClientError(error)
        } catch let error as MessageCenterServiceError {
            throw error
        } catch {
            throw MessageCenterServiceError.networkUnavailable
        }
    }

    func markMessageRead(messageID: String, session: CustSubInfo) async throws {
        _ = try await performBooleanOperation(
            endpoint: NotificationAPI.markRead,
            messageIDs: [messageID],
            session: session,
            includeSingleMessageID: true
        )
    }

    func deleteMessage(messageID: String, session: CustSubInfo) async throws {
        _ = try await performBooleanOperation(
            endpoint: NotificationAPI.markDelete,
            messageIDs: [messageID],
            session: session,
            includeSingleMessageID: true
        )
    }

    func markMessagesRead(messageIDs: [String], session: CustSubInfo) async throws -> MessageCenterBatchResult {
        try await performBatchOperation(
            endpoint: NotificationAPI.batchMarkRead,
            messageIDs: messageIDs,
            session: session
        )
    }

    func deleteMessages(messageIDs: [String], session: CustSubInfo) async throws -> MessageCenterBatchResult {
        try await performBatchOperation(
            endpoint: NotificationAPI.batchMarkDelete,
            messageIDs: messageIDs,
            session: session
        )
    }

    private func performBooleanOperation(
        endpoint: HTTPClient.Endpoint,
        messageIDs: [String],
        session: CustSubInfo,
        includeSingleMessageID: Bool
    ) async throws -> Bool {
        let identity = try session.notificationIdentity()
        var payload = operationPayload(
            identity: identity,
            messageIDs: messageIDs,
            includeSingleMessageID: includeSingleMessageID
        )

        if endpoint.path.contains("markRead") {
            payload.merge(readDevicePayload(), uniquingKeysWith: { _, new in new })
        }

        do {
            let responseData = try await client.post(endpoint, body: payload)
            return NotificationResponseMapper.mapBoolean(from: responseData)
        } catch let error as HTTPClient.ClientError {
            throw mapClientError(error)
        } catch let error as MessageCenterServiceError {
            throw error
        } catch {
            throw MessageCenterServiceError.networkUnavailable
        }
    }

    private func performBatchOperation(
        endpoint: HTTPClient.Endpoint,
        messageIDs: [String],
        session: CustSubInfo
    ) async throws -> MessageCenterBatchResult {
        let identity = try session.notificationIdentity()
        var payload = operationPayload(
            identity: identity,
            messageIDs: messageIDs,
            includeSingleMessageID: false
        )

        if endpoint.path.contains("markRead") {
            payload.merge(readDevicePayload(), uniquingKeysWith: { _, new in new })
        }

        do {
            let responseData = try await client.post(endpoint, body: payload)
            return try NotificationResponseMapper.mapBatchResult(
                from: responseData,
                requestedMessageIDs: messageIDs
            )
        } catch let error as HTTPClient.ClientError {
            throw mapClientError(error)
        } catch let error as MessageCenterServiceError {
            throw error
        } catch {
            throw MessageCenterServiceError.networkUnavailable
        }
    }

    private func operationPayload(
        identity: NotificationIdentity,
        messageIDs: [String],
        includeSingleMessageID: Bool
    ) -> [String: Any] {
        let sanitizedIDs = Array(NSOrderedSet(array: messageIDs)) as? [String] ?? messageIDs
        var payload: [String: Any] = [
            "userId": identity.userID,
            "serviceNumber": identity.serviceNumber,
            "messageIds": sanitizedIDs
        ]

        if includeSingleMessageID, let firstMessageID = sanitizedIDs.first {
            payload["messageId"] = firstMessageID
        }

        return payload
    }

    private func readDevicePayload() -> [String: Any] {
        let deviceInfo = contextBuilder.loginParameters()
        return [
            "deviceBrand": deviceInfo["deviceBrand"] ?? notificationDeviceBrand,
            "deviceModel": deviceInfo["deviceModel"] ?? notificationDeviceModel
        ]
    }

    private var notificationDeviceBrand: String {
        "Apple"
    }

    private var notificationDeviceModel: String {
        #if canImport(UIKit)
        return UIDevice.current.model
        #else
        return "iPhone"
        #endif
    }

    private func mapClientError(_ error: HTTPClient.ClientError) -> MessageCenterServiceError {
        switch error {
        case let .business(code, message, _):
            if code == 40_001 || code == 40_014 || code == 40_015 {
                return .missingIdentity
            }

            if !message.isEmpty {
                return .featureUnavailable(message: message)
            }

            return .networkUnavailable
        case .httpStatus, .invalidJSON, .invalidResponse, .networkUnavailable:
            return .networkUnavailable
        }
    }
}

private struct NotificationIdentity {
    let userID: String
    let serviceNumber: String
}

private extension CustSubInfo {
    func notificationIdentity() throws -> NotificationIdentity {
        let resolvedUserID = userID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let resolvedServiceNumber = (serviceNumber ?? AuthValidator.normalizedPhone(phoneNumber))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !resolvedUserID.isEmpty, !resolvedServiceNumber.isEmpty else {
            throw MessageCenterServiceError.missingIdentity
        }

        return NotificationIdentity(
            userID: resolvedUserID,
            serviceNumber: resolvedServiceNumber
        )
    }
}

private enum NotificationResponseMapper {
    static func mapMessages(from responseData: HTTPClient.ResponseData) throws -> [MessageCenterMessage] {
        let records: [HTTPClient.ResponseData]

        switch responseData {
        case let .object(dictionary):
            if let array = dictionary["records"]?.arrayValue {
                records = array
            } else if let array = dictionary["list"]?.arrayValue {
                records = array
            } else if let array = dictionary["items"]?.arrayValue {
                records = array
            } else {
                throw HTTPClient.ClientError.invalidResponse
            }
        case let .array(array):
            records = array
        default:
            throw HTTPClient.ClientError.invalidResponse
        }

        return try records.map(mapMessage)
    }

    static func mapBoolean(from responseData: HTTPClient.ResponseData) -> Bool {
        switch responseData {
        case let .bool(value):
            return value
        case let .number(value):
            return value != 0
        case let .string(value):
            return ["1", "true", "success"].contains(value.lowercased())
        case .null:
            return true
        default:
            return false
        }
    }

    static func mapBatchResult(
        from responseData: HTTPClient.ResponseData,
        requestedMessageIDs: [String]
    ) throws -> MessageCenterBatchResult {
        switch responseData {
        case let .object(dictionary):
            let successIDs = stringArray(
                in: dictionary,
                keys: ["successMessageIds", "successIds", "successList"]
            )
            let failedIDs = stringArray(
                in: dictionary,
                keys: ["failedMessageIds", "failMessageIds", "failedIds", "failedList"]
            )

            if !successIDs.isEmpty || !failedIDs.isEmpty {
                return MessageCenterBatchResult(
                    succeededMessageIDs: successIDs,
                    failedMessageIDs: failedIDs
                )
            }

            if mapBoolean(from: responseData) {
                return MessageCenterBatchResult(
                    succeededMessageIDs: requestedMessageIDs,
                    failedMessageIDs: []
                )
            }
        case .bool, .number, .string, .null:
            if mapBoolean(from: responseData) {
                return MessageCenterBatchResult(
                    succeededMessageIDs: requestedMessageIDs,
                    failedMessageIDs: []
                )
            }
        default:
            break
        }

        throw MessageCenterServiceError.networkUnavailable
    }

    private static func mapMessage(_ responseData: HTTPClient.ResponseData) throws -> MessageCenterMessage {
        guard let dictionary = responseData.objectValue else {
            throw HTTPClient.ClientError.invalidResponse
        }

        guard let id = string(in: dictionary, keys: ["id"]), !id.isEmpty else {
            throw HTTPClient.ClientError.invalidResponse
        }

        let sender = string(in: dictionary, keys: ["sender"]) ?? ""
        let title = string(in: dictionary, keys: ["title"]) ?? ""
        let content = string(in: dictionary, keys: ["content"]) ?? ""

        return MessageCenterMessage(
            id: id,
            sender: sender.isEmpty ? title : sender,
            title: title,
            arabicTitle: string(in: dictionary, keys: ["titleAr"]) ?? "",
            content: content,
            arabicContent: string(in: dictionary, keys: ["contentAr"]) ?? "",
            category: MessageCenterCategory(rawValue: string(in: dictionary, keys: ["type"]) ?? ""),
            isRead: bool(in: dictionary, keys: ["isRead"]),
            createdAt: date(in: dictionary, keys: ["createdTime", "updatedTime", "readTime"])
        )
    }

    fileprivate static func string(
        in dictionary: [String: HTTPClient.ResponseData],
        keys: [String]
    ) -> String? {
        for key in keys {
            if let value = dictionary[key]?.stringValue {
                return value
            }
            if let value = dictionary[key]?.intValue {
                return "\(value)"
            }
            if let value = dictionary[key]?.doubleValue {
                return "\(value)"
            }
        }
        return nil
    }

    private static func bool(
        in dictionary: [String: HTTPClient.ResponseData],
        keys: [String]
    ) -> Bool {
        for key in keys {
            if let value = dictionary[key]?.boolValue {
                return value
            }
            if let value = dictionary[key]?.intValue {
                return value != 0
            }
            if let value = dictionary[key]?.stringValue {
                return ["1", "true", "yes", "y"].contains(value.lowercased())
            }
        }
        return false
    }

    private static func stringArray(
        in dictionary: [String: HTTPClient.ResponseData],
        keys: [String]
    ) -> [String] {
        for key in keys {
            guard let array = dictionary[key]?.arrayValue else {
                continue
            }
            let values = array.compactMap { item -> String? in
                if let stringValue = item.stringValue, !stringValue.isEmpty {
                    return stringValue
                }
                if let intValue = item.intValue {
                    return "\(intValue)"
                }
                return nil
            }
            if !values.isEmpty {
                return values
            }
        }
        return []
    }

    private static func date(
        in dictionary: [String: HTTPClient.ResponseData],
        keys: [String]
    ) -> Date? {
        for key in keys {
            guard let value = dictionary[key] else {
                continue
            }

            if let stringValue = value.stringValue, let parsedDate = NotificationResponseDateParser.parse(stringValue) {
                return parsedDate
            }

            if let timestamp = value.doubleValue {
                return NotificationResponseDateParser.parse(timestamp: timestamp)
            }

            if let objectValue = value.objectValue, let parsedDate = NotificationResponseDateParser.parse(objectValue) {
                return parsedDate
            }
        }

        return nil
    }
}

private enum NotificationResponseDateParser {
    private static let iso8601FractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static let backendFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    static func parse(_ value: String) -> Date? {
        if let fractionalDate = iso8601FractionalFormatter.date(from: value) {
            return fractionalDate
        }
        if let isoDate = iso8601Formatter.date(from: value) {
            return isoDate
        }
        if let backendDate = backendFormatter.date(from: value) {
            return backendDate
        }
        if let timestamp = Double(value) {
            return parse(timestamp: timestamp)
        }
        return nil
    }

    static func parse(timestamp: Double) -> Date {
        timestamp > 1_000_000_000_000
            ? Date(timeIntervalSince1970: timestamp / 1_000)
            : Date(timeIntervalSince1970: timestamp)
    }

    static func parse(_ dictionary: [String: HTTPClient.ResponseData]) -> Date? {
        if let nestedString = NotificationResponseMapper.string(
            in: dictionary,
            keys: ["value", "dateTime", "time", "localDateTime"]
        ) {
            return parse(nestedString)
        }

        let year = int(in: dictionary, keys: ["year"])
        let month = int(in: dictionary, keys: ["month", "monthValue"])
        let day = int(in: dictionary, keys: ["day", "dayOfMonth"])

        guard let year, let month, let day else {
            return nil
        }

        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        components.hour = int(in: dictionary, keys: ["hour"]) ?? 0
        components.minute = int(in: dictionary, keys: ["minute"]) ?? 0
        components.second = int(in: dictionary, keys: ["second"]) ?? 0

        return components.date
    }

    private static func int(
        in dictionary: [String: HTTPClient.ResponseData],
        keys: [String]
    ) -> Int? {
        for key in keys {
            if let value = dictionary[key]?.intValue {
                return value
            }
            if let value = dictionary[key]?.stringValue, let intValue = Int(value) {
                return intValue
            }
        }
        return nil
    }
}
