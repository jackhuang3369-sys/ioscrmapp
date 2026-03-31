import Foundation
import os

#if canImport(CoreTelephony)
import CoreTelephony
#endif

#if canImport(Network)
import Network
#endif

private let homeLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "ioscrmapp",
    category: "Home"
)

private func homeDisplayMoney(_ value: String) -> String {
    // Isolate mixed LTR currency/number text so RTL layouts do not swap token order.
    "\u{2066}\(value)\u{2069}"
}

protocol HomeServicing: Sendable {
    func fetchDashboard(session: CustSubInfo) async throws -> HomeDashboardResponse
}

enum HomeServiceError: Error {
    case missingIdentity
    case featureUnavailable(message: String)
    case tooManyRequests
    case networkUnavailable

    var textValue: LocalizedTextValue {
        switch self {
        case .missingIdentity:
            return .key("home.state.errorSubtitle")
        case let .featureUnavailable(message):
            return .literal(message)
        case .tooManyRequests:
            return .key("common.error.tooManyRequests")
        case .networkUnavailable:
            return .key("home.state.errorSubtitle")
        }
    }
}

protocol HomeNetworkStatusProviding: Sendable {
    func currentStatus() async -> HomeNetworkStatus?
}

actor MockHomeService: HomeServicing {
    private let networkStatusProvider: any HomeNetworkStatusProviding

    init(networkStatusProvider: any HomeNetworkStatusProviding = SystemHomeNetworkStatusProvider()) {
        self.networkStatusProvider = networkStatusProvider
    }

    func fetchDashboard(session: CustSubInfo) async throws -> HomeDashboardResponse {
        try await Task.sleep(nanoseconds: 250_000_000)

        return HomeDashboardResponse(
            snapshot: HomeDashboardSnapshot(
                profile: HomeProfileSection(
                    displayName: session.displayName,
                    packageName: HomePackageName(
                        defaultName: "Power Plan 500",
                        arabicName: nil
                    ),
                    serviceNumber: (session.serviceNumber ?? session.phoneNumber),
                    networkStatus: await networkStatusProvider.currentStatus() ?? .fiveG
                ),
                summary: HomeSummarySection(
                    paymentType: .hybrid,
                    balanceValue: .literal(homeDisplayMoney("128.50 AED")),
                    currentBillValue: .literal(homeDisplayMoney("43.20 AED")),
                    dueDateValue: .literal("2026-03-28"),
                    creditLimit: HomeCreditLimitSection(
                        totalValue: .key("home.value.unlimited"),
                        usedValue: .literal(homeDisplayMoney("311.80 AED")),
                        remainingValue: .literal(homeDisplayMoney("188.20 AED"))
                    ),
                    inlineMessage: nil
                ),
                usage: HomeUsageSection(
                    cards: [
                        HomeUsageCard(kind: .data, value: .literal("23.4 / 30 GB"), progress: 0.22),
                        HomeUsageCard(kind: .voice, value: .literal("148 / 300 Min"), progress: 0.51),
                        HomeUsageCard(kind: .sms, value: .literal("42 / 100 SMS"), progress: 0.58),
                    ],
                    inlineMessage: nil
                )
            ),
            subscriberKey: session.subscriberKey
        )
    }
}

struct RemoteHomeService: HomeServicing {
    private let client: HTTPClient
    private let networkStatusProvider: any HomeNetworkStatusProviding

    init(
        serverURL: URL,
        session: URLSession = .shared,
        contextBuilder: NetworkContextBuilder = NetworkContextBuilder(),
        networkStatusProvider: any HomeNetworkStatusProviding = SystemHomeNetworkStatusProvider()
    ) {
        client = HTTPClient(
            baseURL: serverURL,
            session: session,
            contextBuilder: contextBuilder
        )
        self.networkStatusProvider = networkStatusProvider
    }

    func fetchDashboard(session: CustSubInfo) async throws -> HomeDashboardResponse {
        let identity = try session.homeIdentity()
        let userInfo = try await fetchUserInfo(
            requestServiceNumber: AuthValidator.localPhoneDigits(identity.serviceNumber),
            fallbackServiceNumber: identity.serviceNumber,
            username: identity.username
        )

        async let balanceResult: Result<HomeBalancePayload, HomeServiceError> = capture {
            try await fetchBalance(
                subscriberKey: userInfo.subscriberKey,
                paymentType: userInfo.paymentTypeCode
            )
        }
        async let freeUnitResult: Result<HomeFreeUnitPayload, HomeServiceError> = capture {
            try await fetchFreeUnits(subscriberKey: userInfo.subscriberKey)
        }
        async let networkStatus = networkStatusProvider.currentStatus()

        return buildDashboard(
            session: session,
            userInfo: userInfo,
            balanceResult: await balanceResult,
            freeUnitResult: await freeUnitResult,
            networkStatus: await networkStatus
        )
    }

    private func fetchUserInfo(
        requestServiceNumber: String,
        fallbackServiceNumber: String,
        username: String
    ) async throws -> HomeUserInfoPayload {
        do {
            let responseData = try await client.post(
                HomeAPI.userInfo,
                body: [
                    "serviceNumber": requestServiceNumber,
                    "language": HomeRequestLanguage.currentCode()
                ]
            )
            return try HomeResponseMapper.mapUserInfo(
                from: responseData,
                username: username,
                fallbackServiceNumber: fallbackServiceNumber
            )
        } catch let error as HTTPClient.ClientError {
            homeLogger.error("Fetch home user info failed: \(String(describing: error), privacy: .public)")
            throw mapClientError(error)
        } catch let error as HomeServiceError {
            throw error
        } catch {
            throw HomeServiceError.networkUnavailable
        }
    }

    private func fetchBalance(
        subscriberKey: String,
        paymentType: String
    ) async throws -> HomeBalancePayload {
        do {
            let responseData = try await client.post(
                HomeAPI.queryBalance,
                body: [
                    "subscriberKey": subscriberKey,
                    "paymentType": paymentType
                ]
            )
            return try HomeResponseMapper.mapBalance(from: responseData)
        } catch let error as HTTPClient.ClientError {
            homeLogger.error("Fetch home balance failed: \(String(describing: error), privacy: .public)")
            throw mapClientError(error)
        } catch let error as HomeServiceError {
            throw error
        } catch {
            throw HomeServiceError.networkUnavailable
        }
    }

    private func fetchFreeUnits(subscriberKey: String) async throws -> HomeFreeUnitPayload {
        do {
            let responseData = try await client.post(
                HomeAPI.queryFreeUnit,
                body: ["subscriberKey": subscriberKey]
            )
            return try HomeResponseMapper.mapFreeUnits(from: responseData)
        } catch let error as HTTPClient.ClientError {
            homeLogger.error("Fetch home free unit failed: \(String(describing: error), privacy: .public)")
            throw mapClientError(error)
        } catch let error as HomeServiceError {
            throw error
        } catch {
            throw HomeServiceError.networkUnavailable
        }
    }

    private func buildDashboard(
        session: CustSubInfo,
        userInfo: HomeUserInfoPayload,
        balanceResult: Result<HomeBalancePayload, HomeServiceError>,
        freeUnitResult: Result<HomeFreeUnitPayload, HomeServiceError>,
        networkStatus: HomeNetworkStatus?
    ) -> HomeDashboardResponse {
        let paymentType = HomePaymentType(code: userInfo.paymentTypeCode)
        let balancePayload = try? balanceResult.get()
        let freeUnitPayload = try? freeUnitResult.get()

        let balanceValue = moneyValue(
            amount: balancePayload?.balance?.amount,
            currencyID: balancePayload?.balance?.currencyID
        )
        let currentBillValue = moneyValue(
            amount: balancePayload?.outstanding?.amount,
            currencyID: balancePayload?.outstanding?.currencyID
        )
        let dueDateValue = dateValue(balancePayload?.outstanding?.dueDate)
        let creditLimit = creditLimitSection(
            from: balancePayload?.creditLimit,
            paymentType: paymentType
        )

        let usageCards = HomeUsageCard.Kind.allCases.map { kind in
            usageCard(for: kind, payload: freeUnitPayload?.totals[kind])
        }

        let packageName = userInfo.packageName?.isEmpty == false || userInfo.packageNameArabic?.isEmpty == false
            ? HomePackageName(
                defaultName: userInfo.packageName ?? "",
                arabicName: userInfo.packageNameArabic
            )
            : nil

        return HomeDashboardResponse(
            snapshot: HomeDashboardSnapshot(
                profile: HomeProfileSection(
                    displayName: userInfo.displayName,
                    packageName: packageName,
                    serviceNumber: userInfo.serviceNumber.isEmpty ? session.phoneNumber : userInfo.serviceNumber,
                    networkStatus: networkStatus
                ),
                summary: HomeSummarySection(
                    paymentType: paymentType,
                    balanceValue: balanceValue,
                    currentBillValue: currentBillValue,
                    dueDateValue: dueDateValue,
                    creditLimit: creditLimit,
                    inlineMessage: accountInlineMessage(
                        paymentType: paymentType,
                        balanceResult: balanceResult,
                        balanceValue: balanceValue,
                        currentBillValue: currentBillValue,
                        dueDateValue: dueDateValue,
                        creditLimit: creditLimit
                    )
                ),
                usage: HomeUsageSection(
                    cards: usageCards,
                    inlineMessage: usageInlineMessage(
                        freeUnitResult: freeUnitResult,
                        cards: usageCards
                    )
                )
            ),
            subscriberKey: userInfo.subscriberKey
        )
    }

    private func accountInlineMessage(
        paymentType: HomePaymentType,
        balanceResult: Result<HomeBalancePayload, HomeServiceError>,
        balanceValue: LocalizedTextValue,
        currentBillValue: LocalizedTextValue,
        dueDateValue: LocalizedTextValue,
        creditLimit: HomeCreditLimitSection?
    ) -> LocalizedTextValue? {
        if case .failure = balanceResult {
            return .key("home.state.billingPartial")
        }

        switch paymentType {
        case .prepaid:
            return isUnavailable(balanceValue) ? .key("home.state.billingPartial") : nil
        case .postpaid:
            if isUnavailable(currentBillValue) || isUnavailable(dueDateValue) || creditLimitHasUnavailableValue(creditLimit) {
                return .key("home.state.billingPartial")
            }
            return nil
        case .hybrid:
            if isUnavailable(balanceValue) || isUnavailable(currentBillValue) || isUnavailable(dueDateValue) || creditLimitHasUnavailableValue(creditLimit) {
                return .key("home.state.billingPartial")
            }
            return nil
        case .unknown:
            return isUnavailable(balanceValue) ? .key("home.state.billingPartial") : nil
        }
    }

    private func usageInlineMessage(
        freeUnitResult: Result<HomeFreeUnitPayload, HomeServiceError>,
        cards: [HomeUsageCard]
    ) -> LocalizedTextValue? {
        if case .failure = freeUnitResult {
            return .key("home.state.usagePartial")
        }

        if cards.contains(where: { isUnavailable($0.value) }) {
            return .key("home.state.usagePartial")
        }

        return nil
    }

    private func creditLimitSection(
        from payload: HomeCreditLimitPayload?,
        paymentType: HomePaymentType
    ) -> HomeCreditLimitSection? {
        switch paymentType {
        case .postpaid, .hybrid:
            break
        case .prepaid, .unknown:
            return nil
        }

        return HomeCreditLimitSection(
            totalValue: creditTotalValue(
                amount: payload?.totalAmount,
                currencyID: payload?.currencyID
            ),
            usedValue: moneyValue(
                amount: payload?.usedAmount,
                currencyID: payload?.currencyID
            ),
            remainingValue: moneyValue(
                amount: payload?.remainingAmount,
                currencyID: payload?.currencyID
            )
        )
    }

    private func usageCard(
        for kind: HomeUsageCard.Kind,
        payload: HomeFreeUnitTotalPayload?
    ) -> HomeUsageCard {
        guard let payload else {
            return HomeUsageCard(kind: kind, value: HomeDisplayValue.unavailable, progress: 0)
        }

        let unitSuffix = unitLabel(for: payload.unit)
        let remaining = displayNumber(payload.remaining)
        let total = displayNumber(payload.total)
        let value: LocalizedTextValue

        if let remaining, let total {
            let suffix = unitSuffix.isEmpty ? "" : " \(unitSuffix)"
            value = .literal("\(remaining) / \(total)\(suffix)")
        } else {
            value = HomeDisplayValue.unavailable
        }

        return HomeUsageCard(
            kind: kind,
            value: value,
            progress: progressValue(
                usedPercent: payload.usedPercent,
                usedAmount: payload.used,
                totalAmount: payload.total
            )
        )
    }

    private func moneyValue(amount: String?, currencyID: String?) -> LocalizedTextValue {
        guard let amount = displayNumber(amount) else {
            return HomeDisplayValue.unavailable
        }

        let currencyCode = currencyCode(for: currencyID)
        if currencyCode.isEmpty {
            return .literal(homeDisplayMoney(amount))
        }

        return .literal(homeDisplayMoney("\(amount) \(currencyCode)"))
    }

    private func creditTotalValue(amount: String?, currencyID: String?) -> LocalizedTextValue {
        if amount?.trimmingCharacters(in: .whitespacesAndNewlines) == "-1" {
            return .key("home.value.unlimited")
        }

        return moneyValue(amount: amount, currencyID: currencyID)
    }

    private func dateValue(_ rawValue: String?) -> LocalizedTextValue {
        guard let trimmed = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines), trimmed.count >= 10 else {
            return HomeDisplayValue.unavailable
        }

        return .literal(String(trimmed.prefix(10)))
    }

    private func mapClientError(_ error: HTTPClient.ClientError) -> HomeServiceError {
        switch error {
        case let .business(_, message, _):
            let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedMessage.isEmpty
                ? .networkUnavailable
                : .featureUnavailable(message: trimmedMessage)
        case .tooManyRequests:
            return .tooManyRequests
        case .httpStatus, .invalidJSON, .invalidResponse, .networkUnavailable:
            return .networkUnavailable
        }
    }

    private func capture<T>(
        _ operation: () async throws -> T
    ) async -> Result<T, HomeServiceError> {
        do {
            return .success(try await operation())
        } catch let error as HomeServiceError {
            return .failure(error)
        } catch {
            return .failure(.networkUnavailable)
        }
    }

    private func progressValue(
        usedPercent: String?,
        usedAmount: String?,
        totalAmount: String?
    ) -> Double {
        if let usedPercent = displayDecimal(usedPercent) {
            let raw = NSDecimalNumber(decimal: usedPercent).doubleValue
            return min(max(raw > 1 ? raw / 100 : raw, 0), 1)
        }

        guard
            let used = displayDecimal(usedAmount),
            let total = displayDecimal(totalAmount),
            total != .zero
        else {
            return 0
        }

        return min(max(NSDecimalNumber(decimal: used / total).doubleValue, 0), 1)
    }

    private func displayNumber(_ rawValue: String?) -> String? {
        guard let decimal = displayDecimal(rawValue) else {
            return nil
        }

        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ","
        return formatter.string(from: NSDecimalNumber(decimal: decimal))
    }

    private func displayDecimal(_ rawValue: String?) -> Decimal? {
        guard let trimmed = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }

        return Decimal(string: trimmed, locale: Locale(identifier: "en_US_POSIX"))
    }

    private func currencyCode(for currencyID: String?) -> String {
        switch currencyID?.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "784":
            return "AED"
        default:
            return "AED"
        }
    }

    private func unitLabel(for unit: String?) -> String {
        switch unit?.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "1109":
            return "GB"
        case "1108":
            return "MB"
        case "1004":
            return "Min"
        case "1006":
            return "SMS"
        case "10000":
            return "Units"
        default:
            return ""
        }
    }

    private func isUnavailable(_ value: LocalizedTextValue) -> Bool {
        value == HomeDisplayValue.unavailable
    }

    private func creditLimitHasUnavailableValue(_ creditLimit: HomeCreditLimitSection?) -> Bool {
        guard let creditLimit else {
            return true
        }

        return isUnavailable(creditLimit.totalValue)
            || isUnavailable(creditLimit.usedValue)
            || isUnavailable(creditLimit.remainingValue)
    }
}

struct SystemHomeNetworkStatusProvider: HomeNetworkStatusProviding {
    func currentStatus() async -> HomeNetworkStatus? {
        #if canImport(Network)
        if await isUsingWiFi() {
            return .wifi
        }
        #endif

        return currentCellularStatus()
    }

    #if canImport(Network)
    private func isUsingWiFi() async -> Bool {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "ioscrmapp.home.network")

        return await withCheckedContinuation { continuation in
            let state = HomeNetworkContinuationState()

            @Sendable func finish(with value: Bool) {
                guard !state.resumed else {
                    return
                }

                state.resumed = true
                monitor.cancel()
                continuation.resume(returning: value)
            }

            monitor.pathUpdateHandler = { path in
                finish(with: path.usesInterfaceType(.wifi))
            }

            monitor.start(queue: queue)
            queue.asyncAfter(deadline: .now() + 0.35) {
                finish(with: false)
            }
        }
    }
    #endif

    private func currentCellularStatus() -> HomeNetworkStatus? {
        #if canImport(CoreTelephony)
        let networkInfo = CTTelephonyNetworkInfo()
        let technology = networkInfo.serviceCurrentRadioAccessTechnology?.values.first
        return mapRadioTechnology(technology)
        #else
        return nil
        #endif
    }

    private func mapRadioTechnology(_ technology: String?) -> HomeNetworkStatus? {
        guard let technology else {
            return nil
        }

        #if canImport(CoreTelephony)
        if #available(iOS 14.1, *) {
            if technology == CTRadioAccessTechnologyNR || technology == CTRadioAccessTechnologyNRNSA {
                return .fiveG
            }
        }
        #endif

        return .fourG
    }
}

private struct HomeIdentity {
    let username: String
    let serviceNumber: String
}

private enum HomeRequestLanguage {
    private static let storedLanguageKey = "app.language"

    static func currentCode(defaults: UserDefaults = .standard) -> String {
        let storedLanguage = defaults.string(forKey: storedLanguageKey)
            .flatMap(AppLanguage.init(rawValue:))
            ?? .fallback

        switch storedLanguage {
        case .arabic:
            return AppLanguage.arabic.rawValue
        case .english, .simplifiedChinese:
            return AppLanguage.english.rawValue
        }
    }
}

private final class HomeNetworkContinuationState: @unchecked Sendable {
    var resumed = false
}

private extension CustSubInfo {
    func homeIdentity() throws -> HomeIdentity {
        let resolvedServiceNumber = (serviceNumber ?? AuthValidator.normalizedPhone(phoneNumber))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedUsername = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !resolvedServiceNumber.isEmpty else {
            throw HomeServiceError.missingIdentity
        }

        return HomeIdentity(
            username: resolvedUsername,
            serviceNumber: resolvedServiceNumber
        )
    }
}

private struct HomeUserInfoPayload {
    let subscriberKey: String
    let paymentTypeCode: String
    let displayName: String
    let serviceNumber: String
    let packageName: String?
    let packageNameArabic: String?
}

private struct HomeMoneyPayload {
    let amount: String?
    let currencyID: String?
}

private struct HomeOutstandingPayload {
    let amount: String?
    let currencyID: String?
    let dueDate: String?
}

private struct HomeCreditLimitPayload {
    let currencyID: String?
    let totalAmount: String?
    let usedAmount: String?
    let remainingAmount: String?
}

private struct HomeBalancePayload {
    let balance: HomeMoneyPayload?
    let outstanding: HomeOutstandingPayload?
    let creditLimit: HomeCreditLimitPayload?
}

private struct HomeFreeUnitTotalPayload {
    let total: String?
    let used: String?
    let remaining: String?
    let unit: String?
    let usedPercent: String?
}

private struct HomeFreeUnitPayload {
    let totals: [HomeUsageCard.Kind: HomeFreeUnitTotalPayload]
}

private enum HomeResponseMapper {
    static func mapUserInfo(
        from responseData: HTTPClient.ResponseData,
        username: String,
        fallbackServiceNumber: String
    ) throws -> HomeUserInfoPayload {
        guard let object = responseData.objectValue else {
            throw HomeServiceError.networkUnavailable
        }

        let subscriberKey = string(in: object, key: "subscriberKey") ?? ""
        let paymentTypeCode = string(in: object, key: "paymentType") ?? "0"
        let serviceNumber = string(in: object, key: "serviceNumber") ?? fallbackServiceNumber
        let nickName = string(in: object, key: "nickName")
        let resolvedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = [
            nickName?.trimmingCharacters(in: .whitespacesAndNewlines),
            resolvedUsername.isEmpty ? nil : resolvedUsername,
            serviceNumber
        ]
        .compactMap { value in
            guard let value, !value.isEmpty else {
                return nil
            }
            return value
        }
        .first ?? fallbackServiceNumber

        guard !subscriberKey.isEmpty else {
            throw HomeServiceError.networkUnavailable
        }

        return HomeUserInfoPayload(
            subscriberKey: subscriberKey,
            paymentTypeCode: paymentTypeCode,
            displayName: displayName,
            serviceNumber: serviceNumber,
            packageName: string(in: object, key: "mainOfferName"),
            packageNameArabic: string(in: object, key: "mainOfferNameAR")
        )
    }

    static func mapBalance(from responseData: HTTPClient.ResponseData) throws -> HomeBalancePayload {
        guard let object = responseData.objectValue else {
            throw HomeServiceError.networkUnavailable
        }

        let balanceObject = object["balanceDto"]?.objectValue
        let outstandingObject = object["outStandingDto"]?.objectValue
        let creditLimitObject = object["creditLimitDto"]?.objectValue

        return HomeBalancePayload(
            balance: balanceObject.map {
                HomeMoneyPayload(
                    amount: string(in: $0, key: "balanceAmount"),
                    currencyID: string(in: $0, key: "currencyId")
                )
            },
            outstanding: outstandingObject.map {
                HomeOutstandingPayload(
                    amount: string(in: $0, key: "outstandingAmount"),
                    currencyID: string(in: $0, key: "currencyId"),
                    dueDate: string(in: $0, key: "dueDate")
                )
            },
            creditLimit: creditLimitObject.map {
                HomeCreditLimitPayload(
                    currencyID: string(in: $0, key: "currencyId"),
                    totalAmount: string(in: $0, key: "taotalCreditAmount"),
                    usedAmount: string(in: $0, key: "totalUsageAmount"),
                    remainingAmount: string(in: $0, key: "totalRemainAmount")
                )
            }
        )
    }

    static func mapFreeUnits(from responseData: HTTPClient.ResponseData) throws -> HomeFreeUnitPayload {
        guard let object = responseData.objectValue else {
            throw HomeServiceError.networkUnavailable
        }

        let totals = object["totalDto"]?.arrayValue ?? []
        let mappedTotals = totals.reduce(into: [HomeUsageCard.Kind: HomeFreeUnitTotalPayload]()) { partialResult, item in
            guard
                let usageItem = item.objectValue,
                let kind = usageKind(from: string(in: usageItem, key: "type"))
            else {
                return
            }

            partialResult[kind] = HomeFreeUnitTotalPayload(
                total: string(in: usageItem, key: "total"),
                used: string(in: usageItem, key: "usage"),
                remaining: string(in: usageItem, key: "unUsage"),
                unit: string(in: usageItem, key: "unit"),
                usedPercent: string(in: usageItem, key: "usedPercent")
            )
        }

        return HomeFreeUnitPayload(totals: mappedTotals)
    }

    private static func usageKind(from rawValue: String?) -> HomeUsageCard.Kind? {
        switch rawValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "data":
            return .data
        case "voice":
            return .voice
        case "sms":
            return .sms
        default:
            return nil
        }
    }

    private static func string(
        in object: [String: HTTPClient.ResponseData],
        key: String
    ) -> String? {
        if let value = object[key]?.stringValue {
            return value
        }

        if let value = object[key]?.intValue {
            return String(value)
        }

        if let value = object[key]?.doubleValue {
            return String(value)
        }

        return nil
    }
}
