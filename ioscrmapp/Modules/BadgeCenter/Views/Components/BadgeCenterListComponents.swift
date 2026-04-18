import SwiftUI

struct BadgeCenterOverviewCard: View {
    @Environment(\.duTheme) private var theme

    let displayName: String
    let overview: BadgeCenterOverview?
    let totalBadgeCount: Int
    let localized: (String, [String]) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: DUSpacing.md) {
            VStack(alignment: .leading, spacing: DUSpacing.xs) {
                Text(displayName)
                    .font(.du(.titleSmallStrong))
                    .foregroundColor(DUColorPrimitives.Neutral.white)
                Text(
                    localized(
                        "badgeCenter.overview.memberSubtitle",
                        [
                            String(overview?.acquiredCount ?? 0),
                            String(totalBadgeCount)
                        ]
                    )
                )
                .font(.du(.bodySmall))
                .foregroundColor(DUColorPrimitives.Neutral.white.opacity(0.84))
            }

            HStack(spacing: 0) {
                overviewStatItem(
                    titleKey: "badgeCenter.overview.acquired",
                    value: overview?.acquiredCount ?? 0
                )
                overviewDivider
                overviewStatItem(
                    titleKey: "badgeCenter.overview.locked",
                    value: overview?.lockedCount ?? 0
                )
                overviewDivider
                overviewStatItem(
                    titleKey: "badgeCenter.overview.expired",
                    value: overview?.expiredCount ?? 0
                )
            }
        }
        .padding(.horizontal, DUSpacing.lg)
        .padding(.vertical, DUSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [theme.colors.brand.secondary, theme.colors.brand.indigo, theme.colors.brand.magenta],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: theme.components.field.cornerRadius, style: .continuous))
        .shadow(
            color: theme.colors.brand.indigo.opacity(0.18),
            radius: DUElevation.lifted.radius,
            x: DUElevation.lifted.x,
            y: DUElevation.lifted.y
        )
    }

    private func overviewStatItem(titleKey: String, value: Int) -> some View {
        HStack(spacing: DUSpacing.xs) {
            Text(String(value))
                .font(.du(.hero))
                .foregroundColor(DUColorPrimitives.Neutral.white)
            Text(localized(titleKey, []))
                .font(.du(.labelStrong))
                .foregroundColor(DUColorPrimitives.Neutral.white.opacity(0.84))
        }
        .frame(maxWidth: .infinity)
    }

    private var overviewDivider: some View {
        Rectangle()
            .fill(DUColorPrimitives.Neutral.white.opacity(0.18))
            .frame(width: 1, height: 42)
    }
}

protocol BadgeFilterDisplayable {
    var filterDisplayTitleKey: String { get }
}

extension BadgeCategoryFilter: BadgeFilterDisplayable {
    var filterDisplayTitleKey: String { titleKey }
}

extension BadgeLevelFilter: BadgeFilterDisplayable {
    var filterDisplayTitleKey: String { titleKey }
}

struct BadgeFilterChip: View {
    @Environment(\.duTheme) private var theme

    let title: String
    var countText: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.du(.labelStrong))
                .foregroundColor(isSelected ? DUColorPrimitives.Neutral.white : theme.colors.text.secondary)
                .padding(.horizontal, DUSpacing.md)
                .frame(height: 36)
                .background(isSelected ? theme.colors.brand.secondary : theme.colors.surface.card)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(theme.colors.border.subtle, lineWidth: isSelected ? 0 : 1)
                )
                .overlay(alignment: .topTrailing) {
                    if let countText {
                        Text(countText)
                            .font(.du(.tinyEmphasized))
                            .foregroundColor(isSelected ? theme.colors.brand.secondary : theme.colors.text.secondary)
                            .padding(.horizontal, DUSpacing.xs + 1)
                            .frame(height: 16)
                            .background(isSelected ? DUColorPrimitives.Neutral.white : theme.colors.background.secondary)
                            .clipShape(Capsule())
                            .offset(x: 6, y: -6)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

struct BadgeCardView: View {
    @Environment(\.duTheme) private var theme

    let badge: BadgeSummary
    let localized: (String, [String]) -> String
    let localizedText: (LocalizedTextValue?) -> String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .center, spacing: DUSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(badge.accentGradient(theme: theme))
                        .frame(width: 54, height: 54)

                    BadgeRemoteIconView(
                        assetName: badge.iconAssetName,
                        url: badge.iconURL,
                        fallbackSystemName: badge.iconSystemName,
                        symbolFont: .du(.titleStrong),
                        padding: 10
                    )
                }

                Text(localizedText(badge.title))
                    .font(.du(.bodySmallEmphasized))
                    .foregroundColor(badge.cardTitleColor(theme: theme))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text(cardSupportingText)
                    .font(.du(.tiny))
                    .foregroundColor(badge.cardBodyColor(theme: theme))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity)

                BadgeSmallPill(
                    title: localized(badge.status.titleKey, []),
                    color: badge.status.statusColor(theme: theme)
                )
            }
            .padding(.horizontal, DUSpacing.sm)
            .padding(.vertical, DUSpacing.md)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 142, alignment: .top)
            .background(theme.colors.surface.card)
            .clipShape(RoundedRectangle(cornerRadius: theme.components.sheet.cornerRadius, style: .continuous))
            .shadow(
                color: theme.components.card.elevation.color,
                radius: DUElevation.control.radius,
                x: DUElevation.control.x,
                y: DUElevation.control.y
            )
            .overlay(lockedOverlay)
            .overlay(alignment: .topTrailing) {
                if badge.isUnread {
                    Circle()
                        .fill(theme.colors.status.error)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(theme.colors.surface.card, lineWidth: 2)
                        )
                        .padding(DUSpacing.md)
                }
            }
            .grayscale(badge.status == .expired ? 0.7 : 0)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("badgeCenter.card.\(badge.id)")
    }

    private var cardSupportingText: String {
        if badge.status == .locked {
            return localizedText(badge.progress?.summary ?? badge.lockHint ?? badge.subtitle)
        }

        if badge.status == .expired {
            return localizedText(badge.statusHint)
        }

        return localizedText(badge.subtitle)
    }

    @ViewBuilder
    private var lockedOverlay: some View {
        if badge.status == .locked {
            RoundedRectangle(cornerRadius: theme.components.sheet.cornerRadius, style: .continuous)
                .fill(lockedOverlayFill)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.components.sheet.cornerRadius, style: .continuous)
                        .stroke(theme.colors.border.default, lineWidth: 1)
                )
        }
    }

    private var lockedOverlayFill: Color {
        switch theme.resolvedColorScheme {
        case .dark:
            return DUColorPrimitives.Neutral.white.opacity(0.12)
        case .light:
            fallthrough
        @unknown default:
            return DUColorPrimitives.Neutral.white.opacity(0.5)
        }
    }
}
