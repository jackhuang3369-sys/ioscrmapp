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
    let membershipLabel: LocalizedTextValue
    let initials: String
}

struct MeStatItem: Identifiable {
    let id: String
    let title: LocalizedTextValue
    let value: String
    let assetName: String
    let actionID: MeActionID
}

struct MeBadgeItem: Identifiable {
    let id: String
    let title: LocalizedTextValue
    let iconAssetName: String?
    let assetName: String?
    let remoteIconURL: URL?
    let fallbackSystemName: String
    let accentStyle: BadgeAccentStyle
    let isUnread: Bool
    let actionID: MeActionID
}

struct MeMenuGroup: Identifiable {
    let id: String
    let items: [MeMenuItem]
}

struct MeMenuItem: Identifiable {
    let id: String
    let title: LocalizedTextValue
    let subtitle: LocalizedTextValue
    let assetName: String
    let actionID: MeActionID
    let accessory: MeMenuAccessory
}

enum MeMenuAccessory {
    case chevron
    case badge(LocalizedTextValue)
}

enum MeActionID: String, Sendable {
    case balance
    case points
    case coupons
    case badges
    case myPlan
    case dataManagement
    case billing
    case orders
    case favorites
    case address
    case changeLanguage
    case changeTheme
    case help
    case about
}

enum MePhoneNumberFormatter {
    static func masked(_ value: String) -> String {
        let normalizedPhone = AuthValidator.normalizedPhone(value)
        guard normalizedPhone.count == AuthValidator.fullPhoneLength else {
            return AuthValidator.formattedPhone(value)
        }

        let prefix = normalizedPhone.prefix(5)
        let suffix = normalizedPhone.suffix(4)
        return "\(prefix)***\(suffix)"
    }
}
