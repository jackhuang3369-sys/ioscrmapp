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
        setupMockOffers()
    }

    private func setupMockOffers() {
        offers = [
            AIChatOffer(name: "DataRoamingPrice (10 GB) KSA", price: "15.00", dataAmount: "10 GB", validity: "Monthly"),
            AIChatOffer(name: "DataRoamingPrice (20 GB) KSA", price: "35.00", dataAmount: "20 GB", validity: "Monthly"),
            AIChatOffer(name: "DataRoamingPrice (50 GB) KSA", price: "55.00", dataAmount: "50 GB", validity: "Monthly"),
            AIChatOffer(name: "DataRoamingPrice (100 GB) KSA", price: "75.00", dataAmount: "100 GB", validity: "Monthly"),
            AIChatOffer(name: "DataRoamingPrice (Unlimited) KSA", price: "120.00", dataAmount: "Unlimited", validity: "Monthly")
        ]
    }

    var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
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

        // 复刻 HTML 逻辑：点击推荐问题直接跳转列表
        if currentStep == .home {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                currentStep = .offersList
            }
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
                    updateAssistantPlaceholder(
                        placeholderID: placeholderID,
                        text: resolvedReplyText(reply),
                        htmlContent: reply.htmlContent,
                        richText: reply.richText,
                        thinkingText: reply.thinkingText,
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
                        actions: []
                    )
                }
            }
        }
    }

    private func updateAssistantPlaceholder(
        placeholderID: UUID,
        text: String,
        htmlContent: String?,
        richText: AttributedString?,
        thinkingText: String,
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
        messages[index].actions = actions
        messages[index].isLoading = false
        isSending = false
    }

    private func resolvedReplyText(_ reply: AIChatReply) -> String {
        if !reply.text.isEmpty {
            return reply.text
        }

        if reply.htmlContent != nil || reply.richText != nil || !reply.actions.isEmpty {
            return ""
        }

        return AIChatLocalizedCopy.emptyReply(for: language)
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
