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
}

enum VideoImageSource: Hashable, Sendable {
    case remote(URL)
    case system(name: String, backgroundHex: UInt32, tintHex: UInt32)
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
}

enum VideoSourceFormat: String, Hashable, Sendable {
    case hls
    case mp4
}

struct VideoSource: Identifiable, Hashable, Sendable {
    let id: String
    let url: URL
    let quality: VideoQuality
    let format: VideoSourceFormat
}

struct VideoSubtitleTrack: Identifiable, Hashable, Sendable {
    let id: String
    let languageCode: String
    let displayName: VideoLocalizedString
    let url: URL?
    let isEmbedded: Bool
}

struct VideoAudioTrack: Identifiable, Hashable, Sendable {
    let id: String
    let languageCode: String
    let displayName: VideoLocalizedString
    let url: URL?
    let isDefault: Bool
}

struct VideoPlaybackSession: Identifiable, Hashable, Sendable {
    let playSessionID: String
    let expiresAt: Date
    let mediaID: String
    let mediaTitle: VideoLocalizedString
    let episode: VideoEpisode
    let videoSources: [VideoSource]
    let subtitles: [VideoSubtitleTrack]
    let audioTracks: [VideoAudioTrack]
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

private func normalizedVideoSearchValue(_ value: String) -> String {
    value
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
}
