import Foundation
import Combine

@MainActor
final class MallViewModel: ObservableObject {
    enum ScreenState: Equatable {
        case idle
        case loading
        case loaded
        case failed(LocalizedTextValue)
    }

    enum ProductFeedState: Equatable {
        case idle
        case loading
        case loaded
        case failed(LocalizedTextValue)
    }

    enum CartState: Equatable {
        case idle
        case loading
        case loaded
        case failed(LocalizedTextValue)
    }

    @Published private(set) var screenState: ScreenState = .idle
    @Published private(set) var homeSnapshot: MallHomeSnapshot?
    @Published private(set) var homeProductFeedState: ProductFeedState = .idle
    @Published private(set) var homeProductFeed: MallHomeProductFeedSnapshot?
    @Published private(set) var isLoadingMoreHomeProducts = false
    @Published private(set) var homeProductFeedLoadMoreError: LocalizedTextValue?
    @Published private(set) var searchBootstrap: MallSearchBootstrap?
    @Published private(set) var bannerMessage: LocalizedTextValue?
    @Published private(set) var cartState: CartState = .idle
    @Published private(set) var cartSnapshot: MallCartSnapshot?

    private let session: CustSubInfo
    private let mallService: any MallServicing
    private var hasLoaded = false
    private var homeProductFeedRequest: HomeProductFeedRequest?
    private var homeProductFeedRequestVersion = 0

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
        } catch let error as MallServiceError {
            bannerMessage = error.textValue
        } catch {
            bannerMessage = .key("mall.search.error.subtitle")
        }
    }

    func clearHistory() async {
        do {
            try await mallService.clearSearchHistory(session: session)
            try await reloadBootstrap()
        } catch let error as MallServiceError {
            bannerMessage = error.textValue
        } catch {
            bannerMessage = .key("mall.search.error.subtitle")
        }
    }

    func loadHomeProductFeed(
        scene: MallHomeProductFeedScene,
        categoryID: String?,
        forceRefresh: Bool = false
    ) async {
        let request = HomeProductFeedRequest(scene: scene, categoryID: normalizedCategoryID(scene: scene, categoryID: categoryID))

        if !forceRefresh,
           request == homeProductFeedRequest,
           homeProductFeed != nil,
           homeProductFeedState == .loaded {
            return
        }

        if !forceRefresh,
           request == homeProductFeedRequest,
           homeProductFeedState == .loading {
            return
        }

        homeProductFeedRequestVersion += 1
        let requestVersion = homeProductFeedRequestVersion
        homeProductFeedRequest = request
        homeProductFeed = nil
        homeProductFeedState = .loading
        homeProductFeedLoadMoreError = nil
        isLoadingMoreHomeProducts = false

        do {
            let snapshot = try await mallService.fetchHomeProductFeed(
                scene: request.scene,
                categoryID: request.categoryID,
                pageNum: MallPaginationDefaults.firstPage,
                pageSize: MallPaginationDefaults.pageSize,
                session: session
            )

            guard requestVersion == homeProductFeedRequestVersion, request == homeProductFeedRequest else {
                return
            }

            homeProductFeed = snapshot
            homeProductFeedState = .loaded
        } catch let error as MallServiceError {
            guard requestVersion == homeProductFeedRequestVersion, request == homeProductFeedRequest else {
                return
            }

            homeProductFeed = nil
            homeProductFeedState = .failed(error.textValue)
        } catch {
            guard requestVersion == homeProductFeedRequestVersion, request == homeProductFeedRequest else {
                return
            }

            homeProductFeed = nil
            homeProductFeedState = .failed(MallServiceError.homeProductFeedUnavailable.textValue)
        }
    }

    func loadMoreHomeProductsIfNeeded(currentProduct: MallProduct) async {
        guard let snapshot = homeProductFeed,
              snapshot.hasMore,
              !isLoadingMoreHomeProducts,
              !snapshot.products.isEmpty,
              snapshot.products.last?.id == currentProduct.id,
              let request = homeProductFeedRequest else {
            return
        }

        isLoadingMoreHomeProducts = true
        homeProductFeedLoadMoreError = nil
        let requestVersion = homeProductFeedRequestVersion

        do {
            let nextSnapshot = try await mallService.fetchHomeProductFeed(
                scene: request.scene,
                categoryID: request.categoryID,
                pageNum: snapshot.pageNum + 1,
                pageSize: snapshot.pageSize,
                session: session
            )

            guard requestVersion == homeProductFeedRequestVersion,
                  request == homeProductFeedRequest else {
                isLoadingMoreHomeProducts = false
                return
            }

            homeProductFeed = MallHomeProductFeedSnapshot(
                scene: nextSnapshot.scene,
                categoryID: nextSnapshot.categoryID,
                pageNum: nextSnapshot.pageNum,
                pageSize: nextSnapshot.pageSize,
                total: nextSnapshot.total,
                hasMore: nextSnapshot.hasMore,
                products: snapshot.products + nextSnapshot.products
            )
            isLoadingMoreHomeProducts = false
        } catch let error as MallServiceError {
            guard requestVersion == homeProductFeedRequestVersion,
                  request == homeProductFeedRequest else {
                isLoadingMoreHomeProducts = false
                return
            }

            isLoadingMoreHomeProducts = false
            homeProductFeedLoadMoreError = error.textValue
        } catch {
            guard requestVersion == homeProductFeedRequestVersion,
                  request == homeProductFeedRequest else {
                isLoadingMoreHomeProducts = false
                return
            }

            isLoadingMoreHomeProducts = false
            homeProductFeedLoadMoreError = MallServiceError.homeProductFeedUnavailable.textValue
        }
    }

    func retryLoadingMoreHomeProducts() async {
        guard let currentProduct = homeProductFeed?.products.last else {
            return
        }

        await loadMoreHomeProductsIfNeeded(currentProduct: currentProduct)
    }

    func searchProducts(
        query: String,
        categoryID: String?,
        sort: MallSearchSortMode,
        order: MallSortOrder,
        pageNum: Int = MallPaginationDefaults.firstPage,
        pageSize: Int = MallPaginationDefaults.pageSize,
        language: AppLanguage
    ) async throws -> MallSearchResultSnapshot {
        let snapshot = try await mallService.searchProducts(
            query: query,
            categoryID: categoryID,
            sort: sort,
            order: order,
            pageNum: pageNum,
            pageSize: pageSize,
            language: language,
            session: session
        )
        if pageNum == MallPaginationDefaults.firstPage {
            // 搜索成功后立即刷新引导数据，让搜索历史和热搜区保持最新状态。
            try await reloadBootstrap()
        }
        return snapshot
    }

    func primaryCategory(id: String) -> MallPrimaryCategory? {
        homeSnapshot?.primaryCategories.first { $0.id == id }
    }

    var cartBadgeCount: Int {
        cartSnapshot?.badgeCount ?? homeSnapshot?.cartBadgeCount ?? 0
    }

    func loadCartIfNeeded() async {
        guard cartState == .idle else {
            return
        }

        await reloadCart(showLoading: true)
    }

    func refreshCart() async {
        await reloadCart(showLoading: cartSnapshot == nil)
    }

    func fetchProductDetailEntry(productID: String) async throws -> MallProductDetailEntry {
        try await mallService.fetchProductDetailEntry(
            productID: productID,
            session: session
        )
    }

    func addCartItem(
        product: MallProduct,
        detailSnapshot: MallProductDetailSnapshot,
        sku: MallProductDetailSKU,
        quantity: Int = 1
    ) async throws {
        let snapshot = try await mallService.addCartItem(
            MallCartAddItemRequest(
                productID: product.id,
                skuID: sku.id,
                title: product.title,
                selectedSummary: detailSnapshot.specificationSummaryValue(for: sku),
                image: sku.previewImage,
                saleLabel: detailSnapshot.saleLabel,
                saleEndsText: sku.originalPrice == nil ? nil : sku.saleEndsText,
                price: sku.price,
                originalPrice: sku.originalPrice,
                quantity: quantity
            ),
            session: session
        )
        cartSnapshot = snapshot
        cartState = .loaded
    }

    func updateCartQuantity(itemID: String, quantity: Int) async throws {
        let snapshot = try await mallService.updateCartItemQuantity(
            MallCartQuantityUpdateRequest(itemID: itemID, quantity: quantity),
            session: session
        )
        cartSnapshot = snapshot
        cartState = .loaded
    }

    func updateCartItemSKU(
        item: MallCartItem,
        detailSnapshot: MallProductDetailSnapshot,
        sku: MallProductDetailSKU
    ) async throws {
        let snapshot = try await mallService.updateCartItemSKU(
            MallCartSKUUpdateRequest(
                itemID: item.id,
                productID: item.productID,
                skuID: sku.id,
                selectedSummary: detailSnapshot.specificationSummaryValue(for: sku),
                image: sku.previewImage,
                saleLabel: detailSnapshot.saleLabel,
                saleEndsText: sku.originalPrice == nil ? nil : sku.saleEndsText,
                price: sku.price,
                originalPrice: sku.originalPrice
            ),
            session: session
        )
        cartSnapshot = snapshot
        cartState = .loaded
    }

    func updateCartSelection(itemIDs: [String], isSelected: Bool) async throws {
        let snapshot = try await mallService.updateCartItemSelection(
            MallCartSelectionUpdateRequest(itemIDs: itemIDs, isSelected: isSelected),
            session: session
        )
        cartSnapshot = snapshot
        cartState = .loaded
    }

    func deleteCartItems(itemIDs: [String]) async throws {
        let snapshot = try await mallService.deleteCartItems(
            MallCartDeleteItemsRequest(itemIDs: itemIDs),
            session: session
        )
        cartSnapshot = snapshot
        cartState = .loaded
    }

    func prepareCartCheckout(itemIDs: [String]) async throws -> MallCartCheckoutPreview {
        try await mallService.prepareCartCheckout(
            MallCartCheckoutRequest(itemIDs: itemIDs),
            session: session
        )
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
            async let loadedCart = mallService.fetchCart(session: session)

            homeSnapshot = try await loadedHome
            searchBootstrap = try await loadedBootstrap
            do {
                cartSnapshot = try await loadedCart
                cartState = .loaded
            } catch let error as MallServiceError {
                cartSnapshot = nil
                cartState = .failed(error.textValue)
            } catch {
                cartSnapshot = nil
                cartState = .failed(MallServiceError.cartUnavailable.textValue)
            }
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

    private func reloadCart(showLoading: Bool) async {
        if showLoading {
            cartState = .loading
        }

        do {
            cartSnapshot = try await mallService.fetchCart(session: session)
            cartState = .loaded
        } catch let error as MallServiceError {
            cartSnapshot = nil
            cartState = .failed(error.textValue)
        } catch {
            cartSnapshot = nil
            cartState = .failed(MallServiceError.cartUnavailable.textValue)
        }
    }

    private func normalizedCategoryID(
        scene: MallHomeProductFeedScene,
        categoryID: String?
    ) -> String? {
        guard scene == .category,
              let categoryID = categoryID?.trimmingCharacters(in: .whitespacesAndNewlines),
              !categoryID.isEmpty else {
            return nil
        }
        return categoryID
    }
}

private struct HomeProductFeedRequest: Equatable {
    let scene: MallHomeProductFeedScene
    let categoryID: String?
}
