import SwiftUI

private struct DUThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue = DUTheme.resolve(mode: .system, systemColorScheme: .light)
}

private struct DUThemeModeEnvironmentKey: EnvironmentKey {
    static let defaultValue: DUThemeMode = .system
}

extension EnvironmentValues {
    var duTheme: DUTheme {
        get { self[DUThemeEnvironmentKey.self] }
        set { self[DUThemeEnvironmentKey.self] = newValue }
    }

    var duThemeMode: DUThemeMode {
        get { self[DUThemeModeEnvironmentKey.self] }
        set { self[DUThemeModeEnvironmentKey.self] = newValue }
    }
}

private struct DUThemeEnvironmentModifier: ViewModifier {
    let mode: DUThemeMode
    @Environment(\.colorScheme) private var systemColorScheme

    func body(content: Content) -> some View {
        content
            .environment(\.duThemeMode, mode)
            .environment(\.duTheme, DUTheme.resolve(mode: mode, systemColorScheme: systemColorScheme))
    }
}

extension View {
    func duTheme(mode: DUThemeMode) -> some View {
        modifier(DUThemeEnvironmentModifier(mode: mode))
    }
}
