import Foundation

enum BadgeCategoryFilter: CaseIterable, Identifiable, Sendable {
    case all
    case newcomer
    case daily
    case challenge
    case event
    case cycle
    case ultimate

    var id: String { titleKeySuffix }

    var titleKey: String {
        "badgeCenter.filter.category.\(titleKeySuffix)"
    }

    var backendCode: String {
        switch self {
        case .all:
            return "ALL"
        case .newcomer:
            return "NEW"
        case .daily:
            return "DAILY"
        case .challenge:
            return "CHALLENGE"
        case .event:
            return "EVENT"
        case .cycle:
            return "CYCLE"
        case .ultimate:
            return "ULTIMATE"
        }
    }

    init?(backendCode: String?) {
        switch backendCode?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "ALL":
            self = .all
        case "NEW":
            self = .newcomer
        case "DAILY":
            self = .daily
        case "CHALLENGE":
            self = .challenge
        case "EVENT":
            self = .event
        case "CYCLE":
            self = .cycle
        case "ULTIMATE":
            self = .ultimate
        default:
            return nil
        }
    }

    private var titleKeySuffix: String {
        switch self {
        case .all:
            return "all"
        case .newcomer:
            return "new"
        case .daily:
            return "daily"
        case .challenge:
            return "challenge"
        case .event:
            return "event"
        case .cycle:
            return "cycle"
        case .ultimate:
            return "ultimate"
        }
    }
}

enum BadgeStatusFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case acquired
    case locked
    case expired

    var id: String { rawValue }

    var titleKey: String {
        "badgeCenter.filter.status.\(rawValue)"
    }

    var backendCode: String {
        switch self {
        case .all:
            return "ALL"
        case .acquired:
            return "ACQUIRED"
        case .locked:
            return "LOCKED"
        case .expired:
            return "EXPIRED"
        }
    }
}

enum BadgeLevelFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case base
    case advanced
    case premium
    case ultimate

    var id: String { rawValue }

    var titleKey: String {
        "badgeCenter.filter.level.\(rawValue)"
    }

    var backendCode: String {
        switch self {
        case .all:
            return "ALL"
        case .base:
            return "BASIC"
        case .advanced:
            return "MID"
        case .premium:
            return "HIGH"
        case .ultimate:
            return "ULTIMATE"
        }
    }
}

enum BadgeDisplayStatus: String, Sendable {
    case acquired
    case locked
    case expired

    init?(backendCode: String?) {
        switch backendCode?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "ACQUIRED":
            self = .acquired
        case "LOCKED":
            self = .locked
        case "EXPIRED":
            self = .expired
        default:
            return nil
        }
    }

    var titleKey: String {
        "badgeCenter.status.\(rawValue)"
    }
}

enum BadgeLevel: String, Sendable {
    case base
    case advanced
    case premium
    case ultimate

    init?(backendCode: String?) {
        switch backendCode?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "BASIC":
            self = .base
        case "MID":
            self = .advanced
        case "HIGH":
            self = .premium
        case "ULTIMATE":
            self = .ultimate
        default:
            return nil
        }
    }

    var titleKey: String {
        "badgeCenter.level.\(rawValue)"
    }
}

enum BadgeAccentStyle: String, Sendable {
    case aurora
    case ocean
    case sunrise
    case night
    case graphite
}

enum BadgeBenefitStatus: String, Sendable {
    case active
    case upcoming
    case unavailable
    case expired

    var titleKey: String {
        "badgeCenter.rewardStatus.\(rawValue)"
    }
}

struct BadgeCenterSnapshot: Sendable {
    let overview: BadgeCenterOverview
    let badges: [BadgeSummary]
    let pendingUnlockEvent: BadgeUnlockEvent?

    var totalCount: Int {
        badges.count
    }

    func count(for category: BadgeCategoryFilter) -> Int {
        guard category != .all else {
            return badges.count
        }
        return badges.filter { $0.category == category }.count
    }

    func count(for status: BadgeStatusFilter) -> Int {
        switch status {
        case .all:
            return badges.count
        case .acquired:
            return badges.filter { $0.status == .acquired }.count
        case .locked:
            return badges.filter { $0.status == .locked }.count
        case .expired:
            return badges.filter { $0.status == .expired }.count
        }
    }

    func count(for level: BadgeLevelFilter) -> Int {
        guard level != .all else {
            return badges.count
        }

        return badges.filter { badge in
            switch level {
            case .all:
                return true
            case .base:
                return badge.level == .base
            case .advanced:
                return badge.level == .advanced
            case .premium:
                return badge.level == .premium
            case .ultimate:
                return badge.level == .ultimate
            }
        }.count
    }
}

struct BadgeCenterOverview: Sendable {
    let acquiredCount: Int
    let lockedCount: Int
    let expiredCount: Int
    let unreadCount: Int
    let featuredCount: Int
}

struct BadgeProgressSnapshot: Sendable {
    let currentValue: Int
    let targetValue: Int
    let summary: LocalizedTextValue

    var completionRatio: Double {
        guard targetValue > 0 else {
            return 0
        }
        return min(max(Double(currentValue) / Double(targetValue), 0), 1)
    }
}

struct BadgeSummary: Identifiable, Sendable {
    let id: String
    let category: BadgeCategoryFilter
    let status: BadgeDisplayStatus
    let level: BadgeLevel
    let accentStyle: BadgeAccentStyle
    let iconAssetName: String?
    let iconSystemName: String
    let iconURL: URL?
    let iconHDURL: URL?
    let backgroundURL: URL?
    let title: LocalizedTextValue
    let subtitle: LocalizedTextValue
    let englishName: String
    let arabicName: String
    let requirementSummary: LocalizedTextValue
    let rewardSummary: LocalizedTextValue
    let acquiredAt: Date?
    let acquisitionTimeText: String?
    let badgeStoryPreview: LocalizedTextValue
    let statusHint: LocalizedTextValue
    let lockHint: LocalizedTextValue?
    let progress: BadgeProgressSnapshot?
    let isUnread: Bool
    let isFeatured: Bool
}

struct BadgeDetail: Identifiable, Sendable {
    let id: String
    let category: BadgeCategoryFilter
    let status: BadgeDisplayStatus
    let level: BadgeLevel
    let accentStyle: BadgeAccentStyle
    let iconAssetName: String?
    let iconSystemName: String
    let iconURL: URL?
    let iconHDURL: URL?
    let backgroundURL: URL?
    let title: LocalizedTextValue
    let subtitle: LocalizedTextValue
    let englishName: String
    let arabicName: String
    let requirementItems: [BadgeRequirementItem]
    let rewardItems: [BadgeRewardItem]
    let acquisitionTimeText: String?
    let badgeStory: LocalizedTextValue
    let statusHint: LocalizedTextValue
    let validityText: LocalizedTextValue
    let triggerText: LocalizedTextValue
    let history: [BadgeHistoryItem]
    let progress: BadgeProgressSnapshot?
    let isUnread: Bool
    let isFeatured: Bool
}

struct BadgeRequirementItem: Identifiable, Sendable {
    let id: String
    let title: LocalizedTextValue
    let isCompleted: Bool
}

struct BadgeRewardItem: Identifiable, Sendable {
    let id: String
    let title: LocalizedTextValue
    let status: BadgeBenefitStatus
    let description: LocalizedTextValue
}

struct BadgeHistoryItem: Identifiable, Sendable {
    let id: String
    let title: LocalizedTextValue
    let subtitle: LocalizedTextValue
    let timestampText: String
}

struct BadgeUnlockEvent: Identifiable, Sendable {
    let id: String
    let badgeID: String
    let title: LocalizedTextValue
    let badgeName: LocalizedTextValue
    let message: LocalizedTextValue
    let iconAssetName: String?
    let iconURL: URL?
}

extension BadgeLevel {
    var sortRank: Int {
        switch self {
        case .base:
            return 1
        case .advanced:
            return 2
        case .premium:
            return 3
        case .ultimate:
            return 4
        }
    }
}
