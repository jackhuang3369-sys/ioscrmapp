import Foundation
import os

private let videoLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "ioscrmapp",
    category: "Video"
)

protocol VideoServicing: Sendable {
    func fetchNavigation(session: CustSubInfo) async throws -> VideoNavigationSnapshot
    func fetchCarousels(categoryID: String, session: CustSubInfo) async throws -> [VideoCarouselItem]
    func fetchList(
        categoryID: String,
        pageNum: Int,
        pageSize: Int,
        session: CustSubInfo
    ) async throws -> VideoPagedFeedSnapshot
    func fetchSearchBootstrap(session: CustSubInfo) async throws -> VideoSearchBootstrap
    func searchVideos(
        keyword: String,
        language: AppLanguage,
        session: CustSubInfo
    ) async throws -> VideoSearchResponse
    func fetchDetail(videoID: String, session: CustSubInfo) async throws -> VideoDetailSnapshot
    func requestPlaybackSession(
        videoID: String,
        episodeID: String?,
        preferredQuality: VideoQuality?,
        session: CustSubInfo
    ) async throws -> VideoPlaybackSession
    func deleteSearchHistory(keyword: String, session: CustSubInfo) async throws
    func clearSearchHistory(session: CustSubInfo) async throws
}

enum VideoServiceError: Error, Equatable {
    case featureDisabled
    case homeUnavailable
    case detailUnavailable
    case searchUnavailable
    case playbackUnavailable
    case keywordInvalid
    case pageInvalid
    case networkUnavailable
    case notFound

    var textValue: LocalizedTextValue {
        switch self {
        case .featureDisabled:
            return .key("home.feature.video.message")
        case .homeUnavailable:
            return .key("video.state.error.subtitle")
        case .detailUnavailable:
            return .key("video.detail.error.subtitle")
        case .searchUnavailable:
            return .key("video.search.error.subtitle")
        case .playbackUnavailable:
            return .key("video.player.error.subtitle")
        case .keywordInvalid:
            return .key("video.search.validation.empty")
        case .pageInvalid:
            return .key("video.state.error.subtitle")
        case .networkUnavailable:
            return .key("video.state.error.subtitle")
        case .notFound:
            return .key("video.detail.error.subtitle")
        }
    }
}

actor MockVideoService: VideoServicing {
    private let catalog = VideoMockCatalog.make()
    private var remoteHistory = [
        "Spider-Man",
        "Batman",
        "Documentary",
    ]

    func fetchNavigation(session: CustSubInfo) async throws -> VideoNavigationSnapshot {
        try await Task.sleep(nanoseconds: 120_000_000)
        return catalog.navigation
    }

    func fetchCarousels(categoryID: String, session: CustSubInfo) async throws -> [VideoCarouselItem] {
        try await Task.sleep(nanoseconds: 80_000_000)
        return catalog.carouselItemsByCategory[categoryID] ?? []
    }

    func fetchList(
        categoryID: String,
        pageNum: Int,
        pageSize: Int,
        session: CustSubInfo
    ) async throws -> VideoPagedFeedSnapshot {
        guard pageNum >= VideoPaginationDefaults.firstPage, pageSize > 0 else {
            throw VideoServiceError.pageInvalid
        }

        try await Task.sleep(nanoseconds: 90_000_000)

        let items = catalog.feedItemsByCategory[categoryID] ?? []
        let startIndex = max(0, (pageNum - 1) * pageSize)
        let endIndex = min(items.count, startIndex + pageSize)
        let pagedItems = startIndex < items.count ? Array(items[startIndex..<endIndex]) : []

        return VideoPagedFeedSnapshot(
            categoryID: categoryID,
            pageNum: pageNum,
            pageSize: pageSize,
            total: items.count,
            hasMore: endIndex < items.count,
            items: pagedItems
        )
    }

    func fetchSearchBootstrap(session: CustSubInfo) async throws -> VideoSearchBootstrap {
        try await Task.sleep(nanoseconds: 70_000_000)
        return VideoSearchBootstrap(
            remoteHistory: remoteHistory,
            historyLimit: VideoPaginationDefaults.historyLimit
        )
    }

    func searchVideos(
        keyword: String,
        language: AppLanguage,
        session: CustSubInfo
    ) async throws -> VideoSearchResponse {
        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKeyword.isEmpty, trimmedKeyword.count <= 50 else {
            throw VideoServiceError.keywordInvalid
        }

        try await Task.sleep(nanoseconds: 100_000_000)

        remoteHistory = [trimmedKeyword] + remoteHistory.filter {
            $0.caseInsensitiveCompare(trimmedKeyword) != .orderedSame
        }
        remoteHistory = Array(remoteHistory.prefix(VideoPaginationDefaults.historyLimit))

        let normalizedKeyword = normalizedVideoSearchValue(trimmedKeyword)
        let details = catalog.detailsByID.values.sorted {
            $0.content.title.english < $1.content.title.english
        }

        for detail in details {
            if detail.content.matches(query: normalizedKeyword, language: language),
               let matchedBy = matchedByLabel(for: detail, query: normalizedKeyword) {
                return VideoSearchResponse(
                    keyword: trimmedKeyword,
                    matchedContent: detail.content,
                    matchedBy: matchedBy,
                    recommendations: Array(detail.related.prefix(3))
                )
            }
        }

        return VideoSearchResponse(
            keyword: trimmedKeyword,
            matchedContent: nil,
            matchedBy: nil,
            recommendations: Array(catalog.feedItemsByCategory["recommend", default: []].prefix(3))
        )
    }

    func fetchDetail(videoID: String, session: CustSubInfo) async throws -> VideoDetailSnapshot {
        try await Task.sleep(nanoseconds: 90_000_000)

        guard let detail = catalog.detailsByID[videoID] else {
            throw VideoServiceError.notFound
        }

        return detail
    }

    func requestPlaybackSession(
        videoID: String,
        episodeID: String?,
        preferredQuality: VideoQuality?,
        session: CustSubInfo
    ) async throws -> VideoPlaybackSession {
        try await Task.sleep(nanoseconds: 120_000_000)

        guard let detail = catalog.detailsByID[videoID] else {
            throw VideoServiceError.notFound
        }

        guard detail.isPlayable else {
            throw VideoServiceError.playbackUnavailable
        }

        let targetEpisode = detail.episodeGroups
            .flatMap(\.episodes)
            .first { $0.id == episodeID }
            ?? detail.defaultEpisode

        guard let targetEpisode, targetEpisode.availabilityStatus.isPlayable else {
            throw VideoServiceError.playbackUnavailable
        }

        return catalog.makePlaybackSession(
            detail: detail,
            episode: targetEpisode,
            preferredQuality: preferredQuality
        )
    }

    func deleteSearchHistory(keyword: String, session: CustSubInfo) async throws {
        remoteHistory.removeAll { $0.caseInsensitiveCompare(keyword) == .orderedSame }
    }

    func clearSearchHistory(session: CustSubInfo) async throws {
        remoteHistory.removeAll()
    }

    private func matchedByLabel(
        for detail: VideoDetailSnapshot,
        query: String
    ) -> VideoLocalizedString? {
        if detail.content.title.matches(query: query) {
            return VideoLocalizedString("标题命中", "Matched by title", "مطابقة بالعنوان")
        }

        if detail.tags.contains(where: { $0.title.matches(query: query) }) {
            return VideoLocalizedString("标签命中", "Matched by tag", "مطابقة بالوسم")
        }

        if detail.cast.contains(where: { normalizedVideoSearchValue($0.name).contains(query) }) {
            return VideoLocalizedString("主创命中", "Matched by cast", "مطابقة بطاقم العمل")
        }

        return VideoLocalizedString("文案命中", "Matched by text", "مطابقة بالنص")
    }
}

struct RemoteVideoService: VideoServicing {
    private let client: HTTPClient

    init(
        serverURL: URL,
        session: URLSession = .shared,
        contextBuilder: NetworkContextBuilder = NetworkContextBuilder()
    ) {
        client = HTTPClient(
            baseURL: serverURL,
            session: session,
            contextBuilder: contextBuilder
        )
    }

    func fetchNavigation(session: CustSubInfo) async throws -> VideoNavigationSnapshot {
        videoLogger.debug("Remote video navigation is disabled until backend integration is ready.")
        _ = client
        return VideoNavigationSnapshot(featureEnabled: false, defaultCategoryID: nil, categories: [])
    }

    func fetchCarousels(categoryID: String, session: CustSubInfo) async throws -> [VideoCarouselItem] {
        throw VideoServiceError.featureDisabled
    }

    func fetchList(
        categoryID: String,
        pageNum: Int,
        pageSize: Int,
        session: CustSubInfo
    ) async throws -> VideoPagedFeedSnapshot {
        throw VideoServiceError.featureDisabled
    }

    func fetchSearchBootstrap(session: CustSubInfo) async throws -> VideoSearchBootstrap {
        throw VideoServiceError.featureDisabled
    }

    func searchVideos(
        keyword: String,
        language: AppLanguage,
        session: CustSubInfo
    ) async throws -> VideoSearchResponse {
        throw VideoServiceError.featureDisabled
    }

    func fetchDetail(videoID: String, session: CustSubInfo) async throws -> VideoDetailSnapshot {
        throw VideoServiceError.featureDisabled
    }

    func requestPlaybackSession(
        videoID: String,
        episodeID: String?,
        preferredQuality: VideoQuality?,
        session: CustSubInfo
    ) async throws -> VideoPlaybackSession {
        throw VideoServiceError.featureDisabled
    }

    func deleteSearchHistory(keyword: String, session: CustSubInfo) async throws {
        throw VideoServiceError.featureDisabled
    }

    func clearSearchHistory(session: CustSubInfo) async throws {
        throw VideoServiceError.featureDisabled
    }
}

private struct VideoCatalog {
    let navigation: VideoNavigationSnapshot
    let carouselItemsByCategory: [String: [VideoCarouselItem]]
    let feedItemsByCategory: [String: [VideoContentSummary]]
    let detailsByID: [String: VideoDetailSnapshot]

    func makePlaybackSession(
        detail: VideoDetailSnapshot,
        episode: VideoEpisode,
        preferredQuality: VideoQuality?
    ) -> VideoPlaybackSession {
        VideoPlaybackSession(
            playSessionID: "play-\(episode.id)-\(UUID().uuidString)",
            expiresAt: Date().addingTimeInterval(30 * 60),
            mediaID: detail.content.id,
            mediaTitle: detail.content.title,
            episode: reorderedEpisode(episode, preferredQuality: preferredQuality),
            pipEnabled: true
        )
    }

    private func reorderedEpisode(
        _ episode: VideoEpisode,
        preferredQuality: VideoQuality?
    ) -> VideoEpisode {
        guard let preferredQuality else {
            return episode
        }

        let sortedResolutions = episode.resolutions.sorted {
            if $0.quality == preferredQuality { return true }
            if $1.quality == preferredQuality { return false }
            return $0.quality.sortOrder < $1.quality.sortOrder
        }

        return VideoEpisode(
            id: episode.id,
            episodeNumber: episode.episodeNumber,
            title: episode.title,
            subtitle: episode.subtitle,
            durationSeconds: episode.durationSeconds,
            thumbnailImage: episode.thumbnailImage,
            availabilityStatus: episode.availabilityStatus,
            availabilityMessage: episode.availabilityMessage,
            resolutions: sortedResolutions,
            subtitleTracks: episode.subtitleTracks,
            audioTracks: episode.audioTracks
        )
    }
}

private enum VideoMockCatalog {
    private static let sampleStreamURL = URL(
        string: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"
    )!

    static func make() -> VideoCatalog {
        let mediaList = CRMReferenceMockData.mediaList
        let mediaByID = Dictionary(uniqueKeysWithValues: mediaList.map { ($0.id, $0) })
        let detailsByID = Dictionary(uniqueKeysWithValues: mediaList.map { media in
            (media.id, makeDetail(from: media, mediaByID: mediaByID))
        })

        let sortedContent = detailsByID.values
            .map(\.content)
            .sorted(by: sortFeedContent)

        let feedItemsByCategory: [String: [VideoContentSummary]] = [
            "recommend": sortedContent,
            "movie": sortedContent.filter { $0.type == .movie },
            "series": sortedContent.filter { $0.type == .series },
            "variety": sortedContent.filter { $0.type == .variety },
            "documentary": sortedContent.filter { $0.type == .documentary },
        ]

        return VideoCatalog(
            navigation: VideoNavigationSnapshot(
                featureEnabled: true,
                defaultCategoryID: "recommend",
                categories: categories
            ),
            carouselItemsByCategory: makeCarousels(from: feedItemsByCategory),
            feedItemsByCategory: feedItemsByCategory,
            detailsByID: detailsByID
        )
    }

    private static let categories = [
        VideoCategory(
            id: "recommend",
            title: VideoLocalizedString("推荐", "Recommend", "موصى به"),
            symbolName: "sparkles"
        ),
        VideoCategory(
            id: "movie",
            title: VideoLocalizedString("电影", "Movie", "أفلام"),
            symbolName: "film"
        ),
        VideoCategory(
            id: "series",
            title: VideoLocalizedString("剧集", "Series", "مسلسلات"),
            symbolName: "rectangle.stack"
        ),
        VideoCategory(
            id: "variety",
            title: VideoLocalizedString("综艺", "Variety", "منوعات"),
            symbolName: "music.note.tv"
        ),
        VideoCategory(
            id: "documentary",
            title: VideoLocalizedString("纪录片", "Documentary", "وثائقي"),
            symbolName: "globe.asia.australia"
        ),
    ]

    private static func makeCarousels(
        from feeds: [String: [VideoContentSummary]]
    ) -> [String: [VideoCarouselItem]] {
        let palettes: [(UInt32, UInt32)] = [
            (0x0F172A, 0x1D4ED8),
            (0x3B0764, 0x2563EB),
            (0x14532D, 0x0F766E),
            (0x7C2D12, 0xDB2777),
        ]

        func items(for categoryID: String, limit: Int) -> [VideoCarouselItem] {
            Array(feeds[categoryID, default: []].prefix(limit)).enumerated().map { index, content in
                let palette = palettes[index % palettes.count]
                return VideoCarouselItem(
                    id: "\(categoryID)-carousel-\(content.id)",
                    eyebrow: content.badgeText ?? localizedTypeTitle(for: content.type),
                    content: content,
                    accentStartHex: palette.0,
                    accentEndHex: palette.1
                )
            }
        }

        return [
            "recommend": items(for: "recommend", limit: 4),
            "movie": items(for: "movie", limit: 3),
            "series": items(for: "series", limit: 3),
            "variety": items(for: "variety", limit: 3),
            "documentary": items(for: "documentary", limit: 3),
        ]
    }

    private static func makeDetail(
        from media: CRMMedia,
        mediaByID: [String: CRMMedia]
    ) -> VideoDetailSnapshot {
        let content = makeContentSummary(from: media)
        let contentType = videoContentType(for: media.type)

        return VideoDetailSnapshot(
            content: content,
            heroImage: imageSource(from: media.cover, fallbackType: contentType),
            synopsis: .mirrored(media.description),
            stats: [
                VideoDetailStat(
                    id: "views",
                    titleKey: "video.detail.stat.views",
                    systemImage: "eye",
                    value: media.formattedViews
                ),
                VideoDetailStat(
                    id: "released",
                    titleKey: "video.detail.stat.released",
                    systemImage: "calendar",
                    value: media.formattedDate
                ),
                VideoDetailStat(
                    id: "episodes",
                    titleKey: "video.detail.stat.episodes",
                    systemImage: "film",
                    value: "\(media.episodes.count)"
                ),
                VideoDetailStat(
                    id: "duration",
                    titleKey: "video.detail.stat.duration",
                    systemImage: "clock",
                    value: runtimeMetricValue(for: media.duration)
                ),
            ],
            tags: media.tags.enumerated().map { index, tag in
                VideoTag(
                    id: "\(media.id)-tag-\(index)",
                    title: .mirrored(tag),
                    style: index == 0 ? .accent : .neutral
                )
            },
            episodeGroups: makeEpisodeGroups(from: media),
            defaultEpisodeID: media.episodes.first?.id,
            cast: media.actors.map { actor in
                VideoCastMember(
                    id: actor.id,
                    name: actor.name,
                    role: actor.role.map(VideoLocalizedString.mirrored),
                    avatarImage: imageSource(from: actor.avatar, fallbackType: contentType)
                )
            },
            related: media.relatedMediaIds.compactMap { relatedID in
                mediaByID[relatedID].map(makeContentSummary(from:))
            }
        )
    }

    private static func makeContentSummary(
        from media: CRMMedia
    ) -> VideoContentSummary {
        let type = videoContentType(for: media.type)
        let year = Calendar.current.component(.year, from: media.publishDate)
        let tags = Array(media.tags.prefix(3)).map(VideoLocalizedString.mirrored)

        return VideoContentSummary(
            id: media.id,
            categoryID: categoryID(for: media.type),
            type: type,
            title: .mirrored(media.title),
            subtitle: subtitleLine(for: media, year: year),
            summary: .mirrored(shortSummary(from: media.description)),
            posterImage: imageSource(from: media.cover, fallbackType: type),
            backdropImage: imageSource(from: media.cover, fallbackType: type),
            badgeText: badgeText(for: media),
            chips: tags,
            ratingText: media.rating.map { String(format: "%.1f", $0) },
            metaLine: metaLine(for: media, year: year),
            durationText: cardMetricText(for: media),
            viewCount: media.views,
            releaseDate: media.publishDate,
            episodeCount: media.episodes.count,
            durationSeconds: media.duration,
            availabilityStatus: .playable,
            availabilityMessage: nil
        )
    }

    private static func makeEpisodeGroups(
        from media: CRMMedia
    ) -> [VideoEpisodeGroup] {
        let contentType = videoContentType(for: media.type)
        let episodes = media.episodes.map { episode in
            VideoEpisode(
                id: episode.id,
                episodeNumber: episode.episodeNumber,
                title: .mirrored(episode.title),
                subtitle: .mirrored(shortEpisodeSubtitle(for: media, episode: episode)),
                durationSeconds: episode.duration,
                thumbnailImage: imageSource(
                    from: episode.thumbnail.isEmpty ? media.cover : episode.thumbnail,
                    fallbackType: contentType
                ),
                availabilityStatus: .playable,
                availabilityMessage: nil,
                resolutions: makeResolutions(for: episode),
                subtitleTracks: makeSubtitleTracks(for: episode),
                audioTracks: makeAudioTracks(for: episode)
            )
        }

        let title: VideoLocalizedString
        switch media.type {
        case .movie:
            title = VideoLocalizedString("正片", "Feature", "الفيلم")
        case .tvSeries:
            title = VideoLocalizedString("第 1 季", "Season 1", "الموسم 1")
        case .variety:
            title = VideoLocalizedString("最新期数", "Latest Episodes", "أحدث الحلقات")
        case .documentary:
            title = media.episodes.count > 1
                ? VideoLocalizedString("纪录篇章", "Documentary Parts", "أجزاء الوثائقي")
                : VideoLocalizedString("正片", "Feature", "الفيلم")
        }

        return [
            VideoEpisodeGroup(
                id: "\(media.id)-group-1",
                title: title,
                episodes: episodes
            ),
        ]
    }

    private static func makeResolutions(
        for episode: CRMEpisode
    ) -> [VideoEpisodeResolution] {
        let mapped = episode.videoSources.map { source in
            VideoEpisodeResolution(
                id: source.id,
                url: playableURL(from: source.url) ?? sampleStreamURL,
                quality: source.quality.videoQuality,
                format: source.format.videoSourceFormat
            )
        }

        if mapped.isEmpty {
            return fallbackResolutions(for: episode.id)
        }

        let deduplicated = Dictionary(mapped.map { ($0.quality, $0) }) { current, _ in current }
        return deduplicated.values.sorted { $0.quality.sortOrder < $1.quality.sortOrder }
    }

    private static func makeSubtitleTracks(
        for episode: CRMEpisode
    ) -> [VideoSubtitleTrack] {
        let mapped = episode.subtitles.map { subtitle in
            VideoSubtitleTrack(
                id: subtitle.id,
                languageCode: subtitle.language,
                displayName: .mirrored(subtitle.displayName),
                url: playableURL(from: subtitle.url),
                isEmbedded: subtitle.isEmbedded
            )
        }

        if mapped.contains(where: { $0.languageCode == "off" }) {
            return mapped
        }

        return [
            VideoSubtitleTrack(
                id: "\(episode.id)-subtitle-off",
                languageCode: "off",
                displayName: VideoLocalizedString("关闭字幕", "Off", "إيقاف الترجمة"),
                url: nil,
                isEmbedded: false
            ),
        ] + mapped
    }

    private static func makeAudioTracks(
        for episode: CRMEpisode
    ) -> [VideoAudioTrack] {
        if episode.audioTracks.isEmpty {
            return [
                VideoAudioTrack(
                    id: "\(episode.id)-audio-default",
                    languageCode: "en-US",
                    displayName: VideoLocalizedString("英语", "English", "الإنجليزية"),
                    url: nil,
                    isDefault: true
                ),
            ]
        }

        return episode.audioTracks.map { track in
            VideoAudioTrack(
                id: track.id,
                languageCode: track.language,
                displayName: .mirrored(track.displayName),
                url: playableURL(from: track.url),
                isDefault: track.isDefault
            )
        }
    }

    private static func imageSource(
        from rawValue: String?,
        fallbackType: VideoContentType
    ) -> VideoImageSource {
        guard let rawValue, !rawValue.isEmpty else {
            return placeholderImage(for: fallbackType)
        }

        if rawValue.hasPrefix("local:") {
            return .asset(String(rawValue.dropFirst(6)))
        }

        if let url = URL(string: rawValue), url.scheme != nil {
            return .remote(url)
        }

        return placeholderImage(for: fallbackType)
    }

    private static func placeholderImage(
        for type: VideoContentType
    ) -> VideoImageSource {
        switch type {
        case .movie:
            return .system(name: "film.fill", backgroundHex: 0xDDE8F6, tintHex: 0x47627D)
        case .series:
            return .system(name: "rectangle.stack.fill", backgroundHex: 0xDDE8F6, tintHex: 0x47627D)
        case .variety:
            return .system(name: "music.note.tv.fill", backgroundHex: 0xDDE8F6, tintHex: 0x47627D)
        case .documentary:
            return .system(name: "globe.asia.australia.fill", backgroundHex: 0xDDE8F6, tintHex: 0x47627D)
        }
    }

    private static func categoryID(for type: CRMMediaType) -> String {
        switch type {
        case .movie:
            return "movie"
        case .tvSeries:
            return "series"
        case .variety:
            return "variety"
        case .documentary:
            return "documentary"
        }
    }

    private static func videoContentType(for type: CRMMediaType) -> VideoContentType {
        switch type {
        case .movie:
            return .movie
        case .tvSeries:
            return .series
        case .variety:
            return .variety
        case .documentary:
            return .documentary
        }
    }

    private static func localizedTypeTitle(for type: VideoContentType) -> VideoLocalizedString {
        switch type {
        case .movie:
            return VideoLocalizedString("电影", "Movie", "أفلام")
        case .series:
            return VideoLocalizedString("剧集", "Series", "مسلسلات")
        case .variety:
            return VideoLocalizedString("综艺", "Variety", "منوعات")
        case .documentary:
            return VideoLocalizedString("纪录片", "Documentary", "وثائقي")
        }
    }

    private static func subtitleLine(
        for media: CRMMedia,
        year: Int
    ) -> VideoLocalizedString {
        let tags = Array(media.tags.prefix(2))
        let english = tags.isEmpty
            ? "\(media.type.displayName) · \(year)"
            : "\(tags.joined(separator: " · ")) · \(year)"
        return .mirrored(english)
    }

    private static func metaLine(
        for media: CRMMedia,
        year: Int
    ) -> VideoLocalizedString {
        let typeTitle = localizedTypeTitle(for: videoContentType(for: media.type))
        return VideoLocalizedString(
            "\(year) | \(typeTitle.simplifiedChinese)",
            "\(year) | \(typeTitle.english)",
            "\(year) | \(typeTitle.arabic)"
        )
    }

    private static func badgeText(for media: CRMMedia) -> VideoLocalizedString? {
        if let rating = media.rating, rating >= 9.0 {
            return VideoLocalizedString("高分推荐", "Top Rated", "أعلى تقييمًا")
        }

        if media.views >= 80_000_000 {
            return VideoLocalizedString("热门", "Trending", "الأكثر مشاهدة")
        }

        return media.tags.first.map(VideoLocalizedString.mirrored)
    }

    private static func cardMetricText(for media: CRMMedia) -> VideoLocalizedString {
        switch media.type {
        case .movie:
            return runtimeMetric(for: media.duration)
        case .tvSeries:
            return VideoLocalizedString(
                "\(media.episodes.count) 集",
                "\(media.episodes.count) episodes",
                "\(media.episodes.count) حلقات"
            )
        case .variety:
            return VideoLocalizedString(
                "更新至 \(media.episodes.count) 期",
                "\(media.episodes.count) episodes",
                "\(media.episodes.count) حلقات"
            )
        case .documentary:
            if media.episodes.count > 1 {
                return VideoLocalizedString(
                    "\(media.episodes.count) 集纪录",
                    "\(media.episodes.count) parts",
                    "\(media.episodes.count) أجزاء"
                )
            }
            return runtimeMetric(for: media.duration)
        }
    }

    private static func runtimeMetricValue(for duration: Int) -> String {
        let hours = duration / 3600
        let minutes = (duration % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }

        return "\(max(1, minutes))m"
    }

    private static func runtimeMetric(for duration: Int) -> VideoLocalizedString {
        let hours = duration / 3600
        let minutes = (duration % 3600) / 60

        if hours > 0 {
            return VideoLocalizedString(
                "\(hours)小时\(minutes)分钟",
                "\(hours)h \(minutes)m",
                "\(hours) س \(minutes) د"
            )
        }

        return VideoLocalizedString(
            "\(max(1, minutes))分钟",
            "\(max(1, minutes))m",
            "\(max(1, minutes)) د"
        )
    }

    private static func shortSummary(
        from description: String
    ) -> String {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 96 else {
            return trimmed
        }

        let index = trimmed.index(trimmed.startIndex, offsetBy: 93)
        return "\(trimmed[..<index])..."
    }

    private static func shortEpisodeSubtitle(
        for media: CRMMedia,
        episode: CRMEpisode
    ) -> String {
        switch media.type {
        case .movie:
            return "Full Movie"
        case .tvSeries:
            return "Episode \(episode.episodeNumber)"
        case .variety:
            return "Stage \(episode.episodeNumber)"
        case .documentary:
            return media.episodes.count > 1 ? "Part \(episode.episodeNumber)" : "Feature"
        }
    }

    private static func playableURL(from rawValue: String?) -> URL? {
        guard let rawValue, !rawValue.isEmpty, let url = URL(string: rawValue) else {
            return nil
        }

        if url.isFileURL, !FileManager.default.fileExists(atPath: url.path) {
            return nil
        }

        return url
    }

    private static func fallbackResolutions(
        for episodeID: String
    ) -> [VideoEpisodeResolution] {
        [
            VideoEpisodeResolution(
                id: "\(episodeID)-480",
                url: sampleStreamURL,
                quality: .sd480,
                format: .hls
            ),
            VideoEpisodeResolution(
                id: "\(episodeID)-720",
                url: sampleStreamURL,
                quality: .hd720,
                format: .hls
            ),
            VideoEpisodeResolution(
                id: "\(episodeID)-1080",
                url: sampleStreamURL,
                quality: .hd1080,
                format: .hls
            ),
        ]
    }

    private static func sortFeedContent(
        lhs: VideoContentSummary,
        rhs: VideoContentSummary
    ) -> Bool {
        if lhs.viewCount != rhs.viewCount {
            return lhs.viewCount > rhs.viewCount
        }

        return lhs.releaseDate > rhs.releaseDate
    }
}

private extension CRMVideoQuality {
    var videoQuality: VideoQuality {
        switch self {
        case .auto:
            return .auto
        case .sd480:
            return .sd480
        case .hd720:
            return .hd720
        case .hd1080:
            return .hd1080
        case .uhd4k:
            return .uhd4k
        }
    }
}

private extension CRMVideoFormat {
    var videoSourceFormat: VideoSourceFormat {
        switch self {
        case .hls, .dash:
            return .hls
        case .mp4:
            return .mp4
        }
    }
}

private enum CRMReferenceRemoteResource {
    private static let baseURL = "http://10.108.1.193:15800/minio/video"

    static func videoURL(_ fileName: String) -> String {
        "\(baseURL)/videos/\(fileName)"
    }

    static func subtitleURL(_ fileName: String) -> String {
        "\(baseURL)/subtitles/\(fileName)"
    }

    static func audioURL(_ fileName: String) -> String {
        "\(baseURL)/audios/\(fileName)"
    }

    static let spidermanCoverURL = "\(baseURL)"
}

private enum CRMReferenceMockData {
    static let actors: [CRMActor] = [
        CRMActor(id: "actor_1", name: "John Smith", avatar: nil, role: "Lead"),
        CRMActor(id: "actor_2", name: "Jane Doe", avatar: nil, role: "Supporting"),
        CRMActor(id: "actor_3", name: "Mike Wilson", avatar: nil, role: "Villain"),
        CRMActor(id: "actor_4", name: "Sarah Brown", avatar: nil, role: "Cameo"),
    ]

    static let spidermanActors: [CRMActor] = [
        CRMActor(
            id: "actor_tom",
            name: "Tom Holland",
            avatar: "local:Tom Holland",
            role: "Peter Parker / Spider-Man"
        ),
        CRMActor(
            id: "actor_zendaya",
            name: "Zendaya",
            avatar: "local:Zendaya",
            role: "MJ"
        ),
        CRMActor(
            id: "actor_sadie",
            name: "Sadie Sink",
            avatar: "local:Sadie Sink",
            role: "-"
        ),
    ]

    static let darkKnightActors: [CRMActor] = [
        CRMActor(
            id: "actor_bale",
            name: "Christian Bale",
            avatar: "local:Christian Bale",
            role: "Bruce Wayne / Batman"
        ),
        CRMActor(
            id: "actor_caine",
            name: "Michael Caine",
            avatar: "https://image.tmdb.org/t/p/w185/bVZRMlpjTAO2pJK6v90uSPbiuz3.jpg",
            role: "Alfred"
        ),
        CRMActor(
            id: "actor_ledger",
            name: "Heath Ledger",
            avatar: "https://image.tmdb.org/t/p/w185/5Y9HnYYa9jF4NunY9lSgJGjSe8E.jpg",
            role: "The Joker"
        ),
    ]

    static let videoSources: [CRMVideoSource] = [
        CRMVideoSource(
            id: "src_480",
            url: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8",
            quality: .sd480,
            format: .hls
        ),
        CRMVideoSource(
            id: "src_720",
            url: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8",
            quality: .hd720,
            format: .hls
        ),
        CRMVideoSource(
            id: "src_1080",
            url: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8",
            quality: .hd1080,
            format: .hls
        ),
    ]

    static var spidermanVideoSources: [CRMVideoSource] {
        [
            CRMVideoSource(
                id: "sm_480",
                url: CRMReferenceRemoteResource.videoURL("video_h264_480p.mp4"),
                quality: .sd480,
                format: .mp4
            ),
            CRMVideoSource(
                id: "sm_720",
                url: CRMReferenceRemoteResource.videoURL("video_h264_720p.mp4"),
                quality: .hd720,
                format: .mp4
            ),
            CRMVideoSource(
                id: "sm_1080",
                url: CRMReferenceRemoteResource.videoURL("video_h264_1080p.mp4"),
                quality: .hd1080,
                format: .mp4
            ),
            CRMVideoSource(
                id: "sm_4k",
                url: CRMReferenceRemoteResource.videoURL("video_h246_4K.mp4"),
                quality: .uhd4k,
                format: .mp4
            ),
        ]
    }

    static var spidermanSubtitles: [CRMSubtitle] {
        [
            CRMSubtitle(
                id: "sm_sub_off",
                language: "off",
                displayName: "Off",
                url: nil,
                isEmbedded: false
            ),
            CRMSubtitle(
                id: "sm_sub_en",
                language: "en-US",
                displayName: "English (VTT)",
                url: CRMReferenceRemoteResource.subtitleURL("subs_en.vtt"),
                isEmbedded: false
            ),
            CRMSubtitle(
                id: "sm_sub_en_srt",
                language: "en-US",
                displayName: "English (SRT)",
                url: CRMReferenceRemoteResource.subtitleURL("subs_en.srt"),
                isEmbedded: false
            ),
            CRMSubtitle(
                id: "sm_sub_jp",
                language: "ja-JP",
                displayName: "日本語 (VTT)",
                url: CRMReferenceRemoteResource.subtitleURL("subs_jp.vtt"),
                isEmbedded: false
            ),
            CRMSubtitle(
                id: "sm_sub_jp_srt",
                language: "ja-JP",
                displayName: "日本語 (SRT)",
                url: CRMReferenceRemoteResource.subtitleURL("subs_jp.srt"),
                isEmbedded: false
            ),
        ]
    }

    static var spidermanAudioTracks: [CRMAudioTrack] {
        [
            CRMAudioTrack(
                id: "sm_audio_en",
                language: "en-US",
                displayName: "English (M4A)",
                url: CRMReferenceRemoteResource.audioURL("audio_en.m4a"),
                isDefault: true
            ),
            CRMAudioTrack(
                id: "sm_audio_en_webm",
                language: "en-US",
                displayName: "English (WEBM)",
                url: CRMReferenceRemoteResource.audioURL("audio_en.webm"),
                isDefault: false
            ),
            CRMAudioTrack(
                id: "sm_audio_jp",
                language: "ja-JP",
                displayName: "日本語 (M4A)",
                url: CRMReferenceRemoteResource.audioURL("audio_jp.m4a"),
                isDefault: false
            ),
        ]
    }

    static let subtitles: [CRMSubtitle] = [
        CRMSubtitle(id: "sub_zh", language: "zh-CN", displayName: "Chinese", url: nil, isEmbedded: true),
        CRMSubtitle(id: "sub_en", language: "en-US", displayName: "English", url: nil, isEmbedded: true),
        CRMSubtitle(id: "sub_off", language: "off", displayName: "Off", url: nil, isEmbedded: false),
    ]

    static let audioTracks: [CRMAudioTrack] = [
        CRMAudioTrack(id: "audio_zh", language: "zh-CN", displayName: "Mandarin", url: nil, isDefault: true),
        CRMAudioTrack(id: "audio_yue", language: "zh-HK", displayName: "Cantonese", url: nil, isDefault: false),
        CRMAudioTrack(id: "audio_en", language: "en-US", displayName: "English", url: nil, isDefault: false),
    ]

    static func generateEpisodes(count: Int) -> [CRMEpisode] {
        (1...count).map { index in
            CRMEpisode(
                id: "ep_\(index)",
                episodeNumber: index,
                title: "Episode \(index)",
                duration: 2400 + index * 120,
                thumbnail: "",
                videoSources: videoSources,
                subtitles: subtitles,
                audioTracks: audioTracks
            )
        }
    }

    static var spidermanEpisode: CRMEpisode {
        CRMEpisode(
            id: "sm_ep_1",
            episodeNumber: 1,
            title: "Full Movie",
            duration: 8400,
            thumbnail: CRMReferenceRemoteResource.spidermanCoverURL,
            videoSources: spidermanVideoSources,
            subtitles: spidermanSubtitles,
            audioTracks: spidermanAudioTracks
        )
    }

    static var mediaList: [CRMMedia] {
        [
            CRMMedia(
                id: "spiderman_2026",
                title: "SPIDER-MAN: BRAND NEW DAY",
                cover: CRMReferenceRemoteResource.spidermanCoverURL,
                description: "Peter Parker tries to focus on college and leave Spider-Man behind. But when a new threat endangers his friends, he must break his promise and suit up again, teaming with an unexpected ally to protect those he loves.",
                type: .movie,
                views: 89_234_567,
                publishDate: createDate(year: 2026, month: 7, day: 31),
                duration: 8400,
                rating: 9.1,
                tags: ["Action", "Superhero", "Marvel", "Sci-Fi"],
                actors: spidermanActors,
                episodes: [spidermanEpisode],
                relatedMediaIds: ["batman_begins", "dark_knight", "dark_knight_rises"]
            ),
            CRMMedia(
                id: "batman_begins",
                title: "Batman Begins",
                cover: "https://image.tmdb.org/t/p/w500/8RW2runSEc34IwKN2D1aPcJd2UL.jpg",
                description: "Driven by tragedy, billionaire Bruce Wayne dedicates his life to uncovering and defeating the corruption that plagues his home, Gotham City. Unable to work within the system, he instead creates a new identity, a symbol of fear for the criminal underworld - The Batman.",
                type: .movie,
                views: 45_678_901,
                publishDate: createDate(year: 2005, month: 6, day: 15),
                duration: 8400,
                rating: 8.2,
                tags: ["Action", "Superhero", "DC", "Crime"],
                actors: darkKnightActors,
                episodes: [
                    CRMEpisode(
                        id: "bb_ep_1",
                        episodeNumber: 1,
                        title: "Full Movie",
                        duration: 8400,
                        thumbnail: "",
                        videoSources: videoSources,
                        subtitles: subtitles,
                        audioTracks: audioTracks
                    ),
                ],
                relatedMediaIds: ["dark_knight", "dark_knight_rises", "spiderman_2026"]
            ),
            CRMMedia(
                id: "dark_knight",
                title: "The Dark Knight",
                cover: "https://image.tmdb.org/t/p/w500/qJ2tW6WMUDux911r6m7haRef0WH.jpg",
                description: "Batman raises the stakes in his war on crime. With the help of Lt. Jim Gordon and District Attorney Harvey Dent, Batman sets out to dismantle the remaining criminal organizations that plague the streets.",
                type: .movie,
                views: 123_456_789,
                publishDate: createDate(year: 2008, month: 7, day: 18),
                duration: 9120,
                rating: 9.0,
                tags: ["Action", "Superhero", "DC", "Crime", "Thriller"],
                actors: darkKnightActors,
                episodes: [
                    CRMEpisode(
                        id: "dk_ep_1",
                        episodeNumber: 1,
                        title: "Full Movie",
                        duration: 9120,
                        thumbnail: "",
                        videoSources: videoSources,
                        subtitles: subtitles,
                        audioTracks: audioTracks
                    ),
                ],
                relatedMediaIds: ["batman_begins", "dark_knight_rises", "spiderman_2026"]
            ),
            CRMMedia(
                id: "dark_knight_rises",
                title: "The Dark Knight Rises",
                cover: "https://image.tmdb.org/t/p/w500/hr0L2aueqlP2BYUblTTjmtn0hw4.jpg",
                description: "Following the death of District Attorney Harvey Dent, Batman assumes responsibility for Dent's crimes to protect the late attorney's reputation and is subsequently hunted by the Gotham City Police Department.",
                type: .movie,
                views: 98_765_432,
                publishDate: createDate(year: 2012, month: 7, day: 20),
                duration: 9900,
                rating: 8.4,
                tags: ["Action", "Superhero", "DC", "Thriller"],
                actors: darkKnightActors,
                episodes: [
                    CRMEpisode(
                        id: "dkr_ep_1",
                        episodeNumber: 1,
                        title: "Full Movie",
                        duration: 9900,
                        thumbnail: "",
                        videoSources: videoSources,
                        subtitles: subtitles,
                        audioTracks: audioTracks
                    ),
                ],
                relatedMediaIds: ["batman_begins", "dark_knight", "spiderman_2026"]
            ),
            CRMMedia(
                id: "media_2",
                title: "Popular TV Series",
                cover: "https://picsum.photos/300/450?random=2",
                description: "The most popular TV series of the year, with 24 episodes. It tells the story of young urban professionals striving for success, with twists and turns that keep viewers engaged.",
                type: .tvSeries,
                views: 98_765_432,
                publishDate: Date().addingTimeInterval(-86400 * 7),
                duration: 24 * 2700,
                rating: 9.2,
                tags: ["Urban", "Romance", "Inspirational"],
                actors: actors,
                episodes: generateEpisodes(count: 24),
                relatedMediaIds: ["spiderman_2026", "media_4"]
            ),
            CRMMedia(
                id: "media_3",
                title: "Documentary: Natural Wonders",
                cover: "https://picsum.photos/300/450?random=3",
                description: "Explore the most spectacular natural landscapes on Earth, from deep seas to mountains, from tropical rainforests to polar glaciers, and discover the magic of nature.",
                type: .documentary,
                views: 567_890,
                publishDate: Date().addingTimeInterval(-86400 * 60),
                duration: 6 * 3600,
                rating: 9.5,
                tags: ["Nature", "Documentary", "Scenery"],
                actors: [],
                episodes: generateEpisodes(count: 6),
                relatedMediaIds: ["media_5"]
            ),
            CRMMedia(
                id: "media_4",
                title: "Variety Show: Fun Stage",
                cover: "https://picsum.photos/300/450?random=4",
                description: "A weekly variety show featuring celebrity guests, bringing laughter and heartwarming moments.",
                type: .variety,
                views: 45_678_901,
                publishDate: Date().addingTimeInterval(-86400 * 1),
                duration: 12 * 5400,
                rating: 8.8,
                tags: ["Variety", "Comedy", "Celebrity"],
                actors: Array(actors.prefix(2)),
                episodes: generateEpisodes(count: 12),
                relatedMediaIds: ["media_2"]
            ),
            CRMMedia(
                id: "media_5",
                title: "Sci-Fi Blockbuster",
                cover: "https://picsum.photos/300/450?random=5",
                description: "In a future world, humanity faces an unprecedented crisis. A group of brave heroes steps up to save the world.",
                type: .movie,
                views: 23_456_789,
                publishDate: Date().addingTimeInterval(-86400 * 14),
                duration: 8400,
                rating: 8.9,
                tags: ["Sci-Fi", "Action", "VFX"],
                actors: actors,
                episodes: [
                    CRMEpisode(
                        id: "ep_movie_5",
                        episodeNumber: 1,
                        title: "Full Movie",
                        duration: 8400,
                        thumbnail: "",
                        videoSources: videoSources,
                        subtitles: subtitles,
                        audioTracks: audioTracks
                    ),
                ],
                relatedMediaIds: ["spiderman_2026", "dark_knight"]
            ),
        ]
    }

    private static func createDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components) ?? Date()
    }
}
