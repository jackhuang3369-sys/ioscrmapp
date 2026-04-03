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
            let coreSize = min(max(min(proxy.size.width * 0.38, proxy.size.height * 0.28), 144), 172)
            let hPad = min(max(proxy.size.width * 0.06, 18), 28)
            let bottomPad = max(proxy.safeAreaInsets.bottom, 16) + 12
            let homeLayout = homeLayoutMetrics(
                for: proxy.size,
                safeAreaInsets: proxy.safeAreaInsets,
                horizontalPadding: hPad,
                bottomPadding: bottomPad
            )

            ZStack {
                deepBackground

                // --- Home Layer (Layer 1) ---
                homeLayer(
                    coreSize: coreSize,
                    layout: homeLayout
                )
                .blur(radius: viewModel.currentStep == .home ? 0 : 15)
                .scaleEffect(viewModel.currentStep == .home ? 1.0 : 0.85)
                .opacity(viewModel.currentStep == .home ? 1.0 : 0.0)
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
            // SwiftUI 在复杂视图里有时会导致基于布尔值的连续动画失效（变静态）。
            // 解决办法：采用一个大范围波动的 Double 类型配合 easeInOut 和极大 duration。
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                isAnimatingCore = true
            }
            withAnimation(.linear(duration: 35).repeatForever(autoreverses: false)) {
                coreRotation = 360
            }
            animatePrompts()
        }
    }

    private func homeLayer(coreSize: CGFloat, layout: AIChatHomeLayout) -> some View {
        VStack(spacing: 0) {
            headerBar

            VStack(spacing: 8) {
                Text(viewModel.title)
                    .font(.system(size: layout.titleFontSize, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)

                // Optional: Subtitle line to add context or just a subtle visual line
                RoundedRectangle(cornerRadius: 1)
                    .fill(
                        LinearGradient(colors: [.clear, Color.white.opacity(0.3), .clear], startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: 120, height: 1)
                    .opacity(0.8)
            }
            .frame(width: layout.titleWidth)
            .padding(.top, layout.titleTopPadding)
            .frame(maxWidth: .infinity)

            homeHeroSection(coreSize: coreSize, layout: layout)
                .frame(width: layout.heroStageWidth, height: layout.heroHeight)
                .padding(.top, layout.heroTopPadding)
                .frame(maxWidth: .infinity)

            Spacer(minLength: 0)

            voiceSection(isCompactHeight: layout.isCompactHeight)
                .frame(width: layout.contentWidth)
                .padding(.bottom, layout.bottomPadding)
                .frame(maxWidth: .infinity)
        }
        .padding(.top, layout.topPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func homeHeroSection(coreSize: CGFloat, layout: AIChatHomeLayout) -> some View {
        GeometryReader { proxy in
            let meshSize = min(max(max(proxy.size.width, proxy.size.height) * 1.02, coreSize * 2.5), 420)
            let orbOffsetY: CGFloat = layout.isCompactHeight ? 10 : 18

            ZStack {
                orbMesh(size: meshSize)
                    .offset(y: orbOffsetY + 8)

                aiCoreOrb(coreSize: coreSize)
                    .offset(y: orbOffsetY)

                scatteredPrompts(
                    coreSize: coreSize,
                    availableSize: proxy.size,
                    promptMaxWidth: layout.promptMaxWidth,
                    orbOffsetY: orbOffsetY
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func homeLayoutMetrics(
        for size: CGSize,
        safeAreaInsets: EdgeInsets,
        horizontalPadding: CGFloat,
        bottomPadding: CGFloat
    ) -> AIChatHomeLayout {
        let isCompactHeight = size.height < 720
        let contentWidth = min(max(size.width - (horizontalPadding * 2) - 12, 280), 344)
        let heroStageWidth = min(max(size.width - (horizontalPadding * 2), 320), 420)
        let titleFontSize: CGFloat = size.height < 540 ? 28 : (isCompactHeight ? 30 : 34)
        let titleWidth = min(max(contentWidth * 0.76, 216), 252)
        let reservedHeight = max(safeAreaInsets.top, DUSpacing.lg) + 44 + bottomPadding + 124 + (isCompactHeight ? 72 : 88)
        let heroHeight = min(max(size.height - reservedHeight, 250), 420)
        let promptMaxWidth = min(max(heroStageWidth * 0.30, 108), 150)

        return AIChatHomeLayout(
            contentWidth: contentWidth,
            heroStageWidth: heroStageWidth,
            horizontalPadding: horizontalPadding,
            topPadding: max(safeAreaInsets.top, DUSpacing.lg),
            titleTopPadding: isCompactHeight ? DUSpacing.md : DUSpacing.xl,
            titleFontSize: titleFontSize,
            titleWidth: titleWidth,
            heroTopPadding: isCompactHeight ? DUSpacing.lg : DUSpacing.xxl,
            heroHeight: heroHeight,
            voiceTopSpacing: isCompactHeight ? DUSpacing.md : DUSpacing.xl,
            promptMaxWidth: promptMaxWidth,
            bottomPadding: bottomPadding,
            isCompactHeight: isCompactHeight
        )
    }

    // MARK: - Background

    private var deepBackground: some View {
        ZStack {
            // 深邃的海蓝色与紫色渐变，增加 3D 深度感
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: 0x0F172A), // 极深蓝
                    Color(hex: 0x1E3A8A), // 宝蓝
                    Color(hex: 0x312E81), // 靛蓝
                    Color(hex: 0x1E1B4B)  // 紫底
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // 环境光：左上深蓝色
            RadialGradient(
                colors: [Color(hex: 0x38BDF8).opacity(0.12), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 600
            )

            // 环境光：底部粉紫色
            RadialGradient(
                colors: [Color(hex: 0xEC4899).opacity(0.08), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 500
            )
            
            // 环境光：中央微光，增加通透度
            Circle()
                .fill(Color(hex: 0x818CF8).opacity(0.1))
                .frame(width: 600, height: 600)
                .blur(radius: 100)
                .offset(y: 50)
        }
        .ignoresSafeArea()
    }

    // MARK: - Orb Mesh Background

    private func orbMesh(size: CGFloat) -> some View {
        ZStack {
            // Organic ripple mesh behind orb
            ForEach(0..<6, id: \.self) { i in
                HeartRipplePath()
                    .stroke(
                        LinearGradient(colors: [
                            Color(hex: 0x38bdf8).opacity(0.4), 
                            Color(hex: 0x4821FF).opacity(0.3), 
                            Color(hex: 0xEC4899).opacity(0.3)
                        ], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1.2
                    )
                    .frame(width: size, height: size)
                    .scaleEffect(0.9 + CGFloat(i) * 0.1)
                    .rotationEffect(.degrees(Double(i) * 12 + coreRotation * 0.1))
            }
        }
        .frame(width: size, height: size)
        .opacity(0.7)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            if viewModel.currentStep != .home {
                Button { viewModel.goBack() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .move(edge: .leading)))
            }
            
            Spacer()
            
            Button { /* 鍏ㄥ睆閫昏緫 */ } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)

            Button { viewModel.requestNewChat() } label: {
                Image(systemName: "bubble.left")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)

            Button { onNavigate(.home) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .regular))
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
        let auraSize = coreSize * 2.2
        
        return ZStack {
            // 脉冲背景光：增强层次感
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: 0x38bdf8).opacity(0.25), Color(hex: 0x818cf8).opacity(0.1), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: auraSize * 0.5
                    )
                )
                .scaleEffect(isAnimatingCore ? 1.1 : 0.95)
                .blur(radius: 40)

            // 旋转光环：极细的光线律动
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [.clear, Color(hex: 0x38bdf8).opacity(0.6), Color(hex: 0xf472b6).opacity(0.7), Color(hex: 0x818cf8).opacity(0.6), .clear],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    lineWidth: 0.8
                )
                .frame(width: auraSize * 0.85, height: auraSize * 0.85)
                .blur(radius: 1)
                .rotationEffect(.degrees(coreRotation * 0.5))
            
            ZStack {
                // Core base gradient: 深邃基底
                FluidBlobShape(offset: isAnimatingCore ? 1.1 : -0.1)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x1E40AF), Color(hex: 0x0F172A)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )

                // 核心液态辉光层
                OrbInternalFluid(isAnimating: isAnimatingCore)
                    .mask(FluidBlobShape(offset: isAnimatingCore ? 1.0 : 0.0))
                    .opacity(0.8)
                
                Group {
                    // 折射光 1：粉紫侧光
                    RadialGradient(colors: [Color(hex: 0xEC4899).opacity(0.5), .clear], center: .bottomTrailing, startRadius: 0, endRadius: coreSize * 0.9)
                    
                    // 折射光 2：青蓝色高光
                    RadialGradient(colors: [Color(hex: 0x22D3EE).opacity(0.4), .clear], center: .topLeading, startRadius: 0, endRadius: coreSize * 0.8)
                }
                .mask(FluidBlobShape(offset: isAnimatingCore ? 1.1 : -0.1))
                .blendMode(.screen)

                // 玻璃表面反射
                GlassReflection()
                    .opacity(0.7)
                    .scaleEffect(1.1)
                    .offset(x: -coreSize * 0.08, y: -coreSize * 0.08)
                
                // 极细边缘光
                FluidBlobShape(offset: isAnimatingCore ? 1.1 : -0.1)
                    .stroke(
                        LinearGradient(colors: [.white.opacity(0.6), .clear, .white.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 0.5
                    )
            }
            .frame(width: coreSize, height: coreSize)
            .shadow(color: Color(hex: 0x38bdf8).opacity(0.4), radius: 25, x: 0, y: 0)
            .shadow(color: Color(hex: 0xEC4899).opacity(0.2), radius: 40, x: 0, y: 0)
            .scaleEffect(isAnimatingCore ? 1.04 : 0.98)
        }
    }

    // MARK: - Scattered Prompts

    private func scatteredPrompts(
        coreSize: CGFloat,
        availableSize: CGSize,
        promptMaxWidth: CGFloat,
        orbOffsetY: CGFloat
    ) -> some View {
        let promptWidth = promptMaxWidth
        let promptHalfWidth = promptWidth * 0.5
        let promptHeight: CGFloat = 56
        let promptHalfHeight = promptHeight * 0.5
        let horizontalMargin: CGFloat = 18
        let verticalMargin: CGFloat = 14
        let minX = promptHalfWidth + horizontalMargin
        let maxX = max(availableSize.width - promptHalfWidth - horizontalMargin, minX)
        let minY = promptHalfHeight + verticalMargin
        let maxY = max(availableSize.height - promptHalfHeight - verticalMargin, minY)
        let orbCenterX = availableSize.width * 0.5
        let orbCenterY = (availableSize.height * 0.5) + orbOffsetY
        let topLeftPoint = CGPoint(
            x: min(max(orbCenterX - coreSize * 0.88, minX), maxX),
            y: min(max(orbCenterY - coreSize * 0.80, minY), maxY)
        )
        let bottomLeftPoint = CGPoint(
            x: min(max(orbCenterX - coreSize * 0.70, minX), maxX),
            y: min(max(orbCenterY + coreSize * 0.92, minY), maxY)
        )
        let rightPoint = CGPoint(
            x: min(max(orbCenterX + coreSize * 0.95, minX), maxX),
            y: min(max(orbCenterY - coreSize * 0.26, minY), maxY)
        )

        return ZStack {
            if let t = viewModel.suggestedPrompts[safe: 0] {
                promptCapsule(t, index: 0, width: promptWidth)
                    .position(x: topLeftPoint.x, y: topLeftPoint.y)
            }
            if let t = viewModel.suggestedPrompts[safe: 1] {
                promptCapsule(t, index: 1, width: promptWidth)
                    .position(x: bottomLeftPoint.x, y: bottomLeftPoint.y)
            }
            if let t = viewModel.suggestedPrompts[safe: 2] {
                promptCapsule(t, index: 2, width: promptWidth)
                    .position(x: rightPoint.x, y: rightPoint.y)
            }
        }
    }

    private func promptCapsule(_ text: String, index: Int, width: CGFloat) -> some View {
        Button {
            viewModel.sendSuggestedPrompt(text)
        } label: {
            Text(text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.95))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(width: width)
                .frame(minHeight: 58)
                .background(
                    ZStack {
                        // 玻璃态背景
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .opacity(0.95)
                        
                        // 微弱内部渐变
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .fill(
                                LinearGradient(colors: [Color.white.opacity(0.08), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(
                            LinearGradient(colors: [.white.opacity(0.4), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 0.5
                        )
                )
                .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .opacity(promptOpacities[safe: index] ?? 0)
        .offset(y: promptOffsets[safe: index] ?? 20)
    }

    // MARK: - Voice Section

    private func voiceSection(isCompactHeight: Bool) -> some View {
        let ringSize: CGFloat = isCompactHeight ? 72 : 82
        let innerSize: CGFloat = isCompactHeight ? 56 : 62
        let iconSize: CGFloat = isCompactHeight ? 24 : 28

        return VStack(spacing: isCompactHeight ? 12 : 20) {
            Text("Hold to Talk ~")
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .tracking(0.5)

            Button {
                let gen = UIImpactFeedbackGenerator(style: .medium)
                gen.impactOccurred()
            } label: {
                ZStack {
                    // 外层呼吸律动环
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        .frame(width: ringSize + 12, height: ringSize + 12)
                        .scaleEffect(isAnimatingCore ? 1.08 : 1.0)
                        .opacity(isAnimatingCore ? 0.2 : 0.5)
                    
                    // 多彩渐变旋转环
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [
                                    Color(hex: 0x38bdf8), Color(hex: 0x818cf8), Color(hex: 0xc084fc), Color(hex: 0xf472b6),
                                    Color(hex: 0x38bdf8)
                                ],
                                center: .center
                            ),
                            lineWidth: 2.5
                        )
                        .frame(width: ringSize, height: ringSize)
                        .rotationEffect(.degrees(coreRotation))
                        .blur(radius: 0.5)

                    // 按钮球体
                    Circle()
                        .fill(
                            LinearGradient(colors: [Color(hex: 0x1E1B4B), Color(hex: 0x0F172A)], startPoint: .top, endPoint: .bottom)
                        )
                        .frame(width: innerSize, height: innerSize)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                        )
                        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)

                    Image(systemName: "mic.fill")
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundColor(.white)
                        .shadow(color: Color(hex: 0x38bdf8).opacity(0.5), radius: 8, x: 0, y: 0)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - New UI Layers (Layer 2, 3, 4)

    private func offersListLayer(hPad: CGFloat, bottomPad: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            headerPlaceholder // Keep header height alignment
            
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
                .padding(.bottom, bottomPad + 100)
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
                            Text("\u{57FA}\u{672C}\u{4FE1}\u{606F}")
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
                            
                            // Mock image placeholder -> HTML network image URL
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
                // Success illustration built with SwiftUI shapes
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
        Color.clear.frame(height: 48)
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

private struct AIChatHomeLayout {
    let contentWidth: CGFloat
    let heroStageWidth: CGFloat
    let horizontalPadding: CGFloat
    let topPadding: CGFloat
    let titleTopPadding: CGFloat
    let titleFontSize: CGFloat
    let titleWidth: CGFloat
    let heroTopPadding: CGFloat
    let heroHeight: CGFloat
    let voiceTopSpacing: CGFloat
    let promptMaxWidth: CGFloat
    let bottomPadding: CGFloat
    let isCompactHeight: Bool
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
        
        // Border-radius animation similar to HTML blob effect
        // 46% 54% 50% 50% / 46% 50% 50% 54%
        let factor = 0.04 * offset
        let r1 = w * (0.46 + factor)
        let r2 = w * (0.54 - factor)
        
        path.addRoundedRect(in: rect, cornerSize: CGSize(width: r1, height: r2), style: .continuous)
        
        var p = Path()
        p.move(to: CGPoint(x: w * 0.5, y: 0))
        p.addCurve(to: CGPoint(x: w, y: h * 0.5), 
                   control1: CGPoint(x: w * (0.85 + factor), y: 0), 
                   control2: CGPoint(x: w, y: h * (0.15 - factor)))
        p.addCurve(to: CGPoint(x: w * 0.5, y: h), 
                   control1: CGPoint(x: w, y: h * (0.85 + factor)), 
                   control2: CGPoint(x: w * (0.85 - factor), y: h))
        p.addCurve(to: CGPoint(x: 0, y: h * 0.5), 
                   control1: CGPoint(x: w * (0.15 - factor), y: h), 
                   control2: CGPoint(x: 0, y: h * (0.85 - factor)))
        p.addCurve(to: CGPoint(x: w * 0.5, y: 0), 
                   control1: CGPoint(x: 0, y: h * (0.15 + factor)), 
                   control2: CGPoint(x: w * (0.15 + factor), y: 0))
        
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
                path.move(to: CGPoint(x: w * 0.1, y: h * 0.3))
                path.addQuadCurve(to: CGPoint(x: w * 0.6, y: h * 0.15), control: CGPoint(x: w * 0.3, y: h * 0.05))
                path.addQuadCurve(to: CGPoint(x: w * 0.1, y: h * 0.3), control: CGPoint(x: w * 0.25, y: h * 0.25))
            }
            .fill(
                LinearGradient(
                    colors: [.white, .white.opacity(0.1)], 
                    startPoint: .topLeading, 
                    endPoint: .bottomTrailing
                )
            )
            .blur(radius: 2)
            .rotationEffect(.degrees(-15))
            .blendMode(.plusLighter)
        }
    }
}

struct HeartRipplePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Organic ripple path inspired by the HTML mock
        path.move(to: CGPoint(x: w * 0.5, y: h * 0.25))
        path.addCurve(to: CGPoint(x: w * 0.8, y: h * 0.45), 
                      control1: CGPoint(x: w * 0.7, y: h * 0.15), 
                      control2: CGPoint(x: w * 0.9, y: h * 0.35))
        path.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.85), 
                      control1: CGPoint(x: w * 0.7, y: h * 0.65), 
                      control2: CGPoint(x: w * 0.6, y: h * 0.8))
        path.addCurve(to: CGPoint(x: w * 0.2, y: h * 0.45), 
                      control1: CGPoint(x: w * 0.4, y: h * 0.8), 
                      control2: CGPoint(x: w * 0.3, y: h * 0.65))
        path.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.25), 
                      control1: CGPoint(x: w * 0.1, y: h * 0.35), 
                      control2: CGPoint(x: w * 0.3, y: h * 0.15))
        
        return path
    }
}
