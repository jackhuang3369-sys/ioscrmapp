import Foundation

protocol MeServicing: Sendable {
    func fetchMeContent(session: UserSession) async throws -> MeContent
    func validateRevealPassword(_ password: String, session: UserSession) async throws -> Bool
}

enum MeServiceError: Error {
    case invalidPassword
    case featureUnavailable(message: String)
    case networkUnavailable

    var textValue: LocalizedTextValue {
        switch self {
        case .invalidPassword:
            return .key("me.reveal.invalidPassword")
        case let .featureUnavailable(message):
            return .literal(message)
        case .networkUnavailable:
            return .key("me.error.subtitle")
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
            membershipLabel: .key("me.membership.vip"),
            initials: String(session.displayName.prefix(2)).uppercased()
        )

        let stats = [
            MeStatItem(
                id: "balance",
                title: .key("me.stat.balance"),
                value: session.balanceText.replacingOccurrences(of: " AED", with: ""),
                assetName: "MeStatBalanceIcon",
                actionID: .balance
            ),
            MeStatItem(
                id: "points",
                title: .key("me.stat.points"),
                value: "2,580",
                assetName: "MeStatPointsIcon",
                actionID: .points
            ),
            MeStatItem(
                id: "coupons",
                title: .key("me.stat.coupons"),
                value: "5",
                assetName: "MeStatCouponsIcon",
                actionID: .coupons
            ),
            MeStatItem(
                id: "badges",
                title: .key("me.stat.badges"),
                value: "12",
                assetName: "MeStatBadgesIcon",
                actionID: .badges
            )
        ]

        let badges = includeContent
            ? [
                MeBadgeItem(id: "new-user", title: .key("me.badge.newUser"), assetName: "MeBadgeNewUserIcon", actionID: .badges),
                MeBadgeItem(id: "first-recharge", title: .key("me.badge.firstRecharge"), assetName: "MeBadgeRechargeIcon", actionID: .badges),
                MeBadgeItem(id: "first-order", title: .key("me.badge.firstOrder"), assetName: "MeBadgeOrderIcon", actionID: .badges),
                MeBadgeItem(id: "vip", title: .key("me.badge.vip"), assetName: "MeBadgeVipIcon", actionID: .badges),
                MeBadgeItem(id: "streak", title: .key("me.badge.streak"), assetName: "MeBadgeStreakIcon", actionID: .badges)
            ]
            : []

        let menuGroups = includeContent
            ? [
                MeMenuGroup(
                    id: "telecom",
                    items: [
                        MeMenuItem(id: "plan", title: .key("me.menu.plan.title"), subtitle: .key("me.menu.plan.subtitle"), assetName: "MeMenuPlanIcon", actionID: .myPlan, accessory: .chevron),
                        MeMenuItem(id: "data", title: .key("me.menu.data.title"), subtitle: .key("me.menu.data.subtitle"), assetName: "MeMenuDataIcon", actionID: .dataManagement, accessory: .chevron),
                        MeMenuItem(id: "billing", title: .key("me.menu.billing.title"), subtitle: .key("me.menu.billing.subtitle"), assetName: "MeMenuBillingIcon", actionID: .billing, accessory: .badge(.key("me.badge.new")))
                    ]
                ),
                MeMenuGroup(
                    id: "account",
                    items: [
                        MeMenuItem(id: "orders", title: .key("me.menu.orders.title"), subtitle: .key("me.menu.orders.subtitle"), assetName: "MeMenuOrdersIcon", actionID: .orders, accessory: .chevron),
                        MeMenuItem(id: "favorites", title: .key("me.menu.favorites.title"), subtitle: .key("me.menu.favorites.subtitle"), assetName: "MeMenuFavoritesIcon", actionID: .favorites, accessory: .chevron),
                        MeMenuItem(id: "address", title: .key("me.menu.address.title"), subtitle: .key("me.menu.address.subtitle"), assetName: "MeMenuAddressIcon", actionID: .address, accessory: .chevron)
                    ]
                ),
                MeMenuGroup(
                    id: "settings",
                    items: [
                        MeMenuItem(id: "language", title: .key("me.menu.language.title"), subtitle: .key("me.menu.language.subtitle"), assetName: "MeMenuSettingsIcon", actionID: .changeLanguage, accessory: .chevron),
                        MeMenuItem(id: "help", title: .key("me.menu.help.title"), subtitle: .key("me.menu.help.subtitle"), assetName: "MeMenuHelpIcon", actionID: .help, accessory: .chevron),
                        MeMenuItem(id: "about", title: .key("me.menu.about.title"), subtitle: .key("me.menu.about.subtitle", arguments: [AppVersionFormatter.currentVersion]), assetName: "MeMenuAboutIcon", actionID: .about, accessory: .chevron)
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
