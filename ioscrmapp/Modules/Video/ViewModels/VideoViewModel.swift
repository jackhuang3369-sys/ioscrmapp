import Foundation

@MainActor
final class VideoViewModel: ObservableObject {
    enum ScreenState: Equatable {
        case idle
        case loading
        case loaded
        case featureDisabled
        case failed(LocalizedTextValue)
    }

    @Published private(set) var screenState: ScreenState = .idle
    @Published private(set) var navigation: VideoNavigationSnapshot?
    @Published private(set) var currentCategoryID = ""
    @Published private(set) var carouselItems: [VideoCarouselItem] = []
    @Published private(set) var feedSnapshot: VideoPagedFeedSnapshot?
    @Published private(set) var isLoadingMore = false
    @Published private(set) var loadMoreError: LocalizedTextValue?
    @Published private(set) var mergedHistory: [String] = []
    @Published private(set) var historyLimit = VideoPaginationDefaults.historyLimit
    @Published private(set) var toastMessage: LocalizedTextValue?
    @Published private(set) var unavailablePresentation: VideoUnavailablePresentation?

    let session: CustSubInfo
    let videoService: any VideoServicing

    private let localHistoryStore = VideoSearchHistoryStore()
    private var hasLoaded = false
    private var feedVersion = 0
    private var toastDismissTask: Task<Void, Never>?

    init(session: CustSubInfo, videoService: any VideoServicing) {
        self.session = session
        self.videoService = videoService
    }

    func loadIfNeeded() async {
        guard !hasLoaded else {
            return
        }

        await load(showLoading: true)
    }

    func reload() async {
        hasLoaded = false
        await load(showLoading: true)
    }

    func refresh() async {
        await load(showLoading: navigation == nil)
    }

    func selectCategory(id: String) async {
        guard currentCategoryID != id else {
            return
        }

        currentCategoryID = id
        await loadCategoryContent(categoryID: id, showLoading: false)
    }

    func loadMoreIfNeeded(currentItem: VideoContentSummary) async {
        guard let feedSnapshot,
              feedSnapshot.hasMore,
              !isLoadingMore,
              feedSnapshot.items.last?.id == currentItem.id else {
            return
        }

        isLoadingMore = true
        loadMoreError = nil
        let requestVersion = feedVersion

        do {
            let nextSnapshot = try await videoService.fetchList(
                categoryID: currentCategoryID,
                pageNum: feedSnapshot.pageNum + 1,
                pageSize: feedSnapshot.pageSize,
                session: session
            )

            guard requestVersion == feedVersion else {
                isLoadingMore = false
                return
            }

            self.feedSnapshot = VideoPagedFeedSnapshot(
                categoryID: nextSnapshot.categoryID,
                pageNum: nextSnapshot.pageNum,
                pageSize: nextSnapshot.pageSize,
                total: nextSnapshot.total,
                hasMore: nextSnapshot.hasMore,
                items: feedSnapshot.items + nextSnapshot.items
            )
            isLoadingMore = false
        } catch let error as VideoServiceError {
            guard requestVersion == feedVersion else {
                isLoadingMore = false
                return
            }

            isLoadingMore = false
            loadMoreError = error.textValue
        } catch {
            guard requestVersion == feedVersion else {
                isLoadingMore = false
                return
            }

            isLoadingMore = false
            loadMoreError = VideoServiceError.homeUnavailable.textValue
        }
    }

    func prepareSearchPanel() async {
        do {
            let bootstrap = try await videoService.fetchSearchBootstrap(session: session)
            let localHistory = await localHistoryStore.history()
            historyLimit = bootstrap.historyLimit
            mergedHistory = mergeHistory(
                local: localHistory,
                remote: bootstrap.remoteHistory,
                limit: bootstrap.historyLimit
            )
        } catch {
            historyLimit = VideoPaginationDefaults.historyLimit
            mergedHistory = await localHistoryStore.history()
        }
    }

    func deleteHistory(keyword: String) async {
        let localHistory = await localHistoryStore.delete(keyword: keyword)
        mergedHistory = mergeHistory(local: localHistory, remote: [], limit: historyLimit)

        do {
            try await videoService.deleteSearchHistory(keyword: keyword, session: session)
        } catch {
            showToast(.key("video.search.error.historySync"))
        }
    }

    func clearHistory() async {
        _ = await localHistoryStore.clear()
        mergedHistory = []

        do {
            try await videoService.clearSearchHistory(session: session)
        } catch {
            showToast(.key("video.search.error.historySync"))
        }
    }

    func search(keyword: String, language: AppLanguage) async throws -> VideoSearchResponse {
        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKeyword.isEmpty, trimmedKeyword.count <= 50 else {
            throw VideoServiceError.keywordInvalid
        }

        let response = try await videoService.searchVideos(
            keyword: trimmedKeyword,
            language: language,
            session: session
        )

        let localHistory = await localHistoryStore.record(
            keyword: trimmedKeyword,
            limit: historyLimit
        )
        mergedHistory = mergeHistory(
            local: localHistory,
            remote: [trimmedKeyword] + mergedHistory,
            limit: historyLimit
        )

        return response
    }

    func handleSelection(of content: VideoContentSummary) async -> String? {
        if content.isPlayable {
            return content.id
        }

        await presentUnavailableContent(for: content.id)
        return nil
    }

    func dismissUnavailablePresentation() {
        unavailablePresentation = nil
    }

    private func load(showLoading: Bool) async {
        if showLoading {
            screenState = .loading
        }

        loadMoreError = nil

        do {
            let navigation = try await videoService.fetchNavigation(session: session)
            self.navigation = navigation

            guard navigation.featureEnabled, let defaultCategoryID = navigation.defaultCategoryID else {
                screenState = .featureDisabled
                carouselItems = []
                feedSnapshot = nil
                currentCategoryID = ""
                return
            }

            if currentCategoryID.isEmpty {
                currentCategoryID = defaultCategoryID
            }

            await loadCategoryContent(categoryID: currentCategoryID, showLoading: false)
            await prepareSearchPanel()
            hasLoaded = true
            screenState = .loaded
        } catch let error as VideoServiceError {
            screenState = error == .featureDisabled ? .featureDisabled : .failed(error.textValue)
        } catch {
            screenState = .failed(VideoServiceError.homeUnavailable.textValue)
        }
    }

    private func loadCategoryContent(
        categoryID: String,
        showLoading: Bool
    ) async {
        if showLoading {
            screenState = .loading
        }

        feedVersion += 1
        let requestVersion = feedVersion
        loadMoreError = nil

        do {
            async let loadedCarousels = videoService.fetchCarousels(categoryID: categoryID, session: session)
            async let loadedFeed = videoService.fetchList(
                categoryID: categoryID,
                pageNum: VideoPaginationDefaults.firstPage,
                pageSize: VideoPaginationDefaults.pageSize,
                session: session
            )

            let carousels = try await loadedCarousels
            let feed = try await loadedFeed

            guard requestVersion == feedVersion else {
                return
            }

            carouselItems = carousels
            feedSnapshot = feed
        } catch let error as VideoServiceError {
            guard requestVersion == feedVersion else {
                return
            }

            screenState = .failed(error.textValue)
        } catch {
            guard requestVersion == feedVersion else {
                return
            }

            screenState = .failed(VideoServiceError.homeUnavailable.textValue)
        }
    }

    private func presentUnavailableContent(for videoID: String) async {
        do {
            let detail = try await videoService.fetchDetail(videoID: videoID, session: session)
            unavailablePresentation = VideoUnavailablePresentation(
                title: detail.content.availabilityStatus == .removed
                    ? .key("video.unavailable.removed.title")
                    : .key("video.unavailable.noSource.title"),
                message: detail.content.availabilityMessage
                    ?? VideoLocalizedString(
                        "暂无可播放源",
                        "No playable source yet",
                        "لا يوجد مصدر تشغيل متاح"
                    ),
                recommendations: Array(detail.related.prefix(3))
            )
            showToast(unavailablePresentation?.title ?? .key("video.unavailable.noSource.title"))
        } catch {
            showToast(.key("video.state.error.subtitle"))
        }
    }

    private func mergeHistory(
        local: [String],
        remote: [String],
        limit: Int
    ) -> [String] {
        var merged: [String] = []
        var seen = Set<String>()

        for keyword in local + remote {
            let normalized = keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !normalized.isEmpty, !seen.contains(normalized) else {
                continue
            }
            seen.insert(normalized)
            merged.append(keyword)
        }

        return Array(merged.prefix(limit))
    }

    private func showToast(_ message: LocalizedTextValue) {
        toastDismissTask?.cancel()
        toastMessage = message

        toastDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            guard !Task.isCancelled else {
                return
            }
            toastMessage = nil
        }
    }
}

@MainActor
final class VideoDetailViewModel: ObservableObject {
    enum ScreenState: Equatable {
        case idle
        case loading
        case loaded
        case failed(LocalizedTextValue)
    }

    @Published private(set) var screenState: ScreenState = .idle
    @Published private(set) var detail: VideoDetailSnapshot?
    @Published private(set) var isRequestingPlayback = false
    @Published private(set) var bannerMessage: LocalizedTextValue?

    let videoID: String
    let session: CustSubInfo
    let videoService: any VideoServicing

    private var hasLoaded = false

    init(
        videoID: String,
        session: CustSubInfo,
        videoService: any VideoServicing
    ) {
        self.videoID = videoID
        self.session = session
        self.videoService = videoService
    }

    func loadIfNeeded() async {
        guard !hasLoaded else {
            return
        }

        await load(showLoading: true)
    }

    func reload() async {
        hasLoaded = false
        await load(showLoading: true)
    }

    func requestPlaybackSession(
        episodeID: String?,
        preferredQuality: VideoQuality? = nil
    ) async -> VideoPlaybackSession? {
        isRequestingPlayback = true
        defer {
            isRequestingPlayback = false
        }

        do {
            return try await videoService.requestPlaybackSession(
                videoID: videoID,
                episodeID: episodeID,
                preferredQuality: preferredQuality,
                session: session
            )
        } catch let error as VideoServiceError {
            bannerMessage = error.textValue
            return nil
        } catch {
            bannerMessage = VideoServiceError.playbackUnavailable.textValue
            return nil
        }
    }

    private func load(showLoading: Bool) async {
        if showLoading {
            screenState = .loading
        }

        bannerMessage = nil

        do {
            detail = try await videoService.fetchDetail(videoID: videoID, session: session)
            hasLoaded = true
            screenState = .loaded
        } catch let error as VideoServiceError {
            screenState = .failed(error.textValue)
        } catch {
            screenState = .failed(VideoServiceError.detailUnavailable.textValue)
        }
    }
}

struct VideoUnavailablePresentation: Equatable {
    let title: LocalizedTextValue
    let message: VideoLocalizedString
    let recommendations: [VideoContentSummary]
}

private actor VideoSearchHistoryStore {
    private let defaults: UserDefaults
    private let storageKey = "video.search.localHistory"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func history() -> [String] {
        defaults.stringArray(forKey: storageKey) ?? []
    }

    @discardableResult
    func record(keyword: String, limit: Int) -> [String] {
        var items = history().filter { $0.caseInsensitiveCompare(keyword) != .orderedSame }
        items.insert(keyword, at: 0)
        let truncatedItems = Array(items.prefix(limit))
        defaults.set(truncatedItems, forKey: storageKey)
        return truncatedItems
    }

    @discardableResult
    func delete(keyword: String) -> [String] {
        let updatedItems = history().filter { $0.caseInsensitiveCompare(keyword) != .orderedSame }
        defaults.set(updatedItems, forKey: storageKey)
        return updatedItems
    }

    @discardableResult
    func clear() -> [String] {
        defaults.removeObject(forKey: storageKey)
        return []
    }
}
