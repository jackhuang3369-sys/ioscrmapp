import SwiftUI

struct AuthLoginContainerView: View {
    @StateObject private var viewModel: AuthLoginViewModel
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
                    AuthLogoView()
                    header
                    tabs
                    if let bannerMessage = viewModel.bannerMessage {
                        AuthBannerView(message: bannerMessage, tone: viewModel.bannerTone)
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
        .fullScreenCover(
            isPresented: $viewModel.isRegistrationPresented,
            onDismiss: { viewModel.handleRegistrationDismissal() }
        ) {
            AuthRegistrationContainerView(
                authService: authService,
                initialPhone: viewModel.phoneNumber,
                onSuccess: { phone in
                    viewModel.handleRegistrationSuccess(phone: phone)
                },
                onGoToLogin: { phone in
                    viewModel.handleRegistrationGoToLogin(phone: phone)
                }
            )
        }
    }

    private var header: some View {
        VStack(spacing: DUSpacing.sm) {
            Text("Welcome back")
                .font(.du(28, weight: .bold))
                .foregroundColor(DUTheme.ink)
            Text("Sign in to your DU account")
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
                    Text(mode == .password ? "Password Login" : "OTP Login")
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
            title: "Phone Number",
            countryCode: "+\(AuthValidator.countryCode)",
            placeholder: "52 123 4567",
            text: $viewModel.phoneNumber,
            error: viewModel.phoneError
        )
    }

    private var passwordField: some View {
        DUInputField(
            title: "Password",
            placeholder: "Enter your password",
            text: $viewModel.password,
            error: viewModel.passwordError,
            isSecure: true
        )
    }

    private var otpField: some View {
        VStack(alignment: .leading, spacing: DUSpacing.sm) {
            Text("OTP")
                .font(.du(14, weight: .semibold))
                .foregroundColor(DUTheme.inkSecondary)
            HStack(alignment: .top, spacing: DUSpacing.md) {
                DUInputField(
                    title: nil,
                    placeholder: "Enter OTP",
                    text: $viewModel.otp,
                    error: viewModel.otpError,
                    keyboardType: .numberPad
                )
                SecondaryActionButton(
                    title: viewModel.otpButtonTitle,
                    isEnabled: viewModel.isSendOTPEnabled
                ) {
                    viewModel.sendOTP()
                }
            }
            Text(viewModel.otpExpiryDescription)
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
                    Text("Remember me")
                        .foregroundColor(DUTheme.inkSecondary)
                }
                .font(.du(13, weight: .medium))
            }
            .buttonStyle(.plain)

            Spacer()

            Button("Forgot password?") {
                viewModel.showPlaceholderMessage(for: "Forgot password")
            }
            .font(.du(13, weight: .medium))
            .foregroundColor(DUTheme.cyan)
        }
    }

    private var primaryButton: some View {
        Button {
            viewModel.login()
        } label: {
            HStack(spacing: DUSpacing.sm) {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                }
                Text(viewModel.selectedMode == .password ? "Login" : "Verify and Login")
                    .font(.du(17, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                viewModel.isPrimaryActionEnabled
                    ? DUTheme.brandGradient
                    : LinearGradient(
                        gradient: Gradient(colors: [DUTheme.inkDisabled]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(
                color: viewModel.isPrimaryActionEnabled ? DUTheme.cyan.opacity(0.28) : .clear,
                radius: 18,
                x: 0,
                y: 8
            )
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.isPrimaryActionEnabled)
    }

    private var socialLogin: some View {
        VStack(spacing: DUSpacing.lg) {
            HStack {
                Rectangle()
                    .fill(DUTheme.lineLight)
                    .frame(height: 1)
                Text("Other ways")
                    .font(.du(13, weight: .medium))
                    .foregroundColor(DUTheme.inkTertiary)
                    .padding(.horizontal, DUSpacing.sm)
                Rectangle()
                    .fill(DUTheme.lineLight)
                    .frame(height: 1)
            }

            HStack(spacing: DUSpacing.lg) {
                PlaceholderCircleButton(assetName: "LoginSMSIcon", title: "SMS") {
                    viewModel.showPlaceholderMessage(for: "SMS login")
                }
                PlaceholderCircleButton(systemName: "touchid", title: "Fingerprint") {
                    viewModel.showPlaceholderMessage(for: "Fingerprint login")
                }
                PlaceholderCircleButton(systemName: "faceid", title: "Face") {
                    viewModel.showPlaceholderMessage(for: "Face login")
                }
            }
        }
    }

    private var registerLink: some View {
        HStack(spacing: DUSpacing.xs) {
            Text("New here?")
                .foregroundColor(DUTheme.inkTertiary)
            Button("Create an account") {
                viewModel.openRegistration()
            }
            .foregroundColor(DUTheme.cyan)
        }
        .font(.du(14, weight: .medium))
        .padding(.bottom, DUSpacing.xxxl)
    }
}

private struct AuthRegistrationContainerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AuthRegistrationViewModel
    @State private var showsPasswordStep = false

    private let onSuccess: (String) -> Void
    private let onGoToLogin: (String) -> Void

    init(
        authService: any AuthServicing,
        initialPhone: String,
        onSuccess: @escaping (String) -> Void,
        onGoToLogin: @escaping (String) -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: AuthRegistrationViewModel(
                authService: authService,
                initialPhone: initialPhone
            )
        )
        self.onSuccess = onSuccess
        self.onGoToLogin = onGoToLogin
    }

    var body: some View {
        NavigationView {
            registrationScrollView {
                VStack(spacing: DUSpacing.xl) {
                    RegistrationTopBarView(title: "Create your account", onClose: { dismiss() })
                    AuthLogoView()
                    registrationHeader(
                        title: "Create your account",
                        subtitle: "Verify your phone number before setting a password."
                    )
                    RegistrationStepIndicator(currentStep: 1)
                    if let bannerMessage = viewModel.bannerMessage {
                        AuthBannerView(message: bannerMessage, tone: viewModel.bannerTone)
                    }
                    registrationVerificationCard
                    verificationPrimaryButton
                    if viewModel.showGoToLoginAction {
                        SecondaryLinkButton(title: "Go to Login") {
                            onGoToLogin(viewModel.currentPhoneForLogin)
                            dismiss()
                        }
                    }
                    footerLoginLink
                }
            }
            .background(passwordNavigationLink)
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
    }

    private func registrationScrollView<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        GeometryReader { proxy in
            let topPadding = max(proxy.safeAreaInsets.top, DUSpacing.sm)
            let bottomPadding = DUSpacing.xxxl
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    content()
                    Spacer(minLength: 0)
                }
                .frame(
                    maxWidth: .infinity,
                    minHeight: max(0, proxy.size.height - topPadding - bottomPadding),
                    alignment: .top
                )
                .padding(.horizontal, DUSpacing.xl)
                .padding(.top, topPadding)
                .padding(.bottom, bottomPadding)
            }
            .background(DUTheme.background.ignoresSafeArea())
        }
    }

    private func registrationHeader(title: String, subtitle: String) -> some View {
        VStack(spacing: DUSpacing.sm) {
            Text(title)
                .font(.du(28, weight: .bold))
                .foregroundColor(DUTheme.ink)
            Text(subtitle)
                .font(.du(15, weight: .medium))
                .foregroundColor(DUTheme.inkTertiary)
                .multilineTextAlignment(.center)
        }
    }

    private var registrationVerificationCard: some View {
        VStack(spacing: DUSpacing.lg) {
            DUPhoneNumberField(
                title: "Phone Number",
                countryCode: "+\(AuthValidator.countryCode)",
                placeholder: "52 123 4567",
                text: $viewModel.phoneNumber,
                error: viewModel.phoneError,
                storageMode: .localDigits
            )

            VStack(alignment: .leading, spacing: DUSpacing.sm) {
                Text("OTP")
                    .font(.du(14, weight: .semibold))
                    .foregroundColor(DUTheme.inkSecondary)

                HStack(alignment: .top, spacing: DUSpacing.md) {
                    DUInputField(
                        title: nil,
                        placeholder: "Enter 6-digit OTP",
                        text: $viewModel.otp,
                        error: viewModel.otpError,
                        keyboardType: .numberPad
                    )

                    SecondaryActionButton(
                        title: viewModel.otpButtonTitle,
                        isEnabled: viewModel.isSendOTPEnabled
                    ) {
                        viewModel.sendOTP()
                    }
                }

                Text(viewModel.otpExpiryDescription)
                    .font(.du(12, weight: .medium))
                    .foregroundColor(DUTheme.inkTertiary)
            }
        }
        .padding(DUSpacing.lg)
        .duCardStyle()
    }

    private var verificationPrimaryButton: some View {
        PrimaryActionButton(
            title: "Verify and Continue",
            isEnabled: viewModel.isVerifyEnabled,
            isLoading: viewModel.isLoading
        ) {
            Task {
                let result = await viewModel.verifyForPasswordSetup()
                if case .advanceToPassword = result {
                    showsPasswordStep = true
                }
            }
        }
    }

    private var footerLoginLink: some View {
        HStack(spacing: DUSpacing.xs) {
            Text("Already have an account?")
                .foregroundColor(DUTheme.inkTertiary)
            Button("Back to login") {
                onGoToLogin(viewModel.currentPhoneForLogin)
                dismiss()
            }
            .foregroundColor(DUTheme.cyan)
        }
        .font(.du(14, weight: .medium))
    }

    private var registrationPasswordScreen: some View {
        registrationScrollView {
            VStack(spacing: DUSpacing.xl) {
                RegistrationTopBarView(
                    title: "Set your password",
                    onBack: { showsPasswordStep = false },
                    onClose: { dismiss() }
                )
                AuthLogoView()
                registrationHeader(
                    title: "Set your password",
                    subtitle: "Use this password for future password login."
                )
                RegistrationStepIndicator(currentStep: 2)
                if let bannerMessage = viewModel.bannerMessage {
                    AuthBannerView(message: bannerMessage, tone: viewModel.bannerTone)
                }
                VStack(spacing: DUSpacing.lg) {
                    VerifiedPhoneSummary(phone: viewModel.verifiedPhoneSummary)
                    DUInputField(
                        title: "New Password",
                        placeholder: "Enter a secure password",
                        text: $viewModel.password,
                        error: viewModel.passwordError,
                        isSecure: true
                    )
                    DUInputField(
                        title: "Confirm Password",
                        placeholder: "Re-enter your password",
                        text: $viewModel.confirmPassword,
                        error: viewModel.confirmPasswordError,
                        isSecure: true
                    )
                }
                .padding(DUSpacing.lg)
                .duCardStyle()

                PrimaryActionButton(
                    title: "Complete Registration",
                    isEnabled: viewModel.isRegisterEnabled,
                    isLoading: viewModel.isLoading
                ) {
                    Task {
                        let didRegister = await viewModel.submitRegistration()
                        guard didRegister else {
                            return
                        }

                        try? await Task.sleep(nanoseconds: 900_000_000)
                        onSuccess(viewModel.currentPhoneForLogin)
                        dismiss()
                    }
                }
            }
        }
        .navigationBarHidden(true)
    }

    private var passwordNavigationLink: some View {
        NavigationLink(
            destination: registrationPasswordScreen,
            isActive: $showsPasswordStep
        ) {
            EmptyView()
        }
        .hidden()
    }
}

private struct AuthLogoView: View {
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

private struct RegistrationTopBarView: View {
    let title: String
    var onBack: (() -> Void)? = nil
    let onClose: () -> Void

    var body: some View {
        HStack {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.du(16, weight: .bold))
                        .foregroundColor(DUTheme.ink)
                        .frame(width: 36, height: 36)
                        .background(DUTheme.panel)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            } else {
                Color.clear
                    .frame(width: 36, height: 36)
            }

            Spacer()

            Text(title)
                .font(.du(15, weight: .semibold))
                .foregroundColor(DUTheme.inkSecondary)

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.du(14, weight: .bold))
                    .foregroundColor(DUTheme.ink)
                    .frame(width: 36, height: 36)
                    .background(DUTheme.panel)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }
}

private struct RegistrationStepIndicator: View {
    let currentStep: Int

    var body: some View {
        HStack(spacing: DUSpacing.sm) {
            ForEach(1...2, id: \.self) { step in
                VStack(spacing: DUSpacing.xs) {
                    Capsule()
                        .fill(step <= currentStep ? DUTheme.cyan : DUTheme.lineLight)
                        .frame(width: 96, height: 8)
                    Text("Step \(step) of 2")
                        .font(.du(11, weight: .medium))
                        .foregroundColor(step == currentStep ? DUTheme.cyan : DUTheme.inkTertiary)
                }
            }
        }
    }
}

private struct VerifiedPhoneSummary: View {
    let phone: String

    var body: some View {
        VStack(alignment: .leading, spacing: DUSpacing.sm) {
            Text("Verified Phone")
                .font(.du(13, weight: .semibold))
                .foregroundColor(DUTheme.inkSecondary)

            HStack(spacing: DUSpacing.md) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(DUTheme.success)
                Text(phone)
                    .font(.du(16, weight: .semibold))
                    .foregroundColor(DUTheme.ink)
                Spacer()
            }
            .padding(.horizontal, DUSpacing.lg)
            .frame(height: 52)
            .background(DUTheme.successBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}

private struct AuthBannerView: View {
    let message: String
    let tone: AuthBannerTone

    private var colors: (background: Color, foreground: Color, icon: String) {
        switch tone {
        case .info:
            return (DUTheme.cyanBackground, DUTheme.cyan, "info.circle.fill")
        case .success:
            return (DUTheme.successBackground, DUTheme.success, "checkmark.circle.fill")
        case .error:
            return (DUTheme.errorBackground, DUTheme.error, "exclamationmark.triangle.fill")
        }
    }

    var body: some View {
        HStack(spacing: DUSpacing.sm) {
            Image(systemName: colors.icon)
            Text(message)
                .font(.du(13, weight: .semibold))
                .multilineTextAlignment(.leading)
            Spacer()
        }
        .foregroundColor(colors.foreground)
        .padding(DUSpacing.lg)
        .background(colors.background)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct PrimaryActionButton: View {
    let title: String
    let isEnabled: Bool
    let isLoading: Bool
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

private struct SecondaryActionButton: View {
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

private struct SecondaryLinkButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.du(15, weight: .semibold))
                .foregroundColor(DUTheme.cyan)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(DUTheme.cyanBackground)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
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

private enum DUPhoneStorageMode {
    case normalized
    case localDigits
}

private struct DUPhoneNumberField: View {
    let title: String
    let countryCode: String
    let placeholder: String
    @Binding var text: String
    let error: String?
    var storageMode: DUPhoneStorageMode = .normalized

    private var sanitizedPhoneBinding: Binding<String> {
        Binding(
            get: { AuthValidator.localPhoneDigits(text) },
            set: { newValue in
                switch storageMode {
                case .normalized:
                    text = AuthValidator.normalizedPhone(newValue)
                case .localDigits:
                    text = AuthValidator.localPhoneDigits(newValue)
                }
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

struct AuthLoginContainerView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AuthLoginContainerView(sessionStore: SessionStore(), authService: MockAuthService())
                .previewDisplayName("Password Mode")

            AuthLoginContainerView(
                sessionStore: SessionStore(defaults: UserDefaults(suiteName: "preview.otp") ?? .standard),
                authService: MockAuthService()
            )
            .previewDisplayName("OTP Mode")

            AuthRegistrationContainerView(
                authService: MockAuthService(),
                initialPhone: "521234567",
                onSuccess: { _ in },
                onGoToLogin: { _ in }
            )
            .previewDisplayName("Registration")
        }
    }
}
