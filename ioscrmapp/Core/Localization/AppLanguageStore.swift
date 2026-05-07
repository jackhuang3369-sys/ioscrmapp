import Foundation
import SwiftUI

@MainActor
final class AppLanguageStore: ObservableObject {
    @Published private(set) var currentLanguage: AppLanguage

    private let defaults: UserDefaults
    private let languageKey = "app.language"
    private var catalogs: [AppLanguage: [String: String]] = [:]

    init(defaults: UserDefaults = .standard, initialLanguage: AppLanguage? = nil) {
        self.defaults = defaults

        if let initialLanguage {
            currentLanguage = initialLanguage
            return
        }

        let storedLanguage = defaults.string(forKey: languageKey)
            .flatMap(AppLanguage.init(rawValue:))
        currentLanguage = storedLanguage ?? .fallback
    }

    var locale: Locale {
        currentLanguage.locale
    }

    var layoutDirection: LayoutDirection {
        currentLanguage.layoutDirection
    }

    func updateLanguage(_ language: AppLanguage) {
        guard currentLanguage != language else {
            return
        }

        currentLanguage = language
        defaults.set(language.rawValue, forKey: languageKey)
    }

    func string(_ value: LocalizedTextValue?) -> String {
        guard let value else {
            return ""
        }

        switch value {
        case let .literal(text):
            return text
        case let .localized(key, arguments):
            return string(key, arguments: arguments)
        }
    }

    func string(_ key: String, arguments: [String] = []) -> String {
        let format = localizedFormat(for: key, language: currentLanguage)
            ?? localizedFormat(for: key, language: .fallback)
            ?? key

        guard !arguments.isEmpty else {
            return format
        }

        return String(format: format, locale: locale, arguments: arguments.map { $0 as CVarArg })
    }

    private func localizedFormat(for key: String, language: AppLanguage) -> String? {
        if let cachedValue = catalogs[language]?[key] {
            return cachedValue
        }

        let loadedCatalog = loadCatalog(for: language)
        catalogs[language] = loadedCatalog
        return loadedCatalog[key]
    }

    private func loadCatalog(for language: AppLanguage) -> [String: String] {
        for fileURL in candidateCatalogURLs(for: language) {
            guard
                let data = try? Data(contentsOf: fileURL),
                let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                continue
            }

            var flattenedCatalog: [String: String] = [:]
            flatten(jsonObject, prefix: "", into: &flattenedCatalog)
            if !flattenedCatalog.isEmpty {
                return flattenedCatalog
            }
        }

        return [:]
    }

    private func candidateCatalogURLs(for language: AppLanguage) -> [URL] {
        let resourceURL = Bundle.main.resourceURL
        let localizedFolder = "\(language.rawValue).lproj"
        let fileName = "Localizable.json"

        return [
            Bundle.main.url(forResource: fileName, withExtension: nil, subdirectory: "Localizations/\(localizedFolder)"),
            Bundle.main.url(forResource: "Localizable", withExtension: "json", subdirectory: "Localizations/\(localizedFolder)"),
            Bundle.main.url(forResource: fileName, withExtension: nil, subdirectory: localizedFolder),
            Bundle.main.url(forResource: "Localizable", withExtension: "json", subdirectory: localizedFolder),
            resourceURL?.appendingPathComponent("Localizations", isDirectory: true)
                .appendingPathComponent(localizedFolder, isDirectory: true)
                .appendingPathComponent(fileName, isDirectory: false),
            resourceURL?.appendingPathComponent(localizedFolder, isDirectory: true)
                .appendingPathComponent(fileName, isDirectory: false)
        ]
        .compactMap { $0 }
    }

    private func flatten(_ dictionary: [String: Any], prefix: String, into output: inout [String: String]) {
        for (key, value) in dictionary {
            let fullKey = prefix.isEmpty ? key : "\(prefix).\(key)"
            if let stringValue = value as? String {
                output[fullKey] = stringValue
                continue
            }

            if let nestedDictionary = value as? [String: Any] {
                flatten(nestedDictionary, prefix: fullKey, into: &output)
            }
        }
    }
}
