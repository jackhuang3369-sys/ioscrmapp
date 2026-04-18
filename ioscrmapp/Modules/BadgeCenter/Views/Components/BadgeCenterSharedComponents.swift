import SwiftUI

struct BadgeRemoteIconView: View {
    let assetName: String?
    let url: URL?
    let fallbackSystemName: String
    let symbolFont: Font
    let padding: CGFloat

    var body: some View {
        Group {
            if let assetName {
                Image(assetName)
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .padding(padding)
            } else if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFit()
                            .padding(padding)
                    default:
                        fallbackIcon
                    }
                }
            } else {
                fallbackIcon
            }
        }
    }

    private var fallbackIcon: some View {
        Image(systemName: fallbackSystemName)
            .font(symbolFont)
            .foregroundColor(DUColorPrimitives.Neutral.white)
            .padding(padding)
    }
}

struct BadgeSmallPill: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.du(.captionEmphasized))
            .foregroundColor(color)
            .padding(.horizontal, DUSpacing.sm)
            .frame(height: 24)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

extension BadgeSummary {
    func accentGradient(theme: DUTheme) -> LinearGradient {
        accentStyle.gradient(theme: theme)
    }

    func cardTitleColor(theme: DUTheme) -> Color {
        status == .locked ? theme.colors.text.secondary : theme.colors.text.primary
    }

    func cardBodyColor(theme: DUTheme) -> Color {
        switch status {
        case .acquired:
            return theme.colors.text.secondary
        case .locked, .expired:
            return theme.colors.text.tertiary
        }
    }
}

extension BadgeDetail {
    func accentGradient(theme: DUTheme) -> LinearGradient {
        accentStyle.gradient(theme: theme)
    }
}

extension BadgeDisplayStatus {
    func statusColor(theme: DUTheme) -> Color {
        switch self {
        case .acquired:
            return theme.colors.status.success
        case .locked:
            return theme.colors.status.warning
        case .expired:
            return theme.colors.text.disabled
        }
    }
}

extension BadgeBenefitStatus {
    func statusColor(theme: DUTheme) -> Color {
        switch self {
        case .active:
            return theme.colors.status.success
        case .upcoming:
            return theme.colors.status.warning
        case .unavailable, .expired:
            return theme.colors.text.disabled
        }
    }
}

extension BadgeLevel {
    func levelColor(theme: DUTheme) -> Color {
        switch self {
        case .base:
            return theme.colors.brand.primary
        case .advanced:
            return theme.colors.brand.secondary
        case .premium:
            return theme.colors.brand.magenta
        case .ultimate:
            return theme.colors.status.warning
        }
    }
}

extension BadgeAccentStyle {
    var gradient: LinearGradient {
        switch self {
        case .aurora:
            return LinearGradient(
                colors: [DUTheme.cyan, DUTheme.blue, DUTheme.indigo],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .ocean:
            return LinearGradient(
                colors: [DUTheme.blueLight, DUTheme.cyan, DUTheme.blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .sunrise:
            return LinearGradient(
                colors: [DUTheme.warning, DUTheme.magenta, DUTheme.indigo],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .night:
            return LinearGradient(
                colors: [DUTheme.ink, DUTheme.indigo, DUTheme.blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .graphite:
            return LinearGradient(
                colors: [DUTheme.inkSecondary, DUTheme.ink, DUTheme.inkTertiary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    func gradient(theme: DUTheme) -> LinearGradient {
        switch self {
        case .aurora:
            return LinearGradient(
                colors: [theme.colors.brand.primary, theme.colors.brand.secondary, theme.colors.brand.indigo],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .ocean:
            return LinearGradient(
                colors: [theme.colors.brand.secondaryLight, theme.colors.brand.primary, theme.colors.brand.secondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .sunrise:
            return LinearGradient(
                colors: [theme.colors.status.warning, theme.colors.brand.magenta, theme.colors.brand.indigo],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .night:
            return LinearGradient(
                colors: [theme.colors.text.primary, theme.colors.brand.indigo, theme.colors.brand.secondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .graphite:
            return LinearGradient(
                colors: [theme.colors.text.secondary, theme.colors.text.primary, theme.colors.text.tertiary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
