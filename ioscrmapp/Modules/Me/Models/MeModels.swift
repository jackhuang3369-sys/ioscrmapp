import Foundation

struct MeContent {
    let profile: MeProfileSummary
    let stats: [MeStatItem]
    let badges: [MeBadgeItem]
    let menuGroups: [MeMenuGroup]

    var isEffectivelyEmpty: Bool {
        stats.isEmpty && badges.isEmpty && menuGroups.allSatisfy { $0.items.isEmpty }
    }
}

struct MeProfileSummary {
    let displayName: String
    let maskedPhoneNumber: String
    let fullPhoneNumber: String
    let membershipLabel: String
    let initials: String
}

struct MeStatItem: Identifiable {
    let id: String
    let title: String
    let value: String
    let assetName: String
    let actionTitle: String
}

struct MeBadgeItem: Identifiable {
    let id: String
    let title: String
    let assetName: String
    let actionTitle: String
}

struct MeMenuGroup: Identifiable {
    let id: String
    let items: [MeMenuItem]
}

struct MeMenuItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let assetName: String
    let actionTitle: String
    let accessory: MeMenuAccessory
}

enum MeMenuAccessory {
    case chevron
    case badge(String)
}

enum MePhoneNumberFormatter {
    static func masked(_ value: String) -> String {
        let localDigits = AuthValidator.localPhoneDigits(value)
        guard localDigits.count == AuthValidator.localPhoneLength else {
            return AuthValidator.formattedPhone(value)
        }

        let prefix = localDigits.prefix(2)
        let suffix = localDigits.suffix(4)
        return "+\(AuthValidator.countryCode) \(prefix)***\(suffix)"
    }
}
