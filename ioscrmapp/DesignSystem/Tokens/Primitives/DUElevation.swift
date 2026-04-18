import SwiftUI

struct DUElevationStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    func withColor(_ color: Color) -> DUElevationStyle {
        DUElevationStyle(color: color, radius: radius, x: x, y: y)
    }
}

enum DUElevation {
    static let none = DUElevationStyle(color: .clear, radius: 0, x: 0, y: 0)
    static let control = DUElevationStyle(color: Color.black.opacity(0.10), radius: 12, x: 0, y: 6)
    static let lifted = DUElevationStyle(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 8)
    static let hero = DUElevationStyle(color: Color.black.opacity(0.14), radius: 15, x: 0, y: 10)
    static let spotlight = DUElevationStyle(color: Color.black.opacity(0.16), radius: 18, x: 0, y: 10)
    static let showcase = DUElevationStyle(color: Color.black.opacity(0.18), radius: 20, x: 0, y: 10)
    static let primaryButton = DUElevationStyle(color: Color.black.opacity(0.14), radius: 18, x: 0, y: 8)

    static func card(for colorScheme: ColorScheme) -> DUElevationStyle {
        switch colorScheme {
        case .dark:
            return DUElevationStyle(color: Color.black.opacity(0.28), radius: 18, x: 0, y: 10)
        case .light:
            fallthrough
        @unknown default:
            return DUElevationStyle(color: Color.black.opacity(0.06), radius: 16, x: 0, y: 8)
        }
    }
}
