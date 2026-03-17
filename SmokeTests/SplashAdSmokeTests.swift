import Foundation

private final class SplashAdMockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let requestHandler = Self.requestHandler else {
            fatalError("Missing splash ad request handler")
        }

        do {
            let (response, data) = try requestHandler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {
    }
}

@main
struct SplashAdSmokeTests {
    static func main() async throws {
        try await testLoadPlayableAd_whenManifestAndFileValid_returnsPlayableAd()
        try await testLoadPlayableAd_whenManifestExpired_clearsCacheAndReturnsNil()
        try await testLoadPlayableAd_whenManifestCorrupted_clearsCacheAndReturnsNil()
        try await testRefreshSplashAdCache_whenRemoteConfigAvailable_downloadsVideoAndUpdatesCache()
        try await testRefreshSplashAdCache_whenDownloadFails_keepsExistingCache()
        print("Splash ad smoke tests passed")
    }

    private static func testLoadPlayableAd_whenManifestAndFileValid_returnsPlayableAd() async throws {
        let fixture = try makeFixtureDirectory()
        defer { try? FileManager.default.removeItem(at: fixture.rootDirectory) }

        let repository = SplashAdCacheRepository(
            cacheDirectory: fixture.rootDirectory,
            nowProvider: { fixture.now }
        )
        try writeManifest(
            SplashAdManifest(
                id: "launch-1",
                startsAt: fixture.now.addingTimeInterval(-60),
                endsAt: fixture.now.addingTimeInterval(60),
                bucketName: "mobileapp",
                objectName: "start/2026/03/17/launch-1.mp4",
                localFileName: "launch-1.mp4",
                updatedAt: fixture.now
            ),
            to: fixture.rootDirectory
        )
        try Data([0x00, 0x01]).write(
            to: fixture.rootDirectory.appendingPathComponent("SplashAds/launch-1.mp4")
        )

        let playableAd = await repository.loadPlayableAd()
        try require(playableAd?.id == "launch-1", "valid cache should return a playable ad")
    }

    private static func testLoadPlayableAd_whenManifestExpired_clearsCacheAndReturnsNil() async throws {
        let fixture = try makeFixtureDirectory()
        defer { try? FileManager.default.removeItem(at: fixture.rootDirectory) }

        let repository = SplashAdCacheRepository(
            cacheDirectory: fixture.rootDirectory,
            nowProvider: { fixture.now }
        )
        try writeManifest(
            SplashAdManifest(
                id: "launch-expired",
                startsAt: fixture.now.addingTimeInterval(-120),
                endsAt: fixture.now.addingTimeInterval(-10),
                bucketName: "mobileapp",
                objectName: "start/2026/03/17/launch-expired.mp4",
                localFileName: "launch-expired.mp4",
                updatedAt: fixture.now
            ),
            to: fixture.rootDirectory
        )
        try Data([0x00, 0x01]).write(
            to: fixture.rootDirectory.appendingPathComponent("SplashAds/launch-expired.mp4")
        )

        let playableAd = await repository.loadPlayableAd()
        try require(playableAd == nil, "expired cache should fall back to content")
        try require(
            !FileManager.default.fileExists(atPath: fixture.rootDirectory.appendingPathComponent("SplashAds/manifest.json").path),
            "expired cache should be cleared"
        )
    }

    private static func testLoadPlayableAd_whenManifestCorrupted_clearsCacheAndReturnsNil() async throws {
        let fixture = try makeFixtureDirectory()
        defer { try? FileManager.default.removeItem(at: fixture.rootDirectory) }

        let splashDirectory = fixture.rootDirectory.appendingPathComponent("SplashAds", isDirectory: true)
        try FileManager.default.createDirectory(at: splashDirectory, withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: splashDirectory.appendingPathComponent("manifest.json"))

        let repository = SplashAdCacheRepository(
            cacheDirectory: fixture.rootDirectory,
            nowProvider: { fixture.now }
        )

        let playableAd = await repository.loadPlayableAd()
        try require(playableAd == nil, "corrupted manifest should not produce playable ad")
        try require(
            !FileManager.default.fileExists(atPath: splashDirectory.appendingPathComponent("manifest.json").path),
            "corrupted manifest should be removed"
        )
    }

    private static func testRefreshSplashAdCache_whenRemoteConfigAvailable_downloadsVideoAndUpdatesCache() async throws {
        let fixture = try makeFixtureDirectory()
        defer { try? FileManager.default.removeItem(at: fixture.rootDirectory) }

        let session = makeMockSession()
        SplashAdMockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!

            switch request.url?.path {
            case "/ser-query/api/advertisement/current":
                return (
                    response,
                    try wrappedResponse(data: [
                        "id": "launch-fresh",
                        "isEnabled": true,
                        "startsAt": "2026-03-17T00:00:00Z",
                        "endsAt": "2026-03-18T00:00:00Z",
                        "bucketName": "mobileapp",
                        "objectName": "start/2026/03/17/launch-fresh.mp4"
                    ])
                )
            case "/api/file/download":
                try require(request.httpMethod == "POST", "material download should use POST")
                let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
                let queryItems = Dictionary(uniqueKeysWithValues: (components?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
                try require(queryItems["bucketName"] == "mobileapp", "download proxy should include bucketName")
                try require(queryItems["objectName"] == "start/2026/03/17/launch-fresh.mp4", "download proxy should include objectName")
                return (response, Data([0x00, 0x01, 0x02]))
            default:
                throw NSError(domain: "SmokeTests", code: 404)
            }
        }

        let service = RemoteSplashAdService(
            serverURL: URL(string: "https://example.com")!,
            session: session,
            cacheDirectory: fixture.rootDirectory,
            nowProvider: { fixture.now }
        )

        await service.refreshSplashAdCache()

        let playableAd = await service.loadPlayableAd()
        try require(playableAd?.id == "launch-fresh", "refresh should update the playable cache")
    }

    private static func testRefreshSplashAdCache_whenDownloadFails_keepsExistingCache() async throws {
        let fixture = try makeFixtureDirectory()
        defer { try? FileManager.default.removeItem(at: fixture.rootDirectory) }

        try writeManifest(
            SplashAdManifest(
                id: "launch-existing",
                startsAt: fixture.now.addingTimeInterval(-60),
                endsAt: fixture.now.addingTimeInterval(60),
                bucketName: "mobileapp",
                objectName: "start/2026/03/17/launch-existing.mp4",
                localFileName: "launch-existing.mp4",
                updatedAt: fixture.now
            ),
            to: fixture.rootDirectory
        )
        try Data([0x00, 0x01]).write(
            to: fixture.rootDirectory.appendingPathComponent("SplashAds/launch-existing.mp4")
        )

        let session = makeMockSession()
        SplashAdMockURLProtocol.requestHandler = { request in
            switch request.url?.path {
            case "/ser-query/api/advertisement/current":
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (
                    response,
                    try wrappedResponse(data: [
                        "id": "launch-new",
                        "isEnabled": true,
                        "startsAt": "2026-03-17T00:00:00Z",
                        "endsAt": "2026-03-18T00:00:00Z",
                        "bucketName": "mobileapp",
                        "objectName": "start/2026/03/17/launch-new.mp4"
                    ])
                )
            case "/api/file/download":
                try require(request.httpMethod == "POST", "material download should use POST")
                let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
                let queryItems = Dictionary(uniqueKeysWithValues: (components?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
                try require(queryItems["bucketName"] == "mobileapp", "download proxy should include bucketName")
                try require(queryItems["objectName"] == "start/2026/03/17/launch-new.mp4", "download proxy should include objectName")
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 500,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, Data())
            default:
                throw NSError(domain: "SmokeTests", code: 404)
            }
        }

        let service = RemoteSplashAdService(
            serverURL: URL(string: "https://example.com")!,
            session: session,
            cacheDirectory: fixture.rootDirectory,
            nowProvider: { fixture.now }
        )

        await service.refreshSplashAdCache()

        let playableAd = await service.loadPlayableAd()
        try require(playableAd?.id == "launch-existing", "download failure should preserve the previous cache")
    }

    private static func makeFixtureDirectory() throws -> (rootDirectory: URL, now: Date) {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        return (rootDirectory, Date(timeIntervalSince1970: 1_773_705_600))
    }

    private static func writeManifest(_ manifest: SplashAdManifest, to rootDirectory: URL) throws {
        let splashDirectory = rootDirectory.appendingPathComponent("SplashAds", isDirectory: true)
        try FileManager.default.createDirectory(at: splashDirectory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest)
        try data.write(to: splashDirectory.appendingPathComponent("manifest.json"), options: .atomic)
    }

    private static func wrappedResponse(data: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "code": 200,
            "msg": "OK",
            "data": data
        ])
    }

    private static func makeMockSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SplashAdMockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() {
            throw NSError(domain: "SplashAdSmokeTests", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }
}
