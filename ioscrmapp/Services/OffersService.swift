import Foundation
import os
#if canImport(UIKit)
import UIKit
#endif

private let offersLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "ioscrmapp",
    category: "Offers"
)

protocol OffersServicing: Sendable {
    func fetchLanding(session: CustSubInfo) async throws -> OffersLandingSnapshot
    func fetchSubscribedOffers(session: CustSubInfo) async throws -> [SubscribedOfferItem]
    func fetchCategories(session: CustSubInfo) async throws -> [OfferCategoryItem]
    func fetchDIYBootstrap(session: CustSubInfo) async throws -> DIYOfferBootstrap
    func calculateDIYPrice(
        _ request: DIYOfferPricingRequest,
        session: CustSubInfo
    ) async throws -> DIYOfferPricing
    func submitDIYOffer(
        _ request: DIYOfferSubmissionRequest,
        session: CustSubInfo
    ) async throws -> OfferAcceptedResult
    func fetchOrders(
        session: CustSubInfo,
        filter: OffersOrderFilter,
        pageIndex: Int,
        pageSize: Int
    ) async throws -> OffersOrderPageSnapshot
    func fetchEligibleOffers(
        session: CustSubInfo,
        resourceType: OffersResourceType,
        categoryId: String?
    ) async throws -> [EligibleOfferItem]
    func submitChange(_ request: OfferChangeRequest, session: CustSubInfo) async throws -> OfferAcceptedResult
}

enum OffersServiceError: Error {
    case missingIdentity
    case tooManyRequests
    case networkUnavailable
    case requestCancelled
    case featureUnavailable(message: String)

    var textValue: LocalizedTextValue {
        switch self {
        case .missingIdentity, .networkUnavailable:
            return .key("offers.state.errorSubtitle")
        case .tooManyRequests:
            return .key("common.error.tooManyRequests")
        case .requestCancelled:
            return .literal("")
        case let .featureUnavailable(message):
            return .literal(message)
        }
    }

    var textValueLiteralFallback: String {
        switch self.textValue {
        case let .literal(text):
            return text
        case let .localized(key, _):
            return key
        }
    }
}

actor MockOffersService: OffersServicing {
    func fetchLanding(session: CustSubInfo) async throws -> OffersLandingSnapshot {
        OffersLandingSnapshot(
            primaryOffer: PrimaryOfferSummary(
                offerId: "primary-1",
                offerCode: "PRIMARY-1",
                offerName: "Power Plan 200",
                effectiveDate: "2026-03-01",
                expiryDate: "2026-04-01"
            ),
            subscribedOffers: mockSubscribedOffers()
        )
    }

    func fetchSubscribedOffers(session: CustSubInfo) async throws -> [SubscribedOfferItem] {
        mockSubscribedOffers()
    }

    func fetchCategories(session: CustSubInfo) async throws -> [OfferCategoryItem] {
        [
            OfferCategoryItem(id: "all-data", name: "All data offers", parentId: nil, sortOrder: 0),
            OfferCategoryItem(id: "social", name: "Social packs", parentId: nil, sortOrder: 1),
            OfferCategoryItem(id: "streaming", name: "Streaming", parentId: nil, sortOrder: 2),
        ]
    }

    func fetchDIYBootstrap(session: CustSubInfo) async throws -> DIYOfferBootstrap {
        DIYOfferBootstrap(
            periods: [
                DIYOfferPeriod(
                    id: "daily",
                    title: "Daily",
                    sortOrder: 0,
                    resources: [
                        DIYOfferResource(
                            id: "daily-data",
                            crmOfferingId: "OFFER:b380fc3d-63a9-4340-9de0-36bc2365c875",
                            offeringId: "OFFER:b380fc3d-63a9-4340-9de0-36bc2365c875",
                            attrName: "Data",
                            attrCode: "MB",
                            unit: "MB",
                            minValue: 20,
                            maxValue: 200,
                            defaultValue: 85,
                            feeCode: "DATA_DAY",
                            rateAmount: "10.00",
                            kind: .data
                        ),
                        DIYOfferResource(
                            id: "daily-sms",
                            crmOfferingId: "OFFER:da116e34-cc02-4bde-b88e-d2f7f378b0be",
                            offeringId: "OFFER:da116e34-cc02-4bde-b88e-d2f7f378b0be",
                            attrName: "SMS",
                            attrCode: "items(SMS)",
                            unit: "SMS",
                            minValue: 0,
                            maxValue: 200,
                            defaultValue: 46,
                            feeCode: "SMS_DAY",
                            rateAmount: "5.00",
                            kind: .sms
                        ),
                        DIYOfferResource(
                            id: "daily-unit",
                            crmOfferingId: "OFFER:c800eb7c-f472-41a3-af93-38e411ef40fc",
                            offeringId: "OFFER:c800eb7c-f472-41a3-af93-38e411ef40fc",
                            attrName: "Units",
                            attrCode: "items(Unit)",
                            unit: "Unit",
                            minValue: 0,
                            maxValue: 200,
                            defaultValue: 52,
                            feeCode: "UNIT_DAY",
                            rateAmount: "1.00",
                            kind: .unit
                        ),
                    ]
                ),
                DIYOfferPeriod(
                    id: "weekly",
                    title: "Weekly",
                    sortOrder: 1,
                    resources: [
                        DIYOfferResource(
                            id: "weekly-data",
                            crmOfferingId: "OFFER:8cf2a35d-d4f8-4273-b607-0fc8cce6baf6",
                            offeringId: "OFFER:8cf2a35d-d4f8-4273-b607-0fc8cce6baf6",
                            attrName: "Data",
                            attrCode: "MB",
                            unit: "MB",
                            minValue: 0,
                            maxValue: 200,
                            defaultValue: 120,
                            feeCode: "DATA_WEEK",
                            rateAmount: "10.00",
                            kind: .data
                        )
                    ]
                ),
                DIYOfferPeriod(
                    id: "monthly",
                    title: "Monthly",
                    sortOrder: 2,
                    resources: []
                )
            ],
            currencyCode: "AED",
            currencyName: "AED",
            cbsAccuracy: 100
        )
    }

    func calculateDIYPrice(
        _ request: DIYOfferPricingRequest,
        session: CustSubInfo
    ) async throws -> DIYOfferPricing {
        let items = request.resources.map { selected -> DIYOfferPricingItem in
            let rate = OffersPriceParser.decimal(selected.resource.rateAmount) ?? .zero
            let subtotal = rate * Decimal(selected.value)
            return DIYOfferPricingItem(
                id: selected.resource.id,
                offeringId: selected.resource.crmOfferingId,
                title: selected.resource.attrName,
                quantity: selected.value,
                unit: selected.resource.unit,
                unitPriceAmount: OffersPriceParser.string(rate),
                subtotalAmount: OffersPriceParser.string(subtotal)
            )
        }

        let total = items.reduce(Decimal.zero) { partialResult, item in
            partialResult + (OffersPriceParser.decimal(item.subtotalAmount) ?? .zero)
        }

        return DIYOfferPricing(
            totalAmount: OffersPriceParser.string(total),
            currencyName: request.currencyName,
            items: items
        )
    }

    func submitDIYOffer(
        _ request: DIYOfferSubmissionRequest,
        session: CustSubInfo
    ) async throws -> OfferAcceptedResult {
        OfferAcceptedResult(
            orderId: "OC\(Int.random(in: 202603250000 ... 202603259999))",
            offerName: "DIY Offer \(request.period.title)",
            operationType: .subscribe
        )
    }

    func fetchOrders(
        session: CustSubInfo,
        filter: OffersOrderFilter,
        pageIndex: Int,
        pageSize: Int
    ) async throws -> OffersOrderPageSnapshot {
        let calendar = Calendar(identifier: .gregorian)
        let anchorDate = calendar.date(from: DateComponents(year: 2026, month: 3, day: 26, hour: 13, minute: 49, second: 21)) ?? Date()
        let records = [
            OffersOrderRecord(
                id: "offer-order-1",
                orderId: "1234541774386089984",
                offerName: "Internet Weekly (2GB)",
                createdTimeText: "2026-03-26 13:49:21",
                subscribeType: .add,
                status: .success,
                statusCode: "1",
                offerType: "Data",
                effectiveMode: "I"
            ),
            OffersOrderRecord(
                id: "offer-order-2",
                orderId: "1234503399646023680",
                offerName: "4G APN Package(500 GB)",
                createdTimeText: "2026-03-26 11:16:52",
                subscribeType: .delete,
                status: .initial,
                statusCode: "0",
                offerType: nil,
                effectiveMode: "I"
            ),
            OffersOrderRecord(
                id: "offer-order-3",
                orderId: "1234481810022217728",
                offerName: "Roaming Daily Pass",
                createdTimeText: "2026-03-25 09:02:11",
                subscribeType: .add,
                status: .abnormal,
                statusCode: "2",
                offerType: "Data",
                effectiveMode: "I"
            ),
        ]

        let filtered = records.filter { record in
            let subscribeTypeMatches = filter.subscribeType == nil || filter.subscribeType == record.subscribeType
            let statusMatches = filter.status == nil || filter.status == record.status
            let recordDate = OffersOrderQueryDate.formatter.date(from: record.createdTimeText) ?? anchorDate
            let startMatches = filter.startDate == nil || recordDate >= OffersOrderQueryDate.startOfDay(for: filter.startDate!)
            let endMatches = filter.endDate == nil || recordDate <= OffersOrderQueryDate.endOfDay(for: filter.endDate!)
            return subscribeTypeMatches && statusMatches && startMatches && endMatches
        }

        let startIndex = max(0, (pageIndex - 1) * pageSize)
        let endIndex = min(filtered.count, startIndex + pageSize)
        let pageRecords = startIndex < endIndex ? Array(filtered[startIndex..<endIndex]) : []
        let totalPages = max(1, Int(ceil(Double(max(filtered.count, 1)) / Double(max(pageSize, 1)))))

        return OffersOrderPageSnapshot(
            records: pageRecords,
            pageIndex: pageIndex,
            pageSize: pageSize,
            totalCount: filtered.count,
            totalPages: totalPages
        )
    }

    func fetchEligibleOffers(
        session: CustSubInfo,
        resourceType: OffersResourceType,
        categoryId: String?
    ) async throws -> [EligibleOfferItem] {
        let offers = [
            EligibleOfferItem(
                id: "offer-1",
                offerId: "offer-1",
                offerCode: "CBS-101",
                offerName: "15 GB Data Booster",
                offerType: resourceType.rawValue,
                validityRaw: "Monthly",
                validityBucket: .monthly,
                resourceSummary: "15 GB",
                displayPriceText: "45.00 AED",
                displayPriceValue: Decimal(string: "45.00"),
                popularRank: 1,
                originalIndex: 0
            ),
            EligibleOfferItem(
                id: "offer-2",
                offerId: "offer-2",
                offerCode: "CBS-102",
                offerName: "Weekend Flex Pack",
                offerType: resourceType.rawValue,
                validityRaw: "Weekly",
                validityBucket: .weekly,
                resourceSummary: nil,
                displayPriceText: "25.00 AED",
                displayPriceValue: Decimal(string: "25.00"),
                popularRank: 2,
                originalIndex: 1
            ),
            EligibleOfferItem(
                id: "offer-3",
                offerId: "offer-3",
                offerCode: "CBS-103",
                offerName: "Night Combo",
                offerType: resourceType.rawValue,
                validityRaw: "Daily",
                validityBucket: .daily,
                resourceSummary: nil,
                displayPriceText: "Contact us",
                displayPriceValue: nil,
                popularRank: 3,
                originalIndex: 2
            ),
        ]

        guard let categoryId, !categoryId.isEmpty, categoryId != "all-data" else {
            return offers
        }

        return offers.filter { offer in
            switch categoryId {
            case "social":
                return offer.offerName.localizedCaseInsensitiveContains("Flex")
            case "streaming":
                return offer.offerName.localizedCaseInsensitiveContains("Night")
            default:
                return true
            }
        }
    }

    func submitChange(_ request: OfferChangeRequest, session: CustSubInfo) async throws -> OfferAcceptedResult {
        switch request {
        case let .subscribe(offer):
            return OfferAcceptedResult(
                orderId: UUID().uuidString,
                offerName: offer.offerName,
                operationType: .subscribe
            )
        case let .unsubscribe(offer):
            return OfferAcceptedResult(
                orderId: UUID().uuidString,
                offerName: offer.offerName,
                operationType: .unsubscribe
            )
        }
    }

    private func mockSubscribedOffers() -> [SubscribedOfferItem] {
        [
            SubscribedOfferItem(
                id: "sub-1",
                offerId: "sub-1",
                itemInstanceId: "item-1",
                offerName: "Social Chat Add-on",
                offerCategory: "Data",
                effectiveDate: "2026-03-15",
                expiryDate: "2026-04-15",
                canUnsubscribe: true
            ),
            SubscribedOfferItem(
                id: "sub-2",
                offerId: "sub-2",
                itemInstanceId: "item-2",
                offerName: "Weekend Voice Booster",
                offerCategory: "Voice",
                effectiveDate: "2026-03-10",
                expiryDate: "2026-04-10",
                canUnsubscribe: true
            ),
        ]
    }
}

struct RemoteOffersService: OffersServicing {
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

    func fetchLanding(session: CustSubInfo) async throws -> OffersLandingSnapshot {
        let context = try await fetchContext(session: session)
        async let primaryOffer = fetchPrimaryOffer(context: context)
        async let subscribedOffers = fetchSubscribedOffers(context: context)

        return try await OffersLandingSnapshot(
            primaryOffer: primaryOffer,
            subscribedOffers: subscribedOffers
        )
    }

    func fetchSubscribedOffers(session: CustSubInfo) async throws -> [SubscribedOfferItem] {
        let context = try await fetchContext(session: session)
        return try await fetchSubscribedOffers(context: context)
    }

    func fetchCategories(session: CustSubInfo) async throws -> [OfferCategoryItem] {
        let context = try await fetchContext(session: session)

        do {
            let response = try await client.post(
                OffersAPI.categories,
                body: [
                    "userId": context.identity.userId,
                    "serviceNumber": context.identity.serviceNumber,
                    "subscriberKey": context.subscriberKey,
                    "lang": OffersRequestLanguage.currentCode(),
                    "type": "MobileOfferMapping",
                    "paymentType": context.paymentTypeInt,
                    "customerType": context.customerType,
                    "mainOfferCode": context.mainOfferCode,
                ]
            )

            let nodes = response.arrayValue ?? []
            return flattenCategories(nodes)
                .sorted { lhs, rhs in
                    if lhs.sortOrder != rhs.sortOrder {
                        return (lhs.sortOrder ?? 0) < (rhs.sortOrder ?? 0)
                    }
                    return lhs.name < rhs.name
                }
        } catch {
            throw mapError(error)
        }
    }

    func fetchDIYBootstrap(session: CustSubInfo) async throws -> DIYOfferBootstrap {
        let context = try await fetchContext(session: session)
        async let periods = fetchDIYPeriods(context: context)
        async let currencyCode = fetchCurrencyCode()
        async let currencyName = fetchCurrencyName()
        async let cbsAccuracy = fetchCBSAccuracy()
        let resolvedPeriods = try await periods
        let resolvedCurrencyCode = try await currencyCode
        let resolvedCurrencyName = try await currencyName
        let resolvedCBSAccuracy = try await cbsAccuracy

        return DIYOfferBootstrap(
            periods: resolvedPeriods,
            currencyCode: resolvedCurrencyCode,
            currencyName: resolvedCurrencyName,
            cbsAccuracy: resolvedCBSAccuracy
        )
    }

    func calculateDIYPrice(
        _ request: DIYOfferPricingRequest,
        session: CustSubInfo
    ) async throws -> DIYOfferPricing {
        let context = try await fetchContext(session: session)
        let body = diyPricingBody(
            context: context,
            period: request.period,
            resources: request.resources
        )

        do {
            let response = try await client.post(OffersAPI.diyOfferTotalFee, body: body)
            return mapDIYPricing(
                from: response,
                request: request
            )
        } catch {
            throw mapError(error)
        }
    }

    func submitDIYOffer(
        _ request: DIYOfferSubmissionRequest,
        session: CustSubInfo
    ) async throws -> OfferAcceptedResult {
        let context = try await fetchContext(session: session)
        let quotation = try await quoteDIYOffer(request, context: context)
        let transactionId = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let body = diySubmitBody(
            context: context,
            request: request,
            quotation: quotation,
            transactionId: transactionId
        )

        do {
            let response = try await client.post(OffersAPI.changeOffer, body: body)
            guard let object = response.objectValue,
                  let orderId = OffersResponseValue.string(in: object, keys: ["orderId"]),
                  !orderId.isEmpty else {
                throw OffersServiceError.featureUnavailable(message: "Missing orderId from DIY offer change response.")
            }

            return OfferAcceptedResult(
                orderId: orderId,
                offerName: "DIY Offer \(request.period.title)",
                operationType: .subscribe
            )
        } catch {
            let mapped = mapError(error)
            throw DIYOfferSubmissionError.submissionFailed(
                DIYOfferFailureResult(
                    message: mapped.textValueLiteralFallback,
                    traceId: OffersServiceTraceID.extract(from: error)
                )
            )
        }
    }

    func fetchOrders(
        session: CustSubInfo,
        filter: OffersOrderFilter,
        pageIndex: Int,
        pageSize: Int
    ) async throws -> OffersOrderPageSnapshot {
        let context = try await fetchContext(session: session)

        var body: [String: Any] = [
            "userId": context.identity.userId,
            "serviceNumber": context.identity.serviceNumber,
            "pageIndex": pageIndex,
            "pageSize": pageSize,
        ]

        if let startDate = filter.startDate {
            body["startTime"] = OffersOrderQueryDate.formatter.string(from: OffersOrderQueryDate.startOfDay(for: startDate))
        }
        if let endDate = filter.endDate {
            body["endTime"] = OffersOrderQueryDate.formatter.string(from: OffersOrderQueryDate.endOfDay(for: endDate))
        }
        if let subscribeType = filter.subscribeType {
            body["subscribeType"] = subscribeType.rawValue
        }
        if let status = filter.status {
            body["status"] = status.rawValue
        }

        do {
            let response = try await client.post(OffersAPI.orderPage, body: body)
            return try mapOrderPage(from: response)
        } catch {
            throw mapError(error)
        }
    }

    func fetchEligibleOffers(
        session: CustSubInfo,
        resourceType: OffersResourceType,
        categoryId: String?
    ) async throws -> [EligibleOfferItem] {
        let context = try await fetchContext(session: session)

        var requestBody: [String: Any] = [
            "userId": context.identity.userId,
            "serviceNumber": context.identity.serviceNumber,
            "subscriberKey": context.subscriberKey,
            "custType": context.customerType,
            "paymentType": context.paymentTypeCode,
            "language": OffersRequestLanguage.currentCode(),
            "destinationId": "0",
        ]

        if resourceType != .all {
            requestBody["offerType"] = resourceType.rawValue
        }

        if let categoryId, !categoryId.isEmpty {
            requestBody["categoryId"] = categoryId
        }

        do {
            let response = try await client.post(OffersAPI.eligibleOffers, body: requestBody)
            let objects = response.arrayValue ?? []
            return objects.enumerated().map { index, item in
                let object = item.objectValue ?? [:]
                let rawPrice = OffersResponseValue.string(in: object, keys: ["rentalPrice"])
                return EligibleOfferItem(
                    id: OffersResponseValue.string(in: object, keys: ["offerId", "cbsCode"]) ?? UUID().uuidString,
                    offerId: OffersResponseValue.string(in: object, keys: ["offerId"]) ?? "",
                    offerCode: OffersResponseValue.string(in: object, keys: ["offerCode", "cbsCode"]) ?? "",
                    offerName: OffersResponseValue.string(in: object, keys: ["offerName"]) ?? "",
                    offerType: OffersResponseValue.string(in: object, keys: ["offerType"]) ?? (resourceType == .all ? "" : resourceType.rawValue),
                    validityRaw: OffersResponseValue.string(in: object, keys: ["validity"]),
                    validityBucket: OffersValidityMapper.bucket(for: OffersResponseValue.string(in: object, keys: ["validity"])),
                    resourceSummary: OffersResponseValue.string(in: object, keys: ["quota"]),
                    displayPriceText: rawPrice,
                    displayPriceValue: OffersPriceParser.decimal(rawPrice),
                    popularRank: OffersResponseValue.int(in: object, keys: ["sort"]),
                    originalIndex: index
                )
            }
        } catch {
            throw mapError(error)
        }
    }

    func submitChange(_ request: OfferChangeRequest, session: CustSubInfo) async throws -> OfferAcceptedResult {
        let context = try await fetchContext(session: session)
        let transactionId = UUID().uuidString.replacingOccurrences(of: "-", with: "")

        var body: [String: Any] = [
            "userId": context.identity.userId,
            "serviceNumber": context.identity.serviceNumber,
            "subscriberKey": context.subscriberKey,
            "businessCode": "ChangeSupplementOffering",
            "transactionId": transactionId,
            "deviceBrand": OffersDeviceContext.currentDeviceBrand,
            "deviceModel": OffersDeviceContext.currentDeviceModel,
        ]

        let action: String
        let offerName: String
        let offerType: String
        let productOffering: [String: Any]
        let operationType: OffersOperationType

        switch request {
        case let .subscribe(offer):
            action = "add"
            offerName = offer.offerName
            offerType = offer.offerType
            operationType = .subscribe
            productOffering = [
                "id": offer.offerId,
                "itemTerm": [
                    ["effectMode": "I"]
                ]
            ]
        case let .unsubscribe(offer):
            action = "delete"
            offerName = offer.offerName
            offerType = offer.offerCategory
            operationType = .unsubscribe
            productOffering = [
                "itemInstanceId": offer.itemInstanceId,
                "itemTerm": [
                    ["expireMode": "I"]
                ]
            ]
        }

        body["offerName"] = offerName
        body["offerType"] = offerType
        body["productOrderItem"] = [
            [
                "action": action,
                "productOffering": productOffering,
            ]
        ]

        do {
            let response = try await client.post(OffersAPI.changeOffer, body: body)
            guard let object = response.objectValue,
                  let orderId = OffersResponseValue.string(in: object, keys: ["orderId"]),
                  !orderId.isEmpty
            else {
                throw OffersServiceError.featureUnavailable(message: "Missing orderId from offer change response.")
            }

            return OfferAcceptedResult(
                orderId: orderId,
                offerName: offerName,
                operationType: operationType
            )
        } catch {
            throw mapError(error)
        }
    }

    private func fetchContext(session: CustSubInfo) async throws -> OffersRequestContext {
        let identity = try session.offersIdentity()

        do {
            let response = try await client.post(
                HomeAPI.userInfo,
                body: ["serviceNumber": identity.serviceNumber]
            )

            guard let object = response.objectValue else {
                throw OffersServiceError.networkUnavailable
            }

            let subscriberKey = OffersResponseValue.string(in: object, keys: ["subscriberKey"]) ?? ""
            guard !subscriberKey.isEmpty else {
                throw OffersServiceError.missingIdentity
            }

            let paymentTypeCode = OffersResponseValue.string(in: object, keys: ["paymentType"]) ?? "0"
            let isCorMember = OffersResponseValue.string(in: object, keys: ["isCorMember"]) ?? "false"

            return OffersRequestContext(
                identity: identity,
                subscriberKey: subscriberKey,
                paymentTypeCode: paymentTypeCode,
                paymentTypeName: OffersPaymentTypeMapper.name(for: paymentTypeCode),
                paymentTypeInt: OffersPaymentTypeMapper.code(for: paymentTypeCode),
                customerType: OffersCustomerTypeMapper.customerType(from: isCorMember),
                mainOfferCode: OffersResponseValue.string(in: object, keys: ["mainOfferCode"]) ?? ""
            )
        } catch {
            throw mapError(error)
        }
    }

    private func fetchPrimaryOffer(context: OffersRequestContext) async throws -> PrimaryOfferSummary {
        do {
            let response = try await client.post(
                OffersAPI.primaryOffer,
                body: [
                    "userId": context.identity.userId,
                    "serviceNumber": context.identity.serviceNumber,
                    "subscriberKey": context.subscriberKey,
                    "lang": OffersRequestLanguage.currentCode(),
                    "freeUnitType": "Data",
                ]
            )

            guard let object = response.objectValue else {
                throw OffersServiceError.networkUnavailable
            }

            return PrimaryOfferSummary(
                offerId: OffersResponseValue.string(in: object, keys: ["offerId"]) ?? "",
                offerCode: OffersResponseValue.string(in: object, keys: ["offerCode"]) ?? "",
                offerName: OffersResponseValue.string(in: object, keys: ["offerName"]) ?? "",
                effectiveDate: OffersResponseValue.dateText(in: object, keys: ["effectiveDate"]),
                expiryDate: OffersResponseValue.dateText(in: object, keys: ["expiryDate"])
            )
        } catch {
            throw mapError(error)
        }
    }

    private func fetchSubscribedOffers(context: OffersRequestContext) async throws -> [SubscribedOfferItem] {
        do {
            let response = try await client.post(
                OffersAPI.subscribedOffers,
                body: [
                    "userId": context.identity.userId,
                    "serviceNumber": context.identity.serviceNumber,
                    "subscriberKey": context.subscriberKey,
                    "lang": OffersRequestLanguage.currentCode(),
                ]
            )

            let items = response.arrayValue ?? []
            return items.map { item in
                let object = item.objectValue ?? [:]
                let rawUnsubscribe = OffersResponseValue.string(in: object, keys: ["unsubscribeEnabled"])

                return SubscribedOfferItem(
                    id: OffersResponseValue.string(in: object, keys: ["itemInstanceId", "offerId"]) ?? UUID().uuidString,
                    offerId: OffersResponseValue.string(in: object, keys: ["offerId"]) ?? "",
                    itemInstanceId: OffersResponseValue.string(in: object, keys: ["itemInstanceId"]) ?? "",
                    offerName: OffersResponseValue.string(in: object, keys: ["offerName"]) ?? "",
                    offerCategory: OffersResponseValue.string(in: object, keys: ["offerCategory"]) ?? "",
                    effectiveDate: OffersResponseValue.dateText(in: object, keys: ["effectiveDate"]),
                    expiryDate: OffersResponseValue.dateText(in: object, keys: ["expiryDate"]),
                    canUnsubscribe: OffersUnsubscribeMapper.canUnsubscribe(from: rawUnsubscribe)
                )
            }
        } catch {
            throw mapError(error)
        }
    }

    private func fetchDIYPeriods(context: OffersRequestContext) async throws -> [DIYOfferPeriod] {
        do {
            let response = try await client.post(
                OffersAPI.diyOfferConfig,
                body: [
                    "userId": context.identity.userId,
                    "serviceNumber": context.identity.serviceNumber,
                    "subscriberKey": context.subscriberKey,
                    "lang": OffersRequestLanguage.currentCode(),
                    "paymentType": context.paymentTypeInt,
                    "customerType": context.customerType,
                    "mainOfferCode": context.mainOfferCode,
                ]
            )

            let rawPeriods: [HTTPClient.ResponseData]
            if let array = response.arrayValue {
                rawPeriods = array
            } else if let object = response.objectValue {
                rawPeriods =
                    object["periods"]?.arrayValue ??
                    object["records"]?.arrayValue ??
                    object["list"]?.arrayValue ??
                    object["data"]?.arrayValue ??
                    []
            } else {
                rawPeriods = []
            }

            return rawPeriods.enumerated().map { index, period in
                let object = period.objectValue ?? [:]
                let title = OffersResponseValue.string(in: object, keys: ["periodName", "period", "validity", "title"]) ?? "Period \(index + 1)"
                let resourceNodes =
                    object["resources"]?.arrayValue ??
                    object["productOffering"]?.arrayValue ??
                    object["productOfferingList"]?.arrayValue ??
                    object["offerList"]?.arrayValue ??
                    []

                let resources = resourceNodes.enumerated().map { resourceIndex, node in
                    let resourceObject = node.objectValue ?? [:]
                    let offeringId = OffersResponseValue.string(in: resourceObject, keys: ["crmOfferingId", "offeringId", "id"]) ?? UUID().uuidString
                    let attrCode = OffersResponseValue.string(in: resourceObject, keys: ["attrCode", "featureCode", "code"]) ?? ""
                    let attrName = OffersResponseValue.string(in: resourceObject, keys: ["attrName", "offerName", "name"]) ?? "Resource \(resourceIndex + 1)"
                    return DIYOfferResource(
                        id: "\(title)-\(resourceIndex)-\(offeringId)",
                        crmOfferingId: OffersResponseValue.string(in: resourceObject, keys: ["crmOfferingId", "offeringId", "id"]) ?? offeringId,
                        offeringId: OffersResponseValue.string(in: resourceObject, keys: ["offeringId", "crmOfferingId", "id"]) ?? offeringId,
                        attrName: attrName,
                        attrCode: attrCode,
                        unit: OffersResponseValue.string(in: resourceObject, keys: ["attrUnit", "unit"]) ?? defaultUnit(for: attrCode),
                        minValue: OffersResponseValue.int(in: resourceObject, keys: ["attrMinValue", "minValue"]) ?? 0,
                        maxValue: OffersResponseValue.int(in: resourceObject, keys: ["attrMaxValue", "maxValue"]) ?? 0,
                        defaultValue: OffersResponseValue.int(in: resourceObject, keys: ["defaultValue", "attrDefaultValue", "attrMinValue"]) ?? 0,
                        feeCode: OffersResponseValue.string(in: resourceObject, keys: ["feeCode"]),
                        rateAmount: OffersResponseValue.string(in: resourceObject, keys: ["price", "attrPrice", "unitPrice"]),
                        kind: DIYOfferResourceKind(attrCode: attrCode)
                    )
                }

                return DIYOfferPeriod(
                    id: title.lowercased(),
                    title: title,
                    sortOrder: index,
                    resources: resources
                )
            }
            .sorted { lhs, rhs in lhs.sortOrder < rhs.sortOrder }
        } catch {
            throw mapError(error)
        }
    }

    private func fetchCBSAccuracy() async throws -> Int {
        do {
            let response = try await client.post(
                OffersAPI.queryConfig,
                body: ["paramCode": "CBS_ACCURACY"]
            )

            guard let object = response.objectValue else {
                return 100
            }

            return OffersResponseValue.int(in: object, keys: ["paramValue", "value"]) ?? 100
        } catch {
            throw mapError(error)
        }
    }

    private func fetchCurrencyCode() async throws -> String {
        do {
            let response = try await client.post(
                OffersAPI.queryConfig,
                body: ["paramCode": "CURRENCY"]
            )

            guard let object = response.objectValue else {
                return "AED"
            }

            return OffersResponseValue.string(in: object, keys: ["paramValue", "value"]) ?? "AED"
        } catch {
            throw mapError(error)
        }
    }

    private func fetchCurrencyName() async throws -> String {
        let fallbackCode = (try? await fetchCurrencyCode()) ?? "AED"

        do {
            let response = try await client.post(
                OffersAPI.queryDictItems,
                body: [
                    "dictCode": "CURRENCY",
                    "lang": OffersRequestLanguage.currentCode(),
                ]
            )

            let items = response.arrayValue ?? []
            for item in items {
                guard let object = item.objectValue else {
                    continue
                }
                let code = OffersResponseValue.string(in: object, keys: ["itemCode", "dictItemCode", "code"]) ?? ""
                if code == fallbackCode {
                    return OffersResponseValue.string(in: object, keys: ["itemName", "dictItemName", "name"]) ?? fallbackCode
                }
            }

            return fallbackCode
        } catch {
            return fallbackCode
        }
    }

    private func diyPricingBody(
        context: OffersRequestContext,
        period: DIYOfferPeriod,
        resources: [DIYOfferSelectedResource]
    ) -> [String: Any] {
        [
            "userId": context.identity.userId,
            "serviceNumber": context.identity.serviceNumber,
            "subscriberKey": context.subscriberKey,
            "lang": OffersRequestLanguage.currentCode(),
            "period": period.title,
            "productOffering": diyProductOfferingPayload(from: resources)
        ]
    }

    private func mapDIYPricing(
        from response: HTTPClient.ResponseData,
        request: DIYOfferPricingRequest
    ) -> DIYOfferPricing {
        let object = response.objectValue ?? [:]
        let itemNodes =
            object["calcOneOffFeeList"]?.arrayValue ??
            object["feeDetailList"]?.arrayValue ??
            object["items"]?.arrayValue ??
            []

        let totalAmount =
            normalizedAmount(OffersResponseValue.string(in: object, keys: ["calculateFee", "totalFee", "chargeAmt"]))
            ?? localDIYTotal(from: request.resources)

        let items = request.resources.map { selected in
            let matched = itemNodes.first { item in
                let itemObject = item.objectValue ?? [:]
                let candidate = OffersResponseValue.string(in: itemObject, keys: ["offeringId", "crmOfferingId", "feeItemCode"])
                return candidate == selected.resource.crmOfferingId || candidate == selected.resource.offeringId || candidate == selected.resource.feeCode
            }?.objectValue

            let localRate = selected.resource.rateAmount ?? "0"
            let localSubtotal = localDIYSubtotal(resource: selected.resource, value: selected.value)

            return DIYOfferPricingItem(
                id: selected.resource.id,
                offeringId: selected.resource.crmOfferingId,
                title: OffersResponseValue.string(in: matched ?? [:], keys: ["feeItemName", "itemName", "offerName"]) ?? selected.resource.attrName,
                quantity: selected.value,
                unit: selected.resource.unit,
                unitPriceAmount: normalizedAmount(OffersResponseValue.string(in: matched ?? [:], keys: ["unitPrice", "price"])) ?? localRate,
                subtotalAmount: normalizedAmount(OffersResponseValue.string(in: matched ?? [:], keys: ["calculateFee", "subtotal", "chargeAmt"])) ?? localSubtotal
            )
        }

        return DIYOfferPricing(
            totalAmount: totalAmount,
            currencyName: request.currencyName,
            items: items
        )
    }

    private func quoteDIYOffer(
        _ request: DIYOfferSubmissionRequest,
        context: OffersRequestContext
    ) async throws -> DIYOfferFeeQuotation {
        let accuracy = try await fetchCBSAccuracy()
        let total = OffersPriceParser.decimal(request.pricing.totalAmount) ?? .zero
        let scaled = total * Decimal(accuracy)
        let body: [String: Any] = [
            "userId": context.identity.userId,
            "serviceNumber": context.identity.serviceNumber,
            "subscriberKey": context.subscriberKey,
            "lang": OffersRequestLanguage.currentCode(),
            "chargeAmt": OffersPriceParser.string(scaled),
            "currencyCode": request.pricing.currencyName,
            "productOffering": diyProductOfferingPayload(from: request.resources)
        ]

        do {
            let response = try await client.post(OffersAPI.feeQuotation, body: body)
            let object = response.objectValue ?? [:]
            return DIYOfferFeeQuotation(
                chargeAmount: OffersResponseValue.string(in: object, keys: ["chargeAmt", "amount"]) ?? OffersPriceParser.string(scaled),
                currencyCode: OffersResponseValue.string(in: object, keys: ["currencyCode", "currency"]) ?? request.pricing.currencyName,
                traceId: OffersResponseValue.string(in: object, keys: ["traceId"])
            )
        } catch {
            let mapped = mapError(error)
            throw DIYOfferSubmissionError.quotationRejected(.literal(mapped.textValueLiteralFallback))
        }
    }

    private func diySubmitBody(
        context: OffersRequestContext,
        request: DIYOfferSubmissionRequest,
        quotation: DIYOfferFeeQuotation,
        transactionId: String
    ) -> [String: Any] {
        [
            "userId": context.identity.userId,
            "serviceNumber": context.identity.serviceNumber,
            "subscriberKey": context.subscriberKey,
            "businessCode": "ChangeSupplementOffering",
            "transactionId": transactionId,
            "deviceBrand": OffersDeviceContext.currentDeviceBrand,
            "deviceModel": OffersDeviceContext.currentDeviceModel,
            "offerName": "DIY Offer \(request.period.title)",
            "offerType": "DIY",
            "feeQuotation": [
                "chargeAmt": quotation.chargeAmount,
                "currencyCode": quotation.currencyCode
            ],
            "productOrderItem": [
                [
                    "action": "add",
                    "productOffering": [
                        "id": "DIY-\(request.period.id)",
                        "name": "DIY Offer \(request.period.title)",
                        "itemTerm": [
                            ["effectMode": "I"]
                        ],
                        "productCharacteristic": diyCharacteristicsPayload(from: request.resources)
                    ]
                ]
            ]
        ]
    }

    private func diyProductOfferingPayload(from resources: [DIYOfferSelectedResource]) -> [[String: Any]] {
        resources.map { selected in
            [
                "id": selected.resource.offeringId,
                "crmOfferingId": selected.resource.crmOfferingId,
                "feeCode": selected.resource.feeCode ?? "",
                "productCharacteristic": [
                    [
                        "name": selected.resource.attrName,
                        "code": selected.resource.attrCode,
                        "value": selected.value,
                        "unitOfMeasure": selected.resource.unit
                    ]
                ]
            ]
        }
    }

    private func diyCharacteristicsPayload(from resources: [DIYOfferSelectedResource]) -> [[String: Any]] {
        resources.map { selected in
            [
                "name": selected.resource.attrName,
                "code": selected.resource.attrCode,
                "value": "\(selected.value)",
                "unitOfMeasure": selected.resource.unit
            ]
        }
    }

    private func flattenCategories(_ nodes: [HTTPClient.ResponseData], parentId: String? = nil) -> [OfferCategoryItem] {
        var flattened: [OfferCategoryItem] = []

        for node in nodes {
            guard let object = node.objectValue else {
                continue
            }

            let categoryId = OffersResponseValue.string(in: object, keys: ["id", "categoryId"]) ?? UUID().uuidString
            let item = OfferCategoryItem(
                id: categoryId,
                name: OffersResponseValue.string(in: object, keys: ["categoryName", "name"]) ?? categoryId,
                parentId: parentId,
                sortOrder: OffersResponseValue.int(in: object, keys: ["sortOrder"])
            )
            flattened.append(item)

            let children = object["children"]?.arrayValue ?? []
            if !children.isEmpty {
                flattened.append(contentsOf: flattenCategories(children, parentId: categoryId))
            }
        }

        return flattened
    }

    private func mapOrderPage(from responseData: HTTPClient.ResponseData) throws -> OffersOrderPageSnapshot {
        guard let object = responseData.objectValue else {
            throw OffersServiceError.networkUnavailable
        }

        let records = object["records"]?.arrayValue ?? []
        let mappedRecords = records.compactMap(mapOrderRecord)
        return OffersOrderPageSnapshot(
            records: mappedRecords,
            pageIndex: OffersResponseValue.int(in: object, keys: ["current"]) ?? 1,
            pageSize: OffersResponseValue.int(in: object, keys: ["size"]) ?? 10,
            totalCount: OffersResponseValue.int(in: object, keys: ["total"]) ?? mappedRecords.count,
            totalPages: OffersResponseValue.int(in: object, keys: ["pages"]) ?? 1
        )
    }

    private func mapOrderRecord(_ responseData: HTTPClient.ResponseData) -> OffersOrderRecord? {
        guard let object = responseData.objectValue,
              let subscribeTypeRaw = OffersResponseValue.string(in: object, keys: ["subscribeType"]),
              let subscribeType = OffersOrderSubscribeType(rawValue: subscribeTypeRaw),
              let statusRaw = OffersResponseValue.string(in: object, keys: ["status"]),
              let status = OffersOrderStatus(rawValue: statusRaw) else {
            return nil
        }

        return OffersOrderRecord(
            id: OffersResponseValue.string(in: object, keys: ["id", "extOrderNo"]) ?? UUID().uuidString,
            orderId: OffersResponseValue.string(in: object, keys: ["extOrderNo", "id"]) ?? "",
            offerName: OffersResponseValue.string(in: object, keys: ["offerName"]) ?? "",
            createdTimeText: OffersResponseValue.dateText(in: object, keys: ["createdTime"]),
            subscribeType: subscribeType,
            status: status,
            statusCode: statusRaw,
            offerType: OffersResponseValue.string(in: object, keys: ["offerType"]),
            effectiveMode: OffersResponseValue.string(in: object, keys: ["effectiveMode"])
        )
    }

    private func defaultUnit(for attrCode: String) -> String {
        switch DIYOfferResourceKind(attrCode: attrCode) {
        case .data:
            return "MB"
        case .sms:
            return "SMS"
        case .unit:
            return "Unit"
        case let .custom(rawValue):
            return rawValue
        }
    }

    private func normalizedAmount(_ rawValue: String?) -> String? {
        guard let decimal = OffersPriceParser.decimal(rawValue) else {
            return nil
        }
        return OffersPriceParser.string(decimal)
    }

    private func localDIYTotal(from resources: [DIYOfferSelectedResource]) -> String {
        let total = resources.reduce(Decimal.zero) { partialResult, selected in
            partialResult + (OffersPriceParser.decimal(localDIYSubtotal(resource: selected.resource, value: selected.value)) ?? .zero)
        }
        return OffersPriceParser.string(total)
    }

    private func localDIYSubtotal(resource: DIYOfferResource, value: Int) -> String {
        let rate = OffersPriceParser.decimal(resource.rateAmount) ?? .zero
        return OffersPriceParser.string(rate * Decimal(value))
    }

    private func mapError(_ error: Error) -> OffersServiceError {
        if let offersError = error as? OffersServiceError {
            return offersError
        }

        guard let clientError = error as? HTTPClient.ClientError else {
            return .networkUnavailable
        }

        switch clientError {
        case .tooManyRequests:
            return .tooManyRequests
        case .networkUnavailable:
            return .networkUnavailable
        case let .business(_, message, _):
            return .featureUnavailable(message: message.isEmpty ? "Offer service unavailable." : message)
        case .httpStatus:
            return .networkUnavailable
        case .invalidJSON, .invalidResponse:
            return .networkUnavailable
        }
    }
}

private struct OffersIdentity: Sendable {
    let userId: String
    let serviceNumber: String
}

private struct OffersRequestContext: Sendable {
    let identity: OffersIdentity
    let subscriberKey: String
    let paymentTypeCode: String
    let paymentTypeName: String
    let paymentTypeInt: Int
    let customerType: String
    let mainOfferCode: String
}

private enum OffersRequestLanguage {
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

private enum OffersPaymentTypeMapper {
    static func name(for code: String) -> String {
        switch normalized(code) {
        case "1", "postpaid":
            return "Postpaid"
        case "2", "hybrid":
            return "Hybrid"
        default:
            return "Prepaid"
        }
    }

    static func code(for rawValue: String) -> Int {
        switch normalized(rawValue) {
        case "1", "postpaid":
            return 1
        case "2", "hybrid":
            return 2
        default:
            return 0
        }
    }

    private static func normalized(_ rawValue: String) -> String {
        rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

private enum OffersCustomerTypeMapper {
    static func customerType(from isCorMember: String) -> String {
        switch isCorMember.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "true", "1", "y", "yes":
            return "1"
        default:
            return "0"
        }
    }
}

private enum OffersValidityMapper {
    static func bucket(for rawValue: String?) -> OffersValidityBucket? {
        let normalized = rawValue?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""

        if normalized.contains("daily") {
            return .daily
        }
        if normalized.contains("weekly") {
            return .weekly
        }
        if normalized.contains("monthly") {
            return .monthly
        }

        return nil
    }
}

private enum OffersUnsubscribeMapper {
    static func canUnsubscribe(from rawValue: String?) -> Bool {
        guard let rawValue else {
            return true
        }

        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "false", "0", "n", "no":
            return false
        default:
            return true
        }
    }
}

private enum OffersPriceParser {
    static func decimal(_ rawValue: String?) -> Decimal? {
        guard let rawValue else {
            return nil
        }

        let allowedScalars = CharacterSet(charactersIn: "0123456789.,")
        let normalized = rawValue.unicodeScalars
            .filter { allowedScalars.contains($0) }
            .map(String.init)
            .joined()
            .replacingOccurrences(of: ",", with: "")

        guard !normalized.isEmpty else {
            return nil
        }

        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
    }

    static func string(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }
}

private enum OffersDeviceContext {
    static var currentDeviceBrand: String { "Apple" }

    static var currentDeviceModel: String {
        #if canImport(UIKit)
        return UIDevice.current.model
        #else
        return "iPhone"
        #endif
    }
}

private enum OffersResponseValue {
    static func string(in dictionary: [String: HTTPClient.ResponseData], keys: [String]) -> String? {
        for key in keys {
            if let value = dictionary[key]?.stringValue, !value.isEmpty {
                return value
            }
            if let value = dictionary[key]?.doubleValue {
                return String(value)
            }
            if let nested = dictionary[key]?.objectValue, let nestedValue = string(in: nested, keys: ["value"]) {
                return nestedValue
            }
        }
        return nil
    }

    static func int(in dictionary: [String: HTTPClient.ResponseData], keys: [String]) -> Int? {
        guard let rawValue = string(in: dictionary, keys: keys) else {
            return nil
        }

        if let intValue = Int(rawValue) {
            return intValue
        }
        if let decimal = Decimal(string: rawValue, locale: Locale(identifier: "en_US_POSIX")) {
            return NSDecimalNumber(decimal: decimal).intValue
        }
        return nil
    }

    static func dateText(in dictionary: [String: HTTPClient.ResponseData], keys: [String]) -> String {
        guard let rawValue = string(in: dictionary, keys: keys) else {
            return "-"
        }

        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "-"
        }

        if let formatted = normalizedDateText(from: trimmed) {
            return formatted
        }

        return trimmed
    }

    private static func normalizedDateText(from rawValue: String) -> String? {
        let digitsOnly = rawValue.unicodeScalars.allSatisfy(CharacterSet.decimalDigits.contains)
        if digitsOnly {
            switch rawValue.count {
            case 14:
                return reformatDate(rawValue, from: "yyyyMMddHHmmss", to: "yyyy-MM-dd HH:mm:ss")
            case 12:
                return reformatDate(rawValue, from: "yyyyMMddHHmm", to: "yyyy-MM-dd HH:mm:ss")
            case 10:
                return reformatDate(rawValue, from: "yyyyMMddHH", to: "yyyy-MM-dd HH:mm:ss")
            case 8:
                return reformatDate(rawValue, from: "yyyyMMdd", to: "yyyy-MM-dd")
            default:
                return nil
            }
        }

        for format in [
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd HH",
            "yyyy/MM/dd HH:mm:ss",
            "yyyy/MM/dd HH:mm",
            "yyyy/MM/dd HH",
            "yyyy-MM-dd",
            "yyyy/MM/dd",
        ] {
            if let date = dateFormatter(format).date(from: rawValue) {
                let outputFormat = format.contains("HH") ? "yyyy-MM-dd HH:mm:ss" : "yyyy-MM-dd"
                return dateFormatter(outputFormat).string(from: date)
            }
        }

        return nil
    }

    private static func reformatDate(_ rawValue: String, from inputFormat: String, to outputFormat: String) -> String? {
        guard let date = dateFormatter(inputFormat).date(from: rawValue) else {
            return nil
        }
        return dateFormatter(outputFormat).string(from: date)
    }

    private static func dateFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = format
        return formatter
    }
}

private enum OffersServiceTraceID {
    static func extract(from error: Error) -> String? {
        guard case let HTTPClient.ClientError.business(_, _, traceID) = error else {
            return nil
        }
        return traceID
    }
}

private enum OffersOrderQueryDate {
    static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    static func startOfDay(for date: Date) -> Date {
        Calendar(identifier: .gregorian).startOfDay(for: date)
    }

    static func endOfDay(for date: Date) -> Date {
        let start = startOfDay(for: date)
        return Calendar(identifier: .gregorian).date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? date
    }
}

private extension CustSubInfo {
    func offersIdentity() throws -> OffersIdentity {
        let resolvedUserId = userID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let rawServiceNumber = (serviceNumber ?? phoneNumber)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedServiceNumber = AuthValidator.localPhoneDigits(rawServiceNumber)

        guard !resolvedUserId.isEmpty, !resolvedServiceNumber.isEmpty else {
            offersLogger.error("Missing offers identity userId=\(resolvedUserId, privacy: .private(mask: .hash))")
            throw OffersServiceError.missingIdentity
        }

        return OffersIdentity(
            userId: resolvedUserId,
            serviceNumber: resolvedServiceNumber
        )
    }
}
