import SwiftUI
import WebKit

struct AIChatView: View {
    @Environment(\.openURL) private var openURL
    @StateObject private var viewModel: AIChatViewModel
    let onNavigate: (AIChatNavigationTarget) -> Void

    @State private var isAnimatingCore = false
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
            let coreSize = min(max(proxy.size.width * 0.34, 110), 150)
            let hPad = min(max(proxy.size.width * 0.06, 18), 28)
            let bottomPad = max(proxy.safeAreaInsets.bottom, 16) + 12

            ZStack {
                deepBackground
                waveLines.opacity(0.15)

                VStack(spacing: 0) {
                    headerBar
                        .padding(.top, 8)

                    Text(viewModel.title)
                        .font(.du(proxy.size.height < 500 ? 24 : 28, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .minimumScaleFactor(0.82)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, DUSpacing.md)
                        .padding(.horizontal, hPad + 4)

                    Spacer(minLength: 8)

                    ZStack {
                        aiCoreOrb(coreSize: coreSize)
                        scatteredPrompts(coreSize: coreSize)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: coreSize * 2.6)

                    Spacer(minLength: 8)

                    voiceSection
                        .padding(.bottom, bottomPad)
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

    // MARK: - Background

    private var deepBackground: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: 0x0D1B3E),
                    Color(hex: 0x162052),
                    Color(hex: 0x1C1F64),
                    Color(hex: 0x2D1B69)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(Color(hex: 0x4821FF).opacity(0.2))
                .frame(width: 220, height: 220)
                .blur(radius: 80)
                .offset(x: -50, y: -80)

            Circle()
                .fill(Color(hex: 0x00E5FF).opacity(0.12))
                .frame(width: 180, height: 180)
                .blur(radius: 90)
                .offset(x: 80, y: 60)
        }
    }

    // MARK: - Wave Lines

    private var waveLines: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                wavePath(w: w, h: h, y0: 0.50, y1: 0.30, cy: 0.60, cx: 0.50)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                wavePath(w: w, h: h, y0: 0.58, y1: 0.38, cy: 0.68, cx: 0.55)
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.6)
                wavePath(w: w, h: h, y0: 0.66, y1: 0.46, cy: 0.76, cx: 0.45)
                    .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                wavePath(w: w, h: h, y0: 0.74, y1: 0.54, cy: 0.84, cx: 0.50)
                    .stroke(Color.white.opacity(0.04), lineWidth: 0.4)
            }
        }
    }

    private func wavePath(w: CGFloat, h: CGFloat, y0: CGFloat, y1: CGFloat, cy: CGFloat, cx: CGFloat) -> Path {
        Path { p in
            p.move(to: CGPoint(x: 0, y: h * y0))
            p.addQuadCurve(to: CGPoint(x: w, y: h * y1), control: CGPoint(x: w * cx, y: h * cy))
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Spacer()
            Button { viewModel.requestNewChat() } label: {
                Image(systemName: "rectangle.on.rectangle")
                    .font(.du(15, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)

            Button { onNavigate(.home) } label: {
                Image(systemName: "xmark")
                    .font(.du(15, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
        }
        .padding(.trailing, 16)
    }

    // MARK: - AI Core Orb

    private func aiCoreOrb(coreSize: CGFloat) -> some View {
        let haloSize = coreSize * 1.6
        let orbitSize = coreSize * 1.26

        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [Color.white.opacity(0.16), .clear]),
                        center: .center, startRadius: 10, endRadius: haloSize / 2
                    )
                )
                .frame(width: haloSize, height: haloSize)

            Circle()
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.08), Color.cyan.opacity(0.35),
                            Color.pink.opacity(0.24), Color.white.opacity(0.08)
                        ]),
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .frame(width: orbitSize, height: orbitSize)
                .rotationEffect(.degrees(coreRotation))

            Circle()
                .trim(from: 0.18, to: 0.92)
                .stroke(
                    AngularGradient(
                        colors: [.clear, Color.cyan.opacity(0.55), Color.pink.opacity(0.55), .clear],
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
                            gradient: Gradient(colors: [
                                Color(hex: 0x00F0FF), Color(hex: 0x4B30FF), Color(hex: 0xFF2E93)
                            ]),
                            startPoint: .topLeading, endPoint: .bottomTrailing
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
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .padding(1)
            )
            .shadow(color: Color(hex: 0x4B30FF).opacity(0.5), radius: 25, x: 0, y: 15)
            .scaleEffect(isAnimatingCore ? 1.04 : 0.96)
            .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: isAnimatingCore)
        }
    }

    // MARK: - Scattered Prompts

    private func scatteredPrompts(coreSize: CGFloat) -> some View {
        ZStack {
            if let t = viewModel.suggestedPrompts[safe: 0] {
                promptCapsule(t, index: 0)
                    .offset(x: -coreSize * 0.55, y: -coreSize * 0.65)
            }
            if let t = viewModel.suggestedPrompts[safe: 1] {
                promptCapsule(t, index: 1)
                    .offset(x: coreSize * 0.50, y: -coreSize * 0.10)
            }
            if let t = viewModel.suggestedPrompts[safe: 2] {
                promptCapsule(t, index: 2)
                    .offset(x: -coreSize * 0.45, y: coreSize * 0.60)
            }
            if let t = viewModel.suggestedPrompts[safe: 3] {
                promptCapsule(t, index: 3)
                    .offset(x: coreSize * 0.35, y: coreSize * 0.55)
            }
        }
    }

    private func promptCapsule(_ text: String, index: Int) -> some View {
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
                .background(.ultraThinMaterial)
                .background(Color.white.opacity(0.1))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .opacity(promptOpacities[safe: index] ?? 1)
        .offset(y: promptOffsets[safe: index] ?? 0)
    }

    // MARK: - Voice Section

    private var voiceSection: some View {
        VStack(spacing: DUSpacing.md) {
            Text("Hold to Talk ~")
                .font(.du(13, weight: .regular))
                .foregroundColor(.white.opacity(0.5))

            Button {
                let gen = UIImpactFeedbackGenerator(style: .medium)
                gen.impactOccurred()
            } label: {
                ZStack {
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [
                                    Color(hex: 0xFF8C42), Color(hex: 0xFF6B8A),
                                    Color(hex: 0xC97DFF), Color(hex: 0x00D4FF),
                                    Color(hex: 0x00E5C3), Color(hex: 0xFF8C42)
                                ],
                                center: .center
                            ),
                            lineWidth: 2.5
                        )
                        .frame(width: 64, height: 64)

                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 56, height: 56)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())

                    Image(systemName: "mic.fill")
                        .font(.du(20, weight: .semibold))
                        .foregroundColor(.white)
                        .shadow(color: Color.cyan.opacity(0.8), radius: 6)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Animations

    private func animatePrompts() {
        for index in 0..<viewModel.suggestedPrompts.count {
            guard index < 4 else { break }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(index) * 0.1 + 0.2)) {
                promptOffsets[index] = 0
                promptOpacities[index] = 1
            }
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
