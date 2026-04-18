import SwiftUI

struct DUIconButton<Icon: View>: View {
    @Environment(\.duTheme) private var theme

    let title: String?
    var circleSize: CGFloat = 64
    var backgroundColor: Color?
    var titleColor: Color?
    var titleFontSize: CGFloat = 11
    var shadowColor: Color = .clear
    var shadowRadius: CGFloat = 0
    var shadowY: CGFloat = 0
    @ViewBuilder let icon: () -> Icon
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: title == nil ? 0 : DUSpacing.sm) {
                Circle()
                    .fill(backgroundColor ?? theme.colors.background.secondary)
                    .frame(width: circleSize, height: circleSize)
                    .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowY)
                    .overlay(icon())

                if let title {
                    Text(title)
                        .font(.du(titleFontSize, weight: .medium))
                        .foregroundColor(titleColor ?? theme.colors.text.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
