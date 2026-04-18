import SwiftUI

struct BadgeUnlockPromptView: View {
    @Environment(\.duTheme) private var theme

    let event: BadgeUnlockEvent
    let isLoading: Bool
    let onLater: () -> Void
    let onViewNow: () -> Void
    let localized: (String, [String]) -> String

    var body: some View {
        ZStack {
            theme.colors.chrome.splashDisabled
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: DUSpacing.lg) {
                HStack(spacing: DUSpacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: theme.components.card.cornerRadius, style: .continuous)
                            .fill(theme.colors.gradient.brand)
                            .frame(width: 64, height: 64)

                        BadgeRemoteIconView(
                            assetName: event.iconAssetName,
                            url: event.iconURL,
                            fallbackSystemName: "sparkles",
                            symbolFont: .du(.hero),
                            padding: 12
                        )
                    }

                    VStack(alignment: .leading, spacing: DUSpacing.xs) {
                        Text(localized(event.title))
                            .font(.du(.title))
                            .foregroundColor(theme.colors.text.primary)
                        Text(localized(event.badgeName))
                            .font(.du(.bodySmallStrong))
                            .foregroundColor(theme.colors.action.primary)
                    }

                    Spacer()
                }

                Text(localized(event.message))
                    .font(.du(.bodySmall))
                    .foregroundColor(theme.colors.text.secondary)
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
            .background(theme.colors.surface.card)
            .clipShape(RoundedRectangle(cornerRadius: DURadius.hero, style: .continuous))
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
