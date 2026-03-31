import Foundation

@MainActor
final class AIChatViewModel: ObservableObject {
    @Published var messages: [AIChatMessage] = []
    @Published var draft = ""
    @Published var isSending = false
    @Published var confirmResetPresented = false

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
                        text: reply.text.isEmpty ? AIChatLocalizedCopy.emptyReply(for: language) : reply.text,
                        thinkingText: reply.thinkingText,
                        actions: reply.actions
                    )
                }
            } catch let error as AIChatServiceError {
                await MainActor.run {
                    updateAssistantPlaceholder(
                        placeholderID: placeholderID,
                        text: AIChatLocalizedCopy.errorMessage(for: language, error: error),
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
        thinkingText: String,
        actions: [AIChatAction]
    ) {
        guard let index = messages.firstIndex(where: { $0.id == placeholderID }) else {
            isSending = false
            return
        }

        messages[index].text = text
        messages[index].thinkingText = thinkingText
        messages[index].actions = actions
        messages[index].isLoading = false
        isSending = false
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
