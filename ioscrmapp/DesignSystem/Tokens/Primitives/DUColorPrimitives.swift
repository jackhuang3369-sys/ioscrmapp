import SwiftUI

enum DUColorPrimitives {
    enum Brand {
        static let cyan = Color(hex: 0x00B3D6)
        static let cyanLight = Color(hex: 0x4DCFE8)
        static let blue = Color(hex: 0x2A6FD8)
        static let blueLight = Color(hex: 0x5B9AF0)
        static let indigo = Color(hex: 0x4A58C6)
        static let magenta = Color(hex: 0xD13AC5)
    }

    enum Neutral {
        static let white = Color.white
        static let black = Color.black
        static let gray50 = Color(hex: 0xF8FAFC)
        static let gray100 = Color(hex: 0xF2F5F8)
        static let gray150 = Color(hex: 0xE8EDF2)
        static let gray200 = Color(hex: 0xDFE5EB)
        static let gray250 = Color(hex: 0xDBE5EF)
        static let gray300 = Color(hex: 0xD6DEE8)
        static let gray350 = Color(hex: 0xCBD5E1)
        static let gray400 = Color(hex: 0xA0AEC0)
        static let gray500 = Color(hex: 0x718096)
        static let gray600 = Color(hex: 0x4A5568)
        static let gray700 = Color(hex: 0x334155)
        static let gray800 = Color(hex: 0x1F2D3D)
        static let gray850 = Color(hex: 0x172033)
        static let gray900 = Color(hex: 0x0F172A)
    }

    enum Status {
        static let success = Color(hex: 0x1F8A52)
        static let successBackground = Color(hex: 0xE8F5E9)
        static let warning = Color(hex: 0xF5A623)
        static let warningBackground = Color(hex: 0xFFF8E1)
        static let error = Color(hex: 0xD32F2F)
        static let errorBackground = Color(hex: 0xFFEBEE)
    }

    enum Chrome {
        static let splash = Color.black.opacity(0.52)
        static let splashDisabled = Color.black.opacity(0.32)
        static let splashProgressFill = Color(hex: 0xF7B733, opacity: 0.96)
        static let transparent = Color(hex: 0xFFFFFF, opacity: 0)
    }

    enum Indicator {
        static let homeCarouselStart = Color(hex: 0x009FFF)
        static let homeCarouselEnd = Color(hex: 0x0066FF)
        static let homeCarouselInactive = Color(hex: 0xD6DEE8)
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let red = Double((hex & 0xFF0000) >> 16) / 255
        let green = Double((hex & 0x00FF00) >> 8) / 255
        let blue = Double(hex & 0x0000FF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}
