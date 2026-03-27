import SwiftUI

struct BadgeCenterOverviewCard: View {
    let displayName: String
    let overview: BadgeCenterOverview?
    let totalBadgeCount: Int
    let localized: (String, [String]) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: DUSpacing.md) {
            VStack(alignment: .leading, spacing: DUSpacing.xs) {
                Text(displayName)
                    .font(.du(18, weight: .bold))
                    .foregroundColor(.white)
                Text(
                    localized(
                        "badgeCenter.overview.memberSubtitle",
                        [
                            String(overview?.acquiredCount ?? 0),
                            String(totalBadgeCount)
                        ]
                    )
                )
                .font(.du(12, weight: .medium))
                .foregroundColor(.white.opacity(0.84))
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
                colors: [DUTheme.blue, DUTheme.indigo, DUTheme.magenta],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: DUTheme.indigo.opacity(0.18), radius: 14, x: 0, y: 8)
    }

    private func overviewStatItem(titleKey: String, value: Int) -> some View {
        HStack(spacing: DUSpacing.xs) {
            Text(String(value))
                .font(.du(28, weight: .bold))
                .foregroundColor(.white)
            Text(localized(titleKey, []))
                .font(.du(13, weight: .semibold))
                .foregroundColor(.white.opacity(0.84))
        }
        .frame(maxWidth: .infinity)
    }

    private var overviewDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.18))
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
    let title: String
    var countText: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.du(13, weight: .semibold))
                .foregroundColor(isSelected ? .white : DUTheme.inkSecondary)
                .padding(.horizontal, DUSpacing.md)
                .frame(height: 36)
                .background(isSelected ? DUTheme.blue : Color.white)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(DUTheme.lineLight, lineWidth: isSelected ? 0 : 1)
                )
                .overlay(alignment: .topTrailing) {
                    if let countText {
                        Text(countText)
                            .font(.du(10, weight: .bold))
                            .foregroundColor(isSelected ? DUTheme.blue : DUTheme.inkSecondary)
                            .padding(.horizontal, 5)
                            .frame(height: 16)
                            .background(isSelected ? Color.white : Color(hex: 0xF1F3F6))
                            .clipShape(Capsule())
                            .offset(x: 6, y: -6)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

struct BadgeCardView: View {
    let badge: BadgeSummary
    let localized: (String, [String]) -> String
    let localizedText: (LocalizedTextValue?) -> String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .center, spacing: DUSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(badge.accentGradient)
                        .frame(width: 54, height: 54)

                    BadgeRemoteIconView(
                        url: badge.iconURL,
                        fallbackSystemName: badge.iconSystemName,
                        symbolFont: .du(22, weight: .bold),
                        padding: 10
                    )
                }

                Text(localizedText(badge.title))
                    .font(.du(14, weight: .bold))
                    .foregroundColor(badge.cardTitleColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text(cardSupportingText)
                    .font(.du(10, weight: .medium))
                    .foregroundColor(badge.cardBodyColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity)

                BadgeSmallPill(
                    title: localized(badge.status.titleKey, []),
                    color: badge.status.statusColor
                )
            }
            .padding(.horizontal, DUSpacing.sm)
            .padding(.vertical, DUSpacing.md)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 142, alignment: .top)
            .background(DUTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 6)
            .overlay(lockedOverlay)
            .overlay(alignment: .topTrailing) {
                if badge.isUnread {
                    Circle()
                        .fill(DUTheme.error)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
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
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(DUTheme.line, lineWidth: 1)
                )
        }
    }
}
