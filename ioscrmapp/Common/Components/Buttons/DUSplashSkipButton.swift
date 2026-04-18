import SwiftUI

struct DUSplashSkipButton: View {
    @Environment(\.duTheme) private var theme

    let title: String
    let progress: Double
    let isEnabled: Bool
    let action: () -> Void

    private var clampedProgress: CGFloat {
        CGFloat(max(0, min(progress, 1)))
    }

    private let buttonWidth: CGFloat = 72
    private let buttonHeight: CGFloat = 31

    var body: some View {
        Button(action: action) {
            ZStack {
                Capsule()
                    .fill(isEnabled ? theme.colors.chrome.splash : theme.colors.chrome.splashDisabled)

                Capsule()
                    .strokeBorder(DUColorPrimitives.Neutral.white.opacity(0.24), lineWidth: 1.25)

                SplashSkipProgressShape()
                    .trim(from: 0, to: clampedProgress)
                    .stroke(
                        theme.colors.chrome.splashProgressFill,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                    )
                    .padding(1.5)

                Text(title)
                    .font(.du(12, weight: .bold))
                    .foregroundColor(DUColorPrimitives.Neutral.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, DUSpacing.sm)
            }
            .frame(width: buttonWidth, height: buttonHeight)
        }
        .buttonStyle(.plain)
        .allowsHitTesting(isEnabled)
        .accessibilityLabel(title)
    }
}

private struct SplashSkipProgressShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = rect.height / 2
        let rightCenter = CGPoint(x: rect.maxX - radius, y: rect.midY)
        let leftCenter = CGPoint(x: rect.minX + radius, y: rect.midY)
        let topCenter = CGPoint(x: rect.midX, y: rect.minY)

        var path = Path()
        path.move(to: topCenter)
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addArc(
            center: rightCenter,
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(90),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addArc(
            center: leftCenter,
            radius: radius,
            startAngle: .degrees(90),
            endAngle: .degrees(270),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        return path
    }
}

struct DUSplashAudioButton: View {
    @Environment(\.duTheme) private var theme

    let accessibilityLabel: String
    let systemImageName: String
    let action: () -> Void

    private let buttonSize: CGFloat = 44

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImageName)
                .font(.du(16, weight: .semibold))
                .foregroundColor(DUColorPrimitives.Neutral.white)
                .frame(width: buttonSize, height: buttonSize)
                .background(theme.colors.chrome.splash)
                .overlay {
                    Circle()
                        .strokeBorder(DUColorPrimitives.Neutral.white.opacity(0.24), lineWidth: 1.25)
                }
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
