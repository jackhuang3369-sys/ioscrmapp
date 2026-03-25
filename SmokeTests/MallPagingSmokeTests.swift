import Foundation

struct CustSubInfo: Sendable {
}

protocol MallServicing: Sendable {
    func fetchHome(session: CustSubInfo) async throws -> MallHomeSnapshot
    func fetchHomeProductFeed(
        scene: MallHomeProductFeedScene,
        categoryID: String?,
        pageNum: Int,
        pageSize: Int,
        session: CustSubInfo
    ) async throws -> MallHomeProductFeedSnapshot
    func fetchSearchBootstrap(session: CustSubInfo) async throws -> MallSearchBootstrap
    func searchProducts(
        query: String,
        categoryID: String?,
        sort: MallSearchSortMode,
        order: MallSortOrder,
        pageNum: Int,
        pageSize: Int,
        language: AppLanguage,
        session: CustSubInfo
    ) async throws -> MallSearchResultSnapshot
    func deleteSearchHistory(keyword: String, session: CustSubInfo) async throws
    func clearSearchHistory(session: CustSubInfo) async throws
}

enum MallServiceError: Error {
    case homeUnavailable
    case homeProductFeedUnavailable
    case searchUnavailable
    case keywordInvalid
    case pageInvalid
    case networkUnavailable

    var textValue: LocalizedTextValue {
        switch self {
        case .homeUnavailable:
            return .key("mall.state.error.subtitle")
        case .homeProductFeedUnavailable:
            return .key("mall.state.error.subtitle")
        case .searchUnavailable:
            return .key("mall.search.error.subtitle")
        case .keywordInvalid:
            return .key("mall.search.validation.empty")
        case .pageInvalid:
            return .key("mall.search.error.subtitle")
        case .networkUnavailable:
            return .key("mall.state.error.subtitle")
        }
    }
}

private struct HomeFeedRequest: Equatable {
    let scene: MallHomeProductFeedScene
    let categoryID: String?
    let pageNum: Int
    let pageSize: Int
}

private struct SearchRequest: Equatable {
    let query: String
    let categoryID: String?
    let sort: MallSearchSortMode
    let order: MallSortOrder
    let pageNum: Int
    let pageSize: Int
    let language: AppLanguage
}

private actor StubMallService: MallServicing {
    private var bootstrap: MallSearchBootstrap
    private let homeSnapshot: MallHomeSnapshot
    private let homeFeedHandler: @Sendable (HomeFeedRequest) -> Result<MallHomeProductFeedSnapshot, MallServiceError>
    private let searchHandler: @Sendable (SearchRequest) -> Result<MallSearchResultSnapshot, MallServiceError>
    private var homeFeedRequests: [HomeFeedRequest] = []
    private var searchRequests: [SearchRequest] = []
    private var bootstrapLoadCount = 0

    init(
        homeSnapshot: MallHomeSnapshot = makeHomeSnapshot(products: []),
        bootstrap: MallSearchBootstrap = MallSearchBootstrap(history: [], hotKeywords: []),
        homeFeedHandler: @escaping @Sendable (HomeFeedRequest) -> Result<MallHomeProductFeedSnapshot, MallServiceError> = {
            .success(
                makeHomeFeedSnapshot(
                    scene: $0.scene,
                    categoryID: $0.categoryID,
                    pageNum: $0.pageNum,
                    pageSize: $0.pageSize,
                    total: 0,
                    hasMore: false,
                    products: []
                )
            )
        },
        searchHandler: @escaping @Sendable (SearchRequest) -> Result<MallSearchResultSnapshot, MallServiceError> = {
            .success(
                MallSearchResultSnapshot(
                    query: $0.query,
                    categoryID: $0.categoryID,
                    pageNum: $0.pageNum,
                    pageSize: $0.pageSize,
                    total: 0,
                    hasMore: false,
                    products: []
                )
            )
        }
    ) {
        self.homeSnapshot = homeSnapshot
        self.bootstrap = bootstrap
        self.homeFeedHandler = homeFeedHandler
        self.searchHandler = searchHandler
    }

    func fetchHome(session: CustSubInfo) async throws -> MallHomeSnapshot {
        homeSnapshot
    }

    func fetchHomeProductFeed(
        scene: MallHomeProductFeedScene,
        categoryID: String?,
        pageNum: Int,
        pageSize: Int,
        session: CustSubInfo
    ) async throws -> MallHomeProductFeedSnapshot {
        let request = HomeFeedRequest(
            scene: scene,
            categoryID: categoryID,
            pageNum: pageNum,
            pageSize: pageSize
        )
        homeFeedRequests.append(request)
        return try homeFeedHandler(request).get()
    }

    func fetchSearchBootstrap(session: CustSubInfo) async throws -> MallSearchBootstrap {
        bootstrapLoadCount += 1
        return bootstrap
    }

    func searchProducts(
        query: String,
        categoryID: String?,
        sort: MallSearchSortMode,
        order: MallSortOrder,
        pageNum: Int,
        pageSize: Int,
        language: AppLanguage,
        session: CustSubInfo
    ) async throws -> MallSearchResultSnapshot {
        let request = SearchRequest(
            query: query,
            categoryID: categoryID,
            sort: sort,
            order: order,
            pageNum: pageNum,
            pageSize: pageSize,
            language: language
        )
        searchRequests.append(request)
        if pageNum == MallPaginationDefaults.firstPage {
            bootstrap.history = [query]
        }
        return try searchHandler(request).get()
    }

    func deleteSearchHistory(keyword: String, session: CustSubInfo) async throws {
        bootstrap.history.removeAll { $0 == keyword }
    }

    func clearSearchHistory(session: CustSubInfo) async throws {
        bootstrap.history.removeAll()
    }

    func recordedHomeFeedRequests() -> [HomeFeedRequest] {
        homeFeedRequests
    }

    func recordedSearchRequests() -> [SearchRequest] {
        searchRequests
    }

    func currentBootstrapLoadCount() -> Int {
        bootstrapLoadCount
    }
}

@main
struct MallPagingSmokeTests {
    static func main() async throws {
        try await testRecommendationFeedLoadsFirstPageAndAppendsNextPage()
        try await testCategorySwitchResetsFeedToFirstPage()
        try await testHomeFeedInitialFailureSetsInlineFailedState()
        try await testHomeFeedLoadMoreFailureKeepsExistingProducts()
        try await testSearchReloadUsesRequestedSortAndFirstPage()
        try await testSearchLoadMoreFailureKeepsExistingResults()
        print("Mall paging smoke tests passed")
    }

    private static func testRecommendationFeedLoadsFirstPageAndAppendsNextPage() async throws {
        let firstPageProducts = makeProducts(range: 1 ... 20, categoryID: "phone")
        let secondPageProducts = makeProducts(range: 21 ... 25, categoryID: "phone")
        let service = StubMallService(
            homeFeedHandler: { request in
                switch (request.scene, request.pageNum) {
                case (.recommendation, 1):
                    return .success(
                        makeHomeFeedSnapshot(
                            scene: .recommendation,
                            categoryID: nil,
                            pageNum: 1,
                            pageSize: request.pageSize,
                            total: 25,
                            hasMore: true,
                            products: firstPageProducts
                        )
                    )
                case (.recommendation, 2):
                    return .success(
                        makeHomeFeedSnapshot(
                            scene: .recommendation,
                            categoryID: nil,
                            pageNum: 2,
                            pageSize: request.pageSize,
                            total: 25,
                            hasMore: false,
                            products: secondPageProducts
                        )
                    )
                default:
                    return .failure(.homeProductFeedUnavailable)
                }
            }
        )
        let viewModel = await MainActor.run { MallViewModel(session: CustSubInfo(), mallService: service) }

        await viewModel.loadHomeProductFeed(scene: .recommendation, categoryID: nil)
        let firstSnapshot = try await MainActor.run {
            try requireHomeFeed(viewModel, "recommendation first page should load")
        }
        try require(firstSnapshot.pageNum == 1, "recommendation feed should start from page 1")
        try require(firstSnapshot.products.count == 20, "recommendation feed should use page size 20 by default")
        try require(firstSnapshot.hasMore, "recommendation feed should expose hasMore on first page")

        let lastProduct = try await MainActor.run {
            try requireHomeFeed(viewModel, "recommendation first page should remain available").products.last
                .unwrap("recommendation first page should contain products")
        }
        await viewModel.loadMoreHomeProductsIfNeeded(currentProduct: lastProduct)

        let appendedSnapshot = try await MainActor.run {
            try requireHomeFeed(viewModel, "recommendation second page should append")
        }
        let recordedRequests = await service.recordedHomeFeedRequests()
        try require(appendedSnapshot.pageNum == 2, "load more should advance to page 2")
        try require(appendedSnapshot.products.count == 25, "load more should append the next page of products")
        try require(!appendedSnapshot.hasMore, "last page should clear hasMore")
        try require(
            recordedRequests == [
                HomeFeedRequest(scene: .recommendation, categoryID: nil, pageNum: 1, pageSize: 20),
                HomeFeedRequest(scene: .recommendation, categoryID: nil, pageNum: 2, pageSize: 20),
            ],
            "recommendation feed should request first page then next page"
        )
    }

    private static func testCategorySwitchResetsFeedToFirstPage() async throws {
        let recommendationProducts = makeProducts(range: 1 ... 20, categoryID: "phone")
        let categoryProducts = makeProducts(range: 201 ... 203, categoryID: "accessory")
        let service = StubMallService(
            homeFeedHandler: { request in
                switch (request.scene, request.categoryID, request.pageNum) {
                case (.recommendation, nil, 1):
                    return .success(
                        makeHomeFeedSnapshot(
                            scene: .recommendation,
                            categoryID: nil,
                            pageNum: 1,
                            pageSize: request.pageSize,
                            total: 20,
                            hasMore: false,
                            products: recommendationProducts
                        )
                    )
                case (.category, "accessory", 1):
                    return .success(
                        makeHomeFeedSnapshot(
                            scene: .category,
                            categoryID: "accessory",
                            pageNum: 1,
                            pageSize: request.pageSize,
                            total: 3,
                            hasMore: false,
                            products: categoryProducts
                        )
                    )
                default:
                    return .failure(.homeProductFeedUnavailable)
                }
            }
        )
        let viewModel = await MainActor.run { MallViewModel(session: CustSubInfo(), mallService: service) }

        await viewModel.loadHomeProductFeed(scene: .recommendation, categoryID: nil)
        await viewModel.loadHomeProductFeed(scene: .category, categoryID: "accessory")

        let categorySnapshot = try await MainActor.run {
            try requireHomeFeed(viewModel, "category feed should replace recommendation feed")
        }
        let recordedRequests = await service.recordedHomeFeedRequests()
        try require(categorySnapshot.scene == .category, "switching category should use category scene")
        try require(categorySnapshot.categoryID == "accessory", "category switch should keep selected category id")
        try require(categorySnapshot.pageNum == 1, "category switch should reset pagination to first page")
        try require(categorySnapshot.products == categoryProducts, "category switch should replace products with category results")
        try require(
            recordedRequests.suffix(1).first == HomeFeedRequest(
                scene: .category,
                categoryID: "accessory",
                pageNum: 1,
                pageSize: 20
            ),
            "category switch should re-request page 1 for the selected category"
        )
    }

    private static func testHomeFeedInitialFailureSetsInlineFailedState() async throws {
        let service = StubMallService(
            homeFeedHandler: { _ in
                .failure(.homeProductFeedUnavailable)
            }
        )
        let viewModel = await MainActor.run { MallViewModel(session: CustSubInfo(), mallService: service) }

        await viewModel.loadHomeProductFeed(scene: .recommendation, categoryID: nil)

        let state = await MainActor.run { viewModel.homeProductFeedState }
        let snapshot = await MainActor.run { viewModel.homeProductFeed }
        try require(
            state == .failed(.key("mall.state.error.subtitle")),
            "initial product feed failure should surface inline failed state"
        )
        try require(snapshot == nil, "initial product feed failure should not keep stale snapshot")
    }

    private static func testHomeFeedLoadMoreFailureKeepsExistingProducts() async throws {
        let firstPageProducts = makeProducts(range: 1 ... 20, categoryID: "phone")
        let service = StubMallService(
            homeFeedHandler: { request in
                switch request.pageNum {
                case 1:
                    return .success(
                        makeHomeFeedSnapshot(
                            scene: request.scene,
                            categoryID: request.categoryID,
                            pageNum: 1,
                            pageSize: request.pageSize,
                            total: 25,
                            hasMore: true,
                            products: firstPageProducts
                        )
                    )
                default:
                    return .failure(.homeProductFeedUnavailable)
                }
            }
        )
        let viewModel = await MainActor.run { MallViewModel(session: CustSubInfo(), mallService: service) }

        await viewModel.loadHomeProductFeed(scene: .recommendation, categoryID: nil)
        let lastProduct = try await MainActor.run {
            try requireHomeFeed(viewModel, "first page should load before testing load-more failure").products.last
                .unwrap("first page should contain a last product")
        }
        await viewModel.loadMoreHomeProductsIfNeeded(currentProduct: lastProduct)

        let snapshot = try await MainActor.run {
            try requireHomeFeed(viewModel, "load-more failure should keep existing products")
        }
        let loadMoreError = await MainActor.run { viewModel.homeProductFeedLoadMoreError }
        try require(snapshot.products == firstPageProducts, "load-more failure should preserve already loaded products")
        try require(
            loadMoreError == .key("mall.state.error.subtitle"),
            "load-more failure should expose retryable inline error"
        )
    }

    private static func testSearchReloadUsesRequestedSortAndFirstPage() async throws {
        let service = StubMallService(
            searchHandler: { request in
                .success(
                    MallSearchResultSnapshot(
                        query: request.query,
                        categoryID: request.categoryID,
                        pageNum: request.pageNum,
                        pageSize: request.pageSize,
                        total: 2,
                        hasMore: false,
                        products: makeProducts(range: 1 ... 2, categoryID: "phone")
                    )
                )
            }
        )
        let viewModel = await MainActor.run { MallViewModel(session: CustSubInfo(), mallService: service) }

        let ascendingSnapshot = try await viewModel.searchProducts(
            query: "router",
            categoryID: "phone",
            sort: .price,
            order: .ascending,
            pageNum: 1,
            pageSize: 20,
            language: .english
        )
        let salesSnapshot = try await viewModel.searchProducts(
            query: "router",
            categoryID: "phone",
            sort: .sales,
            order: .descending,
            pageNum: 1,
            pageSize: 20,
            language: .english
        )

        let recordedRequests = await service.recordedSearchRequests()
        let bootstrapLoadCount = await service.currentBootstrapLoadCount()
        try require(ascendingSnapshot.pageNum == 1, "search reload should request page 1")
        try require(salesSnapshot.pageNum == 1, "sort change should also restart from page 1")
        try require(
            recordedRequests == [
                SearchRequest(
                    query: "router",
                    categoryID: "phone",
                    sort: .price,
                    order: .ascending,
                    pageNum: 1,
                    pageSize: 20,
                    language: .english
                ),
                SearchRequest(
                    query: "router",
                    categoryID: "phone",
                    sort: .sales,
                    order: .descending,
                    pageNum: 1,
                    pageSize: 20,
                    language: .english
                ),
            ],
            "search reload should forward the selected sort, order and first-page parameters"
        )
        try require(bootstrapLoadCount == 2, "successful first-page searches should refresh search bootstrap")
    }

    private static func testSearchLoadMoreFailureKeepsExistingResults() async throws {
        let firstPageProducts = makeProducts(range: 1 ... 20, categoryID: "phone")
        let service = StubMallService(
            searchHandler: { request in
                switch request.pageNum {
                case 1:
                    return .success(
                        MallSearchResultSnapshot(
                            query: request.query,
                            categoryID: request.categoryID,
                            pageNum: 1,
                            pageSize: request.pageSize,
                            total: 25,
                            hasMore: true,
                            products: firstPageProducts
                        )
                    )
                default:
                    return .failure(.searchUnavailable)
                }
            }
        )
        let viewModel = await MainActor.run { MallViewModel(session: CustSubInfo(), mallService: service) }

        var displayedSnapshot = try await viewModel.searchProducts(
            query: "router",
            categoryID: "phone",
            sort: .best,
            order: .descending,
            pageNum: 1,
            pageSize: 20,
            language: .english
        )

        do {
            let nextSnapshot = try await viewModel.searchProducts(
                query: displayedSnapshot.query,
                categoryID: displayedSnapshot.categoryID,
                sort: .best,
                order: .descending,
                pageNum: 2,
                pageSize: displayedSnapshot.pageSize,
                language: .english
            )
            displayedSnapshot = MallSearchResultSnapshot(
                query: nextSnapshot.query,
                categoryID: nextSnapshot.categoryID,
                pageNum: nextSnapshot.pageNum,
                pageSize: nextSnapshot.pageSize,
                total: nextSnapshot.total,
                hasMore: nextSnapshot.hasMore,
                products: displayedSnapshot.products + nextSnapshot.products
            )
        } catch {
            // 结果页加载更多失败时保留当前结果集并展示重试入口。
        }

        try require(displayedSnapshot.products == firstPageProducts, "search load-more failure should keep existing results")
        try require(displayedSnapshot.pageNum == 1, "search load-more failure should not advance the current page")
    }

    @MainActor
    private static func requireHomeFeed(
        _ viewModel: MallViewModel,
        _ message: String
    ) throws -> MallHomeProductFeedSnapshot {
        try viewModel.homeProductFeed.unwrap(message)
    }
}

private func makeHomeSnapshot(products: [MallProduct]) -> MallHomeSnapshot {
    MallHomeSnapshot(
        searchPlaceholder: MallLocalizedString("搜索商品", "Search products", "ابحث عن المنتجات"),
        recommendation: MallHomeRecommendationContent(
            tabTitle: MallLocalizedString("推荐", "Featured", "موصى به"),
            highlightSectionTitle: MallLocalizedString("焦点", "Highlights", "أبرز المنتجات"),
            highlightCards: [],
            activitySectionTitle: MallLocalizedString("活动", "Campaigns", "الحملات"),
            activityCards: [],
            productSectionTitle: MallLocalizedString("精选好物", "Featured Picks", "مختارات")
        ),
        primaryCategories: [],
        products: products,
        defaultCategoryID: "phone",
        cartBadgeCount: 0
    )
}

private func makeHomeFeedSnapshot(
    scene: MallHomeProductFeedScene,
    categoryID: String?,
    pageNum: Int,
    pageSize: Int,
    total: Int,
    hasMore: Bool,
    products: [MallProduct]
) -> MallHomeProductFeedSnapshot {
    MallHomeProductFeedSnapshot(
        scene: scene,
        categoryID: categoryID,
        pageNum: pageNum,
        pageSize: pageSize,
        total: total,
        hasMore: hasMore,
        products: products
    )
}

private func makeProducts(
    range: ClosedRange<Int>,
    categoryID: String
) -> [MallProduct] {
    range.map { index in
        MallProduct(
            id: "product-\(index)",
            categoryID: categoryID,
            subcategoryID: "subcategory-\(categoryID)",
            thirdCategoryID: "third-\(categoryID)",
            title: MallLocalizedString("商品\(index)", "Product \(index)", "المنتج \(index)"),
            subtitle: MallLocalizedString("副标题\(index)", "Subtitle \(index)", "الوصف \(index)"),
            coverImage: .system(name: "shippingbox", backgroundHex: 0xEEF4FA, tintHex: 0x4F5D75),
            detailMediaList: [],
            price: Decimal(index),
            originalPrice: Decimal(index + 1),
            badge: MallProductBadge(
                title: MallLocalizedString("精选", "Featured", "مميز"),
                style: .featured
            ),
            tags: [MallLocalizedString("标签\(index)", "Tag \(index)", "وسم \(index)")],
            salesCount: 100 + index,
            sortWeight: 1_000 - index,
            updatedAt: Date(timeIntervalSince1970: TimeInterval(index)),
            detailTarget: "mall://product/\(index)"
        )
    }
}

private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw NSError(domain: "MallPagingSmokeTests", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

private extension Optional {
    func unwrap(_ message: String) throws -> Wrapped {
        guard let value = self else {
            throw NSError(domain: "MallPagingSmokeTests", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        }
        return value
    }
}
