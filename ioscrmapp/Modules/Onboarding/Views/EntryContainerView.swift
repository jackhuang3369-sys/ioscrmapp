import SwiftUI

struct EntryContainerView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    @StateObject private var viewModel: EntryViewModel
    // Drives UAE Pass OAuth for the eKYC step; shared uaePassService with login flow
    @StateObject private var ekycViewModel: EKYCViewModel

    private let sessionStore: SessionStore
    private let authService: any AuthServicing
    private let uaePassService: UAEPassServicing
    private let onboardingStateStore: OnboardingStateStore

    init(
        sessionStore: SessionStore,
        authService: any AuthServicing,
        uaePassService: UAEPassServicing,
        onboardingStateStore: OnboardingStateStore = OnboardingStateStore()
    ) {
        self.sessionStore = sessionStore
        self.authService = authService
        self.uaePassService = uaePassService
        self.onboardingStateStore = onboardingStateStore
        _viewModel = StateObject(wrappedValue: EntryViewModel(onboardingStateStore: onboardingStateStore))
        _ekycViewModel = StateObject(wrappedValue: EKYCViewModel(uaePassService: uaePassService))
    }

    var body: some View {
        Group {
            switch viewModel.step {
            case .welcome:
                WelcomeView(
                    onGetStarted: { viewModel.handleGetStarted() },
                    onSignIn: { viewModel.handleSignIn() }
                )
            case .ekycVerification:
                OnboardingEKYCView(
                    ekycViewModel: ekycViewModel,
                    onBack: {
                        // Cancel any in-flight UAE Pass session before leaving the step
                        ekycViewModel.cancel()
                        viewModel.resetToWelcome()
                    },
                    onContinue: { viewModel.completeEKYCVerification() }
                )
            case .personalization:
                OnboardingPersonalizationView(
                    onBack: { viewModel.backToEKYCVerification() },
                    onBuyESIM: { viewModel.selectAcquisitionPath(.newNumber) },
                    onPortIn: { viewModel.selectAcquisitionPath(.portIn) }
                )
            case .acquisitionSplit:
                AcquisitionSplitView(
                    onSelectNewNumber: { viewModel.selectAcquisitionPath(.newNumber) },
                    onSelectPortIn: { viewModel.selectAcquisitionPath(.portIn) },
                    onBack: { viewModel.resetToWelcome() }
                )
            case .uaePassLogin:
                AuthLoginContainerView(
                    sessionStore: sessionStore,
                    authService: authService,
                    uaePassService: uaePassService
                )
            case .numberSelection:
                NumberSelectionView(
                    viewModel: NumberSelectionViewModel(onboardingStateStore: onboardingStateStore),
                    onContinue: { selection in viewModel.completeNumberSelection(selection) },
                    // 个性化页现在直接承载 Buy eSIM / Port In，因此选号页返回到个性化页。
                    onBack: { viewModel.backToPersonalization() }
                )
            case .portInPlaceholder:
                // Port In 详情页还未设计完成，当前先保留为后续流程占位。
                placeholderOnboardingView(title: "Port In", detail: "Port-in number flow is coming next.")
            case .planSelection(let selection):
                PlanSelectionView(
                    numberSelection: selection,
                    onBack: { viewModel.backToNumberSelection() },
                    // 套餐确认后进入结账页
                    onCheckout: { summary in viewModel.proceedToCheckout(summary) }
                )
            case .checkout(let summary):
                CheckoutView(
                    summary: summary,
                    onBack: { viewModel.backToPlanSelection() },
                    // 结账完成（支付成功）后的下一步由业务接入，当前先占位
                    onPay: { viewModel.resetToWelcome() }
                )
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.step)
    }

    private func placeholderOnboardingView(title: String, detail: String) -> some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: DUSpacing.xxl) {
                Text(title)
                    .font(.du(.headline))
                    .foregroundColor(.primary)
                Text(detail)
                    .font(.du(.body))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Button("Back to Welcome") {
                    viewModel.resetToWelcome()
                }
                .font(.du(.body))
            }
        }
    }
}

private enum VerifiedOnboardingPalette {
    static let red = Color(hex: 0xFF1235)
    static let gold = Color(hex: 0xF4C15D)
    static let cyan = Color(hex: 0x13C8FF)
    static let canvas = Color(hex: 0x030305)
}

private struct VerifiedOnboardingBackground: View {
    var body: some View {
        ZStack {
            VerifiedOnboardingPalette.canvas

            RadialGradient(
                colors: [VerifiedOnboardingPalette.red.opacity(0.24), .clear],
                center: .topTrailing,
                startRadius: 24,
                endRadius: 310
            )

            RadialGradient(
                colors: [VerifiedOnboardingPalette.cyan.opacity(0.12), .clear],
                center: .bottomLeading,
                startRadius: 20,
                endRadius: 280
            )

            LinearGradient(
                colors: [Color.black.opacity(0.08), Color.black.opacity(0.72)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

private struct OnboardingFlowHeader: View {
    let safeTop: CGFloat
    let onBack: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Spacer()

            Image("RedBullLogo")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: 164, height: 32, alignment: .trailing)
                .shadow(color: Color.white.opacity(0.16), radius: 14, x: 0, y: 0)
        }
        // Reduced top spacing by 18pt to tighten header proximity to status bar (was safeTop+8)
        .padding(.top, max(safeTop - 10, 12))
        .padding(.horizontal, 26)
    }
}

private struct OnboardingEKYCView: View {
    @ObservedObject var ekycViewModel: EKYCViewModel
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                VerifiedOnboardingBackground()

                VStack(alignment: .leading, spacing: 0) {
                    OnboardingFlowHeader(safeTop: proxy.safeAreaInsets.top, onBack: onBack)

                    VStack(alignment: .leading, spacing: 14) {
                        Text("IDENTITY CHECK")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .tracking(4)
                            .foregroundColor(.white.opacity(0.42))

                        // lineLimit(1) + minimumScaleFactor: prevent title from wrapping on narrow screens
                        Text("Verify with UAE Pass")
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        Text("Your device is ready for eSIM. Now verify your identity before choosing a number or porting in.")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.58))
                            .lineSpacing(5)

                        VStack(alignment: .leading, spacing: 10) {
                            OnboardingStatusRow(icon: "checkmark.shield.fill", title: "UAE Pass ready", detail: "Fast verification for UAE mobile onboarding.")
                            OnboardingStatusRow(icon: "faceid", title: "Face recognition fallback", detail: "Use FR when UAE Pass requires an extra check.")
                            OnboardingStatusRow(icon: "person.text.rectangle", title: "Manual review available", detail: "Fallback path for edge-case verification.")
                        }
                        .padding(.top, 10)

                        // Inline error banner — shown only when verification fails
                        if let ekycError = ekycViewModel.error {
                            HStack(spacing: 10) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(VerifiedOnboardingPalette.red)
                                Text(ekycError.errorDescription ?? "Verification failed. Please try again.")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.85))
                                    .lineLimit(3)
                                Spacer(minLength: 0)
                                Button { ekycViewModel.clearError() } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                            .padding(12)
                            .background(
                                VerifiedOnboardingPalette.red.opacity(0.15),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(VerifiedOnboardingPalette.red.opacity(0.3), lineWidth: 1)
                            )
                            .padding(.top, 4)
                        }
                    }
                    .padding(24)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .background(
                        LinearGradient(
                            colors: [VerifiedOnboardingPalette.red.opacity(0.2), Color.white.opacity(0.045)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 32, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    )
                    .padding(.horizontal, 26)
                    .padding(.top, 30)

                    // 测试跳过按钮：紧贴 card 下方居中显示，绕过 UAE Pass 用于下游联调
                    HStack {
                        Spacer()
                        Button(action: onContinue) {
                            Text("Skip for testing")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.36))
                                .underline()
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .padding(.top, 16)

                    Spacer()

                    // Triggers real UAE Pass OAuth; shows spinner while in-flight
                    Button {
                        ekycViewModel.startUAEPassVerification { _ in
                            onContinue()
                        }
                    } label: {
                        ZStack {
                            if ekycViewModel.isLoading {
                                ProgressView()
                                    .tint(Color(hex: 0x1C1B24))
                            } else {
                                Text("VERIFY & CONTINUE")
                                    .font(.system(size: 16, weight: .black, design: .monospaced))
                                    .tracking(3.6)
                                    .foregroundColor(Color(hex: 0x1C1B24))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .shadow(color: Color.white.opacity(0.14), radius: 28, x: 0, y: 14)
                    }
                    .buttonStyle(.plain)
                    .disabled(ekycViewModel.isLoading)
                    .padding(.horizontal, 26)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom, 16))
                }
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden(true)
    }
}

private struct OnboardingStatusRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 34, height: 34)
                .background(VerifiedOnboardingPalette.red.opacity(0.22), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                Text(detail)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.52))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct OnboardingPersonalizationView: View {
    let onBack: () -> Void
    let onBuyESIM: () -> Void
    let onPortIn: () -> Void

    @State private var selectedInterests: Set<String> = ["Events", "Gaming"]
    @State private var selectedPlanPreference = "Balanced"
    @State private var wantsMarketing = true
    @State private var preferredLanguage = "English"

    private let interests = ["Events", "Gaming", "Fitness", "Music", "Travel", "Rewards"]
    private let planPreferences = ["Data first", "Balanced", "Voice heavy", "Annual value"]
    private let languages = ["English", "Arabic", "Chinese"]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                PersonalizationBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("PERSONALIZATION")
                                .font(.system(size: 12, weight: .bold, design: .default))
                                .tracking(3)
                                .foregroundColor(.white.opacity(0.6))

                            Text("Tune your Red Bull\nMobile experience")
                                .font(.system(size: 32, weight: .heavy, design: .default))
                                .foregroundColor(.white)
                                .lineSpacing(1)

                            Text("These choices help us recommend numbers, plans, offers, and activation guidance after verification.")
                                .font(.system(size: 15, weight: .regular, design: .default))
                                .foregroundColor(.white.opacity(0.6))
                                .lineSpacing(3)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, max(proxy.safeAreaInsets.top, 20) + 70)

                        VStack(spacing: 24) {
                            PreferenceSection(title: "Interests") {
                                FlowWrap(items: interests) { interest in
                                    PreferenceChip(
                                        title: interest,
                                        isSelected: selectedInterests.contains(interest)
                                    ) {
                                        // Mock 个性化选择：本阶段只保存本地 UI 状态，后续接入真实画像接口。
                                        if selectedInterests.contains(interest) {
                                            selectedInterests.remove(interest)
                                        } else {
                                            selectedInterests.insert(interest)
                                        }
                                    }
                                }
                            }

                            PreferenceSection(title: "Plan recommendation") {
                                VStack(spacing: 10) {
                                    ForEach(planPreferences, id: \.self) { preference in
                                        PreferenceOptionRow(
                                            title: preference,
                                            isSelected: selectedPlanPreference == preference
                                        ) {
                                            selectedPlanPreference = preference
                                        }
                                    }
                                }
                            }

                            PreferenceSection(title: "Language & marketing") {
                                VStack(spacing: 0) {
                                    HStack(spacing: 10) {
                                        ForEach(languages, id: \.self) { language in
                                            PreferenceChip(
                                                title: language,
                                                isSelected: preferredLanguage == language
                                            ) {
                                                preferredLanguage = language
                                            }
                                        }
                                    }

                                    MarketingToggleRow(isOn: $wantsMarketing)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 24)

                        PersonalizationPathBar(
                            safeBottom: proxy.safeAreaInsets.bottom,
                            onBuyESIM: onBuyESIM,
                            onPortIn: onPortIn
                        )
                    }
                }

                VStack {
                    HStack {
                        Button(action: onBack) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.white.opacity(0.08), in: Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Back")

                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, max(proxy.safeAreaInsets.top - 10, 12))

                    Spacer()
                }
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden(true)
    }
}

private struct PersonalizationBackground: View {
    var body: some View {
        ZStack {
            Color.black

            RadialGradient(
                colors: [Color(hex: 0xE10600, opacity: 0.2), .clear],
                center: UnitPoint(x: 0.85, y: 0.1),
                startRadius: 10,
                endRadius: 300
            )

            RadialGradient(
                colors: [Color(hex: 0x1E2850, opacity: 0.3), .clear],
                center: UnitPoint(x: 0.1, y: 0.8),
                startRadius: 10,
                endRadius: 360
            )
        }
        .ignoresSafeArea()
    }
}

private struct PreferenceSection<Content: View>: View {
    let title: String
    let content: () -> Content

    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .default))
                .tracking(0.5)
                .foregroundColor(.white)

            content()
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct FlowWrap<Content: View>: View {
    let items: [String]
    let content: (String) -> Content

    init(items: [String], @ViewBuilder content: @escaping (String) -> Content) {
        self.items = items
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(strideRows, id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(row, id: \.self) { item in
                        content(item)
                    }
                }
            }
        }
    }

    private var strideRows: [[String]] {
        stride(from: 0, to: items.count, by: 3).map { start in
            Array(items[start..<min(start + 3, items.count)])
        }
    }
}

private struct PreferenceChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .default))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 18)
                .frame(height: 40)
                .background(isSelected ? Color(hex: 0xE10600) : Color.white.opacity(0.1), in: Capsule())
                .overlay(Capsule().stroke(isSelected ? Color(hex: 0xE10600) : Color.white.opacity(0.05), lineWidth: 1))
                .shadow(color: isSelected ? Color(hex: 0xE10600, opacity: 0.4) : .clear, radius: 12, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

private struct PreferenceOptionRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .medium, design: .default))
                    .foregroundColor(.white)
                Spacer()
                RadioCircle(isSelected: isSelected)
            }
            .padding(16)
            .background(isSelected ? Color.white.opacity(0.08) : Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.white.opacity(0.2) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct RadioCircle: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(isSelected ? Color(hex: 0xE10600) : Color.white.opacity(0.3), lineWidth: 2)
                .background(isSelected ? Color(hex: 0xE10600) : .clear, in: Circle())
                .frame(width: 22, height: 22)

            if isSelected {
                Circle()
                    .fill(Color.white)
                    .frame(width: 8, height: 8)
            }
        }
    }
}

private struct MarketingToggleRow: View {
    @Binding var isOn: Bool

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)
                .padding(.top, 24)
                .padding(.bottom, 24)

            HStack(alignment: .center, spacing: 20) {
                Text("Allow Red Bull Mobile offers and event updates")
                    .font(.system(size: 14, weight: .regular, design: .default))
                    .foregroundColor(.white.opacity(0.6))
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .tint(Color(hex: 0xE10600))
            }
        }
    }
}

private struct PersonalizationPathBar: View {
    let safeBottom: CGFloat
    let onBuyESIM: () -> Void
    let onPortIn: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // 入网路径选择放在页面内容末尾，确保用户先完成全部个性化信息。
            Button(action: onBuyESIM) {
                Text("Buy a eSIM")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(primaryActionBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
                    .shadow(color: Color(hex: 0xE10600, opacity: 0.28), radius: 24, x: 0, y: 12)
            }
            .buttonStyle(.plain)

            HStack(spacing: 14) {
                Rectangle()
                    .fill(Color.white.opacity(0.14))
                    .frame(height: 1)

                Text("OR")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(.white.opacity(0.46))
                    .tracking(1.4)

                Rectangle()
                    .fill(Color.white.opacity(0.14))
                    .frame(height: 1)
            }

            Button(action: onPortIn) {
                Text("Port In")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(portInBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 30)
        .padding(.bottom, max(safeBottom, 34) + 24)
    }

    private var primaryActionBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.16),
                Color(hex: 0xFF1B2D),
                Color(hex: 0x9D071D),
                Color(hex: 0x2B0B10)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var portInBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.16),
                Color.white.opacity(0.1),
                Color(hex: 0xE10600, opacity: 0.08)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
