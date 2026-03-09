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
        ScrollView(showsIndicators: false) {
            VStack(spacing: DUSpacing.xxl) {
                Spacer(minLength: 12)
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
                    mockHelper
                    socialLogin
                    registerLink
                }
            }
            .padding(.horizontal, DUSpacing.xl)
            .padding(.vertical, DUSpacing.xxxl)
        }
        .background(DUTheme.background.ignoresSafeArea())
    }

    private var logo: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(DUTheme.brandGradient)
                .frame(width: 88, height: 88)
                .shadow(color: DUTheme.cyan.opacity(0.25), radius: 18, x: 0, y: 8)
            Text("DU")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
        }
    }

    private var header: some View {
        VStack(spacing: DUSpacing.sm) {
            Text("Welcome back")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(DUTheme.ink)
            Text("Sign in to your DU account")
                .font(.system(size: 15, weight: .medium))
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
                        .font(.system(size: 15, weight: .semibold))
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
        DUInputField(
            title: "Phone Number",
            placeholder: "+971 50 123 4567",
            text: $viewModel.phoneNumber,
            error: viewModel.phoneError,
            keyboardType: .phonePad
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
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DUTheme.inkSecondary)
            HStack(alignment: .top, spacing: DUSpacing.md) {
                DUInputField(
                    title: nil,
                    placeholder: "Enter 6-digit OTP",
                    text: $viewModel.otp,
                    error: viewModel.otpError,
                    keyboardType: .numberPad
                )
                Button {
                    viewModel.sendOTP()
                } label: {
                    Text(viewModel.otpButtonTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(viewModel.isSendOTPEnabled ? DUTheme.cyan : DUTheme.inkDisabled)
                        .frame(width: 114, height: 52)
                        .background(viewModel.isSendOTPEnabled ? DUTheme.cyanBackground : DUTheme.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.isSendOTPEnabled)
            }
            Text(viewModel.otpExpiryDescription)
                .font(.system(size: 12, weight: .medium))
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
                .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.plain)

            Spacer()

            Button("Forgot password?") {
                viewModel.showPlaceholderMessage(for: "Forgot password")
            }
            .font(.system(size: 13, weight: .medium))
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
                        .accentColor(.white)
                }
                Text(viewModel.selectedMode == .password ? "Login" : "Verify and Login")
                    .font(.system(size: 17, weight: .bold))
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

    private var mockHelper: some View {
        VStack(spacing: DUSpacing.sm) {
            Text(viewModel.mockHint)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(DUTheme.cyan)
            Text("Use \(AuthValidator.demoPhone) to test the mock flow.")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DUTheme.inkTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DUSpacing.lg)
        .background(DUTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)
    }

    private var socialLogin: some View {
        VStack(spacing: DUSpacing.lg) {
            HStack {
                Rectangle()
                    .fill(DUTheme.lineLight)
                    .frame(height: 1)
                Text("Other ways")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DUTheme.inkTertiary)
                    .padding(.horizontal, DUSpacing.sm)
                Rectangle()
                    .fill(DUTheme.lineLight)
                    .frame(height: 1)
            }

            HStack(spacing: DUSpacing.lg) {
                PlaceholderCircleButton(symbol: "faceid", title: "Biometrics") {
                    viewModel.showPlaceholderMessage(for: "Biometric login")
                }
                PlaceholderCircleButton(symbol: "message", title: "SMS") {
                    viewModel.showPlaceholderMessage(for: "Social login")
                }
                PlaceholderCircleButton(symbol: "lock.shield", title: "Secure") {
                    viewModel.showPlaceholderMessage(for: "Secure sign in")
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
        .font(.system(size: 14, weight: .medium))
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
                .font(.system(size: 13, weight: .semibold))
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

    private var shadowColor: Color {
        if error != nil {
            return DUTheme.errorBackground
        }
        return .clear
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DUSpacing.sm) {
            if let title = title {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
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
                .font(.system(size: 16, weight: .medium))
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
            .background(DUTheme.panel)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(strokeColor, lineWidth: 1.2)
            )
            .shadow(color: shadowColor, radius: 0, x: 0, y: 0)

            if let error = error {
                Text(error)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DUTheme.error)
            }
        }
    }
}

private struct PlaceholderCircleButton: View {
    let symbol: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DUSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(DUTheme.backgroundSecondary)
                        .frame(width: 52, height: 52)
                    Image(systemName: symbol)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(DUTheme.inkSecondary)
                }
                Text(title)
                    .font(.system(size: 11, weight: .medium))
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
