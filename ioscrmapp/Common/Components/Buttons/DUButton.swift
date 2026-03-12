import SwiftUI

enum DUButtonStyle {
    case primary
    case secondary
    case danger
}

struct DUButton: View {
    let title: String
    let style: DUButtonStyle
    var isLoading = false
    var isEnabled = true
    var height: CGFloat = 52
    var fixedWidth: CGFloat? = nil
    var cornerRadius: CGFloat = 18
    var fontSize: CGFloat = 16
    var horizontalPadding: CGFloat = 0
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DUSpacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(foregroundColor)
                }

                Text(title)
                    .font(.du(fontSize, weight: .bold))
            }
            .foregroundColor(foregroundColor)
            .frame(maxWidth: fixedWidth == nil ? .infinity : nil)
            .frame(width: fixedWidth, height: height)
            .padding(.horizontal, horizontalPadding)
            .background(backgroundView)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(
                color: style == .primary && isEnabled ? DUTheme.cyan.opacity(0.28) : .clear,
                radius: 18,
                x: 0,
                y: 8
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private var foregroundColor: Color {
        switch style {
        case .primary, .danger:
            return .white
        case .secondary:
            return isEnabled ? DUTheme.cyan : DUTheme.inkDisabled
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        switch style {
        case .primary:
            if isEnabled {
                shape.fill(DUTheme.brandGradient)
            } else {
                shape.fill(DUTheme.inkDisabled)
            }
        case .secondary:
            if isEnabled {
                shape.fill(DUTheme.cyanBackground)
            } else {
                shape.fill(DUTheme.backgroundSecondary)
            }
        case .danger:
            shape.fill(DUTheme.error)
        }
    }
}
