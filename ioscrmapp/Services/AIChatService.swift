import Foundation
#if canImport(UIKit)
import UIKit
#endif

protocol AIChatServicing {
    func sendMessage(
        _ text: String,
        conversationID: String?,
        context: AIChatContext
    ) async throws -> AIChatReply
}

struct AIChatConfiguration: Sendable {
    let chatCompletionsURL: URL?
    let authorizationToken: String
    let appID: String
    let apiKey: String

    static let current = AIChatConfiguration(
        chatCompletionsURL: URL(
            string: ProcessInfo.processInfo.environment["IOSCRMAPP_AI_CHAT_URL"]
                ?? "https://10.110.63.144:36667/agent-platform/api/v1/chat/completions"
        ),
        authorizationToken: ProcessInfo.processInfo.environment["IOSCRMAPP_AI_AUTH_TOKEN"]
            ?? "Bearer jgDaEBKYfM71LAmFvHcGtJxMzsiHhN0xNyF3EuluWO6sjnbolBtrxynQdED5R6",
        appID: ProcessInfo.processInfo.environment["IOSCRMAPP_AI_APP_ID"]
            ?? "698ae4d0aaf0d645fac831cc",
        apiKey: ProcessInfo.processInfo.environment["IOSCRMAPP_AI_API_KEY"]
            ?? "jgDaEBKYfM71LAmFvHcGtJxMzsiHhN0xNyF3EuluWO6sjnbolBtrxynQdED5R6"
    )
}

struct MockAIChatService: AIChatServicing {
    func sendMessage(
        _ text: String,
        conversationID: String?,
        context: AIChatContext
    ) async throws -> AIChatReply {
        let normalized = text.lowercased()
        let language = AppLanguage(rawValue: context.languageCode) ?? .fallback

        if normalized.contains("bill") || normalized.contains("账单") {
            return AIChatReply(
                conversationID: conversationID ?? UUID().uuidString,
                text: "You can jump to Billing to review outstanding amounts and payment details.",
                thinkingText: "",
                actions: [
                    AIChatAction(
                        title: AIChatLocalizedCopy.actionTitle(for: .billing, language: language),
                        target: .billing,
                        rawValue: "app://payBill"
                    )
                ]
            )
        }

        if normalized.contains("offer") || normalized.contains("优惠") {
            return AIChatReply(
                conversationID: conversationID ?? UUID().uuidString,
                text: "I can take you to the Offers area so you can review available packages.",
                thinkingText: "",
                actions: [
                    AIChatAction(
                        title: AIChatLocalizedCopy.actionTitle(for: .offers, language: language),
                        target: .offers,
                        rawValue: "app://offers"
                    )
                ]
            )
        }

        return AIChatReply(
            conversationID: conversationID ?? UUID().uuidString,
            text: "Your AI assistant integration is connected. Ask about balance, offers, recharge, or billing to test the flow.",
            thinkingText: "",
            actions: [
                AIChatAction(
                    title: AIChatLocalizedCopy.actionTitle(for: .recharge, language: language),
                    target: .recharge,
                    rawValue: "app://recharge"
                ),
                AIChatAction(
                    title: AIChatLocalizedCopy.actionTitle(for: .offers, language: language),
                    target: .offers,
                    rawValue: "app://offers"
                )
            ]
        )
    }
}

struct RemoteAIChatService: AIChatServicing {
    private let configuration: AIChatConfiguration
    private let session: URLSession

    init(
        configuration: AIChatConfiguration = .current,
        session: URLSession? = nil
    ) {
        self.configuration = configuration
        if let session {
            self.session = session
        } else {
            self.session = URLSession(
                configuration: .default,
                delegate: AIChatURLSessionDelegate(configuration: configuration),
                delegateQueue: nil
            )
        }
    }

    func sendMessage(
        _ text: String,
        conversationID: String?,
        context: AIChatContext
    ) async throws -> AIChatReply {
        guard
            let url = configuration.chatCompletionsURL,
            !configuration.authorizationToken.isEmpty,
            !configuration.appID.isEmpty,
            !configuration.apiKey.isEmpty
        else {
            throw AIChatServiceError.missingConfiguration
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(configuration.authorizationToken, forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: buildRequestBody(
                message: text,
                conversationID: conversationID,
                context: context
            )
        )

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIChatServiceError.invalidResponse
            }

            guard (200 ... 299).contains(httpResponse.statusCode) else {
                let message = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
                throw AIChatServiceError.backend(message)
            }

            guard
                let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let choices = jsonObject["choices"] as? [[String: Any]],
                let firstChoice = choices.first,
                let message = firstChoice["message"] as? [String: Any],
                let content = message["content"]
            else {
                throw AIChatServiceError.invalidResponse
            }

            let parsed = AIChatResponseParser.parse(content: content)
            return AIChatReply(
                conversationID: jsonObject["chatId"] as? String ?? conversationID,
                text: parsed.text,
                richText: parsed.richText,
                thinkingText: parsed.thinkingText,
                actions: parsed.actions
            )
        } catch let error as AIChatServiceError {
            throw error
        } catch {
            throw AIChatServiceError.network(underlying: error)
        }
    }

    private func buildRequestBody(
        message: String,
        conversationID: String?,
        context: AIChatContext
    ) -> [String: Any] {
        [
            "chatId": conversationID ?? "",
            "msgId": "\(Int(Date().timeIntervalSince1970 * 1000))\(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8))",
            "stream": false,
            "detail": true,
            "variables": [
                "uuid": "",
                "seqid": "",
                "encrypted_code": "",
                "app_id": configuration.appID,
                "api_key": configuration.apiKey,
                "items": [],
                "preview_file_urls": [],
                "auth_token": context.accessToken,
                "authorization": context.authorization,
                "user_id": context.userID,
                "service_number": context.serviceNumber,
                "subscriber_key": context.subscriberKey,
                "lang": context.languageCode,
                "current_user_context": [
                    "display_name": context.displayName,
                    "is_logged_in": !context.accessToken.isEmpty,
                    "access_token": context.accessToken,
                    "authorization": context.authorization,
                    "user_id": context.userID,
                    "service_number": context.serviceNumber,
                    "subscriber_key": context.subscriberKey,
                    "language": context.languageCode
                ]
            ],
            "messages": [
                [
                    "content": message,
                    "role": "user"
                ]
            ]
        ]
    }
}

private final class AIChatURLSessionDelegate: NSObject, URLSessionDelegate {
    private let allowedHosts: Set<String>
    private let allowsInvalidCertificates: Bool

    init(configuration: AIChatConfiguration) {
        let host = configuration.chatCompletionsURL?.host?.lowercased()
        if let host {
            allowedHosts = [host]
        } else {
            allowedHosts = []
        }

        #if DEBUG
        let debugDefault = true
        #else
        let debugDefault = false
        #endif

        if let override = ProcessInfo.processInfo.environment["IOSCRMAPP_AI_ALLOW_INVALID_CERT"]?.lowercased() {
            allowsInvalidCertificates = ["1", "true", "yes"].contains(override)
        } else {
            allowsInvalidCertificates = debugDefault
        }
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard
            challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
            let trust = challenge.protectionSpace.serverTrust
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let host = challenge.protectionSpace.host.lowercased()
        guard allowsInvalidCertificates, allowedHosts.contains(host) else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}

private struct AIChatParsedContent {
    let text: String
    let richText: AttributedString?
    let thinkingText: String
    let actions: [AIChatAction]
}

private struct AIChatRenderedText {
    let plainText: String
    let richText: AttributedString?
}

private enum AIChatResponseParser {
    static func parse(content: Any) -> AIChatParsedContent {
        var renderedParts: [AIChatRenderedText] = []
        var thinkingParts: [String] = []
        var actions: [AIChatAction] = []

        collect(node: content, renderedParts: &renderedParts, thinkingParts: &thinkingParts, actions: &actions)

        return AIChatParsedContent(
            text: renderedParts
                .map(\.plainText)
                .joined(separator: "\n\n")
                .trimmingCharacters(in: .whitespacesAndNewlines),
            richText: combinedRichText(from: renderedParts),
            thinkingText: thinkingParts.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines),
            actions: actions
        )
    }

    private static func collect(
        node: Any,
        renderedParts: inout [AIChatRenderedText],
        thinkingParts: inout [String],
        actions: inout [AIChatAction]
    ) {
        switch node {
        case let text as String:
            appendText(text, renderedParts: &renderedParts, thinkingParts: &thinkingParts)
        case let array as [Any]:
            for item in array {
                if let dictionary = item as? [String: Any] {
                    if let type = (dictionary["type"] as? String)?.lowercased(),
                       type == "text",
                       let textNode = dictionary["text"] as? [String: Any],
                       let content = textNode["content"] as? String {
                        appendText(content, renderedParts: &renderedParts, thinkingParts: &thinkingParts)
                        continue
                    }

                    if let interactive = dictionary["interactive"] as? [String: Any] {
                        collectInteractive(
                            interactive,
                            renderedParts: &renderedParts,
                            thinkingParts: &thinkingParts,
                            actions: &actions
                        )
                        continue
                    }
                }

                collect(node: item, renderedParts: &renderedParts, thinkingParts: &thinkingParts, actions: &actions)
            }
        case let dictionary as [String: Any]:
            if looksLikeCard(dictionary) {
                collectActions(from: dictionary, actions: &actions)
            }

            if let interactive = dictionary["interactive"] as? [String: Any] {
                collectInteractive(
                    interactive,
                    renderedParts: &renderedParts,
                    thinkingParts: &thinkingParts,
                    actions: &actions
                )
                return
            }

            if let textValue = dictionary["text"] {
                if let text = textValue as? String {
                    appendText(text, renderedParts: &renderedParts, thinkingParts: &thinkingParts)
                } else {
                    collect(node: textValue, renderedParts: &renderedParts, thinkingParts: &thinkingParts, actions: &actions)
                }
                return
            }

            if let content = dictionary["content"] {
                collect(node: content, renderedParts: &renderedParts, thinkingParts: &thinkingParts, actions: &actions)
                return
            }

            if let body = dictionary["body"] {
                collect(node: body, renderedParts: &renderedParts, thinkingParts: &thinkingParts, actions: &actions)
                return
            }

            if
                let description = dictionary["description"] as? String,
                !looksLikeCard(dictionary)
            {
                appendText(description, renderedParts: &renderedParts, thinkingParts: &thinkingParts)
            }
        default:
            return
        }
    }

    private static func collectInteractive(
        _ interactive: [String: Any],
        renderedParts: inout [AIChatRenderedText],
        thinkingParts: inout [String],
        actions: inout [AIChatAction]
    ) {
        let params = interactive["params"] as? [String: Any] ?? [:]
        let interactiveType = (interactive["type"] as? String)?.lowercased() ?? ""
        var interactiveActions: [AIChatAction] = []
        collectActions(from: interactive, actions: &interactiveActions)

        if
            let description = params["description"] as? String,
            shouldDisplayInteractiveDescription(
                interactiveType: interactiveType,
                actions: interactiveActions
            )
        {
            appendText(description, renderedParts: &renderedParts, thinkingParts: &thinkingParts)
        }

        if
            interactiveType == "userselect",
            let options = params["userSelectOptions"] as? [[String: Any]],
            !options.isEmpty
        {
            let optionText = options.enumerated().compactMap { index, item in
                guard let value = item["value"] as? String, !value.isEmpty else {
                    return nil
                }
                return "\(index + 1). \(value)"
            }.joined(separator: "\n")

            appendText(optionText, renderedParts: &renderedParts, thinkingParts: &thinkingParts)
        }

        interactiveActions.forEach { appendUnique($0, actions: &actions) }
    }

    private static func appendText(
        _ rawText: String,
        renderedParts: inout [AIChatRenderedText],
        thinkingParts: inout [String]
    ) {
        let extracted = extractThinking(from: rawText)
        if !extracted.thinking.isEmpty {
            thinkingParts.append(extracted.thinking)
        }

        let rendered = renderDisplayText(extracted.visibleText)
        if !rendered.plainText.isEmpty {
            renderedParts.append(rendered)
        }
    }

    private static func extractThinking(from rawText: String) -> (visibleText: String, thinking: String) {
        let pattern = "(?:<think>|&lt;think&gt;)([\\s\\S]*?)(?:</think>|&lt;/think&gt;)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return (rawText, "")
        }

        let nsRange = NSRange(rawText.startIndex..., in: rawText)
        let matches = regex.matches(in: rawText, options: [], range: nsRange)
        let thinkingParts = matches.compactMap { match -> String? in
            guard match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: rawText) else {
                return nil
            }
            return rawText[range].trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let visibleText = regex.stringByReplacingMatches(
            in: rawText,
            options: [],
            range: nsRange,
            withTemplate: ""
        )

        return (
            visibleText.trimmingCharacters(in: .whitespacesAndNewlines),
            thinkingParts.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private static func renderDisplayText(_ rawText: String) -> AIChatRenderedText {
        let trimmedRawText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRawText.isEmpty else {
            return AIChatRenderedText(plainText: "", richText: nil)
        }

        if let richText = attributedText(from: trimmedRawText) {
            let plainText = collapseDisplayText(String(richText.characters))
            return AIChatRenderedText(
                plainText: plainText,
                richText: plainText.isEmpty ? nil : richText
            )
        }

        let plainText = collapseDisplayText(trimmedRawText)
        return AIChatRenderedText(
            plainText: plainText,
            richText: plainText.isEmpty ? nil : AttributedString(plainText)
        )
    }

    private static func collapseDisplayText(_ rawText: String) -> String {
        let collapsedLines = rawText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
            .reduce(into: [String]()) { result, line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    if result.last != "" {
                        result.append("")
                    }
                } else {
                    result.append(trimmed)
                }
            }

        return collapsedLines
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func attributedText(from rawText: String) -> AttributedString? {
        guard
            let data = htmlDocument(for: rawText).data(using: .utf8),
            let attributed = try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
            )
        else {
            return nil
        }

        #if canImport(UIKit)
        if let richText = try? AttributedString(attributed, including: \.uiKit) {
            return richText
        }
        #endif

        return AttributedString(attributed.string)
    }

    private static func htmlDocument(for rawText: String) -> String {
        let htmlPrepared = rawText.replacingOccurrences(of: "\n", with: "<br/>")
        return """
        <html>
        <head>
        <meta charset="utf-8">
        <style>
        body { margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Helvetica Neue', sans-serif; font-size: 14px; line-height: 1.5; color: #1F2D3D; }
        p { margin: 0 0 10px 0; }
        h1, h2, h3, h4, h5, h6 { margin: 0 0 8px 0; font-weight: 700; line-height: 1.35; }
        ul, ol { margin: 0; padding-left: 18px; }
        li { margin: 0 0 6px 0; }
        strong, b { font-weight: 700; }
        em, i { font-style: italic; }
        code { font-family: Menlo, Monaco, monospace; font-size: 13px; }
        </style>
        </head>
        <body>\(htmlPrepared)</body>
        </html>
        """
    }

    private static func combinedRichText(from renderedParts: [AIChatRenderedText]) -> AttributedString? {
        guard !renderedParts.isEmpty else {
            return nil
        }

        var combined = AttributedString()
        for (index, part) in renderedParts.enumerated() {
            if index > 0 {
                combined += AttributedString("\n\n")
            }

            if let richText = part.richText {
                combined += richText
            } else {
                combined += AttributedString(part.plainText)
            }
        }

        return combined.characters.isEmpty ? nil : combined
    }

    private static func shouldDisplayInteractiveDescription(
        interactiveType: String,
        actions: [AIChatAction]
    ) -> Bool {
        if interactiveType == "userselect" {
            return true
        }

        return actions.isEmpty
    }

    private static func looksLikeCard(_ dictionary: [String: Any]) -> Bool {
        if let type = (dictionary["type"] as? String)?.lowercased(), type.contains("card") {
            return true
        }

        let linkKeys = ["href", "url", "link", "path"]
        if linkKeys.contains(where: { dictionary[$0] != nil }) {
            return true
        }

        let nestedKeys = ["actions", "buttons", "items", "children", "card", "cardConfig"]
        return nestedKeys.contains(where: { dictionary[$0] != nil })
    }

    private static func collectActions(from node: Any, actions: inout [AIChatAction]) {
        switch node {
        case let array as [Any]:
            array.forEach { collectActions(from: $0, actions: &actions) }
        case let dictionary as [String: Any]:
            let rawTarget = [
                dictionary["href"] as? String,
                dictionary["url"] as? String,
                dictionary["link"] as? String,
                dictionary["path"] as? String
            ].compactMap { $0 }.first

            if let rawTarget, !rawTarget.isEmpty {
                let title = extractActionTitle(from: dictionary)
                let action = AIChatAction(
                    title: title.isEmpty ? rawTarget : title,
                    target: navigationTarget(from: rawTarget),
                    rawValue: rawTarget
                )
                appendUnique(action, actions: &actions)
            }

            ["content", "body", "items", "children", "actions", "buttons", "data", "card", "cardConfig", "params"]
                .forEach { key in
                    if let value = dictionary[key] {
                        collectActions(from: value, actions: &actions)
                    }
                }
        default:
            return
        }
    }

    private static func appendUnique(_ action: AIChatAction, actions: inout [AIChatAction]) {
        let exists = actions.contains { $0.title == action.title && $0.rawValue == action.rawValue }
        guard !exists else {
            return
        }
        actions.append(action)
    }

    private static func extractActionTitle(from dictionary: [String: Any]) -> String {
        for key in ["body", "text", "value", "label", "title", "name", "caption"] {
            if let value = dictionary[key] {
                let title = stringifyActionTitle(value)
                if !title.isEmpty {
                    return title
                }
            }
        }
        return ""
    }

    private static func stringifyActionTitle(_ value: Any) -> String {
        switch value {
        case let string as String:
            return string.trimmingCharacters(in: .whitespacesAndNewlines)
        case let number as NSNumber:
            return number.stringValue
        case let array as [Any]:
            return array.map(stringifyActionTitle).filter { !$0.isEmpty }.joined(separator: " ")
        case let dictionary as [String: Any]:
            for key in ["body", "text", "value", "label", "title", "name", "caption"] {
                if let nested = dictionary[key] {
                    let title = stringifyActionTitle(nested)
                    if !title.isEmpty {
                        return title
                    }
                }
            }
            return ""
        default:
            return ""
        }
    }

    private static func navigationTarget(from rawValue: String) -> AIChatNavigationTarget? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return URL(string: trimmed).map { .external($0) }
        }

        let lowercased = trimmed.lowercased()
        if lowercased.hasPrefix("app://") {
            let pageKey = lowercased.replacingOccurrences(of: "app://", with: "").split(separator: "?").first.map(String.init) ?? ""
            switch pageKey {
            case "balance", "balanceenquiry", "home":
                return .home
            case "currentplan", "plan", "primaryoffer", "offer", "offers":
                return .offers
            case "recharge":
                return .recharge
            case "paybill":
                return .billing
            case "profile", "me":
                return .me
            case "mall":
                return .mall
            case "complaint", "complaints", "menu", "service":
                return .service
            default:
                return nil
            }
        }

        if lowercased.contains("/pages/recharge/recharge") {
            return .recharge
        }
        if lowercased.contains("/pages/paybill/paybill") {
            return .billing
        }
        if lowercased.contains("/pages/offer/offer") || lowercased.contains("/pages/primaryoffer/primaryoffer") {
            return .offers
        }
        if lowercased.contains("/pages/profile/profile") {
            return .me
        }
        if lowercased.contains("/pages/homepagenew/homepagenew") {
            return .home
        }
        if lowercased.contains("/pages/menu/menu") || lowercased.contains("/pages/complaint/complaint") {
            return .service
        }

        return nil
    }
}
