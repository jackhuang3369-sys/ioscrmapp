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

enum VideoServiceError: Error {
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
        "Skyline Ops",
        "Pearl Heist",
        "Night Bazaar",
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

        remoteHistory = [trimmedKeyword] + remoteHistory.filter { $0.caseInsensitiveCompare(trimmedKeyword) != .orderedSame }
        remoteHistory = Array(remoteHistory.prefix(VideoPaginationDefaults.historyLimit))

        let normalizedKeyword = normalizedMockQuery(trimmedKeyword)
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

        if detail.cast.contains(where: { normalizedMockQuery($0.name).contains(query) }) {
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
        // 后端视频域还未联调完成前，远端环境默认回退占位页。
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
        let sortedQualities = [VideoQuality.auto, .hd1080, .hd720, .sd480]
        let availableSources = sortedQualities.compactMap { quality -> VideoSource? in
            guard quality != .auto else {
                return VideoSource(
                    id: "\(episode.id)-auto",
                    url: sampleStreamURL,
                    quality: .auto,
                    format: .hls
                )
            }

            return VideoSource(
                id: "\(episode.id)-\(quality.rawValue)",
                url: sampleStreamURL,
                quality: quality,
                format: .hls
            )
        }

        let orderedSources = availableSources.sorted {
            if let preferredQuality {
                if $0.quality == preferredQuality { return true }
                if $1.quality == preferredQuality { return false }
            }
            return $0.quality.sortOrder < $1.quality.sortOrder
        }

        let subtitles = [
            VideoSubtitleTrack(
                id: "subtitle-off",
                languageCode: "off",
                displayName: VideoLocalizedString("关闭字幕", "Subtitles Off", "إيقاف الترجمة"),
                url: nil,
                isEmbedded: true
            ),
            VideoSubtitleTrack(
                id: "subtitle-en",
                languageCode: "en",
                displayName: VideoLocalizedString("英文", "English", "الإنجليزية"),
                url: nil,
                isEmbedded: true
            ),
            VideoSubtitleTrack(
                id: "subtitle-zh",
                languageCode: "zh-Hans",
                displayName: VideoLocalizedString("简体中文", "Simplified Chinese", "الصينية المبسطة"),
                url: nil,
                isEmbedded: true
            ),
            VideoSubtitleTrack(
                id: "subtitle-ar",
                languageCode: "ar",
                displayName: VideoLocalizedString("阿拉伯语", "Arabic", "العربية"),
                url: nil,
                isEmbedded: true
            ),
        ]

        let audioTracks = [
            VideoAudioTrack(
                id: "audio-en",
                languageCode: "en",
                displayName: VideoLocalizedString("英语", "English", "الإنجليزية"),
                url: nil,
                isDefault: true
            ),
            VideoAudioTrack(
                id: "audio-ar",
                languageCode: "ar",
                displayName: VideoLocalizedString("阿拉伯语", "Arabic", "العربية"),
                url: nil,
                isDefault: false
            ),
        ]

        return VideoPlaybackSession(
            playSessionID: "play-\(episode.id)-\(UUID().uuidString)",
            expiresAt: Date().addingTimeInterval(30 * 60),
            mediaID: detail.content.id,
            mediaTitle: detail.content.title,
            episode: episode,
            videoSources: orderedSources,
            subtitles: subtitles,
            audioTracks: audioTracks,
            pipEnabled: true
        )
    }

    private var sampleStreamURL: URL {
        URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8")!
    }
}

private enum VideoMockCatalog {
    static func make() -> VideoCatalog {
        let categories = [
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

        let desertSignal = makeContent(
            id: "desert-signal",
            categoryID: "movie",
            type: .movie,
            title: VideoLocalizedString("沙海信号", "Desert Signal", "إشارة الصحراء"),
            subtitle: VideoLocalizedString("风暴来临前的最后一条直播", "One last live stream before the storm", "آخر بث مباشر قبل العاصفة"),
            summary: VideoLocalizedString("一支应急主播小队在沙漠边境追查断网事件。", "A rescue streamer squad traces a blackout across the desert border.", "يتتبع فريق بث طوارئ انقطاع الشبكة على أطراف الصحراء."),
            posterURL: "https://picsum.photos/id/1011/720/1080",
            backdropURL: "https://picsum.photos/id/1015/1280/720",
            badge: VideoLocalizedString("热映", "Hot Drop", "الأكثر مشاهدة"),
            chips: [
                VideoLocalizedString("动作", "Action", "أكشن"),
                VideoLocalizedString("悬疑", "Mystery", "غموض"),
            ],
            ratingText: "8.9",
            metaLine: VideoLocalizedString("2026 | 电影 | 杜拜出品", "2026 | Movie | DU Original", "2026 | فيلم | إنتاج DU"),
            durationText: VideoLocalizedString("1小时58分钟", "1h 58m", "1 س 58 د"),
            availabilityStatus: .playable,
            availabilityMessage: nil
        )

        let pearlHeist = makeContent(
            id: "pearl-heist",
            categoryID: "movie",
            type: .movie,
            title: VideoLocalizedString("珍珠城局中局", "Pearl Heist", "سرقة اللؤلؤ"),
            subtitle: VideoLocalizedString("失窃的展品与被篡改的时间线", "A stolen exhibit and a broken timeline", "معروض مسروق وخط زمني مضطرب"),
            summary: VideoLocalizedString("一位展馆策展人与调查记者联手复原真相。", "A curator and an investigative reporter rebuild the truth together.", "يعيد أمين معرض وصحفي استقصائي تركيب الحقيقة معًا."),
            posterURL: "https://picsum.photos/id/1025/720/1080",
            backdropURL: "https://picsum.photos/id/1035/1280/720",
            badge: VideoLocalizedString("编辑精选", "Editors' Pick", "اختيار المحررين"),
            chips: [
                VideoLocalizedString("犯罪", "Crime", "جريمة"),
                VideoLocalizedString("剧情", "Drama", "دراما"),
            ],
            ratingText: "8.5",
            metaLine: VideoLocalizedString("2025 | 电影 | 双语", "2025 | Movie | Bilingual", "2025 | فيلم | ثنائي اللغة"),
            durationText: VideoLocalizedString("2小时06分钟", "2h 06m", "2 س 06 د"),
            availabilityStatus: .playable,
            availabilityMessage: nil
        )

        let moonlitRelay = makeContent(
            id: "moonlit-relay",
            categoryID: "movie",
            type: .movie,
            title: VideoLocalizedString("月夜接力", "Moonlit Relay", "سباق ضوء القمر"),
            subtitle: VideoLocalizedString("一场穿越旧城区的夜跑转播", "A night relay across the old district", "سباق ليلي عبر الحي القديم"),
            summary: VideoLocalizedString("四名陌生人在一次公益夜跑中互相照亮。", "Four strangers cross paths during a charity night relay.", "يلتقي أربعة غرباء خلال سباق ليلي خيري."),
            posterURL: "https://picsum.photos/id/1040/720/1080",
            backdropURL: "https://picsum.photos/id/1043/1280/720",
            badge: VideoLocalizedString("新上线", "New", "جديد"),
            chips: [
                VideoLocalizedString("治愈", "Feel-good", "ملهم"),
                VideoLocalizedString("城市", "City", "مدينة"),
            ],
            ratingText: "8.1",
            metaLine: VideoLocalizedString("2026 | 电影 | 口碑榜", "2026 | Movie | Critics Rising", "2026 | فيلم | موصى به"),
            durationText: VideoLocalizedString("1小时42分钟", "1h 42m", "1 س 42 د"),
            availabilityStatus: .playable,
            availabilityMessage: nil
        )

        let skylineOps = makeContent(
            id: "skyline-ops",
            categoryID: "series",
            type: .series,
            title: VideoLocalizedString("天际线任务组", "Skyline Ops", "فرقة الأفق"),
            subtitle: VideoLocalizedString("高楼之间的即时救援任务", "High-rise response in real time", "استجابات فورية بين الأبراج"),
            summary: VideoLocalizedString("一支城市应急小队在直播镜头下处理突发事件。", "An urban response unit handles emergencies under live cameras.", "تتعامل وحدة طوارئ حضرية مع الأزمات تحت عدسات البث المباشر."),
            posterURL: "https://picsum.photos/id/1049/720/1080",
            backdropURL: "https://picsum.photos/id/1050/1280/720",
            badge: VideoLocalizedString("全网热播", "Trending", "الأكثر رواجًا"),
            chips: [
                VideoLocalizedString("剧集", "Series", "مسلسل"),
                VideoLocalizedString("都市", "Urban", "حضري"),
            ],
            ratingText: "9.2",
            metaLine: VideoLocalizedString("第1季 | 共6集 | 每周更新", "Season 1 | 6 eps | Weekly", "الموسم 1 | 6 حلقات | أسبوعي"),
            durationText: VideoLocalizedString("每集45分钟", "45m / episode", "45 د / الحلقة"),
            availabilityStatus: .playable,
            availabilityMessage: nil
        )

        let desertDiary = makeContent(
            id: "desert-diary",
            categoryID: "series",
            type: .series,
            title: VideoLocalizedString("沙丘日记", "Desert Diary", "مذكرات الكثبان"),
            subtitle: VideoLocalizedString("驻站记者的第一手城市观察", "A resident reporter's city notes", "ملاحظات مراسل مقيم عن المدينة"),
            summary: VideoLocalizedString("从清晨批发市场到深夜海边，一位记者记录城市的温度。", "From sunrise markets to midnight coasts, a reporter records the city's pulse.", "من أسواق الفجر إلى شواطئ منتصف الليل، يوثق مراسل نبض المدينة."),
            posterURL: "https://picsum.photos/id/1067/720/1080",
            backdropURL: "https://picsum.photos/id/1068/1280/720",
            badge: VideoLocalizedString("独播", "Exclusive", "حصري"),
            chips: [
                VideoLocalizedString("纪实", "Docu-drama", "دراما وثائقية"),
                VideoLocalizedString("人物", "People", "شخصيات"),
            ],
            ratingText: "8.7",
            metaLine: VideoLocalizedString("第1季 | 共4集 | 已完结", "Season 1 | 4 eps | Complete", "الموسم 1 | 4 حلقات | مكتمل"),
            durationText: VideoLocalizedString("每集38分钟", "38m / episode", "38 د / الحلقة"),
            availabilityStatus: .playable,
            availabilityMessage: nil
        )

        let codeRift = makeContent(
            id: "code-rift",
            categoryID: "series",
            type: .series,
            title: VideoLocalizedString("代码裂缝", "Code Rift", "صدع الشفرة"),
            subtitle: VideoLocalizedString("当城市运行逻辑突然错位", "When the city logic slips", "عندما ينزاح منطق المدينة"),
            summary: VideoLocalizedString("黑客追踪一场影响全城的大规模系统异常。", "A hacker traces a citywide systems failure.", "يلاحق مخترق فشلًا تقنيًا واسع النطاق في المدينة."),
            posterURL: "https://picsum.photos/id/1074/720/1080",
            backdropURL: "https://picsum.photos/id/1077/1280/720",
            badge: VideoLocalizedString("待修复", "Pending Source", "بانتظار المصدر"),
            chips: [
                VideoLocalizedString("科幻", "Sci-Fi", "خيال علمي"),
                VideoLocalizedString("悬疑", "Mystery", "غموض"),
            ],
            ratingText: "8.3",
            metaLine: VideoLocalizedString("第1季 | 共8集 | 暂无片源", "Season 1 | 8 eps | Source pending", "الموسم 1 | 8 حلقات | المصدر غير متاح"),
            durationText: VideoLocalizedString("每集42分钟", "42m / episode", "42 د / الحلقة"),
            availabilityStatus: .sourceUnavailable,
            availabilityMessage: VideoLocalizedString("暂无可播放源", "No playable source yet", "لا يوجد مصدر تشغيل متاح")
        )

        let nightBazaar = makeContent(
            id: "night-bazaar",
            categoryID: "variety",
            type: .variety,
            title: VideoLocalizedString("夜市开麦啦", "Night Bazaar", "ليلة السوق"),
            subtitle: VideoLocalizedString("现场即兴与街头挑战同台", "Street challenges meet live comedy", "تحديات الشارع والكوميديا المباشرة"),
            summary: VideoLocalizedString("主持人与嘉宾在夜市中完成即兴任务。", "Hosts and guests take on spontaneous night-market missions.", "يخوض المقدمون والضيوف مهام مرتجلة داخل السوق الليلي."),
            posterURL: "https://picsum.photos/id/1080/720/1080",
            backdropURL: "https://picsum.photos/id/1084/1280/720",
            badge: VideoLocalizedString("今晚更新", "Tonight", "يُحدَّث الليلة"),
            chips: [
                VideoLocalizedString("综艺", "Variety", "منوعات"),
                VideoLocalizedString("搞笑", "Comedy", "كوميديا"),
            ],
            ratingText: "8.8",
            metaLine: VideoLocalizedString("第2季 | 共10期 | 每周五", "Season 2 | 10 eps | Fridays", "الموسم 2 | 10 حلقات | الجمعة"),
            durationText: VideoLocalizedString("每期52分钟", "52m / episode", "52 د / الحلقة"),
            availabilityStatus: .playable,
            availabilityMessage: nil
        )

        let rooftopMix = makeContent(
            id: "rooftop-mix",
            categoryID: "variety",
            type: .variety,
            title: VideoLocalizedString("天台混音局", "Rooftop Mix", "مزيج السطح"),
            subtitle: VideoLocalizedString("音乐人用城市采样重做热歌", "City samples remixed into live sets", "عينات المدينة تتحول إلى عروض موسيقية"),
            summary: VideoLocalizedString("音乐制作人和舞者在天台完成实时创作。", "Producers and dancers build tracks live above the skyline.", "يصنع المنتجون والراقصون مقاطع مباشرة فوق الأفق."),
            posterURL: "https://picsum.photos/id/1081/720/1080",
            backdropURL: "https://picsum.photos/id/1082/1280/720",
            badge: VideoLocalizedString("舞台首发", "Stage First", "عرض أول"),
            chips: [
                VideoLocalizedString("音乐", "Music", "موسيقى"),
                VideoLocalizedString("Live", "Live", "مباشر"),
            ],
            ratingText: "8.4",
            metaLine: VideoLocalizedString("特别篇 | 3场现场录制", "Special | 3 live cuts", "حلقة خاصة | 3 عروض"),
            durationText: VideoLocalizedString("1小时12分钟", "1h 12m", "1 س 12 د"),
            availabilityStatus: .playable,
            availabilityMessage: nil
        )

        let makerBattle = makeContent(
            id: "maker-battle",
            categoryID: "variety",
            type: .variety,
            title: VideoLocalizedString("创客对决", "Maker Battle", "تحدي المبدعين"),
            subtitle: VideoLocalizedString("48小时快闪改造赛", "A 48-hour build sprint", "سباق بناء خلال 48 ساعة"),
            summary: VideoLocalizedString("三组创客在限定时间内完成城市微装置。", "Three teams race to build city-ready installations in 48 hours.", "تتسابق ثلاث فرق لإنجاز تركيبات حضرية خلال 48 ساعة."),
            posterURL: "https://picsum.photos/id/1083/720/1080",
            backdropURL: "https://picsum.photos/id/1085/1280/720",
            badge: VideoLocalizedString("热议", "Buzzing", "الأكثر نقاشًا"),
            chips: [
                VideoLocalizedString("科技", "Tech", "تقنية"),
                VideoLocalizedString("竞技", "Competition", "منافسة"),
            ],
            ratingText: "8.0",
            metaLine: VideoLocalizedString("第1季 | 共8期 | 已更新至第5期", "Season 1 | 8 eps | Through Ep 5", "الموسم 1 | 8 حلقات | حتى الحلقة 5"),
            durationText: VideoLocalizedString("每期46分钟", "46m / episode", "46 د / الحلقة"),
            availabilityStatus: .playable,
            availabilityMessage: nil
        )

        let deepBlueDesert = makeContent(
            id: "deep-blue-desert",
            categoryID: "documentary",
            type: .documentary,
            title: VideoLocalizedString("深蓝沙洲", "Deep Blue Desert", "الصحراء الزرقاء"),
            subtitle: VideoLocalizedString("海岸、珊瑚与沙丘的共生", "Where dunes meet coral reefs", "حيث تلتقي الكثبان بالشعاب المرجانية"),
            summary: VideoLocalizedString("跟随海洋研究员探索近海生态修复项目。", "Follow marine researchers through coastal restoration work.", "تابع الباحثين البحريين خلال أعمال ترميم الساحل."),
            posterURL: "https://picsum.photos/id/109/720/1080",
            backdropURL: "https://picsum.photos/id/110/1280/720",
            badge: VideoLocalizedString("高分纪录", "Top Rated", "أعلى تقييمًا"),
            chips: [
                VideoLocalizedString("自然", "Nature", "طبيعة"),
                VideoLocalizedString("海洋", "Ocean", "بحر"),
            ],
            ratingText: "9.1",
            metaLine: VideoLocalizedString("纪录片 | 4K 修复", "Documentary | 4K restoration", "وثائقي | 4K"),
            durationText: VideoLocalizedString("58分钟", "58m", "58 د"),
            availabilityStatus: .playable,
            availabilityMessage: nil
        )

        let cityOfWind = makeContent(
            id: "city-of-wind",
            categoryID: "documentary",
            type: .documentary,
            title: VideoLocalizedString("风之城晨报", "City of Wind", "مدينة الريح"),
            subtitle: VideoLocalizedString("一座港口城市的清晨节奏", "Morning rhythms of a port city", "إيقاع الصباح في مدينة الميناء"),
            summary: VideoLocalizedString("纪录团队重访老港的劳动者与市场。", "A film crew revisits workers and markets around the old harbor.", "يعيد فريق تصوير زيارة العمال والأسواق في الميناء القديم."),
            posterURL: "https://picsum.photos/id/111/720/1080",
            backdropURL: "https://picsum.photos/id/112/1280/720",
            badge: VideoLocalizedString("暂时下架", "Removed", "تمت الإزالة"),
            chips: [
                VideoLocalizedString("人文", "Humanity", "إنساني"),
                VideoLocalizedString("港口", "Harbor", "ميناء"),
            ],
            ratingText: "8.2",
            metaLine: VideoLocalizedString("纪录片 | 暂不可播", "Documentary | Temporarily removed", "وثائقي | تمت إزالته مؤقتًا"),
            durationText: VideoLocalizedString("49分钟", "49m", "49 د"),
            availabilityStatus: .removed,
            availabilityMessage: VideoLocalizedString("内容已下架", "This title has been removed", "تمت إزالة هذا المحتوى")
        )

        let oasisKeepers = makeContent(
            id: "oasis-keepers",
            categoryID: "documentary",
            type: .documentary,
            title: VideoLocalizedString("绿洲守望者", "Oasis Keepers", "حراس الواحة"),
            subtitle: VideoLocalizedString("看见城市绿化背后的维护者", "The teams behind urban green belts", "الفرق التي تحافظ على الأحزمة الخضراء"),
            summary: VideoLocalizedString("跟拍夜间养护团队，记录城市绿洲的维护过程。", "Shadow the overnight crews maintaining the city's green corridors.", "رافق فرق الصيانة الليلية التي تحافظ على ممرات المدينة الخضراء."),
            posterURL: "https://picsum.photos/id/113/720/1080",
            backdropURL: "https://picsum.photos/id/114/1280/720",
            badge: VideoLocalizedString("首周口碑", "Fresh Release", "إصدار جديد"),
            chips: [
                VideoLocalizedString("环保", "Sustainability", "استدامة"),
                VideoLocalizedString("人物", "People", "شخصيات"),
            ],
            ratingText: "8.6",
            metaLine: VideoLocalizedString("纪录片 | 人物故事", "Documentary | Human stories", "وثائقي | قصص إنسانية"),
            durationText: VideoLocalizedString("52分钟", "52m", "52 د"),
            availabilityStatus: .playable,
            availabilityMessage: nil
        )

        let details: [String: VideoDetailSnapshot] = [
            desertSignal.id: makeDetail(
                content: desertSignal,
                synopsis: VideoLocalizedString("当一场异常沙暴切断边境通讯，一支临时组成的直播应急小队必须在六小时内完成追踪、撤离与真相还原。", "When a sandstorm cuts the border feed, a live-response squad has six hours to trace the outage, evacuate civilians, and expose the signal hijack.", "عندما تقطع عاصفة رملية الاتصال على الحدود، أمام فرقة بث طارئة ست ساعات فقط لتتبع الانقطاع وإجلاء المدنيين وكشف الاختراق."),
                stats: makeStats(views: "12.6M", released: "2026-03-18", episodes: "1", duration: "118m"),
                tags: makeTags([
                    ("紧张", "Tense", "متوتر"),
                    ("边境", "Border", "حدود"),
                    ("直播", "Live feed", "بث مباشر"),
                ]),
                episodeGroups: [singleEpisodeGroup(content: desertSignal)],
                defaultEpisodeID: nil,
                cast: makeCast([
                    ("cast-ari", "Ari Nasser", VideoLocalizedString("队长", "Team lead", "قائد الفريق")),
                    ("cast-lina", "Lina Zhou", VideoLocalizedString("调查记者", "Reporter", "صحفية")),
                    ("cast-omar", "Omar Haleem", VideoLocalizedString("飞手", "Drone pilot", "طيار درون")),
                ]),
                related: [skylineOps, pearlHeist, deepBlueDesert]
            ),
            pearlHeist.id: makeDetail(
                content: pearlHeist,
                synopsis: VideoLocalizedString("一件即将揭幕的海湾珍珠展品突然失窃，策展人与记者追查中牵出一段被剪辑过的监控时间线。", "A signature Gulf pearl disappears hours before a launch, pulling a curator and reporter into a timeline stitched from edited security footage.", "تختفي لؤلؤة خليجية نادرة قبل ساعات من الافتتاح، فيطارد أمين المعرض والصحفية خطًا زمنيًا تم التلاعب به."),
                stats: makeStats(views: "9.3M", released: "2025-12-05", episodes: "1", duration: "126m"),
                tags: makeTags([
                    ("谜案", "Heist", "سرقة"),
                    ("记者", "Reporter", "صحفي"),
                    ("展馆", "Museum", "متحف"),
                ]),
                episodeGroups: [singleEpisodeGroup(content: pearlHeist)],
                defaultEpisodeID: nil,
                cast: makeCast([
                    ("cast-samia", "Samia Noor", VideoLocalizedString("策展人", "Curator", "أمينة المعرض")),
                    ("cast-ryan", "Ryan Costa", VideoLocalizedString("调查记者", "Journalist", "صحفي استقصائي")),
                    ("cast-farid", "Farid Saif", VideoLocalizedString("安保主管", "Security lead", "رئيس الأمن")),
                ]),
                related: [moonlitRelay, desertSignal, cityOfWind]
            ),
            moonlitRelay.id: makeDetail(
                content: moonlitRelay,
                synopsis: VideoLocalizedString("四条原本不会相交的夜跑路线，因为一场突如其来的慈善接力而串在一起。", "Four unrelated routes weave together through a late-night charity relay.", "تتشابك أربعة مسارات مختلفة خلال سباق خيري ليلي مفاجئ."),
                stats: makeStats(views: "6.1M", released: "2026-02-02", episodes: "1", duration: "102m"),
                tags: makeTags([
                    ("夜跑", "Night run", "سباق ليلي"),
                    ("友情", "Friendship", "صداقة"),
                    ("城市", "City", "مدينة"),
                ]),
                episodeGroups: [singleEpisodeGroup(content: moonlitRelay)],
                defaultEpisodeID: nil,
                cast: makeCast([
                    ("cast-huda", "Huda Malik", VideoLocalizedString("志愿者", "Volunteer", "متطوعة")),
                    ("cast-jay", "Jay Kim", VideoLocalizedString("摄影师", "Cinematographer", "مصور")),
                ]),
                related: [desertSignal, oasisKeepers, nightBazaar]
            ),
            skylineOps.id: makeDetail(
                content: skylineOps,
                synopsis: VideoLocalizedString("高空维修、电梯救援、夜间巡楼，直播镜头记录一支城市应急小队的每次出动。", "Live cameras follow an urban response squad through tower rescues, elevator lock-ins, and after-dark emergencies.", "تتابع الكاميرات المباشرة فرقة طوارئ حضرية خلال عمليات الإنقاذ في الأبراج والمصاعد."),
                stats: makeStats(views: "18.2M", released: "2026-03-01", episodes: "6", duration: "45m"),
                tags: makeTags([
                    ("高楼", "High-rise", "أبراج"),
                    ("应急", "Emergency", "طوارئ"),
                    ("团队", "Team", "فريق"),
                ]),
                episodeGroups: [
                    makeEpisodeGroup(
                        id: "skyline-ops-s1",
                        title: VideoLocalizedString("第 1 季", "Season 1", "الموسم 1"),
                        cover: skylineOps.posterImage,
                        episodeCount: 6
                    ),
                ],
                defaultEpisodeID: "skyline-ops-s1-ep1",
                cast: makeCast([
                    ("cast-ana", "Ana Haddad", VideoLocalizedString("总调度", "Dispatcher", "منسقة")),
                    ("cast-yusuf", "Yusuf Karim", VideoLocalizedString("救援员", "Responder", "منقذ")),
                    ("cast-mika", "Mika Chen", VideoLocalizedString("机械师", "Mechanic", "فني")),
                ]),
                related: [desertSignal, codeRift, deepBlueDesert]
            ),
            desertDiary.id: makeDetail(
                content: desertDiary,
                synopsis: VideoLocalizedString("一位驻站记者带着镜头穿梭在清晨市场、午后老街与午夜海岸，写下城市的细碎温度。", "A resident reporter moves from dawn markets to midnight coasts, tracing the city's quieter pulse.", "يتنقل مراسل مقيم من أسواق الفجر إلى الشواطئ الليلية ليلتقط نبض المدينة الهادئ."),
                stats: makeStats(views: "7.8M", released: "2025-11-20", episodes: "4", duration: "38m"),
                tags: makeTags([
                    ("纪实", "Docu", "وثائقي"),
                    ("城市", "City", "مدينة"),
                    ("采访", "Interview", "مقابلة"),
                ]),
                episodeGroups: [
                    makeEpisodeGroup(
                        id: "desert-diary-s1",
                        title: VideoLocalizedString("第一章", "Chapter One", "الفصل الأول"),
                        cover: desertDiary.posterImage,
                        episodeCount: 4
                    ),
                ],
                defaultEpisodeID: "desert-diary-s1-ep1",
                cast: makeCast([
                    ("cast-layan", "Layan Saad", VideoLocalizedString("驻站记者", "Resident reporter", "مراسلة مقيمة")),
                    ("cast-sami", "Sami Noor", VideoLocalizedString("摄影", "Camera", "تصوير")),
                ]),
                related: [oasisKeepers, cityOfWind, moonlitRelay]
            ),
            codeRift.id: makeDetail(
                content: codeRift,
                synopsis: VideoLocalizedString("全城系统时钟同时错位，一名安全工程师必须在直播宕机前找出真正的根因。", "A citywide clock drift knocks critical systems off schedule, and a security engineer races to find the root cause.", "يتسبب انحراف التوقيت في تعطيل أنظمة المدينة، ويجب على مهندس أمن الوصول إلى السبب قبل انهيار البث."),
                stats: makeStats(views: "11.4M", released: "2026-01-14", episodes: "8", duration: "42m"),
                tags: makeTags([
                    ("科幻", "Sci-Fi", "خيال علمي"),
                    ("系统", "Systems", "أنظمة"),
                    ("黑客", "Hackers", "مخترقون"),
                ]),
                episodeGroups: [
                    makeEpisodeGroup(
                        id: "code-rift-s1",
                        title: VideoLocalizedString("第 1 季", "Season 1", "الموسم 1"),
                        cover: codeRift.posterImage,
                        episodeCount: 8,
                        availabilityStatus: .sourceUnavailable,
                        availabilityMessage: codeRift.availabilityMessage
                    ),
                ],
                defaultEpisodeID: "code-rift-s1-ep1",
                cast: makeCast([
                    ("cast-iman", "Iman Saleh", VideoLocalizedString("安全工程师", "Security engineer", "مهندسة أمن")),
                    ("cast-zhou", "Zhou Ren", VideoLocalizedString("系统架构师", "Architect", "مهندس معماري")),
                ]),
                related: [skylineOps, desertSignal, makerBattle]
            ),
            nightBazaar.id: makeDetail(
                content: nightBazaar,
                synopsis: VideoLocalizedString("夜市摊位、隐藏菜单、临场挑战，主持人与嘉宾在热闹人群里完成一场又一场即兴任务。", "Hosts and guests bounce through food stalls, secret menus, and street games in a fast-moving night market.", "يتنقل المقدمون والضيوف بين أكشاك الطعام والقوائم السرية وتحديات الشارع في سوق ليلي نابض."),
                stats: makeStats(views: "15.1M", released: "2026-02-27", episodes: "10", duration: "52m"),
                tags: makeTags([
                    ("夜市", "Night market", "سوق ليلي"),
                    ("游戏", "Games", "ألعاب"),
                    ("旅行", "Travel", "سفر"),
                ]),
                episodeGroups: [
                    makeEpisodeGroup(
                        id: "night-bazaar-s2",
                        title: VideoLocalizedString("第 2 季", "Season 2", "الموسم 2"),
                        cover: nightBazaar.posterImage,
                        episodeCount: 10
                    ),
                ],
                defaultEpisodeID: "night-bazaar-s2-ep1",
                cast: makeCast([
                    ("cast-zayd", "Zayd Rahman", VideoLocalizedString("主持人", "Host", "مقدم")),
                    ("cast-sora", "Sora Lee", VideoLocalizedString("常驻嘉宾", "Guest regular", "ضيفة ثابتة")),
                ]),
                related: [makerBattle, rooftopMix, desertDiary]
            ),
            rooftopMix.id: makeDetail(
                content: rooftopMix,
                synopsis: VideoLocalizedString("城市采样、即兴编曲与高空舞台，一档把城市声音做成现场演出的特别篇。", "City samples, rooftop dancers, and a live set come together for a one-night performance special.", "عينات المدينة والراقصون وعرض حي فوق الأسطح في حلقة موسيقية خاصة."),
                stats: makeStats(views: "5.4M", released: "2026-03-08", episodes: "1", duration: "72m"),
                tags: makeTags([
                    ("音乐", "Music", "موسيقى"),
                    ("舞台", "Stage", "مسرح"),
                    ("现场", "Live", "مباشر"),
                ]),
                episodeGroups: [singleEpisodeGroup(content: rooftopMix)],
                defaultEpisodeID: nil,
                cast: makeCast([
                    ("cast-yara", "Yara Adel", VideoLocalizedString("制作人", "Producer", "منتجة")),
                    ("cast-jin", "Jin Park", VideoLocalizedString("编舞", "Choreographer", "مصمم رقص")),
                ]),
                related: [nightBazaar, makerBattle, moonlitRelay]
            ),
            makerBattle.id: makeDetail(
                content: makerBattle,
                synopsis: VideoLocalizedString("三支创客团队在 48 小时内交付一件可落地的城市装置，并接受公众即时投票。", "Three maker teams have 48 hours to deliver a build-ready city installation under live public voting.", "أمام ثلاث فرق 48 ساعة لتقديم تركيب حضري جاهز للتنفيذ مع تصويت الجمهور المباشر."),
                stats: makeStats(views: "8.0M", released: "2026-03-12", episodes: "8", duration: "46m"),
                tags: makeTags([
                    ("创客", "Makers", "صنّاع"),
                    ("改造", "Build", "بناء"),
                    ("竞技", "Competition", "منافسة"),
                ]),
                episodeGroups: [
                    makeEpisodeGroup(
                        id: "maker-battle-s1",
                        title: VideoLocalizedString("第一轮", "Round One", "الجولة الأولى"),
                        cover: makerBattle.posterImage,
                        episodeCount: 5
                    ),
                ],
                defaultEpisodeID: "maker-battle-s1-ep1",
                cast: makeCast([
                    ("cast-noor", "Noor Abbas", VideoLocalizedString("评审", "Judge", "حكم")),
                    ("cast-luca", "Luca Moretti", VideoLocalizedString("导师", "Mentor", "مرشد")),
                ]),
                related: [nightBazaar, rooftopMix, codeRift]
            ),
            deepBlueDesert.id: makeDetail(
                content: deepBlueDesert,
                synopsis: VideoLocalizedString("从珊瑚修复到海草回种，纪录团队深入近海研究站，记录人与海岸线共同恢复的过程。", "From coral repair to seagrass replanting, the film follows researchers rebuilding a coastline.", "من ترميم المرجان إلى إعادة زراعة الأعشاب البحرية، يتابع الفيلم الباحثين وهم يعيدون إحياء الساحل."),
                stats: makeStats(views: "10.8M", released: "2025-10-30", episodes: "1", duration: "58m"),
                tags: makeTags([
                    ("海洋", "Ocean", "بحر"),
                    ("修复", "Restoration", "ترميم"),
                    ("纪录", "Documentary", "وثائقي"),
                ]),
                episodeGroups: [singleEpisodeGroup(content: deepBlueDesert)],
                defaultEpisodeID: nil,
                cast: makeCast([
                    ("cast-nea", "Nea Salem", VideoLocalizedString("研究员", "Researcher", "باحثة")),
                    ("cast-faris", "Faris Khan", VideoLocalizedString("潜导", "Dive lead", "قائد الغوص")),
                ]),
                related: [oasisKeepers, cityOfWind, desertDiary]
            ),
            cityOfWind.id: makeDetail(
                content: cityOfWind,
                synopsis: VideoLocalizedString("摄制组重返老港口，追踪市场、码头与清晨班次之间的劳动节奏。", "A film crew returns to the old harbor to trace the labor rhythm behind markets, ferries, and dawn shifts.", "يعود فريق التصوير إلى الميناء القديم ليتتبع إيقاع العمل بين الأسواق والعبّارات ونوبات الفجر."),
                stats: makeStats(views: "4.7M", released: "2024-09-12", episodes: "1", duration: "49m"),
                tags: makeTags([
                    ("港口", "Harbor", "ميناء"),
                    ("清晨", "Dawn", "فجر"),
                    ("人物", "People", "شخصيات"),
                ]),
                episodeGroups: [singleEpisodeGroup(content: cityOfWind, availabilityStatus: .removed, availabilityMessage: cityOfWind.availabilityMessage)],
                defaultEpisodeID: nil,
                cast: makeCast([
                    ("cast-issa", "Issa Mourad", VideoLocalizedString("旁白", "Narrator", "راوٍ")),
                ]),
                related: [deepBlueDesert, oasisKeepers, desertDiary]
            ),
            oasisKeepers.id: makeDetail(
                content: oasisKeepers,
                synopsis: VideoLocalizedString("夜深以后，真正照料城市绿洲的人才开始工作。这部纪录片把镜头交给了他们。", "After midnight, the teams maintaining the city's green belts finally start their shift. This film hands them the camera.", "بعد منتصف الليل تبدأ الفرق التي تحافظ على الواحات الحضرية عملها الحقيقي، ويمنحهم هذا الفيلم الكاميرا."),
                stats: makeStats(views: "5.9M", released: "2026-03-10", episodes: "1", duration: "52m"),
                tags: makeTags([
                    ("绿化", "Greening", "تشجير"),
                    ("夜班", "Night shift", "وردية ليلية"),
                    ("人物", "People", "شخصيات"),
                ]),
                episodeGroups: [singleEpisodeGroup(content: oasisKeepers)],
                defaultEpisodeID: nil,
                cast: makeCast([
                    ("cast-reem", "Reem Al Ali", VideoLocalizedString("维护主管", "Maintenance lead", "مسؤولة الصيانة")),
                    ("cast-khaled", "Khaled Noor", VideoLocalizedString("园艺师", "Horticulturist", "بستاني")),
                ]),
                related: [deepBlueDesert, desertDiary, moonlitRelay]
            ),
        ]

        let feedItemsByCategory: [String: [VideoContentSummary]] = [
            "recommend": [
                skylineOps,
                desertSignal,
                nightBazaar,
                deepBlueDesert,
                pearlHeist,
                makerBattle,
                codeRift,
                oasisKeepers,
                rooftopMix,
                moonlitRelay,
                cityOfWind,
                desertDiary,
            ],
            "movie": [desertSignal, pearlHeist, moonlitRelay],
            "series": [skylineOps, desertDiary, codeRift],
            "variety": [nightBazaar, rooftopMix, makerBattle],
            "documentary": [deepBlueDesert, cityOfWind, oasisKeepers],
        ]

        let carouselItemsByCategory: [String: [VideoCarouselItem]] = [
            "recommend": [
                makeCarousel(id: "c1", eyebrow: VideoLocalizedString("重磅推荐", "Featured Now", "الواجهة الآن"), content: skylineOps, startHex: 0x153B7C, endHex: 0x7C3AED),
                makeCarousel(id: "c2", eyebrow: VideoLocalizedString("城市热播", "City Trending", "الأكثر رواجًا"), content: desertSignal, startHex: 0x0F766E, endHex: 0x2563EB),
                makeCarousel(id: "c3", eyebrow: VideoLocalizedString("周末上新", "Weekend Drop", "إصدار نهاية الأسبوع"), content: nightBazaar, startHex: 0xC2410C, endHex: 0xE11D48),
            ],
            "movie": [
                makeCarousel(id: "m1", eyebrow: VideoLocalizedString("电影推荐", "Movie Spotlight", "واجهة الأفلام"), content: desertSignal, startHex: 0x1D4ED8, endHex: 0x0891B2),
                makeCarousel(id: "m2", eyebrow: VideoLocalizedString("悬疑精选", "Mystery Pick", "اختيار الغموض"), content: pearlHeist, startHex: 0x4C1D95, endHex: 0xBE185D),
                makeCarousel(id: "m3", eyebrow: VideoLocalizedString("夜色电影", "After Dark", "ليلة سينمائية"), content: moonlitRelay, startHex: 0x1F2937, endHex: 0x4F46E5),
            ],
            "series": [
                makeCarousel(id: "s1", eyebrow: VideoLocalizedString("剧集热榜", "Series Trending", "رائج المسلسلات"), content: skylineOps, startHex: 0x0F766E, endHex: 0x2563EB),
                makeCarousel(id: "s2", eyebrow: VideoLocalizedString("本周追更", "Keep Watching", "تابع هذا الأسبوع"), content: desertDiary, startHex: 0x92400E, endHex: 0xDB2777),
                makeCarousel(id: "s3", eyebrow: VideoLocalizedString("片源修复中", "Source Pending", "بانتظار المصدر"), content: codeRift, startHex: 0x374151, endHex: 0x6B7280),
            ],
            "variety": [
                makeCarousel(id: "v1", eyebrow: VideoLocalizedString("今晚首看", "Tonight First", "ليلة اليوم"), content: nightBazaar, startHex: 0xB45309, endHex: 0xEC4899),
                makeCarousel(id: "v2", eyebrow: VideoLocalizedString("现场舞台", "Live Stage", "عرض مباشر"), content: rooftopMix, startHex: 0x7C3AED, endHex: 0x2563EB),
                makeCarousel(id: "v3", eyebrow: VideoLocalizedString("竞技挑战", "Challenge Mode", "وضع التحدي"), content: makerBattle, startHex: 0x0F766E, endHex: 0x059669),
            ],
            "documentary": [
                makeCarousel(id: "d1", eyebrow: VideoLocalizedString("高分纪录", "Top Documentary", "أفضل وثائقي"), content: deepBlueDesert, startHex: 0x0F766E, endHex: 0x0284C7),
                makeCarousel(id: "d2", eyebrow: VideoLocalizedString("城市人物", "City Stories", "قصص المدينة"), content: oasisKeepers, startHex: 0x166534, endHex: 0x15803D),
                makeCarousel(id: "d3", eyebrow: VideoLocalizedString("暂时下架", "Removed", "تمت الإزالة"), content: cityOfWind, startHex: 0x4B5563, endHex: 0x111827),
            ],
        ]

        return VideoCatalog(
            navigation: VideoNavigationSnapshot(
                featureEnabled: true,
                defaultCategoryID: "recommend",
                categories: categories
            ),
            carouselItemsByCategory: carouselItemsByCategory,
            feedItemsByCategory: feedItemsByCategory,
            detailsByID: details
        )
    }

    private static func makeContent(
        id: String,
        categoryID: String,
        type: VideoContentType,
        title: VideoLocalizedString,
        subtitle: VideoLocalizedString,
        summary: VideoLocalizedString,
        posterURL: String,
        backdropURL: String,
        badge: VideoLocalizedString?,
        chips: [VideoLocalizedString],
        ratingText: String?,
        metaLine: VideoLocalizedString,
        durationText: VideoLocalizedString,
        availabilityStatus: VideoAvailabilityStatus,
        availabilityMessage: VideoLocalizedString?
    ) -> VideoContentSummary {
        VideoContentSummary(
            id: id,
            categoryID: categoryID,
            type: type,
            title: title,
            subtitle: subtitle,
            summary: summary,
            posterImage: .remote(URL(string: posterURL)!),
            backdropImage: .remote(URL(string: backdropURL)!),
            badgeText: badge,
            chips: chips,
            ratingText: ratingText,
            metaLine: metaLine,
            durationText: durationText,
            availabilityStatus: availabilityStatus,
            availabilityMessage: availabilityMessage
        )
    }

    private static func makeCarousel(
        id: String,
        eyebrow: VideoLocalizedString,
        content: VideoContentSummary,
        startHex: UInt32,
        endHex: UInt32
    ) -> VideoCarouselItem {
        VideoCarouselItem(
            id: id,
            eyebrow: eyebrow,
            content: content,
            accentStartHex: startHex,
            accentEndHex: endHex
        )
    }

    private static func makeDetail(
        content: VideoContentSummary,
        synopsis: VideoLocalizedString,
        stats: [VideoDetailStat],
        tags: [VideoTag],
        episodeGroups: [VideoEpisodeGroup],
        defaultEpisodeID: String?,
        cast: [VideoCastMember],
        related: [VideoContentSummary]
    ) -> VideoDetailSnapshot {
        VideoDetailSnapshot(
            content: content,
            heroImage: content.backdropImage,
            synopsis: synopsis,
            stats: stats,
            tags: tags,
            episodeGroups: episodeGroups,
            defaultEpisodeID: defaultEpisodeID ?? episodeGroups.first?.episodes.first?.id,
            cast: cast,
            related: related
        )
    }

    private static func makeStats(
        views: String,
        released: String,
        episodes: String,
        duration: String
    ) -> [VideoDetailStat] {
        [
            VideoDetailStat(id: "views", titleKey: "video.detail.stat.views", systemImage: "eye.fill", value: views),
            VideoDetailStat(id: "released", titleKey: "video.detail.stat.released", systemImage: "calendar", value: released),
            VideoDetailStat(id: "episodes", titleKey: "video.detail.stat.episodes", systemImage: "square.stack.3d.up.fill", value: episodes),
            VideoDetailStat(id: "duration", titleKey: "video.detail.stat.duration", systemImage: "clock.fill", value: duration),
        ]
    }

    private static func makeTags(_ items: [(String, String, String)]) -> [VideoTag] {
        items.enumerated().map { index, item in
            VideoTag(
                id: "tag-\(index)-\(item.1)",
                title: VideoLocalizedString(item.0, item.1, item.2),
                style: index == 0 ? .accent : .neutral
            )
        }
    }

    private static func makeCast(
        _ items: [(String, String, VideoLocalizedString?)]
    ) -> [VideoCastMember] {
        items.enumerated().map { index, item in
            VideoCastMember(
                id: item.0,
                name: item.1,
                role: item.2,
                avatarImage: .remote(URL(string: "https://picsum.photos/id/\(220 + index)/200/200")!)
            )
        }
    }

    private static func singleEpisodeGroup(
        content: VideoContentSummary,
        availabilityStatus: VideoAvailabilityStatus? = nil,
        availabilityMessage: VideoLocalizedString? = nil
    ) -> VideoEpisodeGroup {
        VideoEpisodeGroup(
            id: "\(content.id)-default",
            title: VideoLocalizedString("正片", "Feature", "الفيلم"),
            episodes: [
                VideoEpisode(
                    id: "\(content.id)-ep1",
                    episodeNumber: 1,
                    title: VideoLocalizedString("正片", "Feature", "الفيلم"),
                    subtitle: nil,
                    durationSeconds: 42 * 60,
                    thumbnailImage: content.posterImage,
                    availabilityStatus: availabilityStatus ?? content.availabilityStatus,
                    availabilityMessage: availabilityMessage ?? content.availabilityMessage
                ),
            ]
        )
    }

    private static func makeEpisodeGroup(
        id: String,
        title: VideoLocalizedString,
        cover: VideoImageSource,
        episodeCount: Int,
        availabilityStatus: VideoAvailabilityStatus = .playable,
        availabilityMessage: VideoLocalizedString? = nil
    ) -> VideoEpisodeGroup {
        let episodes = (1...episodeCount).map { number in
            VideoEpisode(
                id: "\(id)-ep\(number)",
                episodeNumber: number,
                title: VideoLocalizedString("第 \(number) 集", "Episode \(number)", "الحلقة \(number)"),
                subtitle: VideoLocalizedString("城市任务 \(number)", "Urban mission \(number)", "مهمة المدينة \(number)"),
                durationSeconds: 40 * 60 + (number * 2),
                thumbnailImage: cover,
                availabilityStatus: availabilityStatus,
                availabilityMessage: availabilityMessage
            )
        }

        return VideoEpisodeGroup(id: id, title: title, episodes: episodes)
    }
}

private func normalizedMockQuery(_ value: String) -> String {
    value
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
}

private extension VideoLocalizedString {
    func matches(query: String) -> Bool {
        let values = [simplifiedChinese, english, arabic]
        return values.contains { normalizedMockQuery($0).contains(query) }
    }
}
