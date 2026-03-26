import Foundation

@MainActor
final class OffersViewModel: ObservableObject {
    enum ScreenState {
        case idle
        case loading
        case loaded
        case failed(LocalizedTextValue)
    }

    @Published private(set) var landingState: ScreenState = .idle
    @Published private(set) var purchaseState: ScreenState = .idle
    @Published private(set) var ordersState: ScreenState = .idle
    @Published private(set) var landingSnapshot: OffersLandingSnapshot?
    @Published private(set) var categories: [OfferCategoryItem] = []
    @Published private(set) var eligibleOffers: [EligibleOfferItem] = []
    @Published private(set) var ordersSnapshot: OffersOrderPageSnapshot?
    @Published var isSubscribedExpanded = true
    @Published var isPurchaseListPresented = false
    @Published var isOrderListPresented = false
    @Published var isFilterSheetPresented = false
    @Published var isOrderFilterPresented = false
    @Published var filterSheetPresentationID = UUID()
    @Published var orderFilter = OffersOrderFilter.empty
    @Published var selectedResourceType: OffersResourceType = .all
    @Published var selectedCategoryID: String?
    @Published var selectedCategoryRootID: String?
    @Published var selectedValidityBuckets: Set<OffersValidityBucket> = []
    @Published var minimumPriceInput = ""
    @Published var maximumPriceInput = ""
    @Published var selectedSortOption: OffersSortOption = .popular
    @Published var selectedDetailOffer: EligibleOfferItem?
    @Published var pendingSubscribeOffer: EligibleOfferItem?
    @Published var pendingUnsubscribeOffer: SubscribedOfferItem?
    @Published var acceptedResult: OfferAcceptedResult?
    @Published var toastMessage: LocalizedTextValue?
    @Published private(set) var isLoadingMoreOrders = false

    private let session: CustSubInfo
    private let offersService: any OffersServicing
    private var hasLoadedPurchase = false
    private var hasLoadedOrders = false
    private let ordersPageSize = 10

    init(session: CustSubInfo, offersService: any OffersServicing) {
        self.session = session
        self.offersService = offersService
    }

    var subscribedOffers: [SubscribedOfferItem] {
        landingSnapshot?.subscribedOffers ?? []
    }

    var hasMoreOrders: Bool {
        guard let ordersSnapshot else {
            return false
        }
        return ordersSnapshot.pageIndex < ordersSnapshot.totalPages
    }

    var filteredEligibleOffers: [EligibleOfferItem] {
        let minimumPrice = parsedPrice(from: minimumPriceInput)
        let maximumPrice = parsedPrice(from: maximumPriceInput)

        let filtered = eligibleOffers.filter { offer in
            if minimumPrice != nil || maximumPrice != nil {
                guard let price = offer.displayPriceValue else {
                    return false
                }

                if let minimumPrice, price < minimumPrice {
                    return false
                }

                if let maximumPrice, price > maximumPrice {
                    return false
                }
            }

            if !selectedValidityBuckets.isEmpty {
                guard let bucket = offer.validityBucket, selectedValidityBuckets.contains(bucket) else {
                    return false
                }
            }

            return true
        }

        switch selectedSortOption {
        case .popular:
            return filtered.sorted { lhs, rhs in
                if lhs.originalIndex != rhs.originalIndex {
                    return lhs.originalIndex < rhs.originalIndex
                }
                return lhs.offerName < rhs.offerName
            }
        case .price:
            let priced = filtered.filter { $0.displayPriceValue != nil }
                .sorted { lhs, rhs in
                    guard let lhsPrice = lhs.displayPriceValue, let rhsPrice = rhs.displayPriceValue else {
                        return lhs.originalIndex < rhs.originalIndex
                    }
                    if lhsPrice != rhsPrice {
                        return lhsPrice < rhsPrice
                    }
                    return lhs.originalIndex < rhs.originalIndex
                }
            let unpriced = filtered.filter { $0.displayPriceValue == nil }
                .sorted { $0.originalIndex < $1.originalIndex }
            return priced + unpriced
        }
    }

    var hasActiveLocalFilters: Bool {
        selectedCategoryID != nil ||
            !minimumPriceInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !maximumPriceInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !selectedValidityBuckets.isEmpty ||
            selectedSortOption != .popular
    }

    func loadLandingIfNeeded() async {
        guard case .idle = landingState else {
            return
        }
        await refreshLanding()
    }

    func refreshLanding() async {
        landingState = .loading
        do {
            landingSnapshot = try await offersService.fetchLanding(session: session)
            landingState = .loaded
        } catch {
            let message = (error as? OffersServiceError)?.textValue ?? .key("offers.state.errorSubtitle")
            landingState = .failed(message)
        }
    }

    func openPurchaseList() {
        isPurchaseListPresented = true
    }

    func openOrderList() {
        isOrderListPresented = true
    }

    func openFilters() {
        filterSheetPresentationID = UUID()
        isFilterSheetPresented = true
    }

    func openOrderFilters() {
        isOrderFilterPresented = true
    }

    func loadPurchaseIfNeeded() async {
        guard !hasLoadedPurchase else {
            return
        }
        hasLoadedPurchase = true
        await refreshPurchaseList()
    }

    func loadOrdersIfNeeded() async {
        guard !hasLoadedOrders else {
            return
        }
        hasLoadedOrders = true
        await refreshOrders()
    }

    func refreshPurchaseList() async {
        purchaseState = .loading
        do {
            async let loadedCategories = offersService.fetchCategories(session: session)
            async let loadedOffers = offersService.fetchEligibleOffers(
                session: session,
                resourceType: selectedResourceType,
                categoryId: selectedCategoryID
            )

            categories = try await loadedCategories
            eligibleOffers = try await loadedOffers
            purchaseState = .loaded
        } catch {
            let message = (error as? OffersServiceError)?.textValue ?? .key("offers.state.errorSubtitle")
            purchaseState = .failed(message)
        }
    }

    func refreshOrders() async {
        let hadLoadedContent = ordersSnapshot != nil && {
            if case .loaded = ordersState {
                return true
            }
            return false
        }()

        if !hadLoadedContent {
            ordersState = .loading
        }

        do {
            ordersSnapshot = try await offersService.fetchOrders(
                session: session,
                filter: orderFilter,
                pageIndex: 1,
                pageSize: ordersPageSize
            )
            ordersState = .loaded
        } catch {
            let message = (error as? OffersServiceError)?.textValue ?? .key("offers.state.errorSubtitle")
            if hadLoadedContent {
                toastMessage = message
                ordersState = .loaded
            } else {
                ordersState = .failed(message)
            }
        }
    }

    func loadMoreOrdersIfNeeded(currentRecord: OffersOrderRecord) async {
        guard let snapshot = ordersSnapshot,
              snapshot.pageIndex < snapshot.totalPages,
              !isLoadingMoreOrders,
              !snapshot.records.isEmpty,
              snapshot.records.last?.id == currentRecord.id else {
            return
        }

        isLoadingMoreOrders = true
        do {
            let nextSnapshot = try await offersService.fetchOrders(
                session: session,
                filter: orderFilter,
                pageIndex: snapshot.pageIndex + 1,
                pageSize: ordersPageSize
            )
            ordersSnapshot = OffersOrderPageSnapshot(
                records: snapshot.records + nextSnapshot.records,
                pageIndex: nextSnapshot.pageIndex,
                pageSize: nextSnapshot.pageSize,
                totalCount: nextSnapshot.totalCount,
                totalPages: nextSnapshot.totalPages
            )
            isLoadingMoreOrders = false
        } catch {
            isLoadingMoreOrders = false
            toastMessage = (error as? OffersServiceError)?.textValue ?? .key("offers.state.errorSubtitle")
        }
    }

    func selectResourceType(_ resourceType: OffersResourceType) {
        guard selectedResourceType != resourceType else {
            return
        }

        selectedResourceType = resourceType
        Task { await refreshPurchaseList() }
    }

    func selectCategory(_ categoryID: String?, rootCategoryID: String? = nil) {
        guard selectedCategoryID != categoryID || selectedCategoryRootID != rootCategoryID else {
            return
        }

        selectedCategoryID = categoryID
        selectedCategoryRootID = rootCategoryID
        Task { await refreshPurchaseList() }
    }

    func toggleValidityBucket(_ bucket: OffersValidityBucket) {
        if selectedValidityBuckets.contains(bucket) {
            selectedValidityBuckets.remove(bucket)
        } else {
            selectedValidityBuckets.insert(bucket)
        }
    }

    func resetFilters() {
        selectedCategoryID = nil
        selectedCategoryRootID = nil
        selectedValidityBuckets.removeAll()
        minimumPriceInput = ""
        maximumPriceInput = ""
        selectedSortOption = .popular
    }

    func applyOrderFilter(_ filter: OffersOrderFilter) {
        guard orderFilter != filter else {
            return
        }
        orderFilter = filter
        Task { await refreshOrders() }
    }

    func resetOrderFilter() {
        applyOrderFilter(.empty)
    }

    func requestSubscribe(_ offer: EligibleOfferItem) {
        pendingSubscribeOffer = offer
    }

    func requestUnsubscribe(_ offer: SubscribedOfferItem) {
        guard offer.canUnsubscribe else {
            return
        }
        pendingUnsubscribeOffer = offer
    }

    func confirmSubscribe(_ offer: EligibleOfferItem) async {
        do {
            let result = try await offersService.submitChange(.subscribe(offer), session: session)
            pendingSubscribeOffer = nil
            acceptedResult = result
        } catch {
            pendingSubscribeOffer = nil
            toastMessage = (error as? OffersServiceError)?.textValue ?? .key("offers.failure.body")
        }
    }

    func confirmUnsubscribe(_ offer: SubscribedOfferItem) async {
        do {
            let result = try await offersService.submitChange(.unsubscribe(offer), session: session)
            pendingUnsubscribeOffer = nil
            acceptedResult = result
        } catch {
            pendingUnsubscribeOffer = nil
            toastMessage = (error as? OffersServiceError)?.textValue ?? .key("offers.failure.body")
        }
    }

    func dismissToast() {
        toastMessage = nil
    }

    func handleAcceptedResultDismiss() {
        acceptedResult = nil
        selectedDetailOffer = nil
        isPurchaseListPresented = false

        Task {
            await refreshSubscribedOffers()
        }
    }

    private func refreshSubscribedOffers() async {
        do {
            let subscribed = try await offersService.fetchSubscribedOffers(session: session)
            if let landingSnapshot {
                self.landingSnapshot = OffersLandingSnapshot(
                    primaryOffer: landingSnapshot.primaryOffer,
                    subscribedOffers: subscribed
                )
            }
            landingState = .loaded
        } catch {
            toastMessage = (error as? OffersServiceError)?.textValue ?? .key("offers.state.errorSubtitle")
        }
    }

    private func parsedPrice(from rawValue: String) -> Decimal? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
    }
}
