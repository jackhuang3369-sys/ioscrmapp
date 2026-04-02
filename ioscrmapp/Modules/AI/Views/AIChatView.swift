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
            
            // 液体玻璃核心 (Liquid Glass Core)
            ZStack {
                // 深邃底部
                LinearGradient(
                    colors: [Color(hex: 0x0900FF), Color(hex: 0x171B40)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )

                // 内部流动流体 (Fluid Blobs), 与屏幕叠加并缓缓旋转
                ZStack {
                    // Blob 1: 青色
                    Circle()
                        .fill(RadialGradient(colors: [Color.cyan.opacity(0.9), .clear], center: .center, startRadius: 0, endRadius: coreSize * 0.45))
                        .frame(width: coreSize * 1.5, height: coreSize * 1.5)
                        .offset(x: isAnimatingCore ? coreSize * 0.15 : -coreSize * 0.15, y: isAnimatingCore ? -coreSize * 0.15 : coreSize * 0.15)
                        .blur(radius: 12)

                    // Blob 2: 粉紫色
                    Circle()
                        .fill(RadialGradient(colors: [Color.pink.opacity(0.8), .clear], center: .center, startRadius: 0, endRadius: coreSize * 0.45))
                        .frame(width: coreSize * 1.5, height: coreSize * 1.5)
                        .offset(x: isAnimatingCore ? -coreSize * 0.15 : coreSize * 0.15, y: isAnimatingCore ? coreSize * 0.15 : -coreSize * 0.15)
                        .blur(radius: 12)

                    // Blob 3: 珊瑚橙
                    Circle()
                        .fill(RadialGradient(colors: [Color(hex: 0xFF6B6B).opacity(0.95), .clear], center: .center, startRadius: 0, endRadius: coreSize * 0.35))
                        .frame(width: coreSize * 1.2, height: coreSize * 1.2)
                        .offset(x: 0, y: isAnimatingCore ? -coreSize * 0.25 : coreSize * 0.1)
                        .blur(radius: 12)
                }
                .blendMode(.screen)
                .rotationEffect(.degrees(isAnimatingCore ? 360 : 0))
                .animation(.linear(duration: 15).repeatForever(autoreverses: false), value: isAnimatingCore)

                // 静态表面几何高光片 (Glass Specular Reflection)
                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.8), .clear],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: coreSize * 0.45, height: coreSize * 0.35)
                    .rotationEffect(.degrees(-25))
                    .offset(x: -coreSize * 0.15, y: -coreSize * 0.25)
                    .blendMode(.overlay)
                
                // 强烈的内外边缘折射（模拟内阴影营造物理厚度）
                Circle().stroke(Color.white.opacity(0.6), lineWidth: 4).blur(radius: 8).offset(x: -6, y: -6)
                Circle().stroke(Color.black.opacity(0.8), lineWidth: 6).blur(radius: 10).offset(x: 8, y: 8)
                Circle().stroke(Color.pink.opacity(0.7), lineWidth: 5).blur(radius: 12).offset(x: 10, y: -10)
                Circle().stroke(Color.cyan.opacity(0.8), lineWidth: 5).blur(radius: 12).offset(x: -10, y: 10)
                
                // 极细的玻璃边缘包边
                Circle().stroke(Color.white.opacity(0.3), lineWidth: 0.5)
            }
            .clipShape(Circle())
            // 使用非均匀缩放模拟液态 blob 的微小形变蠕动效果
            .scaleEffect(x: isAnimatingCore ? 1.03 : 0.97, y: isAnimatingCore ? 0.97 : 1.03)
            .shadow(color: Color.cyan.opacity(0.4), radius: 20, x: 0, y: 0)
            .shadow(color: Color.purple.opacity(0.3), radius: 40, x: 0, y: 0)
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
                    .offset(x: -coreSize * 0.75, y: -coreSize * 0.3)
            }
            // Order a meal package (左下)
            if let t = viewModel.suggestedPrompts[safe: 1] {
                promptCapsule(t, index: 1)
                    .offset(x: -coreSize * 0.55, y: coreSize * 0.4)
            }
            // Check the weather (右中)
            if let t = viewModel.suggestedPrompts[safe: 2] {
                promptCapsule(t, index: 2)
                    .offset(x: coreSize * 0.85, y: coreSize * 0.1)
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
                .padding(.vertical, 8) // 稍微变薄一点
                .background(.ultraThinMaterial)
                .background(Color.white.opacity(0.05))
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
