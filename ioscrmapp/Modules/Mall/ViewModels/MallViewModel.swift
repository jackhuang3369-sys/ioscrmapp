import Foundation

@MainActor
final class MallViewModel: ObservableObject {
    enum ScreenState: Equatable {
        case idle
        case loading
        case loaded
        case failed(LocalizedTextValue)
    }

    @Published private(set) var screenState: ScreenState = .idle
    @Published private(set) var homeSnapshot: MallHomeSnapshot?
    @Published private(set) var searchBootstrap: MallSearchBootstrap?
    @Published private(set) var bannerMessage: LocalizedTextValue?

    private let session: CustSubInfo
    private let mallService: any MallServicing
    private var hasLoaded = false

    init(session: CustSubInfo, mallService: any MallServicing) {
        self.session = session
        self.mallService = mallService
    }

    func loadIfNeeded() async {
        // 首页和搜索页共享同一份 ViewModel，这里避免重复拉取首页/搜索引导数据。
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
        await load(showLoading: homeSnapshot == nil)
    }

    func deleteHistory(keyword: String) async {
        do {
            try await mallService.deleteSearchHistory(keyword: keyword, session: session)
            try await reloadBootstrap()
        } catch {
            bannerMessage = .key("mall.search.error.subtitle")
        }
    }

    func clearHistory() async {
        do {
            try await mallService.clearSearchHistory(session: session)
            try await reloadBootstrap()
        } catch {
            bannerMessage = .key("mall.search.error.subtitle")
        }
    }

    func searchProducts(
        query: String,
        categoryID: String?,
        sort: MallSearchSortMode,
        order: MallSortOrder,
        language: AppLanguage
    ) async throws -> MallSearchResultSnapshot {
        let snapshot = try await mallService.searchProducts(
            query: query,
            categoryID: categoryID,
            sort: sort,
            order: order,
            language: language,
            session: session
        )
        // 搜索成功后立即刷新引导数据，让搜索历史和热搜区保持最新状态。
        try await reloadBootstrap()
        return snapshot
    }

    func primaryCategory(id: String) -> MallPrimaryCategory? {
        homeSnapshot?.primaryCategories.first { $0.id == id }
    }

    func products(
        for categoryID: String,
        subcategoryID: String?
    ) -> [MallProduct] {
        // 首页/分类页商品都从同一份快照中过滤，排序规则保持和搜索“综合”一致。
        let filteredProducts = (homeSnapshot?.products ?? []).filter { product in
            guard product.categoryID == categoryID else {
                return false
            }

            guard let subcategoryID, !subcategoryID.isEmpty else {
                return true
            }
            return product.subcategoryID == subcategoryID
        }

        return filteredProducts.sorted {
            if $0.sortWeight != $1.sortWeight {
                return $0.sortWeight > $1.sortWeight
            }
            if $0.salesCount != $1.salesCount {
                return $0.salesCount > $1.salesCount
            }
            return $0.updatedAt > $1.updatedAt
        }
    }

    private func load(showLoading: Bool) async {
        if showLoading {
            screenState = .loading
        }

        bannerMessage = nil

        do {
            // 首页快照和搜索引导并发加载，减少商城首屏等待时间。
            async let loadedHome = mallService.fetchHome(session: session)
            async let loadedBootstrap = mallService.fetchSearchBootstrap(session: session)

            homeSnapshot = try await loadedHome
            searchBootstrap = try await loadedBootstrap
            hasLoaded = true
            screenState = .loaded
        } catch let error as MallServiceError {
            screenState = .failed(error.textValue)
        } catch {
            screenState = .failed(MallServiceError.networkUnavailable.textValue)
        }
    }

    private func reloadBootstrap() async throws {
        // 搜索历史删除、清空、搜索成功后都复用同一刷新入口。
        searchBootstrap = try await mallService.fetchSearchBootstrap(session: session)
    }
}
