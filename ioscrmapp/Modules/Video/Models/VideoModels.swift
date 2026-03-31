import Foundation

struct VideoLocalizedString: Hashable, Sendable {
    let simplifiedChinese: String
    let english: String
    let arabic: String

    init(_ simplifiedChinese: String, _ english: String, _ arabic: String) {
        self.simplifiedChinese = simplifiedChinese
        self.english = english
        self.arabic = arabic
    }

    static func mirrored(_ value: String) -> Self {
        .init(value, value, value)
    }

    func value(for language: AppLanguage) -> String {
        switch language {
        case .simplifiedChinese:
            return simplifiedChinese
        case .english:
            return english
        case .arabic:
            return arabic
        }
    }

    func matches(query: String) -> Bool {
        let normalizedQuery = normalizedVideoSearchValue(query)
        guard !normalizedQuery.isEmpty else {
            return false
        }

        return [
            simplifiedChinese,
            english,
            arabic,
        ].contains { value in
            normalizedVideoSearchValue(value).contains(normalizedQuery)
        }
    }
}

enum VideoImageSource: Hashable, Sendable {
    case remote(URL)
    case asset(String)
    case system(name: String, backgroundHex: UInt32, tintHex: UInt32)

    var crmSourceString: String {
        switch self {
        case let .remote(url):
            return url.absoluteString
        case let .asset(name):
            return "local:\(name)"
        case .system:
            return ""
        }
    }
}

enum VideoContentType: String, Hashable, Sendable {
    case movie
    case series
    case variety
    case documentary
}

enum VideoAvailabilityStatus: String, Hashable, Sendable {
    case playable
    case removed
    case sourceUnavailable

    var isPlayable: Bool {
        self == .playable
    }
}

struct VideoCategory: Identifiable, Hashable, Sendable {
    let id: String
    let title: VideoLocalizedString
    let symbolName: String
}

struct VideoNavigationSnapshot: Sendable {
    let featureEnabled: Bool
    let defaultCategoryID: String?
    let categories: [VideoCategory]
}

struct VideoContentSummary: Identifiable, Hashable, Sendable {
    let id: String
    let categoryID: String
    let type: VideoContentType
    let title: VideoLocalizedString
    let subtitle: VideoLocalizedString
    let summary: VideoLocalizedString
    let posterImage: VideoImageSource
    let backdropImage: VideoImageSource
    let badgeText: VideoLocalizedString?
    let chips: [VideoLocalizedString]
    let ratingText: String?
    let metaLine: VideoLocalizedString
    let durationText: VideoLocalizedString
    let viewCount: Int
    let releaseDate: Date
    let episodeCount: Int
    let durationSeconds: Int
    let availabilityStatus: VideoAvailabilityStatus
    let availabilityMessage: VideoLocalizedString?

    var isPlayable: Bool {
        availabilityStatus.isPlayable
    }

    func matches(query: String, language: AppLanguage) -> Bool {
        let normalizedQuery = normalizedVideoSearchValue(query)
        guard !normalizedQuery.isEmpty else {
            return false
        }

        let searchableValues = [
            title.value(for: language),
            subtitle.value(for: language),
            summary.value(for: language),
            title.simplifiedChinese,
            title.english,
            title.arabic,
            subtitle.simplifiedChinese,
            subtitle.english,
            subtitle.arabic,
            summary.simplifiedChinese,
            summary.english,
            summary.arabic,
        ] + chips.map(\.simplifiedChinese)
            + chips.map(\.english)
            + chips.map(\.arabic)

        return searchableValues.contains { value in
            normalizedVideoSearchValue(value).contains(normalizedQuery)
        }
    }

    var crmSummaryMedia: CRMMedia {
        CRMMedia(
            id: id,
            title: title.english,
            cover: posterImage.crmSourceString,
            description: summary.english,
            type: type.crmType,
            views: viewCount,
            publishDate: releaseDate,
            duration: durationSeconds,
            rating: ratingText.flatMap(Double.init),
            tags: chips.map(\.english),
            actors: [],
            episodes: [],
            relatedMediaIds: []
        )
    }
}

struct VideoCarouselItem: Identifiable, Hashable, Sendable {
    let id: String
    let eyebrow: VideoLocalizedString
    let content: VideoContentSummary
    let accentStartHex: UInt32
    let accentEndHex: UInt32
}

struct VideoPagedFeedSnapshot: Sendable {
    let categoryID: String
    let pageNum: Int
    let pageSize: Int
    let total: Int
    let hasMore: Bool
    let items: [VideoContentSummary]
}

struct VideoSearchBootstrap: Sendable {
    let remoteHistory: [String]
    let historyLimit: Int
}

struct VideoSearchResponse: Sendable {
    let keyword: String
    let matchedContent: VideoContentSummary?
    let matchedBy: VideoLocalizedString?
    let recommendations: [VideoContentSummary]
}

enum VideoTagStyle: Hashable, Sendable {
    case neutral
    case accent
    case warning
}

struct VideoTag: Identifiable, Hashable, Sendable {
    let id: String
    let title: VideoLocalizedString
    let style: VideoTagStyle
}

struct VideoDetailStat: Identifiable, Hashable, Sendable {
    let id: String
    let titleKey: String
    let systemImage: String
    let value: String
}

struct VideoCastMember: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let role: VideoLocalizedString?
    let avatarImage: VideoImageSource?

    var crmActor: CRMActor {
        CRMActor(
            id: id,
            name: name,
            avatar: avatarImage?.crmSourceString,
            role: role?.english
        )
    }
}

enum VideoQuality: String, CaseIterable, Hashable, Sendable {
    case auto
    case sd480
    case hd720
    case hd1080
    case uhd4k

    func title(for language: AppLanguage) -> String {
        switch self {
        case .auto:
            switch language {
            case .simplifiedChinese: return "自动"
            case .english: return "Auto"
            case .arabic: return "تلقائي"
            }
        case .sd480:
            return "480P"
        case .hd720:
            return "720P HD"
        case .hd1080:
            return "1080P FHD"
        case .uhd4k:
            return "4K UHD"
        }
    }

    var sortOrder: Int {
        switch self {
        case .auto: return 0
        case .sd480: return 1
        case .hd720: return 2
        case .hd1080: return 3
        case .uhd4k: return 4
        }
    }

    var crmQuality: CRMVideoQuality {
        switch self {
        case .auto: return .auto
        case .sd480: return .sd480
        case .hd720: return .hd720
        case .hd1080: return .hd1080
        case .uhd4k: return .uhd4k
        }
    }
}

enum VideoSourceFormat: String, Hashable, Sendable {
    case hls
    case mp4

    var crmFormat: CRMVideoFormat {
        switch self {
        case .hls:
            return .hls
        case .mp4:
            return .mp4
        }
    }
}

struct VideoEpisodeResolution: Identifiable, Hashable, Sendable {
    let id: String
    let url: URL
    let quality: VideoQuality
    let format: VideoSourceFormat

    var crmVideoSource: CRMVideoSource {
        CRMVideoSource(
            id: id,
            url: url.absoluteString,
            quality: quality.crmQuality,
            format: format.crmFormat
        )
    }
}

struct VideoSubtitleTrack: Identifiable, Hashable, Sendable {
    let id: String
    let languageCode: String
    let displayName: VideoLocalizedString
    let url: URL?
    let isEmbedded: Bool

    var crmSubtitle: CRMSubtitle {
        CRMSubtitle(
            id: id,
            language: languageCode,
            displayName: displayName.english,
            url: url?.absoluteString,
            isEmbedded: isEmbedded
        )
    }
}

struct VideoAudioTrack: Identifiable, Hashable, Sendable {
    let id: String
    let languageCode: String
    let displayName: VideoLocalizedString
    let url: URL?
    let isDefault: Bool

    var crmAudioTrack: CRMAudioTrack {
        CRMAudioTrack(
            id: id,
            language: languageCode,
            displayName: displayName.english,
            url: url?.absoluteString,
            isDefault: isDefault
        )
    }
}

struct VideoEpisode: Identifiable, Hashable, Sendable {
    let id: String
    let episodeNumber: Int
    let title: VideoLocalizedString
    let subtitle: VideoLocalizedString?
    let durationSeconds: Int
    let thumbnailImage: VideoImageSource
    let availabilityStatus: VideoAvailabilityStatus
    let availabilityMessage: VideoLocalizedString?
    let resolutions: [VideoEpisodeResolution]
    let subtitleTracks: [VideoSubtitleTrack]
    let audioTracks: [VideoAudioTrack]

    var crmEpisode: CRMEpisode {
        CRMEpisode(
            id: id,
            episodeNumber: episodeNumber,
            title: title.english,
            duration: durationSeconds,
            thumbnail: thumbnailImage.crmSourceString,
            videoSources: resolutions.map(\.crmVideoSource),
            subtitles: subtitleTracks.map(\.crmSubtitle),
            audioTracks: audioTracks.map(\.crmAudioTrack)
        )
    }
}

struct VideoEpisodeGroup: Identifiable, Hashable, Sendable {
    let id: String
    let title: VideoLocalizedString
    let episodes: [VideoEpisode]
}

struct VideoDetailSnapshot: Sendable {
    let content: VideoContentSummary
    let heroImage: VideoImageSource
    let synopsis: VideoLocalizedString
    let stats: [VideoDetailStat]
    let tags: [VideoTag]
    let episodeGroups: [VideoEpisodeGroup]
    let defaultEpisodeID: String?
    let cast: [VideoCastMember]
    let related: [VideoContentSummary]

    var defaultEpisode: VideoEpisode? {
        episodeGroups
            .flatMap(\.episodes)
            .first { $0.id == defaultEpisodeID }
            ?? episodeGroups.first?.episodes.first
    }

    var isPlayable: Bool {
        content.isPlayable
    }

    var crmMedia: CRMMedia {
        CRMMedia(
            id: content.id,
            title: content.title.english,
            cover: heroImage.crmSourceString.isEmpty ? content.posterImage.crmSourceString : heroImage.crmSourceString,
            description: synopsis.english,
            type: content.type.crmType,
            views: content.viewCount,
            publishDate: content.releaseDate,
            duration: content.durationSeconds,
            rating: content.ratingText.flatMap(Double.init),
            tags: tags.map { $0.title.english },
            actors: cast.map(\.crmActor),
            episodes: episodeGroups.flatMap(\.episodes).map(\.crmEpisode),
            relatedMediaIds: related.map(\.id)
        )
    }

    var crmRelatedMedia: [CRMMedia] {
        related.map(\.crmSummaryMedia)
    }
}

struct VideoPlaybackSession: Identifiable, Hashable, Sendable {
    let playSessionID: String
    let expiresAt: Date
    let mediaID: String
    let mediaTitle: VideoLocalizedString
    let episode: VideoEpisode
    let pipEnabled: Bool

    var id: String {
        playSessionID
    }
}

enum VideoPaginationDefaults {
    static let firstPage = 1
    static let pageSize = 10
    static let historyLimit = 20
}

enum CRMMediaType: String, Hashable, Sendable {
    case movie = "movie"
    case tvSeries = "tv_series"
    case variety = "variety"
    case documentary = "documentary"

    var displayName: String {
        switch self {
        case .movie:
            return "Movie"
        case .tvSeries:
            return "TV Series"
        case .variety:
            return "Variety"
        case .documentary:
            return "Documentary"
        }
    }
}

struct CRMMedia: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let cover: String
    let description: String
    let type: CRMMediaType
    let views: Int
    let publishDate: Date
    let duration: Int
    let rating: Double?
    let tags: [String]
    let actors: [CRMActor]
    let episodes: [CRMEpisode]
    let relatedMediaIds: [String]

    var formattedViews: String {
        switch views {
        case 1_000_000_000...:
            return String(format: "%.1fB", Double(views) / 1_000_000_000)
        case 1_000_000...:
            return String(format: "%.1fM", Double(views) / 1_000_000)
        case 1_000...:
            return String(format: "%.1fK", Double(views) / 1_000)
        default:
            return "\(views)"
        }
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: publishDate)
    }
}

struct CRMActor: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let avatar: String?
    let role: String?
}

struct CRMEpisode: Identifiable, Hashable, Sendable {
    let id: String
    let episodeNumber: Int
    let title: String
    let duration: Int
    let thumbnail: String
    let videoSources: [CRMVideoSource]
    let subtitles: [CRMSubtitle]
    let audioTracks: [CRMAudioTrack]

    var formattedDuration: String {
        let hours = duration / 3600
        let minutes = (duration % 3600) / 60
        let seconds = duration % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct CRMVideoSource: Identifiable, Hashable, Sendable {
    let id: String
    let url: String
    let quality: CRMVideoQuality
    let format: CRMVideoFormat
}

enum CRMVideoQuality: String, CaseIterable, Hashable, Sendable {
    case auto = "auto"
    case sd480 = "480p"
    case hd720 = "720p"
    case hd1080 = "1080p"
    case uhd4k = "4K"

    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .sd480: return "480P"
        case .hd720: return "720P HD"
        case .hd1080: return "1080P FHD"
        case .uhd4k: return "4K UHD"
        }
    }

    var sortOrder: Int {
        switch self {
        case .auto: return 0
        case .sd480: return 1
        case .hd720: return 2
        case .hd1080: return 3
        case .uhd4k: return 4
        }
    }
}

enum CRMVideoFormat: String, Hashable, Sendable {
    case hls = "hls"
    case mp4 = "mp4"
    case dash = "dash"
}

struct CRMSubtitle: Identifiable, Hashable, Sendable {
    let id: String
    let language: String
    let displayName: String
    let url: String?
    let isEmbedded: Bool
}

struct CRMAudioTrack: Identifiable, Hashable, Sendable {
    let id: String
    let language: String
    let displayName: String
    let url: String?
    let isDefault: Bool

    var isExternal: Bool {
        guard let url, !url.isEmpty else {
            return false
        }

        return true
    }
}

extension VideoContentType {
    var crmType: CRMMediaType {
        switch self {
        case .movie:
            return .movie
        case .series:
            return .tvSeries
        case .variety:
            return .variety
        case .documentary:
            return .documentary
        }
    }
}

func normalizedVideoSearchValue(_ value: String) -> String {
    value
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
}
