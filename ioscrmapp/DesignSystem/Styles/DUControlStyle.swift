import SwiftUI

enum DUControlStyle {
    static let buttonHeight: CGFloat = 52
    static let iconButtonSize: CGFloat = 64
    static let minimumHitSize: CGFloat = 44
}

private struct DUControlShadowModifier: ViewModifier {
    let elevation: DUElevationStyle

    func body(content: Content) -> some View {
        content.shadow(color: elevation.color, radius: elevation.radius, x: elevation.x, y: elevation.y)
    }
}

extension View {
    func duControlShadow(_ elevation: DUElevationStyle = DUElevation.control) -> some View {
        modifier(DUControlShadowModifier(elevation: elevation))
    }
}
