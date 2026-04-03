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

                // --- Home Layer (Layer 1) ---
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
                        .frame(maxWidth: 250, alignment: .leading) // 对标 HTML max-width: 250px
                        .padding(.top, DUSpacing.md)
                        .padding(.horizontal, hPad + 4)

                    Spacer(minLength: 8)

                    ZStack {
                        orbMesh
                        aiCoreOrb(coreSize: coreSize)
                        scatteredPrompts(coreSize: coreSize)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: coreSize * 2.8) // 稍微增加高度适应更大的 OrbMesh
                    .offset(y: -20)

                    Spacer(minLength: 8)

                    voiceSection
                        .padding(.bottom, bottomPad)
                }
                .blur(radius: viewModel.currentStep == .home ? 0 : 30) // 增加模糊度
                .scaleEffect(viewModel.currentStep == .home ? 1.0 : 0.85) // 增加缩放感
                .opacity(viewModel.currentStep == .home ? 1.0 : 0.0) // 隐藏以提升性能
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.currentStep)

                // --- Layer 2: Offers List ---
                if viewModel.currentStep == .offersList {
                    offersListLayer(hPad: hPad, bottomPad: bottomPad)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                        .zIndex(2)
                }

                // --- Layer 3: Offer Details ---
                if case .offerDetails(let offer) = viewModel.currentStep {
                    offerDetailsLayer(offer: offer, hPad: hPad, bottomPad: bottomPad)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                        .zIndex(3)
                }

                // --- Layer 4: Success ---
                if viewModel.currentStep == .success {
                    successLayer(hPad: hPad)
                        .transition(.asymmetric(insertion: .scale(scale: 0.95).combined(with: .opacity), removal: .opacity))
                        .zIndex(4)
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
            // 对标 HTML SVG 路径的三角形涟漪线条背景
            ForEach(0..<5, id: \.self) { i in
                TriangleRipplePath()
                    .stroke(
                        [Color.cyan, Color.purple, Color.pink, Color.cyan, Color.purple][i % 5].opacity(0.2),
                        lineWidth: i < 3 ? 1.5 : 1.0
                    )
                    .frame(width: 400, height: 400)
                    .scaleEffect(1.0 - CGFloat(i) * 0.15)
                    .rotationEffect(.degrees(Double(i) * 15))
            }
        }
        .frame(width: 400, height: 400)
        .rotationEffect(.degrees(coreRotation * 0.2))
        .opacity(0.8)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            if viewModel.currentStep != .home {
                Button { viewModel.goBack() } label: {
                    Image(systemName: "chevron.left")
                        .font(.du(20, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .move(edge: .leading)))
            }
            
            Spacer()
            
            Button { viewModel.requestNewChat() } label: {
                Image(systemName: "message")
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
        .padding(.horizontal, 16)
        .animation(.spring(), value: viewModel.currentStep)
    }

    // MARK: - AI Core Orb

    private func aiCoreOrb(coreSize: CGFloat) -> some View {
        let auraSize = coreSize * 1.8
        
        return ZStack {
            // 背景慢速旋转的多彩光环 (Aura) - 对标 HTML conic-gradient
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
                .blur(radius: 25)
                .rotationEffect(.degrees(coreRotation * 0.5))
            
            // 液体玻璃核心极为关键的光影合成
            ZStack {
                // 深邃底部
                FluidBlobShape(offset: isAnimatingCore ? 1 : 0)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x0900FF), Color(hex: 0x171B40)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )

                // 内部流动液体 (Orb Fluid)
                OrbInternalFluid(isAnimating: isAnimatingCore)
                    .mask(FluidBlobShape(offset: isAnimatingCore ? 1 : 0))
                
                // 表面静态反射
                GlassReflection()
                    .opacity(0.6)
                
                // 完美的玻璃体积感：多层内阴影模拟
                FluidBlobShape(offset: isAnimatingCore ? 1 : 0)
                    .stroke(Color.white.opacity(0.8), lineWidth: 10)
                    .blur(radius: 8)
                    .offset(x: -8, y: -8)
                    .mask(FluidBlobShape(offset: isAnimatingCore ? 1 : 0))
                
                FluidBlobShape(offset: isAnimatingCore ? 1 : 0)
                    .stroke(Color.black.opacity(0.9), lineWidth: 15)
                    .blur(radius: 12)
                    .offset(x: 10, y: 10)
                    .mask(FluidBlobShape(offset: isAnimatingCore ? 1 : 0))
            }
            .frame(width: coreSize, height: coreSize)
            .shadow(color: Color.cyan.opacity(0.4), radius: 30, x: 0, y: 0)
            .shadow(color: Color.purple.opacity(0.3), radius: 50, x: 0, y: 0)
            .scaleEffect(isAnimatingCore ? 1.03 : 0.97)
            .animation(.easeInOut(duration: 5).repeatForever(autoreverses: true), value: isAnimatingCore)
        }
    }

    // MARK: - Scattered Prompts

    private func scatteredPrompts(coreSize: CGFloat) -> some View {
        ZStack {
            // tag-1: Book a flight (左上) - 对标 HTML tag-1: top -20, left -140
            if let t = viewModel.suggestedPrompts[safe: 0] {
                promptCapsule(t, index: 0)
                    .offset(x: -coreSize * 0.95, y: -coreSize * 0.8)
            }
            // tag-2: Order a meal package (左下) - 对标 HTML tag-2: bottom -20, left -110
            if let t = viewModel.suggestedPrompts[safe: 1] {
                promptCapsule(t, index: 1)
                    .offset(x: -coreSize * 0.85, y: coreSize * 0.8)
            }
            // tag-3: Check the weather (右中) - 对标 HTML tag-3: top 40, right -150
            if let t = viewModel.suggestedPrompts[safe: 2] {
                promptCapsule(t, index: 2)
                    .offset(x: coreSize * 1.0, y: coreSize * 0.3)
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
                .font(.du(14, weight: .light))
                .foregroundColor(.white.opacity(0.7))

            Button {
                let gen = UIImpactFeedbackGenerator(style: .medium)
                gen.impactOccurred()
            } label: {
                ZStack {
                    // 更细更多彩的动态圆环对标 HTML conic-gradient
                    // 橙-粉-紫-青-绿-黄-橙
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [
                                    Color(hex: 0x38bdf8), Color(hex: 0x818cf8), Color(hex: 0xc084fc), Color(hex: 0xf472b6),
                                    Color(hex: 0xfb923c), Color(hex: 0xfcd34d), Color(hex: 0x34d399), Color(hex: 0x38bdf8)
                                ],
                                center: .center
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 76, height: 76) // 对标 HTML 76px
                        .rotationEffect(.degrees(coreRotation))

                    Circle()
                        .fill(Color(hex: 0x1E1B4B).opacity(0.4))
                        .frame(width: 58, height: 58) // 对标 HTML 58px
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 0.5))

                    Image(systemName: "mic")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - New UI Layers (Layer 2, 3, 4)

    private func offersListLayer(hPad: CGFloat, bottomPad: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            headerPlaceholder // 为了保持对齐
            
            Text("Here are the recommended package options for you~")
                .font(.du(18, weight: .regular))
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, hPad + 4)
                .padding(.top, 20)
                .padding(.bottom, 20)

            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(viewModel.offers) { offer in
                        offerCard(offer)
                    }
                }
                .padding(.horizontal, hPad)
                .padding(.bottom, bottomPad + 100) // 为语音按钮留白
            }
        }
        .padding(.top, 8)
    }

    private func offerCard(_ offer: AIChatOffer) -> some View {
        Button { viewModel.selectOffer(offer) } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text(offer.name)
                    .font(.du(18, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(height: 48, alignment: .top)
                    .padding(.bottom, 20)

                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DATA")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                        Text(offer.dataAmount)
                            .font(.du(15, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    Divider()
                        .background(Color.white.opacity(0.2))
                        .frame(height: 30)
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("VALIDITY")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                        Text(offer.validity)
                            .font(.du(15, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.bottom, 24)

                // Price Button Style
                HStack(spacing: 4) {
                    Text(offer.price)
                        .font(.system(size: 20, weight: .heavy))
                    Text("\(offer.currency)/\(offer.unit)")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.top, 4)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    LinearGradient(colors: [Color(hex: 0x3cd1ff), Color(hex: 0xc349ff)], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(Capsule())
                .shadow(color: Color(hex: 0x3cd1ff).opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .padding(18)
            .background(
                ZStack {
                    LinearGradient(colors: [Color(hex: 0x3b4eb7), Color(hex: 0x6c3fc4)], startPoint: .top, endPoint: .bottom)
                    LinearGradient(colors: [Color(hex: 0x7dd3fc).opacity(0.08), .clear, Color(hex: 0xf472b6).opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color(hex: 0x080f2d).opacity(0.2), radius: 20, x: 0, y: 16)
        }
        .buttonStyle(.plain)
    }

    private func offerDetailsLayer(offer: AIChatOffer, hPad: CGFloat, bottomPad: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            headerPlaceholder
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Selected Mini Card with Checkmark
                    ZStack(alignment: .topTrailing) {
                        offerCard(offer)
                            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color(hex: 0x38bdf8), lineWidth: 1.5))
                            .background(Color(hex: 0x38bdf8).opacity(0.1).clipShape(RoundedRectangle(cornerRadius: 28)))
                        
                        ZStack {
                            Circle().fill(Color(hex: 0x22c55e)).frame(width: 24, height: 24)
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(12)
                    }
                    .padding(.top, 10)
                    
                    Text("You have selected: ") + 
                    Text(offer.name).foregroundColor(Color(hex: 0x38bdf8)).bold() +
                    Text(", here are the package details.")
                    
                    VStack(spacing: 20) {
                        // Info Card 1
                        VStack(alignment: .leading, spacing: 16) {
                            Text("基本信息")
                                .font(.du(16, weight: .semibold))
                                .foregroundColor(Color(hex: 0x38bdf8))
                            
                            detailRow(key: "Combo Name:", value: offer.name)
                            detailRow(key: "Effective time:", value: "Effective immediately")
                            detailRow(key: "Validity period:", value: "The current month")
                        }
                        .padding(24)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        
                        // Info Card 2
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Business Details")
                                .font(.du(16, weight: .semibold))
                                .foregroundColor(Color(hex: 0x38bdf8))
                            
                            // Mock Image Placeholder -> HTML 真实网络图片链接
                            AsyncImage(url: URL(string: "https://images.unsplash.com/photo-1543269865-cbf427effbad?auto=format&fit=crop&q=80&w=600")) { phase in
                                if let image = phase.image {
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } else {
                                    LinearGradient(colors: [Color(hex: 0x1e3a8a), Color(hex: 0x1e1b4b)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                        .overlay(Image(systemName: "photo").foregroundColor(.white.opacity(0.3)).font(.system(size: 40)))
                                }
                            }
                            .frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            
                            Text("This package offers high-speed data roaming services across KSA territories. Ensure data roaming is enabled on your device Settings.")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.6))
                                .lineSpacing(4)
                            
                            Button {
                                viewModel.processImmediately()
                            } label: {
                                Text("Process Immediately")
                                    .font(.du(18, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 60)
                                    .background(LinearGradient(colors: [Color(hex: 0x38bdf8), Color(hex: 0xc148ff)], startPoint: .leading, endPoint: .trailing))
                                    .clipShape(Capsule())
                                    .shadow(color: Color(hex: 0xc148ff).opacity(0.4), radius: 15, x: 0, y: 8)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 10)
                        }
                        .padding(24)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    }
                    .padding(.bottom, bottomPad + 40)
                }
                .padding(.horizontal, hPad)
            }
        }
        .padding(.top, 8)
    }

    private func successLayer(hPad: CGFloat) -> some View {
        VStack(spacing: 0) {
            headerPlaceholder
            
            Spacer()
            
            VStack(spacing: 40) {
                // Success Illustration 纯 SwiftUI Path 模拟 HTML 中的 SVG
                ZStack {
                    // Document Body
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 100, height: 130)
                        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.3), lineWidth: 2))
                    
                    // Document Layout Elements
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 6).fill(Color(hex: 0x38bdf8).opacity(0.4)).frame(width: 30, height: 30)
                            VStack(alignment: .leading, spacing: 9) {
                                RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.4)).frame(width: 30, height: 6)
                                RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.2)).frame(width: 20, height: 6)
                            }
                        }
                        Spacer()
                    }
                    .frame(width: 70, height: 100, alignment: .topLeading)
                    .offset(y: 10)
                    
                    // Checkmark Bubble
                    ZStack {
                        Circle().fill(Color(hex: 0x38bdf8).opacity(0.2)).frame(width: 70, height: 70)
                        Circle().fill(Color(hex: 0x38bdf8).opacity(0.8)).frame(width: 50, height: 50)
                        Image(systemName: "checkmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .offset(x: 35, y: 40)
                    
                    // Stars
                    Image(systemName: "star.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: 0xfbbf24))
                        .offset(x: 60, y: -40)
                        
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: 0xfbbf24))
                        .offset(x: -45, y: 35)
                }
                .frame(width: 200, height: 200)
                
                Text("Congratulations on your successful application")
                    .font(.du(26, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
            }
            .offset(y: -60)
            
            Spacer()
        }
    }

    private func detailRow(key: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(key)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.4))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.trailing)
        }
    }

    private var headerPlaceholder: some View {
        Color.clear.frame(height: 48) // 与 HeaderBar 高度一致
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

}

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Helper UI Components for Premium Orb

struct FluidBlobShape: Shape {
    var offset: Double
    
    var animatableData: Double {
        get { offset }
        set { offset = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // 动态计算 border-radius 的波动 (类似 HTML blob animation)
        // 46% 54% 50% 50% / 46% 50% 50% 54%
        let factor = 0.04 * offset
        let r1 = w * (0.46 + factor)
        let r2 = w * (0.54 - factor)
        let r3 = w * (0.50 + factor)
        let r4 = w * (0.50 - factor)
        
        path.addRoundedRect(in: rect, cornerSize: CGSize(width: r1, height: r2), style: .continuous)
        
        // 简单的 RoundedRect 效果不足以完全复刻 CSS 的不规则 border-radius 组合，
        // 这里使用贝塞尔曲线精细模拟
        var p = Path()
        p.move(to: CGPoint(x: w * 0.5, y: 0))
        p.addCurve(to: CGPoint(x: w, y: h * 0.5), 
                   control1: CGPoint(x: w * (0.8 + factor), y: 0), 
                   control2: CGPoint(x: w, y: h * (0.2 - factor)))
        p.addCurve(to: CGPoint(x: w * 0.5, y: h), 
                   control1: CGPoint(x: w, y: h * (0.8 + factor)), 
                   control2: CGPoint(x: w * (0.8 - factor), y: h))
        p.addCurve(to: CGPoint(x: 0, y: h * 0.5), 
                   control1: CGPoint(x: w * (0.2 - factor), y: h), 
                   control2: CGPoint(x: 0, y: h * (0.8 - factor)))
        p.addCurve(to: CGPoint(x: w * 0.5, y: 0), 
                   control1: CGPoint(x: 0, y: h * (0.2 + factor)), 
                   control2: CGPoint(x: w * (0.2 + factor), y: 0))
        
        return p
    }
}

struct OrbInternalFluid: View {
    let isAnimating: Bool
    
    var body: some View {
        ZStack {
            // Fluid 1 (Cyan)
            RadialGradient(colors: [Color.cyan.opacity(0.9), .clear], center: .topLeading, startRadius: 0, endRadius: 100)
                .scaleEffect(isAnimating ? 1.2 : 0.8)
                .offset(x: isAnimating ? 20 : -20, y: isAnimating ? -20 : 20)
            
            // Fluid 2 (Pink)
            RadialGradient(colors: [Color.pink.opacity(0.8), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 100)
                .scaleEffect(isAnimating ? 0.8 : 1.2)
                .offset(x: isAnimating ? -20 : 20, y: isAnimating ? 20 : -20)
            
            // Fluid 3 (Red/Orange)
            RadialGradient(colors: [Color.orange.opacity(0.7), .clear], center: .topTrailing, startRadius: 0, endRadius: 80)
                .offset(y: isAnimating ? 10 : -30)
        }
        .blur(radius: 15)
        .blendMode(.screen)
        .animation(.easeInOut(duration: 8).repeatForever(autoreverses: true), value: isAnimating)
    }
}

struct GlassReflection: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            Path { path in
                path.move(to: CGPoint(x: w * 0.15, y: h * 0.2))
                path.addQuadCurve(to: CGPoint(x: w * 0.6, y: h * 0.1), control: CGPoint(x: w * 0.35, y: h * 0.05))
                path.addQuadCurve(to: CGPoint(x: w * 0.15, y: h * 0.2), control: CGPoint(x: w * 0.2, y: h * 0.15))
            }
            .fill(LinearGradient(colors: [.white.opacity(0.8), .clear], startPoint: .top, endPoint: .bottom))
            .rotationEffect(.degrees(-25))
            .blendMode(.overlay)
        }
    }
}

struct TriangleRipplePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let center = CGPoint(x: w/2, y: h/2)
        
        // 模拟 HTML 中的三角形波纹路径
        // M200 40 Q300 0, 360 120 T200 360 T40 120 T200 40
        path.move(to: CGPoint(x: w * 0.5, y: h * 0.1))
        path.addQuadCurve(to: CGPoint(x: w * 0.9, y: h * 0.3), control: CGPoint(x: w * 0.75, y: 0))
        path.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.9), control1: CGPoint(x: w, y: h * 0.6), control2: CGPoint(x: w * 0.7, y: h))
        path.addCurve(to: CGPoint(x: w * 0.1, y: h * 0.3), control1: CGPoint(x: w * 0.3, y: h), control2: CGPoint(x: 0, y: h * 0.6))
        path.addQuadCurve(to: CGPoint(x: w * 0.5, y: h * 0.1), control: CGPoint(x: w * 0.25, y: 0))
        
        return path
    }
}
