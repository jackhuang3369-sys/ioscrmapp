import SwiftUI

struct AuthLoginContainerView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    @StateObject private var viewModel: AuthLoginViewModel
    @State private var isShowingRegistration = false

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
        DUPhoneNumberField(
            title: localized("auth.field.phone.title"),
            countryCode: "+\(AuthValidator.countryCode)",
            placeholder: localized("auth.field.phone.placeholder"),
            text: $viewModel.phoneNumber,
            error: localized(viewModel.phoneError)
        )
    }

    private var passwordField: some View {
        DUInputField(
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
                DUInputField(
                    title: nil,
                    placeholder: localized("auth.field.otp.placeholder"),
                    text: $viewModel.otp,
                    error: localized(viewModel.otpError),
                    keyboardType: .numberPad
                )
                OTPActionButton(
                    title: localized(viewModel.otpButtonText),
                    isEnabled: viewModel.isSendOTPEnabled
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

            Button(localized("auth.option.forgotPassword")) {
                viewModel.showPlaceholderMessage(for: "auth.placeholder.forgotPassword")
            }
            .font(.du(13, weight: .medium))
            .foregroundColor(DUTheme.cyan)
        }
    }

    private var primaryButton: some View {
        AuthPrimaryButton(
            title: localized(
                viewModel.selectedMode == .password
                    ? "auth.primary.password"
                    : "auth.primary.otp"
            ),
            isLoading: viewModel.isLoading,
            isEnabled: viewModel.isPrimaryActionEnabled
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
                PlaceholderCircleButton(assetName: "LoginSMSIcon", title: localized("auth.social.sms")) {
                    viewModel.showPlaceholderMessage(for: "auth.placeholder.sms")
                }
                PlaceholderCircleButton(systemName: "touchid", title: localized("auth.social.fingerprint")) {
                    viewModel.showPlaceholderMessage(for: "auth.placeholder.fingerprint")
                }
                PlaceholderCircleButton(systemName: "faceid", title: localized("auth.social.face")) {
                    viewModel.showPlaceholderMessage(for: "auth.placeholder.face")
                }
            }
        }
    }

    private var registerLink: some View {
        HStack(spacing: DUSpacing.xs) {
            Text(localized("auth.register.prompt"))
                .foregroundColor(DUTheme.inkTertiary)
            Button(localized("auth.register.action")) {
                isShowingRegistration = true
            }
            .foregroundColor(DUTheme.cyan)
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
            DUPhoneNumberField(
                title: localized("auth.field.phone.title"),
                countryCode: "+\(AuthValidator.countryCode)",
                placeholder: localized("auth.field.phone.placeholder"),
                text: $viewModel.phoneNumber,
                error: localized(viewModel.phoneError)
            )

            VStack(alignment: .leading, spacing: DUSpacing.sm) {
                Text(localized("auth.field.otp.title"))
                    .font(.du(14, weight: .semibold))
                    .foregroundColor(DUTheme.inkSecondary)

                HStack(alignment: .top, spacing: DUSpacing.md) {
                    DUInputField(
                        title: nil,
                        placeholder: localized("auth.field.otp.placeholder"),
                        text: $viewModel.otp,
                        error: localized(viewModel.otpError),
                        keyboardType: .numberPad
                    )

                    OTPActionButton(
                        title: localized(viewModel.otpButtonText),
                        isEnabled: viewModel.canSendOTP
                    ) {
                        viewModel.sendOTP()
                    }
                }

                Text(localized(viewModel.otpHelperText))
                    .font(.du(12, weight: .medium))
                    .foregroundColor(DUTheme.inkTertiary)
            }

            AuthPrimaryButton(
                title: localized("auth.registration.action.verify"),
                isLoading: viewModel.isLoading,
                isEnabled: viewModel.canVerifyOTP
            ) {
                verifyAction()
            }

            if viewModel.shouldShowGoToLoginAction {
                Button(localized("auth.registration.action.goToLogin")) {
                    goToLoginAction()
                }
                .font(.du(15, weight: .semibold))
                .foregroundColor(DUTheme.cyan)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(DUTheme.cyanBackground)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .buttonStyle(.plain)
            }
        }
        .padding(DUSpacing.xl)
        .duCardStyle()
    }

    private var loginFooter: some View {
        Button(localized("auth.registration.action.backToLogin")) {
            goToLoginAction()
        }
        .font(.du(14, weight: .semibold))
        .foregroundColor(DUTheme.cyan)
        .buttonStyle(.plain)
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

            DUInputField(
                title: localized("auth.field.password.title"),
                placeholder: localized("auth.field.password.placeholder"),
                text: $viewModel.password,
                error: localized(viewModel.passwordError),
                isSecure: true
            )

            DUInputField(
                title: localized("auth.registration.field.confirmPassword.title"),
                placeholder: localized("auth.registration.field.confirmPassword.placeholder"),
                text: $viewModel.confirmPassword,
                error: localized(viewModel.confirmPasswordError),
                isSecure: true
            )

            AuthPrimaryButton(
                title: localized("auth.registration.action.complete"),
                isLoading: viewModel.isLoading,
                isEnabled: viewModel.canSubmitRegistration
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
        Button(localized("auth.registration.action.backToLogin")) {
            goToLoginAction()
        }
        .font(.du(14, weight: .semibold))
        .foregroundColor(DUTheme.cyan)
        .buttonStyle(.plain)
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
            Text("DU")
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
                chromeButton(systemName: "chevron.left", action: backAction)
            } else {
                Color.clear
                    .frame(width: 40, height: 40)
            }

            Spacer()

            chromeButton(systemName: "xmark", action: closeAction)
        }
    }

    private func chromeButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(DUTheme.ink)
                .frame(width: 40, height: 40)
                .background(DUTheme.panel)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
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

private struct AuthPrimaryButton: View {
    let title: String
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DUSpacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                }
                Text(title)
                    .font(.du(17, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                isEnabled
                    ? DUTheme.brandGradient
                    : LinearGradient(
                        gradient: Gradient(colors: [DUTheme.inkDisabled]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(
                color: isEnabled ? DUTheme.cyan.opacity(0.28) : .clear,
                radius: 18,
                x: 0,
                y: 8
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
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

private struct OTPActionButton: View {
    let title: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.du(14, weight: .semibold))
                .foregroundColor(isEnabled ? DUTheme.cyan : DUTheme.inkDisabled)
                .frame(width: 114, height: 52)
                .background(isEnabled ? DUTheme.cyanBackground : DUTheme.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

private struct DUInputField: View {
    let title: String?
    let placeholder: String
    @Binding var text: String
    let error: String?
    var keyboardType: UIKeyboardType = .default
    var isSecure = false

    @State private var isSecureRevealed = false

    private var strokeColor: Color {
        if error != nil {
            return DUTheme.error
        }
        return DUTheme.line
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DUSpacing.sm) {
            if let title = title {
                Text(title)
                    .font(.du(14, weight: .semibold))
                    .foregroundColor(DUTheme.inkSecondary)
            }

            HStack(spacing: DUSpacing.sm) {
                Group {
                    if isSecure, !isSecureRevealed {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                            .keyboardType(keyboardType)
                    }
                }
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .font(.du(16, weight: .medium))
                .foregroundColor(DUTheme.ink)

                if isSecure {
                    Button {
                        isSecureRevealed.toggle()
                    } label: {
                        Image(systemName: isSecureRevealed ? "eye.slash" : "eye")
                            .foregroundColor(DUTheme.inkTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DUSpacing.lg)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(DUTheme.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(strokeColor, lineWidth: 1.2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            if let error = error {
                Text(error)
                    .font(.du(12, weight: .medium))
                    .foregroundColor(DUTheme.error)
            }
        }
    }
}

private struct DUPhoneNumberField: View {
    let title: String
    let countryCode: String
    let placeholder: String
    @Binding var text: String
    let error: String?

    private var sanitizedPhoneBinding: Binding<String> {
        Binding(
            get: { AuthValidator.localPhoneDigits(text) },
            set: { newValue in
                text = AuthValidator.normalizedPhone(newValue)
            }
        )
    }

    private var strokeColor: Color {
        if error != nil {
            return DUTheme.error
        }
        return DUTheme.line
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DUSpacing.sm) {
            Text(title)
                .font(.du(14, weight: .semibold))
                .foregroundColor(DUTheme.inkSecondary)

            HStack(spacing: DUSpacing.md) {
                Text(countryCode)
                    .font(.du(16, weight: .semibold))
                    .foregroundColor(DUTheme.inkSecondary)

                Rectangle()
                    .fill(DUTheme.lineLight)
                    .frame(width: 1, height: 22)

                TextField(placeholder, text: sanitizedPhoneBinding)
                    .keyboardType(.numberPad)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .font(.du(16, weight: .medium))
                    .foregroundColor(DUTheme.ink)
            }
            .padding(.horizontal, DUSpacing.lg)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(DUTheme.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(strokeColor, lineWidth: 1.2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            if let error = error {
                Text(error)
                    .font(.du(12, weight: .medium))
                    .foregroundColor(DUTheme.error)
            }
        }
    }
}

private struct PlaceholderCircleButton: View {
    let assetName: String?
    let systemName: String?
    let title: String
    let action: () -> Void
    private let iconVerticalOffset: CGFloat = 6

    init(assetName: String, title: String, action: @escaping () -> Void) {
        self.assetName = assetName
        self.systemName = nil
        self.title = title
        self.action = action
    }

    init(systemName: String, title: String, action: @escaping () -> Void) {
        self.assetName = nil
        self.systemName = systemName
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: DUSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(DUTheme.backgroundSecondary)
                        .frame(width: 64, height: 64)
                    if let assetName {
                        Image(assetName)
                            .renderingMode(.original)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 48, height: 48)
                            .offset(y: iconVerticalOffset)
                    } else if let systemName {
                        Image(systemName: systemName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 30, height: 30)
                            .foregroundColor(DUTheme.inkSecondary)
                    }
                }
                Text(title)
                    .font(.du(11, weight: .medium))
                    .foregroundColor(DUTheme.inkTertiary)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct RegistrationPasswordPreviewHost: View {
    @StateObject private var viewModel = AuthRegistrationViewModel(
        authService: MockAuthService(),
        initialPhone: "+971 55 123 4567"
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
                    phoneNumber: AuthValidator.normalizedPhone("+971 55 123 4567"),
                    otpCode: AuthValidator.demoRegistrationOTP
                )
            )
        }
    }
}

private struct RegistrationVerifyRegisteredPreviewHost: View {
    @StateObject private var viewModel = AuthRegistrationViewModel(
        authService: MockAuthService(),
        initialPhone: "+971 55 555 1111"
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
