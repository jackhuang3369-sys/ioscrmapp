import Foundation
import os

private let badgeCenterLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "ioscrmapp",
    category: "BadgeCenter"
)

protocol BadgeCenterServicing: Sendable {
    func fetchBadgeCenter(session: CustSubInfo, language: AppLanguage) async throws -> BadgeCenterSnapshot
    func fetchBadgeDetail(badgeID: String, session: CustSubInfo, language: AppLanguage) async throws -> BadgeDetail
    func markBadgeAsRead(id: String, session: CustSubInfo) async throws
    func markUnlockEventHandled(
        id: String,
        source: BadgeUnlockHandledSource,
        session: CustSubInfo
    ) async throws
}

enum BadgeUnlockHandledSource: String, Sendable {
    case popupConfirm = "POPUP_CONFIRM"
    case popupDismiss = "POPUP_DISMISS"
    case detailPage = "DETAIL_PAGE"
}

enum BadgeCenterServiceError: Error {
    case notFound
    case networkUnavailable
    case featureUnavailable(message: String)

    var textValue: LocalizedTextValue {
        switch self {
        case .notFound:
            return .key("badgeCenter.error.notFound")
        case .networkUnavailable:
            return .key("badgeCenter.error.load")
        case let .featureUnavailable(message):
            return .literal(message)
        }
    }
}

actor MockBadgeCenterService: BadgeCenterServicing {
    private var records: [MockBadgeRecord]

    init() {
        records = Self.makeRecords()
    }

    func fetchBadgeCenter(session: CustSubInfo, language: AppLanguage) async throws -> BadgeCenterSnapshot {
        let sortedRecords = records.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder {
                return lhs.sortOrder < rhs.sortOrder
            }
            return lhs.id < rhs.id
        }

        return BadgeCenterSnapshot(
            overview: buildOverview(from: sortedRecords),
            badges: sortedRecords.map { $0.summary(language: language) },
            pendingUnlockEvent: sortedRecords.first(where: { $0.hasPendingUnlockEvent })?.unlockEvent(language: language)
        )
    }

    func fetchBadgeDetail(badgeID: String, session: CustSubInfo, language: AppLanguage) async throws -> BadgeDetail {
        guard let record = records.first(where: { $0.id == badgeID }) else {
            throw BadgeCenterServiceError.notFound
        }
        return record.detail(language: language)
    }

    func markBadgeAsRead(id: String, session: CustSubInfo) async throws {
        guard let index = records.firstIndex(where: { $0.id == id }) else {
            throw BadgeCenterServiceError.notFound
        }
        records[index].isUnread = false
    }

    func markUnlockEventHandled(
        id: String,
        source _: BadgeUnlockHandledSource,
        session: CustSubInfo
    ) async throws {
        guard let index = records.firstIndex(where: { "unlock-\($0.id)" == id }) else {
            throw BadgeCenterServiceError.notFound
        }
        records[index].hasPendingUnlockEvent = false
    }

    private func buildOverview(from records: [MockBadgeRecord]) -> BadgeCenterOverview {
        BadgeCenterOverview(
            acquiredCount: records.filter { $0.status == .acquired }.count,
            lockedCount: records.filter { $0.status == .locked }.count,
            expiredCount: records.filter { $0.status == .expired }.count,
            unreadCount: records.filter { $0.isUnread }.count,
            featuredCount: records.filter { $0.isFeatured }.count
        )
    }
}

struct RemoteBadgeCenterService: BadgeCenterServicing {
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

    func fetchBadgeCenter(session _: CustSubInfo, language: AppLanguage) async throws -> BadgeCenterSnapshot {
        do {
            async let snapshotTask = fetchAllBadges(language: language)
            async let unlockEventTask = fetchPendingUnlockEvent(language: language)

            let snapshot = try await snapshotTask

            let pendingUnlockEvent: BadgeUnlockEvent?
            do {
                pendingUnlockEvent = try await unlockEventTask
            } catch {
                if error is CancellationError {
                    throw error
                }
                badgeCenterLogger.error(
                    "Fetch badge unlock event failed: \(String(describing: error), privacy: .public)"
                )
                pendingUnlockEvent = nil
            }

            return BadgeCenterSnapshot(
                overview: snapshot.overview,
                badges: snapshot.badges,
                pendingUnlockEvent: pendingUnlockEvent
            )
        } catch let error as HTTPClient.ClientError {
            badgeCenterLogger.error("Fetch badge center failed: \(String(describing: error), privacy: .public)")
            throw mapClientError(error)
        } catch let error as BadgeCenterServiceError {
            throw error
        } catch {
            if error is CancellationError {
                throw error
            }
            throw BadgeCenterServiceError.networkUnavailable
        }
    }

    func fetchBadgeDetail(
        badgeID: String,
        session _: CustSubInfo,
        language: AppLanguage
    ) async throws -> BadgeDetail {
        do {
            let responseData = try await client.get(
                BadgeCenterAPI.detail(badgeID: try sanitizedResourceID(badgeID)),
                query: ["lang": language.rawValue]
            )
            return try BadgeCenterResponseMapper.mapBadgeDetail(
                from: responseData,
                language: language
            )
        } catch let error as HTTPClient.ClientError {
            badgeCenterLogger.error("Fetch badge detail failed: \(String(describing: error), privacy: .public)")
            throw mapClientError(error)
        } catch let error as BadgeCenterServiceError {
            throw error
        } catch {
            if error is CancellationError {
                throw error
            }
            throw BadgeCenterServiceError.networkUnavailable
        }
    }

    func markBadgeAsRead(id: String, session _: CustSubInfo) async throws {
        do {
            let responseData = try await client.post(
                BadgeCenterAPI.markRead(badgeID: try sanitizedResourceID(id))
            )
            guard BadgeCenterResponseMapper.mapBoolean(from: responseData) else {
                throw BadgeCenterServiceError.networkUnavailable
            }
        } catch let error as HTTPClient.ClientError {
            badgeCenterLogger.error("Mark badge read failed: \(String(describing: error), privacy: .public)")
            throw mapClientError(error)
        } catch let error as BadgeCenterServiceError {
            throw error
        } catch {
            if error is CancellationError {
                throw error
            }
            throw BadgeCenterServiceError.networkUnavailable
        }
    }

    func markUnlockEventHandled(
        id: String,
        source: BadgeUnlockHandledSource,
        session _: CustSubInfo
    ) async throws {
        do {
            let responseData = try await client.post(
                BadgeCenterAPI.handleUnlockEvent(eventID: try sanitizedResourceID(id)),
                body: ["handledSource": source.rawValue]
            )
            guard BadgeCenterResponseMapper.mapBoolean(from: responseData) else {
                throw BadgeCenterServiceError.networkUnavailable
            }
        } catch let error as HTTPClient.ClientError {
            badgeCenterLogger.error(
                "Handle badge unlock event failed: \(String(describing: error), privacy: .public)"
            )
            throw mapClientError(error)
        } catch let error as BadgeCenterServiceError {
            throw error
        } catch {
            if error is CancellationError {
                throw error
            }
            throw BadgeCenterServiceError.networkUnavailable
        }
    }

    private func fetchAllBadges(language: AppLanguage) async throws -> BadgeCenterRemoteSnapshot {
        var pageNum = 1
        var allBadges: [BadgeSummary] = []
        var overview: BadgeCenterOverview?

        while true {
            try Task.checkCancellation()

            let responseData = try await client.get(
                BadgeCenterAPI.badges,
                query: [
                    "type": BadgeCategoryFilter.all.backendCode,
                    "status": BadgeStatusFilter.all.backendCode,
                    "level": BadgeLevelFilter.all.backendCode,
                    "pageNum": pageNum,
                    "pageSize": BadgeCenterAPI.maxPageSize,
                    "lang": language.rawValue
                ]
            )

            let page = try BadgeCenterResponseMapper.mapBadgeListPage(
                from: responseData,
                language: language
            )
            if overview == nil {
                overview = page.overview
            }
            allBadges.append(contentsOf: page.items)

            guard page.hasMore, !page.items.isEmpty else {
                break
            }
            pageNum += 1
        }

        return BadgeCenterRemoteSnapshot(
            overview: overview ?? BadgeCenterResponseMapper.emptyOverview,
            badges: allBadges
        )
    }

    private func fetchPendingUnlockEvent(language: AppLanguage) async throws -> BadgeUnlockEvent? {
        let responseData = try await client.get(
            BadgeCenterAPI.unlockEvents,
            query: [
                "status": "UNREAD",
                "limit": 1,
                "lang": language.rawValue
            ]
        )

        return try BadgeCenterResponseMapper.mapUnlockEvents(
            from: responseData,
            language: language
        ).first
    }

    private func sanitizedResourceID(_ rawValue: String) throws -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = "^[A-Za-z0-9_-]{1,64}$"
        guard
            !trimmed.isEmpty,
            trimmed.range(of: pattern, options: .regularExpression) != nil
        else {
            throw BadgeCenterServiceError.notFound
        }
        return trimmed
    }

    private func mapClientError(_ error: HTTPClient.ClientError) -> BadgeCenterServiceError {
        switch error {
        case let .business(code, message, _):
            switch code {
            case 50_027:
                return .notFound
            case 40_014, 40_015:
                return .networkUnavailable
            default:
                if !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return .featureUnavailable(message: message)
                }
                return .networkUnavailable
            }
        case .httpStatus, .invalidJSON, .invalidResponse, .networkUnavailable:
            return .networkUnavailable
        }
    }
}

private struct BadgeCenterRemoteSnapshot {
    let overview: BadgeCenterOverview
    let badges: [BadgeSummary]
}

private struct BadgeCenterListPage {
    let overview: BadgeCenterOverview
    let items: [BadgeSummary]
    let hasMore: Bool
}

private enum BadgeCenterResponseMapper {
    static let emptyOverview = BadgeCenterOverview(
        acquiredCount: 0,
        lockedCount: 0,
        expiredCount: 0,
        unreadCount: 0,
        featuredCount: 0
    )

    static func mapBadgeListPage(
        from responseData: HTTPClient.ResponseData,
        language: AppLanguage
    ) throws -> BadgeCenterListPage {
        guard let object = responseData.objectValue else {
            throw HTTPClient.ClientError.invalidResponse
        }

        let overview = mapOverview(from: object["overview"]?.objectValue)
        let items = (object["items"]?.arrayValue ?? []).compactMap {
            mapBadgeSummary(from: $0, language: language)
        }
        let pageInfo = object["pageInfo"]?.objectValue

        return BadgeCenterListPage(
            overview: overview,
            items: items,
            hasMore: bool(in: pageInfo, keys: ["hasMore"]) ?? false
        )
    }

    static func mapBadgeDetail(
        from responseData: HTTPClient.ResponseData,
        language: AppLanguage
    ) throws -> BadgeDetail {
        guard
            let object = responseData.objectValue,
            let badgeID = string(in: object, keys: ["badgeId"]),
            let status = BadgeDisplayStatus(backendCode: string(in: object, keys: ["displayStatus"]))
        else {
            throw HTTPClient.ClientError.invalidResponse
        }

        let category = BadgeCategoryFilter(backendCode: string(in: object, keys: ["badgeType"])) ?? .event
        let level = BadgeLevel(backendCode: string(in: object, keys: ["badgeLevel"])) ?? .base
        let badgeName = firstNonEmpty([
            string(in: object, keys: ["displayName"]),
            string(in: object, keys: ["badgeCode"])
        ]) ?? badgeID
        let subtitle = firstNonEmpty([
            string(in: object, keys: ["subtitle"]),
            string(in: object, keys: ["specialTagText"])
        ]) ?? ""
        let rewardsText = string(in: object, keys: ["rewards"]) ?? ""
        let lockHint = string(in: object, keys: ["lockHint"]) ?? ""
        let progressText = string(in: object, keys: ["progressText"]) ?? ""
        let benefitPayloads = object["benefits"]?.arrayValue ?? []
        let historyPayloads = object["historyEntries"]?.arrayValue ?? []

        return BadgeDetail(
            id: badgeID,
            category: category,
            status: status,
            level: level,
            accentStyle: accentStyle(
                for: category,
                level: level
            ),
            iconSystemName: iconSystemName(for: category, level: level),
            iconURL: url(in: object, keys: ["iconUrl"]),
            iconHDURL: url(in: object, keys: ["iconHdUrl"]),
            backgroundURL: url(in: object, keys: ["backgroundUrl"]),
            title: .literal(badgeName),
            subtitle: .literal(subtitle),
            englishName: firstNonEmpty([
                string(in: object, keys: ["englishName"]),
                string(in: object, keys: ["displayName"])
            ]) ?? badgeName,
            arabicName: firstNonEmpty([
                string(in: object, keys: ["arabicName"]),
                string(in: object, keys: ["englishName"]),
                string(in: object, keys: ["displayName"])
            ]) ?? badgeName,
            requirementItems: buildRequirementItems(
                status: status,
                requirements: string(in: object, keys: ["requirements"]) ?? "",
                progressText: progressText,
                lockHint: lockHint
            ),
            rewardItems: buildRewardItems(
                rewards: rewardsText,
                benefits: benefitPayloads,
                badgeStatus: status
            ),
            acquisitionTimeText: BadgeCenterDateParser.displayText(from: object["acquiredAt"]),
            badgeStory: .literal(string(in: object, keys: ["badgeStory"]) ?? ""),
            statusHint: .literal(resolveStatusHint(from: object, status: status)),
            validityText: .literal(string(in: object, keys: ["validityText"]) ?? ""),
            triggerText: .literal(string(in: object, keys: ["triggerSource"]) ?? ""),
            history: historyPayloads.compactMap {
                mapHistoryItem(from: $0, language: language)
            },
            progress: progressText.isEmpty ? nil : parseProgress(progressText),
            isUnread: bool(in: object, keys: ["hasUnread"]) ?? false,
            isFeatured: isFeatured(from: object)
        )
    }

    static func mapUnlockEvents(
        from responseData: HTTPClient.ResponseData,
        language _: AppLanguage
    ) throws -> [BadgeUnlockEvent] {
        guard let object = responseData.objectValue else {
            throw HTTPClient.ClientError.invalidResponse
        }

        return (object["events"]?.arrayValue ?? []).compactMap { responseData in
            guard
                let eventObject = responseData.objectValue,
                let eventID = string(in: eventObject, keys: ["eventId"]),
                let badgeID = string(in: eventObject, keys: ["badgeId"])
            else {
                return nil
            }

            let displayName = firstNonEmpty([
                string(in: eventObject, keys: ["displayName"]),
                string(in: eventObject, keys: ["badgeSummary"])
            ]) ?? badgeID

            return BadgeUnlockEvent(
                id: eventID,
                badgeID: badgeID,
                title: .literal(
                    firstNonEmpty([
                        string(in: eventObject, keys: ["popupTitle"]),
                        displayName
                    ]) ?? displayName
                ),
                badgeName: .literal(displayName),
                message: .literal(string(in: eventObject, keys: ["popupMessage"]) ?? ""),
                iconURL: url(in: eventObject, keys: ["iconUrl"])
            )
        }
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

    private static func mapOverview(from dictionary: [String: HTTPClient.ResponseData]?) -> BadgeCenterOverview {
        BadgeCenterOverview(
            acquiredCount: int(in: dictionary, keys: ["acquiredCount"]) ?? 0,
            lockedCount: int(in: dictionary, keys: ["lockedCount"]) ?? 0,
            expiredCount: int(in: dictionary, keys: ["expiredCount"]) ?? 0,
            unreadCount: int(in: dictionary, keys: ["unreadCount"]) ?? 0,
            featuredCount: 0
        )
    }

    private static func mapBadgeSummary(
        from responseData: HTTPClient.ResponseData,
        language _: AppLanguage
    ) -> BadgeSummary? {
        guard
            let object = responseData.objectValue,
            let badgeID = string(in: object, keys: ["badgeId"]),
            let status = BadgeDisplayStatus(backendCode: string(in: object, keys: ["displayStatus"]))
        else {
            return nil
        }

        let category = BadgeCategoryFilter(backendCode: string(in: object, keys: ["badgeType"])) ?? .event
        let level = BadgeLevel(backendCode: string(in: object, keys: ["badgeLevel"])) ?? .base
        let displayName = firstNonEmpty([
            string(in: object, keys: ["displayName"]),
            string(in: object, keys: ["badgeCode"])
        ]) ?? badgeID
        let subtitle = firstNonEmpty([
            string(in: object, keys: ["subtitle"]),
            string(in: object, keys: ["rewardSummary"]),
            string(in: object, keys: ["specialTagText"])
        ]) ?? ""
        let progressText = string(in: object, keys: ["progressText"]) ?? ""
        let lockHint = string(in: object, keys: ["lockHint"]) ?? ""
        let rewardSummary = string(in: object, keys: ["rewardSummary"]) ?? ""

        return BadgeSummary(
            id: badgeID,
            category: category,
            status: status,
            level: level,
            accentStyle: accentStyle(for: category, level: level),
            iconSystemName: iconSystemName(for: category, level: level),
            iconURL: url(in: object, keys: ["iconUrl"]),
            iconHDURL: url(in: object, keys: ["iconHdUrl"]),
            backgroundURL: url(in: object, keys: ["backgroundUrl"]),
            title: .literal(displayName),
            subtitle: .literal(subtitle),
            englishName: displayName,
            arabicName: displayName,
            requirementSummary: .literal(firstNonEmpty([lockHint, progressText]) ?? ""),
            rewardSummary: .literal(rewardSummary),
            acquiredAt: BadgeCenterDateParser.date(from: object["acquiredAt"]),
            acquisitionTimeText: BadgeCenterDateParser.displayText(from: object["acquiredAt"]),
            badgeStoryPreview: .literal(subtitle),
            statusHint: .literal(resolveStatusHint(from: object, status: status)),
            lockHint: lockHint.isEmpty ? nil : .literal(lockHint),
            progress: progressText.isEmpty ? nil : parseProgress(progressText),
            isUnread: bool(in: object, keys: ["hasUnread"]) ?? false,
            isFeatured: isFeatured(from: object)
        )
    }

    private static func buildRequirementItems(
        status: BadgeDisplayStatus,
        requirements: String,
        progressText: String,
        lockHint: String
    ) -> [BadgeRequirementItem] {
        uniqueTexts([requirements, progressText, lockHint]).enumerated().map { index, text in
            BadgeRequirementItem(
                id: "requirement-\(index)",
                title: .literal(text),
                isCompleted: status != .locked
            )
        }
    }

    private static func buildRewardItems(
        rewards: String,
        benefits: [HTTPClient.ResponseData],
        badgeStatus: BadgeDisplayStatus
    ) -> [BadgeRewardItem] {
        let benefitItems = benefits.compactMap { responseData -> BadgeRewardItem? in
            guard let object = responseData.objectValue else {
                return nil
            }

            let benefitID = string(in: object, keys: ["benefitId"]) ?? UUID().uuidString
            let title = firstNonEmpty([
                string(in: object, keys: ["title"]),
                string(in: object, keys: ["summary"]),
                benefitID
            ]) ?? benefitID
            let description = firstNonEmpty([
                string(in: object, keys: ["summary"]),
                string(in: object, keys: ["validFromRule"]),
                rewards
            ]) ?? ""

            return BadgeRewardItem(
                id: benefitID,
                title: .literal(title),
                status: mapBenefitStatus(
                    rawValue: string(in: object, keys: ["status"]),
                    badgeStatus: badgeStatus
                ),
                description: .literal(description)
            )
        }

        guard benefitItems.isEmpty else {
            return benefitItems
        }

        let normalizedRewards = rewards.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedRewards.isEmpty else {
            return []
        }

        return [
            BadgeRewardItem(
                id: "reward-text",
                title: .literal(firstNonEmpty([firstLine(from: normalizedRewards), normalizedRewards]) ?? normalizedRewards),
                status: defaultBenefitStatus(for: badgeStatus),
                description: .literal(normalizedRewards)
            )
        ]
    }

    private static func mapHistoryItem(
        from responseData: HTTPClient.ResponseData,
        language: AppLanguage
    ) -> BadgeHistoryItem? {
        guard let object = responseData.objectValue else {
            return nil
        }

        let historyID = string(in: object, keys: ["eventId"]) ?? UUID().uuidString
        let eventType = string(in: object, keys: ["eventType"]) ?? ""
        let description = firstNonEmpty([
            string(in: object, keys: ["description"]),
            eventType
        ]) ?? ""

        return BadgeHistoryItem(
            id: historyID,
            title: historyTitle(for: eventType, language: language),
            subtitle: .literal(description),
            timestampText: BadgeCenterDateParser.displayText(from: object["eventTime"]) ?? ""
        )
    }

    private static func resolveStatusHint(
        from object: [String: HTTPClient.ResponseData],
        status: BadgeDisplayStatus
    ) -> String {
        switch status {
        case .locked:
            return firstNonEmpty([
                string(in: object, keys: ["lockHint"]),
                string(in: object, keys: ["progressText"]),
                string(in: object, keys: ["requirements"])
            ]) ?? ""
        case .expired:
            return firstNonEmpty([
                BadgeCenterDateParser.displayText(from: object["expiredAt"]).map { "Expired at \($0)" },
                string(in: object, keys: ["validityText"]),
                string(in: object, keys: ["subtitle"])
            ]) ?? ""
        case .acquired:
            return firstNonEmpty([
                string(in: object, keys: ["specialTagText"]),
                string(in: object, keys: ["rewardSummary"]),
                string(in: object, keys: ["subtitle"])
            ]) ?? ""
        }
    }

    private static func historyTitle(for rawEventType: String, language: AppLanguage) -> LocalizedTextValue {
        let eventType = rawEventType.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        switch language {
        case .simplifiedChinese:
            switch eventType {
            case "UNLOCK":
                return .literal("已解锁")
            case "EXPIRE":
                return .literal("已过期")
            default:
                return .literal("状态更新")
            }
        case .arabic:
            switch eventType {
            case "UNLOCK":
                return .literal("تم الفتح")
            case "EXPIRE":
                return .literal("انتهت الصلاحية")
            default:
                return .literal("تم تحديث الحالة")
            }
        case .english:
            switch eventType {
            case "UNLOCK":
                return .literal("Unlocked")
            case "EXPIRE":
                return .literal("Expired")
            default:
                return .literal("Status Updated")
            }
        }
    }

    private static func parseProgress(_ rawText: String) -> BadgeProgressSnapshot? {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let pattern = #"(\d+)\s*/\s*(\d+)"#
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(
                in: trimmed,
                range: NSRange(location: 0, length: (trimmed as NSString).length)
            ),
            match.numberOfRanges == 3
        else {
            return nil
        }

        let currentRange = Range(match.range(at: 1), in: trimmed)
        let targetRange = Range(match.range(at: 2), in: trimmed)
        guard
            let currentRange,
            let targetRange,
            let currentValue = Int(trimmed[currentRange]),
            let targetValue = Int(trimmed[targetRange])
        else {
            return nil
        }

        return BadgeProgressSnapshot(
            currentValue: currentValue,
            targetValue: targetValue,
            summary: .literal(trimmed)
        )
    }

    private static func mapBenefitStatus(
        rawValue: String?,
        badgeStatus: BadgeDisplayStatus
    ) -> BadgeBenefitStatus {
        switch rawValue?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "AVAILABLE":
            return badgeStatus == .expired ? .expired : .active
        case "LOCKED":
            return badgeStatus == .locked ? .upcoming : .unavailable
        case "EXPIRED":
            return .expired
        default:
            return defaultBenefitStatus(for: badgeStatus)
        }
    }

    private static func defaultBenefitStatus(for badgeStatus: BadgeDisplayStatus) -> BadgeBenefitStatus {
        switch badgeStatus {
        case .acquired:
            return .active
        case .locked:
            return .upcoming
        case .expired:
            return .expired
        }
    }

    private static func iconSystemName(
        for category: BadgeCategoryFilter,
        level: BadgeLevel
    ) -> String {
        switch category {
        case .all:
            return "rosette"
        case .newcomer:
            return "star.circle.fill"
        case .daily:
            return level == .ultimate ? "calendar.badge.clock" : "calendar.circle.fill"
        case .challenge:
            return "bolt.shield.fill"
        case .event:
            return "sparkles"
        case .cycle:
            return "arrow.triangle.2.circlepath.circle.fill"
        case .ultimate:
            return "crown.fill"
        }
    }

    private static func accentStyle(
        for category: BadgeCategoryFilter,
        level: BadgeLevel
    ) -> BadgeAccentStyle {
        switch (category, level) {
        case (.ultimate, _), (_, .ultimate):
            return .sunrise
        case (.challenge, _), (_, .premium):
            return .night
        case (.event, _):
            return .sunrise
        case (.cycle, _):
            return .ocean
        case (.newcomer, _):
            return .aurora
        case (.daily, _):
            return .ocean
        case (.all, _), (_, .advanced):
            return .ocean
        }
    }

    private static func isFeatured(from object: [String: HTTPClient.ResponseData]) -> Bool {
        let specialTag = string(in: object, keys: ["specialTag"]) ?? ""
        let specialTagText = string(in: object, keys: ["specialTagText"]) ?? ""
        return !specialTag.isEmpty || !specialTagText.isEmpty
    }

    private static func firstLine(from text: String) -> String? {
        text.split(whereSeparator: \.isNewline).first.map(String.init)
    }

    private static func uniqueTexts(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var results: [String] = []

        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                continue
            }

            let dedupeKey = trimmed.lowercased()
            if seen.insert(dedupeKey).inserted {
                results.append(trimmed)
            }
        }

        return results
    }

    private static func url(
        in dictionary: [String: HTTPClient.ResponseData],
        keys: [String]
    ) -> URL? {
        guard let rawValue = string(in: dictionary, keys: keys) else {
            return nil
        }
        return URL(string: rawValue)
    }

    fileprivate static func string(
        in dictionary: [String: HTTPClient.ResponseData]?,
        keys: [String]
    ) -> String? {
        guard let dictionary else {
            return nil
        }

        for key in keys {
            if let value = dictionary[key]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                return value
            }

            if let value = dictionary[key]?.intValue {
                return String(value)
            }

            if let value = dictionary[key]?.doubleValue {
                return String(value)
            }
        }

        return nil
    }

    fileprivate static func int(
        in dictionary: [String: HTTPClient.ResponseData]?,
        keys: [String]
    ) -> Int? {
        guard let dictionary else {
            return nil
        }

        for key in keys {
            if let value = dictionary[key]?.intValue {
                return value
            }

            if let value = dictionary[key]?.stringValue, let intValue = Int(value) {
                return intValue
            }
        }

        return nil
    }

    private static func bool(
        in dictionary: [String: HTTPClient.ResponseData]?,
        keys: [String]
    ) -> Bool? {
        guard let dictionary else {
            return nil
        }

        for key in keys {
            if let value = dictionary[key]?.boolValue {
                return value
            }

            if let value = dictionary[key]?.intValue {
                return value != 0
            }

            if let value = dictionary[key]?.stringValue {
                switch value.lowercased() {
                case "1", "true", "yes":
                    return true
                case "0", "false", "no":
                    return false
                default:
                    break
                }
            }
        }

        return nil
    }

    private static func firstNonEmpty(_ values: [String?]) -> String? {
        for value in values {
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return nil
    }
}

private enum BadgeCenterDateParser {
    private static let iso8601FractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let backendFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    static func displayText(from responseData: HTTPClient.ResponseData?) -> String? {
        if let date = parse(responseData) {
            return displayFormatter.string(from: date)
        }

        guard let rawValue = responseData?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines), !rawValue.isEmpty else {
            return nil
        }

        return rawValue.count >= 16 ? String(rawValue.prefix(16)) : rawValue
    }

    static func date(from responseData: HTTPClient.ResponseData?) -> Date? {
        parse(responseData)
    }

    private static func parse(_ responseData: HTTPClient.ResponseData?) -> Date? {
        guard let responseData else {
            return nil
        }

        switch responseData {
        case let .string(value):
            return parse(value)
        case let .number(value):
            return parse(timestamp: value)
        case let .object(dictionary):
            return parse(dictionary)
        default:
            return nil
        }
    }

    private static func parse(_ value: String) -> Date? {
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

    private static func parse(timestamp: Double) -> Date {
        timestamp > 1_000_000_000_000
            ? Date(timeIntervalSince1970: timestamp / 1_000)
            : Date(timeIntervalSince1970: timestamp)
    }

    private static func parse(_ dictionary: [String: HTTPClient.ResponseData]) -> Date? {
        if let nestedString = BadgeCenterResponseMapper.string(
            in: dictionary,
            keys: ["value", "dateTime", "time", "localDateTime"]
        ) {
            return parse(nestedString)
        }

        let year = BadgeCenterResponseMapper.int(in: dictionary, keys: ["year"])
        let month = BadgeCenterResponseMapper.int(in: dictionary, keys: ["month", "monthValue"])
        let day = BadgeCenterResponseMapper.int(in: dictionary, keys: ["day", "dayOfMonth"])

        guard let year, let month, let day else {
            return nil
        }

        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone.current
        components.year = year
        components.month = month
        components.day = day
        components.hour = BadgeCenterResponseMapper.int(in: dictionary, keys: ["hour"]) ?? 0
        components.minute = BadgeCenterResponseMapper.int(in: dictionary, keys: ["minute"]) ?? 0
        components.second = BadgeCenterResponseMapper.int(in: dictionary, keys: ["second"]) ?? 0
        return components.date
    }
}

private struct MockBadgeRecord: Sendable {
    let id: String
    let sortOrder: Int
    let category: BadgeCategoryFilter
    let status: BadgeDisplayStatus
    let level: BadgeLevel
    let accentStyle: BadgeAccentStyle
    let iconSystemName: String
    let title: BadgeCopy
    let subtitle: BadgeCopy
    let englishName: String
    let arabicName: String
    let requirementSummary: BadgeCopy
    let rewardSummary: BadgeCopy
    let badgeStoryPreview: BadgeCopy
    let statusHint: BadgeCopy
    let lockHint: BadgeCopy?
    let progress: MockProgress?
    let requirementItems: [MockRequirement]
    let rewardItems: [MockReward]
    let badgeStory: BadgeCopy
    let validityText: BadgeCopy
    let triggerText: BadgeCopy
    let history: [MockHistory]
    let acquisitionTimeText: String?
    let isFeatured: Bool
    var isUnread: Bool
    var hasPendingUnlockEvent: Bool
    let unlockMessage: BadgeCopy?

    func summary(language: AppLanguage) -> BadgeSummary {
        BadgeSummary(
            id: id,
            category: category,
            status: status,
            level: level,
            accentStyle: accentStyle,
            iconSystemName: iconSystemName,
            iconURL: nil,
            iconHDURL: nil,
            backgroundURL: nil,
            title: title.value(language: language),
            subtitle: subtitle.value(language: language),
            englishName: englishName,
            arabicName: arabicName,
            requirementSummary: requirementSummary.value(language: language),
            rewardSummary: rewardSummary.value(language: language),
            acquiredAt: nil,
            acquisitionTimeText: acquisitionTimeText,
            badgeStoryPreview: badgeStoryPreview.value(language: language),
            statusHint: statusHint.value(language: language),
            lockHint: lockHint?.value(language: language),
            progress: progress?.snapshot(language: language),
            isUnread: isUnread,
            isFeatured: isFeatured
        )
    }

    func detail(language: AppLanguage) -> BadgeDetail {
        BadgeDetail(
            id: id,
            category: category,
            status: status,
            level: level,
            accentStyle: accentStyle,
            iconSystemName: iconSystemName,
            iconURL: nil,
            iconHDURL: nil,
            backgroundURL: nil,
            title: title.value(language: language),
            subtitle: subtitle.value(language: language),
            englishName: englishName,
            arabicName: arabicName,
            requirementItems: requirementItems.map { $0.item(language: language) },
            rewardItems: rewardItems.map { $0.item(language: language) },
            acquisitionTimeText: acquisitionTimeText,
            badgeStory: badgeStory.value(language: language),
            statusHint: statusHint.value(language: language),
            validityText: validityText.value(language: language),
            triggerText: triggerText.value(language: language),
            history: history.map { $0.item(language: language) },
            progress: progress?.snapshot(language: language),
            isUnread: isUnread,
            isFeatured: isFeatured
        )
    }

    func unlockEvent(language: AppLanguage) -> BadgeUnlockEvent? {
        guard hasPendingUnlockEvent, let unlockMessage else {
            return nil
        }

        return BadgeUnlockEvent(
            id: "unlock-\(id)",
            badgeID: id,
            title: .key("badgeCenter.popup.title"),
            badgeName: title.value(language: language),
            message: unlockMessage.value(language: language),
            iconURL: nil
        )
    }
}

private struct MockProgress: Sendable {
    let currentValue: Int
    let targetValue: Int
    let summary: BadgeCopy

    func snapshot(language: AppLanguage) -> BadgeProgressSnapshot {
        BadgeProgressSnapshot(
            currentValue: currentValue,
            targetValue: targetValue,
            summary: summary.value(language: language)
        )
    }
}

private struct MockRequirement: Sendable {
    let id: String
    let title: BadgeCopy
    let isCompleted: Bool

    func item(language: AppLanguage) -> BadgeRequirementItem {
        BadgeRequirementItem(
            id: id,
            title: title.value(language: language),
            isCompleted: isCompleted
        )
    }
}

private struct MockReward: Sendable {
    let id: String
    let title: BadgeCopy
    let status: BadgeBenefitStatus
    let description: BadgeCopy

    func item(language: AppLanguage) -> BadgeRewardItem {
        BadgeRewardItem(
            id: id,
            title: title.value(language: language),
            status: status,
            description: description.value(language: language)
        )
    }
}

private struct MockHistory: Sendable {
    let id: String
    let title: BadgeCopy
    let subtitle: BadgeCopy
    let timestampText: String

    func item(language: AppLanguage) -> BadgeHistoryItem {
        BadgeHistoryItem(
            id: id,
            title: title.value(language: language),
            subtitle: subtitle.value(language: language),
            timestampText: timestampText
        )
    }
}

private struct BadgeCopy: Sendable {
    let zhHans: String
    let en: String
    let ar: String

    func value(language: AppLanguage) -> LocalizedTextValue {
        .literal(string(language: language))
    }

    func string(language: AppLanguage) -> String {
        switch language {
        case .simplifiedChinese:
            return zhHans
        case .english:
            return en
        case .arabic:
            return ar
        }
    }
}

private extension MockBadgeCenterService {
    static func makeRecords() -> [MockBadgeRecord] {
        [
            MockBadgeRecord(
                id: "welcome-onboard",
                sortOrder: 10,
                category: .newcomer,
                status: .acquired,
                level: .base,
                accentStyle: .aurora,
                iconSystemName: "sparkles",
                title: BadgeCopy(
                    zhHans: "欢迎登船",
                    en: "Welcome Onboard",
                    ar: "مرحبًا بك"
                ),
                subtitle: BadgeCopy(
                    zhHans: "完成注册与首登",
                    en: "Joined and verified your line",
                    ar: "أكملت التسجيل وتوثيق الخط"
                ),
                englishName: "Welcome Onboard",
                arabicName: "مرحبًا بك",
                requirementSummary: BadgeCopy(
                    zhHans: "完成账号注册并首次登录 du App",
                    en: "Register your account and complete your first du App sign-in",
                    ar: "سجل حسابك وأكمل أول تسجيل دخول إلى تطبيق du"
                ),
                rewardSummary: BadgeCopy(
                    zhHans: "获得 5GB 新手流量包与新人专属标识",
                    en: "Receive a 5GB starter pass and a newcomer crest",
                    ar: "احصل على باقة 5 جيجابايت للمبتدئين وشارة ترحيبية"
                ),
                badgeStoryPreview: BadgeCopy(
                    zhHans: "你的徽章旅程从这里开始。",
                    en: "This is where your badge journey begins.",
                    ar: "من هنا تبدأ رحلة الأوسمة الخاصة بك."
                ),
                statusHint: BadgeCopy(
                    zhHans: "已获得，可立即查看权益。",
                    en: "Acquired and ready to use.",
                    ar: "تم الحصول عليه وهو جاهز للاستخدام."
                ),
                lockHint: nil,
                progress: nil,
                requirementItems: [
                    MockRequirement(
                        id: "register",
                        title: BadgeCopy(
                            zhHans: "完成新用户注册",
                            en: "Complete a new-user registration",
                            ar: "أكمل تسجيل مستخدم جديد"
                        ),
                        isCompleted: true
                    ),
                    MockRequirement(
                        id: "login",
                        title: BadgeCopy(
                            zhHans: "首次登录 App",
                            en: "Sign in to the app for the first time",
                            ar: "سجل الدخول إلى التطبيق لأول مرة"
                        ),
                        isCompleted: true
                    )
                ],
                rewardItems: [
                    MockReward(
                        id: "starter-data",
                        title: BadgeCopy(
                            zhHans: "5GB 新手流量包",
                            en: "5GB starter data pass",
                            ar: "باقة 5 جيجابايت للمبتدئين"
                        ),
                        status: .active,
                        description: BadgeCopy(
                            zhHans: "已生效，可在本月套餐外优先抵扣。",
                            en: "Active now and deducted before out-of-plan usage this month.",
                            ar: "مفعلة الآن وتُستهلك قبل الاستخدام خارج الباقة هذا الشهر."
                        )
                    )
                ],
                badgeStory: BadgeCopy(
                    zhHans: "欢迎登船徽章记录了你正式开启 du 数字服务体验的第一步，它代表账户、号码和设备已经完成可信绑定。",
                    en: "The Welcome Onboard badge marks the moment your account, line, and device are fully connected to the du digital experience.",
                    ar: "يوثق وسام الترحيب اللحظة التي أصبح فيها حسابك وخطك وجهازك مرتبطين بالكامل بتجربة du الرقمية."
                ),
                validityText: BadgeCopy(
                    zhHans: "永久有效",
                    en: "Always valid",
                    ar: "صالح دائمًا"
                ),
                triggerText: BadgeCopy(
                    zhHans: "系统在注册完成后自动发放。",
                    en: "Granted automatically once onboarding is completed.",
                    ar: "يُمنح تلقائيًا عند اكتمال رحلة الانضمام."
                ),
                history: [
                    MockHistory(
                        id: "issued",
                        title: BadgeCopy(
                            zhHans: "徽章已发放",
                            en: "Badge issued",
                            ar: "تم إصدار الوسام"
                        ),
                        subtitle: BadgeCopy(
                            zhHans: "系统确认你的新用户注册状态。",
                            en: "The system verified your new-user registration.",
                            ar: "أكد النظام حالة تسجيل المستخدم الجديد."
                        ),
                        timestampText: "2026-02-08 10:20"
                    ),
                    MockHistory(
                        id: "benefit",
                        title: BadgeCopy(
                            zhHans: "权益已激活",
                            en: "Benefit activated",
                            ar: "تم تفعيل الميزة"
                        ),
                        subtitle: BadgeCopy(
                            zhHans: "新手流量包已发放到当前号码。",
                            en: "The starter data pass was attached to your current line.",
                            ar: "تم ربط باقة البيانات الترحيبية بخطك الحالي."
                        ),
                        timestampText: "2026-02-08 10:22"
                    )
                ],
                acquisitionTimeText: "2026-02-08 10:20",
                isFeatured: false,
                isUnread: false,
                hasPendingUnlockEvent: false,
                unlockMessage: nil
            ),
            MockBadgeRecord(
                id: "monthly-active",
                sortOrder: 20,
                category: .daily,
                status: .acquired,
                level: .advanced,
                accentStyle: .ocean,
                iconSystemName: "calendar.badge.clock",
                title: BadgeCopy(
                    zhHans: "月度活跃",
                    en: "Monthly Active",
                    ar: "نشط شهريًا"
                ),
                subtitle: BadgeCopy(
                    zhHans: "连续 30 天保持活跃",
                    en: "Stayed active for 30 consecutive days",
                    ar: "بقيت نشطًا لمدة 30 يومًا متتالية"
                ),
                englishName: "Monthly Active",
                arabicName: "نشط شهريًا",
                requirementSummary: BadgeCopy(
                    zhHans: "自然月内完成 20 次有效 App 互动",
                    en: "Complete 20 qualified app interactions within one calendar month",
                    ar: "أكمل 20 تفاعلًا مؤهلًا داخل التطبيق خلال شهر واحد"
                ),
                rewardSummary: BadgeCopy(
                    zhHans: "获得每月活动优先报名资格",
                    en: "Unlock priority registration for monthly campaigns",
                    ar: "احصل على أولوية التسجيل في الحملات الشهرية"
                ),
                badgeStoryPreview: BadgeCopy(
                    zhHans: "持续活跃是忠诚度成长的基础。",
                    en: "Consistency is the foundation of loyalty growth.",
                    ar: "الاستمرارية هي أساس نمو الولاء."
                ),
                statusHint: BadgeCopy(
                    zhHans: "已达成，本月活动报名优先权已生效。",
                    en: "Achieved, and your monthly campaign priority is active.",
                    ar: "تم تحقيقه وأولوية الحملات الشهرية مفعلة."
                ),
                lockHint: nil,
                progress: nil,
                requirementItems: [
                    MockRequirement(
                        id: "qualified-activity",
                        title: BadgeCopy(
                            zhHans: "30 天内完成 20 次有效互动",
                            en: "Complete 20 qualified interactions in 30 days",
                            ar: "أكمل 20 تفاعلًا مؤهلًا خلال 30 يومًا"
                        ),
                        isCompleted: true
                    )
                ],
                rewardItems: [
                    MockReward(
                        id: "campaign-priority",
                        title: BadgeCopy(
                            zhHans: "每月活动优先报名",
                            en: "Priority access to monthly campaigns",
                            ar: "أولوية الوصول إلى الحملات الشهرية"
                        ),
                        status: .active,
                        description: BadgeCopy(
                            zhHans: "你将在活动开放前 4 小时收到预通知。",
                            en: "You'll receive early notice four hours before public release.",
                            ar: "ستتلقى إشعارًا مبكرًا قبل الإطلاق العام بأربع ساعات."
                        )
                    )
                ],
                badgeStory: BadgeCopy(
                    zhHans: "月度活跃徽章代表你在一个完整周期内保持了稳定的使用频率，是系统判断高黏性用户的重要标记。",
                    en: "The Monthly Active badge signals sustained engagement across an entire cycle and is used as a high-retention loyalty signal.",
                    ar: "يشير وسام النشاط الشهري إلى التفاعل المستمر عبر دورة كاملة ويُستخدم كإشارة ولاء عالية الاحتفاظ."
                ),
                validityText: BadgeCopy(
                    zhHans: "本周期内有效，满足新周期条件后自动续期",
                    en: "Valid for the current cycle and renewed automatically when requalified",
                    ar: "صالح للدورة الحالية ويُجدد تلقائيًا عند إعادة التأهل"
                ),
                triggerText: BadgeCopy(
                    zhHans: "系统每日批量校验月度活跃条件。",
                    en: "Validated in the daily monthly-activity batch job.",
                    ar: "يتم التحقق منه يوميًا ضمن مهمة النشاط الشهري الدورية."
                ),
                history: [
                    MockHistory(
                        id: "reached-target",
                        title: BadgeCopy(
                            zhHans: "达成活跃目标",
                            en: "Activity target reached",
                            ar: "تم بلوغ هدف النشاط"
                        ),
                        subtitle: BadgeCopy(
                            zhHans: "当月第 20 次有效互动已记录。",
                            en: "Your 20th qualified interaction was recorded this month.",
                            ar: "تم تسجيل التفاعل المؤهل العشرين لهذا الشهر."
                        ),
                        timestampText: "2026-03-03 19:10"
                    )
                ],
                acquisitionTimeText: "2026-03-03 19:10",
                isFeatured: false,
                isUnread: false,
                hasPendingUnlockEvent: false,
                unlockMessage: nil
            ),
            MockBadgeRecord(
                id: "night-data-king",
                sortOrder: 30,
                category: .challenge,
                status: .acquired,
                level: .premium,
                accentStyle: .night,
                iconSystemName: "moon.stars.fill",
                title: BadgeCopy(
                    zhHans: "夜间流量王",
                    en: "Night Data King",
                    ar: "ملك البيانات الليلية"
                ),
                subtitle: BadgeCopy(
                    zhHans: "深夜挑战达成",
                    en: "Completed the late-night challenge",
                    ar: "أكملت تحدي الاستخدام الليلي"
                ),
                englishName: "Night Data King",
                arabicName: "ملك البيانات الليلية",
                requirementSummary: BadgeCopy(
                    zhHans: "30 天内完成 12 次 22:00 后的数据签到",
                    en: "Complete 12 data check-ins after 22:00 within 30 days",
                    ar: "أكمل 12 عملية تحقق بيانات بعد الساعة 22:00 خلال 30 يومًا"
                ),
                rewardSummary: BadgeCopy(
                    zhHans: "解锁夜间 2 倍积分与限定主题卡面",
                    en: "Unlock double night points and a limited profile theme",
                    ar: "افتح مضاعفة نقاط الليل وسمة ملف شخصية محدودة"
                ),
                badgeStoryPreview: BadgeCopy(
                    zhHans: "专属于夜猫子的高阶挑战勋章。",
                    en: "A premium challenge reserved for night owls.",
                    ar: "وسام تحدٍ مميز مخصص لعشاق الليل."
                ),
                statusHint: BadgeCopy(
                    zhHans: "已解锁，夜间双倍积分已生效。",
                    en: "Unlocked, and double night points are now active.",
                    ar: "تم الفتح، ونقاط الليل المضاعفة مفعلة الآن."
                ),
                lockHint: nil,
                progress: nil,
                requirementItems: [
                    MockRequirement(
                        id: "night-checkins",
                        title: BadgeCopy(
                            zhHans: "完成 12 次夜间数据签到",
                            en: "Complete 12 night-time data check-ins",
                            ar: "أكمل 12 عملية تحقق بيانات ليلية"
                        ),
                        isCompleted: true
                    ),
                    MockRequirement(
                        id: "single-line",
                        title: BadgeCopy(
                            zhHans: "保持同一号码参与挑战",
                            en: "Use the same line throughout the challenge",
                            ar: "استخدم نفس الخط طوال مدة التحدي"
                        ),
                        isCompleted: true
                    )
                ],
                rewardItems: [
                    MockReward(
                        id: "double-points",
                        title: BadgeCopy(
                            zhHans: "夜间双倍积分",
                            en: "Double points at night",
                            ar: "نقاط مضاعفة ليلًا"
                        ),
                        status: .active,
                        description: BadgeCopy(
                            zhHans: "22:00-06:00 的流量消耗按 2 倍积分累计。",
                            en: "Usage between 22:00 and 06:00 earns points at a 2x rate.",
                            ar: "يُحتسب الاستخدام بين 22:00 و06:00 بمعدل نقاط مضاعف."
                        )
                    ),
                    MockReward(
                        id: "night-theme",
                        title: BadgeCopy(
                            zhHans: "限定夜幕主题",
                            en: "Exclusive midnight theme",
                            ar: "سمة منتصف الليل الحصرية"
                        ),
                        status: .active,
                        description: BadgeCopy(
                            zhHans: "已同步到个人中心头像与徽章展示卡面。",
                            en: "Applied to your Me profile avatar and badge hero card.",
                            ar: "تم تطبيقها على صورة الملف الشخصي وبطاقة الوسام الرئيسية."
                        )
                    )
                ],
                badgeStory: BadgeCopy(
                    zhHans: "夜间流量王徽章来源于夜间活跃挑战，系统会追踪你在深夜时段的稳定访问行为，并为高频用户提供加速成长权益。",
                    en: "Night Data King comes from the late-night usage challenge, rewarding members who stay consistently active during off-peak hours.",
                    ar: "ينبع وسام ملك البيانات الليلية من تحدي الاستخدام الليلي، ويكافئ الأعضاء الذين يحافظون على نشاط ثابت خارج أوقات الذروة."
                ),
                validityText: BadgeCopy(
                    zhHans: "有效期至 2026-12-31 23:59",
                    en: "Valid until 2026-12-31 23:59",
                    ar: "صالح حتى 2026-12-31 23:59"
                ),
                triggerText: BadgeCopy(
                    zhHans: "满足挑战条件后，系统实时发放并推送解锁弹窗。",
                    en: "Granted in real time once the challenge is completed, followed by an unlock prompt.",
                    ar: "يُمنح فورًا عند اكتمال التحدي مع إظهار نافذة فتح الوسام."
                ),
                history: [
                    MockHistory(
                        id: "challenge-complete",
                        title: BadgeCopy(
                            zhHans: "夜间挑战完成",
                            en: "Night challenge completed",
                            ar: "اكتمل التحدي الليلي"
                        ),
                        subtitle: BadgeCopy(
                            zhHans: "你已完成第 12 次夜间签到。",
                            en: "You completed your 12th night-time check-in.",
                            ar: "أكملت عملية التحقق الليلية الثانية عشرة."
                        ),
                        timestampText: "2026-03-21 22:10"
                    ),
                    MockHistory(
                        id: "prompt-created",
                        title: BadgeCopy(
                            zhHans: "解锁提示已生成",
                            en: "Unlock prompt generated",
                            ar: "تم إنشاء إشعار الفتح"
                        ),
                        subtitle: BadgeCopy(
                            zhHans: "等待你查看徽章详情并确认权益。",
                            en: "Waiting for you to open the badge detail and confirm benefits.",
                            ar: "في انتظار فتح تفاصيل الوسام وتأكيد المزايا."
                        ),
                        timestampText: "2026-03-21 22:11"
                    )
                ],
                acquisitionTimeText: "2026-03-21 22:10",
                isFeatured: true,
                isUnread: true,
                hasPendingUnlockEvent: true,
                unlockMessage: BadgeCopy(
                    zhHans: "你已解锁“夜间流量王”徽章，夜间双倍积分现已生效。",
                    en: "You've unlocked Night Data King. Double night points are now active.",
                    ar: "لقد فتحت وسام ملك البيانات الليلية. نقاط الليل المضاعفة مفعلة الآن."
                )
            ),
            MockBadgeRecord(
                id: "uae-national-day",
                sortOrder: 40,
                category: .event,
                status: .acquired,
                level: .premium,
                accentStyle: .sunrise,
                iconSystemName: "flag.2.crossed.fill",
                title: BadgeCopy(
                    zhHans: "国庆限定",
                    en: "National Day Exclusive",
                    ar: "وسام اليوم الوطني"
                ),
                subtitle: BadgeCopy(
                    zhHans: "节日活动专属纪念徽章",
                    en: "Limited commemorative campaign badge",
                    ar: "وسام تذكاري محدود لحملة اليوم الوطني"
                ),
                englishName: "National Day Exclusive",
                arabicName: "وسام اليوم الوطني",
                requirementSummary: BadgeCopy(
                    zhHans: "参与国庆活动并完成分享任务",
                    en: "Join the National Day campaign and complete the sharing task",
                    ar: "شارك في حملة اليوم الوطني وأكمل مهمة المشاركة"
                ),
                rewardSummary: BadgeCopy(
                    zhHans: "获得节日抽奖资格与专属封面",
                    en: "Receive raffle access and an exclusive cover style",
                    ar: "احصل على دخول السحب وتصميم غلاف حصري"
                ),
                badgeStoryPreview: BadgeCopy(
                    zhHans: "面向节日活动参与者的限定收藏。",
                    en: "A collectible reserved for seasonal campaign participants.",
                    ar: "مقتنى مخصص للمشاركين في الحملات الموسمية."
                ),
                statusHint: BadgeCopy(
                    zhHans: "活动权益已解锁，可在节日专区查看。",
                    en: "Campaign benefits are unlocked and available in the seasonal hub.",
                    ar: "تم فتح مزايا الحملة وهي متاحة في مساحة الموسم."
                ),
                lockHint: nil,
                progress: nil,
                requirementItems: [
                    MockRequirement(
                        id: "holiday-campaign",
                        title: BadgeCopy(
                            zhHans: "进入国庆活动页并完成报名",
                            en: "Open the National Day event page and complete registration",
                            ar: "افتح صفحة فعالية اليوم الوطني وأكمل التسجيل"
                        ),
                        isCompleted: true
                    ),
                    MockRequirement(
                        id: "share-task",
                        title: BadgeCopy(
                            zhHans: "完成 1 次活动分享",
                            en: "Complete one campaign share task",
                            ar: "أكمل مهمة مشاركة واحدة للحملة"
                        ),
                        isCompleted: true
                    )
                ],
                rewardItems: [
                    MockReward(
                        id: "raffle",
                        title: BadgeCopy(
                            zhHans: "节日抽奖资格",
                            en: "Holiday raffle access",
                            ar: "إمكانية دخول السحب الموسمي"
                        ),
                        status: .active,
                        description: BadgeCopy(
                            zhHans: "活动结束前可参与 1 次节日抽奖。",
                            en: "You can enter one holiday raffle before the campaign ends.",
                            ar: "يمكنك الدخول في سحب موسمي واحد قبل انتهاء الحملة."
                        )
                    )
                ],
                badgeStory: BadgeCopy(
                    zhHans: "国庆限定徽章属于品牌活动纪念系列，强调参与感和节日仪式感，适合在个人中心展示节日成就。",
                    en: "National Day Exclusive belongs to the commemorative brand-event collection and highlights festive participation in your profile.",
                    ar: "ينتمي وسام اليوم الوطني إلى مجموعة الفعاليات التذكارية للعلامة ويبرز مشاركتك الاحتفالية داخل ملفك الشخصي."
                ),
                validityText: BadgeCopy(
                    zhHans: "纪念徽章长期保留，活动权益至 2026-04-15 23:59",
                    en: "The badge remains, while campaign benefits stay active until 2026-04-15 23:59",
                    ar: "يبقى الوسام محفوظًا بينما تستمر المزايا حتى 2026-04-15 23:59"
                ),
                triggerText: BadgeCopy(
                    zhHans: "活动任务完成后即时发放。",
                    en: "Granted instantly after the campaign task is completed.",
                    ar: "يُمنح فورًا بعد إكمال مهمة الحملة."
                ),
                history: [
                    MockHistory(
                        id: "campaign-joined",
                        title: BadgeCopy(
                            zhHans: "节日活动已完成",
                            en: "Campaign completed",
                            ar: "تم إكمال الحملة"
                        ),
                        subtitle: BadgeCopy(
                            zhHans: "你的分享任务已通过校验。",
                            en: "Your sharing task passed verification.",
                            ar: "تم التحقق من مهمة المشاركة الخاصة بك."
                        ),
                        timestampText: "2026-03-18 15:05"
                    )
                ],
                acquisitionTimeText: "2026-03-18 15:05",
                isFeatured: true,
                isUnread: false,
                hasPendingUnlockEvent: false,
                unlockMessage: nil
            ),
            MockBadgeRecord(
                id: "ramadan-exclusive",
                sortOrder: 50,
                category: .event,
                status: .acquired,
                level: .premium,
                accentStyle: .aurora,
                iconSystemName: "gift.fill",
                title: BadgeCopy(
                    zhHans: "斋月限定",
                    en: "Ramadan Exclusive",
                    ar: "وسام رمضان الحصري"
                ),
                subtitle: BadgeCopy(
                    zhHans: "夜间福利专区入场凭证",
                    en: "Entry pass to the Ramadan night-benefit lane",
                    ar: "تصريح دخول إلى مسار مزايا رمضان الليلي"
                ),
                englishName: "Ramadan Exclusive",
                arabicName: "وسام رمضان الحصري",
                requirementSummary: BadgeCopy(
                    zhHans: "参与斋月专题活动并连续 5 天签到",
                    en: "Join the Ramadan campaign and check in for five consecutive days",
                    ar: "انضم إلى حملة رمضان وسجل حضورك لخمسة أيام متتالية"
                ),
                rewardSummary: BadgeCopy(
                    zhHans: "解锁斋月夜场福利与优先客服入口",
                    en: "Unlock Ramadan night offers and priority support access",
                    ar: "افتح عروض رمضان الليلية ومدخل الدعم ذي الأولوية"
                ),
                badgeStoryPreview: BadgeCopy(
                    zhHans: "节庆限定系列中的高关注度徽章。",
                    en: "A high-visibility collectible from the seasonal badge series.",
                    ar: "وسام بارز ضمن سلسلة الأوسمة الموسمية."
                ),
                statusHint: BadgeCopy(
                    zhHans: "已获得，节庆权益窗口已打开。",
                    en: "Acquired, and the seasonal benefit lane is now open.",
                    ar: "تم الحصول عليه، وتم فتح مسار المزايا الموسمية."
                ),
                lockHint: nil,
                progress: nil,
                requirementItems: [
                    MockRequirement(
                        id: "seasonal-checkin",
                        title: BadgeCopy(
                            zhHans: "连续 5 天完成斋月签到",
                            en: "Check in for five consecutive Ramadan days",
                            ar: "سجل حضورك لخمسة أيام رمضانية متتالية"
                        ),
                        isCompleted: true
                    )
                ],
                rewardItems: [
                    MockReward(
                        id: "night-offer",
                        title: BadgeCopy(
                            zhHans: "斋月夜场福利",
                            en: "Ramadan night offers",
                            ar: "عروض رمضان الليلية"
                        ),
                        status: .active,
                        description: BadgeCopy(
                            zhHans: "夜间专享包与客服快速通道已生效。",
                            en: "Night-only bundles and fast-lane support are active now.",
                            ar: "الحزم الليلية ومسار الدعم السريع مفعّلان الآن."
                        )
                    )
                ],
                badgeStory: BadgeCopy(
                    zhHans: "斋月限定徽章代表你已加入节庆特别活动周期，系统将根据活动规则同步福利资格和专属入口。",
                    en: "Ramadan Exclusive confirms your participation in the seasonal loyalty cycle and syncs access to night-time offers and support lanes.",
                    ar: "يؤكد وسام رمضان الحصري مشاركتك في دورة الولاء الموسمية ويزامن وصولك إلى العروض الليلية ومسارات الدعم."
                ),
                validityText: BadgeCopy(
                    zhHans: "权益有效期至 2026-04-10 23:59",
                    en: "Benefits remain active until 2026-04-10 23:59",
                    ar: "تظل المزايا مفعلة حتى 2026-04-10 23:59"
                ),
                triggerText: BadgeCopy(
                    zhHans: "专题活动签到任务每日校验，满足条件后次日 00:05 发放。",
                    en: "The seasonal check-in job runs daily and grants the badge at 00:05 the next day.",
                    ar: "تتحقق مهمة الحضور الموسمي يوميًا ويُمنح الوسام عند 00:05 في اليوم التالي."
                ),
                history: [
                    MockHistory(
                        id: "seasonal-issued",
                        title: BadgeCopy(
                            zhHans: "徽章已发放",
                            en: "Badge granted",
                            ar: "تم منح الوسام"
                        ),
                        subtitle: BadgeCopy(
                            zhHans: "系统确认你已完成连续签到。",
                            en: "The system confirmed your consecutive check-ins.",
                            ar: "أكد النظام عمليات الحضور المتتالية الخاصة بك."
                        ),
                        timestampText: "2026-03-24 00:05"
                    )
                ],
                acquisitionTimeText: "2026-03-24 00:05",
                isFeatured: true,
                isUnread: true,
                hasPendingUnlockEvent: false,
                unlockMessage: nil
            ),
            MockBadgeRecord(
                id: "legends-ultimate",
                sortOrder: 60,
                category: .ultimate,
                status: .locked,
                level: .ultimate,
                accentStyle: .graphite,
                iconSystemName: "crown.fill",
                title: BadgeCopy(
                    zhHans: "传奇终章",
                    en: "Legends Ultimate",
                    ar: "أسطورة القمة"
                ),
                subtitle: BadgeCopy(
                    zhHans: "终极深夜挑战徽章",
                    en: "The final-tier late-night challenge badge",
                    ar: "الوسام النهائي لتحدي الليل"
                ),
                englishName: "Legends Ultimate",
                arabicName: "أسطورة القمة",
                requirementSummary: BadgeCopy(
                    zhHans: "在 45 天内完成 12 次深夜签到并保持 95% 到达率",
                    en: "Complete 12 late-night check-ins in 45 days with a 95% completion rate",
                    ar: "أكمل 12 عملية تحقق ليلية خلال 45 يومًا مع معدل إنجاز 95%"
                ),
                rewardSummary: BadgeCopy(
                    zhHans: "解锁终极身份边框、专属客服与年度抽奖资格",
                    en: "Unlock the ultimate profile frame, concierge support, and annual raffle access",
                    ar: "افتح إطار الهوية النهائي والدعم المخصص وإمكانية السحب السنوي"
                ),
                badgeStoryPreview: BadgeCopy(
                    zhHans: "这是夜间挑战线的终极目标。",
                    en: "This is the final objective in the night challenge path.",
                    ar: "هذا هو الهدف النهائي في مسار تحدي الليل."
                ),
                statusHint: BadgeCopy(
                    zhHans: "锁定中，请继续完成挑战。",
                    en: "Locked. Keep progressing through the challenge.",
                    ar: "مقفل. واصل التقدم في التحدي."
                ),
                lockHint: BadgeCopy(
                    zhHans: "还差 3 次深夜签到即可解锁。",
                    en: "Three more late-night check-ins to unlock.",
                    ar: "تبقى ثلاث عمليات تحقق ليلية لفتح الوسام."
                ),
                progress: MockProgress(
                    currentValue: 9,
                    targetValue: 12,
                    summary: BadgeCopy(
                        zhHans: "当前进度 9 / 12 次深夜签到",
                        en: "Current progress 9 / 12 night check-ins",
                        ar: "التقدم الحالي 9 / 12 من عمليات التحقق الليلية"
                    )
                ),
                requirementItems: [
                    MockRequirement(
                        id: "night-12",
                        title: BadgeCopy(
                            zhHans: "完成 12 次深夜签到",
                            en: "Complete 12 late-night check-ins",
                            ar: "أكمل 12 عملية تحقق ليلية"
                        ),
                        isCompleted: false
                    ),
                    MockRequirement(
                        id: "attendance-rate",
                        title: BadgeCopy(
                            zhHans: "挑战期间到达率不低于 95%",
                            en: "Maintain at least a 95% completion rate",
                            ar: "حافظ على معدل إنجاز لا يقل عن 95%"
                        ),
                        isCompleted: true
                    )
                ],
                rewardItems: [
                    MockReward(
                        id: "ultimate-frame",
                        title: BadgeCopy(
                            zhHans: "终极身份边框",
                            en: "Ultimate identity frame",
                            ar: "إطار الهوية النهائي"
                        ),
                        status: .upcoming,
                        description: BadgeCopy(
                            zhHans: "解锁后会自动应用到个人头像和徽章详情头图。",
                            en: "Automatically applied to your profile avatar and badge hero after unlock.",
                            ar: "يُطبق تلقائيًا على صورة الملف الشخصي وبطاقة الوسام بعد الفتح."
                        )
                    ),
                    MockReward(
                        id: "annual-raffle",
                        title: BadgeCopy(
                            zhHans: "年度抽奖资格",
                            en: "Annual raffle entry",
                            ar: "إمكانية الدخول في السحب السنوي"
                        ),
                        status: .upcoming,
                        description: BadgeCopy(
                            zhHans: "完成挑战后生效，年度活动开放时自动入场。",
                            en: "Enabled after unlock and auto-enrolled when the annual event opens.",
                            ar: "تُفعل بعد الفتح ويتم تسجيلك تلقائيًا عند بدء الفعالية السنوية."
                        )
                    )
                ],
                badgeStory: BadgeCopy(
                    zhHans: "传奇终章是夜间挑战系列中的终极徽章，专为长期保持稳定深夜活跃度的高价值用户设计。",
                    en: "Legends Ultimate is the endgame badge of the late-night series, designed for members with sustained, high-value off-peak activity.",
                    ar: "يمثل أسطورة القمة وسام النهاية في سلسلة التحديات الليلية، وهو مخصص للأعضاء ذوي النشاط المرتفع والمستمر خارج أوقات الذروة."
                ),
                validityText: BadgeCopy(
                    zhHans: "解锁后有效期 365 天",
                    en: "Valid for 365 days after unlock",
                    ar: "صالح لمدة 365 يومًا بعد الفتح"
                ),
                triggerText: BadgeCopy(
                    zhHans: "挑战条件实时累计，系统在目标达成后立即授予。",
                    en: "Progress accumulates in real time and the badge is granted immediately upon completion.",
                    ar: "يتراكم التقدم في الوقت الحقيقي ويُمنح الوسام فور اكتمال المتطلبات."
                ),
                history: [
                    MockHistory(
                        id: "progress-updated",
                        title: BadgeCopy(
                            zhHans: "挑战进度已更新",
                            en: "Challenge progress updated",
                            ar: "تم تحديث تقدم التحدي"
                        ),
                        subtitle: BadgeCopy(
                            zhHans: "昨晚的深夜签到已成功计入。",
                            en: "Last night's qualifying check-in has been counted.",
                            ar: "تم احتساب عملية التحقق المؤهلة لليلة الماضية."
                        ),
                        timestampText: "2026-03-24 23:20"
                    )
                ],
                acquisitionTimeText: nil,
                isFeatured: true,
                isUnread: false,
                hasPendingUnlockEvent: false,
                unlockMessage: nil
            ),
            MockBadgeRecord(
                id: "weekend-recharge-pro",
                sortOrder: 70,
                category: .daily,
                status: .locked,
                level: .base,
                accentStyle: .sunrise,
                iconSystemName: "bolt.badge.clock.fill",
                title: BadgeCopy(
                    zhHans: "周末充值达人",
                    en: "Weekend Recharge Pro",
                    ar: "خبير الشحن في عطلة نهاية الأسبوع"
                ),
                subtitle: BadgeCopy(
                    zhHans: "新手成长线任务徽章",
                    en: "Starter-path growth badge",
                    ar: "وسام نمو ضمن مسار المبتدئين"
                ),
                englishName: "Weekend Recharge Pro",
                arabicName: "خبير الشحن في عطلة نهاية الأسبوع",
                requirementSummary: BadgeCopy(
                    zhHans: "连续 3 个周末完成指定金额充值",
                    en: "Recharge the required amount over three consecutive weekends",
                    ar: "أعد الشحن بالمبلغ المطلوب خلال ثلاثة عطلات نهاية أسبوع متتالية"
                ),
                rewardSummary: BadgeCopy(
                    zhHans: "解锁周末充值返券与成长积分",
                    en: "Unlock weekend recharge vouchers and growth points",
                    ar: "افتح قسائم الشحن الأسبوعية ونقاط النمو"
                ),
                badgeStoryPreview: BadgeCopy(
                    zhHans: "适合新用户快速完成成长任务。",
                    en: "A fast-track growth badge for new members.",
                    ar: "وسام نمو سريع مناسب للأعضاء الجدد."
                ),
                statusHint: BadgeCopy(
                    zhHans: "尚未解锁，继续完成周末充值任务。",
                    en: "Not unlocked yet. Continue your weekend recharge streak.",
                    ar: "لم يُفتح بعد. واصل سلسلة الشحن في عطلة نهاية الأسبوع."
                ),
                lockHint: BadgeCopy(
                    zhHans: "再完成 2 次周末充值即可解锁。",
                    en: "Two more weekend recharges to unlock.",
                    ar: "تبقى عمليتا شحن في عطلة نهاية الأسبوع لفتح الوسام."
                ),
                progress: MockProgress(
                    currentValue: 1,
                    targetValue: 3,
                    summary: BadgeCopy(
                        zhHans: "当前进度 1 / 3 次周末充值",
                        en: "Current progress 1 / 3 weekend recharges",
                        ar: "التقدم الحالي 1 / 3 من عمليات الشحن الأسبوعية"
                    )
                ),
                requirementItems: [
                    MockRequirement(
                        id: "weekend-recharge",
                        title: BadgeCopy(
                            zhHans: "连续 3 个周末完成指定金额充值",
                            en: "Recharge over three consecutive weekends",
                            ar: "أعد الشحن خلال ثلاثة عطلات نهاية أسبوع متتالية"
                        ),
                        isCompleted: false
                    )
                ],
                rewardItems: [
                    MockReward(
                        id: "voucher",
                        title: BadgeCopy(
                            zhHans: "周末充值返券",
                            en: "Weekend recharge voucher",
                            ar: "قسيمة شحن لعطلة نهاية الأسبوع"
                        ),
                        status: .upcoming,
                        description: BadgeCopy(
                            zhHans: "解锁后每周末可领取一张返券。",
                            en: "Claim one cashback voucher each weekend after unlock.",
                            ar: "يمكنك الحصول على قسيمة استرداد كل عطلة نهاية أسبوع بعد الفتح."
                        )
                    )
                ],
                badgeStory: BadgeCopy(
                    zhHans: "周末充值达人帮助新用户建立稳定的充值习惯，是成长徽章中的入门挑战之一。",
                    en: "Weekend Recharge Pro helps new members build a steady recharge habit and serves as one of the first growth challenges.",
                    ar: "يساعد وسام خبير الشحن الأسبوعي الأعضاء الجدد على بناء عادة شحن منتظمة ويعد من أول تحديات النمو."
                ),
                validityText: BadgeCopy(
                    zhHans: "解锁后连续 90 天有效",
                    en: "Valid for 90 days after unlock",
                    ar: "صالح لمدة 90 يومًا بعد الفتح"
                ),
                triggerText: BadgeCopy(
                    zhHans: "周末充值交易入账后实时累计。",
                    en: "Progress updates in real time after the weekend recharge is posted.",
                    ar: "يتم تحديث التقدم فور تسجيل عملية الشحن الأسبوعية."
                ),
                history: [
                    MockHistory(
                        id: "first-weekend",
                        title: BadgeCopy(
                            zhHans: "首个周末任务完成",
                            en: "First weekend completed",
                            ar: "تم إكمال أول عطلة نهاية أسبوع"
                        ),
                        subtitle: BadgeCopy(
                            zhHans: "本周充值已计入成长任务。",
                            en: "This week's recharge has been added to your growth task.",
                            ar: "تمت إضافة شحن هذا الأسبوع إلى مهمة النمو الخاصة بك."
                        ),
                        timestampText: "2026-03-22 11:40"
                    )
                ],
                acquisitionTimeText: nil,
                isFeatured: false,
                isUnread: false,
                hasPendingUnlockEvent: false,
                unlockMessage: nil
            ),
            MockBadgeRecord(
                id: "cycle-explorer",
                sortOrder: 80,
                category: .cycle,
                status: .expired,
                level: .advanced,
                accentStyle: .ocean,
                iconSystemName: "bicycle.circle.fill",
                title: BadgeCopy(
                    zhHans: "骑行探索者",
                    en: "Cycle Explorer",
                    ar: "مستكشف الدراجات"
                ),
                subtitle: BadgeCopy(
                    zhHans: "城市漫游活动联名徽章",
                    en: "City roaming co-branded activity badge",
                    ar: "وسام فعالية التجوال في المدينة"
                ),
                englishName: "Cycle Explorer",
                arabicName: "مستكشف الدراجات",
                requirementSummary: BadgeCopy(
                    zhHans: "参与城市骑行活动并完成签到",
                    en: "Join the city cycling campaign and complete the event check-in",
                    ar: "شارك في حملة ركوب الدراجات وأكمل تسجيل الحضور"
                ),
                rewardSummary: BadgeCopy(
                    zhHans: "已结束，历史权益仅保留展示记录",
                    en: "Ended. Benefit history is preserved for reference only",
                    ar: "انتهت الصلاحية. تم الاحتفاظ بسجل المزايا للعرض فقط"
                ),
                badgeStoryPreview: BadgeCopy(
                    zhHans: "活动结束后保留为历史成就。",
                    en: "Preserved as a historical achievement after the event ended.",
                    ar: "يُحتفظ به كإنجاز تاريخي بعد انتهاء الفعالية."
                ),
                statusHint: BadgeCopy(
                    zhHans: "已过期，当前不再提供活动权益。",
                    en: "Expired, and campaign benefits are no longer active.",
                    ar: "منتهي الصلاحية ولم تعد مزايا الحملة نشطة."
                ),
                lockHint: nil,
                progress: nil,
                requirementItems: [
                    MockRequirement(
                        id: "city-ride",
                        title: BadgeCopy(
                            zhHans: "参加城市骑行并完成签到",
                            en: "Attend the city ride and finish the event check-in",
                            ar: "شارك في جولة المدينة وأكمل تسجيل الحضور"
                        ),
                        isCompleted: true
                    )
                ],
                rewardItems: [
                    MockReward(
                        id: "coupon",
                        title: BadgeCopy(
                            zhHans: "活动联名优惠券",
                            en: "Co-branded event coupon",
                            ar: "قسيمة الفعالية المشتركة"
                        ),
                        status: .expired,
                        description: BadgeCopy(
                            zhHans: "权益已于活动结束时失效。",
                            en: "The benefit expired when the campaign ended.",
                            ar: "انتهت صلاحية الميزة مع انتهاء الحملة."
                        )
                    )
                ],
                badgeStory: BadgeCopy(
                    zhHans: "骑行探索者属于一次性活动徽章，虽然权益已经结束，但仍会保留在你的徽章历史中作为纪念。",
                    en: "Cycle Explorer is a one-time campaign badge. Even though its benefits have ended, it remains in your history as a keepsake.",
                    ar: "يُعد مستكشف الدراجات وسام حملة لمرة واحدة. ورغم انتهاء مزاياه، فإنه يبقى في سجلك كتذكار."
                ),
                validityText: BadgeCopy(
                    zhHans: "已于 2026-02-28 23:59 过期",
                    en: "Expired on 2026-02-28 23:59",
                    ar: "انتهت صلاحيته في 2026-02-28 23:59"
                ),
                triggerText: BadgeCopy(
                    zhHans: "活动签到数据回传后自动发放。",
                    en: "Granted automatically after the campaign attendance feed is received.",
                    ar: "يُمنح تلقائيًا بعد استلام بيانات حضور الحملة."
                ),
                history: [
                    MockHistory(
                        id: "event-completed",
                        title: BadgeCopy(
                            zhHans: "活动已完成",
                            en: "Campaign completed",
                            ar: "اكتملت الحملة"
                        ),
                        subtitle: BadgeCopy(
                            zhHans: "你的联名骑行签到已同步。",
                            en: "Your co-branded cycling event check-in was synced.",
                            ar: "تمت مزامنة تسجيل حضور فعالية ركوب الدراجات المشتركة."
                        ),
                        timestampText: "2025-12-15 08:00"
                    ),
                    MockHistory(
                        id: "benefit-expired",
                        title: BadgeCopy(
                            zhHans: "权益已过期",
                            en: "Benefit expired",
                            ar: "انتهت صلاحية الميزة"
                        ),
                        subtitle: BadgeCopy(
                            zhHans: "活动结束后优惠券自动失效。",
                            en: "The coupon expired automatically once the campaign ended.",
                            ar: "انتهت صلاحية القسيمة تلقائيًا بعد انتهاء الحملة."
                        ),
                        timestampText: "2026-02-28 23:59"
                    )
                ],
                acquisitionTimeText: "2025-12-15 08:00",
                isFeatured: false,
                isUnread: false,
                hasPendingUnlockEvent: false,
                unlockMessage: nil
            )
        ]
    }
}
