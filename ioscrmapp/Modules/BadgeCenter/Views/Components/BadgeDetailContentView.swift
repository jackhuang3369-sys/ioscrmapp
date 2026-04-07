import SwiftUI

struct BadgeDetailContentView: View {
    let badge: BadgeDetail
    let localized: (String, [String]) -> String
    let localizedText: (LocalizedTextValue?) -> String

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: DUSpacing.lg) {
                heroCard
                metaSection
                requirementsSection
                rewardsSection
                storySection
                historySection
            }
            .padding(DUSpacing.lg)
            .padding(.bottom, DUSpacing.xxxl)
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: DUSpacing.lg) {
            HStack(alignment: .center, spacing: DUSpacing.lg) {
                ZStack {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(badge.accentGradient)
                        .frame(width: 98, height: 98)

                    BadgeRemoteIconView(
                        assetName: badge.iconAssetName,
                        url: badge.iconURL,
                        fallbackSystemName: badge.iconSystemName,
                        symbolFont: .du(42, weight: .bold),
                        padding: 18
                    )
                }

                VStack(alignment: .leading, spacing: DUSpacing.sm) {
                    Text(localizedText(badge.title))
                        .font(.du(24, weight: .bold))
                        .foregroundColor(.white)
                    Text(localizedText(badge.subtitle))
                        .font(.du(13, weight: .medium))
                        .foregroundColor(.white.opacity(0.88))

                    HStack(spacing: DUSpacing.sm) {
                        BadgeSmallPill(
                            title: localized(badge.level.titleKey, []),
                            color: badge.level.levelColor
                        )
                        BadgeSmallPill(
                            title: localized(badge.category.titleKey, []),
                            color: .white
                        )
                    }
                }

                Spacer(minLength: 0)
            }

            if let progress = badge.progress {
                VStack(alignment: .leading, spacing: DUSpacing.xs) {
                    Text(localized("badgeCenter.detail.progress", []))
                        .font(.du(12, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                    ProgressView(value: progress.completionRatio)
                        .tint(.white)
                    Text(localizedText(progress.summary))
                        .font(.du(12, weight: .medium))
                        .foregroundColor(.white.opacity(0.88))
                }
            }
        }
        .padding(DUSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(heroBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: badge.level.levelColor.opacity(0.22), radius: 18, x: 0, y: 10)
    }

    private var heroBackground: some View {
        ZStack {
            badge.accentGradient

            if let backgroundURL = badge.backgroundURL {
                AsyncImage(url: backgroundURL) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Color.clear
                    }
                }
            }

            LinearGradient(
                colors: [Color.black.opacity(0.12), Color.black.opacity(0.38)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var metaSection: some View {
        DUSectionCard(title: localized("badgeCenter.detail.meta", [])) {
            VStack(spacing: DUSpacing.md) {
                detailInfoRow(
                    title: localized("badgeCenter.detail.status", []),
                    value: localizedText(badge.statusHint)
                )
                detailInfoRow(
                    title: localized("badgeCenter.detail.acquisitionTime", []),
                    value: badge.acquisitionTimeText ?? localized("badgeCenter.detail.notAcquiredYet", [])
                )
                detailInfoRow(
                    title: localized("badgeCenter.detail.validity", []),
                    value: localizedText(badge.validityText)
                )
                detailInfoRow(
                    title: localized("badgeCenter.detail.trigger", []),
                    value: localizedText(badge.triggerText)
                )
            }
        }
    }

    private var requirementsSection: some View {
        DUSectionCard(title: localized("badgeCenter.detail.requirements", [])) {
            VStack(spacing: DUSpacing.md) {
                ForEach(badge.requirementItems) { item in
                    HStack(alignment: .top, spacing: DUSpacing.sm) {
                        Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "lock.circle.fill")
                            .font(.du(16, weight: .bold))
                            .foregroundColor(item.isCompleted ? DUTheme.success : DUTheme.warning)
                        Text(localizedText(item.title))
                            .font(.du(14, weight: .medium))
                            .foregroundColor(DUTheme.ink)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                }
            }
            .accessibilityIdentifier("badgeCenter.detail.\(badge.id).requirements")
        }
    }

    private var rewardsSection: some View {
        DUSectionCard(title: localized("badgeCenter.detail.rewards", [])) {
            VStack(spacing: DUSpacing.md) {
                ForEach(badge.rewardItems) { item in
                    VStack(alignment: .leading, spacing: DUSpacing.sm) {
                        HStack(spacing: DUSpacing.sm) {
                            Text(localizedText(item.title))
                                .font(.du(15, weight: .bold))
                                .foregroundColor(DUTheme.ink)
                            Spacer()
                            BadgeSmallPill(
                                title: localized(item.status.titleKey, []),
                                color: item.status.statusColor
                            )
                        }

                        Text(localizedText(item.description))
                            .font(.du(13, weight: .medium))
                            .foregroundColor(DUTheme.inkSecondary)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DUSpacing.md)
                    .background(DUTheme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
            .accessibilityIdentifier("badgeCenter.detail.\(badge.id).rewards")
        }
    }

    private var storySection: some View {
        DUSectionCard(title: localized("badgeCenter.detail.badgeStory", [])) {
            Text(localizedText(badge.badgeStory))
                .font(.du(14, weight: .medium))
                .foregroundColor(DUTheme.inkSecondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var historySection: some View {
        DUSectionCard(title: localized("badgeCenter.detail.history", [])) {
            Group {
                if badge.history.isEmpty {
                    Text(localized("badgeCenter.detail.historyEmpty", []))
                        .font(.du(13, weight: .medium))
                        .foregroundColor(DUTheme.inkTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(spacing: DUSpacing.md) {
                        ForEach(badge.history) { item in
                            VStack(alignment: .leading, spacing: DUSpacing.xs) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(localizedText(item.title))
                                        .font(.du(14, weight: .bold))
                                        .foregroundColor(DUTheme.ink)
                                    Spacer()
                                    Text(item.timestampText)
                                        .font(.du(11, weight: .semibold))
                                        .foregroundColor(DUTheme.inkTertiary)
                                }
                                Text(localizedText(item.subtitle))
                                    .font(.du(13, weight: .medium))
                                    .foregroundColor(DUTheme.inkSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(DUSpacing.md)
                            .background(DUTheme.background)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                    }
                }
            }
            .accessibilityIdentifier("badgeCenter.detail.\(badge.id).history")
        }
    }

    private func detailInfoRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DUSpacing.xs) {
            Text(title)
                .font(.du(12, weight: .bold))
                .foregroundColor(DUTheme.inkTertiary)
            Text(value)
                .font(.du(14, weight: .medium))
                .foregroundColor(DUTheme.ink)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
