import SwiftUI

extension DUTheme {
    static var cyan: Color { DUColorTokens.Brand.primary.light }
    static var cyanLight: Color { DUColorTokens.Brand.primaryLight.light }
    static var cyanBackground: Color { DUColorTokens.Brand.primaryBackground.light }
    static var blue: Color { DUColorTokens.Brand.secondary.light }
    static var blueLight: Color { DUColorTokens.Brand.secondaryLight.light }
    static var indigo: Color { DUColorTokens.Brand.indigo.light }
    static var magenta: Color { DUColorTokens.Brand.magenta.light }

    static var ink: Color { DUColorTokens.Text.primary.light }
    static var inkSecondary: Color { DUColorTokens.Text.secondary.light }
    static var inkTertiary: Color { DUColorTokens.Text.tertiary.light }
    static var inkDisabled: Color { DUColorTokens.Text.disabled.light }

    static var background: Color { DUColorTokens.Background.canvas.light }
    static var backgroundSecondary: Color { DUColorTokens.Background.secondary.light }
    static var backgroundTertiary: Color { DUColorTokens.Background.tertiary.light }
    static var panel: Color { DUColorTokens.Surface.card.light }
    static var line: Color { DUColorTokens.Border.default.light }
    static var lineLight: Color { DUColorTokens.Border.subtle.light }
    static var homeCarouselIndicatorInactive: Color { DUColorTokens.Indicator.homeCarouselInactive.light }

    static var success: Color { DUColorTokens.Status.success.light }
    static var successBackground: Color { DUColorTokens.Status.successBackground.light }
    static var warning: Color { DUColorTokens.Status.warning.light }
    static var warningBackground: Color { DUColorTokens.Status.warningBackground.light }
    static var error: Color { DUColorTokens.Status.error.light }
    static var errorBackground: Color { DUColorTokens.Status.errorBackground.light }
    static var splashChrome: Color { DUColorTokens.Chrome.splash.light }
    static var splashChromeDisabled: Color { DUColorTokens.Chrome.splashDisabled.light }
    static var splashProgressFill: Color { DUColorTokens.Chrome.splashProgressFill.light }

    static var brandGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [cyan, blue, indigo, magenta]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static var subtleGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [cyanLight, blueLight]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var homeCarouselIndicatorGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [DUColorTokens.Indicator.homeCarouselStart.light, DUColorTokens.Indicator.homeCarouselEnd.light]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static var homeTabBarBackgroundGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(hex: 0x0077FF, opacity: 0.30),
                Color(hex: 0xFFFFFF, opacity: 0)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
