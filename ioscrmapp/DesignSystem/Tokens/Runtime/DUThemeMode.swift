import Foundation

enum DUThemeMode: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayNameKey: String {
        switch self {
        case .system:
            return "theme.mode.system.title"
        case .light:
            return "theme.mode.light.title"
        case .dark:
            return "theme.mode.dark.title"
        }
    }

    var descriptionKey: String {
        switch self {
        case .system:
            return "theme.mode.system.subtitle"
        case .light:
            return "theme.mode.light.subtitle"
        case .dark:
            return "theme.mode.dark.subtitle"
        }
    }
}
