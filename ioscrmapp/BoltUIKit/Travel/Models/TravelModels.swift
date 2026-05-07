import Foundation

// MARK: - Travel Intent
/// 行程意图数据模型
struct TravelIntent: Identifiable, Equatable, Sendable {
    let id = UUID()
    let destination: String
    let departureDate: Date?
    let returnDate: Date?
    let transportMode: TravelTransportMode
    let passengerCount: Int
    let priceRange: PriceRange?
    let suggestions: [TravelSuggestion]

    struct PriceRange: Equatable, Sendable {
        let min: Double
        let max: Double
        let currency: String

        var displayText: String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = currency
            let minStr = formatter.string(from: NSNumber(value: min)) ?? "\(min)"
            let maxStr = formatter.string(from: NSNumber(value: max)) ?? "\(max)"
            return "\(minStr) - \(maxStr)"
        }
    }

    var formattedDateRange: String? {
        guard let departure = departureDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        if let returnDate = returnDate {
            return "\(formatter.string(from: departure)) - \(formatter.string(from: returnDate))"
        }
        return formatter.string(from: departure)
    }

    var nightsCount: Int? {
        guard let departure = departureDate, let returnDate = returnDate else { return nil }
        let components = Calendar.current.dateComponents([.day], from: departure, to: returnDate)
        return components.day
    }
}

// MARK: - Travel Transport Mode
enum TravelTransportMode: String, Codable, CaseIterable, Sendable {
    case flight
    case train
    case bus

    var icon: String {
        switch self {
        case .flight: return "airplane"
        case .train: return "tram.fill"
        case .bus: return "bus.fill"
        }
    }

    var displayName: String {
        switch self {
        case .flight: return "Flight"
        case .train: return "Train"
        case .bus: return "Bus"
        }
    }
}

// MARK: - Travel Suggestion
struct TravelSuggestion: Identifiable, Equatable, Sendable {
    let id = UUID()
    let type: SuggestionType
    let title: String
    let subtitle: String
    let price: String?
    let rating: Double?
    let badge: String?
    let imageURL: URL?
    let actionTitle: String

    enum SuggestionType: Equatable, Sendable {
        case hotel
        case flight
        case activity
        case package

        var displayName: String {
            switch self {
            case .hotel: return "Hotel"
            case .flight: return "Flight"
            case .activity: return "Activity"
            case .package: return "Package"
            }
        }
    }
}

// MARK: - Localized String Provider
/// 多语言文本提供器
struct TravelLocalized {
    static let destination = BoltLocalizedString(key: "bolt.travel.destination", defaultValue: "Destination")
    static let departure = BoltLocalizedString(key: "bolt.travel.departure", defaultValue: "Departure")
    static let returnDate = BoltLocalizedString(key: "bolt.travel.return", defaultValue: "Return")
    static let passengers = BoltLocalizedString(key: "bolt.travel.passengers", defaultValue: "Passengers")
    static let nights = BoltLocalizedString(key: "bolt.travel.nights", defaultValue: "nights")
    static let priceFrom = BoltLocalizedString(key: "bolt.travel.price_from", defaultValue: "from")
    static let explore = BoltLocalizedString(key: "bolt.travel.explore", defaultValue: "Explore")
    static let viewDeal = BoltLocalizedString(key: "bolt.travel.view_deal", defaultValue: "View Deal")
    static let compare = BoltLocalizedString(key: "bolt.travel.compare", defaultValue: "Compare")
    static let bookNow = BoltLocalizedString(key: "bolt.travel.book_now", defaultValue: "Book Now")
}

// MARK: - Bolt Localized String
struct BoltLocalizedString {
    let key: String
    let defaultValue: String

    // 实际项目中应该从Localization service获取
    // 这里简化处理
    var value: String {
        // TODO: 接入实际的Localization系统
        return defaultValue
    }
}
