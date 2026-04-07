import SwiftUI

struct BadgeUnlockPromptView: View {
    let event: BadgeUnlockEvent
    let isLoading: Bool
    let onLater: () -> Void
    let onViewNow: () -> Void
    let localized: (String, [String]) -> String

    var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: DUSpacing.lg) {
                HStack(spacing: DUSpacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(DUTheme.brandGradient)
                            .frame(width: 64, height: 64)

                        BadgeRemoteIconView(
                            assetName: event.iconAssetName,
                            url: event.iconURL,
                            fallbackSystemName: "sparkles",
                            symbolFont: .du(28, weight: .bold),
                            padding: 12
                        )
                    }

                    VStack(alignment: .leading, spacing: DUSpacing.xs) {
                        Text(localized(event.title))
                            .font(.du(20, weight: .bold))
                            .foregroundColor(DUTheme.ink)
                        Text(localized(event.badgeName))
                            .font(.du(14, weight: .semibold))
                            .foregroundColor(DUTheme.cyan)
                    }

                    Spacer()
                }

                Text(localized(event.message))
                    .font(.du(14, weight: .medium))
                    .foregroundColor(DUTheme.inkSecondary)
                    .multilineTextAlignment(.leading)

                HStack(spacing: DUSpacing.md) {
                    DUButton(
                        title: localized("badgeCenter.popup.later", []),
                        style: .secondary,
                        isEnabled: !isLoading,
                        height: 48,
                        action: onLater
                    )
                    .accessibilityIdentifier("badgeCenter.unlockPrompt.laterButton")

                    DUButton(
                        title: localized("badgeCenter.popup.viewNow", []),
                        style: .primary,
                        isLoading: isLoading,
                        isEnabled: !isLoading,
                        height: 48,
                        action: onViewNow
                    )
                    .accessibilityIdentifier("badgeCenter.unlockPrompt.viewNowButton")
                }
            }
            .padding(DUSpacing.xl)
            .background(DUTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(.horizontal, DUSpacing.xl)
            .accessibilityIdentifier("badgeCenter.unlockPrompt")
        }
    }

    private func localized(_ value: LocalizedTextValue?) -> String {
        switch value {
        case let .localized(key, arguments):
            return localized(key, arguments)
        case let .literal(text):
            return text
        case .none:
            return ""
        }
    }
}
