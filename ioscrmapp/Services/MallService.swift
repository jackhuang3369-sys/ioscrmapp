import Foundation
import os

private let mallLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "ioscrmapp",
    category: "Mall"
)

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
    case featureUnavailable(message: String)
    case tooManyRequests
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
        case let .featureUnavailable(message):
            return .literal(message)
        case .tooManyRequests:
            return .key("common.error.tooManyRequests")
        case .networkUnavailable:
            return .key("mall.state.error.subtitle")
        }
    }
}

actor MockMallService: MallServicing {
    private let homeSnapshot = MallMockData.makeHomeSnapshot()
    private let hotKeywords = MallMockData.makeHotKeywords()
    private var searchHistory = MallMockData.defaultSearchHistory

    func fetchHome(session: CustSubInfo) async throws -> MallHomeSnapshot {
        try await Task.sleep(nanoseconds: 120_000_000)
        return homeSnapshot
    }

    func fetchHomeProductFeed(
        scene: MallHomeProductFeedScene,
        categoryID: String?,
        pageNum: Int,
        pageSize: Int,
        session: CustSubInfo
    ) async throws -> MallHomeProductFeedSnapshot {
        guard pageNum >= MallPaginationDefaults.firstPage, pageSize > 0 else {
            throw MallServiceError.pageInvalid
        }

        try await Task.sleep(nanoseconds: 90_000_000)

        let filteredProducts = homeProducts(for: scene, categoryID: categoryID)
        let pagedProducts = pageProducts(filteredProducts, pageNum: pageNum, pageSize: pageSize)

        return MallHomeProductFeedSnapshot(
            scene: scene,
            categoryID: scene == .category ? categoryID : nil,
            pageNum: pageNum,
            pageSize: pageSize,
            total: filteredProducts.count,
            hasMore: pageNum * pageSize < filteredProducts.count,
            products: pagedProducts
        )
    }

    func fetchSearchBootstrap(session: CustSubInfo) async throws -> MallSearchBootstrap {
        try await Task.sleep(nanoseconds: 80_000_000)
        return MallSearchBootstrap(history: searchHistory, hotKeywords: hotKeywords)
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
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty, normalizedQuery.count <= 50 else {
            throw MallServiceError.keywordInvalid
        }
        guard pageNum >= MallPaginationDefaults.firstPage, pageSize > 0 else {
            throw MallServiceError.pageInvalid
        }

        try await Task.sleep(nanoseconds: 90_000_000)

        var filteredProducts = homeSnapshot.products.filter { product in
            product.matches(query: normalizedQuery, language: language)
        }

        if let categoryID, !categoryID.isEmpty {
            filteredProducts = filteredProducts.filter { product in
                product.categoryID == categoryID
                    || product.subcategoryID == categoryID
                    || product.thirdCategoryID == categoryID
            }
        }

        if filteredProducts.isEmpty,
           let categoryID,
           !categoryID.isEmpty,
           isKnownThirdCategoryQuery(
               normalizedQuery,
               within: categoryID,
               language: language
           ) {
            // 三级分类入口会把分类标题直接当作搜索词传进来，这里兜底返回该分类下的商品。
            filteredProducts = homeSnapshot.products.filter { product in
                product.categoryID == categoryID
                    || product.subcategoryID == categoryID
                    || product.thirdCategoryID == categoryID
            }
        }

        filteredProducts = sortProducts(
            filteredProducts,
            sort: sort,
            order: order
        )
        let pagedProducts = pageProducts(filteredProducts, pageNum: pageNum, pageSize: pageSize)

        searchHistory = [normalizedQuery] + searchHistory.filter { $0 != normalizedQuery }
        if searchHistory.count > 6 {
            searchHistory = Array(searchHistory.prefix(6))
        }

        return MallSearchResultSnapshot(
            query: normalizedQuery,
            categoryID: categoryID,
            pageNum: pageNum,
            pageSize: pageSize,
            total: filteredProducts.count,
            hasMore: pageNum * pageSize < filteredProducts.count,
            products: pagedProducts
        )
    }

    func deleteSearchHistory(keyword: String, session: CustSubInfo) async throws {
        searchHistory.removeAll { $0 == keyword }
    }

    func clearSearchHistory(session: CustSubInfo) async throws {
        searchHistory.removeAll()
    }

    private func homeProducts(
        for scene: MallHomeProductFeedScene,
        categoryID: String?
    ) -> [MallProduct] {
        switch scene {
        case .recommendation:
            return sortProducts(homeSnapshot.products, sort: .best, order: .descending)
        case .category:
            let filteredProducts = homeSnapshot.products.filter { product in
                guard let categoryID, !categoryID.isEmpty else {
                    return false
                }
                return product.categoryID == categoryID
                    || product.subcategoryID == categoryID
                    || product.thirdCategoryID == categoryID
            }
            return sortProducts(filteredProducts, sort: .best, order: .descending)
        }
    }

    private func sortProducts(
        _ products: [MallProduct],
        sort: MallSearchSortMode,
        order: MallSortOrder
    ) -> [MallProduct] {
        switch sort {
        case .best:
            return products.sorted {
                if $0.sortWeight != $1.sortWeight {
                    return $0.sortWeight > $1.sortWeight
                }
                if $0.salesCount != $1.salesCount {
                    return $0.salesCount > $1.salesCount
                }
                return $0.updatedAt > $1.updatedAt
            }
        case .sales:
            return products.sorted {
                if order == .ascending {
                    return $0.salesCount < $1.salesCount
                }
                return $0.salesCount > $1.salesCount
            }
        case .price:
            return products.sorted {
                if order == .ascending {
                    return $0.price < $1.price
                }
                return $0.price > $1.price
            }
        case .newest:
            return products.sorted { $0.updatedAt > $1.updatedAt }
        }
    }

    private func isKnownThirdCategoryQuery(
        _ normalizedQuery: String,
        within categoryID: String,
        language: AppLanguage
    ) -> Bool {
        guard !normalizedQuery.isEmpty else {
            return false
        }

        for category in homeSnapshot.primaryCategories {
            if category.id == categoryID {
                let titles = category.subcategories.flatMap(\.thirdCategories).map { item in
                    item.title.value(for: language)
                }
                return titles.contains { normalizeQuery($0) == normalizedQuery }
            }

            if let subcategory = category.subcategories.first(where: { $0.id == categoryID }) {
                let titles = subcategory.thirdCategories.map { item in
                    item.title.value(for: language)
                }
                return titles.contains { normalizeQuery($0) == normalizedQuery }
            }

            for subcategory in category.subcategories {
                if let thirdCategory = subcategory.thirdCategories.first(where: { $0.id == categoryID }) {
                    return normalizeQuery(thirdCategory.title.value(for: language)) == normalizedQuery
                }
            }
        }

        return false
    }

    private func normalizeQuery(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    private func pageProducts(
        _ products: [MallProduct],
        pageNum: Int,
        pageSize: Int
    ) -> [MallProduct] {
        let startIndex = max(0, (pageNum - 1) * pageSize)
        guard startIndex < products.count else {
            return []
        }
        let endIndex = min(products.count, startIndex + pageSize)
        return Array(products[startIndex..<endIndex])
    }
}

struct RemoteMallService: MallServicing {
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

    func fetchHome(session: CustSubInfo) async throws -> MallHomeSnapshot {
        do {
            let responseData = try await client.get(
                MallAPI.home,
                query: ["lang": MallRequestLanguage.currentCode()]
            )
            return try MallResponseMapper.mapHome(from: responseData)
        } catch let error as HTTPClient.ClientError {
            mallLogger.error("Fetch mall home failed: \(String(describing: error), privacy: .public)")
            throw mapClientError(error, fallback: .homeUnavailable)
        } catch let error as MallServiceError {
            throw error
        } catch {
            throw MallServiceError.networkUnavailable
        }
    }

    func fetchHomeProductFeed(
        scene: MallHomeProductFeedScene,
        categoryID: String?,
        pageNum: Int,
        pageSize: Int,
        session: CustSubInfo
    ) async throws -> MallHomeProductFeedSnapshot {
        guard pageNum >= MallPaginationDefaults.firstPage, pageSize > 0 else {
            throw MallServiceError.pageInvalid
        }

        var requestQuery: [String: Any] = [
            "scene": scene.rawValue,
            "pageNum": pageNum,
            "pageSize": pageSize,
            "lang": MallRequestLanguage.currentCode()
        ]

        if let categoryID, !categoryID.isEmpty {
            requestQuery["categoryId"] = categoryID
        }

        do {
            let responseData = try await client.get(MallAPI.homeProducts, query: requestQuery)
            return try MallResponseMapper.mapHomeProductFeed(from: responseData)
        } catch let error as HTTPClient.ClientError {
            mallLogger.error("Fetch mall home product feed failed: \(String(describing: error), privacy: .public)")
            throw mapClientError(error, fallback: .homeProductFeedUnavailable)
        } catch let error as MallServiceError {
            throw error
        } catch {
            throw MallServiceError.networkUnavailable
        }
    }

    func fetchSearchBootstrap(session: CustSubInfo) async throws -> MallSearchBootstrap {
        do {
            let responseData = try await client.get(
                MallAPI.searchBootstrap,
                query: ["lang": MallRequestLanguage.currentCode()]
            )
            return try MallResponseMapper.mapSearchBootstrap(from: responseData)
        } catch let error as HTTPClient.ClientError {
            mallLogger.error("Fetch mall bootstrap failed: \(String(describing: error), privacy: .public)")
            throw mapClientError(error, fallback: .searchUnavailable)
        } catch let error as MallServiceError {
            throw error
        } catch {
            throw MallServiceError.networkUnavailable
        }
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
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty, normalizedQuery.count <= 50 else {
            throw MallServiceError.keywordInvalid
        }
        guard pageNum >= MallPaginationDefaults.firstPage, pageSize > 0 else {
            throw MallServiceError.pageInvalid
        }

        var requestQuery: [String: Any] = [
            "query": normalizedQuery,
            "sort": sort.rawValue,
            "order": order.rawValue,
            "pageNum": pageNum,
            "pageSize": pageSize,
            "lang": language.rawValue
        ]

        if let categoryID, !categoryID.isEmpty {
            requestQuery["categoryId"] = categoryID
        }

        do {
            let responseData = try await client.get(MallAPI.searchResults, query: requestQuery)
            return try MallResponseMapper.mapSearchResults(from: responseData)
        } catch let error as HTTPClient.ClientError {
            mallLogger.error("Search mall products failed: \(String(describing: error), privacy: .public)")
            throw mapClientError(error, fallback: .searchUnavailable)
        } catch let error as MallServiceError {
            throw error
        } catch {
            throw MallServiceError.networkUnavailable
        }
    }

    func deleteSearchHistory(keyword: String, session: CustSubInfo) async throws {
        do {
            let responseData = try await client.post(
                MallAPI.deleteSearchHistory,
                body: ["keyword": keyword]
            )
            guard MallResponseMapper.mapBoolean(from: responseData) else {
                throw MallServiceError.searchUnavailable
            }
        } catch let error as HTTPClient.ClientError {
            mallLogger.error("Delete mall search history failed: \(String(describing: error), privacy: .public)")
            throw mapClientError(error, fallback: .searchUnavailable)
        } catch let error as MallServiceError {
            throw error
        } catch {
            throw MallServiceError.networkUnavailable
        }
    }

    func clearSearchHistory(session: CustSubInfo) async throws {
        do {
            let responseData = try await client.post(MallAPI.clearSearchHistory)
            guard MallResponseMapper.mapBoolean(from: responseData) else {
                throw MallServiceError.searchUnavailable
            }
        } catch let error as HTTPClient.ClientError {
            mallLogger.error("Clear mall search history failed: \(String(describing: error), privacy: .public)")
            throw mapClientError(error, fallback: .searchUnavailable)
        } catch let error as MallServiceError {
            throw error
        } catch {
            throw MallServiceError.networkUnavailable
        }
    }

    private func mapClientError(
        _ error: HTTPClient.ClientError,
        fallback: MallServiceError
    ) -> MallServiceError {
        switch error {
        case let .business(code, message, _):
            switch code {
            case 50_016:
                return .homeUnavailable
            case 50_024, 50_025:
                return .homeProductFeedUnavailable
            case 50_017, 50_020:
                return .searchUnavailable
            case 50_018:
                return .keywordInvalid
            case 50_019:
                return .pageInvalid
            default:
                let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmedMessage.isEmpty ? fallback : .featureUnavailable(message: trimmedMessage)
            }
        case .tooManyRequests:
            return .tooManyRequests
        case .networkUnavailable:
            return .networkUnavailable
        default:
            return fallback
        }
    }
}

private enum MallRequestLanguage {
    private static let storedLanguageKey = "app.language"

    static func currentCode(defaults: UserDefaults = .standard) -> String {
        if let storedLanguage = defaults.string(forKey: storedLanguageKey)
            .flatMap(AppLanguage.init(rawValue:))
        {
            return storedLanguage.rawValue
        }

        return Locale.preferredLanguages.first ?? AppLanguage.fallback.rawValue
    }
}

private enum MallResponseMapper {
    private static let fallbackLocalizedValue = MallLocalizedString("推荐", "Featured", "مميز")

    static func mapHome(from responseData: HTTPClient.ResponseData) throws -> MallHomeSnapshot {
        let payload = try object(from: responseData)
        return MallHomeSnapshot(
            searchPlaceholder: localizedString(in: payload, keys: ["searchPlaceholder"]),
            recommendation: try mapRecommendation(in: payload, keys: ["recommendation"]),
            primaryCategories: try objectArray(in: payload, keys: ["primaryCategories"]).map(mapPrimaryCategory),
            products: try objectArray(in: payload, keys: ["products"]).map(mapProduct),
            defaultCategoryID: string(in: payload, keys: ["defaultCategoryID", "defaultCategoryId"]) ?? "",
            cartBadgeCount: int(in: payload, keys: ["cartBadgeCount"]) ?? 0
        )
    }

    static func mapSearchBootstrap(from responseData: HTTPClient.ResponseData) throws -> MallSearchBootstrap {
        let payload = try object(from: responseData)
        return MallSearchBootstrap(
            history: stringArray(in: payload, keys: ["history"]),
            hotKeywords: try objectArray(in: payload, keys: ["hotKeywords"]).map(mapHotKeyword)
        )
    }

    static func mapHomeProductFeed(from responseData: HTTPClient.ResponseData) throws -> MallHomeProductFeedSnapshot {
        let payload = try object(from: responseData)
        let sceneRawValue = string(in: payload, keys: ["scene"]) ?? MallHomeProductFeedScene.recommendation.rawValue
        let scene = MallHomeProductFeedScene(rawValue: sceneRawValue) ?? .recommendation
        return MallHomeProductFeedSnapshot(
            scene: scene,
            categoryID: string(in: payload, keys: ["categoryID", "categoryId"]),
            pageNum: int(in: payload, keys: ["pageNum"]) ?? MallPaginationDefaults.firstPage,
            pageSize: int(in: payload, keys: ["pageSize"]) ?? MallPaginationDefaults.pageSize,
            total: int(in: payload, keys: ["total"]) ?? 0,
            hasMore: bool(in: payload, keys: ["hasMore"]) ?? false,
            products: try objectArray(in: payload, keys: ["products"]).map(mapProduct)
        )
    }

    static func mapSearchResults(from responseData: HTTPClient.ResponseData) throws -> MallSearchResultSnapshot {
        let payload = try object(from: responseData)
        return MallSearchResultSnapshot(
            query: string(in: payload, keys: ["query"]) ?? "",
            categoryID: string(in: payload, keys: ["categoryID", "categoryId"]),
            pageNum: int(in: payload, keys: ["pageNum"]) ?? MallPaginationDefaults.firstPage,
            pageSize: int(in: payload, keys: ["pageSize"]) ?? MallPaginationDefaults.pageSize,
            total: int(in: payload, keys: ["total"]) ?? 0,
            hasMore: bool(in: payload, keys: ["hasMore"]) ?? false,
            products: try objectArray(in: payload, keys: ["products"]).map(mapProduct)
        )
    }

    static func mapBoolean(from responseData: HTTPClient.ResponseData) -> Bool {
        switch responseData {
        case let .bool(value):
            return value
        case let .number(value):
            return value != 0
        case let .string(value):
            return ["1", "true", "success"].contains(value.lowercased())
        case .null:
            return true
        default:
            return false
        }
    }

    private static func mapRecommendation(
        in dictionary: [String: HTTPClient.ResponseData],
        keys: [String]
    ) throws -> MallHomeRecommendationContent {
        guard let payload = object(in: dictionary, keys: keys) else {
            return MallHomeRecommendationContent(
                tabTitle: emptyLocalizedString(),
                highlightSectionTitle: emptyLocalizedString(),
                highlightCards: [],
                activitySectionTitle: emptyLocalizedString(),
                activityCards: [],
                productSectionTitle: emptyLocalizedString()
            )
        }

        return MallHomeRecommendationContent(
            tabTitle: localizedString(in: payload, keys: ["tabTitle"]),
            highlightSectionTitle: localizedString(in: payload, keys: ["highlightSectionTitle"]),
            highlightCards: try objectArray(in: payload, keys: ["highlightCards"]).map(mapHighlightCard),
            activitySectionTitle: localizedString(in: payload, keys: ["activitySectionTitle"]),
            activityCards: try objectArray(in: payload, keys: ["activityCards"]).map(mapActivityCard),
            productSectionTitle: localizedString(in: payload, keys: ["productSectionTitle"])
        )
    }

    private static func mapPrimaryCategory(_ dictionary: [String: HTTPClient.ResponseData]) throws -> MallPrimaryCategory {
        MallPrimaryCategory(
            id: string(in: dictionary, keys: ["id"]) ?? "",
            title: localizedString(in: dictionary, keys: ["title"]),
            subcategories: try objectArray(in: dictionary, keys: ["subcategories"]).map(mapSubcategory)
        )
    }

    private static func mapSubcategory(_ dictionary: [String: HTTPClient.ResponseData]) throws -> MallSubcategory {
        MallSubcategory(
            id: string(in: dictionary, keys: ["id"]) ?? "",
            title: localizedString(in: dictionary, keys: ["title"]),
            image: imageSource(in: dictionary, keys: ["image"]),
            thirdCategories: try objectArray(in: dictionary, keys: ["thirdCategories"]).map(mapThirdCategory)
        )
    }

    private static func mapThirdCategory(_ dictionary: [String: HTTPClient.ResponseData]) throws -> MallThirdCategory {
        MallThirdCategory(
            id: string(in: dictionary, keys: ["id"]) ?? "",
            title: localizedString(in: dictionary, keys: ["title"]),
            image: imageSource(in: dictionary, keys: ["image"])
        )
    }

    private static func mapHighlightCard(_ dictionary: [String: HTTPClient.ResponseData]) throws -> MallHomeHighlightCard {
        MallHomeHighlightCard(
            id: string(in: dictionary, keys: ["id"]) ?? "",
            badge: localizedString(in: dictionary, keys: ["badge"]),
            title: localizedString(in: dictionary, keys: ["title"]),
            subtitle: localizedString(in: dictionary, keys: ["subtitle"]),
            image: imageSource(in: dictionary, keys: ["image"]),
            startHex: uint32(in: dictionary, keys: ["startHex"]) ?? 0,
            endHex: uint32(in: dictionary, keys: ["endHex"]) ?? 0,
            productID: string(in: dictionary, keys: ["productID", "productId"]) ?? ""
        )
    }

    private static func mapActivityCard(_ dictionary: [String: HTTPClient.ResponseData]) throws -> MallHomeActivityCard {
        MallHomeActivityCard(
            id: string(in: dictionary, keys: ["id"]) ?? "",
            tag: localizedString(in: dictionary, keys: ["tag"]),
            title: localizedString(in: dictionary, keys: ["title"]),
            subtitle: localizedString(in: dictionary, keys: ["subtitle"]),
            image: imageSource(in: dictionary, keys: ["image"]),
            startHex: uint32(in: dictionary, keys: ["startHex"]) ?? 0,
            endHex: uint32(in: dictionary, keys: ["endHex"]) ?? 0,
            categoryID: string(in: dictionary, keys: ["categoryID", "categoryId"]) ?? "",
            subcategoryID: string(in: dictionary, keys: ["subcategoryID", "subcategoryId"])
        )
    }

    private static func mapProduct(_ dictionary: [String: HTTPClient.ResponseData]) throws -> MallProduct {
        MallProduct(
            id: string(in: dictionary, keys: ["id"]) ?? "",
            categoryID: string(in: dictionary, keys: ["categoryID", "categoryId"]) ?? "",
            subcategoryID: string(in: dictionary, keys: ["subcategoryID", "subcategoryId"]) ?? "",
            thirdCategoryID: string(in: dictionary, keys: ["thirdCategoryID", "thirdCategoryId"]) ?? "",
            title: localizedString(in: dictionary, keys: ["title"]),
            subtitle: localizedString(in: dictionary, keys: ["subtitle"]),
            coverImage: remoteImageSource(in: dictionary, keys: ["coverImageUrl", "coverImageURL"]),
            detailMediaList: detailMediaList(in: dictionary, keys: ["detailMediaList"]),
            price: decimal(in: dictionary, keys: ["price"]) ?? .zero,
            originalPrice: decimal(in: dictionary, keys: ["originalPrice"]),
            badge: productBadge(in: dictionary, keys: ["badge"]),
            tags: localizedStringArray(in: dictionary, keys: ["tags"]),
            salesCount: int(in: dictionary, keys: ["salesCount"]) ?? 0,
            sortWeight: int(in: dictionary, keys: ["sortWeight"]) ?? 0,
            updatedAt: date(in: dictionary, keys: ["updatedAt"]) ?? .distantPast,
            detailTarget: string(in: dictionary, keys: ["detailTarget"]) ?? ""
        )
    }

    private static func mapProductDetailMedia(
        _ dictionary: [String: HTTPClient.ResponseData]
    ) -> MallProductDetailMedia? {
        guard
            let id = string(in: dictionary, keys: ["id"]),
            let url = url(in: dictionary, keys: ["url", "mediaUrl"])
        else {
            return nil
        }

        let type = string(in: dictionary, keys: ["type", "mediaType"])
            .flatMap { MallProductDetailMediaType(rawValue: $0.lowercased()) }
            ?? .image
        return MallProductDetailMedia(id: id, type: type, url: url)
    }

    private static func mapHotKeyword(_ dictionary: [String: HTTPClient.ResponseData]) throws -> MallHotKeyword {
        MallHotKeyword(
            id: string(in: dictionary, keys: ["id"]) ?? "",
            title: localizedString(in: dictionary, keys: ["title"]),
            meta: localizedString(in: dictionary, keys: ["meta"])
        )
    }

    private static func productBadge(
        in dictionary: [String: HTTPClient.ResponseData],
        keys: [String]
    ) -> MallProductBadge {
        guard let payload = object(in: dictionary, keys: keys) else {
            return MallProductBadge(title: fallbackLocalizedValue, style: .featured)
        }

        let title = localizedString(in: payload, keys: ["title"])
        let resolvedTitle = isEmpty(title) ? fallbackLocalizedValue : title
        let style = string(in: payload, keys: ["style"])
            .flatMap { MallProductBadgeStyle(rawValue: $0.lowercased()) }
            ?? .featured
        return MallProductBadge(title: resolvedTitle, style: style)
    }

    private static func localizedString(
        in dictionary: [String: HTTPClient.ResponseData],
        keys: [String]
    ) -> MallLocalizedString {
        guard let payload = object(in: dictionary, keys: keys) else {
            return emptyLocalizedString()
        }
        return localizedString(from: payload)
    }

    private static func localizedString(from dictionary: [String: HTTPClient.ResponseData]) -> MallLocalizedString {
        let simplifiedChinese = string(in: dictionary, keys: ["simplifiedChinese"]) ?? ""
        let english = string(in: dictionary, keys: ["english"]) ?? ""
        let arabic = string(in: dictionary, keys: ["arabic"]) ?? ""
        let fallback = firstNonEmpty([simplifiedChinese, english, arabic]) ?? ""

        return MallLocalizedString(
            simplifiedChinese.isEmpty ? fallback : simplifiedChinese,
            english.isEmpty ? fallback : english,
            arabic.isEmpty ? fallback : arabic
        )
    }

    private static func localizedStringArray(
        in dictionary: [String: HTTPClient.ResponseData],
        keys: [String]
    ) -> [MallLocalizedString] {
        guard let responseArray = array(in: dictionary, keys: keys) else {
            return []
        }

        return responseArray.compactMap { responseData in
            guard let payload = responseData.objectValue else {
                return nil
            }
            let value = localizedString(from: payload)
            return isEmpty(value) ? nil : value
        }
    }

    private static func imageSource(
        in dictionary: [String: HTTPClient.ResponseData],
        keys: [String]
    ) -> MallImageSource {
        guard let payload = object(in: dictionary, keys: keys) else {
            return fallbackImageSource()
        }

        if let url = url(in: payload, keys: ["url", "imageUrl", "imageURL"]) {
            return .remote(url: url)
        }

        let type = string(in: payload, keys: ["type"])?.lowercased()
        if let assetName = string(in: payload, keys: ["assetName"]), !assetName.isEmpty {
            if type == nil || type == "asset" {
                return .asset(name: assetName)
            }
        }

        if let systemName = string(in: payload, keys: ["systemName"]), !systemName.isEmpty {
            return .system(
                name: systemName,
                backgroundHex: uint32(in: payload, keys: ["backgroundHex"]) ?? 0xEEF4FA,
                tintHex: uint32(in: payload, keys: ["tintHex"]) ?? 0x4F5D75
            )
        }

        if let assetName = string(in: payload, keys: ["assetName"]), !assetName.isEmpty {
            return .asset(name: assetName)
        }

        return fallbackImageSource()
    }

    private static func remoteImageSource(
        in dictionary: [String: HTTPClient.ResponseData],
        keys: [String]
    ) -> MallImageSource {
        if let url = url(in: dictionary, keys: keys) {
            return .remote(url: url)
        }
        return fallbackImageSource()
    }

    private static func detailMediaList(
        in dictionary: [String: HTTPClient.ResponseData],
        keys: [String]
    ) -> [MallProductDetailMedia] {
        guard let responseArray = array(in: dictionary, keys: keys) else {
            return []
        }

        return responseArray.compactMap { responseData in
            guard let payload = responseData.objectValue else {
                return nil
            }
            return mapProductDetailMedia(payload)
        }
    }

    private static func emptyLocalizedString() -> MallLocalizedString {
        MallLocalizedString("", "", "")
    }

    private static func fallbackImageSource() -> MallImageSource {
        .system(name: "shippingbox.fill", backgroundHex: 0xEEF4FA, tintHex: 0x4F5D75)
    }

    private static func isEmpty(_ value: MallLocalizedString) -> Bool {
        value.simplifiedChinese.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            value.english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            value.arabic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func object(from responseData: HTTPClient.ResponseData) throws -> [String: HTTPClient.ResponseData] {
        guard let payload = responseData.objectValue else {
            throw HTTPClient.ClientError.invalidResponse
        }
        return payload
    }

    private static func object(
        in dictionary: [String: HTTPClient.ResponseData],
        keys: [String]
    ) -> [String: HTTPClient.ResponseData]? {
        for key in keys {
            if let value = dictionary[key]?.objectValue {
                return value
            }
        }
        return nil
    }

    private static func array(
        in dictionary: [String: HTTPClient.ResponseData],
        keys: [String]
    ) -> [HTTPClient.ResponseData]? {
        for key in keys {
            if let value = dictionary[key]?.arrayValue {
                return value
            }
        }
        return nil
    }

    private static func objectArray(
        in dictionary: [String: HTTPClient.ResponseData],
        keys: [String]
    ) throws -> [[String: HTTPClient.ResponseData]] {
        guard let responseArray = array(in: dictionary, keys: keys) else {
            return []
        }

        return try responseArray.map { responseData in
            guard let payload = responseData.objectValue else {
                throw HTTPClient.ClientError.invalidResponse
            }
            return payload
        }
    }

    fileprivate static func string(in dictionary: [String: HTTPClient.ResponseData], keys: [String]) -> String? {
        for key in keys {
            guard let value = dictionary[key] else {
                continue
            }

            if let stringValue = value.stringValue, !stringValue.isEmpty {
                return stringValue
            }

            if let intValue = value.intValue {
                return String(intValue)
            }

            if let doubleValue = value.doubleValue {
                return String(doubleValue)
            }
        }
        return nil
    }

    private static func int(in dictionary: [String: HTTPClient.ResponseData], keys: [String]) -> Int? {
        for key in keys {
            if let intValue = dictionary[key]?.intValue {
                return intValue
            }
            if let stringValue = dictionary[key]?.stringValue, let intValue = Int(stringValue) {
                return intValue
            }
        }
        return nil
    }

    private static func bool(in dictionary: [String: HTTPClient.ResponseData], keys: [String]) -> Bool? {
        for key in keys {
            if let boolValue = dictionary[key]?.boolValue {
                return boolValue
            }
            if let stringValue = dictionary[key]?.stringValue {
                let normalized = stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if normalized == "true" {
                    return true
                }
                if normalized == "false" {
                    return false
                }
            }
        }
        return nil
    }

    private static func uint32(in dictionary: [String: HTTPClient.ResponseData], keys: [String]) -> UInt32? {
        int(in: dictionary, keys: keys).map { UInt32(bitPattern: Int32($0)) }
    }

    private static func decimal(in dictionary: [String: HTTPClient.ResponseData], keys: [String]) -> Decimal? {
        let locale = Locale(identifier: "en_US_POSIX")

        for key in keys {
            if let stringValue = dictionary[key]?.stringValue, let value = Decimal(string: stringValue, locale: locale) {
                return value
            }
            if let doubleValue = dictionary[key]?.doubleValue {
                return Decimal(string: String(doubleValue), locale: locale)
            }
        }
        return nil
    }

    private static func date(in dictionary: [String: HTTPClient.ResponseData], keys: [String]) -> Date? {
        for key in keys {
            guard let value = dictionary[key] else {
                continue
            }

            if let stringValue = value.stringValue, let parsedDate = MallResponseDateParser.parse(stringValue) {
                return parsedDate
            }

            if let timestamp = value.doubleValue {
                return MallResponseDateParser.parse(timestamp: timestamp)
            }

            if let nestedObject = value.objectValue, let parsedDate = MallResponseDateParser.parse(nestedObject) {
                return parsedDate
            }
        }
        return nil
    }

    private static func stringArray(
        in dictionary: [String: HTTPClient.ResponseData],
        keys: [String]
    ) -> [String] {
        guard let responseArray = array(in: dictionary, keys: keys) else {
            return []
        }

        return responseArray.compactMap { responseData in
            if let stringValue = responseData.stringValue, !stringValue.isEmpty {
                return stringValue
            }
            if let intValue = responseData.intValue {
                return String(intValue)
            }
            return nil
        }
    }

    private static func url(
        in dictionary: [String: HTTPClient.ResponseData],
        keys: [String]
    ) -> URL? {
        guard let value = string(in: dictionary, keys: keys) else {
            return nil
        }
        return URL(string: value)
    }

    private static func firstNonEmpty(_ values: [String]) -> String? {
        values.first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}

private enum MallResponseDateParser {
    private static let iso8601FractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static let backendFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    static func parse(_ value: String) -> Date? {
        if let fractionalDate = iso8601FractionalFormatter.date(from: value) {
            return fractionalDate
        }
        if let isoDate = iso8601Formatter.date(from: value) {
            return isoDate
        }
        if let backendDate = backendFormatter.date(from: value) {
            return backendDate
        }
        if let timestamp = Double(value) {
            return parse(timestamp: timestamp)
        }
        return nil
    }

    static func parse(timestamp: Double) -> Date {
        timestamp > 1_000_000_000_000
            ? Date(timeIntervalSince1970: timestamp / 1_000)
            : Date(timeIntervalSince1970: timestamp)
    }

    static func parse(_ dictionary: [String: HTTPClient.ResponseData]) -> Date? {
        if let nestedString = MallResponseMapper.string(
            in: dictionary,
            keys: ["value", "dateTime", "time", "localDateTime"]
        ) {
            return parse(nestedString)
        }

        let year = int(in: dictionary, keys: ["year"])
        let month = int(in: dictionary, keys: ["month", "monthValue"])
        let day = int(in: dictionary, keys: ["day", "dayOfMonth"])

        guard let year, let month, let day else {
            return nil
        }

        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        components.hour = int(in: dictionary, keys: ["hour"]) ?? 0
        components.minute = int(in: dictionary, keys: ["minute"]) ?? 0
        components.second = int(in: dictionary, keys: ["second"]) ?? 0
        return components.date
    }

    private static func int(
        in dictionary: [String: HTTPClient.ResponseData],
        keys: [String]
    ) -> Int? {
        for key in keys {
            if let intValue = dictionary[key]?.intValue {
                return intValue
            }
            if let stringValue = dictionary[key]?.stringValue, let intValue = Int(stringValue) {
                return intValue
            }
        }
        return nil
    }
}

private enum MallMockData {
    static let defaultSearchHistory = [
        "MacBook Air",
        "AirPods Pro",
        "修护精华",
        "运动鞋"
    ]

    static func makeHomeSnapshot() -> MallHomeSnapshot {
        let products = makeProducts()
        let primaryCategories = [
            makeElectronicsCategory(),
            makeBeautyCategory(),
            makeApparelCategory(),
            makeHomeCategory(),
        ]

        return MallHomeSnapshot(
            searchPlaceholder: MallLocalizedString(
                "搜索商品、品牌、活动",
                "Search products, brands, offers",
                "ابحث عن منتجات وعلامات وعروض"
            ),
            recommendation: makeRecommendationContent(products: products),
            primaryCategories: primaryCategories,
            products: products,
            defaultCategoryID: "electronics",
            cartBadgeCount: 4
        )
    }

    static func makeHotKeywords() -> [MallHotKeyword] {
        [
            MallHotKeyword(
                id: "macbook",
                title: MallLocalizedString("MacBook Air", "MacBook Air", "MacBook Air"),
                meta: MallLocalizedString("今日热度 92.1 万", "Trending now", "الأكثر تداولًا")
            ),
            MallHotKeyword(
                id: "airpods",
                title: MallLocalizedString("降噪耳机", "Noise-canceling earbuds", "سماعات عزل الضوضاء"),
                meta: MallLocalizedString("热搜上升", "Top search", "بحث شائع")
            ),
            MallHotKeyword(
                id: "serum",
                title: MallLocalizedString("修护精华", "Repair serum", "سيروم الإصلاح"),
                meta: MallLocalizedString("春季护肤", "Season pick", "مفضل الموسم")
            ),
            MallHotKeyword(
                id: "sneakers",
                title: MallLocalizedString("运动鞋", "Running sneakers", "أحذية جري"),
                meta: MallLocalizedString("运动上新", "Fresh drop", "إصدار جديد")
            ),
        ]
    }

    private static func makeElectronicsCategory() -> MallPrimaryCategory {
        MallPrimaryCategory(
            id: "electronics",
            title: MallLocalizedString("电子产品", "Electronics", "الإلكترونيات"),
            subcategories: [
                makeSubcategory(
                    id: "phones",
                    title: MallLocalizedString("手机", "Phones", "الهواتف"),
                    image: .asset(name: "ProductIPhoneImage"),
                    groups: [
                        makeGroup(
                            id: "phones-hot",
                            title: MallLocalizedString("热门机型", "Hot models", "الأكثر رواجًا"),
                            items: [
                                browseItem("iphone-line", "iPhone 系列", "iPhone", "آيفون", "iphone"),
                                browseItem("android-line", "安卓旗舰", "Android flagship", "أندرويد رائد", "apps.iphone"),
                                browseItem("fold-line", "折叠屏", "Foldable phones", "هواتف قابلة للطي", "rectangle.on.rectangle")
                            ]
                        ),
                        makeGroup(
                            id: "phones-accessories",
                            title: MallLocalizedString("配件专区", "Accessories", "الإكسسوارات"),
                            items: [
                                browseItem("case", "手机壳", "Cases", "أغطية", "iphone.gen3"),
                                browseItem("charger", "快充头", "Chargers", "شواحن", "bolt.fill"),
                                browseItem("powerbank", "移动电源", "Power banks", "بطاريات متنقلة", "battery.100.bolt")
                            ]
                        ),
                    ]
                ),
                makeSubcategory(
                    id: "laptops",
                    title: MallLocalizedString("笔记本", "Laptops", "أجهزة محمولة"),
                    image: .system(name: "laptopcomputer", backgroundHex: 0xEEF3FF, tintHex: 0x4A58C6),
                    groups: [
                        makeGroup(
                            id: "laptops-office",
                            title: MallLocalizedString("办公轻薄", "Office picks", "للعمل"),
                            items: [
                                browseItem("ultrabook", "轻薄本", "Ultrabooks", "خفيفة", "laptopcomputer"),
                                browseItem("creator", "创作者本", "Creator laptops", "للمبدعين", "scribble.variable"),
                                browseItem("gaming-book", "游戏本", "Gaming laptops", "ألعاب", "gamecontroller.fill")
                            ]
                        ),
                        makeGroup(
                            id: "laptops-accessories",
                            title: MallLocalizedString("桌面搭配", "Desk setup", "إعداد المكتب"),
                            items: [
                                browseItem("monitor", "显示器", "Monitors", "شاشات", "display"),
                                browseItem("keyboard", "机械键盘", "Keyboards", "لوحات مفاتيح", "keyboard"),
                                browseItem("mouse", "无线鼠标", "Mouse", "فأرة", "computermouse")
                            ]
                        ),
                    ]
                ),
                makeSubcategory(
                    id: "audio",
                    title: MallLocalizedString("音频", "Audio", "الصوت"),
                    image: .asset(name: "ProductAirPodsImage"),
                    groups: [
                        makeGroup(
                            id: "audio-listen",
                            title: MallLocalizedString("随身音频", "Daily audio", "صوت يومي"),
                            items: [
                                browseItem("earbuds", "蓝牙耳机", "Earbuds", "سماعات أذن", "airpodspro"),
                                browseItem("headphones", "头戴耳机", "Headphones", "سماعات رأس", "headphones"),
                                browseItem("speaker", "蓝牙音箱", "Speakers", "سماعات", "hifispeaker.fill")
                            ]
                        ),
                    ]
                ),
                makeSubcategory(
                    id: "gaming",
                    title: MallLocalizedString("游戏", "Gaming", "الألعاب"),
                    image: .system(name: "gamecontroller.fill", backgroundHex: 0xFFF0F3, tintHex: 0xFF4B61),
                    groups: [
                        makeGroup(
                            id: "gaming-core",
                            title: MallLocalizedString("玩家装备", "Player setup", "معدات اللاعبين"),
                            items: [
                                browseItem("console", "主机", "Consoles", "منصات", "gamecontroller.fill"),
                                browseItem("chair", "电竞椅", "Gaming chairs", "كراسي ألعاب", "chair.lounge.fill"),
                                browseItem("rgb", "RGB 配件", "RGB gear", "إكسسوارات RGB", "sparkles")
                            ]
                        ),
                    ]
                ),
                makeSubcategory(
                    id: "wearable",
                    title: MallLocalizedString("穿戴", "Wearables", "الأجهزة القابلة للارتداء"),
                    image: .asset(name: "ProductWatchImage"),
                    groups: [
                        makeGroup(
                            id: "wearable-core",
                            title: MallLocalizedString("智能穿戴", "Smart wear", "الأجهزة الذكية"),
                            items: [
                                browseItem("watch", "智能手表", "Smart watches", "ساعات ذكية", "applewatch.watchface"),
                                browseItem("band", "运动手环", "Fitness bands", "أساور رياضية", "figure.walk"),
                                browseItem("tracker", "睡眠监测", "Sleep trackers", "متابعة النوم", "moon.stars.fill")
                            ]
                        ),
                    ]
                ),
            ]
        )
    }

    private static func makeBeautyCategory() -> MallPrimaryCategory {
        MallPrimaryCategory(
            id: "beauty",
            title: MallLocalizedString("美妆护肤", "Beauty", "الجمال"),
            subcategories: [
                makeSubcategory(
                    id: "skincare",
                    title: MallLocalizedString("护肤", "Skincare", "العناية"),
                    image: .system(name: "drop.fill", backgroundHex: 0xFFF5E9, tintHex: 0xF59E0B),
                    groups: [
                        makeGroup(
                            id: "skincare-core",
                            title: MallLocalizedString("修护保湿", "Hydration", "الترطيب"),
                            items: [
                                browseItem("cleanser", "洁面", "Cleanser", "غسول", "drop.fill"),
                                browseItem("serum", "精华", "Serums", "سيرومات", "sparkles"),
                                browseItem("cream", "面霜", "Creams", "كريمات", "heart.text.square.fill")
                            ]
                        ),
                    ]
                ),
                makeSubcategory(
                    id: "makeup",
                    title: MallLocalizedString("彩妆", "Makeup", "المكياج"),
                    image: .system(name: "paintbrush.pointed.fill", backgroundHex: 0xFFF1F4, tintHex: 0xEC4899),
                    groups: [
                        makeGroup(
                            id: "makeup-core",
                            title: MallLocalizedString("春季妆容", "Spring looks", "إطلالات الربيع"),
                            items: [
                                browseItem("lip", "口红", "Lipsticks", "أحمر شفاه", "paintbrush.pointed.fill"),
                                browseItem("base", "底妆", "Base makeup", "أساس", "circle.lefthalf.filled"),
                                browseItem("eye", "眼妆", "Eye makeup", "مكياج العيون", "eye.fill")
                            ]
                        ),
                    ]
                ),
                makeSubcategory(
                    id: "fragrance",
                    title: MallLocalizedString("香氛", "Fragrance", "العطور"),
                    image: .system(name: "sparkles", backgroundHex: 0xEEF7FF, tintHex: 0x0EA5E9),
                    groups: [
                        makeGroup(
                            id: "fragrance-core",
                            title: MallLocalizedString("人气香水", "Perfume picks", "العطور المميزة"),
                            items: [
                                browseItem("perfume", "香水", "Perfume", "عطر", "sparkles"),
                                browseItem("mist", "香氛喷雾", "Mists", "بخاخات", "spray.can.fill"),
                                browseItem("set", "礼盒", "Gift boxes", "هدايا", "gift.fill")
                            ]
                        ),
                    ]
                ),
                makeSubcategory(
                    id: "giftset",
                    title: MallLocalizedString("礼盒", "Gift Sets", "الهدايا"),
                    image: .system(name: "gift.fill", backgroundHex: 0xFFF7ED, tintHex: 0xFB923C),
                    groups: [
                        makeGroup(
                            id: "giftset-core",
                            title: MallLocalizedString("节日送礼", "Gift guide", "هدايا المناسبات"),
                            items: [
                                browseItem("holiday", "节日礼盒", "Holiday gifts", "هدايا موسمية", "gift.fill"),
                                browseItem("travel", "旅行套装", "Travel kits", "حقائب سفر", "suitcase.fill"),
                                browseItem("premium", "高端礼赠", "Premium gifts", "هدايا فاخرة", "star.fill")
                            ]
                        ),
                    ]
                ),
                makeSubcategory(
                    id: "tools",
                    title: MallLocalizedString("工具", "Tools", "الأدوات"),
                    image: .system(name: "scissors", backgroundHex: 0xF3F4F6, tintHex: 0x64748B),
                    groups: [
                        makeGroup(
                            id: "tools-core",
                            title: MallLocalizedString("妆造工具", "Beauty tools", "أدوات التجميل"),
                            items: [
                                browseItem("brush", "化妆刷", "Brushes", "فرش", "paintbrush.fill"),
                                browseItem("dryer", "吹风机", "Dryers", "مجففات", "wind"),
                                browseItem("mirror", "补光镜", "Mirrors", "مرايا", "sun.max.fill")
                            ]
                        ),
                    ]
                ),
            ]
        )
    }

    private static func makeApparelCategory() -> MallPrimaryCategory {
        MallPrimaryCategory(
            id: "apparel",
            title: MallLocalizedString("服饰穿搭", "Clothing", "الأزياء"),
            subcategories: [
                makeSubcategory(
                    id: "sneakers",
                    title: MallLocalizedString("鞋履", "Shoes", "الأحذية"),
                    image: .system(name: "figure.walk", backgroundHex: 0xEFF6FF, tintHex: 0x2563EB),
                    groups: [
                        makeGroup(
                            id: "sneakers-core",
                            title: MallLocalizedString("运动精选", "Sport shoes", "أحذية رياضية"),
                            items: [
                                browseItem("runner", "跑鞋", "Running", "جري", "figure.run"),
                                browseItem("trainer", "训练鞋", "Training", "تمارين", "figure.strengthtraining.traditional"),
                                browseItem("casual", "休闲鞋", "Casual", "كاجوال", "shoeprints.fill")
                            ]
                        ),
                    ]
                ),
                makeSubcategory(
                    id: "bags",
                    title: MallLocalizedString("箱包", "Bags", "الحقائب"),
                    image: .system(name: "bag.fill", backgroundHex: 0xFEF2F2, tintHex: 0xEF4444),
                    groups: [
                        makeGroup(
                            id: "bags-core",
                            title: MallLocalizedString("通勤包袋", "City bags", "حقائب المدينة"),
                            items: [
                                browseItem("tote", "托特包", "Tote bags", "حقائب كبيرة", "bag.fill"),
                                browseItem("crossbody", "斜挎包", "Crossbody", "حقائب كتف", "bag.circle.fill"),
                                browseItem("wallet", "卡包", "Wallets", "محافظ", "creditcard.fill")
                            ]
                        ),
                    ]
                ),
                makeSubcategory(
                    id: "outerwear",
                    title: MallLocalizedString("外套", "Outerwear", "الملابس الخارجية"),
                    image: .system(name: "tshirt.fill", backgroundHex: 0xF5F3FF, tintHex: 0x8B5CF6),
                    groups: [
                        makeGroup(
                            id: "outerwear-core",
                            title: MallLocalizedString("当季上新", "Seasonal edit", "اختيارات الموسم"),
                            items: [
                                browseItem("jacket", "轻薄外套", "Jackets", "سترات", "tshirt.fill"),
                                browseItem("hoodie", "卫衣", "Hoodies", "هودي", "tshirt"),
                                browseItem("coat", "长风衣", "Coats", "معاطف", "person.crop.rectangle")
                            ]
                        ),
                    ]
                ),
                makeSubcategory(
                    id: "accessories",
                    title: MallLocalizedString("配饰", "Accessories", "الإكسسوارات"),
                    image: .system(name: "tag.fill", backgroundHex: 0xFFFBEB, tintHex: 0xD97706),
                    groups: [
                        makeGroup(
                            id: "accessories-core",
                            title: MallLocalizedString("日常配饰", "Daily style", "إكسسوارات يومية"),
                            items: [
                                browseItem("cap", "帽子", "Caps", "قبعات", "sun.max.fill"),
                                browseItem("belt", "腰带", "Belts", "أحزمة", "minus"),
                                browseItem("glasses", "墨镜", "Sunglasses", "نظارات", "eye.fill")
                            ]
                        ),
                    ]
                ),
                makeSubcategory(
                    id: "watches",
                    title: MallLocalizedString("腕表", "Watches", "الساعات"),
                    image: .asset(name: "ProductWatchImage"),
                    groups: [
                        makeGroup(
                            id: "watches-core",
                            title: MallLocalizedString("轻奢腕表", "Watch edit", "اختيارات الساعات"),
                            items: [
                                browseItem("classic", "经典腕表", "Classic", "كلاسيكية", "applewatch.watchface"),
                                browseItem("sport", "运动款", "Sport", "رياضية", "figure.walk"),
                                browseItem("strap", "表带配件", "Straps", "أحزمة ساعة", "link")
                            ]
                        ),
                    ]
                ),
            ]
        )
    }

    private static func makeHomeCategory() -> MallPrimaryCategory {
        MallPrimaryCategory(
            id: "home",
            title: MallLocalizedString("家居生活", "Home", "المنزل"),
            subcategories: [
                makeSubcategory(
                    id: "cleaning",
                    title: MallLocalizedString("清洁", "Cleaning", "التنظيف"),
                    image: .system(name: "sparkles", backgroundHex: 0xECFEFF, tintHex: 0x06B6D4),
                    groups: [
                        makeGroup(
                            id: "cleaning-core",
                            title: MallLocalizedString("清洁电器", "Cleaning tech", "أجهزة التنظيف"),
                            items: [
                                browseItem("robot", "扫地机器人", "Robot vacuums", "روبوتات تنظيف", "sparkles"),
                                browseItem("vacuum", "手持吸尘器", "Vacuums", "مكانس", "wind"),
                                browseItem("mop", "洗地机", "Mops", "مماسح", "drop.fill")
                            ]
                        ),
                    ]
                ),
                makeSubcategory(
                    id: "kitchen",
                    title: MallLocalizedString("厨房", "Kitchen", "المطبخ"),
                    image: .system(name: "cup.and.saucer.fill", backgroundHex: 0xFFF7ED, tintHex: 0xF97316),
                    groups: [
                        makeGroup(
                            id: "kitchen-core",
                            title: MallLocalizedString("厨房家电", "Kitchen picks", "أجهزة المطبخ"),
                            items: [
                                browseItem("coffee", "咖啡机", "Coffee makers", "ماكينات قهوة", "cup.and.saucer.fill"),
                                browseItem("kettle", "电热水壶", "Kettles", "غلايات", "flame.fill"),
                                browseItem("blender", "搅拌机", "Blenders", "خلاطات", "drop.triangle.fill")
                            ]
                        ),
                    ]
                ),
                makeSubcategory(
                    id: "smart",
                    title: MallLocalizedString("智能家居", "Smart Home", "المنزل الذكي"),
                    image: .system(name: "house.fill", backgroundHex: 0xEFF6FF, tintHex: 0x2563EB),
                    groups: [
                        makeGroup(
                            id: "smart-core",
                            title: MallLocalizedString("联动设备", "Smart setup", "الإعداد الذكي"),
                            items: [
                                browseItem("speaker", "智能音箱", "Smart speakers", "مكبرات ذكية", "hifispeaker.fill"),
                                browseItem("camera", "家庭摄像头", "Cameras", "كاميرات", "video.fill"),
                                browseItem("light", "智能灯带", "Lights", "إضاءة", "lightbulb.fill")
                            ]
                        ),
                    ]
                ),
                makeSubcategory(
                    id: "care",
                    title: MallLocalizedString("个护", "Care", "العناية الشخصية"),
                    image: .system(name: "heart.fill", backgroundHex: 0xFEF2F2, tintHex: 0xEF4444),
                    groups: [
                        makeGroup(
                            id: "care-core",
                            title: MallLocalizedString("个护电器", "Personal care", "العناية الشخصية"),
                            items: [
                                browseItem("dryer", "吹风机", "Hair dryers", "مجففات", "wind"),
                                browseItem("shaver", "剃须刀", "Shavers", "ماكينات حلاقة", "scissors"),
                                browseItem("brush", "电动牙刷", "Toothbrushes", "فرش أسنان", "sparkles")
                            ]
                        ),
                    ]
                ),
                makeSubcategory(
                    id: "office",
                    title: MallLocalizedString("办公", "Office", "المكتب"),
                    image: .system(name: "shippingbox.fill", backgroundHex: 0xF8FAFC, tintHex: 0x475569),
                    groups: [
                        makeGroup(
                            id: "office-core",
                            title: MallLocalizedString("桌面升级", "Desk upgrade", "ترقية المكتب"),
                            items: [
                                browseItem("desk-lamp", "台灯", "Desk lamps", "مصابيح", "lamp.desk.fill"),
                                browseItem("stand", "电脑支架", "Laptop stands", "حوامل", "laptopcomputer"),
                                browseItem("storage", "收纳盒", "Storage", "تخزين", "shippingbox.fill")
                            ]
                        ),
                    ]
                ),
            ]
        )
    }

    private static func makeProducts() -> [MallProduct] {
        [
            makeProduct(
                id: "iphone-16-pro",
                categoryID: "electronics",
                subcategoryID: "phones",
                thirdCategoryID: "iphone-line",
                title: MallLocalizedString("iPhone 16 Pro Max 256G", "iPhone 16 Pro Max 256GB", "iPhone 16 Pro Max 256GB"),
                subtitle: MallLocalizedString("沙漠金旗舰 手机焕新直降", "Desert titanium flagship with instant savings", "هاتف رائد بلون التيتانيوم الصحراوي"),
                image: .asset(name: "ProductIPhoneImage"),
                detailMediaList: sampleDetailMedia(slug: "iphone-16-pro"),
                price: 8_999,
                originalPrice: 9_999,
                badge: MallProductBadge(
                    title: MallLocalizedString("新品", "New", "جديد"),
                    style: .sale
                ),
                tags: [
                    MallLocalizedString("百亿补贴", "Instant rebate", "خصم مباشر"),
                    MallLocalizedString("次日达", "Next-day", "توصيل سريع")
                ],
                salesCount: 56_000,
                sortWeight: 98,
                updatedAt: date(daysAgo: 1)
            ),
            makeProduct(
                id: "macbook-air-m4",
                categoryID: "electronics",
                subcategoryID: "laptops",
                thirdCategoryID: "ultrabook",
                title: MallLocalizedString("MacBook Air 13 英寸 M4", "MacBook Air 13-inch M4", "MacBook Air 13 بوصة M4"),
                subtitle: MallLocalizedString("轻薄办公本 支持 24 期免息", "Lightweight laptop with installment offer", "حاسوب خفيف مع تقسيط"),
                image: .system(name: "laptopcomputer", backgroundHex: 0xEFF4FF, tintHex: 0x4A58C6),
                detailMediaList: sampleDetailMedia(slug: "macbook-air-m4"),
                price: 7_499,
                originalPrice: 8_299,
                badge: MallProductBadge(
                    title: MallLocalizedString("自营", "Brand", "رسمي"),
                    style: .brand
                ),
                tags: [
                    MallLocalizedString("国家补贴", "Subsidy", "دعم حكومي"),
                    MallLocalizedString("24 期免息", "24 mo", "24 شهر")
                ],
                salesCount: 21_000,
                sortWeight: 96,
                updatedAt: date(daysAgo: 3)
            ),
            makeProduct(
                id: "airpods-pro",
                categoryID: "electronics",
                subcategoryID: "audio",
                thirdCategoryID: "earbuds",
                title: MallLocalizedString("AirPods Pro 主动降噪耳机", "AirPods Pro noise-canceling earbuds", "AirPods Pro لعزل الضوضاء"),
                subtitle: MallLocalizedString("随身轻便 通勤游戏都合适", "Portable audio for commute and play", "سماعات خفيفة للتنقل واللعب"),
                image: .asset(name: "ProductAirPodsImage"),
                detailMediaList: sampleDetailMedia(slug: "airpods-pro", includesVideo: true),
                price: 1_499,
                originalPrice: 1_899,
                badge: MallProductBadge(
                    title: MallLocalizedString("热卖", "Hot", "الأكثر مبيعًا"),
                    style: .sale
                ),
                tags: [
                    MallLocalizedString("限时直降", "Flash deal", "عرض سريع"),
                    MallLocalizedString("以旧换新", "Trade-in", "استبدال")
                ],
                salesCount: 93_000,
                sortWeight: 95,
                updatedAt: date(daysAgo: 2)
            ),
            makeProduct(
                id: "active-watch",
                categoryID: "electronics",
                subcategoryID: "wearable",
                thirdCategoryID: "watch",
                title: MallLocalizedString("智能运动手表 Active", "Active smart fitness watch", "ساعة Active الذكية"),
                subtitle: MallLocalizedString("心率监测与全天候运动记录", "Heart-rate tracking and daily activity", "مراقبة نبضات القلب والنشاط اليومي"),
                image: .asset(name: "ProductWatchImage"),
                detailMediaList: sampleDetailMedia(slug: "active-watch"),
                price: 699,
                originalPrice: 899,
                badge: MallProductBadge(
                    title: MallLocalizedString("精选", "Pick", "مختارة"),
                    style: .featured
                ),
                tags: [
                    MallLocalizedString("赠表带", "Extra strap", "سوار إضافي"),
                    MallLocalizedString("运动模式", "Workout modes", "وضعيات رياضية")
                ],
                salesCount: 18_000,
                sortWeight: 90,
                updatedAt: date(daysAgo: 4)
            ),
            makeProduct(
                id: "repair-serum-kit",
                categoryID: "beauty",
                subcategoryID: "skincare",
                thirdCategoryID: "serum",
                title: MallLocalizedString("修护精华礼盒", "Repair serum gift set", "مجموعة سيروم الإصلاح"),
                subtitle: MallLocalizedString("春季保湿维稳套装", "Hydrating set for seasonal care", "مجموعة ترطيب للعناية الموسمية"),
                image: .system(name: "drop.fill", backgroundHex: 0xFFF7ED, tintHex: 0xF59E0B),
                detailMediaList: sampleDetailMedia(slug: "repair-serum-kit"),
                price: 369,
                originalPrice: 459,
                badge: MallProductBadge(
                    title: MallLocalizedString("特卖", "Sale", "تخفيض"),
                    style: .sale
                ),
                tags: [
                    MallLocalizedString("买一赠一", "Buy 1 get 1", "اشترِ واحدة واحصل على أخرى"),
                    MallLocalizedString("赠旅行装", "Travel size", "حجم سفر")
                ],
                salesCount: 88_000,
                sortWeight: 94,
                updatedAt: date(daysAgo: 5)
            ),
            makeProduct(
                id: "matte-lip-kit",
                categoryID: "beauty",
                subcategoryID: "makeup",
                thirdCategoryID: "lip",
                title: MallLocalizedString("春日樱粉口红套装", "Spring matte lip set", "مجموعة أحمر شفاه ربيعية"),
                subtitle: MallLocalizedString("显白提气色 送礼也合适", "Soft matte shades for daily looks", "درجات ناعمة مناسبة للهدايا"),
                image: .system(name: "paintbrush.pointed.fill", backgroundHex: 0xFFF1F4, tintHex: 0xEC4899),
                detailMediaList: sampleDetailMedia(slug: "matte-lip-kit", includesVideo: true),
                price: 129,
                originalPrice: 169,
                badge: MallProductBadge(
                    title: MallLocalizedString("爆款", "Best", "الأفضل"),
                    style: .sale
                ),
                tags: [
                    MallLocalizedString("今日热搜", "Top search", "بحث شائع"),
                    MallLocalizedString("限时 9 折", "10% off", "خصم 10%")
                ],
                salesCount: 120_000,
                sortWeight: 92,
                updatedAt: date(daysAgo: 2)
            ),
            makeProduct(
                id: "perfume-box",
                categoryID: "beauty",
                subcategoryID: "fragrance",
                thirdCategoryID: "perfume",
                title: MallLocalizedString("高定香氛礼盒", "Premium fragrance gift box", "صندوق عطور فاخر"),
                subtitle: MallLocalizedString("清新木质香调 节日送礼推荐", "Fresh woody notes for gifting", "روائح خشبية منعشة للهدايا"),
                image: .system(name: "sparkles", backgroundHex: 0xEEF7FF, tintHex: 0x0EA5E9),
                detailMediaList: sampleDetailMedia(slug: "perfume-box"),
                price: 499,
                originalPrice: 699,
                badge: MallProductBadge(
                    title: MallLocalizedString("大牌", "Brand", "ماركة"),
                    style: .brand
                ),
                tags: [
                    MallLocalizedString("满 399 减 60", "Save 60", "وفر 60"),
                    MallLocalizedString("顺丰包邮", "Free ship", "شحن مجاني")
                ],
                salesCount: 36_000,
                sortWeight: 88,
                updatedAt: date(daysAgo: 6)
            ),
            makeProduct(
                id: "city-tote-bag",
                categoryID: "apparel",
                subcategoryID: "bags",
                thirdCategoryID: "tote",
                title: MallLocalizedString("通勤托特包", "City tote bag", "حقيبة توت للعمل"),
                subtitle: MallLocalizedString("大容量高级感 通勤百搭", "Spacious bag for everyday commute", "واسعة وأنيقة للاستخدام اليومي"),
                image: .system(name: "bag.fill", backgroundHex: 0xFEF2F2, tintHex: 0xEF4444),
                detailMediaList: sampleDetailMedia(slug: "city-tote-bag"),
                price: 259,
                originalPrice: 339,
                badge: MallProductBadge(
                    title: MallLocalizedString("精选", "Pick", "مختارة"),
                    style: .featured
                ),
                tags: [
                    MallLocalizedString("新品上新", "New drop", "إصدار جديد"),
                    MallLocalizedString("30 天退换", "30-day return", "استرجاع 30 يومًا")
                ],
                salesCount: 33_000,
                sortWeight: 86,
                updatedAt: date(daysAgo: 4)
            ),
            makeProduct(
                id: "runner-sneakers",
                categoryID: "apparel",
                subcategoryID: "sneakers",
                thirdCategoryID: "runner",
                title: MallLocalizedString("复古运动鞋", "Retro runner sneakers", "حذاء رياضي كلاسيكي"),
                subtitle: MallLocalizedString("轻弹缓震 日常百搭", "Soft rebound sole for daily wear", "نعل مريح للاستخدام اليومي"),
                image: .system(name: "figure.walk", backgroundHex: 0xEFF6FF, tintHex: 0x2563EB),
                detailMediaList: sampleDetailMedia(slug: "runner-sneakers"),
                price: 329,
                originalPrice: 459,
                badge: MallProductBadge(
                    title: MallLocalizedString("热卖", "Hot", "الأكثر مبيعًا"),
                    style: .sale
                ),
                tags: [
                    MallLocalizedString("包邮", "Free ship", "شحن مجاني"),
                    MallLocalizedString("运动场景", "Sport ready", "جاهز للرياضة")
                ],
                salesCount: 65_000,
                sortWeight: 93,
                updatedAt: date(daysAgo: 1)
            ),
            makeProduct(
                id: "wind-jacket",
                categoryID: "apparel",
                subcategoryID: "outerwear",
                thirdCategoryID: "jacket",
                title: MallLocalizedString("轻薄防风外套", "Lightweight wind jacket", "سترة خفيفة مقاومة للرياح"),
                subtitle: MallLocalizedString("春季叠穿更有层次", "Layer-friendly jacket for spring", "سترة مثالية لطبقات الربيع"),
                image: .system(name: "tshirt.fill", backgroundHex: 0xF5F3FF, tintHex: 0x8B5CF6),
                detailMediaList: sampleDetailMedia(slug: "wind-jacket"),
                price: 219,
                originalPrice: 299,
                badge: MallProductBadge(
                    title: MallLocalizedString("上新", "Fresh", "جديد"),
                    style: .featured
                ),
                tags: [
                    MallLocalizedString("穿搭推荐", "Style pick", "اختيار أناقة"),
                    MallLocalizedString("店播同款", "Live room", "الأكثر مشاهدة")
                ],
                salesCount: 29_000,
                sortWeight: 85,
                updatedAt: date(daysAgo: 2)
            ),
            makeProduct(
                id: "robot-vacuum",
                categoryID: "home",
                subcategoryID: "cleaning",
                thirdCategoryID: "robot",
                title: MallLocalizedString("扫拖一体机器人", "Robot vacuum and mop", "روبوت تنظيف ومسح"),
                subtitle: MallLocalizedString("自动集尘 解放双手", "Auto-empty dock for hands-free cleaning", "قاعدة تفريغ تلقائي للتنظيف السهل"),
                image: .system(name: "sparkles", backgroundHex: 0xECFEFF, tintHex: 0x06B6D4),
                detailMediaList: sampleDetailMedia(slug: "robot-vacuum", includesVideo: true),
                price: 1_799,
                originalPrice: 2_299,
                badge: MallProductBadge(
                    title: MallLocalizedString("热卖", "Hot", "الأكثر مبيعًا"),
                    style: .sale
                ),
                tags: [
                    MallLocalizedString("以旧换新", "Trade-in", "استبدال"),
                    MallLocalizedString("送耗材", "Extra kit", "ملحقات إضافية")
                ],
                salesCount: 34_000,
                sortWeight: 89,
                updatedAt: date(daysAgo: 5)
            ),
            makeProduct(
                id: "capsule-coffee",
                categoryID: "home",
                subcategoryID: "kitchen",
                thirdCategoryID: "coffee",
                title: MallLocalizedString("胶囊咖啡机", "Capsule coffee machine", "ماكينة قهوة بالكبسولات"),
                subtitle: MallLocalizedString("桌面小体积 早晨一键出杯", "Compact machine for a quick morning brew", "جهاز صغير لتحضير قهوتك بسرعة"),
                image: .system(name: "cup.and.saucer.fill", backgroundHex: 0xFFF7ED, tintHex: 0xF97316),
                detailMediaList: sampleDetailMedia(slug: "capsule-coffee"),
                price: 799,
                originalPrice: 999,
                badge: MallProductBadge(
                    title: MallLocalizedString("精选", "Pick", "مختارة"),
                    style: .featured
                ),
                tags: [
                    MallLocalizedString("桌面家电", "Desk size", "حجم مكتبي"),
                    MallLocalizedString("一键萃取", "One touch", "بلمسة واحدة")
                ],
                salesCount: 12_000,
                sortWeight: 83,
                updatedAt: date(daysAgo: 7)
            ),
        ]
    }

    private static func makeRecommendationContent(
        products: [MallProduct]
    ) -> MallHomeRecommendationContent {
        MallHomeRecommendationContent(
            tabTitle: MallLocalizedString(
                "推荐",
                "Featured",
                "موصى به"
            ),
            highlightSectionTitle: MallLocalizedString(
                "热门推荐",
                "Hot Picks",
                "الاختيارات الرائجة"
            ),
            highlightCards: [
                highlightCard(
                    id: "featured-iphone",
                    badge: MallLocalizedString("旗舰补贴", "Flagship Deal", "عرض رائد"),
                    title: MallLocalizedString(
                        "iPhone 16 Pro Max",
                        "iPhone 16 Pro Max",
                        "iPhone 16 Pro Max"
                    ),
                    subtitle: MallLocalizedString(
                        "24 期免息，热门配色现货优先发",
                        "24-month installment with priority stock",
                        "تقسيط 24 شهرًا مع أولوية في المخزون"
                    ),
                    image: product(id: "iphone-16-pro", within: products).coverImage,
                    startHex: 0x0BB4D7,
                    endHex: 0x4B5AC6,
                    productID: "iphone-16-pro"
                ),
                highlightCard(
                    id: "featured-serum",
                    badge: MallLocalizedString("春季上新", "Spring Beauty", "جمال الربيع"),
                    title: MallLocalizedString(
                        "修护精华礼盒",
                        "Repair Serum Set",
                        "مجموعة سيروم الإصلاح"
                    ),
                    subtitle: MallLocalizedString(
                        "保湿修护组合，买一赠一限时抢",
                        "Hydration set with limited buy-one-get-one offer",
                        "مجموعة ترطيب بعرض اشترِ واحدة واحصل على أخرى"
                    ),
                    image: product(id: "repair-serum-kit", within: products).coverImage,
                    startHex: 0xFF8A88,
                    endHex: 0xF973A0,
                    productID: "repair-serum-kit"
                ),
                highlightCard(
                    id: "featured-home",
                    badge: MallLocalizedString("居家焕新", "Home Upgrade", "تجديد المنزل"),
                    title: MallLocalizedString(
                        "扫拖一体机器人",
                        "Robot Vacuum Combo",
                        "روبوت تنظيف ومسح"
                    ),
                    subtitle: MallLocalizedString(
                        "限时送耗材与安装服务",
                        "Limited-time kit bundle with setup support",
                        "عرض لفترة محدودة مع ملحقات ودعم التركيب"
                    ),
                    image: product(id: "robot-vacuum", within: products).coverImage,
                    startHex: 0x0EA5E9,
                    endHex: 0x14B8A6,
                    productID: "robot-vacuum"
                ),
            ],
            activitySectionTitle: MallLocalizedString(
                "活动专区",
                "Offers",
                "منطقة العروض"
            ),
            activityCards: [
                activityCard(
                    id: "activity-apple",
                    tag: MallLocalizedString("限时会场", "Time-Limited", "لفترة محدودة"),
                    title: MallLocalizedString(
                        "Apple 生态焕新周",
                        "Apple Upgrade Week",
                        "أسبوع ترقية Apple"
                    ),
                    subtitle: MallLocalizedString(
                        "手机、耳机、手表组合购低至 85 折",
                        "Bundle your phone, audio, and watch from 15% off",
                        "خصم حتى 15% على حزم الهاتف والسماعات والساعة"
                    ),
                    image: .asset(name: "ProductAirPodsImage"),
                    startHex: 0x102A43,
                    endHex: 0x243B53,
                    categoryID: "electronics",
                    subcategoryID: "audio"
                ),
                activityCard(
                    id: "activity-beauty",
                    tag: MallLocalizedString("满减专区", "Bundle Savings", "توفير الحزم"),
                    title: MallLocalizedString(
                        "春日护肤计划",
                        "Spring Skin Routine",
                        "روتين العناية الربيعي"
                    ),
                    subtitle: MallLocalizedString(
                        "精华、面霜、面膜任选满减",
                        "Mix serums, creams, and masks with bundle savings",
                        "خصومات عند الجمع بين السيروم والكريمات والأقنعة"
                    ),
                    image: .system(name: "sparkles", backgroundHex: 0xFFF7ED, tintHex: 0xF59E0B),
                    startHex: 0xF9738A,
                    endHex: 0xFB7185,
                    categoryID: "beauty",
                    subcategoryID: "skincare"
                ),
                activityCard(
                    id: "activity-home",
                    tag: MallLocalizedString("家电满减", "Home Deals", "عروض المنزل"),
                    title: MallLocalizedString(
                        "轻家电生活馆",
                        "Smart Home Living",
                        "ركن الأجهزة المنزلية"
                    ),
                    subtitle: MallLocalizedString(
                        "咖啡机、清洁电器与智能家居同步优惠",
                        "Coffee, cleaning, and smart-home deals in one place",
                        "عروض على القهوة والتنظيف والمنزل الذكي في مكان واحد"
                    ),
                    image: .system(name: "house.fill", backgroundHex: 0xE0F2FE, tintHex: 0x2563EB),
                    startHex: 0x06B6D4,
                    endHex: 0x2563EB,
                    categoryID: "home",
                    subcategoryID: "smart"
                ),
            ],
            productSectionTitle: MallLocalizedString(
                "为你精选",
                "Picked For You",
                "مختارة لك"
            )
        )
    }

    private static func makeProduct(
        id: String,
        categoryID: String,
        subcategoryID: String,
        thirdCategoryID: String,
        title: MallLocalizedString,
        subtitle: MallLocalizedString,
        image: MallImageSource,
        detailMediaList: [MallProductDetailMedia] = [],
        price: Decimal,
        originalPrice: Decimal?,
        badge: MallProductBadge,
        tags: [MallLocalizedString],
        salesCount: Int,
        sortWeight: Int,
        updatedAt: Date
    ) -> MallProduct {
        MallProduct(
            id: id,
            categoryID: categoryID,
            subcategoryID: subcategoryID,
            thirdCategoryID: thirdCategoryID,
            title: title,
            subtitle: subtitle,
            coverImage: image,
            detailMediaList: detailMediaList,
            price: price,
            originalPrice: originalPrice,
            badge: badge,
            tags: tags,
            salesCount: salesCount,
            sortWeight: sortWeight,
            updatedAt: updatedAt,
            detailTarget: "mall://product/\(id)"
        )
    }

    private static func sampleDetailMedia(
        slug: String,
        includesVideo: Bool = false
    ) -> [MallProductDetailMedia] {
        [
            MallProductDetailMedia(
                id: "\(slug)-detail-1",
                type: .image,
                url: sampleImageURL(slug: slug, suffix: "detail+1")
            ),
            MallProductDetailMedia(
                id: "\(slug)-detail-2",
                type: includesVideo ? .video : .image,
                url: includesVideo
                    ? fixedURL("https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4")
                    : sampleImageURL(slug: slug, suffix: "detail+2")
            ),
        ]
    }

    private static func sampleImageURL(slug: String, suffix: String) -> URL {
        fixedURL(
            "https://placehold.co/1600x2000/png?text=\(slug.replacingOccurrences(of: "-", with: "+"))+\(suffix)"
        )
    }

    private static func fixedURL(_ value: String) -> URL {
        guard let url = URL(string: value) else {
            preconditionFailure("Invalid Mall mock URL: \(value)")
        }
        return url
    }

    private static func makeSubcategory(
        id: String,
        title: MallLocalizedString,
        image: MallImageSource,
        groups: [[MallThirdCategory]]
    ) -> MallSubcategory {
        MallSubcategory(id: id, title: title, image: image, thirdCategories: groups.flatMap { $0 })
    }

    private static func makeGroup(
        id: String,
        title: MallLocalizedString,
        items: [MallThirdCategory]
    ) -> [MallThirdCategory] {
        _ = id
        _ = title
        return items
    }

    private static func browseItem(
        _ id: String,
        _ simplifiedChinese: String,
        _ english: String,
        _ arabic: String,
        _ systemName: String,
        backgroundHex: UInt32 = 0xF4F7FB,
        tintHex: UInt32 = 0x4A58C6
    ) -> MallThirdCategory {
        MallThirdCategory(
            id: id,
            title: MallLocalizedString(simplifiedChinese, english, arabic),
            image: .system(name: systemName, backgroundHex: backgroundHex, tintHex: tintHex)
        )
    }

    private static func highlightCard(
        id: String,
        badge: MallLocalizedString,
        title: MallLocalizedString,
        subtitle: MallLocalizedString,
        image: MallImageSource,
        startHex: UInt32,
        endHex: UInt32,
        productID: String
    ) -> MallHomeHighlightCard {
        MallHomeHighlightCard(
            id: id,
            badge: badge,
            title: title,
            subtitle: subtitle,
            image: image,
            startHex: startHex,
            endHex: endHex,
            productID: productID
        )
    }

    private static func activityCard(
        id: String,
        tag: MallLocalizedString,
        title: MallLocalizedString,
        subtitle: MallLocalizedString,
        image: MallImageSource,
        startHex: UInt32,
        endHex: UInt32,
        categoryID: String,
        subcategoryID: String?
    ) -> MallHomeActivityCard {
        MallHomeActivityCard(
            id: id,
            tag: tag,
            title: title,
            subtitle: subtitle,
            image: image,
            startHex: startHex,
            endHex: endHex,
            categoryID: categoryID,
            subcategoryID: subcategoryID
        )
    }

    private static func product(
        id: String,
        within products: [MallProduct]
    ) -> MallProduct {
        products.first(where: { $0.id == id }) ?? products[0]
    }

    private static func date(daysAgo: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
    }
}
