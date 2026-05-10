import SwiftUI

struct WelcomeView: View {
    let onGetStarted: () -> Void
    let onSignIn: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                WelcomeHomeBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        topBar(safeTop: proxy.safeAreaInsets.top)

                        WelcomeESIMHero()
                            .padding(.top, 38)

                        ESIMPurchaseSummaryCard()
                            .padding(.top, 28)

                        ActivationPathCard()
                            // Activation 卡整体下移，让它与上下模块的留白更均衡。
                            .padding(.top, 42)

                        Spacer(minLength: 12)

                        ctaArea(safeBottom: proxy.safeAreaInsets.bottom)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: proxy.size.height)
                    .padding(.horizontal, 24)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func topBar(safeTop: CGFloat) -> some View {
        HStack(alignment: .center) {
            RedBullMobileWordmark()

            Spacer()

            HStack(spacing: 7) {
                Circle()
                    .fill(WelcomePalette.red)
                    .frame(width: 7, height: 7)
                    .shadow(color: WelcomePalette.red.opacity(0.8), radius: 8, x: 0, y: 0)

                Text("UAE")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.1)
            }
            .foregroundColor(.white.opacity(0.82))
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        // 首页整体重心偏下时，顶部安全区只保留必要距离，让首屏内容更贴近 HTML 原型。
        .padding(.top, max(safeTop - 18, 14))
    }

    private func ctaArea(safeBottom: CGFloat) -> some View {
        VStack(spacing: 12) {
            Button(action: onGetStarted) {
                Text("Get Started")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(primaryButtonBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .shadow(color: WelcomePalette.red.opacity(0.24), radius: 24, x: 0, y: 14)
            }
            .buttonStyle(.plain)

            Button(action: onSignIn) {
                HStack(spacing: 6) {
                    Text("Already have a line?")
                    Text("Sign in")
                        .foregroundColor(.white)
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.58))
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, max(safeBottom, 12))
    }

    private var primaryButtonBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.16),
                WelcomePalette.red,
                Color(hex: 0x9D071D),
                Color(hex: 0x2B0B10)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

}

private enum WelcomePalette {
    static let red = Color(hex: 0xFF1235)
    static let deepRed = Color(hex: 0x7B0619)
    static let gold = Color(hex: 0xF4C15D)
    static let canvas = Color(hex: 0x030305)
}

private struct WelcomeHomeBackground: View {
    var body: some View {
        ZStack {
            WelcomePalette.canvas

            RadialGradient(
                colors: [WelcomePalette.red.opacity(0.24), .clear],
                center: .topTrailing,
                startRadius: 24,
                endRadius: 310
            )

            RadialGradient(
                colors: [WelcomePalette.gold.opacity(0.12), .clear],
                center: .bottomLeading,
                startRadius: 20,
                endRadius: 250
            )

            LinearGradient(
                colors: [Color.black.opacity(0.08), Color.black.opacity(0.72)],
                startPoint: .top,
                endPoint: .bottom
            )

            WelcomeParticleField()
        }
        .ignoresSafeArea()
    }
}

private struct WelcomeParticleField: View {
    private let particles: [WelcomeParticle] = [
        WelcomeParticle(x: 0.08, y: 0.22, size: 4, opacity: 0.16),
        WelcomeParticle(x: 0.74, y: 0.08, size: 3, opacity: 0.12),
        WelcomeParticle(x: 0.92, y: 0.18, size: 5, opacity: 0.14),
        WelcomeParticle(x: 0.28, y: 0.42, size: 6, opacity: 0.18),
        WelcomeParticle(x: 0.78, y: 0.57, size: 4, opacity: 0.13),
        WelcomeParticle(x: 0.36, y: 0.68, size: 3, opacity: 0.12),
        WelcomeParticle(x: 0.88, y: 0.78, size: 5, opacity: 0.16),
        WelcomeParticle(x: 0.18, y: 0.87, size: 4, opacity: 0.12)
    ]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(Color.white.opacity(particle.opacity))
                        .frame(width: particle.size, height: particle.size)
                        .position(
                            x: proxy.size.width * particle.x,
                            y: proxy.size.height * particle.y
                        )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct WelcomeParticle: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let opacity: Double
}

private struct RedBullMobileWordmark: View {
    var body: some View {
        // 顶部品牌区使用真实 SVG 资源，保持与 Web 原型左上角一致。
        Image("RedBullLogo")
            .resizable()
            .renderingMode(.original)
            .scaledToFit()
            .frame(width: 162, height: 32, alignment: .leading)
            .shadow(color: Color.white.opacity(0.18), radius: 14, x: 0, y: 0)
            .accessibilityLabel("Red Bull Mobile")
    }
}

private struct WelcomeESIMHero: View {
    var body: some View {
        // Unified typography: Display style (36pt, .heavy, .rounded) for main page title
        Text("Start your UAE eSIM")
            .font(.system(size: 36, weight: .heavy, design: .rounded))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.82)
    }
}

private struct ESIMGlassChip: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(chipBackground)
                .frame(width: 148, height: 148)
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
                .shadow(color: WelcomePalette.red.opacity(0.26), radius: 34, x: 0, y: 0)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 2)
                .frame(width: 110, height: 110)
                .background(Color.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 24, style: .continuous))

            // eSIM 玻璃芯片内同样加载 Red Bull SVG，避免出现手写品牌字样与真实 Logo 不一致。
            Image("RedBullLogo")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: 112, height: 28)
                .shadow(color: Color.white.opacity(0.22), radius: 18, x: 0, y: 0)
                .shadow(color: WelcomePalette.red.opacity(0.18), radius: 18, x: 0, y: 0)
                .accessibilityHidden(true)
        }
    }

    private var chipBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.14),
                Color.white.opacity(0.035),
                WelcomePalette.red.opacity(0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct ESIMPurchaseSummaryCard: View {
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(Color.black.opacity(0.28))
                    .frame(width: 44, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 18, weight: .bold))
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Device check complete.")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)

                Text("Supports eSIM · UAE activation ready · onboarding can continue.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.54))
                    .lineSpacing(2)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(summaryBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.32), radius: 22, x: 0, y: 16)
    }

    private var summaryBackground: LinearGradient {
        LinearGradient(
            colors: [
                WelcomePalette.red.opacity(0.22),
                WelcomePalette.gold.opacity(0.08),
                Color.white.opacity(0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct ActivationPathCard: View {
    private let steps: [ActivationStep] = [
        ActivationStep(icon: "iphone.gen3", title: "Device supports eSIM"),
        ActivationStep(icon: "checkmark.shield.fill", title: "Verify identity with UAE Pass"),
        ActivationStep(icon: "sparkles", title: "Personalize your experience"),
        ActivationStep(icon: "arrow.triangle.branch", title: "Choose Buy eSIM or Port In")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text("Activation path")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Spacer()

                Text("ready")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(WelcomePalette.red.opacity(0.22), in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(WelcomePalette.red.opacity(0.38), lineWidth: 1)
                    )
            }

            VStack(spacing: 8) {
                ForEach(steps) { step in
                    ActivationStepRow(step: step)
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .background(cardWarmOverlay, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private var cardWarmOverlay: LinearGradient {
        LinearGradient(
            colors: [
                WelcomePalette.red.opacity(0.14),
                WelcomePalette.gold.opacity(0.055),
                Color.white.opacity(0.035)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct ActivationStepRow: View {
    let step: ActivationStep

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.075))
                    .frame(width: 30, height: 30)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )

                Image(systemName: step.icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white.opacity(0.92))
            }

            Text(step.title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.78))
                .lineLimit(2)
                .minimumScaleFactor(0.9)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 42)
        .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.075), lineWidth: 1)
        )
    }
}

private struct ActivationStep: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
}

struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView(onGetStarted: {}, onSignIn: {})
            .duTheme(mode: .dark)
            .environmentObject(AppLanguageStore())
    }
}
