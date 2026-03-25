import Foundation

/// Centralized environment and service configuration for packaging and runtime overrides.
/// Update this file when changing supported environments, service modes, or default base URLs.
enum AppEnvironment: String {
    case develop
    case test
    case production

    static let current = Catalog.resolvedEnvironment()
}

enum AppServiceMode: String {
    case mock
    case remote
}

struct AppServiceConfiguration {
    let mode: AppServiceMode
    let serverURL: URL

    func withOverridesFromEnvironment() -> AppServiceConfiguration {
        AppServiceConfiguration(
            mode: Catalog.resolvedServiceMode(fallback: mode),
            serverURL: Catalog.resolvedServerURL(fallback: serverURL)
        )
    }
}

struct AppConfig {
    let environment: AppEnvironment
    let serviceConfiguration: AppServiceConfiguration

    static let current = Catalog.loadCurrentConfig()
    static let preview = AppConfig(
        environment: .develop,
        serviceConfiguration: AppServiceConfiguration(
            mode: .mock,
            serverURL: Catalog.configuration(for: .develop).serverURL
        )
    )

    init(environment: AppEnvironment) {
        self.environment = environment
        self.serviceConfiguration = Catalog.configuration(for: environment).withOverridesFromEnvironment()
    }

    init(environment: AppEnvironment, serviceConfiguration: AppServiceConfiguration) {
        self.environment = environment
        self.serviceConfiguration = serviceConfiguration
    }
}

private enum Catalog {
    enum Keys {
        static let environment = "IOSCRMAPP_ENVIRONMENT"
        static let serviceMode = "IOSCRMAPP_SERVICE_MODE"
        static let serverURL = "IOSCRMAPP_SERVER_URL"
    }

    private static let defaultMode: AppServiceMode = .mock

    private static let environmentURLs: [AppEnvironment: URL] = [
        .develop: URL(string: "http://10.72.61.85:9000")!,
//        .develop: URL(string: "http://192.168.137.1:9000")!,
        .test: URL(string: "https://staging-api.example.com")!,
        .production: URL(string: "https://api.example.com")!,
    ]

    private static let environmentModes: [AppEnvironment: AppServiceMode] = [
        .develop: .remote,
        .test: .remote,
        .production: .remote,
    ]

    private static let configurations: [AppEnvironment: AppServiceConfiguration] = [
        .develop: AppServiceConfiguration(
            mode: environmentModes[.develop]!,
            serverURL: environmentURLs[.develop]!
        ),
        .test: AppServiceConfiguration(
            mode: environmentModes[.test]!,
            serverURL: environmentURLs[.test]!
        ),
        .production: AppServiceConfiguration(
            mode: environmentModes[.production]!,
            serverURL: environmentURLs[.production]!
        ),
    ]

    static func loadCurrentConfig() -> AppConfig {
        let environment = resolvedEnvironment()
        return makeConfig(environment: environment)
    }

    static func makeConfig(environment: AppEnvironment) -> AppConfig {
        AppConfig(environment: environment)
    }

    static func configuration(for environment: AppEnvironment) -> AppServiceConfiguration {
        configurations[environment]!
    }

    static func resolvedEnvironment() -> AppEnvironment {
        if let override = ProcessInfo.processInfo.environment[Keys.environment] {
            return AppEnvironment(rawValue: override.lowercased()) ?? defaultEnvironment
        }

        return defaultEnvironment
    }

    static func resolvedServiceMode(fallback: AppServiceMode) -> AppServiceMode {
        if let override = ProcessInfo.processInfo.environment[Keys.serviceMode] {
            return AppServiceMode(rawValue: override.lowercased()) ?? fallback
        }

        if isLocalDebugRun {
            return .remote
        }

        return fallback
    }

    static func resolvedServerURL(fallback: URL) -> URL {
        if
            let override = ProcessInfo.processInfo.environment[Keys.serverURL],
            let url = URL(string: override)
        {
            return url
        }

        return fallback
    }

    private static var defaultEnvironment: AppEnvironment {
        #if APP_PACKAGE_DEVELOP
        return .develop
        #elseif APP_PACKAGE_TEST
        return .test
        #elseif APP_PACKAGE_PRODUCTION
        return .production
        #elseif DEBUG
        return .develop
        #else
        return .production
        #endif
    }

    private static var isLocalDebugRun: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}
