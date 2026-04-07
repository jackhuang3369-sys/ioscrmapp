import Foundation
import SwiftUI

@MainActor
final class AIChatViewModel: ObservableObject {
    @Published var messages: [AIChatMessage] = []
    @Published var draft = ""
    @Published var isSending = false
    @Published var confirmResetPresented = false
    @Published var currentStep: AIChatViewStep = .home
    @Published var selectedOffer: AIChatOffer?
    @Published var offers: [AIChatOffer] = []

    let language: AppLanguage
    let title: String
    let subtitle: String
    let suggestedPrompts: [String]

    private let custSubInfo: CustSubInfo
    private let aiChatService: any AIChatServicing
    private var conversationID: String?
    private var activeAssistantMessageID: UUID?

    init(
        custSubInfo: CustSubInfo,
        language: AppLanguage,
        aiChatService: any AIChatServicing
    ) {
        self.custSubInfo = custSubInfo
        self.language = language
        self.aiChatService = aiChatService
        title = AIChatLocalizedCopy.title(for: language)
        subtitle = AIChatLocalizedCopy.subtitle(for: language)
        suggestedPrompts = AIChatLocalizedCopy.suggestedPrompts(for: language)
    }

    var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    var currentAssistantMessage: AIChatMessage? {
        if let activeAssistantMessageID {
            return messages.first(where: { $0.id == activeAssistantMessageID })
        }

        return messages.last(where: { $0.sender == .assistant && !$0.isLoading })
    }

    func directNavigationTarget(for text: String) -> AIChatNavigationTarget? {
        let normalized = normalizedIntentText(text)
        guard !normalized.isEmpty else {
            return nil
        }

        let balanceHints = [
            "how can i check my balance",
            "how do i check my balance",
            "check my balance",
            "view my balance",
            "my balance",
            "balance inquiry",
            "查看余额",
            "查余额",
            "余额",
            "الرصيد"
        ]

        if balanceHints.contains(where: { normalized.contains($0) }) {
            return .home
        }

        let rechargeHints = [
            "how do i recharge my account",
            "how can i recharge my account",
            "recharge my account",
            "recharge account",
            "top up my account",
            "top up",
            "充值",
            "充话费",
            "重新充值",
            "اعادة شحن",
            "شحن الحساب"
        ]

        if rechargeHints.contains(where: { normalized.contains($0) }) {
            return .recharge
        }

        return nil
    }

    func sendDraft() {
        let message = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else {
            return
        }

        draft = ""
        send(message)
    }

    func sendSuggestedPrompt(_ prompt: String) {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        send(prompt)
    }

    func requestNewChat() {
        guard !messages.isEmpty || !draft.isEmpty else {
            clearConversation()
            return
        }
        confirmResetPresented = true
    }

    func confirmNewChat() {
        clearConversation()
        confirmResetPresented = false
    }

    private func clearConversation() {
        conversationID = nil
        messages.removeAll()
        draft = ""
        isSending = false
        currentStep = .home
        selectedOffer = nil
        offers = []
        activeAssistantMessageID = nil
    }

    func selectOffer(_ offer: AIChatOffer) {
        selectedOffer = offer
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            currentStep = .offerDetails(offer)
        }
    }

    func processImmediately() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            currentStep = .success
        }
    }

    func goBack() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            switch currentStep {
            case .success:
                if let offer = selectedOffer {
                    currentStep = .offerDetails(offer)
                } else {
                    currentStep = .offersList
                }
            case .offerDetails:
                currentStep = .offersList
            case .answer:
                currentStep = .home
            case .offersList:
                currentStep = .home
            case .home:
                break
            }
        }
    }

    private func send(_ message: String) {
        guard !isSending else {
            return
        }

        let placeholderID = UUID()
        messages.append(
            AIChatMessage(
                sender: .user,
                text: message
            )
        )
        messages.append(
            AIChatMessage(
                id: placeholderID,
                sender: .assistant,
                text: "",
                isLoading: true
            )
        )
        isSending = true

        Task {
            do {
                let reply = try await aiChatService.sendMessage(
                    message,
                    conversationID: conversationID,
                    context: buildContext()
                )

                await MainActor.run {
                    conversationID = reply.conversationID ?? conversationID
                    applyReplyMetadata(reply)
                    updateAssistantPlaceholder(
                        placeholderID: placeholderID,
                        text: resolvedReplyText(reply),
                        htmlContent: reply.htmlContent,
                        richText: reply.richText,
                        thinkingText: reply.thinkingText,
                        recommendedOffers: reply.recommendedOffers,
                        actions: reply.actions
                    )
                }
            } catch let error as AIChatServiceError {
                await MainActor.run {
                    updateAssistantPlaceholder(
                        placeholderID: placeholderID,
                        text: AIChatLocalizedCopy.errorMessage(for: language, error: error),
                        htmlContent: nil,
                        richText: nil,
                        thinkingText: "",
                        recommendedOffers: [],
                        actions: []
                    )
                }
            } catch {
                await MainActor.run {
                    updateAssistantPlaceholder(
                        placeholderID: placeholderID,
                        text: AIChatLocalizedCopy.errorMessage(
                            for: language,
                            error: .network(underlying: error)
                        ),
                        htmlContent: nil,
                        richText: nil,
                        thinkingText: "",
                        recommendedOffers: [],
                        actions: []
                    )
                }
            }
        }
    }

    private func applyReplyMetadata(_ reply: AIChatReply) {
        guard !reply.recommendedOffers.isEmpty else {
            return
        }

        offers = reply.recommendedOffers

        if case .offerDetails(let currentSelection) = currentStep,
           let updatedSelection = reply.recommendedOffers.first(where: { $0.name == currentSelection.name })
        {
            selectedOffer = updatedSelection
            currentStep = .offerDetails(updatedSelection)
            return
        }

        if currentStep == .home || currentStep == .offersList {
            currentStep = .offersList
        }
    }

    private func updateAssistantPlaceholder(
        placeholderID: UUID,
        text: String,
        htmlContent: String?,
        richText: AttributedString?,
        thinkingText: String,
        recommendedOffers: [AIChatOffer],
        actions: [AIChatAction]
    ) {
        guard let index = messages.firstIndex(where: { $0.id == placeholderID }) else {
            isSending = false
            return
        }

        messages[index].text = text
        messages[index].htmlContent = htmlContent
        messages[index].richText = richText
        messages[index].thinkingText = thinkingText
        messages[index].recommendedOffers = recommendedOffers
        messages[index].actions = actions
        messages[index].isLoading = false
        activeAssistantMessageID = placeholderID
        offers = recommendedOffers
        selectedOffer = nil
        isSending = false

        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
            currentStep = recommendedOffers.isEmpty ? .answer : .offersList
        }
    }

    private func resolvedReplyText(_ reply: AIChatReply) -> String {
        if !reply.text.isEmpty {
            return reply.text
        }

        if reply.htmlContent != nil || reply.richText != nil || !reply.actions.isEmpty || !reply.recommendedOffers.isEmpty {
            return ""
        }

        return AIChatLocalizedCopy.emptyReply(for: language)
    }

    private func normalizedIntentText(_ text: String) -> String {
        let lowercased = text.lowercased()
        let sanitized = lowercased.replacingOccurrences(
            of: #"[^a-z0-9\u{4e00}-\u{9fff}\u{0600}-\u{06ff}]+"#,
            with: " ",
            options: .regularExpression
        )

        return sanitized
            .split(separator: " ")
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func buildContext() -> AIChatContext {
        let tokenStore = KeychainAuthTokenStore()
        let accessToken = tokenStore.loadTokens()?.currentAuthorizationToken() ?? ""
        let serviceNumber = custSubInfo.serviceNumber ?? custSubInfo.phoneNumber

        return AIChatContext(
            accessToken: accessToken,
            authorization: accessToken.isEmpty ? "" : "Bearer \(accessToken)",
            userID: custSubInfo.userID ?? "",
            serviceNumber: serviceNumber,
            subscriberKey: "",
            languageCode: language.rawValue,
            displayName: custSubInfo.displayName
        )
    }
}
