import SwiftUI

private struct DUCardModifier: ViewModifier {
    @Environment(\.duTheme) private var theme

    func body(content: Content) -> some View {
        let card = theme.components.card
        content
            .background(card.background)
            .clipShape(RoundedRectangle(cornerRadius: card.cornerRadius, style: .continuous))
            .shadow(color: card.elevation.color, radius: card.elevation.radius, x: card.elevation.x, y: card.elevation.y)
    }
}

extension View {
    func duCardStyle() -> some View {
        modifier(DUCardModifier())
    }
}
