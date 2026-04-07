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
            .foregroundColor(.white)
            .padding(padding)
    }
}

struct BadgeSmallPill: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.du(11, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, DUSpacing.sm)
            .frame(height: 24)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

extension BadgeSummary {
    var accentGradient: LinearGradient {
        accentStyle.gradient
    }

    var cardTitleColor: Color {
        status == .locked ? DUTheme.inkSecondary : DUTheme.ink
    }

    var cardBodyColor: Color {
        switch status {
        case .acquired:
            return DUTheme.inkSecondary
        case .locked, .expired:
            return DUTheme.inkTertiary
        }
    }
}

extension BadgeDetail {
    var accentGradient: LinearGradient {
        accentStyle.gradient
    }
}

extension BadgeDisplayStatus {
    var statusColor: Color {
        switch self {
        case .acquired:
            return DUTheme.success
        case .locked:
            return DUTheme.warning
        case .expired:
            return DUTheme.inkDisabled
        }
    }
}

extension BadgeBenefitStatus {
    var statusColor: Color {
        switch self {
        case .active:
            return DUTheme.success
        case .upcoming:
            return DUTheme.warning
        case .unavailable, .expired:
            return DUTheme.inkDisabled
        }
    }
}

extension BadgeLevel {
    var levelColor: Color {
        switch self {
        case .base:
            return DUTheme.cyan
        case .advanced:
            return DUTheme.blue
        case .premium:
            return DUTheme.magenta
        case .ultimate:
            return DUTheme.warning
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
}
