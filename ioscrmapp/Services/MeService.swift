import Foundation

protocol MeServicing: Sendable {
    func fetchMeContent(session: CustSubInfo, language: AppLanguage) async throws -> MeContent
    func validateRevealPassword(_ password: String, session: CustSubInfo) async throws -> Bool
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
    private let badgeCenterService: any BadgeCenterServicing

    init(
        mode: Mode = .loaded,
        badgeCenterService: any BadgeCenterServicing = MockBadgeCenterService()
    ) {
        self.mode = mode
        self.badgeCenterService = badgeCenterService
    }

    func fetchMeContent(session: CustSubInfo, language: AppLanguage) async throws -> MeContent {
        switch mode {
        case .loaded:
            return await buildContent(
                session: session,
                language: language,
                includeContent: true
            )
        case .empty:
            return await buildContent(
                session: session,
                language: language,
                includeContent: false
            )
        case .failed:
            throw MeServiceError.networkUnavailable
        }
    }

    func validateRevealPassword(_ password: String, session: CustSubInfo) async throws -> Bool {
        let normalizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPassword.isEmpty else {
            throw MeServiceError.invalidPassword
        }
        return normalizedPassword == AuthValidator.demoPassword
    }

    private func buildContent(
        session: CustSubInfo,
        language: AppLanguage,
        includeContent: Bool
    ) async -> MeContent {
        let profile = MeProfileSummary(
            displayName: session.displayName,
            maskedPhoneNumber: MePhoneNumberFormatter.masked(session.phoneNumber),
            fullPhoneNumber: AuthValidator.formattedPhone(session.phoneNumber),
            membershipLabel: .key("me.membership.vip"),
            initials: String(session.displayName.prefix(2)).uppercased()
        )

        let badgeSnapshot: BadgeCenterSnapshot? = if includeContent {
            try? await badgeCenterService.fetchBadgeCenter(
                session: session,
                language: language
            )
        } else {
            nil
        }

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
                value: badgeSnapshot.map { String($0.overview.acquiredCount) } ?? "12",
                assetName: "MeStatBadgesIcon",
                actionID: .badges
            )
        ]

        let badges = includeContent
            ? MeBadgePreviewBuilder.previewItems(from: badgeSnapshot)
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

struct RemoteMeService: MeServicing {
    private let fallbackService: MockMeService
    private let badgeCenterService: any BadgeCenterServicing

    init(
        badgeCenterService: any BadgeCenterServicing,
        fallbackService: MockMeService = MockMeService()
    ) {
        self.badgeCenterService = badgeCenterService
        self.fallbackService = fallbackService
    }

    func fetchMeContent(session: CustSubInfo, language: AppLanguage) async throws -> MeContent {
        let fallbackContent = try await fallbackService.fetchMeContent(
            session: session,
            language: language
        )

        guard
            let snapshot = try? await badgeCenterService.fetchBadgeCenter(
                session: session,
                language: language
            )
        else {
            return fallbackContent
        }

        let previewBadges = buildBadgePreviewItems(from: snapshot)
        return MeContent(
            profile: fallbackContent.profile,
            stats: mergedStats(
                from: fallbackContent.stats,
                acquiredBadgeCount: snapshot.overview.acquiredCount
            ),
            badges: previewBadges,
            menuGroups: fallbackContent.menuGroups
        )
    }

    func validateRevealPassword(_ password: String, session: CustSubInfo) async throws -> Bool {
        try await fallbackService.validateRevealPassword(password, session: session)
    }

    private func mergedStats(from stats: [MeStatItem], acquiredBadgeCount: Int) -> [MeStatItem] {
        stats.map { item in
            guard item.actionID == .badges else {
                return item
            }

            return MeStatItem(
                id: item.id,
                title: item.title,
                value: String(acquiredBadgeCount),
                assetName: item.assetName,
                actionID: item.actionID
            )
        }
    }

    private func buildBadgePreviewItems(from snapshot: BadgeCenterSnapshot) -> [MeBadgeItem] {
        MeBadgePreviewBuilder.previewItems(from: snapshot)
    }
}

private enum MeBadgePreviewBuilder {
    static func previewItems(from snapshot: BadgeCenterSnapshot?) -> [MeBadgeItem] {
        guard let snapshot else {
            return []
        }

        return snapshot.badges
            .filter { $0.status == .acquired }
            .sorted { lhs, rhs in
                if lhs.level.sortRank != rhs.level.sortRank {
                    return lhs.level.sortRank > rhs.level.sortRank
                }

                return (lhs.acquiredAt ?? .distantPast) > (rhs.acquiredAt ?? .distantPast)
            }
            .prefix(5)
            .map { badge in
                MeBadgeItem(
                    id: badge.id,
                    title: badge.title,
                    iconAssetName: badge.iconAssetName,
                    assetName: nil,
                    remoteIconURL: badge.iconURL,
                    fallbackSystemName: badge.iconSystemName,
                    accentStyle: badge.accentStyle,
                    isUnread: badge.isUnread,
                    actionID: .badges
                )
            }
    }
}

private enum AppVersionFormatter {
    static var currentVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        return version
    }
}
