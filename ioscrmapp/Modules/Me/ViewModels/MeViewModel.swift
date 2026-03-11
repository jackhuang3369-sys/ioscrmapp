import Foundation

@MainActor
final class MeViewModel: ObservableObject {
    enum ScreenState {
        case idle
        case loading
        case loaded(MeContent)
        case failed(String)
    }

    @Published private(set) var screenState: ScreenState = .idle
    @Published var placeholderMessage: String?
    @Published var isRevealSheetPresented = false
    @Published var revealPassword = ""
    @Published var revealErrorMessage: String?
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
            let localizedMessage = (error as? LocalizedError)?.errorDescription
            screenState = .failed(localizedMessage ?? "Unable to load your profile right now.")
        }
    }

    func handleAction(named title: String) {
        placeholderMessage = "\(title) is coming soon."
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
                        revealErrorMessage = MeServiceError.invalidPassword.errorDescription
                    }
                }
            } catch {
                await MainActor.run {
                    isValidatingPassword = false
                    revealErrorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to verify your password."
                }
            }
        }
    }
}
