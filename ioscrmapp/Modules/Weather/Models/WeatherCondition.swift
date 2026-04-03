import SwiftUI

// MARK: - Weather Condition

enum WeatherCondition: String, CaseIterable {
    case clear
    case partlyCloudy
    case cloudy
    case drizzle
    case rain
    case snow
    case thunderstorm
    case fog

    var sfSymbol: String {
        switch self {
        case .clear:        return "sun.max.fill"
        case .partlyCloudy: return "cloud.sun.fill"
        case .cloudy:       return "cloud.fill"
        case .drizzle:      return "cloud.drizzle.fill"
        case .rain:         return "cloud.rain.fill"
        case .snow:         return "cloud.snow.fill"
        case .thunderstorm: return "cloud.bolt.rain.fill"
        case .fog:          return "cloud.fog.fill"
        }
    }

    var displayName: String {
        switch self {
        case .clear:        return "Clear"
        case .partlyCloudy: return "Partly Cloudy"
        case .cloudy:       return "Cloudy"
        case .drizzle:      return "Drizzle"
        case .rain:         return "Rain"
        case .snow:         return "Snow"
        case .thunderstorm: return "Thunderstorm"
        case .fog:          return "Foggy"
        }
    }

    var eyebrowTitle: String {
        switch self {
        case .clear:        return "SUN CLEAR"
        case .partlyCloudy: return "SUN + CLOUD"
        case .cloudy:       return "OVERCAST"
        case .drizzle:      return "LIGHT RAIN"
        case .rain:         return "RAIN FRONT"
        case .snow:         return "SNOW FALL"
        case .thunderstorm: return "STORM CELL"
        case .fog:          return "LOW FOG"
        }
    }

    var accentColor: Color {
        switch self {
        case .clear:        return Color(hex: 0xFFD166)
        case .partlyCloudy: return Color(hex: 0xF6C47A)
        case .cloudy:       return Color(hex: 0xD6E0F0)
        case .drizzle:      return Color(hex: 0x7DD3FC)
        case .rain:         return Color(hex: 0x60A5FA)
        case .snow:         return Color(hex: 0xF8FAFC)
        case .thunderstorm: return Color(hex: 0xFDE68A)
        case .fog:          return Color(hex: 0xE2E8F0)
        }
    }

    var glowColors: [Color] {
        switch self {
        case .clear:
            return [Color(hex: 0xBAE6FD, opacity: 0.50), Color(hex: 0x38BDF8, opacity: 0.18), .clear]
        case .partlyCloudy:
            return [Color(hex: 0xBAE6FD, opacity: 0.42), Color(hex: 0x93C5FD, opacity: 0.18), .clear]
        case .cloudy:
            return [Color(hex: 0xE2E8F0, opacity: 0.34), Color(hex: 0x94A3B8, opacity: 0.16), .clear]
        case .drizzle:
            return [Color(hex: 0xBAE6FD, opacity: 0.34), Color(hex: 0x38BDF8, opacity: 0.16), .clear]
        case .rain:
            return [Color(hex: 0x93C5FD, opacity: 0.28), Color(hex: 0x2563EB, opacity: 0.14), .clear]
        case .snow:
            return [Color(hex: 0xFFFFFF, opacity: 0.44), Color(hex: 0xCBD5E1, opacity: 0.18), .clear]
        case .thunderstorm:
            return [Color(hex: 0xFDE68A, opacity: 0.30), Color(hex: 0x1E293B, opacity: 0.16), .clear]
        case .fog:
            return [Color(hex: 0xF8FAFC, opacity: 0.28), Color(hex: 0xCBD5E1, opacity: 0.14), .clear]
        }
    }

    var heroPanelGradient: [Color] {
        switch self {
        case .clear:
            return [Color.white.opacity(0.16), Color(hex: 0x12233B, opacity: 0.22)]
        case .partlyCloudy:
            return [Color.white.opacity(0.18), Color(hex: 0x16314A, opacity: 0.26)]
        case .cloudy:
            return [Color.white.opacity(0.15), Color(hex: 0x1F2937, opacity: 0.28)]
        case .drizzle, .rain:
            return [Color.white.opacity(0.12), Color(hex: 0x0F172A, opacity: 0.32)]
        case .snow:
            return [Color.white.opacity(0.22), Color(hex: 0x1E293B, opacity: 0.24)]
        case .thunderstorm:
            return [Color.white.opacity(0.10), Color(hex: 0x0B1120, opacity: 0.40)]
        case .fog:
            return [Color.white.opacity(0.18), Color(hex: 0x334155, opacity: 0.24)]
        }
    }

    /// 条件对应的主色调（用于 3D 场景背景渐变）
    var skyColors: (top: Color, bottom: Color) {
        switch self {
        case .clear:
            return (Color(hex: 0x4FC3F7), Color(hex: 0x0277BD))
        case .partlyCloudy:
            return (Color(hex: 0x81D4FA), Color(hex: 0x0288D1))
        case .cloudy:
            return (Color(hex: 0xB0BEC5), Color(hex: 0x546E7A))
        case .drizzle:
            return (Color(hex: 0x90A4AE), Color(hex: 0x455A64))
        case .rain:
            return (Color(hex: 0x78909C), Color(hex: 0x37474F))
        case .snow:
            return (Color(hex: 0xCFD8DC), Color(hex: 0x90A4AE))
        case .thunderstorm:
            return (Color(hex: 0x546E7A), Color(hex: 0x1C313A))
        case .fog:
            return (Color(hex: 0xB0BEC5), Color(hex: 0x78909C))
        }
    }

    /// 是否有降水粒子效果
    var hasParticles: Bool {
        switch self {
        case .rain, .drizzle, .thunderstorm, .snow: return true
        default: return false
        }
    }
}
