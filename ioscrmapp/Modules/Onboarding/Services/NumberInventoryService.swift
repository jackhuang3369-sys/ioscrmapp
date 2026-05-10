import Foundation

/// Backend contract for Journey 03 new-number inventory, suffix search, short-lock reservation, and stock refresh.
protocol NumberInventoryServicing: Sendable {
    func fetchNumbers(category: NumberCategory, suffix: String?, page: Int, pageSize: Int) async throws -> NumberInventoryPage
    func reserve(msisdn: String) async throws -> NumberSelection
    func stockStatus(msisdns: [String]) async throws -> [String: NumberReservationStatus]
}

enum NumberInventoryError: LocalizedError {
    case numberUnavailable
    case numberExpired
    case priceChanged

    var errorDescription: String? {
        switch self {
        case .numberUnavailable:
            return "This number is no longer available. Please choose another one."
        case .numberExpired:
            return "The number reservation expired. Please refresh and choose again."
        case .priceChanged:
            return "The premium number price changed. Please review the latest price."
        }
    }
}

/// Mock implementation that preserves the eventual API shape while product pricing and inventory rules are finalized.
struct MockNumberInventoryService: NumberInventoryServicing {
    private let allNumbers: [NumberInventoryItem]

    init() {
        allNumbers = Self.makePremiumNumbers() + Self.makeStandardNumbers()
    }

    func fetchNumbers(category: NumberCategory, suffix: String?, page: Int, pageSize: Int) async throws -> NumberInventoryPage {
        try await Task.sleep(nanoseconds: 420_000_000)

        let normalizedSuffix = suffix?.filter(\.isNumber)
        let filtered = allNumbers.filter { item in
            guard item.category == category else { return false }
            guard let normalizedSuffix, !normalizedSuffix.isEmpty else { return true }
            return item.msisdn.filter(\.isNumber).hasSuffix(normalizedSuffix)
        }

        let start = page * pageSize
        guard start < filtered.count else {
            return NumberInventoryPage(items: [], nextPage: nil)
        }

        let end = min(start + pageSize, filtered.count)
        let nextPage = end < filtered.count ? page + 1 : nil
        return NumberInventoryPage(items: Array(filtered[start..<end]), nextPage: nextPage)
    }

    func reserve(msisdn: String) async throws -> NumberSelection {
        try await Task.sleep(nanoseconds: 520_000_000)

        guard let item = allNumbers.first(where: { $0.msisdn == msisdn }) else {
            throw NumberInventoryError.numberUnavailable
        }

        guard item.reservationStatus == .available else {
            throw NumberInventoryError.numberUnavailable
        }

        // The lock id is intentionally opaque so downstream order APIs do not infer lock semantics from the client.
        return NumberSelection(
            numberType: item.category,
            selectedMsisdn: item.msisdn,
            premiumTier: item.premiumTier,
            premiumFee: item.price,
            lockId: "lock-\(UUID().uuidString)"
        )
    }

    func stockStatus(msisdns: [String]) async throws -> [String: NumberReservationStatus] {
        try await Task.sleep(nanoseconds: 260_000_000)
        return Dictionary(uniqueKeysWithValues: allNumbers
            .filter { msisdns.contains($0.msisdn) }
            .map { ($0.msisdn, $0.reservationStatus) })
    }

    private static func makePremiumNumbers() -> [NumberInventoryItem] {
        [
            item("+971 50 888 8888", tier: .royal, score: 98, price: 2_500),
            item("+971 50 777 7777", tier: .royal, score: 96, price: 2_500),
            item("+971 54 900 0000", tier: .elite, score: 94, price: 5_000),
            item("+971 58 555 5555", tier: .elite, score: 93, price: 5_000),
            item("+971 52 333 9999", tier: .gold, score: 88, price: 1_000),
            item("+971 56 123 9999", tier: .gold, score: 84, price: 1_000),
            item("+971 50 000 0001", tier: .platinum, score: 100, price: 10_000),
            item("+971 55 111 1111", tier: .platinum, score: 99, price: 10_000),
            item("+971 58 700 7777", tier: .royal, score: 92, price: 2_500),
            item("+971 56 808 0808", tier: .elite, score: 90, price: 5_000)
        ]
    }

    private static func makeStandardNumbers() -> [NumberInventoryItem] {
        [
            standard("+971 50 123 4567", score: 52),
            standard("+971 54 918 2046", score: 49),
            standard("+971 55 620 1843", score: 45),
            standard("+971 56 770 1942", score: 55),
            standard("+971 58 401 8729", score: 43),
            standard("+971 52 312 9088", score: 58),
            standard("+971 50 817 2201", score: 40),
            standard("+971 54 242 6007", score: 44),
            standard("+971 55 909 6612", score: 50),
            standard("+971 58 118 3456", score: 53),
            standard("+971 56 734 8888", score: 60),
            standard("+971 52 441 9999", score: 61)
        ]
    }

    private static func item(_ msisdn: String, tier: PremiumNumberTier, score: Int, price: Decimal) -> NumberInventoryItem {
        NumberInventoryItem(
            msisdn: msisdn,
            category: .premium,
            premiumTier: tier,
            vanityScore: score,
            price: price,
            currency: "AED",
            reservationStatus: .available
        )
    }

    private static func standard(_ msisdn: String, score: Int) -> NumberInventoryItem {
        NumberInventoryItem(
            msisdn: msisdn,
            category: .standard,
            premiumTier: nil,
            vanityScore: score,
            price: 0,
            currency: "AED",
            reservationStatus: .available
        )
    }
}
