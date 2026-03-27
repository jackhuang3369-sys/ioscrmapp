import Foundation

@MainActor
final class BadgeCenterViewModel: ObservableObject {
    enum ScreenState {
        case idle
        case loading
        case loaded
        case failed(LocalizedTextValue)
    }

    @Published private(set) var screenState: ScreenState = .idle
    @Published private(set) var snapshot: BadgeCenterSnapshot?
    @Published private(set) var selectedBadge: BadgeDetail?
    @Published var selectedCategory: BadgeCategoryFilter = .all
    @Published var selectedStatus: BadgeStatusFilter = .all
    @Published var selectedLevel: BadgeLevelFilter = .all
    @Published var isAdvancedFiltersPresented = false
    @Published var alertMessage: LocalizedTextValue?
    @Published private(set) var isDetailLoading = false
    @Published private(set) var isUnlockActionInFlight = false

    private let session: CustSubInfo
    private let badgeCenterService: any BadgeCenterServicing
    private var selectedBadgeID: String?
    private var lastLoadedLanguage: AppLanguage?

    init(session: CustSubInfo, badgeCenterService: any BadgeCenterServicing) {
        self.session = session
        self.badgeCenterService = badgeCenterService
    }

    var visibleBadges: [BadgeSummary] {
        guard let snapshot else {
            return []
        }

        return snapshot.badges.filter { badge in
            let matchesCategory = selectedCategory == .all || badge.category == selectedCategory
            let matchesStatus: Bool
            switch selectedStatus {
            case .all:
                matchesStatus = true
            case .acquired:
                matchesStatus = badge.status == .acquired
            case .locked:
                matchesStatus = badge.status == .locked
            case .expired:
                matchesStatus = badge.status == .expired
            }

            let matchesLevel: Bool
            switch selectedLevel {
            case .all:
                matchesLevel = true
            case .base:
                matchesLevel = badge.level == .base
            case .advanced:
                matchesLevel = badge.level == .advanced
            case .premium:
                matchesLevel = badge.level == .premium
            case .ultimate:
                matchesLevel = badge.level == .ultimate
            }

            return matchesCategory && matchesStatus && matchesLevel
        }
    }

    var isShowingDetail: Bool {
        selectedBadgeID != nil
    }

    var pendingUnlockEvent: BadgeUnlockEvent? {
        snapshot?.pendingUnlockEvent
    }

    var unreadCount: Int {
        snapshot?.overview.unreadCount ?? 0
    }

    var hasAnyBadges: Bool {
        !(snapshot?.badges.isEmpty ?? true)
    }

    var isFilteredEmpty: Bool {
        hasAnyBadges && visibleBadges.isEmpty
    }

    var activeAdvancedFilterCount: Int {
        var count = 0
        if selectedLevel != .all {
            count += 1
        }
        if selectedCategory != .all {
            count += 1
        }
        return count
    }

    var hasAdvancedFiltersApplied: Bool {
        activeAdvancedFilterCount > 0
    }

    func statusBadgeCount(for status: BadgeStatusFilter) -> Int {
        guard let snapshot else {
            return 0
        }

        return snapshot.badges.filter { badge in
            let matchesCategory = selectedCategory == .all || badge.category == selectedCategory

            let matchesLevel: Bool
            switch selectedLevel {
            case .all:
                matchesLevel = true
            case .base:
                matchesLevel = badge.level == .base
            case .advanced:
                matchesLevel = badge.level == .advanced
            case .premium:
                matchesLevel = badge.level == .premium
            case .ultimate:
                matchesLevel = badge.level == .ultimate
            }

            let matchesStatus: Bool
            switch status {
            case .all:
                matchesStatus = true
            case .acquired:
                matchesStatus = badge.status == .acquired
            case .locked:
                matchesStatus = badge.status == .locked
            case .expired:
                matchesStatus = badge.status == .expired
            }

            return matchesCategory && matchesLevel && matchesStatus
        }.count
    }

    func toggleAdvancedFilters() {
        isAdvancedFiltersPresented.toggle()
    }

    func loadIfNeeded(language: AppLanguage) async {
        guard snapshot == nil else {
            await refreshForLanguageChangeIfNeeded(language: language)
            return
        }
        await reload(language: language)
    }

    func reload(language: AppLanguage) async {
        lastLoadedLanguage = language

        if snapshot == nil {
            screenState = .loading
        }

        do {
            let loadedSnapshot = try await badgeCenterService.fetchBadgeCenter(
                session: session,
                language: language
            )
            snapshot = loadedSnapshot
            screenState = .loaded

            if let selectedBadgeID {
                if let selectedBadgeSummary = loadedSnapshot.badges.first(where: { $0.id == selectedBadgeID }) {
                    let fetchedDetail = try await badgeCenterService.fetchBadgeDetail(
                        badgeID: selectedBadgeID,
                        session: session,
                        language: language
                    )
                    selectedBadge = detailByApplyingListArtwork(
                        fetchedDetail,
                        badgeSummary: selectedBadgeSummary
                    )
                } else {
                    selectedBadge = nil
                    self.selectedBadgeID = nil
                }
            }
        } catch {
            let errorText = (error as? BadgeCenterServiceError)?.textValue ?? .key("badgeCenter.error.load")

            if snapshot == nil {
                screenState = .failed(errorText)
            } else {
                screenState = .loaded
                alertMessage = errorText
            }
        }
    }

    func openBadge(_ badge: BadgeSummary, language: AppLanguage) async {
        let pendingUnlockEventID = snapshot?.pendingUnlockEvent?.badgeID == badge.id
            ? snapshot?.pendingUnlockEvent?.id
            : nil
        selectedBadgeID = badge.id
        isDetailLoading = true

        do {
            let fetchedDetail = try await badgeCenterService.fetchBadgeDetail(
                badgeID: badge.id,
                session: session,
                language: language
            )
            selectedBadge = detailByApplyingListArtwork(
                fetchedDetail,
                badgeSummary: badge
            )
        } catch {
            selectedBadgeID = nil
            selectedBadge = nil
            alertMessage = (error as? BadgeCenterServiceError)?.textValue ?? .key("badgeCenter.error.detail")
            isDetailLoading = false
            return
        }

        isDetailLoading = false

        if let pendingUnlockEventID {
            Task { [weak self, badgeID = badge.id, pendingUnlockEventID, language] in
                await self?.handleUnlockEventThenMarkBadgeAsReadIfNeeded(
                    eventID: pendingUnlockEventID,
                    badgeID: badgeID,
                    language: language
                )
            }
            return
        }

        guard
            selectedBadge?.status == .acquired,
            selectedBadge?.isUnread == true || badge.isUnread
        else {
            return
        }

        Task { [weak self, badgeID = badge.id, language] in
            await self?.markBadgeAsReadAndRefresh(for: badgeID, language: language)
        }
    }

    func dismissDetail() {
        selectedBadgeID = nil
        selectedBadge = nil
    }

    // Dismissing the popup only removes the popup entry. The badge card stays unread
    // until the user actually opens the badge detail from the popup or from the list.
    func handleUnlockLater(language: AppLanguage) async {
        guard let pendingUnlockEvent else {
            return
        }

        isUnlockActionInFlight = true

        do {
            try await badgeCenterService.markUnlockEventHandled(
                id: pendingUnlockEvent.id,
                source: .popupDismiss,
                session: session
            )
            try await refreshSnapshotAfterMutation(language: language)
        } catch {
            alertMessage = (error as? BadgeCenterServiceError)?.textValue ?? .key("badgeCenter.error.handleUnlock")
        }

        isUnlockActionInFlight = false
    }

    func handleUnlockViewNow(language: AppLanguage) async {
        guard
            let pendingUnlockEvent,
            let unlockBadge = snapshot?.badges.first(where: { $0.id == pendingUnlockEvent.badgeID })
        else {
            return
        }

        isUnlockActionInFlight = true

        do {
            try await badgeCenterService.markUnlockEventHandled(
                id: pendingUnlockEvent.id,
                source: .popupConfirm,
                session: session
            )
            try await refreshSnapshotAfterMutation(language: language)
            isUnlockActionInFlight = false
            await openBadge(unlockBadge, language: language)
        } catch {
            isUnlockActionInFlight = false
            alertMessage = (error as? BadgeCenterServiceError)?.textValue ?? .key("badgeCenter.error.handleUnlock")
        }
    }

    func clearAlert() {
        alertMessage = nil
    }

    func refreshForLanguageChangeIfNeeded(language: AppLanguage) async {
        guard lastLoadedLanguage != language else {
            return
        }
        await reload(language: language)
    }

    private func refreshSnapshotAfterMutation(language: AppLanguage) async throws {
        lastLoadedLanguage = language
        let refreshedSnapshot = try await badgeCenterService.fetchBadgeCenter(
            session: session,
            language: language
        )
        snapshot = refreshedSnapshot
        screenState = .loaded

        if let selectedBadgeID {
            guard let selectedBadgeSummary = refreshedSnapshot.badges.first(where: { $0.id == selectedBadgeID }) else {
                selectedBadge = nil
                self.selectedBadgeID = nil
                return
            }

            let fetchedDetail = try await badgeCenterService.fetchBadgeDetail(
                badgeID: selectedBadgeID,
                session: session,
                language: language
            )
            selectedBadge = detailByApplyingListArtwork(
                fetchedDetail,
                badgeSummary: selectedBadgeSummary
            )
        }
    }

    private func markBadgeAsReadAndRefresh(for badgeID: String, language: AppLanguage) async {
        do {
            try await badgeCenterService.markBadgeAsRead(id: badgeID, session: session)
            try await refreshSnapshotAfterMutation(language: language)
        } catch {
            // Do not block detail presentation when read reconciliation fails.
        }
    }

    // Entering detail from an unread unlock popup needs two independent mutations:
    // first close the popup queue item, then clear the badge unread indicator.
    private func handleUnlockEventThenMarkBadgeAsReadIfNeeded(
        eventID: String,
        badgeID: String,
        language: AppLanguage
    ) async {
        do {
            try await badgeCenterService.markUnlockEventHandled(
                id: eventID,
                source: .detailPage,
                session: session
            )
            try await refreshSnapshotAfterMutation(language: language)
        } catch {
            // Do not block detail presentation when popup reconciliation fails.
        }

        let stillUnread = selectedBadge?.isUnread == true
            || snapshot?.badges.first(where: { $0.id == badgeID })?.isUnread == true
        guard stillUnread else {
            return
        }

        await markBadgeAsReadAndRefresh(for: badgeID, language: language)
    }

    private func detailByApplyingListArtwork(
        _ detail: BadgeDetail,
        badgeSummary: BadgeSummary
    ) -> BadgeDetail {
        BadgeDetail(
            id: detail.id,
            category: detail.category,
            status: detail.status,
            level: detail.level,
            accentStyle: detail.accentStyle,
            iconSystemName: badgeSummary.iconSystemName,
            iconURL: badgeSummary.iconURL,
            iconHDURL: badgeSummary.iconHDURL,
            backgroundURL: detail.backgroundURL,
            title: detail.title,
            subtitle: detail.subtitle,
            englishName: detail.englishName,
            arabicName: detail.arabicName,
            requirementItems: detail.requirementItems,
            rewardItems: detail.rewardItems,
            acquisitionTimeText: detail.acquisitionTimeText,
            badgeStory: detail.badgeStory,
            statusHint: detail.statusHint,
            validityText: detail.validityText,
            triggerText: detail.triggerText,
            history: detail.history,
            progress: detail.progress,
            isUnread: detail.isUnread,
            isFeatured: detail.isFeatured
        )
    }
}
