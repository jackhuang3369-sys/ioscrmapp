import Foundation

protocol MeServicing: Sendable {
    func fetchMeContent(session: UserSession) async throws -> MeContent
    func validateRevealPassword(_ password: String, session: UserSession) async throws -> Bool
}

enum MeServiceError: Error, LocalizedError {
    case invalidPassword
    case featureUnavailable(message: String)
    case networkUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidPassword:
            return "Enter the correct password to reveal the full phone number."
        case let .featureUnavailable(message):
            return message
        case .networkUnavailable:
            return "Unable to load your profile right now. Please try again."
        }
    }
}

actor MockMeService: MeServicing {
    enum Mode: Sendable {
        case loaded
        case empty
        case failed
    }

    private let mode: Mode

    init(mode: Mode = .loaded) {
        self.mode = mode
    }

    func fetchMeContent(session: UserSession) async throws -> MeContent {
        switch mode {
        case .loaded:
            return buildContent(session: session, includeContent: true)
        case .empty:
            return buildContent(session: session, includeContent: false)
        case .failed:
            throw MeServiceError.networkUnavailable
        }
    }

    func validateRevealPassword(_ password: String, session: UserSession) async throws -> Bool {
        let normalizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPassword.isEmpty else {
            throw MeServiceError.invalidPassword
        }
        return normalizedPassword == AuthValidator.demoPassword
    }

    private func buildContent(session: UserSession, includeContent: Bool) -> MeContent {
        let profile = MeProfileSummary(
            displayName: session.displayName,
            maskedPhoneNumber: MePhoneNumberFormatter.masked(session.phoneNumber),
            fullPhoneNumber: AuthValidator.formattedPhone(session.phoneNumber),
            membershipLabel: "VIP Member",
            initials: String(session.displayName.prefix(2)).uppercased()
        )

        let stats = [
            MeStatItem(
                id: "balance",
                title: "Balance (AED)",
                value: session.balanceText.replacingOccurrences(of: " AED", with: ""),
                assetName: "MeStatBalanceIcon",
                actionTitle: "Balance"
            ),
            MeStatItem(
                id: "points",
                title: "Points",
                value: "2,580",
                assetName: "MeStatPointsIcon",
                actionTitle: "Points"
            ),
            MeStatItem(
                id: "coupons",
                title: "Coupons",
                value: "5",
                assetName: "MeStatCouponsIcon",
                actionTitle: "Coupons"
            ),
            MeStatItem(
                id: "badges",
                title: "Badges",
                value: "12",
                assetName: "MeStatBadgesIcon",
                actionTitle: "Badges"
            )
        ]

        let badges = includeContent
            ? [
                MeBadgeItem(id: "new-user", title: "New User", assetName: "MeBadgeNewUserIcon", actionTitle: "New User badge"),
                MeBadgeItem(id: "first-recharge", title: "First Recharge", assetName: "MeBadgeRechargeIcon", actionTitle: "First Recharge badge"),
                MeBadgeItem(id: "first-order", title: "First Order", assetName: "MeBadgeOrderIcon", actionTitle: "First Order badge"),
                MeBadgeItem(id: "vip", title: "VIP Member", assetName: "MeBadgeVipIcon", actionTitle: "VIP Member badge"),
                MeBadgeItem(id: "streak", title: "Streak", assetName: "MeBadgeStreakIcon", actionTitle: "Streak badge")
            ]
            : []

        let menuGroups = includeContent
            ? [
                MeMenuGroup(
                    id: "telecom",
                    items: [
                        MeMenuItem(id: "plan", title: "My Plan", subtitle: "Premium Plan 99 AED/month", assetName: "MeMenuPlanIcon", actionTitle: "My Plan", accessory: .chevron),
                        MeMenuItem(id: "data", title: "Data Management", subtitle: "8.5GB remaining", assetName: "MeMenuDataIcon", actionTitle: "Data Management", accessory: .chevron),
                        MeMenuItem(id: "billing", title: "Billing", subtitle: "View billing history", assetName: "MeMenuBillingIcon", actionTitle: "Billing", accessory: .badge("New"))
                    ]
                ),
                MeMenuGroup(
                    id: "account",
                    items: [
                        MeMenuItem(id: "orders", title: "My Orders", subtitle: "View all orders", assetName: "MeMenuOrdersIcon", actionTitle: "My Orders", accessory: .chevron),
                        MeMenuItem(id: "favorites", title: "Favorites", subtitle: "Saved items and content", assetName: "MeMenuFavoritesIcon", actionTitle: "Favorites", accessory: .chevron),
                        MeMenuItem(id: "address", title: "Delivery Address", subtitle: "Manage addresses", assetName: "MeMenuAddressIcon", actionTitle: "Delivery Address", accessory: .chevron)
                    ]
                ),
                MeMenuGroup(
                    id: "settings",
                    items: [
                        MeMenuItem(id: "settings", title: "Settings", subtitle: "Account, notifications, privacy", assetName: "MeMenuSettingsIcon", actionTitle: "Settings", accessory: .chevron),
                        MeMenuItem(id: "help", title: "Help & Feedback", subtitle: "FAQ, customer service", assetName: "MeMenuHelpIcon", actionTitle: "Help & Feedback", accessory: .chevron),
                        MeMenuItem(id: "about", title: "About Us", subtitle: "Version \(AppVersionFormatter.currentVersion)", assetName: "MeMenuAboutIcon", actionTitle: "About Us", accessory: .chevron)
                    ]
                )
            ]
            : []

        return MeContent(profile: profile, stats: stats, badges: badges, menuGroups: menuGroups)
    }
}

/// Reserved for future server integration. Replace `MockMeService` injection with this
/// implementation after the profile-related endpoints are available and mapped.
struct RemoteMeService: MeServicing {
    let serverURL: URL

    func fetchMeContent(session: UserSession) async throws -> MeContent {
        throw MeServiceError.featureUnavailable(message: "Remote profile service is not configured yet.")
    }

    func validateRevealPassword(_ password: String, session: UserSession) async throws -> Bool {
        throw MeServiceError.featureUnavailable(message: "Remote password verification is not configured yet.")
    }
}

private enum AppVersionFormatter {
    static var currentVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        return version
    }
}
