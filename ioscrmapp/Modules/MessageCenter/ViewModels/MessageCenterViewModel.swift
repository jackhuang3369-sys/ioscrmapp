import Foundation

@MainActor
final class MessageCenterViewModel: ObservableObject {
    enum BatchAction: Equatable {
        case markRead
        case delete
    }

    @Published private(set) var screenState: MessageCenterScreenState = .idle
    @Published private(set) var messages: [MessageCenterMessage] = []
    @Published private(set) var selectedMessageID: String?
    @Published private(set) var selectedMessageIDs: Set<String> = []
    @Published private(set) var selectionMode = false
    @Published var banner: MessageCenterBanner?
    @Published private(set) var inFlightBatchAction: BatchAction?

    private let session: CustSubInfo
    private let notificationService: any NotificationServicing
    private var hasLoaded = false

    init(session: CustSubInfo, notificationService: any NotificationServicing) {
        self.session = session
        self.notificationService = notificationService
    }

    var unreadCount: Int {
        messages.reduce(into: 0) { partialResult, message in
            if !message.isRead {
                partialResult += 1
            }
        }
    }

    var selectedCount: Int {
        selectedMessageIDs.count
    }

    var selectedMessage: MessageCenterMessage? {
        guard let selectedMessageID else {
            return nil
        }
        return messages.first(where: { $0.id == selectedMessageID })
    }

    var allMessagesSelected: Bool {
        !messages.isEmpty && selectedMessageIDs.count == messages.count
    }

    var canBatchMarkRead: Bool {
        let selectedIDs = selectedMessageIDs
        return messages.contains(where: { selectedIDs.contains($0.id) && !$0.isRead })
    }

    func loadIfNeeded() async {
        guard !hasLoaded else {
            return
        }
        await loadMessages(showLoading: true)
    }

    func reload() async {
        await loadMessages(showLoading: messages.isEmpty)
    }

    func openMessage(_ message: MessageCenterMessage) {
        if selectionMode {
            toggleSelection(for: message.id)
            return
        }

        banner = nil
        selectedMessageID = message.id

        guard !message.isRead else {
            return
        }

        Task { [weak self] in
            await self?.markMessageReadIfNeeded(messageID: message.id)
        }
    }

    func closeDetail() {
        selectedMessageID = nil
    }

    func enterSelectionMode(with messageID: String) {
        selectedMessageID = nil
        selectionMode = true
        selectedMessageIDs = [messageID]
        banner = nil
    }

    func exitSelectionMode() {
        selectionMode = false
        selectedMessageIDs = []
    }

    func toggleSelection(for messageID: String) {
        if selectedMessageIDs.contains(messageID) {
            selectedMessageIDs.remove(messageID)
        } else {
            selectedMessageIDs.insert(messageID)
        }
    }

    func toggleSelectAll() {
        if allMessagesSelected {
            selectedMessageIDs = []
        } else {
            selectedMessageIDs = Set(messages.map(\.id))
        }
    }

    func deleteMessage(_ messageID: String) async {
        banner = nil

        do {
            try await notificationService.deleteMessage(messageID: messageID, session: session)
            removeMessages(with: [messageID])
        } catch {
            banner = MessageCenterBanner(
                message: .key("messageCenter.banner.deleteSingleFailed"),
                style: .error
            )
        }
    }

    func markSelectedMessagesRead() async {
        let messageIDs = Array(selectedMessageIDs)
        guard !messageIDs.isEmpty else {
            return
        }

        inFlightBatchAction = .markRead
        defer {
            inFlightBatchAction = nil
        }

        do {
            let result = try await notificationService.markMessagesRead(messageIDs: messageIDs, session: session)
            applyMarkReadResult(result)
        } catch {
            banner = MessageCenterBanner(
                message: .key("messageCenter.banner.batchReadFailed"),
                style: .error
            )
        }
    }

    func deleteSelectedMessages() async {
        let messageIDs = Array(selectedMessageIDs)
        guard !messageIDs.isEmpty else {
            return
        }

        inFlightBatchAction = .delete
        defer {
            inFlightBatchAction = nil
        }

        do {
            let result = try await notificationService.deleteMessages(messageIDs: messageIDs, session: session)
            applyDeleteResult(result)
        } catch {
            banner = MessageCenterBanner(
                message: .key("messageCenter.banner.batchDeleteFailed"),
                style: .error
            )
        }
    }

    private func loadMessages(showLoading: Bool) async {
        if showLoading {
            screenState = .loading
        }

        do {
            let fetchedMessages = try await notificationService.fetchMessages(session: session)
            hasLoaded = true
            messages = fetchedMessages.sorted {
                ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast)
            }
            reconcileTransientState()
            screenState = messages.isEmpty ? .empty : .loaded
        } catch let serviceError as MessageCenterServiceError {
            applyLoadFailure(serviceError)
        } catch {
            applyLoadFailure(.networkUnavailable)
        }
    }

    private func applyLoadFailure(_ error: MessageCenterServiceError) {
        if messages.isEmpty {
            screenState = .failed(error.textValue)
        } else {
            banner = MessageCenterBanner(message: error.textValue, style: .error)
        }
    }

    private func markMessageReadIfNeeded(messageID: String) async {
        guard messages.contains(where: { $0.id == messageID && !$0.isRead }) else {
            return
        }

        do {
            try await notificationService.markMessageRead(messageID: messageID, session: session)
            messages = messages.map { message in
                message.id == messageID ? message.markingRead() : message
            }
        } catch {
            banner = MessageCenterBanner(
                message: .key("messageCenter.banner.readSyncFailed"),
                style: .warning
            )
        }
    }

    private func applyMarkReadResult(_ result: MessageCenterBatchResult) {
        if !result.succeededMessageIDs.isEmpty {
            let succeededIDs = Set(result.succeededMessageIDs)
            messages = messages.map { message in
                succeededIDs.contains(message.id) ? message.markingRead() : message
            }
        }

        if result.failedMessageIDs.isEmpty {
            exitSelectionMode()
            return
        }

        selectedMessageIDs = Set(result.failedMessageIDs)
        banner = MessageCenterBanner(
            message: .key(
                "messageCenter.banner.batchReadPartial",
                arguments: [
                    "\(result.succeededMessageIDs.count)",
                    "\(result.failedMessageIDs.count)"
                ]
            ),
            style: .warning
        )
    }

    private func applyDeleteResult(_ result: MessageCenterBatchResult) {
        if !result.succeededMessageIDs.isEmpty {
            removeMessages(with: result.succeededMessageIDs)
        }

        if result.failedMessageIDs.isEmpty {
            exitSelectionMode()
            return
        }

        selectedMessageIDs = Set(result.failedMessageIDs)
        banner = MessageCenterBanner(
            message: .key(
                "messageCenter.banner.batchDeletePartial",
                arguments: [
                    "\(result.succeededMessageIDs.count)",
                    "\(result.failedMessageIDs.count)"
                ]
            ),
            style: .warning
        )
    }

    private func removeMessages(with messageIDs: [String]) {
        let removedIDs = Set(messageIDs)
        messages.removeAll(where: { removedIDs.contains($0.id) })

        if let selectedMessageID, removedIDs.contains(selectedMessageID) {
            self.selectedMessageID = nil
        }

        selectedMessageIDs.subtract(removedIDs)
        reconcileTransientState()
    }

    private func reconcileTransientState() {
        let availableIDs = Set(messages.map(\.id))
        selectedMessageIDs = selectedMessageIDs.intersection(availableIDs)

        if let selectedMessageID, !availableIDs.contains(selectedMessageID) {
            self.selectedMessageID = nil
        }

        if messages.isEmpty {
            selectionMode = false
            selectedMessageIDs = []
        }

        if screenState != .loading {
            screenState = messages.isEmpty ? .empty : .loaded
        }
    }
}
