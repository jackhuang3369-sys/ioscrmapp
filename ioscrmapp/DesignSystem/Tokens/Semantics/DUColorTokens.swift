import SwiftUI

struct DUColorToken {
    let light: Color
    let dark: Color

    func resolve(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .dark:
            return dark
        case .light:
            fallthrough
        @unknown default:
            return light
        }
    }
}

struct DUThemeColors {
    let brand: DUBrandColors
    let text: DUTextColors
    let background: DUBackgroundColors
    let surface: DUSurfaceColors
    let border: DUBorderColors
    let status: DUStatusColors
    let action: DUActionColors
    let chrome: DUChromeColors
    let indicator: DUIndicatorColors
    let gradient: DUGradientColors
}

struct DUBrandColors {
    let primary: Color
    let primaryLight: Color
    let primaryBackground: Color
    let secondary: Color
    let secondaryLight: Color
    let indigo: Color
    let magenta: Color
}

struct DUTextColors {
    let primary: Color
    let secondary: Color
    let tertiary: Color
    let disabled: Color
    let inverse: Color
}

struct DUBackgroundColors {
    let canvas: Color
    let secondary: Color
    let tertiary: Color
}

struct DUSurfaceColors {
    let card: Color
    let raised: Color
    let sheet: Color
}

struct DUBorderColors {
    let `default`: Color
    let subtle: Color
}

struct DUStatusColors {
    let success: Color
    let successBackground: Color
    let warning: Color
    let warningBackground: Color
    let error: Color
    let errorBackground: Color
}

struct DUActionColors {
    let primary: Color
    let primaryBackground: Color
    let disabled: Color
}

struct DUChromeColors {
    let splash: Color
    let splashDisabled: Color
    let splashProgressFill: Color
}

struct DUIndicatorColors {
    let homeCarouselInactive: Color
    let homeCarouselStart: Color
    let homeCarouselEnd: Color
}

struct DUGradientColors {
    let brand: LinearGradient
    let subtle: LinearGradient
    let homeCarouselIndicator: LinearGradient
    let homeTabBarBackground: LinearGradient
}

enum DUColorTokens {
    enum Brand {
        static let primary = DUColorToken(light: DUColorPrimitives.Brand.cyan, dark: DUColorPrimitives.Brand.cyanLight)
        static let primaryLight = DUColorToken(light: DUColorPrimitives.Brand.cyanLight, dark: Color(hex: 0x7CE4F2))
        static let primaryBackground = DUColorToken(
            light: Color(hex: 0x00B3D6, opacity: 0.08),
            dark: Color(hex: 0x00B3D6, opacity: 0.20)
        )
        static let secondary = DUColorToken(light: DUColorPrimitives.Brand.blue, dark: DUColorPrimitives.Brand.blueLight)
        static let secondaryLight = DUColorToken(light: DUColorPrimitives.Brand.blueLight, dark: Color(hex: 0x8DBBFA))
        static let indigo = DUColorToken(light: DUColorPrimitives.Brand.indigo, dark: Color(hex: 0x8790F0))
        static let magenta = DUColorToken(light: DUColorPrimitives.Brand.magenta, dark: Color(hex: 0xF275E8))
    }

    enum Text {
        static let primary = DUColorToken(light: DUColorPrimitives.Neutral.gray800, dark: DUColorPrimitives.Neutral.gray50)
        static let secondary = DUColorToken(light: DUColorPrimitives.Neutral.gray600, dark: DUColorPrimitives.Neutral.gray350)
        static let tertiary = DUColorToken(light: DUColorPrimitives.Neutral.gray500, dark: DUColorPrimitives.Neutral.gray400)
        static let disabled = DUColorToken(light: DUColorPrimitives.Neutral.gray400, dark: DUColorPrimitives.Neutral.gray600)
        static let inverse = DUColorToken(light: DUColorPrimitives.Neutral.white, dark: DUColorPrimitives.Neutral.gray900)
    }

    enum Background {
        static let canvas = DUColorToken(light: DUColorPrimitives.Neutral.gray100, dark: DUColorPrimitives.Neutral.gray900)
        static let secondary = DUColorToken(light: DUColorPrimitives.Neutral.gray150, dark: DUColorPrimitives.Neutral.gray850)
        static let tertiary = DUColorToken(light: DUColorPrimitives.Neutral.gray200, dark: DUColorPrimitives.Neutral.gray800)
    }

    enum Surface {
        static let card = DUColorToken(light: DUColorPrimitives.Neutral.white, dark: Color(hex: 0x172033))
        static let raised = DUColorToken(light: DUColorPrimitives.Neutral.white, dark: Color(hex: 0x1F2A44))
        static let sheet = DUColorToken(light: DUColorPrimitives.Neutral.white, dark: DUColorPrimitives.Neutral.gray850)
    }

    enum Border {
        static let `default` = DUColorToken(light: DUColorPrimitives.Neutral.gray250, dark: Color(hex: 0x334155))
        static let subtle = DUColorToken(light: Color(hex: 0xE8EEF4), dark: Color(hex: 0x26364D))
    }

    enum Status {
        static let success = DUColorToken(light: DUColorPrimitives.Status.success, dark: Color(hex: 0x4ADE80))
        static let successBackground = DUColorToken(light: DUColorPrimitives.Status.successBackground, dark: Color(hex: 0x123A25))
        static let warning = DUColorToken(light: DUColorPrimitives.Status.warning, dark: Color(hex: 0xFACC15))
        static let warningBackground = DUColorToken(light: DUColorPrimitives.Status.warningBackground, dark: Color(hex: 0x3D2F08))
        static let error = DUColorToken(light: DUColorPrimitives.Status.error, dark: Color(hex: 0xF87171))
        static let errorBackground = DUColorToken(light: DUColorPrimitives.Status.errorBackground, dark: Color(hex: 0x431818))
    }

    enum Action {
        static let primary = Brand.primary
        static let primaryBackground = Brand.primaryBackground
        static let disabled = Text.disabled
    }

    enum Chrome {
        static let splash = DUColorToken(light: DUColorPrimitives.Chrome.splash, dark: DUColorPrimitives.Chrome.splash)
        static let splashDisabled = DUColorToken(light: DUColorPrimitives.Chrome.splashDisabled, dark: DUColorPrimitives.Chrome.splashDisabled)
        static let splashProgressFill = DUColorToken(
            light: DUColorPrimitives.Chrome.splashProgressFill,
            dark: DUColorPrimitives.Chrome.splashProgressFill
        )
    }

    enum Indicator {
        static let homeCarouselInactive = DUColorToken(
            light: DUColorPrimitives.Indicator.homeCarouselInactive,
            dark: Color(hex: 0x475569)
        )
        static let homeCarouselStart = DUColorToken(
            light: DUColorPrimitives.Indicator.homeCarouselStart,
            dark: Color(hex: 0x38BDF8)
        )
        static let homeCarouselEnd = DUColorToken(
            light: DUColorPrimitives.Indicator.homeCarouselEnd,
            dark: Color(hex: 0x60A5FA)
        )
    }

    static func resolve(for colorScheme: ColorScheme) -> DUThemeColors {
        let brand = DUBrandColors(
            primary: Brand.primary.resolve(for: colorScheme),
            primaryLight: Brand.primaryLight.resolve(for: colorScheme),
            primaryBackground: Brand.primaryBackground.resolve(for: colorScheme),
            secondary: Brand.secondary.resolve(for: colorScheme),
            secondaryLight: Brand.secondaryLight.resolve(for: colorScheme),
            indigo: Brand.indigo.resolve(for: colorScheme),
            magenta: Brand.magenta.resolve(for: colorScheme)
        )
        let indicator = DUIndicatorColors(
            homeCarouselInactive: Indicator.homeCarouselInactive.resolve(for: colorScheme),
            homeCarouselStart: Indicator.homeCarouselStart.resolve(for: colorScheme),
            homeCarouselEnd: Indicator.homeCarouselEnd.resolve(for: colorScheme)
        )

        return DUThemeColors(
            brand: brand,
            text: DUTextColors(
                primary: Text.primary.resolve(for: colorScheme),
                secondary: Text.secondary.resolve(for: colorScheme),
                tertiary: Text.tertiary.resolve(for: colorScheme),
                disabled: Text.disabled.resolve(for: colorScheme),
                inverse: Text.inverse.resolve(for: colorScheme)
            ),
            background: DUBackgroundColors(
                canvas: Background.canvas.resolve(for: colorScheme),
                secondary: Background.secondary.resolve(for: colorScheme),
                tertiary: Background.tertiary.resolve(for: colorScheme)
            ),
            surface: DUSurfaceColors(
                card: Surface.card.resolve(for: colorScheme),
                raised: Surface.raised.resolve(for: colorScheme),
                sheet: Surface.sheet.resolve(for: colorScheme)
            ),
            border: DUBorderColors(
                default: Border.default.resolve(for: colorScheme),
                subtle: Border.subtle.resolve(for: colorScheme)
            ),
            status: DUStatusColors(
                success: Status.success.resolve(for: colorScheme),
                successBackground: Status.successBackground.resolve(for: colorScheme),
                warning: Status.warning.resolve(for: colorScheme),
                warningBackground: Status.warningBackground.resolve(for: colorScheme),
                error: Status.error.resolve(for: colorScheme),
                errorBackground: Status.errorBackground.resolve(for: colorScheme)
            ),
            action: DUActionColors(
                primary: Action.primary.resolve(for: colorScheme),
                primaryBackground: Action.primaryBackground.resolve(for: colorScheme),
                disabled: Action.disabled.resolve(for: colorScheme)
            ),
            chrome: DUChromeColors(
                splash: Chrome.splash.resolve(for: colorScheme),
                splashDisabled: Chrome.splashDisabled.resolve(for: colorScheme),
                splashProgressFill: Chrome.splashProgressFill.resolve(for: colorScheme)
            ),
            indicator: indicator,
            gradient: DUGradientColors(
                brand: LinearGradient(
                    gradient: Gradient(colors: [brand.primary, brand.secondary, brand.indigo, brand.magenta]),
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                subtle: LinearGradient(
                    gradient: Gradient(colors: [brand.primaryLight, brand.secondaryLight]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                homeCarouselIndicator: LinearGradient(
                    gradient: Gradient(colors: [indicator.homeCarouselStart, indicator.homeCarouselEnd]),
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                homeTabBarBackground: LinearGradient(
                    gradient: Gradient(colors: [Brand.secondary.resolve(for: colorScheme).opacity(0.30), Color(hex: 0xFFFFFF, opacity: 0)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        )
    }
}
