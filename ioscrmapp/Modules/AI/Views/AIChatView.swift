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

                VStack(spacing: 0) {
                    headerBar
                        .padding(.top, 8)

                    Text(viewModel.title)
                        .font(.du(proxy.size.height < 500 ? 28 : 32, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .minimumScaleFactor(0.82)
                        .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, DUSpacing.md)
                        .padding(.horizontal, hPad + 4)

                    Spacer(minLength: 8)

                    ZStack {
                        orbMesh
                        aiCoreOrb(coreSize: coreSize)
                        scatteredPrompts(coreSize: coreSize)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: coreSize * 2.6)
                    .offset(y: -20)

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
                    Color(hex: 0x184CC2),
                    Color(hex: 0x1A1E50),
                    Color(hex: 0x151336)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )

            // 底部深紫色的朦胧背景光（模拟网格下方的背景）
            VStack {
                Spacer()
                Circle()
                    .fill(Color(hex: 0x9333EA).opacity(0.4))
                    .frame(width: 400, height: 400)
                    .blur(radius: 120)
                    .offset(y: 200)
            }
        }
    }

    // MARK: - Orb Mesh Background

    private var orbMesh: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 60, style: .continuous)
                    .stroke(Color.white.opacity(0.04), lineWidth: 1.5)
                    .frame(width: 320, height: 120)
                    .rotationEffect(.degrees(Double(i) * 45))
            }
        }
        .frame(width: 320, height: 320)
        .rotationEffect(.degrees(coreRotation * 0.15))
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Spacer()
            Button { viewModel.requestNewChat() } label: {
                Image(systemName: "message") // 更简洁的对话图标
                    .font(.du(18, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)

            Button { onNavigate(.home) } label: {
                Image(systemName: "xmark")
                    .font(.du(20, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
        .padding(.trailing, 16)
    }

    // MARK: - AI Core Orb

    private func aiCoreOrb(coreSize: CGFloat) -> some View {
        let auraSize = coreSize * 1.6
        
        return ZStack {
            // 背景慢速旋转的多彩光环 (Aura)
            Circle()
                .fill(
                    AngularGradient(
                        colors: [.clear, Color.cyan.opacity(0.4), Color.pink.opacity(0.5), Color.purple.opacity(0.4), .clear],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    )
                )
                .frame(width: auraSize, height: auraSize)
                .blur(radius: 20)
                .rotationEffect(.degrees(coreRotation * 0.4))
            
            // 液体玻璃核心极为关键的光影合成
            ZStack {
                // 深邃底部
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x0900FF), Color(hex: 0x171B40)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )

                // 流体内光 (内部光源) - 避免使用 mix-blend-mode 以防在视图层中异常变白
                Circle()
                    .fill(RadialGradient(colors: [Color.cyan.opacity(0.8), .clear], center: .topLeading, startRadius: 0, endRadius: coreSize * 0.5))
                    .frame(width: coreSize, height: coreSize)
                    .offset(x: isAnimatingCore ? 10 : -10, y: isAnimatingCore ? -10 : 10)
                
                Circle()
                    .fill(RadialGradient(colors: [Color.pink.opacity(0.8), .clear], center: .bottomTrailing, startRadius: 0, endRadius: coreSize * 0.5))
                    .frame(width: coreSize, height: coreSize)
                    .offset(x: isAnimatingCore ? -10 : 10, y: isAnimatingCore ? 10 : -10)
                
                // 静态表面高光反射片
                GeometryReader { geo in
                    Path { path in
                        let w = geo.size.width
                        let h = geo.size.height
                        path.move(to: CGPoint(x: w * 0.15, y: h * 0.25))
                        path.addQuadCurve(to: CGPoint(x: w * 0.85, y: h * 0.25), control: CGPoint(x: w * 0.5, y: -h * 0.1))
                        path.addQuadCurve(to: CGPoint(x: w * 0.15, y: h * 0.25), control: CGPoint(x: w * 0.5, y: h * 0.15))
                    }
                    .fill(LinearGradient(colors: [Color.white.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom))
                }
                
                // 完美的玻璃体积感（内阴影效果替代手法）：偏移遮罩线条
                Circle().stroke(Color.white, lineWidth: 6).blur(radius: 5).offset(x: -6, y: -6)
                Circle().stroke(Color.black.opacity(0.8), lineWidth: 12).blur(radius: 10).offset(x: 8, y: 8)
                Circle().stroke(Color.pink.opacity(0.6), lineWidth: 8).blur(radius: 10).offset(x: 10, y: -5)
                Circle().stroke(Color.cyan.opacity(0.7), lineWidth: 8).blur(radius: 10).offset(x: -10, y: 5)
            }
            .clipShape(Circle())
            // 极细物理包边
            .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
            .scaleEffect(x: isAnimatingCore ? 1.02 : 0.98, y: isAnimatingCore ? 0.98 : 1.02)
            .shadow(color: Color.cyan.opacity(0.3), radius: 20, x: 0, y: 0)
            .shadow(color: Color.purple.opacity(0.2), radius: 40, x: 0, y: 0)
            .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: isAnimatingCore)
            .frame(width: coreSize, height: coreSize)
        }
    }

    // MARK: - Scattered Prompts

    private func scatteredPrompts(coreSize: CGFloat) -> some View {
        ZStack {
            // Book a flight (左上)
            if let t = viewModel.suggestedPrompts[safe: 0] {
                promptCapsule(t, index: 0)
                    .offset(x: -coreSize * 1.0, y: -coreSize * 0.5)
            }
            // Order a meal package (左下)
            if let t = viewModel.suggestedPrompts[safe: 1] {
                promptCapsule(t, index: 1)
                    .offset(x: -coreSize * 0.9, y: coreSize * 0.5)
            }
            // Check the weather (右中)
            if let t = viewModel.suggestedPrompts[safe: 2] {
                promptCapsule(t, index: 2)
                    .offset(x: coreSize * 1.1, y: coreSize * 0.1)
            }
        }
    }

    private func promptCapsule(_ text: String, index: Int) -> some View {
        Button {
            viewModel.sendSuggestedPrompt(text)
        } label: {
            Text(text)
                .font(.du(13, weight: .regular))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .lineLimit(3)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: 120) // 强制折行保证不变成横向面条
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.3), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)
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
                    // 更细更多彩的动态圆环
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [
                                    Color.cyan, Color.purple, Color.pink,
                                    Color.orange, Color.yellow, Color.green, Color.cyan
                                ],
                                center: .center
                            ),
                            lineWidth: 2.5
                        )
                        .frame(width: 72, height: 72)
                        .rotationEffect(.degrees(coreRotation))

                    Circle()
                        .fill(Color(hex: 0x1E1B4B).opacity(0.4))
                        .frame(width: 54, height: 54)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())

                    Image(systemName: "mic") // 内部改为细线形话筒
                        .font(.du(22, weight: .regular))
                        .foregroundColor(.white)
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
