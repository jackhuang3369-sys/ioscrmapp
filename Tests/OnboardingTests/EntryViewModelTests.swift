import Testing
@testable import du_App

@MainActor
@Test("EntryViewModel starts at welcome step")
func viewModelStartsAtWelcome() async throws {
    let store = OnboardingStateStore(suiteName: "test.vm.welcome")
    let viewModel = EntryViewModel(onboardingStateStore: store)
    #expect(viewModel.step == .welcome)
}

@MainActor
@Test("EntryViewModel transitions to eKYC on Get Started")
func viewModelTransitionsOnGetStarted() async throws {
    let store = OnboardingStateStore(suiteName: "test.vm.transition")
    let viewModel = EntryViewModel(onboardingStateStore: store)
    viewModel.handleGetStarted()
    #expect(viewModel.step == .ekycVerification)
}

@MainActor
@Test("EntryViewModel saves state when acquisition path selected")
func viewModelSavesStateOnAcquisitionSelection() async throws {
    let store = OnboardingStateStore(suiteName: "test.vm.acquisition")
    let viewModel = EntryViewModel(onboardingStateStore: store)
    viewModel.handleGetStarted()
    viewModel.completeEKYCVerification()
    viewModel.selectAcquisitionPath(.newNumber)
    let savedState = store.load()
    #expect(savedState?.entryIntent == .onboarding)
    #expect(savedState?.acquisitionPath == .newNumber)
}

@MainActor
@Test("EntryViewModel sets login intent on Sign in")
func viewModelSetsLoginIntentOnSignIn() async throws {
    let store = OnboardingStateStore(suiteName: "test.vm.login")
    let viewModel = EntryViewModel(onboardingStateStore: store)
    viewModel.handleSignIn()
    #expect(viewModel.entryIntent == .login)
    #expect(viewModel.shouldShowUAEPassLogin)
}
