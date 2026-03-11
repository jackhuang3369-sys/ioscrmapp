import SwiftUI

struct AuthLoginContainerView: View {
    @StateObject private var viewModel: AuthLoginViewModel

    init(sessionStore: SessionStore, authService: any AuthServicing) {
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
                    logo
                    header
                    tabs
                    if let bannerMessage = viewModel.bannerMessage {
                        banner(message: bannerMessage, tone: viewModel.bannerTone)
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
    }

    private var logo: some View {
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
                Button {
                    viewModel.sendOTP()
                } label: {
                    Text(viewModel.otpButtonTitle)
                        .font(.du(14, weight: .semibold))
                        .foregroundColor(viewModel.isSendOTPEnabled ? DUTheme.cyan : DUTheme.inkDisabled)
                        .frame(width: 114, height: 52)
                        .background(viewModel.isSendOTPEnabled ? DUTheme.cyanBackground : DUTheme.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.isSendOTPEnabled)
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
                viewModel.showPlaceholderMessage(for: "Registration")
            }
            .foregroundColor(DUTheme.cyan)
        }
        .font(.du(14, weight: .medium))
        .padding(.bottom, DUSpacing.xxxl)
    }

    private func banner(message: String, tone: AuthLoginViewModel.BannerTone) -> some View {
        let background: Color
        let foreground: Color

        switch tone {
        case .info:
            background = DUTheme.cyanBackground
            foreground = DUTheme.cyan
        case .success:
            background = DUTheme.successBackground
            foreground = DUTheme.success
        case .error:
            background = DUTheme.errorBackground
            foreground = DUTheme.error
        }

        return HStack(spacing: DUSpacing.sm) {
            Image(systemName: tone == .error ? "exclamationmark.triangle.fill" : "sparkles")
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
        }
    }
}
