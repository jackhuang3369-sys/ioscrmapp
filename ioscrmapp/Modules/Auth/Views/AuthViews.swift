import SwiftUI

struct AuthLoginContainerView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    @StateObject private var viewModel: AuthLoginViewModel
    @State private var isShowingRegistration = false
    @State private var isShowingForgotPassword = false

    private let authService: any AuthServicing

    init(sessionStore: SessionStore, authService: any AuthServicing) {
        self.authService = authService
        _viewModel = StateObject(
            wrappedValue: AuthLoginViewModel(
                authService: authService,
                sessionStore: sessionStore
            )
        )
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: DUSpacing.xxl) {
                    AuthBrandMark()
                    header
                    tabs
                    if let bannerMessage = viewModel.bannerMessage {
                        AuthBannerView(message: localized(bannerMessage), tone: viewModel.bannerTone)
                    }
                    phoneField
                    if viewModel.selectedMode == .password {
                        passwordField
                        loginOptions
                    } else {
                        otpField
                    }
                    Group {
                        primaryButton
                        socialLogin
                        registerLink
                    }
                }
                .padding(.horizontal, DUSpacing.xl)
                .padding(.top, max(proxy.safeAreaInsets.top, DUSpacing.sm))
                .padding(.bottom, DUSpacing.xxxl)
            }
            .background(DUTheme.background.ignoresSafeArea())
        }
        .fullScreenCover(isPresented: $isShowingRegistration) {
            AuthRegistrationContainerView(
                authService: authService,
                initialPhone: registrationInitialPhone
            ) { result in
                viewModel.applyRegistrationResult(result)
            }
        }
        .fullScreenCover(isPresented: $isShowingForgotPassword) {
            AuthForgotPasswordContainerView(
                authService: authService,
                initialPhone: viewModel.phoneNumber
            ) { result in
                viewModel.applyForgotPasswordResult(result)
            }
        }
    }

    private var registrationInitialPhone: String {
        let normalizedDemoPhone = AuthValidator.normalizedPhone(AuthValidator.demoPhone)
        return viewModel.phoneNumber == normalizedDemoPhone ? "" : viewModel.phoneNumber
    }

    private var header: some View {
        VStack(spacing: DUSpacing.sm) {
            Text(localized("auth.header.title"))
                .font(.du(28, weight: .bold))
                .foregroundColor(DUTheme.ink)
            Text(localized("auth.header.subtitle"))
                .font(.du(15, weight: .medium))
                .foregroundColor(DUTheme.inkTertiary)
        }
    }

    private var tabs: some View {
        HStack(spacing: DUSpacing.xs) {
            ForEach(LoginMode.allCases) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.select(mode: mode)
                    }
                } label: {
                    Text(localized(mode.titleKey))
                        .font(.du(15, weight: .semibold))
                        .foregroundColor(viewModel.selectedMode == mode ? DUTheme.ink : DUTheme.inkSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(viewModel.selectedMode == mode ? DUTheme.panel : .clear)
                                .shadow(
                                    color: Color.black.opacity(viewModel.selectedMode == mode ? 0.06 : 0),
                                    radius: 8,
                                    x: 0,
                                    y: 4
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DUSpacing.xs)
        .background(DUTheme.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var phoneField: some View {
        DUPhoneField(
            title: localized("auth.field.phone.title"),
            countryCode: "+\(AuthValidator.countryCode)",
            placeholder: localized("auth.field.phone.placeholder"),
            text: $viewModel.phoneNumber,
            error: localized(viewModel.phoneError),
            displayText: AuthValidator.localPhoneDigits,
            normalizeText: AuthValidator.normalizedPhone
        )
    }

    private var passwordField: some View {
        DUTextField(
            title: localized("auth.field.password.title"),
            placeholder: localized("auth.field.password.placeholder"),
            text: $viewModel.password,
            error: localized(viewModel.passwordError),
            isSecure: true
        )
    }

    private var otpField: some View {
        VStack(alignment: .leading, spacing: DUSpacing.sm) {
            Text(localized("auth.field.otp.title"))
                .font(.du(14, weight: .semibold))
                .foregroundColor(DUTheme.inkSecondary)
            HStack(alignment: .top, spacing: DUSpacing.md) {
                DUTextField(
                    title: nil,
                    placeholder: localized("auth.field.otp.placeholder"),
                    text: $viewModel.otp,
                    error: localized(viewModel.otpError),
                    keyboardType: .numberPad
                )
                DUButton(
                    title: localized(viewModel.otpButtonText),
                    style: .secondary,
                    isEnabled: viewModel.isSendOTPEnabled,
                    fixedWidth: 114,
                    fontSize: 14
                ) {
                    viewModel.sendOTP()
                }
            }
            Text(localized("auth.otp.expiry"))
                .font(.du(12, weight: .medium))
                .foregroundColor(DUTheme.inkTertiary)
        }
    }

    private var loginOptions: some View {
        HStack {
            Button {
                viewModel.rememberMe.toggle()
            } label: {
                HStack(spacing: DUSpacing.sm) {
                    Image(systemName: viewModel.rememberMe ? "checkmark.square.fill" : "square")
                        .foregroundColor(viewModel.rememberMe ? DUTheme.cyan : DUTheme.inkDisabled)
                    Text(localized("auth.option.rememberMe"))
                        .foregroundColor(DUTheme.inkSecondary)
                }
                .font(.du(13, weight: .medium))
            }
            .buttonStyle(.plain)

            Spacer()

            DUTextButton(
                title: localized("auth.option.forgotPassword"),
                fontSize: 13,
                weight: .medium
            ) {
                isShowingForgotPassword = true
            }
        }
    }

    private var primaryButton: some View {
        DUButton(
            title: localized(
                viewModel.selectedMode == .password
                    ? "auth.primary.password"
                    : "auth.primary.otp"
            ),
            style: .primary,
            isLoading: viewModel.isLoading,
            isEnabled: viewModel.isPrimaryActionEnabled,
            height: 56,
            cornerRadius: 22,
            fontSize: 17
        ) {
            viewModel.login()
        }
    }

    private var socialLogin: some View {
        VStack(spacing: DUSpacing.lg) {
            HStack {
                Rectangle()
                    .fill(DUTheme.lineLight)
                    .frame(height: 1)
                Text(localized("auth.social.otherWays"))
                    .font(.du(13, weight: .medium))
                    .foregroundColor(DUTheme.inkTertiary)
                    .padding(.horizontal, DUSpacing.sm)
                Rectangle()
                    .fill(DUTheme.lineLight)
                    .frame(height: 1)
            }

            HStack(spacing: DUSpacing.lg) {
                DUIconButton(
                    title: localized("auth.social.sms")
                ) {
                    Image("LoginSMSIcon")
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .offset(y: 6)
                } action: {
                    viewModel.showPlaceholderMessage(for: "auth.placeholder.sms")
                }
                DUIconButton(
                    title: localized("auth.social.fingerprint")
                ) {
                    Image(systemName: "touchid")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                        .foregroundColor(DUTheme.inkSecondary)
                } action: {
                    viewModel.showPlaceholderMessage(for: "auth.placeholder.fingerprint")
                }
                DUIconButton(
                    title: localized("auth.social.face")
                ) {
                    Image(systemName: "faceid")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                        .foregroundColor(DUTheme.inkSecondary)
                } action: {
                    viewModel.showPlaceholderMessage(for: "auth.placeholder.face")
                }
            }
        }
    }

    private var registerLink: some View {
        HStack(spacing: DUSpacing.xs) {
            Text(localized("auth.register.prompt"))
                .foregroundColor(DUTheme.inkTertiary)
            DUTextButton(
                title: localized("auth.register.action"),
                fontSize: 14,
                weight: .medium
            ) {
                isShowingRegistration = true
            }
        }
        .font(.du(14, weight: .medium))
        .padding(.bottom, DUSpacing.xxxl)
    }

    private func localized(_ key: String, arguments: [String] = []) -> String {
        languageStore.string(key, arguments: arguments)
    }

    private func localized(_ value: LocalizedTextValue) -> String {
        languageStore.string(value)
    }

    private func localized(_ value: LocalizedTextValue?) -> String? {
        guard let value else {
            return nil
        }

        return languageStore.string(value)
    }
}

private enum AuthRegistrationStep {
    case verify
    case password
}

private enum AuthForgotPasswordStep {
    case verify
    case password
}

struct AuthForgotPasswordContainerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AuthForgotPasswordViewModel
    @State private var step: AuthForgotPasswordStep = .verify

    private let onComplete: (ForgotPasswordFlowResult) -> Void

    init(
        authService: any AuthServicing,
        initialPhone: String = "",
        onComplete: @escaping (ForgotPasswordFlowResult) -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: AuthForgotPasswordViewModel(
                authService: authService,
                initialPhone: initialPhone
            )
        )
        self.onComplete = onComplete
    }

    var body: some View {
        Group {
            switch step {
            case .verify:
                AuthForgotPasswordVerifyView(
                    viewModel: viewModel,
                    closeAction: { dismiss() },
                    verifyAction: {
                        viewModel.verifyAndContinue { context in
                            viewModel.restorePasswordStep(with: context)
                            withAnimation(.easeInOut(duration: 0.2)) {
                                step = .password
                            }
                        }
                    },
                    backToLoginAction: { dismiss() }
                )
            case .password:
                AuthForgotPasswordPasswordView(
                    viewModel: viewModel,
                    closeAction: { dismiss() },
                    backAction: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            step = .verify
                        }
                    },
                    submitAction: {
                        viewModel.resetPassword { result in
                            finish(with: result)
                        }
                    },
                    backToLoginAction: { dismiss() }
                )
            }
        }
        .onAppear {
            viewModel.logFlowOpened()
        }
    }

    private func finish(with result: ForgotPasswordFlowResult) {
        onComplete(result)
        dismiss()
    }
}

private struct AuthForgotPasswordVerifyView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    @ObservedObject var viewModel: AuthForgotPasswordViewModel

    let closeAction: () -> Void
    let verifyAction: () -> Void
    let backToLoginAction: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: DUSpacing.xxl) {
                    AuthFlowChrome(closeAction: closeAction)
                    AuthBrandMark()
                    header
                    AuthStepBadge(title: localized("auth.forgot.step.verify"))
                    if let bannerMessage = viewModel.bannerMessage {
                        AuthBannerView(message: localized(bannerMessage), tone: viewModel.bannerTone)
                    }
                    contentCard
                    loginFooter
                }
                .padding(.horizontal, DUSpacing.xl)
                .padding(.top, max(proxy.safeAreaInsets.top, DUSpacing.sm))
                .padding(.bottom, DUSpacing.xxxl)
            }
            .background(DUTheme.background.ignoresSafeArea())
        }
        .navigationBarBackButtonHidden(true)
    }

    private var header: some View {
        VStack(spacing: DUSpacing.sm) {
            Text(localized("auth.forgot.title"))
                .font(.du(28, weight: .bold))
                .foregroundColor(DUTheme.ink)
                .multilineTextAlignment(.center)
            Text(localized("auth.forgot.subtitle"))
                .font(.du(15, weight: .medium))
                .foregroundColor(DUTheme.inkTertiary)
                .multilineTextAlignment(.center)
        }
    }

    private var contentCard: some View {
        VStack(spacing: DUSpacing.lg) {
            DUPhoneField(
                title: localized("auth.field.phone.title"),
                countryCode: "+\(AuthValidator.countryCode)",
                placeholder: localized("auth.field.phone.placeholder"),
                text: $viewModel.phoneNumber,
                error: localized(viewModel.phoneError),
                displayText: AuthValidator.localPhoneDigits,
                normalizeText: AuthValidator.normalizedPhone
            )

            VStack(alignment: .leading, spacing: DUSpacing.sm) {
                Text(localized("auth.field.otp.title"))
                    .font(.du(14, weight: .semibold))
                    .foregroundColor(DUTheme.inkSecondary)

                HStack(alignment: .top, spacing: DUSpacing.md) {
                    DUTextField(
                        title: nil,
                        placeholder: localized("auth.field.otp.placeholder"),
                        text: $viewModel.otp,
                        error: localized(viewModel.otpError),
                        keyboardType: .numberPad
                    )

                    DUButton(
                        title: localized(viewModel.otpButtonText),
                        style: .secondary,
                        isEnabled: viewModel.canSendOTP,
                        fixedWidth: 114,
                        fontSize: 14
                    ) {
                        viewModel.sendOTP()
                    }
                }

                Text(localized(viewModel.otpHelperText))
                    .font(.du(12, weight: .medium))
                    .foregroundColor(DUTheme.inkTertiary)
            }

            DUButton(
                title: localized("auth.forgot.action.verify"),
                style: .primary,
                isLoading: viewModel.isLoading,
                isEnabled: viewModel.canVerifyOTP,
                height: 56,
                cornerRadius: 22,
                fontSize: 17
            ) {
                verifyAction()
            }
        }
        .padding(DUSpacing.xl)
        .duCardStyle()
    }

    private var loginFooter: some View {
        DUTextButton(title: localized("auth.forgot.action.backToLogin")) {
            backToLoginAction()
        }
    }

    private func localized(_ key: String, arguments: [String] = []) -> String {
        languageStore.string(key, arguments: arguments)
    }

    private func localized(_ value: LocalizedTextValue) -> String {
        languageStore.string(value)
    }

    private func localized(_ value: LocalizedTextValue?) -> String? {
        guard let value else {
            return nil
        }
        return languageStore.string(value)
    }
}

private struct AuthForgotPasswordPasswordView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    @ObservedObject var viewModel: AuthForgotPasswordViewModel

    let closeAction: () -> Void
    let backAction: () -> Void
    let submitAction: () -> Void
    let backToLoginAction: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: DUSpacing.xxl) {
                    AuthFlowChrome(backAction: backAction, closeAction: closeAction)
                    AuthBrandMark()
                    header
                    AuthStepBadge(title: localized("auth.forgot.step.password"))
                    if let bannerMessage = viewModel.bannerMessage {
                        AuthBannerView(message: localized(bannerMessage), tone: viewModel.bannerTone)
                    }
                    contentCard
                    loginFooter
                }
                .padding(.horizontal, DUSpacing.xl)
                .padding(.top, max(proxy.safeAreaInsets.top, DUSpacing.sm))
                .padding(.bottom, DUSpacing.xxxl)
            }
            .background(DUTheme.background.ignoresSafeArea())
        }
        .navigationBarBackButtonHidden(true)
    }

    private var header: some View {
        VStack(spacing: DUSpacing.sm) {
            Text(localized("auth.forgot.passwordTitle"))
                .font(.du(28, weight: .bold))
                .foregroundColor(DUTheme.ink)
                .multilineTextAlignment(.center)
            Text(localized("auth.forgot.passwordSubtitle"))
                .font(.du(15, weight: .medium))
                .foregroundColor(DUTheme.inkTertiary)
                .multilineTextAlignment(.center)
        }
    }

    private var contentCard: some View {
        VStack(spacing: DUSpacing.lg) {
            verifiedPhoneSummary

            DUTextField(
                title: localized("auth.field.password.title"),
                placeholder: localized("auth.field.password.placeholder"),
                text: $viewModel.password,
                error: localized(viewModel.passwordError),
                isSecure: true
            )

            DUTextField(
                title: localized("auth.registration.field.confirmPassword.title"),
                placeholder: localized("auth.registration.field.confirmPassword.placeholder"),
                text: $viewModel.confirmPassword,
                error: localized(viewModel.confirmPasswordError),
                isSecure: true
            )

            DUButton(
                title: localized("auth.forgot.action.complete"),
                style: .primary,
                isLoading: viewModel.isLoading,
                isEnabled: viewModel.canSubmitPasswordReset,
                height: 56,
                cornerRadius: 22,
                fontSize: 17
            ) {
                submitAction()
            }
        }
        .padding(DUSpacing.xl)
        .duCardStyle()
    }

    private var verifiedPhoneSummary: some View {
        VStack(alignment: .leading, spacing: DUSpacing.sm) {
            Text(localized("auth.forgot.summary.verifiedPhone"))
                .font(.du(13, weight: .semibold))
                .foregroundColor(DUTheme.inkTertiary)
            Text(AuthValidator.formattedPhone(viewModel.verifiedContext?.phoneNumber ?? viewModel.phoneNumber))
                .font(.du(18, weight: .bold))
                .foregroundColor(DUTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DUSpacing.lg)
        .background(DUTheme.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var loginFooter: some View {
        DUTextButton(title: localized("auth.forgot.action.backToLogin")) {
            backToLoginAction()
        }
    }

    private func localized(_ key: String, arguments: [String] = []) -> String {
        languageStore.string(key, arguments: arguments)
    }

    private func localized(_ value: LocalizedTextValue) -> String {
        languageStore.string(value)
    }

    private func localized(_ value: LocalizedTextValue?) -> String? {
        guard let value else {
            return nil
        }
        return languageStore.string(value)
    }
}

struct AuthRegistrationContainerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AuthRegistrationViewModel
    @State private var step: AuthRegistrationStep = .verify

    private let onComplete: (RegistrationFlowResult) -> Void

    init(
        authService: any AuthServicing,
        initialPhone: String = "",
        onComplete: @escaping (RegistrationFlowResult) -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: AuthRegistrationViewModel(
                authService: authService,
                initialPhone: initialPhone
            )
        )
        self.onComplete = onComplete
    }

    var body: some View {
        Group {
            switch step {
            case .verify:
                AuthRegistrationVerifyView(
                    viewModel: viewModel,
                    closeAction: { dismiss() },
                    verifyAction: {
                        viewModel.verifyAndContinue { _ in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                step = .password
                            }
                        }
                    },
                    goToLoginAction: {
                        finish(with: viewModel.goToLoginResult())
                    }
                )
            case .password:
                AuthRegistrationPasswordView(
                    viewModel: viewModel,
                    closeAction: { dismiss() },
                    backAction: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            step = .verify
                        }
                    },
                    submitAction: {
                        viewModel.register { result in
                            finish(with: result)
                        }
                    },
                    goToLoginAction: {
                        finish(with: viewModel.goToLoginResult())
                    }
                )
            }
        }
        .onAppear {
            viewModel.logRegistrationOpened()
        }
    }

    private func finish(with result: RegistrationFlowResult) {
        onComplete(result)
        dismiss()
    }
}

private struct AuthRegistrationVerifyView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    @ObservedObject var viewModel: AuthRegistrationViewModel

    let closeAction: () -> Void
    let verifyAction: () -> Void
    let goToLoginAction: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: DUSpacing.xxl) {
                    AuthFlowChrome(closeAction: closeAction)
                    AuthBrandMark()
                    header
                    AuthStepBadge(title: localized("auth.registration.step.verify"))
                    if let bannerMessage = viewModel.bannerMessage {
                        AuthBannerView(message: localized(bannerMessage), tone: viewModel.bannerTone)
                    }
                    contentCard
                    loginFooter
                }
                .padding(.horizontal, DUSpacing.xl)
                .padding(.top, max(proxy.safeAreaInsets.top, DUSpacing.sm))
                .padding(.bottom, DUSpacing.xxxl)
            }
            .background(DUTheme.background.ignoresSafeArea())
        }
        .navigationBarBackButtonHidden(true)
    }

    private var header: some View {
        VStack(spacing: DUSpacing.sm) {
            Text(localized("auth.registration.title"))
                .font(.du(28, weight: .bold))
                .foregroundColor(DUTheme.ink)
                .multilineTextAlignment(.center)
            Text(localized("auth.registration.subtitle"))
                .font(.du(15, weight: .medium))
                .foregroundColor(DUTheme.inkTertiary)
                .multilineTextAlignment(.center)
        }
    }

    private var contentCard: some View {
        VStack(spacing: DUSpacing.lg) {
            DUPhoneField(
                title: localized("auth.field.phone.title"),
                countryCode: "+\(AuthValidator.countryCode)",
                placeholder: localized("auth.field.phone.placeholder"),
                text: $viewModel.phoneNumber,
                error: localized(viewModel.phoneError),
                displayText: AuthValidator.localPhoneDigits,
                normalizeText: AuthValidator.normalizedPhone
            )

            VStack(alignment: .leading, spacing: DUSpacing.sm) {
                Text(localized("auth.field.otp.title"))
                    .font(.du(14, weight: .semibold))
                    .foregroundColor(DUTheme.inkSecondary)

                HStack(alignment: .top, spacing: DUSpacing.md) {
                    DUTextField(
                        title: nil,
                        placeholder: localized("auth.field.otp.placeholder"),
                        text: $viewModel.otp,
                        error: localized(viewModel.otpError),
                        keyboardType: .numberPad
                    )

                    DUButton(
                        title: localized(viewModel.otpButtonText),
                        style: .secondary,
                        isEnabled: viewModel.canSendOTP,
                        fixedWidth: 114,
                        fontSize: 14
                    ) {
                        viewModel.sendOTP()
                    }
                }

                Text(localized(viewModel.otpHelperText))
                    .font(.du(12, weight: .medium))
                    .foregroundColor(DUTheme.inkTertiary)
            }

            DUButton(
                title: localized("auth.registration.action.verify"),
                style: .primary,
                isLoading: viewModel.isLoading,
                isEnabled: viewModel.canVerifyOTP,
                height: 56,
                cornerRadius: 22,
                fontSize: 17
            ) {
                verifyAction()
            }

            if viewModel.shouldShowGoToLoginAction {
                DUButton(
                    title: localized("auth.registration.action.goToLogin"),
                    style: .secondary,
                    height: 50,
                    fontSize: 15
                ) {
                    goToLoginAction()
                }
            }
        }
        .padding(DUSpacing.xl)
        .duCardStyle()
    }

    private var loginFooter: some View {
        DUTextButton(title: localized("auth.registration.action.backToLogin")) {
            goToLoginAction()
        }
    }

    private func localized(_ key: String, arguments: [String] = []) -> String {
        languageStore.string(key, arguments: arguments)
    }

    private func localized(_ value: LocalizedTextValue) -> String {
        languageStore.string(value)
    }

    private func localized(_ value: LocalizedTextValue?) -> String? {
        guard let value else {
            return nil
        }

        return languageStore.string(value)
    }
}

private struct AuthRegistrationPasswordView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    @ObservedObject var viewModel: AuthRegistrationViewModel

    let closeAction: () -> Void
    let backAction: () -> Void
    let submitAction: () -> Void
    let goToLoginAction: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: DUSpacing.xxl) {
                    AuthFlowChrome(backAction: backAction, closeAction: closeAction)
                    AuthBrandMark()
                    header
                    AuthStepBadge(title: localized("auth.registration.step.password"))
                    if let bannerMessage = viewModel.bannerMessage {
                        AuthBannerView(message: localized(bannerMessage), tone: viewModel.bannerTone)
                    }
                    contentCard
                    loginFooter
                }
                .padding(.horizontal, DUSpacing.xl)
                .padding(.top, max(proxy.safeAreaInsets.top, DUSpacing.sm))
                .padding(.bottom, DUSpacing.xxxl)
            }
            .background(DUTheme.background.ignoresSafeArea())
        }
        .navigationBarBackButtonHidden(true)
    }

    private var header: some View {
        VStack(spacing: DUSpacing.sm) {
            Text(localized("auth.registration.passwordTitle"))
                .font(.du(28, weight: .bold))
                .foregroundColor(DUTheme.ink)
                .multilineTextAlignment(.center)
            Text(localized("auth.registration.passwordSubtitle"))
                .font(.du(15, weight: .medium))
                .foregroundColor(DUTheme.inkTertiary)
                .multilineTextAlignment(.center)
        }
    }

    private var contentCard: some View {
        VStack(spacing: DUSpacing.lg) {
            verifiedPhoneSummary

            DUTextField(
                title: localized("auth.field.password.title"),
                placeholder: localized("auth.field.password.placeholder"),
                text: $viewModel.password,
                error: localized(viewModel.passwordError),
                isSecure: true
            )

            DUTextField(
                title: localized("auth.registration.field.confirmPassword.title"),
                placeholder: localized("auth.registration.field.confirmPassword.placeholder"),
                text: $viewModel.confirmPassword,
                error: localized(viewModel.confirmPasswordError),
                isSecure: true
            )

            DUButton(
                title: localized("auth.registration.action.complete"),
                style: .primary,
                isLoading: viewModel.isLoading,
                isEnabled: viewModel.canSubmitRegistration,
                height: 56,
                cornerRadius: 22,
                fontSize: 17
            ) {
                submitAction()
            }
        }
        .padding(DUSpacing.xl)
        .duCardStyle()
    }

    private var verifiedPhoneSummary: some View {
        VStack(alignment: .leading, spacing: DUSpacing.sm) {
            Text(localized("auth.registration.summary.verifiedPhone"))
                .font(.du(13, weight: .semibold))
                .foregroundColor(DUTheme.inkTertiary)
            Text(AuthValidator.formattedPhone(viewModel.verifiedContext?.phoneNumber ?? viewModel.phoneNumber))
                .font(.du(18, weight: .bold))
                .foregroundColor(DUTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DUSpacing.lg)
        .background(DUTheme.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var loginFooter: some View {
        DUTextButton(title: localized("auth.registration.action.backToLogin")) {
            goToLoginAction()
        }
    }

    private func localized(_ key: String, arguments: [String] = []) -> String {
        languageStore.string(key, arguments: arguments)
    }

    private func localized(_ value: LocalizedTextValue) -> String {
        languageStore.string(value)
    }

    private func localized(_ value: LocalizedTextValue?) -> String? {
        guard let value else {
            return nil
        }

        return languageStore.string(value)
    }
}

private struct AuthBrandMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(DUTheme.brandGradient)
                .frame(width: 88, height: 88)
                .shadow(color: DUTheme.cyan.opacity(0.25), radius: 18, x: 0, y: 8)
            Text("du")
                .font(.du(32, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.top, DUSpacing.sm)
    }
}

private struct AuthFlowChrome: View {
    var backAction: (() -> Void)? = nil
    let closeAction: () -> Void

    var body: some View {
        HStack {
            if let backAction {
                DUIconButton(
                    title: nil,
                    circleSize: 40,
                    backgroundColor: DUTheme.panel,
                    shadowColor: Color.black.opacity(0.06),
                    shadowRadius: 10,
                    shadowY: 6
                ) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(DUTheme.ink)
                } action: {
                    backAction()
                }
            } else {
                Color.clear
                    .frame(width: 40, height: 40)
            }

            Spacer()

            DUIconButton(
                title: nil,
                circleSize: 40,
                backgroundColor: DUTheme.panel,
                shadowColor: Color.black.opacity(0.06),
                shadowRadius: 10,
                shadowY: 6
            ) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DUTheme.ink)
            } action: {
                closeAction()
            }
        }
    }
}

private struct AuthStepBadge: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.du(13, weight: .semibold))
            .foregroundColor(DUTheme.cyan)
            .padding(.horizontal, DUSpacing.lg)
            .padding(.vertical, DUSpacing.sm)
            .background(DUTheme.cyanBackground)
            .clipShape(Capsule())
    }
}

private struct AuthBannerView: View {
    let message: String
    let tone: AuthBannerTone

    var body: some View {
        let background: Color
        let foreground: Color
        let iconName: String

        switch tone {
        case .info:
            background = DUTheme.cyanBackground
            foreground = DUTheme.cyan
            iconName = "sparkles"
        case .success:
            background = DUTheme.successBackground
            foreground = DUTheme.success
            iconName = "checkmark.circle.fill"
        case .error:
            background = DUTheme.errorBackground
            foreground = DUTheme.error
            iconName = "exclamationmark.triangle.fill"
        }

        return HStack(spacing: DUSpacing.sm) {
            Image(systemName: iconName)
            Text(message)
                .font(.du(13, weight: .semibold))
                .multilineTextAlignment(.leading)
            Spacer()
        }
        .foregroundColor(foreground)
        .padding(DUSpacing.lg)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct RegistrationPasswordPreviewHost: View {
    @StateObject private var viewModel = AuthRegistrationViewModel(
        authService: MockAuthService(),
        initialPhone: "971551234567"
    )

    var body: some View {
        AuthRegistrationPasswordView(
            viewModel: viewModel,
            closeAction: {},
            backAction: {},
            submitAction: {},
            goToLoginAction: {}
        )
        .task {
            viewModel.restorePasswordStep(
                with: RegistrationVerifiedContext(
                    phoneNumber: AuthValidator.normalizedPhone("971551234567"),
                    otpCode: AuthValidator.demoRegistrationOTP
                )
            )
        }
    }
}

private struct RegistrationVerifyRegisteredPreviewHost: View {
    @StateObject private var viewModel = AuthRegistrationViewModel(
        authService: MockAuthService(),
        initialPhone: "971555551111"
    )

    var body: some View {
        AuthRegistrationVerifyView(
            viewModel: viewModel,
            closeAction: {},
            verifyAction: {},
            goToLoginAction: {}
        )
        .task {
            viewModel.bannerTone = .error
            viewModel.bannerMessage = .key("auth.registration.error.alreadyRegistered")
            viewModel.shouldShowGoToLoginAction = true
        }
    }
}

struct AuthLoginContainerView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AuthLoginContainerView(sessionStore: SessionStore(), authService: MockAuthService())
                .previewDisplayName("Login")

            AuthRegistrationContainerView(authService: MockAuthService()) { _ in }
                .previewDisplayName("Registration Verify")

            RegistrationPasswordPreviewHost()
                .previewDisplayName("Registration Password")

            RegistrationVerifyRegisteredPreviewHost()
                .previewDisplayName("Registration Registered State")
        }
        .environmentObject(AppLanguageStore(initialLanguage: .english))
    }
}
