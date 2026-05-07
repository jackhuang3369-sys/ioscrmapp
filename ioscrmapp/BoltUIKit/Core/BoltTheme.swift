import SwiftUI

// MARK: - BoltUI Theme v2
/// 旅行场景深度设计令牌
/// 暖色调体系 + 玻璃态 + 多层深度

struct BoltTheme {

    // MARK: ── 品牌色 ────────────────────────────────────────────────
    static let gold        = Color(hex: 0xD4A853)   // 主暖金色
    static let amber       = Color(hex: 0xF5A623)   // 琥珀色
    static let sunset      = Color(hex: 0xFF6B4A)   // 落日渐变终点
    static let rose        = Color(hex: 0xE8735A)   // 玫瑰暖色
    static let oceanDeep   = Color(hex: 0x1B4F72)   // 深海蓝
    static let skyBlue     = Color(hex: 0x5DADE2)   // 天空蓝
    static let forest      = Color(hex: 0x229954)   // 森林绿
    static let lavender    = Color(hex: 0xA569BD)   // 薰衣草紫

    // 渐变预设
    static let gradientGold  = [Color(hex: 0xF9D56E), Color(hex: 0xF5A623), Color(hex: 0xE8735A)]
    static let gradientOcean = [Color(hex: 0x1B4F72), Color(hex: 0x2E86C1), Color(hex: 0x5DADE2)]
    static let gradientDusk  = [Color(hex: 0x2C3E50), Color(hex: 0x4A235A), Color(hex: 0x8E44AD)]
    static let gradientWarm  = [Color(hex: 0xFF6B4A), Color(hex: 0xF5A623), Color(hex: 0xD4A853)]

    // MARK: ── 背景层级 ────────────────────────────────────────────
    static let surfaceBase     = Color.white.opacity(0.04)
    static let surfaceRaised   = Color.white.opacity(0.06)
    static let surfaceGlass    = Color.white.opacity(0.08)
    static let surfaceGlassHover = Color.white.opacity(0.14)
    static let surfaceGlow     = Color.white.opacity(0.10)

    // MARK: ── 文字层级 ────────────────────────────────────────────
    static let textPrimary     = Color.white.opacity(0.95)
    static let textSecondary   = Color.white.opacity(0.65)
    static let textTertiary    = Color.white.opacity(0.40)
    static let textInverse     = Color.black.opacity(0.85)

    // MARK: ── 边框 ────────────────────────────────────────────────
    static let borderSubtle    = Color.white.opacity(0.10)
    static let borderMedium    = Color.white.opacity(0.18)
    static let borderAccent    = Color.white.opacity(0.28)

    // MARK: ── 间距 ────────────────────────────────────────────────
    static let spacing3xs: CGFloat = 2
    static let spacing2xs: CGFloat = 4
    static let spacingXs:  CGFloat = 8
    static let spacingSm:  CGFloat = 12
    static let spacingMd:  CGFloat = 16
    static let spacingLg:  CGFloat = 24
    static let spacingXl:  CGFloat = 32
    static let spacing2xl: CGFloat = 48
    static let spacing3xl: CGFloat = 64

    // MARK: ── 圆角 ────────────────────────────────────────────────
    static let radiusSm:  CGFloat = 8
    static let radiusMd:  CGFloat = 14
    static let radiusLg:  CGFloat = 20
    static let radiusXl:  CGFloat = 28
    static let radiusFull: CGFloat = 9999

    // MARK: ── 阴影系统（多层）─────────────────────────────────────
    static let shadowNear   = Color.black.opacity(0.20)
    static let shadowMid    = Color.black.opacity(0.12)
    static let shadowFar    = Color.black.opacity(0.06)

    // MARK: ── 动画 ────────────────────────────────────────────────
    static let durationFast:   Double = 0.18
    static let durationNormal: Double = 0.30
    static let durationSlow:   Double = 0.50
    static let springEase = Animation.spring(response: 0.40, dampingFraction: 0.72)
    static let springBounce = Animation.spring(response: 0.45, dampingFraction: 0.60)

    // MARK: ── 排版 ────────────────────────────────────────────────
    static func displayFont(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
    static func headingFont(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
    static func bodyFont(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }
    static func captionFont(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }
}
