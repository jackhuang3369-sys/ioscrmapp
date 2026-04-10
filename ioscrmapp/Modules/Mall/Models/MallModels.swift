import Foundation

struct MallLocalizedString: Hashable, Sendable {
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

enum MallImageSource: Hashable, Sendable {
    case asset(name: String)
    case system(name: String, backgroundHex: UInt32, tintHex: UInt32)
    case remote(url: URL)
}

struct MallThirdCategory: Identifiable, Hashable, Sendable {
    let id: String
    let title: MallLocalizedString
    let image: MallImageSource
}

struct MallSubcategory: Identifiable, Hashable, Sendable {
    let id: String
    let title: MallLocalizedString
    let image: MallImageSource
    let thirdCategories: [MallThirdCategory]
}

struct MallPrimaryCategory: Identifiable, Hashable, Sendable {
    let id: String
    let title: MallLocalizedString
    let subcategories: [MallSubcategory]
}

enum MallProductBadgeStyle: String, Hashable, Sendable {
    case sale
    case brand
    case featured
}

struct MallProductBadge: Hashable, Sendable {
    let title: MallLocalizedString
    let style: MallProductBadgeStyle
}

struct MallHomeHighlightCard: Identifiable, Hashable, Sendable {
    let id: String
    let badge: MallLocalizedString
    let title: MallLocalizedString
    let subtitle: MallLocalizedString
    let image: MallImageSource
    let startHex: UInt32
    let endHex: UInt32
    let productID: String
}

struct MallHomeActivityCard: Identifiable, Hashable, Sendable {
    let id: String
    let tag: MallLocalizedString
    let title: MallLocalizedString
    let subtitle: MallLocalizedString
    let image: MallImageSource
    let startHex: UInt32
    let endHex: UInt32
    let categoryID: String
    let subcategoryID: String?
}

struct MallHomeRecommendationContent: Hashable, Sendable {
    let tabTitle: MallLocalizedString
    let highlightSectionTitle: MallLocalizedString
    let highlightCards: [MallHomeHighlightCard]
    let activitySectionTitle: MallLocalizedString
    let activityCards: [MallHomeActivityCard]
    let productSectionTitle: MallLocalizedString
}

enum MallProductDetailMediaType: String, Hashable, Sendable {
    case image
    case video
}

struct MallProductDetailMedia: Identifiable, Hashable, Sendable {
    let id: String
    let type: MallProductDetailMediaType
    let url: URL
}

struct MallProduct: Identifiable, Hashable, Sendable {
    let id: String
    let categoryID: String
    let subcategoryID: String
    let thirdCategoryID: String
    let title: MallLocalizedString
    let subtitle: MallLocalizedString
    let coverImage: MallImageSource
    let detailMediaList: [MallProductDetailMedia]
    let price: Decimal
    let originalPrice: Decimal?
    let badge: MallProductBadge
    let tags: [MallLocalizedString]
    let salesCount: Int
    let sortWeight: Int
    let updatedAt: Date
    let detailTarget: String

    func resolvedTitle(for language: AppLanguage) -> String {
        title.value(for: language)
    }

    func resolvedSubtitle(for language: AppLanguage) -> String {
        subtitle.value(for: language)
    }

    func resolvedBadge(for language: AppLanguage) -> String {
        badge.title.value(for: language)
    }

    func resolvedTags(for language: AppLanguage) -> [String] {
        tags.map { $0.value(for: language) }
    }

    func formattedPrice(for locale: Locale) -> String {
        formatDecimal(price, locale: locale)
    }

    func formattedOriginalPrice(for locale: Locale) -> String? {
        guard let originalPrice else {
            return nil
        }
        return formatDecimal(originalPrice, locale: locale)
    }

    func salesText(for language: AppLanguage) -> String {
        switch language {
        case .simplifiedChinese:
            return "销量 \(compactChineseSalesCount)"
        case .english:
            return "Sales \(compactSalesCount)"
        case .arabic:
            return "المبيعات \(compactSalesCount)"
        }
    }

    func matches(query: String, language: AppLanguage) -> Bool {
        let normalizedQuery = normalizedSearchValue(query)
        guard !normalizedQuery.isEmpty else {
            return false
        }

        let searchableValues = [
            resolvedTitle(for: language),
            resolvedSubtitle(for: language),
            title.simplifiedChinese,
            title.english,
            title.arabic,
            subtitle.simplifiedChinese,
            subtitle.english,
            subtitle.arabic,
        ] + resolvedTags(for: language)

        return searchableValues.contains { value in
            normalizedSearchValue(value).contains(normalizedQuery)
        }
    }

    private var compactSalesCount: String {
        if salesCount >= 1_000 {
            let value = Double(salesCount) / 1_000
            return String(format: "%.0fK+", value.rounded())
        }

        return "\(salesCount)+"
    }

    private var compactChineseSalesCount: String {
        if salesCount >= 10_000 {
            let value = Double(salesCount) / 10_000
            return String(format: "%.1f万+", value)
        }

        return "\(salesCount)+"
    }
}

enum MallProductDetailHeroMediaType: String, Hashable, Sendable {
    case image
    case video
}

struct MallProductDetailHeroMedia: Identifiable, Hashable, Sendable {
    let id: String
    let type: MallProductDetailHeroMediaType
    let previewImage: MallImageSource
}

enum MallProductDetailSpecificationDisplayMode: String, Hashable, Sendable {
    case chip
    case imageTile
}

struct MallProductDetailSpecificationValue: Identifiable, Hashable, Sendable {
    let id: String
    let title: MallLocalizedString
    let image: MallImageSource?
    let swatchHex: UInt32?
}

struct MallProductDetailSpecificationGroup: Identifiable, Hashable, Sendable {
    let id: String
    let title: MallLocalizedString
    let displayMode: MallProductDetailSpecificationDisplayMode
    let values: [MallProductDetailSpecificationValue]
}

struct MallProductDetailSKU: Identifiable, Hashable, Sendable {
    let id: String
    let valueIDs: [String]
    let price: Decimal
    let originalPrice: Decimal?
    let saleEndsText: MallLocalizedString
    let previewImage: MallImageSource
    let isDefault: Bool

    func formattedPrice(for locale: Locale) -> String {
        formatDecimal(price, locale: locale)
    }

    func formattedOriginalPrice(for locale: Locale) -> String? {
        guard let originalPrice else {
            return nil
        }
        return formatDecimal(originalPrice, locale: locale)
    }
}

struct MallProductDetailSnapshot: Identifiable, Hashable, Sendable {
    let id: String
    let searchPlaceholder: MallLocalizedString
    let cartBadgeCount: Int
    let heroMedia: [MallProductDetailHeroMedia]
    let saleLabel: MallLocalizedString
    let title: MallLocalizedString
    let subtitle: MallLocalizedString
    let brandText: MallLocalizedString?
    let shipmentSummary: MallLocalizedString
    let deliveryAddressSummary: MallLocalizedString
    let detailSectionTitle: MallLocalizedString
    let detailHTML: MallLocalizedString
    let selectionQuantitySuffix: MallLocalizedString
    let specificationGroups: [MallProductDetailSpecificationGroup]
    let skus: [MallProductDetailSKU]

    var defaultSKU: MallProductDetailSKU? {
        skus.first(where: \.isDefault) ?? skus.first
    }

    var firstSpecificationGroup: MallProductDetailSpecificationGroup? {
        specificationGroups.first
    }

    func sku(id: String) -> MallProductDetailSKU? {
        skus.first { $0.id == id }
    }

    func specificationValue(id: String) -> MallProductDetailSpecificationValue? {
        specificationGroups
            .flatMap(\.values)
            .first { $0.id == id }
    }

    func selectedValueID(
        for groupID: String,
        in sku: MallProductDetailSKU
    ) -> String? {
        let valueIDs = Set(group(id: groupID)?.values.map(\.id) ?? [])
        return sku.valueIDs.first(where: valueIDs.contains)
    }

    func availableValueIDs(
        for groupID: String,
        selectedValueIDs: Set<String>
    ) -> Set<String> {
        guard let group = group(id: groupID) else {
            return []
        }

        var selectedValueIDsByGroup = selectedValuesByGroup(from: selectedValueIDs)
        return Set(group.values.compactMap { value in
            selectedValueIDsByGroup[groupID] = value.id
            let candidateValues = Set(selectedValueIDsByGroup.values)
            let matches = skus.contains { sku in
                Set(sku.valueIDs) == candidateValues
            }
            return matches ? value.id : nil
        })
    }

    func currentSKU(for selectedValueIDs: Set<String>) -> MallProductDetailSKU? {
        skus.first { Set($0.valueIDs) == selectedValueIDs } ?? defaultSKU
    }

    func selectedSummary(
        for sku: MallProductDetailSKU,
        language: AppLanguage
    ) -> String {
        let selectedTitles = selectedTitles(for: sku, language: language)

        let baseText = selectedTitles.joined(separator: " ")
        let suffix = selectionQuantitySuffix.value(for: language)
        guard !baseText.isEmpty else {
            return suffix
        }
        return "\(baseText), \(suffix)"
    }

    func typesSummary(language: AppLanguage) -> String {
        let count = firstSpecificationGroup?.values.count ?? 0
        switch language {
        case .simplifiedChinese:
            return "\(count) 款"
        case .english:
            return "\(count) types"
        case .arabic:
            return "\(count) أنواع"
        }
    }

    func specificationSummary(
        for sku: MallProductDetailSKU,
        language: AppLanguage
    ) -> String {
        selectedTitles(for: sku, language: language).joined(separator: " ")
    }

    func selectedSummaryValue(for sku: MallProductDetailSKU) -> MallLocalizedString {
        MallLocalizedString(
            selectedSummary(for: sku, language: .simplifiedChinese),
            selectedSummary(for: sku, language: .english),
            selectedSummary(for: sku, language: .arabic)
        )
    }

    func specificationSummaryValue(for sku: MallProductDetailSKU) -> MallLocalizedString {
        MallLocalizedString(
            specificationSummary(for: sku, language: .simplifiedChinese),
            specificationSummary(for: sku, language: .english),
            specificationSummary(for: sku, language: .arabic)
        )
    }

    private func group(id: String) -> MallProductDetailSpecificationGroup? {
        specificationGroups.first { $0.id == id }
    }

    private func selectedTitles(
        for sku: MallProductDetailSKU,
        language: AppLanguage
    ) -> [String] {
        specificationGroups.compactMap { group in
            guard
                let valueID = selectedValueID(for: group.id, in: sku),
                let value = specificationValue(id: valueID)
            else {
                return nil
            }
            return value.title.value(for: language)
        }
    }

    private func selectedValuesByGroup(from selectedValueIDs: Set<String>) -> [String: String] {
        var valuesByGroup: [String: String] = [:]

        for group in specificationGroups {
            for value in group.values where selectedValueIDs.contains(value.id) {
                valuesByGroup[group.id] = value.id
            }
        }

        return valuesByGroup
    }
}

struct MallCartItem: Identifiable, Hashable, Sendable {
    let id: String
    let productID: String
    let skuID: String
    let title: MallLocalizedString
    let selectedSummary: MallLocalizedString
    let image: MallImageSource
    let saleLabel: MallLocalizedString?
    let saleEndsText: MallLocalizedString?
    let price: Decimal
    let originalPrice: Decimal?
    let quantity: Int
    let isSelected: Bool
    let isInvalid: Bool
    let invalidReason: MallLocalizedString?
    let updatedAt: Date

    var isSelectable: Bool {
        !isInvalid
    }

    var lineSubtotal: Decimal {
        price * Decimal(quantity)
    }

    func formattedPrice(for locale: Locale) -> String {
        formatDecimal(price, locale: locale)
    }

    func formattedOriginalPrice(for locale: Locale) -> String? {
        guard let originalPrice else {
            return nil
        }
        return formatDecimal(originalPrice, locale: locale)
    }

    func formattedLineSubtotal(for locale: Locale) -> String {
        formatDecimal(lineSubtotal, locale: locale)
    }
}

struct MallProductDetailEntry: Sendable {
    let product: MallProduct
    let snapshot: MallProductDetailSnapshot
}

struct MallCartSnapshot: Sendable {
    let items: [MallCartItem]

    var badgeCount: Int {
        items.reduce(0) { partialResult, item in
            partialResult + item.quantity
        }
    }

    var selectedItems: [MallCartItem] {
        items.filter { $0.isSelected && $0.isSelectable }
    }

    var subtotal: Decimal {
        selectedItems.reduce(.zero) { partialResult, item in
            partialResult + item.lineSubtotal
        }
    }

    var selectedLineCount: Int {
        selectedItems.count
    }

    var selectedQuantity: Int {
        selectedItems.reduce(0) { partialResult, item in
            partialResult + item.quantity
        }
    }

    var isAllSelected: Bool {
        let selectableItems = items.filter(\.isSelectable)
        guard !selectableItems.isEmpty else {
            return false
        }
        return selectableItems.allSatisfy(\.isSelected)
    }

    var invalidItems: [MallCartItem] {
        items.filter(\.isInvalid)
    }

    var selectableItemIDs: [String] {
        items.filter(\.isSelectable).map(\.id)
    }

    func formattedSubtotal(for locale: Locale) -> String {
        formatDecimal(subtotal, locale: locale)
    }
}

struct MallCartCheckoutPreview: Sendable {
    let items: [MallCartItem]
    let subtotal: Decimal
    let selectedQuantity: Int
    let title: MallLocalizedString
    let message: MallLocalizedString

    func formattedSubtotal(for locale: Locale) -> String {
        formatDecimal(subtotal, locale: locale)
    }
}

struct MallCartAddItemRequest: Sendable {
    let productID: String
    let skuID: String
    let title: MallLocalizedString
    let selectedSummary: MallLocalizedString
    let image: MallImageSource
    let saleLabel: MallLocalizedString?
    let saleEndsText: MallLocalizedString?
    let price: Decimal
    let originalPrice: Decimal?
    let quantity: Int
}

struct MallCartQuantityUpdateRequest: Sendable {
    let itemID: String
    let quantity: Int
}

struct MallCartSKUUpdateRequest: Sendable {
    let itemID: String
    let productID: String
    let skuID: String
    let selectedSummary: MallLocalizedString
    let image: MallImageSource
    let saleLabel: MallLocalizedString?
    let saleEndsText: MallLocalizedString?
    let price: Decimal
    let originalPrice: Decimal?
}

struct MallCartSelectionUpdateRequest: Sendable {
    let itemIDs: [String]
    let isSelected: Bool
}

struct MallCartDeleteItemsRequest: Sendable {
    let itemIDs: [String]
}

struct MallCartCheckoutRequest: Sendable {
    let itemIDs: [String]
}

struct MallHotKeyword: Identifiable, Hashable, Sendable {
    let id: String
    let title: MallLocalizedString
    let meta: MallLocalizedString
}

struct MallHomeSnapshot: Sendable {
    let searchPlaceholder: MallLocalizedString
    let recommendation: MallHomeRecommendationContent
    let primaryCategories: [MallPrimaryCategory]
    let products: [MallProduct]
    let defaultCategoryID: String
    let cartBadgeCount: Int
}

enum MallHomeProductFeedScene: String, Hashable, Sendable {
    case recommendation
    case category
}

struct MallHomeProductFeedSnapshot: Sendable {
    let scene: MallHomeProductFeedScene
    let categoryID: String?
    let pageNum: Int
    let pageSize: Int
    let total: Int
    let hasMore: Bool
    let products: [MallProduct]
}

struct MallSearchBootstrap: Sendable {
    var history: [String]
    let hotKeywords: [MallHotKeyword]
}

struct MallSearchResultSnapshot: Sendable {
    let query: String
    let categoryID: String?
    let pageNum: Int
    let pageSize: Int
    let total: Int
    let hasMore: Bool
    let products: [MallProduct]
}

enum MallSearchSortMode: String, Hashable, Sendable {
    case best
    case sales
    case price
    case newest

    var localizationKey: String {
        switch self {
        case .best:
            return "mall.sort.best"
        case .sales:
            return "mall.sort.sales"
        case .price:
            return "mall.sort.price"
        case .newest:
            return "mall.sort.newest"
        }
    }
}

enum MallSortOrder: String, Hashable, Sendable {
    case ascending
    case descending
}

enum MallPaginationDefaults {
    static let firstPage = 1
    static let pageSize = 20
}

private func formatDecimal(_ value: Decimal, locale: Locale) -> String {
    let formatter = NumberFormatter()
    formatter.locale = locale
    formatter.numberStyle = .decimal

    var roundedValue = Decimal()
    var mutableValue = value
    NSDecimalRound(&roundedValue, &mutableValue, 0, .plain)
    let hasFraction = roundedValue != value

    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = hasFraction ? 2 : 0
    return formatter.string(from: NSDecimalNumber(decimal: value)) ?? NSDecimalNumber(decimal: value).stringValue
}

private func normalizedSearchValue(_ value: String) -> String {
    value
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
}
