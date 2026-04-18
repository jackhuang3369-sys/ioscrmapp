import Foundation
import SwiftUI

@MainActor
final class AppThemeStore: ObservableObject {
    @Published private(set) var currentMode: DUThemeMode

    private let defaults: UserDefaults
    private let themeKey = "app.themeMode"

    init(defaults: UserDefaults = .standard, initialMode: DUThemeMode? = nil) {
        self.defaults = defaults

        if let initialMode {
            currentMode = initialMode
            return
        }

        let storedMode = defaults.string(forKey: themeKey)
            .flatMap(DUThemeMode.init(rawValue:))
        currentMode = storedMode ?? .system
    }

    func updateThemeMode(_ mode: DUThemeMode) {
        guard currentMode != mode else {
            return
        }

        currentMode = mode
        defaults.set(mode.rawValue, forKey: themeKey)
    }
}
