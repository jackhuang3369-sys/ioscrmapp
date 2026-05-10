import SwiftUI

struct DUBrandMark: View {
    @Environment(\.duTheme) private var theme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: theme.components.sheet.cornerRadius, style: .continuous)
                .fill(theme.colors.gradient.brand)
                .frame(width: 88, height: 88)
                .shadow(
                    color: theme.components.button.primary.shadowColor,
                    radius: theme.components.card.elevation.radius,
                    x: theme.components.card.elevation.x,
                    y: theme.components.card.elevation.y
                )
            Text("du")
                .font(.du(.screenTitle))
                .foregroundColor(DUColorPrimitives.Neutral.white)
        }
        .padding(.top, DUSpacing.sm)
    }
}
