// ioscrmapp/ioscrmapp/Modules/Onboarding/ViewModels/EntryViewModel.swift
import Foundation

/// 入网入口流程的页面状态。
enum EntryStep: Equatable {
    case welcome
    case ekycVerification
    case personalization
    case acquisitionSplit
    case uaePassLogin
    case numberSelection
    case portInPlaceholder
    case planSelection(NumberSelection)
    // 套餐确认后进入结账支付页，携带结账摘要数据
    case checkout(CheckoutSummary)
}

/// 管理入网入口的流程状态和路由决策。
@MainActor
final class EntryViewModel: ObservableObject {
    @Published private(set) var step: EntryStep = .welcome
    @Published private(set) var entryIntent: EntryIntent?
    // 保存选号结果，用于从结账页返回套餐选择页时复原
    @Published private(set) var currentNumberSelection: NumberSelection?

    private let onboardingStateStore: OnboardingStateStore

    init(onboardingStateStore: OnboardingStateStore = OnboardingStateStore()) {
        self.onboardingStateStore = onboardingStateStore
    }

    /// Welcome 页展示设备可用性后，用户点击 Get Started 进入 eKYC。
    func handleGetStarted() {
        step = .ekycVerification
    }

    /// eKYC 通过后进入个性化偏好选择。
    func completeEKYCVerification() {
        step = .personalization
    }

    /// 用户点击 Sign in / Log in 后进入 UAE Pass 登录。
    func handleSignIn() {
        entryIntent = .login
        step = .uaePassLogin
        onboardingStateStore.save(EntryRoutingState.login())
    }

    /// 用户在个性化页底部选择入网路径后，保存路径并进入对应流程。
    func selectAcquisitionPath(_ path: AcquisitionPath) {
        entryIntent = .onboarding
        let state = EntryRoutingState.onboarding(path: path)
        onboardingStateStore.save(state)
        step = path == .newNumber ? .numberSelection : .portInPlaceholder
    }

    /// 选号完成后保存锁定号码，并进入套餐选择。
    func completeNumberSelection(_ selection: NumberSelection) {
        onboardingStateStore.save(selection)
        currentNumberSelection = selection  // 保留用于结账页返回导航
        step = .planSelection(selection)
    }

    /// 套餐选择完成，携带结账摘要进入结账支付页。
    func proceedToCheckout(_ summary: CheckoutSummary) {
        step = .checkout(summary)
    }

    /// 从结账页返回套餐选择页。
    func backToPlanSelection() {
        guard let selection = currentNumberSelection else {
            step = .numberSelection
            return
        }
        step = .planSelection(selection)
    }

    /// 是否展示 UAE Pass 登录。
    var shouldShowUAEPassLogin: Bool {
        step == .uaePassLogin
    }

    /// 是否展示旧版路径选择页，保留给兼容入口使用。
    var shouldShowAcquisitionSplit: Bool {
        step == .acquisitionSplit
    }

    /// 退出当前流程并回到 Welcome。
    func resetToWelcome() {
        step = .welcome
        entryIntent = nil
    }

    /// 从选号或 Port In 后续页面返回个性化页，因为这里承载 Buy eSIM / Port In 路由。
    func backToPersonalization() {
        step = .personalization
    }

    /// 从个性化页返回 eKYC。
    func backToEKYCVerification() {
        step = .ekycVerification
    }

    /// 从套餐选择页返回选号页。
    func backToNumberSelection() {
        step = .numberSelection
    }
}
