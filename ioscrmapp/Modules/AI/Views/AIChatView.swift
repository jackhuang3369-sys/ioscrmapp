import SceneKit
import SwiftUI
import UIKit
import WebKit

struct AIChatView: View {
    private struct AssistantAnswerSection {
        let title: String?
        let paragraphs: [String]

        var hasVisibleContent: Bool {
            title != nil || paragraphs.contains { !$0.isEmpty }
        }
    }

    @Environment(\.openURL) private var openURL
    @StateObject private var viewModel: AIChatViewModel
    @FocusState private var isDraftFieldFocused: Bool
    let onNavigate: (AIChatNavigationTarget) -> Void

    @State private var isAnimatingCore = false
    @State private var coreRotation: Double = 0
    @State private var tilt3D: CGFloat = 0
    @State private var composerMode: AIChatComposerMode = .text
    @State private var isVoiceListening = false
    @State private var promptOffsets: [CGFloat] = [50, 50, 50, 50]
    @State private var promptOpacities: [Double] = [0, 0, 0, 0]
    @State private var glowOffset: CGFloat = -1.2 // 驱动详情页扫光效果
    @State private var keyboardFrameInScreen: CGRect = .null
    @State private var transientUserMessageText: String?
    @State private var floatingMessageHideWorkItem: DispatchWorkItem?

    private var latestUserMessage: AIChatMessage? {
        viewModel.messages.last(where: { $0.sender == .user })
    }

    private var shouldShowPersistentComposer: Bool {
        switch viewModel.currentStep {
        case .home, .offersList, .answer, .offerDetails, .success:
            return true
        }
    }

    private var shouldShowThinkingIndicator: Bool {
        viewModel.currentStep == .home && viewModel.isSending
    }

    private var floatingUserMessageReserveHeight: CGFloat {
        guard transientUserMessageText != nil else {
            return 0
        }

        return 120
    }

    private var composerReserveHeight: CGFloat {
        shouldShowPersistentComposer ? 112 + floatingUserMessageReserveHeight : 0
    }

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
            let baseSafeBottomInset = min(proxy.safeAreaInsets.bottom, 34)
            let bottomPad = max(baseSafeBottomInset, 16) + 12
            let viewFrameInScreen = proxy.frame(in: .global)
            let keyboardOverlap = keyboardOverlapHeight(for: viewFrameInScreen)
            let composerBottomPadding = keyboardOverlap > 0 ? keyboardOverlap + 6 : baseSafeBottomInset + 12
            let homeLayout = homeLayoutMetrics(
                for: proxy.size,
                safeAreaInsets: proxy.safeAreaInsets,
                horizontalPadding: hPad,
                bottomPadding: bottomPad
            )

            ZStack(alignment: .center) {
                deepBackground

                // --- Home Layer (Layer 1) ---
                homeLayer(
                    coreSize: coreSize,
                    layout: homeLayout
                )
                .frame(maxWidth: .infinity)
                .blur(radius: viewModel.currentStep == .home ? 0 : 15)
                .scaleEffect(viewModel.currentStep == .home ? 1.0 : 0.85)
                .opacity(viewModel.currentStep == .home ? 1.0 : 0.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.currentStep)

                // --- Layer 2: Offers List ---
                if viewModel.currentStep == .offersList {
                    offersListLayer(hPad: hPad, bottomPad: bottomPad)
                        .frame(maxWidth: .infinity)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                        .zIndex(2)
                }

                if viewModel.currentStep == .answer {
                    answerLayer(hPad: hPad, bottomPad: bottomPad)
                        .frame(maxWidth: .infinity)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                        .zIndex(2)
                }

                // --- Layer 3: Offer Details ---
                if case .offerDetails(let offer) = viewModel.currentStep {
                    offerDetailsLayer(offer: offer, hPad: hPad, bottomPad: bottomPad)
                        .frame(maxWidth: .infinity)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                        .zIndex(3)
                }

                // --- Layer 4: Success ---
                if viewModel.currentStep == .success {
                    successLayer(hPad: hPad)
                        .frame(maxWidth: .infinity)
                        .transition(.asymmetric(insertion: .scale(scale: 0.95).combined(with: .opacity), removal: .opacity))
                        .zIndex(4)
                }
            }
            .frame(width: proxy.size.width)
            .clipped()
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture().onEnded {
                    dismissKeyboardIfNeeded()
                }
            )
            .overlay(alignment: .bottom) {
                if shouldShowPersistentComposer {
                    VStack(spacing: homeLayout.isCompactHeight ? 10 : 14) {
                        if shouldShowThinkingIndicator {
                            thinkingStatusBubble(
                                maxWidth: homeLayout.contentWidth,
                                isCompactHeight: homeLayout.isCompactHeight
                            )
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

                        composerSection(isCompactHeight: homeLayout.isCompactHeight)
                    }
                        .frame(width: homeLayout.contentWidth)
                        .padding(.bottom, composerBottomPadding)
                        .frame(maxWidth: .infinity)
                }
            }
            .animation(.spring(response: 0.42, dampingFraction: 0.86), value: transientUserMessageText)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                isAnimatingCore = true
            }
            withAnimation(.linear(duration: 35).repeatForever(autoreverses: false)) {
                coreRotation = 360
            }
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                tilt3D = 1
            }
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                glowOffset = 1.2
            }
            animatePrompts()
        }
        .onChange(of: latestUserMessage?.id) { _ in
            presentTransientUserMessageIfNeeded()
        }
        .onDisappear {
            floatingMessageHideWorkItem?.cancel()
            floatingMessageHideWorkItem = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
            updateKeyboardFrame(from: notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.2)) {
                keyboardFrameInScreen = .null
            }
        }
        .onChange(of: isDraftFieldFocused) { isFocused in
            if isFocused {
                composerMode = .text
                isVoiceListening = false
            }
        }
        .onChange(of: viewModel.currentStep) { _ in
            isDraftFieldFocused = false
            composerMode = .text
            isVoiceListening = false
            if viewModel.currentStep != .home {
                floatingMessageHideWorkItem?.cancel()
                floatingMessageHideWorkItem = nil
                withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                    transientUserMessageText = nil
                }
            }
        }
    }

    private func homeLayer(coreSize: CGFloat, layout: AIChatHomeLayout) -> some View {
        VStack(spacing: 0) {
            headerBar

            hiddenLegacyTitle(layout: layout)
                .frame(height: 0)

            homeHeroSection(coreSize: coreSize, layout: layout)
                .frame(width: layout.heroStageWidth, height: layout.heroHeight)
                .frame(maxWidth: .infinity)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func hiddenLegacyTitle(layout: AIChatHomeLayout) -> some View {
        Text(viewModel.title)
            .font(.system(size: layout.titleFontSize, weight: .bold, design: .rounded))
            .hidden()
            .accessibilityHidden(true)
    }

    private func homeHeroSection(coreSize: CGFloat, layout: AIChatHomeLayout) -> some View {
        GeometryReader { proxy in
            let orbOffsetY: CGFloat = layout.isCompactHeight ? 10 : 18

            ZStack {
                AIOrbStageView(
                    coreSize: coreSize,
                    isAnimating: isAnimatingCore,
                    tiltAmount: tilt3D
                )
                .frame(
                    width: min(max(coreSize * 2.95, proxy.size.width * 0.9), proxy.size.width),
                    height: min(max(coreSize * 2.35, proxy.size.height * 0.95), proxy.size.height)
                )
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
        // 完全动态计算宽度，移除会导致溢出的 Min 最小值（320等）
        let contentWidth = size.width - (horizontalPadding * 2)
        let heroStageWidth = contentWidth
        let titleFontSize: CGFloat = size.height < 540 ? 26 : (isCompactHeight ? 28 : 32)
        let titleWidth = min(contentWidth * 0.95, 340)
        let reservedHeight = max(safeAreaInsets.top, DUSpacing.lg) + 44 + bottomPadding + 124 + (isCompactHeight ? 72 : 88)
        let heroHeight = min(max(size.height - reservedHeight, 250), 420)
        let promptMaxWidth = min(heroStageWidth * 0.35, 160)

        return AIChatHomeLayout(
            contentWidth: contentWidth,
            heroStageWidth: heroStageWidth,
            horizontalPadding: horizontalPadding,
            bottomPadding: bottomPadding,
            isCompactHeight: isCompactHeight,
            titleFontSize: titleFontSize,
            titleWidth: titleWidth,
            heroHeight: heroHeight,
            promptMaxWidth: promptMaxWidth,
            titleTopPadding: max(safeAreaInsets.top, DUSpacing.lg),
            safeAreaInsets: safeAreaInsets
        )
    }

    // MARK: - Background

    private var deepBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: 0x0E5CB7),
                    Color(hex: 0x780BAA)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Image("AIChatBottomWave")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .clipped()
        }
        .ignoresSafeArea()
    }

    // MARK: - Orb Mesh Background

    private func orbMesh(size: CGFloat) -> some View {
        ZStack {
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
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            Spacer()
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
        .padding(.horizontal, 28)
        .frame(height: 50)
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
        let horizontalMargin: CGFloat = 32
        let verticalMargin: CGFloat = 16
        let promptWidth = max(promptMaxWidth * 0.86, 122)
        let promptHalfWidth = promptWidth * 0.5
        let promptHeight: CGFloat = 52
        let promptHalfHeight = promptHeight * 0.5
        let sideColumnOffset = coreSize * 0.72
        let transientBottomAllowance = promptHeight * 1.6
        let minX = promptHalfWidth + horizontalMargin
        let maxX = max(availableSize.width - promptHalfWidth - horizontalMargin, minX)
        let minY = promptHalfHeight + verticalMargin
        let maxY = max(availableSize.height - promptHalfHeight - verticalMargin, minY)
        let orbCenterX = availableSize.width * 0.5
        let orbCenterY = (availableSize.height * 0.5) + orbOffsetY
        let leftColumnX = min(max(orbCenterX - sideColumnOffset, minX), maxX)
        let rightColumnX = min(max(orbCenterX + sideColumnOffset, minX), maxX)
        let topLeftPoint = CGPoint(
            x: leftColumnX,
            y: min(max(orbCenterY - coreSize * 0.78, minY), maxY)
        )
        let bottomLeftPoint = CGPoint(
            x: leftColumnX,
            y: min(max(orbCenterY + coreSize * 0.85, minY), maxY)
        )
        let topRightPoint = CGPoint(
            x: rightColumnX,
            y: min(max(orbCenterY + coreSize * 0.15, minY), maxY)
        )
        let transientRightPoint = CGPoint(
            x: rightColumnX,
            y: min(max(orbCenterY + coreSize * 1.68, minY), maxY + transientBottomAllowance)
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
                    .position(x: topRightPoint.x, y: topRightPoint.y)
            }
            if let transientUserMessageText {
                transientPromptCapsule(transientUserMessageText, width: promptWidth)
                    .position(x: transientRightPoint.x, y: transientRightPoint.y)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
            }
        }
    }

    private func promptCapsule(_ text: String, index: Int, width: CGFloat) -> some View {
        Button {
            if let target = viewModel.directNavigationTarget(for: text) {
                onNavigate(target)
            } else {
                viewModel.sendSuggestedPrompt(text)
            }
        } label: {
            promptCapsuleContent(text, width: width, lineLimit: 2)
        }
        .buttonStyle(.plain)
        .opacity(promptOpacities[safe: index] ?? 0)
        .offset(y: promptOffsets[safe: index] ?? 20)
    }

    private func transientPromptCapsule(_ text: String, width: CGFloat) -> some View {
        promptCapsuleContent(text, width: width, lineLimit: 2)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func promptCapsuleContent(_ text: String, width: CGFloat, lineLimit: Int) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundColor(.white.opacity(0.95))
            .multilineTextAlignment(.center)
            .lineLimit(lineLimit)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: width)
            .frame(minHeight: 52)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(0.58)

                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(Color.white.opacity(0.012))

                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.05),
                                    Color.white.opacity(0.01),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.white.opacity(0.62), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }

    // MARK: - Composer Section

    private func composerSection(isCompactHeight: Bool) -> some View {
        Group {
            switch composerMode {
            case .text:
                draftComposerBar(isCompactHeight: isCompactHeight)
            case .voice:
                voiceSection(isCompactHeight: isCompactHeight)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.86), value: composerMode)
        .animation(.easeInOut(duration: 0.22), value: isVoiceListening)
    }

    private func draftComposerBar(isCompactHeight: Bool) -> some View {
        let barHeight: CGFloat = isCompactHeight ? 46 : 50
        let iconDiameter: CGFloat = isCompactHeight ? 36 : 40

        return HStack(spacing: DUSpacing.sm) {
            ZStack(alignment: .leading) {
                TextField("", text: $viewModel.draft, prompt: composerPrompt)
                    .focused($isDraftFieldFocused)
                    .textInputAutocapitalization(.sentences)
                    .disableAutocorrection(false)
                    .submitLabel(.send)
                    .font(.du(17, weight: .medium))
                    .foregroundColor(.white.opacity(0.94))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture {
                        focusDraftField()
                    }
                    .onSubmit {
                        submitDraftFromComposer()
                    }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                focusDraftField()
            }

            Button {
                transitionToVoiceMode()
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0x1E1B4B), Color(hex: 0x2A2469)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [
                                    Color(hex: 0x34D3FF),
                                    Color(hex: 0x7068FF),
                                    Color(hex: 0xFF5FB6),
                                    Color(hex: 0x34D3FF)
                                ],
                                center: .center
                            ),
                            lineWidth: 1.8
                        )

                    Image(systemName: "mic.fill")
                        .font(.system(size: isCompactHeight ? 16 : 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: iconDiameter, height: iconDiameter)
                .shadow(color: Color(hex: 0x34D3FF).opacity(0.18), radius: 8, x: 0, y: 0)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(AIChatLocalizedCopy.voiceEntryTitle(for: viewModel.language)))
        }
        .padding(.leading, DUSpacing.lg)
        .padding(.trailing, DUSpacing.sm)
        .frame(height: barHeight)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: 0x8B2BFF).opacity(0.26),
                            Color(hex: 0x5B4CFF).opacity(0.18),
                            Color(hex: 0xED68C2).opacity(0.22)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(0.5)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.18), .white.opacity(0.06), .white.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var composerPrompt: Text {
        Text(AIChatLocalizedCopy.inputPlaceholder(for: viewModel.language))
            .font(.du(17, weight: .medium))
            .foregroundColor(.white.opacity(0.48))
    }

    private func thinkingStatusBubble(maxWidth: CGFloat, isCompactHeight: Bool) -> some View {
        VStack(spacing: isCompactHeight ? 10 : 12) {
            AIChatThinkingIndicatorView(isCompactHeight: isCompactHeight)

            Text("Thinking...")
                .font(.system(size: isCompactHeight ? 16 : 18, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.88))
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .padding(.horizontal, 6)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, isCompactHeight ? 14 : 16)
        .frame(maxWidth: min(maxWidth * 0.84, 336))
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(0.94)

                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.white.opacity(0.06))

                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.18),
                                Color.white.opacity(0.05),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.68), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.14), radius: 14, x: 0, y: 8)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func presentTransientUserMessageIfNeeded() {
        guard viewModel.currentStep == .home, let latestUserMessage else {
            return
        }

        let trimmedText = latestUserMessage.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return
        }

        floatingMessageHideWorkItem?.cancel()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            transientUserMessageText = trimmedText
        }

        let workItem = DispatchWorkItem {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                transientUserMessageText = nil
            }
            floatingMessageHideWorkItem = nil
        }
        floatingMessageHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: workItem)
    }

    private func voiceSection(isCompactHeight: Bool) -> some View {
        let ringSize: CGFloat = isCompactHeight ? 72 : 82
        let innerSize: CGFloat = isCompactHeight ? 56 : 62
        let iconSize: CGFloat = isCompactHeight ? 24 : 28

        return VStack(spacing: isCompactHeight ? 12 : 20) {
            HStack(spacing: DUSpacing.sm) {
                Button {
                    transitionToTextMode()
                } label: {
                    Image(systemName: "keyboard")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(AIChatLocalizedCopy.keyboardEntryTitle(for: viewModel.language)))

                Text(
                    isVoiceListening
                        ? AIChatLocalizedCopy.voiceListeningTitle(for: viewModel.language)
                        : AIChatLocalizedCopy.voiceHoldTitle(for: viewModel.language)
                )
                .font(.du(13, weight: .medium))
                .foregroundColor(.white.opacity(0.68))
                .tracking(0.4)
            }

            Button {
                toggleVoiceListening()
            } label: {
                ZStack {
                    // 外层呼吸律动环
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        .frame(width: ringSize + 12, height: ringSize + 12)
                        .scaleEffect(isVoiceListening ? 1.16 : (isAnimatingCore ? 1.08 : 1.0))
                        .opacity(isVoiceListening ? 0.45 : (isAnimatingCore ? 0.2 : 0.5))
                    
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
                        .scaleEffect(isVoiceListening ? 1.04 : 1.0)

                    // 按钮球体
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: isVoiceListening
                                    ? [Color(hex: 0x273B8C), Color(hex: 0x0F172A)]
                                    : [Color(hex: 0x1E1B4B), Color(hex: 0x0F172A)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
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
                        .shadow(color: Color(hex: 0x38bdf8).opacity(isVoiceListening ? 0.8 : 0.5), radius: 8, x: 0, y: 0)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func transitionToVoiceMode() {
        isDraftFieldFocused = false
        isVoiceListening = false
        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
            composerMode = .voice
        }
    }

    private func transitionToTextMode() {
        isVoiceListening = false
        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
            composerMode = .text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            isDraftFieldFocused = true
        }
    }

    private func toggleVoiceListening() {
        let generator = UIImpactFeedbackGenerator(style: isVoiceListening ? .light : .medium)
        generator.impactOccurred()
        withAnimation(.easeInOut(duration: 0.2)) {
            isVoiceListening.toggle()
        }
    }

    private func submitDraftFromComposer() {
        let message = viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else {
            return
        }

        if let target = viewModel.directNavigationTarget(for: message) {
            viewModel.draft = ""
            isDraftFieldFocused = false
            onNavigate(target)
            return
        }

        guard viewModel.canSend else {
            return
        }

        viewModel.sendDraft()
        isDraftFieldFocused = false
    }

    private func focusDraftField() {
        composerMode = .text
        isVoiceListening = false
        DispatchQueue.main.async {
            isDraftFieldFocused = true
        }
    }

    private func dismissKeyboardIfNeeded() {
        guard isDraftFieldFocused else {
            return
        }

        isDraftFieldFocused = false
    }

    private func keyboardOverlapHeight(for viewFrameInScreen: CGRect) -> CGFloat {
        guard keyboardFrameInScreen.isNull == false else {
            return 0
        }

        return max(0, viewFrameInScreen.intersection(keyboardFrameInScreen).height)
    }

    private func updateKeyboardFrame(from notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
        else {
            return
        }

        let duration = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.25

        withAnimation(.easeOut(duration: duration)) {
            if keyboardFrame.minY >= UIScreen.main.bounds.height {
                keyboardFrameInScreen = .null
            } else {
                keyboardFrameInScreen = keyboardFrame
            }
        }
    }

    // MARK: - New UI Layers (Layer 2, 3, 4)

    private func offersListLayer(hPad: CGFloat, bottomPad: CGFloat) -> some View {
        let offerIntroText = viewModel.currentAssistantMessage?
            .text
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let displayTitle = (offerIntroText?.isEmpty == false)
            ? (offerIntroText ?? "")
            : AIChatLocalizedCopy.offersResultTitle(for: viewModel.language)

        return VStack(spacing: 0) {
            headerBar

            Text(displayTitle)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, hPad + 12)
                .padding(.top, 16)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity)

            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(viewModel.offers) { offer in
                        offerCard(offer)
                    }
                }
                .padding(.horizontal, hPad)
                .padding(.bottom, bottomPad + composerReserveHeight)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.top, 8)
    }

    private func answerLayer(hPad: CGFloat, bottomPad: CGFloat) -> some View {
        let assistantMessage = viewModel.currentAssistantMessage
        let questionText = latestUserMessage?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return VStack(spacing: 0) {
            headerBar

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    if !questionText.isEmpty {
                        infoGlassCard(title: AIChatLocalizedCopy.questionSectionTitle(for: viewModel.language)) {
                            Text(questionText)
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.98))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    infoGlassCard(title: AIChatLocalizedCopy.answerSectionTitle(for: viewModel.language)) {
                        assistantAnswerContent(message: assistantMessage)
                    }

                    if let actions = assistantMessage?.actions, !actions.isEmpty {
                        infoGlassCard(title: AIChatLocalizedCopy.suggestedActionsTitle(for: viewModel.language)) {
                            VStack(alignment: .leading, spacing: 14) {
                                Text(AIChatLocalizedCopy.continueAskingHint(for: viewModel.language))
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.68))
                                    .fixedSize(horizontal: false, vertical: true)

                                LazyVGrid(
                                    columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                                    spacing: 12
                                ) {
                                    ForEach(actions) { action in
                                        actionButton(action)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, hPad)
                .padding(.top, 18)
                .padding(.bottom, bottomPad + composerReserveHeight)
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func assistantAnswerContent(message: AIChatMessage?) -> some View {
        if let message {
            let sections = structuredAnswerSections(from: message)

            if !sections.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                        assistantAnswerSectionCard(section, index: index)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if let richText = message.richText, attributedTextIsNotEmpty(richText) {
                Text(richText)
                    .foregroundColor(.white.opacity(0.92))
                    .lineSpacing(4)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let htmlAttributed = attributedHTML(message.htmlContent), attributedTextIsNotEmpty(htmlAttributed) {
                Text(htmlAttributed)
                    .foregroundColor(.white.opacity(0.92))
                    .lineSpacing(4)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            } else if !message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(message.text)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.92))
                    .lineSpacing(4)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(AIChatLocalizedCopy.emptyReply(for: viewModel.language))
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.72))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            Text(AIChatLocalizedCopy.loadingTitle(for: viewModel.language))
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.72))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func assistantAnswerSectionCard(_ section: AssistantAnswerSection, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title = section.title {
                HStack(alignment: .center, spacing: 10) {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0x59D0FF), Color(hex: 0x8B5CFF)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 4, height: 24)

                    Text(title)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.98))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(section.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                    if let bulletText = bulletBody(from: paragraph) {
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(Color.white.opacity(0.72))
                                .frame(width: 6, height: 6)
                                .padding(.top, 7)

                            Text(bulletText)
                                .font(.system(size: 15, weight: .regular, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))
                                .lineSpacing(4)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } else {
                        Text(paragraph)
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                            .lineSpacing(4)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(index == 0 ? 0.1 : 0.08),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func structuredAnswerSections(from message: AIChatMessage) -> [AssistantAnswerSection] {
        let source = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else {
            return []
        }

        let normalized = source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.components(separatedBy: "\n")

        var sections: [AssistantAnswerSection] = []
        var currentTitle: String?
        var currentParagraphLines: [String] = []
        var currentParagraphs: [String] = []
        var detectedStructuredContent = false

        func flushParagraph() {
            let paragraph = currentParagraphLines
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !paragraph.isEmpty {
                currentParagraphs.append(paragraph)
            }
            currentParagraphLines.removeAll()
        }

        func flushSection() {
            flushParagraph()
            let section = AssistantAnswerSection(title: currentTitle, paragraphs: currentParagraphs)
            if section.hasVisibleContent {
                sections.append(section)
            }
            currentTitle = nil
            currentParagraphs.removeAll()
        }

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

            if line.isEmpty {
                flushParagraph()
                continue
            }

            if let title = assistantSectionTitle(from: line) {
                flushSection()
                currentTitle = title
                detectedStructuredContent = true
                continue
            }

            if let bulletText = normalizedBulletLine(from: line) {
                flushParagraph()
                currentParagraphs.append(bulletText)
                detectedStructuredContent = true
                continue
            }

            currentParagraphLines.append(line)
        }

        flushSection()

        let visibleSections = sections.filter(\.hasVisibleContent)
        let hasTitledSections = visibleSections.contains { $0.title != nil }
        return detectedStructuredContent && (visibleSections.count > 1 || hasTitledSections)
            ? visibleSections
            : []
    }

    private func assistantSectionTitle(from line: String) -> String? {
        if let title = firstMatch(in: line, pattern: #"^\s*#{1,6}\s+(.+)$"#) {
            return title
        }

        if let numberedTitle = firstMatch(in: line, pattern: #"^\s*(\d+\.\s+.+)$"#) {
            return numberedTitle
        }

        return nil
    }

    private func normalizedBulletLine(from line: String) -> String? {
        if let bulletText = firstMatch(in: line, pattern: #"^\s*[-*+•]\s+(.+)$"#) {
            return "• \(bulletText)"
        }

        return nil
    }

    private func bulletBody(from paragraph: String) -> String? {
        firstMatch(in: paragraph, pattern: #"^\s*•\s+(.+)$"#)
    }

    private func firstMatch(in text: String, pattern: String) -> String? {
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(
                in: text,
                range: NSRange(text.startIndex..., in: text)
            )
        else {
            return nil
        }

        let targetRange = match.numberOfRanges > 1 ? match.range(at: 1) : match.range
        guard let range = Range(targetRange, in: text) else {
            return nil
        }

        return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func infoGlassCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x51C7FF), Color(hex: 0xC64EFF)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 12, height: 12)
                    .shadow(color: Color(hex: 0xC64EFF).opacity(0.45), radius: 8, x: 0, y: 0)

                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.94))
            }

            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.1),
                            Color(hex: 0xF472B6).opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(0.78)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 10)
    }

    private func actionButton(_ action: AIChatAction) -> some View {
        Button {
            handleAction(action)
        } label: {
            Text(action.title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
                .padding(.horizontal, 12)
                .background(
                    LinearGradient(
                        colors: [Color(hex: 0x3CD1FF), Color(hex: 0xC349FF)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color(hex: 0xC349FF).opacity(0.22), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    private func handleAction(_ action: AIChatAction) {
        if let target = action.target {
            onNavigate(target)
            return
        }

        guard let rawValue = action.rawValue?.trimmingCharacters(in: .whitespacesAndNewlines), !rawValue.isEmpty else {
            return
        }

        if let target = navigationTarget(from: rawValue) {
            onNavigate(target)
            return
        }

        guard let url = URL(string: rawValue) else {
            return
        }

        openURL(url)
    }

    private func navigationTarget(from rawValue: String) -> AIChatNavigationTarget? {
        let normalized = rawValue.lowercased()

        if normalized.hasPrefix("app://") {
            if normalized.contains("recharge") {
                return .recharge
            }
            if normalized.contains("offer") {
                return .offers
            }
            if normalized.contains("bill") {
                return .billing
            }
            if normalized.contains("mall") {
                return .mall
            }
            if normalized.contains("service") {
                return .service
            }
            if normalized.contains("me") {
                return .me
            }
            if normalized.contains("home") {
                return .home
            }
        }

        if let url = URL(string: rawValue), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) {
            return .external(url)
        }

        return nil
    }

    private func attributedHTML(_ html: String?) -> AttributedString? {
        guard
            let html,
            let data = html.data(using: .utf8),
            let nsAttributed = try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
            )
        else {
            return nil
        }

        return AttributedString(nsAttributed.string)
    }

    private func attributedTextIsNotEmpty(_ text: AttributedString) -> Bool {
        !String(text.characters)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }

    private func offerCard(_ offer: AIChatOffer) -> some View {
        Button { viewModel.selectOffer(offer) } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text(offer.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.85)
                    .frame(height: 40, alignment: .top)
                    .padding(.bottom, 12)

                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("DATA")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                        Text(offer.dataAmount)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }

                    Spacer(minLength: 4)
                    Divider()
                        .background(Color.white.opacity(0.2))
                        .frame(height: 26)
                    Spacer(minLength: 4)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("VALIDITY")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                        Text(offer.validity)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }
                .padding(.bottom, 14)

                // Price Button
                HStack(spacing: 3) {
                    Text(offer.price)
                        .font(.system(size: 17, weight: .heavy))
                    Text("\(offer.currency)/\(offer.unit)")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.top, 3)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    LinearGradient(colors: [Color(hex: 0x3cd1ff), Color(hex: 0xc349ff)], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(Capsule())
                .shadow(color: Color(hex: 0x3cd1ff).opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .padding(12)
            .background(
                ZStack {
                    LinearGradient(colors: [Color(hex: 0x3b4eb7), Color(hex: 0x6c3fc4)], startPoint: .top, endPoint: .bottom)
                    LinearGradient(colors: [Color(hex: 0x7dd3fc).opacity(0.08), .clear, Color(hex: 0xf472b6).opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color(hex: 0x080f2d).opacity(0.15), radius: 12, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }

    private func offerDetailsLayer(offer: AIChatOffer, hPad: CGFloat, bottomPad: CGFloat) -> some View {
        let sectionSpacing: CGFloat = 12
        let cardPadding: CGFloat = 14
        let summaryHorizontalPadding: CGFloat = 14
        let summaryVerticalPadding: CGFloat = 10
        let imageHeight: CGFloat = 124
        let actionButtonHeight: CGFloat = 48

        return VStack(spacing: 0) {
            headerBar

            ScrollView(showsIndicators: false) {
                VStack(spacing: sectionSpacing) {
                    // 选中套餐摘要条
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: 0x22c55e))
                                .frame(width: 24, height: 24)
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(offer.name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Text("\(offer.price) \(offer.currency)/\(offer.unit) · \(offer.dataAmount) · \(offer.validity)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.55))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }

                        Spacer()

//                        Image(systemName: "chevron.down")
//                            .font(.system(size: 12, weight: .semibold))
//                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(.horizontal, summaryHorizontalPadding)
                    .padding(.vertical, summaryVerticalPadding)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(
                                        LinearGradient(colors: [Color(hex: 0x38bdf8).opacity(0.08), Color(hex: 0x6c3fc4).opacity(0.06)], startPoint: .leading, endPoint: .trailing)
                                    )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color(hex: 0x38bdf8).opacity(0.3), lineWidth: 0.5)
                    )

                    // 基本信息卡片
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: 0x38bdf8))
                            Text("Plan Information")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.bottom, 12)

                        detailRow(key: "Combo Name", value: offer.name)
                        detailRow(key: "Effective time", value: "Effective immediately")
                        detailRow(key: "Validity period", value: "The current month")
                    }
                    .padding(cardPadding)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.white.opacity(0.04))
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [.clear, Color(hex: 0x38bdf8).opacity(0.35), .clear],
                                    startPoint: UnitPoint(x: glowOffset - 0.2, y: glowOffset - 0.2),
                                    endPoint: UnitPoint(x: glowOffset + 0.2, y: glowOffset + 0.2)
                                ),
                                lineWidth: 1.2
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                    )
                    .shadow(color: Color(hex: 0x38bdf8).opacity(0.08), radius: 10, x: 0, y: 5)

                    // 业务详情卡片
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: 0x38bdf8))
                            Text("Business Details")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.bottom, 12)

                        // 图片
                        AsyncImage(url: URL(string: "https://images.unsplash.com/photo-1543269865-cbf427effbad?auto=format&fit=crop&q=80&w=600")) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                LinearGradient(colors: [Color(hex: 0x1e3a8a), Color(hex: 0x1e1b4b)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    .overlay(Image(systemName: "photo").foregroundColor(.white.opacity(0.3)).font(.system(size: 32)))
                            }
                        }
                        .frame(height: imageHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                        .padding(.bottom, 10)

                        Text("This package offers high-speed data roaming services across du territories. Ensure data roaming is enabled on your device Settings.")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.white.opacity(0.55))
                            .lineSpacing(3)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(cardPadding)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.white.opacity(0.04))
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [.clear, Color(hex: 0xc148ff).opacity(0.25), .clear],
                                    startPoint: UnitPoint(x: 1 - glowOffset - 0.2, y: 1 - glowOffset - 0.2),
                                    endPoint: UnitPoint(x: 1 - glowOffset + 0.2, y: 1 - glowOffset + 0.2)
                                ),
                                lineWidth: 1.2
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                    )
                    .shadow(color: Color(hex: 0xc148ff).opacity(0.05), radius: 10, x: 0, y: 5)

                    // 立即办理按钮
                    Button {
                        viewModel.processImmediately()
                    } label: {
                        Text("Process Immediately")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: actionButtonHeight)
                            .background(
                                LinearGradient(colors: [Color(hex: 0x38bdf8), Color(hex: 0xc148ff)], startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(Capsule())
                            .shadow(color: Color(hex: 0xc148ff).opacity(0.35), radius: 12, x: 0, y: 6)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
                .padding(.horizontal, hPad + 4)
                .padding(.top, 4)
                .padding(.bottom, bottomPad + composerReserveHeight)
            }
        }
        .padding(.top, 4)
    }

    private func successLayer(hPad: CGFloat) -> some View {
        VStack(spacing: 0) {
            headerBar
            
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
                    .font(.system(size: 26, weight: .semibold))
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
        VStack(alignment: .leading, spacing: 3) {
            Text(key)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 0.5)
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

    // MARK: - 3D 浮动光粒子

    private func floatingParticles(in size: CGSize) -> some View {
        ZStack {
            ForEach(0..<10, id: \.self) { i in
                let angle = Double(i) * .pi * 2.0 / 10.0
                let radius = min(size.width, size.height) * 0.35
                let baseX = CGFloat(cos(angle)) * radius
                let baseY = CGFloat(sin(angle)) * radius
                let dotSize: CGFloat = CGFloat(1.5 + Double(i % 3) * 1.2)
                let drift: CGFloat = i % 2 == 0 ? 15 : -15

                Circle()
                    .fill(
                        i % 3 == 0
                            ? Color(hex: 0x38BDF8).opacity(0.6)
                            : i % 3 == 1
                                ? Color(hex: 0xA855F7).opacity(0.5)
                                : Color.white.opacity(0.5)
                    )
                    .frame(width: dotSize, height: dotSize)
                    .blur(radius: 1)
                    .offset(
                        x: baseX + (isAnimatingCore ? drift : -drift),
                        y: baseY + (isAnimatingCore ? -drift * 0.6 : drift * 0.6)
                    )
                    .opacity(isAnimatingCore ? 0.7 : 0.15)
            }
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

private struct AIChatThinkingIndicatorView: View {
    let isCompactHeight: Bool
    @State private var rotation: Double = 0

    var body: some View {
        Image("AIChatThinkingIndicator")
            .resizable()
            .renderingMode(.original)
            .scaledToFit()
            .frame(width: isCompactHeight ? 34 : 40, height: isCompactHeight ? 34 : 40)
            .rotationEffect(.degrees(rotation))
            .shadow(color: Color(hex: 0x7C3AED).opacity(0.18), radius: 8, x: 0, y: 2)
            .onAppear {
                rotation = 0
                withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

private enum AIChatComposerMode {
    case text
    case voice
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

private struct AIOrbStageView: View {
    let coreSize: CGFloat
    let isAnimating: Bool
    let tiltAmount: CGFloat

    var body: some View {
        let stageWidth = coreSize * 2.9
        let stageHeight = coreSize * 2.3

        ZStack {
            Circle()
                .fill(Color(hex: 0x38BDF8).opacity(0.16))
                .frame(width: coreSize * 2.3, height: coreSize * 2.3)
                .blur(radius: coreSize * 0.24)
                .scaleEffect(isAnimating ? 1.05 : 0.94)

            Circle()
                .fill(Color(hex: 0xC026D3).opacity(0.12))
                .frame(width: coreSize * 1.95, height: coreSize * 1.95)
                .blur(radius: coreSize * 0.20)
                .offset(x: coreSize * 0.12, y: coreSize * 0.08)
                .scaleEffect(isAnimating ? 0.98 : 1.06)

            AIOrbSceneView()
                .frame(width: stageWidth, height: stageHeight)
                .allowsHitTesting(false)

            Ellipse()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.20),
                            Color(hex: 0x38BDF8).opacity(0.12),
                            Color(hex: 0xEC4899).opacity(0.14),
                            Color.white.opacity(0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
                .frame(width: coreSize * 2.45, height: coreSize * 1.84)
                .blur(radius: 0.8)
                .opacity(0.8)
        }
        .frame(width: stageWidth, height: stageHeight)
        .scaleEffect(isAnimating ? 1.024 : 0.985)
        .rotation3DEffect(
            .degrees(tiltAmount * 6),
            axis: (x: 0.24, y: 1, z: 0.12),
            perspective: 0.72
        )
    }
}

private struct AIOrbSceneView: UIViewRepresentable {
    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        let scene = AIOrbSceneComposer.makeScene()

        scnView.scene = scene
        scnView.pointOfView = scene.rootNode.childNode(
            withName: AIOrbSceneComposer.cameraNodeName,
            recursively: false
        )
        scnView.backgroundColor = .clear
        scnView.isOpaque = false
        scnView.allowsCameraControl = false
        scnView.autoenablesDefaultLighting = false
        scnView.antialiasingMode = .multisampling4X
        scnView.rendersContinuously = true
        scnView.preferredFramesPerSecond = 60
        scnView.isPlaying = true

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
    }
}

private enum AIOrbSceneComposer {
    static let cameraNodeName = "ai_orb_camera"

    static func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor.clear

        let cameraNode = makeCameraNode()
        scene.rootNode.addChildNode(cameraNode)
        makeLightNodes().forEach { scene.rootNode.addChildNode($0) }
        scene.rootNode.addChildNode(makeOrbRootNode())

        return scene
    }

    private static func makeCameraNode() -> SCNNode {
        let camera = SCNCamera()
        camera.fieldOfView = 34
        camera.zNear = 0.1
        camera.zFar = 60
        camera.wantsHDR = true
        camera.wantsExposureAdaptation = false
        camera.bloomIntensity = 0.82
        camera.bloomThreshold = 0.22
        camera.bloomBlurRadius = 16

        let cameraNode = SCNNode()
        cameraNode.name = cameraNodeName
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 8.6)
        return cameraNode
    }

    private static func makeLightNodes() -> [SCNNode] {
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 280
        ambient.color = UIColor(hex: 0x8697FF, alpha: 1)

        let ambientNode = SCNNode()
        ambientNode.light = ambient

        let key = SCNLight()
        key.type = .omni
        key.intensity = 1350
        key.color = UIColor(hex: 0x67E8F9, alpha: 1)
        key.attenuationStartDistance = 4
        key.attenuationEndDistance = 18

        let keyNode = SCNNode()
        keyNode.light = key
        keyNode.position = SCNVector3(-2.6, 2.0, 4.8)

        let fill = SCNLight()
        fill.type = .omni
        fill.intensity = 1100
        fill.color = UIColor(hex: 0xF472B6, alpha: 1)
        fill.attenuationStartDistance = 4
        fill.attenuationEndDistance = 20

        let fillNode = SCNNode()
        fillNode.light = fill
        fillNode.position = SCNVector3(2.4, -1.8, 4.4)

        let rim = SCNLight()
        rim.type = .directional
        rim.intensity = 820
        rim.color = UIColor(hex: 0xC084FC, alpha: 1)

        let rimNode = SCNNode()
        rimNode.light = rim
        rimNode.eulerAngles = SCNVector3(-0.28, .pi - 0.52, 0)

        return [ambientNode, keyNode, fillNode, rimNode]
    }

    private static func makeOrbRootNode() -> SCNNode {
        let root = SCNNode()

        root.addChildNode(makeRibbonGroup())
        root.addChildNode(makeCoreNode())
        root.addChildNode(makeSparkCluster(count: 28))

        let bobUp = SCNAction.moveBy(x: 0, y: 0.12, z: 0, duration: 3.4)
        bobUp.timingMode = .easeInEaseOut
        let bobDown = SCNAction.moveBy(x: 0, y: -0.12, z: 0, duration: 3.4)
        bobDown.timingMode = .easeInEaseOut
        root.runAction(.repeatForever(.sequence([bobUp, bobDown])))

        let yaw = SCNAction.rotateBy(x: 0.05, y: CGFloat.pi * 2, z: 0.10, duration: 26)
        root.runAction(.repeatForever(yaw))

        return root
    }

    private static func makeCoreNode() -> SCNNode {
        let core = SCNNode()

        let shellSphere = SCNSphere(radius: 1.28)
        shellSphere.segmentCount = 96
        shellSphere.firstMaterial = makeShellMaterial()
        let shellNode = SCNNode(geometry: shellSphere)

        let energySphere = SCNSphere(radius: 1.10)
        energySphere.segmentCount = 96
        energySphere.firstMaterial = makeEnergyMaterial(opacity: 0.86)
        let energyNode = SCNNode(geometry: energySphere)
        energyNode.eulerAngles = SCNVector3(0.44, -0.28, 0.14)
        energyNode.runAction(.repeatForever(.rotateBy(x: 0.18, y: CGFloat.pi * 2, z: 0.22, duration: 13)))

        let secondarySphere = SCNSphere(radius: 0.88)
        secondarySphere.segmentCount = 72
        secondarySphere.firstMaterial = makeEnergyMaterial(opacity: 0.54)
        let secondaryNode = SCNNode(geometry: secondarySphere)
        secondaryNode.eulerAngles = SCNVector3(-0.32, 0.22, -0.46)
        secondaryNode.runAction(.repeatForever(.rotateBy(x: -0.16, y: -CGFloat.pi * 2, z: 0.10, duration: 17)))

        core.addChildNode(shellNode)
        core.addChildNode(energyNode)
        core.addChildNode(secondaryNode)

        let pulseOut = SCNAction.scale(to: 1.03, duration: 2.8)
        pulseOut.timingMode = .easeInEaseOut
        let pulseIn = SCNAction.scale(to: 0.98, duration: 2.8)
        pulseIn.timingMode = .easeInEaseOut
        core.runAction(.repeatForever(.sequence([pulseOut, pulseIn])))

        return core
    }

    private static func makeShellMaterial() -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = UIColor(hex: 0x211A67, alpha: 0.90)
        material.emission.contents = UIColor(hex: 0x332380, alpha: 0.34)
        material.specular.contents = UIColor.white.withAlphaComponent(0.70)
        material.metalness.contents = 0.08
        material.roughness.contents = 0.18
        material.transparency = 0.94
        material.fresnelExponent = 1.65
        return material
    }

    private static func makeEnergyMaterial(opacity: CGFloat) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = AIOrbAssets.orbTexture
        material.emission.contents = AIOrbAssets.orbTexture
        material.transparent.contents = AIOrbAssets.orbMask
        material.transparency = opacity
        material.writesToDepthBuffer = false
        return material
    }

    private static func makeSparkCluster(count: Int) -> SCNNode {
        let cluster = SCNNode()

        for index in 0..<count {
            let orbit = SCNNode()
            orbit.eulerAngles = SCNVector3(
                Float.random(in: -0.9...0.9),
                Float.random(in: 0...(Float.pi * 2)),
                Float.random(in: -0.8...0.8)
            )

            let spark = SCNSphere(radius: CGFloat.random(in: 0.024...0.058))
            spark.segmentCount = 20

            let material = SCNMaterial()
            material.lightingModel = .constant
            material.diffuse.contents = UIColor.white.withAlphaComponent(0.04)
            material.emission.contents = sparkColor(for: index).withAlphaComponent(0.94)
            material.writesToDepthBuffer = false
            spark.firstMaterial = material

            let sparkNode = SCNNode(geometry: spark)
            sparkNode.position = SCNVector3(
                Float.random(in: 1.10...1.56),
                Float.random(in: -0.10...0.10),
                Float.random(in: -0.12...0.12)
            )

            let fadeIn = SCNAction.fadeOpacity(to: CGFloat.random(in: 0.75...1.0), duration: Double.random(in: 1.2...2.2))
            fadeIn.timingMode = .easeInEaseOut
            let fadeOut = SCNAction.fadeOpacity(to: CGFloat.random(in: 0.25...0.55), duration: Double.random(in: 1.2...2.2))
            fadeOut.timingMode = .easeInEaseOut
            sparkNode.opacity = CGFloat.random(in: 0.3...0.7)
            sparkNode.runAction(.repeatForever(.sequence([fadeIn, fadeOut])))

            let pulseOut = SCNAction.scale(to: CGFloat.random(in: 1.18...1.42), duration: Double.random(in: 1.4...2.4))
            pulseOut.timingMode = .easeInEaseOut
            let pulseIn = SCNAction.scale(to: CGFloat.random(in: 0.72...0.96), duration: Double.random(in: 1.4...2.4))
            pulseIn.timingMode = .easeInEaseOut
            sparkNode.runAction(.repeatForever(.sequence([pulseOut, pulseIn])))

            orbit.addChildNode(sparkNode)
            orbit.runAction(.repeatForever(
                .rotateBy(
                    x: CGFloat.random(in: -0.4...0.5),
                    y: CGFloat.pi * 2,
                    z: CGFloat.random(in: -0.8...0.8),
                    duration: Double.random(in: 5.4...9.8)
                )
            ))
            cluster.addChildNode(orbit)
        }

        return cluster
    }

    private static func sparkColor(for index: Int) -> UIColor {
        switch index % 4 {
        case 0:
            return UIColor(hex: 0x67E8F9, alpha: 1)
        case 1:
            return UIColor(hex: 0xC084FC, alpha: 1)
        case 2:
            return UIColor(hex: 0xF472B6, alpha: 1)
        default:
            return UIColor(hex: 0xE0F2FE, alpha: 1)
        }
    }

    private static func makeRibbonGroup() -> SCNNode {
        let group = SCNNode()

        group.addChildNode(makeRibbonRing(
            ringRadius: 1.98,
            pipeRadius: 0.015,
            scale: SCNVector3(1.22, 0.86, 1.0),
            eulerAngles: SCNVector3(0.50, 0.22, 0.38),
            tint: UIColor(hex: 0x67E8F9, alpha: 1),
            opacity: 0.52,
            duration: 12
        ))
        group.addChildNode(makeRibbonRing(
            ringRadius: 2.10,
            pipeRadius: 0.012,
            scale: SCNVector3(0.92, 1.34, 1.0),
            eulerAngles: SCNVector3(-0.38, 0.40, -0.62),
            tint: UIColor(hex: 0xA855F7, alpha: 1),
            opacity: 0.42,
            duration: 16
        ))
        group.addChildNode(makeRibbonRing(
            ringRadius: 2.26,
            pipeRadius: 0.011,
            scale: SCNVector3(1.38, 0.82, 1.0),
            eulerAngles: SCNVector3(0.18, -0.34, 0.92),
            tint: UIColor(hex: 0xF472B6, alpha: 1),
            opacity: 0.34,
            duration: 19
        ))
        group.addChildNode(makeRibbonRing(
            ringRadius: 2.42,
            pipeRadius: 0.010,
            scale: SCNVector3(1.14, 1.18, 1.0),
            eulerAngles: SCNVector3(-0.70, -0.12, 0.28),
            tint: UIColor(hex: 0x38BDF8, alpha: 1),
            opacity: 0.22,
            duration: 24
        ))

        let swayLeft = SCNAction.rotateTo(x: 0.10, y: 0.06, z: -0.10, duration: 3.6, usesShortestUnitArc: true)
        swayLeft.timingMode = .easeInEaseOut
        let swayRight = SCNAction.rotateTo(x: -0.08, y: -0.06, z: 0.08, duration: 3.6, usesShortestUnitArc: true)
        swayRight.timingMode = .easeInEaseOut
        group.runAction(.repeatForever(.sequence([swayLeft, swayRight])))

        return group
    }

    private static func makeRibbonRing(
        ringRadius: CGFloat,
        pipeRadius: CGFloat,
        scale: SCNVector3,
        eulerAngles: SCNVector3,
        tint: UIColor,
        opacity: CGFloat,
        duration: TimeInterval
    ) -> SCNNode {
        let torus = SCNTorus(ringRadius: ringRadius, pipeRadius: pipeRadius)
        torus.ringSegmentCount = 220
        torus.pipeSegmentCount = 24

        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = tint.withAlphaComponent(0.10)
        material.emission.contents = tint.withAlphaComponent(0.92)
        material.blendMode = .add
        material.isDoubleSided = true
        material.writesToDepthBuffer = false
        torus.firstMaterial = material

        let node = SCNNode(geometry: torus)
        node.scale = scale
        node.eulerAngles = eulerAngles
        node.opacity = opacity
        node.runAction(.repeatForever(
            .rotateBy(
                x: CGFloat.random(in: -0.4...0.5),
                y: CGFloat.random(in: 0.8...1.4),
                z: CGFloat.pi * 2,
                duration: duration
            )
        ))
        return node
    }

}

private enum AIOrbAssets {
    static let orbTexture = AIOrbTextureFactory.makeOrbTexture()
    static let orbMask = AIOrbTextureFactory.makeRadialMaskTexture()
}

private enum AIOrbTextureFactory {
    static func makeOrbTexture(size: CGFloat = 1024) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: CGSize(width: size, height: size))
            let cgContext = context.cgContext
            cgContext.setFillColor(UIColor(hex: 0x070212, alpha: 1).cgColor)
            cgContext.fill(rect)

            drawRadialGlow(
                in: cgContext,
                rect: rect,
                center: CGPoint(x: size * 0.27, y: size * 0.26),
                radius: size * 0.38,
                colors: [
                    UIColor(hex: 0x34D3FF, alpha: 0.96),
                    UIColor(hex: 0x1375FF, alpha: 0.68),
                    UIColor.clear
                ]
            )
            drawRadialGlow(
                in: cgContext,
                rect: rect,
                center: CGPoint(x: size * 0.74, y: size * 0.25),
                radius: size * 0.34,
                colors: [
                    UIColor(hex: 0x6956FF, alpha: 0.76),
                    UIColor(hex: 0x2F3BFF, alpha: 0.38),
                    UIColor.clear
                ]
            )
            drawRadialGlow(
                in: cgContext,
                rect: rect,
                center: CGPoint(x: size * 0.70, y: size * 0.74),
                radius: size * 0.40,
                colors: [
                    UIColor(hex: 0xFF6BD5, alpha: 0.74),
                    UIColor(hex: 0x8B2BFF, alpha: 0.46),
                    UIColor.clear
                ]
            )
            drawRadialGlow(
                in: cgContext,
                rect: rect,
                center: CGPoint(x: size * 0.33, y: size * 0.76),
                radius: size * 0.36,
                colors: [
                    UIColor(hex: 0x3158FF, alpha: 0.88),
                    UIColor(hex: 0x12093B, alpha: 0.22),
                    UIColor.clear
                ]
            )

            let topRibbon = UIBezierPath()
            topRibbon.move(to: CGPoint(x: size * 0.10, y: size * 0.26))
            topRibbon.addCurve(
                to: CGPoint(x: size * 0.90, y: size * 0.20),
                controlPoint1: CGPoint(x: size * 0.26, y: size * 0.05),
                controlPoint2: CGPoint(x: size * 0.70, y: size * 0.38)
            )
            drawGradientRibbon(
                in: cgContext,
                path: topRibbon,
                lineWidth: size * 0.18,
                colors: [
                    UIColor(hex: 0x82F3FF, alpha: 0.98),
                    UIColor(hex: 0x1BA7FF, alpha: 0.92),
                    UIColor(hex: 0x7468FF, alpha: 0.84)
                ],
                start: CGPoint(x: size * 0.08, y: size * 0.18),
                end: CGPoint(x: size * 0.92, y: size * 0.24),
                alpha: 0.90,
                blendMode: .screen
            )

            let lowerRibbon = UIBezierPath()
            lowerRibbon.move(to: CGPoint(x: size * 0.14, y: size * 0.72))
            lowerRibbon.addCurve(
                to: CGPoint(x: size * 0.88, y: size * 0.78),
                controlPoint1: CGPoint(x: size * 0.32, y: size * 0.48),
                controlPoint2: CGPoint(x: size * 0.62, y: size * 0.92)
            )
            drawGradientRibbon(
                in: cgContext,
                path: lowerRibbon,
                lineWidth: size * 0.17,
                colors: [
                    UIColor(hex: 0x315CFF, alpha: 0.94),
                    UIColor(hex: 0x3EE7FF, alpha: 0.88),
                    UIColor(hex: 0xA54BFF, alpha: 0.84)
                ],
                start: CGPoint(x: size * 0.10, y: size * 0.72),
                end: CGPoint(x: size * 0.90, y: size * 0.78),
                alpha: 0.80,
                blendMode: .screen
            )

            let rightFlow = UIBezierPath()
            rightFlow.move(to: CGPoint(x: size * 0.74, y: size * 0.10))
            rightFlow.addCurve(
                to: CGPoint(x: size * 0.68, y: size * 0.92),
                controlPoint1: CGPoint(x: size * 0.88, y: size * 0.30),
                controlPoint2: CGPoint(x: size * 0.54, y: size * 0.60)
            )
            drawGradientRibbon(
                in: cgContext,
                path: rightFlow,
                lineWidth: size * 0.12,
                colors: [
                    UIColor.white.withAlphaComponent(0.98),
                    UIColor(hex: 0x70F6FF, alpha: 0.92),
                    UIColor(hex: 0x318AFF, alpha: 0.18)
                ],
                start: CGPoint(x: size * 0.76, y: size * 0.10),
                end: CGPoint(x: size * 0.62, y: size * 0.92),
                alpha: 0.84,
                blendMode: .screen
            )

            let magentaFlow = UIBezierPath()
            magentaFlow.move(to: CGPoint(x: size * 0.22, y: size * 0.84))
            magentaFlow.addCurve(
                to: CGPoint(x: size * 0.80, y: size * 0.28),
                controlPoint1: CGPoint(x: size * 0.18, y: size * 0.52),
                controlPoint2: CGPoint(x: size * 0.58, y: size * 0.58)
            )
            drawGradientRibbon(
                in: cgContext,
                path: magentaFlow,
                lineWidth: size * 0.10,
                colors: [
                    UIColor(hex: 0xE182FF, alpha: 0.86),
                    UIColor(hex: 0xFF80B8, alpha: 0.82),
                    UIColor.white.withAlphaComponent(0.78)
                ],
                start: CGPoint(x: size * 0.24, y: size * 0.86),
                end: CGPoint(x: size * 0.82, y: size * 0.26),
                alpha: 0.70,
                blendMode: .screen
            )

            let shadowBand = UIBezierPath()
            shadowBand.move(to: CGPoint(x: size * 0.18, y: size * 0.56))
            shadowBand.addCurve(
                to: CGPoint(x: size * 0.83, y: size * 0.48),
                controlPoint1: CGPoint(x: size * 0.36, y: size * 0.38),
                controlPoint2: CGPoint(x: size * 0.62, y: size * 0.70)
            )
            drawGradientRibbon(
                in: cgContext,
                path: shadowBand,
                lineWidth: size * 0.20,
                colors: [
                    UIColor(hex: 0x0A0218, alpha: 0.10),
                    UIColor.black.withAlphaComponent(0.96),
                    UIColor(hex: 0x140625, alpha: 0.16)
                ],
                start: CGPoint(x: size * 0.18, y: size * 0.58),
                end: CGPoint(x: size * 0.82, y: size * 0.48),
                alpha: 0.88,
                blendMode: .multiply
            )

            drawEllipticalRadialGlow(
                in: cgContext,
                rect: CGRect(
                    x: size * 0.35,
                    y: size * 0.36,
                    width: size * 0.30,
                    height: size * 0.22
                ),
                rotation: -0.18,
                centerOffset: CGPoint(x: 0, y: size * 0.01),
                colors: [
                    UIColor.black.withAlphaComponent(0.98),
                    UIColor(hex: 0x1A0830, alpha: 0.84),
                    UIColor.clear
                ]
            )

            drawEllipticalRadialGlow(
                in: cgContext,
                rect: CGRect(
                    x: size * 0.15,
                    y: size * 0.08,
                    width: size * 0.22,
                    height: size * 0.13
                ),
                rotation: -0.70,
                centerOffset: CGPoint(x: -size * 0.02, y: -size * 0.02),
                colors: [
                    UIColor.white.withAlphaComponent(0.96),
                    UIColor(hex: 0x92F8FF, alpha: 0.52),
                    UIColor.clear
                ]
            )

            drawRadialGlow(
                in: cgContext,
                rect: rect,
                center: CGPoint(x: size * 0.63, y: size * 0.34),
                radius: size * 0.15,
                colors: [
                    UIColor.white.withAlphaComponent(0.72),
                    UIColor(hex: 0xFF7EB4, alpha: 0.48),
                    UIColor.clear
                ]
            )

            drawRadialGlow(
                in: cgContext,
                rect: rect,
                center: CGPoint(x: size * 0.59, y: size * 0.58),
                radius: size * 0.14,
                colors: [
                    UIColor.white.withAlphaComponent(0.70),
                    UIColor(hex: 0x72F5FF, alpha: 0.42),
                    UIColor.clear
                ]
            )
        }
    }

    static func makeRadialMaskTexture(size: CGFloat = 768) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: CGSize(width: size, height: size))
            drawRadialGlow(
                in: context.cgContext,
                rect: rect,
                center: CGPoint(x: size * 0.5, y: size * 0.5),
                radius: size * 0.48,
                colors: [
                    UIColor.white,
                    UIColor.white.withAlphaComponent(0.95),
                    UIColor.white.withAlphaComponent(0.6),
                    UIColor.clear
                ]
            )
        }
    }

    private static func drawRadialGlow(
        in context: CGContext,
        rect: CGRect,
        center: CGPoint,
        radius: CGFloat,
        colors: [UIColor]
    ) {
        let locations = colors.indices.map { CGFloat($0) / CGFloat(max(colors.count - 1, 1)) }
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors.map(\.cgColor) as CFArray,
            locations: locations
        )
        context.drawRadialGradient(
            gradient!,
            startCenter: center,
            startRadius: 0,
            endCenter: center,
            endRadius: radius,
            options: [.drawsAfterEndLocation]
        )
    }

    private static func drawGradientRibbon(
        in context: CGContext,
        path: UIBezierPath,
        lineWidth: CGFloat,
        colors: [UIColor],
        start: CGPoint,
        end: CGPoint,
        alpha: CGFloat,
        blendMode: CGBlendMode
    ) {
        let strokedPath = path.cgPath.copy(
            strokingWithWidth: lineWidth,
            lineCap: .round,
            lineJoin: .round,
            miterLimit: 10
        )

        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors.map(\.cgColor) as CFArray,
            locations: colors.indices.map { CGFloat($0) / CGFloat(max(colors.count - 1, 1)) }
        )

        context.saveGState()
        context.setAlpha(alpha)
        context.setBlendMode(blendMode)
        context.addPath(strokedPath)
        context.clip()
        context.drawLinearGradient(
            gradient!,
            start: start,
            end: end,
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
        context.restoreGState()
    }

    private static func drawEllipticalRadialGlow(
        in context: CGContext,
        rect: CGRect,
        rotation: CGFloat,
        centerOffset: CGPoint,
        colors: [UIColor]
    ) {
        let center = CGPoint(x: rect.midX, y: rect.midY)

        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: rotation)
        context.translateBy(x: -center.x, y: -center.y)
        context.addPath(UIBezierPath(ovalIn: rect).cgPath)
        context.clip()
        drawRadialGlow(
            in: context,
            rect: rect,
            center: CGPoint(x: center.x + centerOffset.x, y: center.y + centerOffset.y),
            radius: max(rect.width, rect.height) * 0.82,
            colors: colors
        )
        context.restoreGState()
    }
}

private extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        let red = CGFloat((hex & 0xFF0000) >> 16) / 255
        let green = CGFloat((hex & 0x00FF00) >> 8) / 255
        let blue = CGFloat(hex & 0x0000FF) / 255
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}

struct AIChatHomeLayout {
    let contentWidth: CGFloat
    let heroStageWidth: CGFloat
    let horizontalPadding: CGFloat
    let bottomPadding: CGFloat
    let isCompactHeight: Bool
    let titleFontSize: CGFloat
    let titleWidth: CGFloat
    let heroHeight: CGFloat
    let promptMaxWidth: CGFloat
    let titleTopPadding: CGFloat
    let safeAreaInsets: EdgeInsets
}
