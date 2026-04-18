import SwiftUI

struct DUTheme {
    let mode: DUThemeMode
    let resolvedColorScheme: ColorScheme
    let colors: DUThemeColors
    let typography: DUTypographyTokens.Resolved
    let components: DUComponentTokens.Resolved

    static func resolve(mode: DUThemeMode, systemColorScheme: ColorScheme) -> DUTheme {
        let resolvedColorScheme: ColorScheme
        switch mode {
        case .system:
            resolvedColorScheme = systemColorScheme
        case .light:
            resolvedColorScheme = .light
        case .dark:
            resolvedColorScheme = .dark
        }

        let colors = DUColorTokens.resolve(for: resolvedColorScheme)
        return DUTheme(
            mode: mode,
            resolvedColorScheme: resolvedColorScheme,
            colors: colors,
            typography: DUTypographyTokens.standard,
            components: DUComponentTokens.resolve(for: resolvedColorScheme, colors: colors)
        )
    }
}
