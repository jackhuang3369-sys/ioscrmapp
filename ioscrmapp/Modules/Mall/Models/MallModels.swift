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
