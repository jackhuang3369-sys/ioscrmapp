import SwiftUI

enum DUSurfaceKind {
    case canvas
    case surface
    case raised
    case sheet
}

private struct DUSurfaceModifier: ViewModifier {
    @Environment(\.duTheme) private var theme
    let kind: DUSurfaceKind

    func body(content: Content) -> some View {
        content.background(backgroundColor)
    }

    private var backgroundColor: Color {
        switch kind {
        case .canvas:
            return theme.colors.background.canvas
        case .surface:
            return theme.colors.surface.card
        case .raised:
            return theme.colors.surface.raised
        case .sheet:
            return theme.colors.surface.sheet
        }
    }
}

extension View {
    func duSurfaceStyle(_ kind: DUSurfaceKind = .surface) -> some View {
        modifier(DUSurfaceModifier(kind: kind))
    }
}
