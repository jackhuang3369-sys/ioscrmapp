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
    @Published var isBillingPresented = false
    @Published var isBadgeCenterPresented = false
    @Published var revealPassword = ""
    @Published var revealErrorMessage: LocalizedTextValue?
    @Published private(set) var isPhoneNumberRevealed = false
    @Published private(set) var isValidatingPassword = false

    private let custSubInfo: CustSubInfo
    private let meService: any MeServicing
    private var lastLoadedLanguage: AppLanguage?

    init(session: CustSubInfo, meService: any MeServicing) {
        custSubInfo = session
        self.meService = meService
    }

    var displayedPhoneNumber: String {
        switch screenState {
        case let .loaded(content):
            return isPhoneNumberRevealed ? content.profile.fullPhoneNumber : content.profile.maskedPhoneNumber
        case .idle, .loading, .failed:
            let fallbackPhone = AuthValidator.formattedPhone(custSubInfo.phoneNumber)
            return isPhoneNumberRevealed ? fallbackPhone : MePhoneNumberFormatter.masked(custSubInfo.phoneNumber)
        }
    }

    func loadIfNeeded(language: AppLanguage) async {
        guard case .idle = screenState else {
            if lastLoadedLanguage != language {
                await refresh(language: language)
            }
            return
        }
        await refresh(language: language)
    }

    func refresh(language: AppLanguage) async {
        lastLoadedLanguage = language
        screenState = .loading

        do {
            let content = try await meService.fetchMeContent(
                session: custSubInfo,
                language: language
            )
            screenState = .loaded(content)
        } catch {
            let errorText = (error as? MeServiceError)?.textValue ?? .key("me.error.subtitle")
            screenState = .failed(errorText)
        }
    }

    func handleAction(_ actionID: MeActionID, localizedTitle: String) {
        switch actionID {
        case .billing:
            isBillingPresented = true
        case .badges:
            isBadgeCenterPresented = true
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
                let isValid = try await meService.validateRevealPassword(revealPassword, session: custSubInfo)
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
