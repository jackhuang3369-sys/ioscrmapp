import Foundation

enum OffersResourceType: String, CaseIterable, Identifiable, Hashable, Sendable {
    case all = ""
    case data = "Data"
    case voice = "Voice"
    case sms = "SMS"

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .all:
            return "offers.resource.all"
        case .data:
            return "offers.resource.data"
        case .voice:
            return "offers.resource.voice"
        case .sms:
            return "offers.resource.sms"
        }
    }
}

enum OffersValidityBucket: String, CaseIterable, Identifiable, Hashable, Sendable {
    case daily
    case weekly
    case monthly

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .daily:
            return "offers.validity.daily"
        case .weekly:
            return "offers.validity.weekly"
        case .monthly:
            return "offers.validity.monthly"
        }
    }
}

enum OffersSortOption: String, CaseIterable, Identifiable, Hashable, Sendable {
    case popular
    case price

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .popular:
            return "offers.sort.popular"
        case .price:
            return "offers.sort.price"
        }
    }
}

enum OffersPriceRange: String, CaseIterable, Identifiable, Hashable, Sendable {
    case zeroToTwentyFive
    case twentyFiveToFifty
    case fiftyToOneHundred
    case aboveOneHundred

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .zeroToTwentyFive:
            return "offers.priceRange.zeroToTwentyFive"
        case .twentyFiveToFifty:
            return "offers.priceRange.twentyFiveToFifty"
        case .fiftyToOneHundred:
            return "offers.priceRange.fiftyToOneHundred"
        case .aboveOneHundred:
            return "offers.priceRange.aboveOneHundred"
        }
    }

    func contains(_ value: Decimal) -> Bool {
        switch self {
        case .zeroToTwentyFive:
            return value >= 0 && value < 25
        case .twentyFiveToFifty:
            return value >= 25 && value < 50
        case .fiftyToOneHundred:
            return value >= 50 && value <= 100
        case .aboveOneHundred:
            return value > 100
        }
    }
}

enum OffersOrderSubscribeType: String, CaseIterable, Identifiable, Hashable, Sendable {
    case add
    case delete

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .add:
            return "offers.orders.subscribeType.add"
        case .delete:
            return "offers.orders.subscribeType.delete"
        }
    }
}

enum OffersOrderStatus: String, CaseIterable, Identifiable, Hashable, Sendable {
    case initial = "0"
    case success = "1"
    case abnormal = "2"

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .initial:
            return "offers.orders.status.initial"
        case .success:
            return "offers.orders.status.success"
        case .abnormal:
            return "offers.orders.status.abnormal"
        }
    }
}

enum OffersOperationType: String, Sendable {
    case subscribe
    case unsubscribe

    var titleKey: String {
        switch self {
        case .subscribe:
            return "offers.operation.subscribe"
        case .unsubscribe:
            return "offers.operation.unsubscribe"
        }
    }

    var acceptedTitleKey: String {
        switch self {
        case .subscribe:
            return "offers.accepted.subscribe.title"
        case .unsubscribe:
            return "offers.accepted.unsubscribe.title"
        }
    }

    var acceptedBodyKey: String {
        switch self {
        case .subscribe:
            return "offers.accepted.subscribe.body"
        case .unsubscribe:
            return "offers.accepted.unsubscribe.body"
        }
    }
}

struct PrimaryOfferSummary: Equatable, Sendable {
    let offerId: String
    let offerCode: String
    let offerName: String
    let effectiveDate: String
    let expiryDate: String
}

struct SubscribedOfferItem: Identifiable, Equatable, Sendable {
    let id: String
    let offerId: String
    let itemInstanceId: String
    let offerName: String
    let offerCategory: String
    let effectiveDate: String
    let expiryDate: String
    let canUnsubscribe: Bool
}

struct OfferCategoryItem: Identifiable, Equatable, Hashable, Sendable {
    let id: String
    let name: String
    let parentId: String?
    let sortOrder: Int?
}

struct EligibleOfferItem: Identifiable, Equatable, Sendable {
    let id: String
    let offerId: String
    let offerCode: String
    let offerName: String
    let offerType: String
    let validityRaw: String?
    let validityBucket: OffersValidityBucket?
    let resourceSummary: String?
    let displayPriceText: String?
    let displayPriceValue: Decimal?
    let popularRank: Int?
    let originalIndex: Int
}

struct OffersLandingSnapshot: Equatable, Sendable {
    let primaryOffer: PrimaryOfferSummary
    let subscribedOffers: [SubscribedOfferItem]
}

struct OffersOrderRecord: Identifiable, Equatable, Sendable {
    let id: String
    let orderId: String
    let offerName: String
    let createdTimeText: String
    let subscribeType: OffersOrderSubscribeType
    let status: OffersOrderStatus
    let statusCode: String
    let offerType: String?
    let effectiveMode: String?
}

struct OffersOrderPageSnapshot: Equatable, Sendable {
    let records: [OffersOrderRecord]
    let pageIndex: Int
    let pageSize: Int
    let totalCount: Int
    let totalPages: Int
}

struct OffersOrderFilter: Equatable, Sendable {
    var startDate: Date?
    var endDate: Date?
    var subscribeType: OffersOrderSubscribeType?
    var status: OffersOrderStatus?

    static let empty = OffersOrderFilter(
        startDate: nil,
        endDate: nil,
        subscribeType: nil,
        status: nil
    )
}

struct OfferAcceptedResult: Identifiable, Equatable, Sendable {
    let orderId: String
    let offerName: String
    let operationType: OffersOperationType

    var id: String { orderId }
}

enum OfferChangeRequest: Sendable {
    case subscribe(EligibleOfferItem)
    case unsubscribe(SubscribedOfferItem)
}
