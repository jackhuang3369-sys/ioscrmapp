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
    /// 傍晚/日落时段（用于逐小时 timeline）
    case sunset
    /// 夜间晴（用于逐小时 timeline）
    case night

    var sfSymbol: String { WeatherTheme.theme(for: self).sfSymbol }
    var displayName: String { WeatherTheme.theme(for: self).displayName }
    var eyebrowTitle: String { WeatherTheme.theme(for: self).eyebrowTitle }
    var accentColor: Color { WeatherTheme.theme(for: self).accentColor }
    var glowColors: [Color] { WeatherTheme.theme(for: self).glowColors }
    var heroPanelGradient: [Color] { WeatherTheme.theme(for: self).heroPanelGradient }

    /// 条件对应的主色调（用于 3D 场景背景渐变）
    var skyColors: (top: Color, bottom: Color) { WeatherTheme.theme(for: self).skyColors }

    /// 是否有降水粒子效果
    var hasParticles: Bool { WeatherCondition.particleConditions.contains(self) }
    private static let particleConditions: Set<WeatherCondition> = [.rain, .drizzle, .thunderstorm, .snow]
}

// MARK: - Weather Theme

/// 每种天气状况的所有视觉属性集合，用静态查找表代替多处 switch 展开。
struct WeatherTheme {
    let sfSymbol: String
    let displayName: String
    let eyebrowTitle: String
    let accentColor: Color
    let glowColors: [Color]
    let heroPanelGradient: [Color]
    let skyColors: (top: Color, bottom: Color)

    // MARK: Static lookup

    static func theme(for condition: WeatherCondition) -> WeatherTheme {
        table[condition] ?? table[.clear]!
    }

    // swiftlint:disable closure_body_length
    private static let table: [WeatherCondition: WeatherTheme] = {
        typealias C = Color
        func hex(_ v: UInt32, opacity: Double = 1) -> Color { C(hex: v, opacity: opacity) }

        return [
            .clear: WeatherTheme(
                sfSymbol: "sun.max.fill",
                displayName: "Clear",
                eyebrowTitle: "SUN CLEAR",
                accentColor: hex(0xFFD166),
                glowColors: [hex(0xBAE6FD, opacity: 0.50), hex(0x38BDF8, opacity: 0.18), .clear],
                heroPanelGradient: [C.white.opacity(0.16), hex(0x12233B, opacity: 0.22)],
                skyColors: (hex(0x4FC3F7), hex(0x0277BD))
            ),
            .partlyCloudy: WeatherTheme(
                sfSymbol: "cloud.sun.fill",
                displayName: "Partly Cloudy",
                eyebrowTitle: "SUN + CLOUD",
                accentColor: hex(0xF6C47A),
                glowColors: [hex(0xBAE6FD, opacity: 0.42), hex(0x93C5FD, opacity: 0.18), .clear],
                heroPanelGradient: [C.white.opacity(0.18), hex(0x16314A, opacity: 0.26)],
                skyColors: (hex(0x81D4FA), hex(0x0288D1))
            ),
            .cloudy: WeatherTheme(
                sfSymbol: "cloud.fill",
                displayName: "Cloudy",
                eyebrowTitle: "OVERCAST",
                accentColor: hex(0xD6E0F0),
                glowColors: [hex(0xE2E8F0, opacity: 0.34), hex(0x94A3B8, opacity: 0.16), .clear],
                heroPanelGradient: [C.white.opacity(0.15), hex(0x1F2937, opacity: 0.28)],
                skyColors: (hex(0xB0BEC5), hex(0x546E7A))
            ),
            .drizzle: WeatherTheme(
                sfSymbol: "cloud.drizzle.fill",
                displayName: "Drizzle",
                eyebrowTitle: "LIGHT RAIN",
                accentColor: hex(0x7DD3FC),
                glowColors: [hex(0xBAE6FD, opacity: 0.34), hex(0x38BDF8, opacity: 0.16), .clear],
                heroPanelGradient: [C.white.opacity(0.12), hex(0x0F172A, opacity: 0.32)],
                skyColors: (hex(0x90A4AE), hex(0x455A64))
            ),
            .rain: WeatherTheme(
                sfSymbol: "cloud.rain.fill",
                displayName: "Rain",
                eyebrowTitle: "RAIN FRONT",
                accentColor: hex(0x60A5FA),
                glowColors: [hex(0x93C5FD, opacity: 0.28), hex(0x2563EB, opacity: 0.14), .clear],
                heroPanelGradient: [C.white.opacity(0.12), hex(0x0F172A, opacity: 0.32)],
                skyColors: (hex(0x78909C), hex(0x37474F))
            ),
            .snow: WeatherTheme(
                sfSymbol: "cloud.snow.fill",
                displayName: "Snow",
                eyebrowTitle: "SNOW FALL",
                accentColor: hex(0xF8FAFC),
                glowColors: [hex(0xFFFFFF, opacity: 0.44), hex(0xCBD5E1, opacity: 0.18), .clear],
                heroPanelGradient: [C.white.opacity(0.22), hex(0x1E293B, opacity: 0.24)],
                skyColors: (hex(0xCFD8DC), hex(0x90A4AE))
            ),
            .thunderstorm: WeatherTheme(
                sfSymbol: "cloud.bolt.rain.fill",
                displayName: "Thunderstorm",
                eyebrowTitle: "STORM CELL",
                accentColor: hex(0xFDE68A),
                glowColors: [hex(0xFDE68A, opacity: 0.30), hex(0x1E293B, opacity: 0.16), .clear],
                heroPanelGradient: [C.white.opacity(0.10), hex(0x0B1120, opacity: 0.40)],
                skyColors: (hex(0x546E7A), hex(0x1C313A))
            ),
            .fog: WeatherTheme(
                sfSymbol: "cloud.fog.fill",
                displayName: "Foggy",
                eyebrowTitle: "LOW FOG",
                accentColor: hex(0xE2E8F0),
                glowColors: [hex(0xF8FAFC, opacity: 0.28), hex(0xCBD5E1, opacity: 0.14), .clear],
                heroPanelGradient: [C.white.opacity(0.18), hex(0x334155, opacity: 0.24)],
                skyColors: (hex(0xB0BEC5), hex(0x78909C))
            ),
            .sunset: WeatherTheme(
                sfSymbol: "sunset.fill",
                displayName: "Sunset",
                eyebrowTitle: "GOLDEN HOUR",
                accentColor: hex(0xF28C52),
                glowColors: [hex(0xFDE68A, opacity: 0.40), hex(0xF28C52, opacity: 0.18), .clear],
                heroPanelGradient: [C.white.opacity(0.16), hex(0x7C2D12, opacity: 0.28)],
                skyColors: (hex(0xFB923C), hex(0x7C2D12))
            ),
            .night: WeatherTheme(
                sfSymbol: "moon.stars.fill",
                displayName: "Clear Night",
                eyebrowTitle: "CLEAR NIGHT",
                accentColor: hex(0xC7D2FE),
                glowColors: [hex(0x818CF8, opacity: 0.30), hex(0x1E1B4B, opacity: 0.16), .clear],
                heroPanelGradient: [C.white.opacity(0.10), hex(0x0F0F2D, opacity: 0.40)],
                skyColors: (hex(0x1E1B4B), hex(0x0B0B1A))
            ),
        ]
    }()
    // swiftlint:enable closure_body_length
}
