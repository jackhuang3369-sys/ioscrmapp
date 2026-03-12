import Foundation

@MainActor
final class MeViewModel: ObservableObject {
    enum ScreenState {
        case idle
        case loading
        case loaded(MeContent)
        case failed(LocalizedTextValue)
    }

    @Published private(set) var screenState: ScreenState = .idle
    @Published var placeholderMessage: LocalizedTextValue?
    @Published var isRevealSheetPresented = false
    @Published var isLanguageSettingsPresented = false
    @Published var revealPassword = ""
    @Published var revealErrorMessage: LocalizedTextValue?
    @Published private(set) var isPhoneNumberRevealed = false
    @Published private(set) var isValidatingPassword = false

    private let session: UserSession
    private let meService: any MeServicing

    init(session: UserSession, meService: any MeServicing) {
        self.session = session
        self.meService = meService
    }

    var displayedPhoneNumber: String {
        switch screenState {
        case let .loaded(content):
            return isPhoneNumberRevealed ? content.profile.fullPhoneNumber : content.profile.maskedPhoneNumber
        case .idle, .loading, .failed:
            let fallbackPhone = AuthValidator.formattedPhone(session.phoneNumber)
            return isPhoneNumberRevealed ? fallbackPhone : MePhoneNumberFormatter.masked(session.phoneNumber)
        }
    }

    func loadIfNeeded() async {
        guard case .idle = screenState else {
            return
        }
        await refresh()
    }

    func refresh() async {
        screenState = .loading

        do {
            let content = try await meService.fetchMeContent(session: session)
            screenState = .loaded(content)
        } catch {
            let errorText = (error as? MeServiceError)?.textValue ?? .key("me.error.subtitle")
            screenState = .failed(errorText)
        }
    }

    func handleAction(_ actionID: MeActionID, localizedTitle: String) {
        switch actionID {
        case .changeLanguage:
            isLanguageSettingsPresented = true
        default:
            placeholderMessage = .key("common.placeholder.feature", arguments: [localizedTitle])
        }
    }

    func togglePhoneNumberVisibility() {
        if isPhoneNumberRevealed {
            isPhoneNumberRevealed = false
            return
        }

        revealPassword = ""
        revealErrorMessage = nil
        isRevealSheetPresented = true
    }

    func submitRevealPassword() {
        guard !isValidatingPassword else {
            return
        }

        revealErrorMessage = nil
        isValidatingPassword = true

        Task {
            do {
                let isValid = try await meService.validateRevealPassword(revealPassword, session: session)
                await MainActor.run {
                    isValidatingPassword = false
                    if isValid {
                        isPhoneNumberRevealed = true
                        isRevealSheetPresented = false
                        revealPassword = ""
                    } else {
                        revealErrorMessage = MeServiceError.invalidPassword.textValue
                    }
                }
            } catch {
                await MainActor.run {
                    isValidatingPassword = false
                    revealErrorMessage = (error as? MeServiceError)?.textValue ?? .key("me.reveal.verifyFailed")
                }
            }
        }
    }
}
