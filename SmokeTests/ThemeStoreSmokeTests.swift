import Foundation
import SwiftUI

@main
struct ThemeStoreSmokeTests {
    static func main() async throws {
        try await MainActor.run {
            try testDefaultsToSystemWhenMissing()
            try testPersistsLightAndDarkRawValues()
            try testInvalidStoredValueFallsBackToSystem()
        }

        print("Theme store smoke tests passed")
    }

    @MainActor
    private static func testDefaultsToSystemWhenMissing() throws {
        let defaults = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }

        let store = AppThemeStore(defaults: defaults)
        try require(store.currentMode == .system, "missing theme mode should default to system")
    }

    @MainActor
    private static func testPersistsLightAndDarkRawValues() throws {
        let defaults = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }

        let store = AppThemeStore(defaults: defaults)
        store.updateThemeMode(.light)
        try require(store.currentMode == .light, "store should update to light")
        try require(defaults.string(forKey: "app.themeMode") == "light", "store should persist light raw value only")

        store.updateThemeMode(.dark)
        try require(store.currentMode == .dark, "store should update to dark")
        try require(defaults.string(forKey: "app.themeMode") == "dark", "store should persist dark raw value only")
    }

    @MainActor
    private static func testInvalidStoredValueFallsBackToSystem() throws {
        let defaults = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }

        defaults.set("neon", forKey: "app.themeMode")
        let store = AppThemeStore(defaults: defaults)
        try require(store.currentMode == .system, "invalid theme mode should default to system")
        try require(defaults.string(forKey: "app.themeMode") == "neon", "initialization should not rewrite invalid stored values")
    }

    private static func makeDefaults() throws -> UserDefaults {
        let suiteName = "ThemeStoreSmokeTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw SmokeError("could not create UserDefaults suite")
        }
        defaults.set(suiteName, forKey: "_suiteName")
        return defaults
    }

    private static func defaultsSuiteName(_ defaults: UserDefaults) -> String {
        defaults.string(forKey: "_suiteName") ?? ""
    }

    private static func require(_ condition: Bool, _ message: String) throws {
        guard condition else {
            throw SmokeError(message)
        }
    }
}

private struct SmokeError: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        message
    }
}
