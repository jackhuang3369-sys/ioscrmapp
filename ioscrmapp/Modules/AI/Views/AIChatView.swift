import SwiftUI
import WebKit

struct AIChatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @StateObject private var viewModel: AIChatViewModel
    let onNavigate: (AIChatNavigationTarget) -> Void

    @State private var isAnimatingCore = false
    @State private var rippleScale: CGFloat = 1.0
    @State private var rippleOpacity: Double = 0.8
    @State private var coreRotation: Double = 0
    @State private var promptOffsets: [CGFloat] = [50, 50, 50, 50]
    @State private var promptOpacities: [Double] = [0, 0, 0, 0]

    init(
        custSubInfo: CustSubInfo,
        language: AppLanguage,
        aiChatService: any AIChatServicing,
        onNavigate: @escaping (AIChatNavigationTarget) -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: AIChatViewModel(
                custSubInfo: custSubInfo,
                language: language,
                aiChatService: aiChatService
            )
        )
        self.onNavigate = onNavigate
    }

    var body: some View {
        GeometryReader { proxy in
            let horizontalPadding = min(max(proxy.size.width * 0.06, 18), 28)
            let titleTopPadding = max(proxy.size.height * 0.03, DUSpacing.md)
            let coreSize = min(max(proxy.size.width * 0.42, 138), 176)
            let voiceButtonSize = min(max(proxy.size.width * 0.2, 68), 80)
            let contentBottomPadding = max(proxy.safeAreaInsets.bottom, 16) + 12

            ZStack {
                auroraBackground

                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.85)

                VStack(spacing: 0) {
                    header(topPadding: max(proxy.safeAreaInsets.top, 18))

                    VStack(alignment: .center, spacing: 8) {
                        Text("AI Assistant")
                            .font(.du(13, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.62))
                            .tracking(3)
                            .textCase(.uppercase)

                        Text(viewModel.title)
                            .font(.du(proxy.size.height < 620 ? 24 : 26, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .minimumScaleFactor(0.82)
                    }
                    .padding(.top, titleTopPadding)
                    .padding(.horizontal, horizontalPadding)

                    Spacer(minLength: max(proxy.size.height * 0.035, 16))

                    aiCoreFeature(coreSize: coreSize)

                    Spacer(minLength: max(proxy.size.height * 0.05, 20))

                    scatteredPrompts
                        .padding(.horizontal, horizontalPadding)

                    Spacer(minLength: max(proxy.size.height * 0.04, 16))

                    voiceActionBar(buttonSize: voiceButtonSize)
                        .padding(.bottom, contentBottomPadding)
                }
            }
        }
        .onAppear {
            isAnimatingCore = true
            withAnimation(.linear(duration: 25).repeatForever(autoreverses: false)) {
                coreRotation = 360
            }
            animatePrompts()
        }
    }

    private var auroraBackground: some View {
        ZStack {
            Color.black.opacity(0.12)

            Circle()
                .fill(Color(hex: 0x4821FF))
                .frame(width: 250, height: 250)
                .blur(radius: 60)
                .offset(x: isAnimatingCore ? -60 : 40, y: isAnimatingCore ? -120 : -80)

            Circle()
                .fill(Color(hex: 0x00E5FF))
                .frame(width: 200, height: 200)
                .blur(radius: 70)
                .offset(x: isAnimatingCore ? 80 : -40, y: isAnimatingCore ? 60 : 120)

            Circle()
                .fill(Color(hex: 0xFF2180).opacity(0.6))
                .frame(width: 180, height: 180)
                .blur(radius: 80)
                .offset(x: isAnimatingCore ? -30 : 60, y: isAnimatingCore ? 140 : 40)
        }
        .animation(.easeInOut(duration: 8).repeatForever(autoreverses: true), value: isAnimatingCore)
    }

    private func header(topPadding: CGFloat) -> some View {
        HStack {
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.du(16, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .padding(.trailing, 20)
            .padding(.top, topPadding)
        }
    }

    private func aiCoreFeature(coreSize: CGFloat) -> some View {
        let haloSize = coreSize * 1.6
        let orbitSize = coreSize * 1.26

        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [Color.white.opacity(0.16), .clear]),
                        center: .center,
                        startRadius: 10,
                        endRadius: haloSize / 2
                    )
                )
                .frame(width: haloSize, height: haloSize)

            Circle()
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.08),
                            Color.cyan.opacity(0.35),
                            Color.pink.opacity(0.24),
                            Color.white.opacity(0.08)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .frame(width: orbitSize, height: orbitSize)
                .rotationEffect(.degrees(coreRotation))

            Circle()
                .trim(from: 0.18, to: 0.92)
                .stroke(
                    AngularGradient(
                        colors: [
                            Color.clear,
                            Color.cyan.opacity(0.55),
                            Color.pink.opacity(0.55),
                            Color.clear
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 1.2, lineCap: .round)
                )
                .frame(width: orbitSize * 1.08, height: orbitSize * 1.08)
                .rotationEffect(.degrees(-coreRotation * 0.65))

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(hex: 0x00F0FF), Color(hex: 0x4B30FF), Color(hex: 0xFF2E93)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Circle()
                    .fill(Color(hex: 0xFFBDE6))
                    .frame(width: coreSize * 0.53, height: coreSize * 0.53)
                    .blur(radius: 15)
                    .offset(x: isAnimatingCore ? -20 : 15, y: isAnimatingCore ? -25 : 10)

                Circle()
                    .fill(Color(hex: 0x82FFF0))
                    .frame(width: coreSize * 0.46, height: coreSize * 0.46)
                    .blur(radius: 20)
                    .offset(x: isAnimatingCore ? 20 : -15, y: isAnimatingCore ? 20 : -10)
            }
            .frame(width: coreSize, height: coreSize)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.white.opacity(0.6), .clear, .clear]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(1)
            )
            .shadow(color: Color(hex: 0x4B30FF).opacity(0.5), radius: 25, x: 0, y: 15)
            .scaleEffect(isAnimatingCore ? 1.04 : 0.96)
            .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: isAnimatingCore)
        }
    }

    private var scatteredPrompts: some View {
        VStack(spacing: 12) {
            if let firstPrompt = viewModel.suggestedPrompts[safe: 0] {
                promptCapsule(firstPrompt, index: 0, isFullWidth: true)
            }
            HStack(alignment: .top, spacing: 12) {
                if let secondPrompt = viewModel.suggestedPrompts[safe: 1] {
                    promptCapsule(secondPrompt, index: 1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let thirdPrompt = viewModel.suggestedPrompts[safe: 2] {
                    promptCapsule(thirdPrompt, index: 2)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
    }

    private func promptCapsule(_ text: String, index: Int, isFullWidth: Bool = false) -> some View {
        Button {
            viewModel.sendSuggestedPrompt(text)
        } label: {
            Text(text)
                .font(.du(13, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: isFullWidth ? .infinity : nil)
                .background(.ultraThinMaterial)
                .background(Color.white.opacity(0.1))
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .opacity(promptOpacities[safe: index] ?? 1)
        .offset(y: promptOffsets[safe: index] ?? 0)
    }

    private func voiceActionBar(buttonSize: CGFloat) -> some View {
        VStack(spacing: DUSpacing.sm) {
            Text("Hold to Talk")
                .font(.du(12, weight: .regular))
                .foregroundColor(.white.opacity(0.5))

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(rippleOpacity * 0.5), lineWidth: 1)
                    .frame(width: buttonSize + 10, height: buttonSize + 10)
                    .scaleEffect(rippleScale)

                Button {
                    triggerVoiceAnimation()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: buttonSize, height: buttonSize)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                            )
                            .shadow(color: Color.cyan.opacity(0.18), radius: 16, x: 0, y: 0)

                        Image(systemName: "mic.fill")
                            .font(.du(buttonSize > 72 ? 22 : 20, weight: .semibold))
                            .foregroundColor(.white)
                            .shadow(color: Color.cyan.opacity(0.8), radius: 6, x: 0, y: 0)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear {
            startRippleAnimation()
        }
    }

    private func animatePrompts() {
        for index in 0..<viewModel.suggestedPrompts.count {
            guard index < 4 else { break }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(index) * 0.1 + 0.2)) {
                promptOffsets[index] = 0
                promptOpacities[index] = 1
            }
        }
    }

    private func startRippleAnimation() {
        withAnimation(.easeOut(duration: 2).repeatForever(autoreverses: false)) {
            rippleScale = 2.0
            rippleOpacity = 0.0
        }
    }

    private func triggerVoiceAnimation() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        rippleScale = 1.0
        rippleOpacity = 0.8
        withAnimation(.easeOut(duration: 0.5)) {
            rippleScale = 2.5
            rippleOpacity = 0.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.rippleScale = 1.0
            self.rippleOpacity = 0.8
            self.startRippleAnimation()
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
