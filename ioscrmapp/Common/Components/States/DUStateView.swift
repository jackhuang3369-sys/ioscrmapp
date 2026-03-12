import SwiftUI

struct DUStateView: View {
    let systemImage: String
    let iconColor: Color
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var actionStyle: DUButtonStyle = .primary
    var actionHeight: CGFloat = 46
    var actionFontSize: CGFloat = 15
    var footer: AnyView? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: DUSpacing.lg) {
            Image(systemName: systemImage)
                .font(.du(42, weight: .bold))
                .foregroundColor(iconColor)

            Text(title)
                .font(.du(22, weight: .bold))
                .foregroundColor(DUTheme.ink)

            Text(subtitle)
                .font(.du(15, weight: .medium))
                .foregroundColor(DUTheme.inkSecondary)
                .multilineTextAlignment(.center)

            if let actionTitle, let action {
                DUButton(
                    title: actionTitle,
                    style: actionStyle,
                    height: actionHeight,
                    fontSize: actionFontSize,
                    horizontalPadding: DUSpacing.xxl,
                    action: action
                )
            }

            if let footer {
                footer
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, DUSpacing.xxl)
    }
}
