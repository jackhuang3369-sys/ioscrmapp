import Foundation
import os
#if canImport(UIKit)
import UIKit
#endif

private let billingLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "ioscrmapp",
    category: "Billing"
)

private func billingDisplayMoney(_ value: String) -> String {
    "\u{2066}\(value)\u{2069}"
}

protocol BillingServicing: Sendable {
    func fetchSummary(session: CustSubInfo) async throws -> BillingSummarySnapshot
    func fetchBillList(session: CustSubInfo, pageIndex: Int?, pageSize: Int?) async throws -> BillingListSnapshot
    func submitPayment(_ request: BillingPaymentRequest, session: CustSubInfo) async throws -> BillingPaymentSubmission
    func downloadInvoicePDF(for invoice: BillingInvoice, session: CustSubInfo) async throws -> URL
}

enum BillingServiceError: Error {
    case missingIdentity
    case missingAccountCode
    case featureUnavailable(message: String)
    case networkUnavailable
    case requestCancelled

    var textValue: LocalizedTextValue {
        switch self {
        case .missingIdentity, .missingAccountCode, .networkUnavailable:
            return .key("billing.state.errorSubtitle")
        case .requestCancelled:
            return .literal("")
        case let .featureUnavailable(message):
            return .literal(message)
        }
    }
}

actor MockBillingService: BillingServicing {
    func fetchSummary(session: CustSubInfo) async throws -> BillingSummarySnapshot {
        let outstanding = mockInvoices().filter(\.isPayable)
        return BillingSummarySnapshot(
            summary: BillingSummary(
                totalDueAmountRaw: "245.00",
                totalDueAmountText: billingDisplayMoney("245.00 AED"),
                dueDateText: "2026-03-28",
                unbilledAmountText: billingDisplayMoney("38.00 AED"),
                remainingCreditText: billingDisplayMoney("188.20 AED"),
                totalUsageText: billingDisplayMoney("311.80 AED"),
                totalCreditText: billingDisplayMoney("500.00 AED"),
                accountCode: "ACC-202603"
            ),
            outstandingInvoices: outstanding
        )
    }

    func fetchBillList(session: CustSubInfo, pageIndex: Int?, pageSize: Int?) async throws -> BillingListSnapshot {
        BillingListSnapshot(
            invoices: mockInvoices(),
            pageIndex: pageIndex,
            pageSize: pageSize
        )
    }

    func submitPayment(_ request: BillingPaymentRequest, session: CustSubInfo) async throws -> BillingPaymentSubmission {
        let target: BillingPaymentSubmission.ReturnTarget
        switch request.context {
        case .summary:
            target = .summary
        case .invoice:
            target = .list
        }

        return BillingPaymentSubmission(
            orderId: UUID().uuidString,
            statusText: "Payment Submitted",
            returnTarget: target
        )
    }

    func downloadInvoicePDF(for invoice: BillingInvoice, session: CustSubInfo) async throws -> URL {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("bill_\(invoice.invoiceNo)_\(BillingRequestLanguage.currentCode()).pdf")
        let mockPDF = Data("%PDF-1.4\n% Mock bill preview\n".utf8)
        try mockPDF.write(to: tempURL, options: .atomic)
        return tempURL
    }

    private func mockInvoices() -> [BillingInvoice] {
        [
            BillingInvoice(
                id: "bill-20260301",
                invoiceId: "INV-20260301",
                invoiceNo: "20260301",
                billCycleID: "20260301",
                currencyId: "AED",
                invoiceAmountRaw: "145.00",
                openAmountRaw: "145.00",
                taxAmountRaw: "0.00",
                invoiceAmountText: billingDisplayMoney("145.00 AED"),
                openAmountText: billingDisplayMoney("145.00 AED"),
                taxAmountText: billingDisplayMoney("0.00 AED"),
                invoiceDateText: "2026-03-01",
                dueDateText: "2026-03-28",
                billCycleBeginText: "2026-03-01",
                statusCode: "O",
                status: .outstanding
            ),
            BillingInvoice(
                id: "bill-20260201",
                invoiceId: "INV-20260201",
                invoiceNo: "20260201",
                billCycleID: "20260201",
                currencyId: "AED",
                invoiceAmountRaw: "100.00",
                openAmountRaw: "100.00",
                taxAmountRaw: "0.00",
                invoiceAmountText: billingDisplayMoney("100.00 AED"),
                openAmountText: billingDisplayMoney("100.00 AED"),
                taxAmountText: billingDisplayMoney("0.00 AED"),
                invoiceDateText: "2026-02-01",
                dueDateText: "2026-02-28",
                billCycleBeginText: "2026-02-01",
                statusCode: "O",
                status: .outstanding
            ),
            BillingInvoice(
                id: "bill-20260101",
                invoiceId: "INV-20260101",
                invoiceNo: "20260101",
                billCycleID: "20260101",
                currencyId: "AED",
                invoiceAmountRaw: "86.00",
                openAmountRaw: "0.00",
                taxAmountRaw: "0.00",
                invoiceAmountText: billingDisplayMoney("86.00 AED"),
                openAmountText: billingDisplayMoney("0.00 AED"),
                taxAmountText: billingDisplayMoney("0.00 AED"),
                invoiceDateText: "2026-01-01",
                dueDateText: "2026-01-28",
                billCycleBeginText: "2026-01-01",
                statusCode: "C",
                status: .completed
            )
        ]
    }
}

struct RemoteBillingService: BillingServicing {
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

    func fetchSummary(session: CustSubInfo) async throws -> BillingSummarySnapshot {
        let identity = try session.billingIdentity()
        let balance = try await fetchBalance(identity: identity)
        let outstandingInvoices = try await fetchInvoices(
            identity: identity,
            accountCode: balance.accountCode,
            outstandingFlag: "Y",
            pageIndex: nil,
            pageSize: nil
        )

        let totalDueRaw = outstandingInvoices
            .map(\.openAmountRaw)
            .compactMap(BillingNumberParser.decimal)
            .reduce(Decimal.zero, +)

        let totalDueText: String
        if totalDueRaw > 0 {
            totalDueText = billingDisplayMoney("\(BillingNumberParser.string(totalDueRaw)) AED")
        } else {
            totalDueText = moneyText(balance.dueAmount)
        }

        return BillingSummarySnapshot(
            summary: BillingSummary(
                totalDueAmountRaw: BillingNumberParser.string(totalDueRaw),
                totalDueAmountText: totalDueText,
                dueDateText: balance.nextBillDueDateText,
                unbilledAmountText: moneyText(balance.unbilledAmount),
                remainingCreditText: moneyText(balance.remainCreditLimitAmount),
                totalUsageText: moneyText(balance.totalUsageAmount),
                totalCreditText: moneyText(balance.totalCreditLimitAmount),
                accountCode: balance.accountCode
            ),
            outstandingInvoices: outstandingInvoices
        )
    }

    func fetchBillList(session: CustSubInfo, pageIndex: Int?, pageSize: Int?) async throws -> BillingListSnapshot {
        let identity = try session.billingIdentity()
        let balance = try await fetchBalance(identity: identity)
        let invoices = try await fetchInvoices(
            identity: identity,
            accountCode: balance.accountCode,
            outstandingFlag: nil,
            pageIndex: pageIndex,
            pageSize: pageSize
        )

        return BillingListSnapshot(
            invoices: invoices,
            pageIndex: pageIndex,
            pageSize: pageSize
        )
    }

    func submitPayment(_ request: BillingPaymentRequest, session: CustSubInfo) async throws -> BillingPaymentSubmission {
        let identity = try session.billingIdentity()
        let userInfo = try await fetchUserInfo(identity: identity)
        let serialNo = UUID().uuidString.replacingOccurrences(of: "-", with: "")

        guard let paybillAmount = BillingNumberParser.normalized(request.amountText), !paybillAmount.isEmpty else {
            throw BillingServiceError.featureUnavailable(message: "Enter a valid payment amount.")
        }
        let otpCode = "111111"
        let target: BillingPaymentSubmission.ReturnTarget
        let billAmount: String
        let billDate: String
        let invoiceList: [[String: Any]]

        switch request.context {
        case let .summary(oldestInvoice):
            target = .summary
            billAmount = oldestInvoice.openAmountRaw
            billDate = oldestInvoice.billCycleBeginText.isEmpty ? oldestInvoice.billCycleID : oldestInvoice.billCycleBeginText
            invoiceList = [[
                "invoiceId": oldestInvoice.invoiceId,
                "invoiceNo": oldestInvoice.invoiceNo,
                "InvoiceDetailID": oldestInvoice.invoiceNo,
                "invoiceSerialNo": serialNo,
                "currencyId": oldestInvoice.currencyId,
                "paymentAmount": paybillAmount,
                "taxAmount": oldestInvoice.taxAmountRaw
            ]]
        case let .invoice(invoice):
            target = .list
            billAmount = invoice.openAmountRaw
            billDate = invoice.billCycleBeginText.isEmpty ? invoice.billCycleID : invoice.billCycleBeginText
            invoiceList = [[
                "invoiceId": invoice.invoiceId,
                "invoiceNo": invoice.invoiceNo,
                "InvoiceDetailID": invoice.invoiceNo,
                "invoiceSerialNo": serialNo,
                "currencyId": invoice.currencyId,
                "paymentAmount": paybillAmount,
                "taxAmount": invoice.taxAmountRaw
            ]]
        }

        do {
            let mobileMoneyData = try await client.post(
                BillingAPI.mobileMoneyPay,
                body: [
                    "serviceNumber": identity.serviceNumber,
                    "otpCode": otpCode,
                    "amount": paybillAmount,
                    "currency": "SDG",
                    "paymentType": "payment",
                    "deviceModel": BillingDeviceContext.currentDeviceModel,
                    "deviceBrand": BillingDeviceContext.currentDeviceBrand,
                    "billAmount": billAmount,
                    "billDate": billDate,
                    "payBillAmount": paybillAmount,
                    "subscriberKey": userInfo.subscriberKey,
                    "paymentMethod": request.paymentMethod.backendValue,
                    "payFor": "1",
                    "receiveServiceNumber": identity.serviceNumber,
                    "invoiceList": invoiceList
                ]
            )
            let isSuccess = BillingResponseDataValue.bool(in: mobileMoneyData, keys: ["success"]) ?? false
            guard isSuccess else {
                let errorMessage = BillingResponseDataValue.string(in: mobileMoneyData, keys: ["mmDesc"])
                    ?? "Mobile Money payment initialization failed."
                throw BillingServiceError.featureUnavailable(message: errorMessage)
            }
            guard let transactionId = BillingResponseDataValue.string(in: mobileMoneyData, keys: ["transactionId"]),
                  !transactionId.isEmpty else {
                throw BillingServiceError.featureUnavailable(message: "Missing Mobile Money transaction ID.")
            }

            let responseData = try await client.post(
                BillingAPI.payBill,
                body: [
                    "userId": identity.userId,
                    "serviceNumber": identity.serviceNumber,
                    "receiveServiceNumber": identity.serviceNumber,
                    "accountKey": userInfo.subscriberKey,
                    "paymentMethod": request.paymentMethod.backendValue,
                    "transactionId": transactionId,
                    "payFor": "1",
                    "deviceModel": BillingDeviceContext.currentDeviceModel,
                    "deviceBrand": BillingDeviceContext.currentDeviceBrand,
                    "billAmount": billAmount,
                    "billDate": billDate,
                    "paybillAmount": paybillAmount,
                    "invoiceList": invoiceList
                ]
            )

            let orderId = BillingResponseDataValue.string(in: responseData, keys: ["orderId"]) ?? transactionId
            let statusText = BillingResponseDataValue.string(in: responseData, keys: ["submissionStatus"]) ?? "Payment Submitted"
            return BillingPaymentSubmission(
                orderId: orderId,
                statusText: statusText,
                returnTarget: target
            )
        } catch let error as HTTPClient.ClientError {
            billingLogger.error("Submit billing payment failed: \(String(describing: error), privacy: .public)")
            throw mapClientError(error)
        } catch let error as BillingServiceError {
            throw error
        } catch {
            throw BillingServiceError.networkUnavailable
        }
    }

    func downloadInvoicePDF(for invoice: BillingInvoice, session: CustSubInfo) async throws -> URL {
        let identity = try session.billingIdentity()
        let balance = try await fetchBalance(identity: identity)

        do {
            let downloadedURL = try await client.download(
                BillingAPI.downloadInvoicePdf,
                parameters: [
                    "userId": identity.userId,
                    "serviceNumber": identity.serviceNumber,
                    "billCycleID": invoice.billCycleID,
                    "invoiceId": invoice.invoiceId,
                    "invoiceNo": invoice.invoiceNo,
                    "accountCode": balance.accountCode,
                    "lang": BillingRequestLanguage.currentCode()
                ]
            )
            return try persistDownloadedPDF(
                from: downloadedURL,
                invoice: invoice,
                languageCode: BillingRequestLanguage.currentCode()
            )
        } catch let error as HTTPClient.ClientError {
            billingLogger.error("Download billing PDF failed: \(String(describing: error), privacy: .public)")
            throw mapClientError(error)
        } catch {
            throw BillingServiceError.networkUnavailable
        }
    }

    private func persistDownloadedPDF(
        from sourceURL: URL,
        invoice: BillingInvoice,
        languageCode: String
    ) throws -> URL {
        let fileManager = FileManager.default
        let directoryURL = fileManager.temporaryDirectory.appendingPathComponent("billing-preview", isDirectory: true)
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let resolvedInvoiceNo = invoice.invoiceNo.isEmpty ? invoice.billCycleID : invoice.invoiceNo
        let targetURL = directoryURL.appendingPathComponent("bill_\(resolvedInvoiceNo)_\(languageCode).pdf")

        if fileManager.fileExists(atPath: targetURL.path) {
            try fileManager.removeItem(at: targetURL)
        }

        try fileManager.copyItem(at: sourceURL, to: targetURL)
        return targetURL
    }

    private func fetchBalance(identity: BillingIdentity) async throws -> BillingBalancePayload {
        do {
            let responseData = try await client.post(
                BillingAPI.balanceEnquiry,
                body: [
                    "userId": identity.userId,
                    "serviceNumber": identity.serviceNumber
                ]
            )

            let accountCode = BillingResponseDataValue.string(in: responseData, keys: ["accountNo"])
                ?? BillingResponseDataValue.string(in: responseData, keys: ["accountCode"])
                ?? ""
            guard !accountCode.isEmpty else {
                throw BillingServiceError.missingAccountCode
            }

            return BillingBalancePayload(
                accountCode: accountCode,
                dueAmount: BillingResponseDataValue.string(in: responseData, keys: ["dueAmount"]) ?? "",
                unbilledAmount: BillingResponseDataValue.string(in: responseData, keys: ["unbilledAmount", "unBilledAmount"]) ?? "",
                nextBillDueDateText: BillingResponseDataValue.dateText(in: responseData, keys: ["nextBillDueDate"]),
                remainCreditLimitAmount: BillingResponseDataValue.string(in: responseData, keys: ["remainCreditLimitAmount"]) ?? "",
                totalUsageAmount: BillingResponseDataValue.string(in: responseData, keys: ["totalUsageAmount"]) ?? "",
                totalCreditLimitAmount: BillingResponseDataValue.string(in: responseData, keys: ["totalCreditLimitAmount"]) ?? ""
            )
        } catch let error as HTTPClient.ClientError {
            billingLogger.error("Fetch billing balance failed: \(String(describing: error), privacy: .public)")
            throw mapClientError(error)
        } catch let error as BillingServiceError {
            throw error
        } catch {
            throw BillingServiceError.networkUnavailable
        }
    }

    private func fetchInvoices(
        identity: BillingIdentity,
        accountCode: String,
        outstandingFlag: String?,
        pageIndex: Int?,
        pageSize: Int?
    ) async throws -> [BillingInvoice] {
        do {
            let resolvedPageIndex = pageIndex ?? BillingPaginationDefaults.pageIndex
            let resolvedPageSize = pageSize ?? BillingPaginationDefaults.pageSize
            var body: [String: Any] = [
                "userId": identity.userId,
                "serviceNumber": identity.serviceNumber,
                "accountCode": accountCode,
                "pageIndex": resolvedPageIndex,
                "pageSize": resolvedPageSize
            ]
            if let outstandingFlag, !outstandingFlag.isEmpty {
                body["OutstandingFlag"] = outstandingFlag
            }

            let responseData = try await client.post(BillingAPI.queryToPayBillList, body: body)
            let items = responseData.objectValue?["invoiceItemDtoList"]?.arrayValue ?? []
            return items.compactMap(Self.mapInvoice)
        } catch let error as HTTPClient.ClientError {
            billingLogger.error("Fetch billing list failed: \(String(describing: error), privacy: .public)")
            throw mapClientError(error)
        } catch {
            throw BillingServiceError.networkUnavailable
        }
    }

    private func fetchUserInfo(identity: BillingIdentity) async throws -> BillingUserInfo {
        do {
            let responseData = try await client.post(
                HomeAPI.userInfo,
                body: [
                    "serviceNumber": AuthValidator.localPhoneDigits(identity.serviceNumber),
                    "language": BillingRequestLanguage.currentCode()
                ]
            )

            let subscriberKey = BillingResponseDataValue.string(in: responseData, keys: ["subscriberKey"]) ?? ""
            guard !subscriberKey.isEmpty else {
                throw BillingServiceError.missingIdentity
            }

            return BillingUserInfo(subscriberKey: subscriberKey)
        } catch let error as HTTPClient.ClientError {
            billingLogger.error("Fetch billing user info failed: \(String(describing: error), privacy: .public)")
            throw mapClientError(error)
        } catch let error as BillingServiceError {
            throw error
        } catch {
            throw BillingServiceError.networkUnavailable
        }
    }

    private func moneyText(_ rawValue: String?) -> String {
        guard let normalized = BillingNumberParser.normalized(rawValue), !normalized.isEmpty else {
            return billingDisplayMoney("0.00 AED")
        }
        if normalized.uppercased().contains("AED") {
            return billingDisplayMoney(normalized)
        }
        return billingDisplayMoney("\(normalized) AED")
    }

    private func mapClientError(_ error: HTTPClient.ClientError) -> BillingServiceError {
        switch error {
        case let .business(_, message, _):
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? .networkUnavailable : .featureUnavailable(message: trimmed)
        case let .networkUnavailable(underlying):
            if let urlError = underlying as? URLError, urlError.code == .cancelled {
                return .requestCancelled
            }

            let nsError = underlying as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                return .requestCancelled
            }

            return .networkUnavailable
        default:
            return .networkUnavailable
        }
    }

    private static func mapInvoice(_ item: HTTPClient.ResponseData) -> BillingInvoice? {
        guard let object = item.objectValue else {
            return nil
        }

        let invoiceId = BillingResponseDataValue.string(in: object, keys: ["invoiceId"]) ?? UUID().uuidString
        let invoiceNo = BillingResponseDataValue.string(in: object, keys: ["invoiceNo"]) ?? invoiceId
        let billCycleID = BillingResponseDataValue.string(in: object, keys: ["billCycleID"]) ?? invoiceNo
        let currencyId = BillingResponseDataValue.string(in: object, keys: ["currencyId"]) ?? "AED"
        let invoiceAmountRaw = BillingResponseDataValue.string(in: object, keys: ["invoiceAmount"]) ?? "0"
        let openAmountRaw = BillingResponseDataValue.string(in: object, keys: ["openAmount"]) ?? "0"
        let taxAmountRaw = BillingResponseDataValue.string(in: object, keys: ["taxAmount"]) ?? "0"
        let statusCode = BillingResponseDataValue.string(in: object, keys: ["status"]) ?? ""
        let invoiceDateText = BillingResponseDataValue.dateText(in: object, keys: ["invoiceDate"])
        let dueDateText = BillingResponseDataValue.dateText(in: object, keys: ["dueDate"])
        let stableID = buildInvoiceStableID(
            invoiceId: invoiceId,
            invoiceNo: invoiceNo,
            billCycleID: billCycleID,
            invoiceDateText: invoiceDateText,
            dueDateText: dueDateText,
            statusCode: statusCode
        )

        return BillingInvoice(
            id: stableID,
            invoiceId: invoiceId,
            invoiceNo: invoiceNo,
            billCycleID: billCycleID,
            currencyId: currencyId,
            invoiceAmountRaw: invoiceAmountRaw,
            openAmountRaw: openAmountRaw,
            taxAmountRaw: taxAmountRaw,
            invoiceAmountText: BillingNumberParser.displayMoney(invoiceAmountRaw),
            openAmountText: BillingNumberParser.displayMoney(openAmountRaw),
            taxAmountText: BillingNumberParser.displayMoney(taxAmountRaw),
            invoiceDateText: invoiceDateText,
            dueDateText: dueDateText,
            billCycleBeginText: BillingResponseDataValue.dateText(in: object, keys: ["billCycleBeginTime"]),
            statusCode: statusCode,
            status: BillingInvoiceStatus(code: statusCode)
        )
    }

    private static func buildInvoiceStableID(
        invoiceId: String,
        invoiceNo: String,
        billCycleID: String,
        invoiceDateText: String,
        dueDateText: String,
        statusCode: String
    ) -> String {
        let parts = [
            invoiceId.trimmingCharacters(in: .whitespacesAndNewlines),
            invoiceNo.trimmingCharacters(in: .whitespacesAndNewlines),
            billCycleID.trimmingCharacters(in: .whitespacesAndNewlines),
            invoiceDateText.trimmingCharacters(in: .whitespacesAndNewlines),
            dueDateText.trimmingCharacters(in: .whitespacesAndNewlines),
            statusCode.trimmingCharacters(in: .whitespacesAndNewlines)
        ].filter { !$0.isEmpty }

        if parts.isEmpty {
            return UUID().uuidString
        }

        return parts.joined(separator: "|")
    }
}

private struct BillingIdentity: Sendable {
    let userId: String
    let serviceNumber: String
}

private struct BillingUserInfo: Sendable {
    let subscriberKey: String
}

private struct BillingBalancePayload: Sendable {
    let accountCode: String
    let dueAmount: String
    let unbilledAmount: String
    let nextBillDueDateText: String
    let remainCreditLimitAmount: String
    let totalUsageAmount: String
    let totalCreditLimitAmount: String
}

private enum BillingRequestLanguage {
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

private enum BillingDeviceContext {
    static var currentDeviceBrand: String { "Apple" }
    static var currentDeviceModel: String {
        #if canImport(UIKit)
        return UIDevice.current.model
        #else
        return "iPhone"
        #endif
    }
}

private enum BillingPaginationDefaults {
    static let pageIndex = 1
    static let pageSize = 20
}

enum BillingNumberParser {
    static func normalized(_ rawValue: String?) -> String? {
        guard let rawValue else {
            return nil
        }

        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        return trimmed
            .replacingOccurrences(of: "AED", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func decimal(_ rawValue: String?) -> Decimal? {
        guard let normalized = normalized(rawValue) else {
            return nil
        }
        return Decimal(string: normalized)
    }

    static func string(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ","
        return formatter.string(for: value) ?? "\(value)"
    }

    static func displayMoney(_ rawValue: String?) -> String {
        guard let decimal = decimal(rawValue) else {
            return billingDisplayMoney("0.00 AED")
        }
        return billingDisplayMoney("\(string(decimal)) AED")
    }
}

private enum BillingResponseDataValue {
    static func string(in responseData: HTTPClient.ResponseData, keys: [String]) -> String? {
        guard let dictionary = responseData.objectValue else {
            return nil
        }
        return string(in: dictionary, keys: keys)
    }

    static func string(in dictionary: [String: HTTPClient.ResponseData], keys: [String]) -> String? {
        for key in keys {
            if let value = dictionary[key]?.stringValue, !value.isEmpty {
                return value
            }
            if let value = dictionary[key]?.doubleValue {
                return String(value)
            }
            if let nested = dictionary[key]?.objectValue, let value = string(in: nested, keys: ["value"]) {
                return value
            }
        }
        return nil
    }

    static func bool(in responseData: HTTPClient.ResponseData, keys: [String]) -> Bool? {
        guard let dictionary = responseData.objectValue else {
            return nil
        }
        for key in keys {
            if let value = dictionary[key]?.boolValue {
                return value
            }
            if let value = dictionary[key]?.stringValue {
                let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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

    static func dateText(in responseData: HTTPClient.ResponseData, keys: [String]) -> String {
        guard let dictionary = responseData.objectValue else {
            return "-"
        }
        return dateText(in: dictionary, keys: keys)
    }

    static func dateText(in dictionary: [String: HTTPClient.ResponseData], keys: [String]) -> String {
        guard let rawValue = string(in: dictionary, keys: keys) else {
            return "-"
        }

        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "-"
        }

        if trimmed.count >= 10 {
            return String(trimmed.prefix(10))
        }
        return trimmed
    }
}

private extension CustSubInfo {
    func billingIdentity() throws -> BillingIdentity {
        let resolvedUserId = userID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let rawServiceNumber = (serviceNumber ?? phoneNumber)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedServiceNumber = AuthValidator.localPhoneDigits(rawServiceNumber)

        guard !resolvedUserId.isEmpty, !resolvedServiceNumber.isEmpty else {
            throw BillingServiceError.missingIdentity
        }

        return BillingIdentity(
            userId: resolvedUserId,
            serviceNumber: resolvedServiceNumber
        )
    }
}
