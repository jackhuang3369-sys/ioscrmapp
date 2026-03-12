import SwiftUI

struct DUIconButton<Icon: View>: View {
    let title: String?
    var circleSize: CGFloat = 64
    var backgroundColor: Color = DUTheme.backgroundSecondary
    var titleColor: Color = DUTheme.inkTertiary
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
                    .fill(backgroundColor)
                    .frame(width: circleSize, height: circleSize)
                    .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowY)
                    .overlay(icon())

                if let title {
                    Text(title)
                        .font(.du(titleFontSize, weight: .medium))
                        .foregroundColor(titleColor)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
