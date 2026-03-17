import Foundation
import os

private let splashAdLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "ioscrmapp",
    category: "SplashAd"
)

protocol SplashAdServicing: Sendable {
    func loadPlayableAd() async -> SplashAdPlayable?
    func refreshSplashAdCache() async
}

actor MockSplashAdService: SplashAdServicing {
    private let cachedAd: SplashAdPlayable?

    init(cachedAd: SplashAdPlayable? = nil) {
        self.cachedAd = cachedAd
    }

    func loadPlayableAd() async -> SplashAdPlayable? {
        cachedAd
    }

    func refreshSplashAdCache() async {
    }
}

struct RemoteSplashAdService: SplashAdServicing {
    private let client: HTTPClient
    private let repository: SplashAdCacheRepository

    init(
        serverURL: URL,
        session: URLSession = .shared,
        contextBuilder: NetworkContextBuilder = NetworkContextBuilder(),
        fileManager: FileManager = .default,
        cacheDirectory: URL? = nil,
        nowProvider: @escaping @Sendable () -> Date = { Date() }
    ) {
        client = HTTPClient(
            baseURL: serverURL,
            session: session,
            contextBuilder: contextBuilder
        )
        repository = SplashAdCacheRepository(
            cacheDirectory: cacheDirectory,
            fileManager: fileManager,
            nowProvider: nowProvider
        )
    }

    func loadPlayableAd() async -> SplashAdPlayable? {
        await repository.loadPlayableAd()
    }

    func refreshSplashAdCache() async {
        do {
            guard let configuration = try await fetchCurrentConfiguration() else {
                await repository.clearCache()
                return
            }

            guard configuration.isCacheable else {
                await repository.clearCache()
                return
            }

            let downloadedFileURL = try await downloadMaterial(
                bucketName: configuration.bucketName,
                objectName: configuration.objectName
            )
            try await repository.replaceCache(with: configuration, downloadedFileURL: downloadedFileURL)
        } catch is CancellationError {
            splashAdLogger.notice("Splash ad cache refresh cancelled")
        } catch let error as HTTPClient.ClientError {
            splashAdLogger.error("Splash ad refresh failed with client error: \(String(describing: error), privacy: .public)")
        } catch {
            splashAdLogger.error("Splash ad refresh failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func fetchCurrentConfiguration() async throws -> SplashAdRemoteConfiguration? {
        let responseData = try await client.get(AdvertisementAPI.currentSplashAdvertisement)

        switch responseData {
        case .null:
            return nil
        case let .object(dictionary):
            return try SplashAdRemoteConfigurationMapper.map(dictionary)
        default:
            throw HTTPClient.ClientError.invalidResponse
        }
    }

    private func downloadMaterial(bucketName: String, objectName: String) async throws -> URL {
        try await client.download(
            AdvertisementAPI.splashMaterialDownload,
            parameters: [
                "bucketName": bucketName,
                "objectName": objectName
            ]
        )
    }
}

actor SplashAdCacheRepository {
    private let fileManager: FileManager
    private let nowProvider: @Sendable () -> Date
    private let rootDirectory: URL
    private let manifestURL: URL
    private let manifestEncoder: JSONEncoder
    private let manifestDecoder: JSONDecoder

    init(
        cacheDirectory: URL? = nil,
        fileManager: FileManager = .default,
        nowProvider: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.fileManager = fileManager
        self.nowProvider = nowProvider

        let baseDirectory = cacheDirectory
            ?? fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        rootDirectory = baseDirectory.appendingPathComponent("SplashAds", isDirectory: true)
        manifestURL = rootDirectory.appendingPathComponent("manifest.json", isDirectory: false)

        manifestEncoder = JSONEncoder()
        manifestEncoder.dateEncodingStrategy = .iso8601
        manifestEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        manifestDecoder = JSONDecoder()
        manifestDecoder.dateDecodingStrategy = .iso8601
    }

    func loadPlayableAd() -> SplashAdPlayable? {
        ensureCacheDirectoryIfNeeded()

        guard let manifest = loadManifest() else {
            return nil
        }

        guard manifest.id.isEmpty == false, manifest.localFileName.isEmpty == false else {
            clearCacheFiles()
            return nil
        }

        let now = nowProvider()
        guard now >= manifest.startsAt else {
            clearCacheFiles()
            return nil
        }
        if let endsAt = manifest.endsAt, now > endsAt {
            clearCacheFiles()
            return nil
        }

        let videoFileURL = rootDirectory.appendingPathComponent(manifest.localFileName, isDirectory: false)
        guard fileManager.fileExists(atPath: videoFileURL.path) else {
            clearCacheFiles()
            return nil
        }

        return SplashAdPlayable(
            id: manifest.id,
            fileURL: videoFileURL,
            startsAt: manifest.startsAt,
            endsAt: manifest.endsAt
        )
    }

    func replaceCache(with configuration: SplashAdRemoteConfiguration, downloadedFileURL: URL) throws {
        ensureCacheDirectoryIfNeeded()

        let localFileName = makeLocalFileName(for: configuration)
        let destinationURL = rootDirectory.appendingPathComponent(localFileName, isDirectory: false)
        let temporaryURL = rootDirectory.appendingPathComponent(UUID().uuidString, isDirectory: false)
            .appendingPathExtension(destinationURL.pathExtension)

        if fileManager.fileExists(atPath: temporaryURL.path) {
            try? fileManager.removeItem(at: temporaryURL)
        }
        try fileManager.moveItem(at: downloadedFileURL, to: temporaryURL)

        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: temporaryURL, to: destinationURL)

            let manifest = SplashAdManifest(
                id: configuration.id,
                startsAt: configuration.startsAt,
                endsAt: configuration.endsAt,
                bucketName: configuration.bucketName,
                objectName: configuration.objectName,
                localFileName: localFileName,
                updatedAt: nowProvider()
            )
            try writeManifest(manifest)
            removeStaleFiles(keeping: localFileName)
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw error
        }
    }

    func clearCache() {
        clearCacheFiles()
    }

    private func ensureCacheDirectoryIfNeeded() {
        guard !fileManager.fileExists(atPath: rootDirectory.path) else {
            return
        }

        try? fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
    }

    private func loadManifest() -> SplashAdManifest? {
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            return nil
        }

        guard
            let data = try? Data(contentsOf: manifestURL),
            let manifest = try? manifestDecoder.decode(SplashAdManifest.self, from: data)
        else {
            clearCacheFiles()
            return nil
        }

        return manifest
    }

    private func writeManifest(_ manifest: SplashAdManifest) throws {
        let data = try manifestEncoder.encode(manifest)
        try data.write(to: manifestURL, options: .atomic)
    }

    private func clearCacheFiles() {
        guard fileManager.fileExists(atPath: rootDirectory.path) else {
            return
        }

        let fileURLs = (try? fileManager.contentsOfDirectory(
            at: rootDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []

        for fileURL in fileURLs {
            try? fileManager.removeItem(at: fileURL)
        }

        try? fileManager.removeItem(at: manifestURL)
    }

    private func removeStaleFiles(keeping activeFileName: String) {
        let fileURLs = (try? fileManager.contentsOfDirectory(
            at: rootDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []

        for fileURL in fileURLs where fileURL.lastPathComponent != activeFileName && fileURL.lastPathComponent != manifestURL.lastPathComponent {
            try? fileManager.removeItem(at: fileURL)
        }
    }

    private func makeLocalFileName(for configuration: SplashAdRemoteConfiguration) -> String {
        let pathExtension = URL(fileURLWithPath: configuration.objectName).pathExtension.isEmpty
            ? "mp4"
            : URL(fileURLWithPath: configuration.objectName).pathExtension
        let sanitizedIdentifier = configuration.id
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "-")
        return "splash-\(sanitizedIdentifier).\(pathExtension)"
    }
}

private enum SplashAdRemoteConfigurationMapper {
    static func map(_ dictionary: [String: HTTPClient.ResponseData]) throws -> SplashAdRemoteConfiguration {
        guard let id = string(in: dictionary, keys: ["id"]) else {
            throw HTTPClient.ClientError.invalidResponse
        }

        let isEnabled = dictionary["isEnabled"]?.boolValue ?? false
        guard
            let startsAtString = string(in: dictionary, keys: ["startsAt"]),
            let startsAt = SplashAdDateParser.parse(startsAtString),
            let bucketName = string(in: dictionary, keys: ["bucketName"]),
            let objectName = string(in: dictionary, keys: ["objectName"])
        else {
            throw HTTPClient.ClientError.invalidResponse
        }

        let endsAt = string(in: dictionary, keys: ["endsAt"]).flatMap(SplashAdDateParser.parse)

        return SplashAdRemoteConfiguration(
            id: id,
            isEnabled: isEnabled,
            startsAt: startsAt,
            endsAt: endsAt,
            bucketName: bucketName,
            objectName: objectName
        )
    }

    private static func string(in dictionary: [String: HTTPClient.ResponseData], keys: [String]) -> String? {
        for key in keys {
            if let value = dictionary[key]?.stringValue, value.isEmpty == false {
                return value
            }
        }
        return nil
    }
}

private enum SplashAdDateParser {
    private static let internetDateTimeFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static let fractionalSecondsFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static let compactFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()

    private static let backendFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    static func parse(_ value: String) -> Date? {
        if let date = fractionalSecondsFormatter.date(from: value) {
            return date
        }
        if let date = internetDateTimeFormatter.date(from: value) {
            return date
        }
        if let date = compactFormatter.date(from: value) {
            return date
        }
        return backendFormatter.date(from: value)
    }
}
