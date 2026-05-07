import SwiftUI

struct AuthLoginContainerView: View {
    @Environment(\.duTheme) private var theme
    @EnvironmentObject private var languageStore: AppLanguageStore
    @StateObject private var viewModel: AuthLoginViewModel
    @State private var isShowingRegistration = false
    @State private var isShowingForgotPassword = false

    private let authService: any AuthServicing
    private let uaePassService: UAEPassServicing

    init(sessionStore: SessionStore, authService: any AuthServicing, uaePassService: UAEPassServicing = MockUAEPassService()) {
        self.authService = authService
        self.uaePassService = uaePassService
        _viewModel = StateObject(
            wrappedValue: AuthLoginViewModel(
                authService: authService,
                uaePassService: uaePassService,
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
            .background(theme.colors.background.canvas.ignoresSafeArea())
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
                .font(.du(.hero))
                .foregroundColor(theme.colors.text.primary)
            Text(localized("auth.header.subtitle"))
                .font(.du(.body))
                .foregroundColor(theme.colors.text.tertiary)
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
                        .font(.du(.bodyStrong))
                        .foregroundColor(viewModel.selectedMode == mode ? theme.colors.text.primary : theme.colors.text.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: DURadius.field, style: .continuous)
                                .fill(viewModel.selectedMode == mode ? theme.colors.surface.card : DUColorPrimitives.Chrome.transparent)
                                .shadow(
                                    color: viewModel.selectedMode == mode ? theme.components.card.elevation.color : DUElevation.none.color,
                                    radius: theme.components.card.elevation.radius,
                                    x: theme.components.card.elevation.x,
                                    y: theme.components.card.elevation.y
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DUSpacing.xs)
        .background(theme.colors.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.components.card.cornerRadius, style: .continuous))
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
                .font(.du(.bodySmallStrong))
                .foregroundColor(theme.colors.text.secondary)
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
                    textStyle: .bodySmallEmphasized
                ) {
                    viewModel.sendOTP()
                }
            }
            Text(localized("auth.otp.expiry"))
                .font(.du(.bodySmall))
                .foregroundColor(theme.colors.text.tertiary)
        }
    }

    private var loginOptions: some View {
        HStack {
            Button {
                viewModel.rememberMe.toggle()
            } label: {
                HStack(spacing: DUSpacing.sm) {
                    Image(systemName: viewModel.rememberMe ? "checkmark.square.fill" : "square")
                        .foregroundColor(viewModel.rememberMe ? theme.colors.action.primary : theme.colors.text.disabled)
                    Text(localized("auth.option.rememberMe"))
                        .foregroundColor(theme.colors.text.secondary)
                }
                .font(.du(.label))
            }
            .buttonStyle(.plain)

            Spacer()

            DUTextButton(
                title: localized("auth.option.forgotPassword"),
                textStyle: .label
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
            textStyle: .titleSmall
        ) {
            viewModel.login()
        }
    }

    private var socialLogin: some View {
        VStack(spacing: DUSpacing.lg) {
            HStack {
                Rectangle()
                    .fill(theme.colors.border.subtle)
                    .frame(height: 1)
                Text(localized("auth.social.otherWays"))
                    .font(.du(.label))
                    .foregroundColor(theme.colors.text.tertiary)
                    .padding(.horizontal, DUSpacing.sm)
                Rectangle()
                    .fill(theme.colors.border.subtle)
                    .frame(height: 1)
            }

            HStack(spacing: DUSpacing.lg) {
                DUIconButton(
                    title: localized("auth.social.uaePass")
                ) {
                    Image("LoginUAEPassIcon")
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .offset(y: 6)
                } action: {
                    viewModel.loginWithUAEPass()
                }
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
                    title: localized("auth.social.face")
                ) {
                    Image(systemName: "faceid")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                        .foregroundColor(theme.colors.text.secondary)
                } action: {
                    viewModel.showPlaceholderMessage(for: "auth.placeholder.face")
                }
            }
        }
    }

    private var registerLink: some View {
        HStack(spacing: DUSpacing.xs) {
            Text(localized("auth.register.prompt"))
                .foregroundColor(theme.colors.text.tertiary)
            DUTextButton(
                title: localized("auth.register.action"),
                textStyle: .body
            ) {
                isShowingRegistration = true
            }
        }
        .font(.du(.bodySmall))
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
    @Environment(\.duTheme) private var theme
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
            .background(theme.colors.background.canvas.ignoresSafeArea())
        }
        .navigationBarBackButtonHidden(true)
    }

    private var header: some View {
        VStack(spacing: DUSpacing.sm) {
            Text(localized("auth.forgot.title"))
                .font(.du(.hero))
                .foregroundColor(theme.colors.text.primary)
                .multilineTextAlignment(.center)
            Text(localized("auth.forgot.subtitle"))
                .font(.du(.body))
                .foregroundColor(theme.colors.text.tertiary)
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
                    .font(.du(.bodySmallStrong))
                    .foregroundColor(theme.colors.text.secondary)

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
                        textStyle: .bodySmallEmphasized
                    ) {
                        viewModel.sendOTP()
                    }
                }

                Text(localized(viewModel.otpHelperText))
                    .font(.du(.bodySmall))
                    .foregroundColor(theme.colors.text.tertiary)
            }

            DUButton(
                title: localized("auth.forgot.action.verify"),
                style: .primary,
                isLoading: viewModel.isLoading,
                isEnabled: viewModel.canVerifyOTP,
                height: 56,
                textStyle: .titleSmall
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
    @Environment(\.duTheme) private var theme
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
            .background(theme.colors.background.canvas.ignoresSafeArea())
        }
        .navigationBarBackButtonHidden(true)
    }

    private var header: some View {
        VStack(spacing: DUSpacing.sm) {
            Text(localized("auth.forgot.passwordTitle"))
                .font(.du(.hero))
                .foregroundColor(theme.colors.text.primary)
                .multilineTextAlignment(.center)
            Text(localized("auth.forgot.passwordSubtitle"))
                .font(.du(.body))
                .foregroundColor(theme.colors.text.tertiary)
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
                textStyle: .titleSmall
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
                .font(.du(.labelStrong))
                .foregroundColor(theme.colors.text.tertiary)
            Text(AuthValidator.formattedPhone(viewModel.verifiedContext?.phoneNumber ?? viewModel.phoneNumber))
                .font(.du(.titleSmallStrong))
                .foregroundColor(theme.colors.text.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DUSpacing.lg)
        .background(theme.colors.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.components.field.cornerRadius, style: .continuous))
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
    @Environment(\.duTheme) private var theme
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
            .background(theme.colors.background.canvas.ignoresSafeArea())
        }
        .navigationBarBackButtonHidden(true)
    }

    private var header: some View {
        VStack(spacing: DUSpacing.sm) {
            Text(localized("auth.registration.title"))
                .font(.du(.hero))
                .foregroundColor(theme.colors.text.primary)
                .multilineTextAlignment(.center)
            Text(localized("auth.registration.subtitle"))
                .font(.du(.body))
                .foregroundColor(theme.colors.text.tertiary)
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
                    .font(.du(.bodySmallStrong))
                    .foregroundColor(theme.colors.text.secondary)

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
                        textStyle: .bodySmallEmphasized
                    ) {
                        viewModel.sendOTP()
                    }
                }

                Text(localized(viewModel.otpHelperText))
                    .font(.du(.bodySmall))
                    .foregroundColor(theme.colors.text.tertiary)
            }

            DUButton(
                title: localized("auth.registration.action.verify"),
                style: .primary,
                isLoading: viewModel.isLoading,
                isEnabled: viewModel.canVerifyOTP,
                height: 56,
                textStyle: .titleSmall
            ) {
                verifyAction()
            }

            if viewModel.shouldShowGoToLoginAction {
                DUButton(
                    title: localized("auth.registration.action.goToLogin"),
                    style: .secondary,
                    height: 50,
                    textStyle: .bodyEmphasized
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
    @Environment(\.duTheme) private var theme
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
            .background(theme.colors.background.canvas.ignoresSafeArea())
        }
        .navigationBarBackButtonHidden(true)
    }

    private var header: some View {
        VStack(spacing: DUSpacing.sm) {
            Text(localized("auth.registration.passwordTitle"))
                .font(.du(.hero))
                .foregroundColor(theme.colors.text.primary)
                .multilineTextAlignment(.center)
            Text(localized("auth.registration.passwordSubtitle"))
                .font(.du(.body))
                .foregroundColor(theme.colors.text.tertiary)
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
                textStyle: .titleSmall
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
                .font(.du(.labelStrong))
                .foregroundColor(theme.colors.text.tertiary)
            Text(AuthValidator.formattedPhone(viewModel.verifiedContext?.phoneNumber ?? viewModel.phoneNumber))
                .font(.du(.titleSmallStrong))
                .foregroundColor(theme.colors.text.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DUSpacing.lg)
        .background(theme.colors.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.components.field.cornerRadius, style: .continuous))
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
    @Environment(\.duTheme) private var theme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: theme.components.sheet.cornerRadius, style: .continuous)
                .fill(theme.colors.gradient.brand)
                .frame(width: 88, height: 88)
                .shadow(
                    color: theme.components.button.primary.shadowColor,
                    radius: theme.components.card.elevation.radius,
                    x: theme.components.card.elevation.x,
                    y: theme.components.card.elevation.y
                )
            Text("du")
                .font(.du(.screenTitle))
                .foregroundColor(DUColorPrimitives.Neutral.white)
        }
        .padding(.top, DUSpacing.sm)
    }
}

private struct AuthFlowChrome: View {
    @Environment(\.duTheme) private var theme

    var backAction: (() -> Void)? = nil
    let closeAction: () -> Void

    var body: some View {
        HStack {
            if let backAction {
                DUIconButton(
                    title: nil,
                    circleSize: 40,
                    backgroundColor: theme.colors.surface.card,
                    shadowColor: theme.components.card.elevation.color,
                    shadowRadius: DUElevation.control.radius,
                    shadowY: DUElevation.control.y
                ) {
                    Image(systemName: "chevron.left")
                        .font(.du(.bodyLargeSemibold))
                        .foregroundColor(theme.colors.text.primary)
                } action: {
                    backAction()
                }
            } else {
                DUColorPrimitives.Chrome.transparent
                    .frame(width: 40, height: 40)
            }

            Spacer()

            DUIconButton(
                title: nil,
                circleSize: 40,
                backgroundColor: theme.colors.surface.card,
                shadowColor: theme.components.card.elevation.color,
                shadowRadius: DUElevation.control.radius,
                shadowY: DUElevation.control.y
            ) {
                Image(systemName: "xmark")
                    .font(.du(.bodyLargeSemibold))
                    .foregroundColor(theme.colors.text.primary)
            } action: {
                closeAction()
            }
        }
    }
}

private struct AuthStepBadge: View {
    @Environment(\.duTheme) private var theme

    let title: String

    var body: some View {
        Text(title)
            .font(.du(.labelStrong))
            .foregroundColor(theme.colors.action.primary)
            .padding(.horizontal, DUSpacing.lg)
            .padding(.vertical, DUSpacing.sm)
            .background(theme.colors.action.primaryBackground)
            .clipShape(Capsule())
    }
}

private struct AuthBannerView: View {
    @Environment(\.duTheme) private var theme

    let message: String
    let tone: AuthBannerTone

    var body: some View {
        let background: Color
        let foreground: Color
        let iconName: String

        switch tone {
        case .info:
            background = theme.colors.action.primaryBackground
            foreground = theme.colors.action.primary
            iconName = "sparkles"
        case .success:
            background = theme.colors.status.successBackground
            foreground = theme.colors.status.success
            iconName = "checkmark.circle.fill"
        case .error:
            background = theme.colors.status.errorBackground
            foreground = theme.colors.status.error
            iconName = "exclamationmark.triangle.fill"
        }

        return HStack(spacing: DUSpacing.sm) {
            Image(systemName: iconName)
            Text(message)
                .font(.du(.labelStrong))
                .multilineTextAlignment(.leading)
            Spacer()
        }
        .foregroundColor(foreground)
        .padding(DUSpacing.lg)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: theme.components.field.cornerRadius, style: .continuous))
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
            AuthLoginContainerView(sessionStore: SessionStore(), authService: MockAuthService(), uaePassService: MockUAEPassService())
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
