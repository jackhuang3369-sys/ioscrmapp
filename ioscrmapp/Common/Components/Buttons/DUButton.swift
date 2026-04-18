import SwiftUI

enum DUButtonStyle {
    case primary
    case secondary
    case danger
}

struct DUButton: View {
    @Environment(\.duTheme) private var theme

    let title: String
    let style: DUButtonStyle
    var isLoading = false
    var isEnabled = true
    var height: CGFloat = 52
    var fixedWidth: CGFloat? = nil
    var cornerRadius: CGFloat = DURadius.button
    var fontSize: CGFloat = 16
    var textStyle: DUTextStyle? = nil
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
                    .font(buttonFont)
            }
            .foregroundColor(foregroundColor)
            .frame(maxWidth: fixedWidth == nil ? .infinity : nil)
            .frame(width: fixedWidth, height: height)
            .padding(.horizontal, horizontalPadding)
            .background(backgroundView)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(
                color: style == .primary && isEnabled ? buttonTokens.shadowColor : .clear,
                radius: DUElevation.primaryButton.radius,
                x: DUElevation.primaryButton.x,
                y: DUElevation.primaryButton.y
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private var buttonFont: Font {
        if let textStyle {
            return .du(textStyle)
        }

        return .du(fontSize, weight: .bold)
    }

    private var foregroundColor: Color {
        isEnabled ? buttonTokens.foreground : buttonTokens.disabledForeground
    }

    private var buttonTokens: DUComponentTokens.ButtonVariantTokens {
        switch style {
        case .primary:
            return theme.components.button.primary
        case .secondary:
            return theme.components.button.secondary
        case .danger:
            return theme.components.button.danger
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        switch style {
        case .primary:
            if isEnabled {
                shape.fill(theme.colors.gradient.brand)
            } else {
                shape.fill(buttonTokens.disabledBackground)
            }
        case .secondary:
            if isEnabled {
                shape.fill(buttonTokens.background)
            } else {
                shape.fill(buttonTokens.disabledBackground)
            }
        case .danger:
            shape.fill(isEnabled ? buttonTokens.background : buttonTokens.disabledBackground)
        }
    }
}
