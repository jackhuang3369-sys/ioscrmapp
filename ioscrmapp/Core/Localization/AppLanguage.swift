import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case arabic = "ar"

    static let fallback: AppLanguage = .english

    var id: String { rawValue }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    var layoutDirection: LayoutDirection {
        switch self {
        case .arabic:
            return .rightToLeft
        case .english, .simplifiedChinese:
            return .leftToRight
        }
    }

    var nativeName: String {
        switch self {
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        case .arabic:
            return "العربية"
        }
    }

    var displayNameKey: String {
        switch self {
        case .english:
            return "language.name.english"
        case .simplifiedChinese:
            return "language.name.chinese"
        case .arabic:
            return "language.name.arabic"
        }
    }
}
