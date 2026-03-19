import Foundation

enum MessageCenterCategory: String, Equatable, Sendable {
    case system
    case promotion
    case other

    init(rawValue: String) {
        switch rawValue.lowercased() {
        case "0", "system":
            self = .system
        case "1", "promotion":
            self = .promotion
        default:
            self = .other
        }
    }

    var titleKey: String {
        switch self {
        case .system:
            return "messageCenter.category.system"
        case .promotion:
            return "messageCenter.category.promotion"
        case .other:
            return "messageCenter.category.other"
        }
    }
}

struct MessageCenterMessage: Identifiable, Equatable, Sendable {
    let id: String
    let sender: String
    let title: String
    let arabicTitle: String
    let content: String
    let arabicContent: String
    let category: MessageCenterCategory
    let isRead: Bool
    let createdAt: Date?

    func summary(for language: AppLanguage) -> String {
        preferredLocalizedValue(
            for: language,
            primaryArabic: arabicTitle,
            fallback: title,
            secondFallback: content
        )
    }

    func detailTitle(for language: AppLanguage) -> String {
        preferredLocalizedValue(
            for: language,
            primaryArabic: arabicTitle,
            fallback: title,
            secondFallback: sender
        )
    }

    func detailBody(for language: AppLanguage) -> String {
        preferredLocalizedValue(
            for: language,
            primaryArabic: arabicContent,
            fallback: content,
            secondFallback: summary(for: language)
        )
    }

    func displaySender(fallback: String = "DU") -> String {
        let trimmed = sender.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return fallback
        }
        return trimmed
    }

    func markingRead() -> MessageCenterMessage {
        MessageCenterMessage(
            id: id,
            sender: sender,
            title: title,
            arabicTitle: arabicTitle,
            content: content,
            arabicContent: arabicContent,
            category: category,
            isRead: true,
            createdAt: createdAt
        )
    }

    private func preferredLocalizedValue(
        for language: AppLanguage,
        primaryArabic: String,
        fallback: String,
        secondFallback: String
    ) -> String {
        switch language {
        case .arabic:
            let arabicValue = primaryArabic.trimmingCharacters(in: .whitespacesAndNewlines)
            if !arabicValue.isEmpty {
                return arabicValue
            }
            fallthrough
        case .english, .simplifiedChinese:
            let primary = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
            if !primary.isEmpty {
                return primary
            }
            let secondary = secondFallback.trimmingCharacters(in: .whitespacesAndNewlines)
            if !secondary.isEmpty {
                return secondary
            }
            return displaySender()
        }
    }
}

struct MessageCenterBatchResult: Equatable, Sendable {
    let succeededMessageIDs: [String]
    let failedMessageIDs: [String]

    var hasFailures: Bool {
        !failedMessageIDs.isEmpty
    }
}

enum MessageCenterServiceError: Error, Equatable {
    case missingIdentity
    case featureUnavailable(message: String)
    case networkUnavailable

    var textValue: LocalizedTextValue {
        switch self {
        case .missingIdentity:
            return .key("messageCenter.error.missingIdentity")
        case let .featureUnavailable(message):
            return .literal(message)
        case .networkUnavailable:
            return .key("messageCenter.error.subtitle")
        }
    }
}

enum MessageCenterScreenState: Equatable {
    case idle
    case loading
    case loaded
    case empty
    case failed(LocalizedTextValue)
}

enum MessageCenterBannerStyle: Equatable {
    case error
    case warning
}

struct MessageCenterBanner: Identifiable, Equatable {
    let id = UUID()
    let message: LocalizedTextValue
    let style: MessageCenterBannerStyle
}
