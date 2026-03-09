import SwiftUI

enum DUTheme {
    static let cyan = Color(hex: 0x00B3D6)
    static let cyanLight = Color(hex: 0x4DCFE8)
    static let cyanBackground = Color(red: 0, green: 179 / 255, blue: 214 / 255, opacity: 0.08)
    static let blue = Color(hex: 0x2A6FD8)
    static let blueLight = Color(hex: 0x5B9AF0)
    static let indigo = Color(hex: 0x4A58C6)
    static let magenta = Color(hex: 0xD13AC5)

    static let ink = Color(hex: 0x1F2D3D)
    static let inkSecondary = Color(hex: 0x4A5568)
    static let inkTertiary = Color(hex: 0x718096)
    static let inkDisabled = Color(hex: 0xA0AEC0)

    static let background = Color(hex: 0xF2F5F8)
    static let backgroundSecondary = Color(hex: 0xE8EDF2)
    static let backgroundTertiary = Color(hex: 0xDFE5EB)
    static let panel = Color.white
    static let line = Color(hex: 0xDBE5EF)
    static let lineLight = Color(hex: 0xE8EEF4)

    static let success = Color(hex: 0x1F8A52)
    static let successBackground = Color(hex: 0xE8F5E9)
    static let warning = Color(hex: 0xF5A623)
    static let warningBackground = Color(hex: 0xFFF8E1)
    static let error = Color(hex: 0xD32F2F)
    static let errorBackground = Color(hex: 0xFFEBEE)

    static let brandGradient = LinearGradient(
        gradient: Gradient(colors: [cyan, blue, indigo, magenta]),
        startPoint: .leading,
        endPoint: .trailing
    )

    static let subtleGradient = LinearGradient(
        gradient: Gradient(colors: [cyanLight, blueLight]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

enum DUSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let red = Double((hex & 0xFF0000) >> 16) / 255
        let green = Double((hex & 0x00FF00) >> 8) / 255
        let blue = Double(hex & 0x0000FF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}

private struct DUCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(DUTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.06), radius: 16, x: 0, y: 8)
    }
}

extension View {
    func duCardStyle() -> some View {
        modifier(DUCardModifier())
    }
}
