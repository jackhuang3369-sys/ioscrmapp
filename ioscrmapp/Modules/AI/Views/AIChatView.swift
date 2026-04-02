import SwiftUI
import WebKit

struct AIChatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @StateObject private var viewModel: AIChatViewModel
    let onNavigate: (AIChatNavigationTarget) -> Void
    
    // Animation states
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
        ZStack {
            // 1. Futuristic Space Gradient Background
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: 0x0B0F19), Color(hex: 0x1A1025), Color(hex: 0x0F1B2A)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Subtle animated backglow
            RadialGradient(
                gradient: Gradient(colors: [DUTheme.indigo.opacity(0.15), .clear]),
                center: .center,
                startRadius: 100,
                endRadius: 400
            )
            .scaleEffect(isAnimatingCore ? 1.1 : 0.9)
            .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: isAnimatingCore)
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header (Minimalist)
                header
                
                Spacer()

                // Center AI Core Sphere
                aiCoreFeature
                
                Spacer()
                
                // Greeting and Capsule Prompts
                VStack(spacing: DUSpacing.xl) {
                    VStack(spacing: DUSpacing.xs) {
                        Text(viewModel.title)
                            .font(.du(28, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: DUTheme.cyanLight.opacity(0.3), radius: 8, x: 0, y: 0)
                            
                        Text(viewModel.subtitle)
                            .font(.du(14, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.bottom, DUSpacing.sm)
                    
                    capsulePrompts
                }
                .padding(.horizontal, DUSpacing.xl)
                
                Spacer()
                
                // Bottom Voice Action
                voiceActionBar
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 20)
            }
        }
        .onAppear {
            isAnimatingCore = true
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                coreRotation = 360
            }
            animatePrompts()
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "sparkle")
                .font(.du(20, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
                
            Text("AI Assistant")
                .font(.du(16, weight: .bold))
                .foregroundColor(.white.opacity(0.9))
                .tracking(2)
            
            Spacer()
            
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.du(16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DUSpacing.xl)
        .padding(.top, DUSpacing.md)
    }

    private var aiCoreFeature: some View {
        ZStack {
            // Outermost glowing aura
            Circle()
                .fill(RadialGradient(gradient: Gradient(colors: [DUTheme.magenta.opacity(0.3), .clear]), center: .center, startRadius: 20, endRadius: 150))
                .frame(width: 300, height: 300)
                .scaleEffect(isAnimatingCore ? 1.05 : 0.95)
                .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: isAnimatingCore)
            
            // Rotating mesh-like rings
            ZStack {
                Circle().stroke(DUTheme.cyanLight.opacity(0.2), lineWidth: 1)
                    .frame(width: 200, height: 200)
                    .rotation3DEffect(.degrees(75), axis: (x: 1, y: 0.5, z: 0))
                    .rotationEffect(.degrees(coreRotation))
                
                Circle().stroke(DUTheme.indigo.opacity(0.3), lineWidth: 2)
                    .frame(width: 220, height: 220)
                    .rotation3DEffect(.degrees(65), axis: (x: 0, y: 1, z: 0.5))
                    .rotationEffect(.degrees(-coreRotation * 0.8))
            }
            
            // Core Sphere (Code-drawn glass orb)
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [DUTheme.cyanLight, DUTheme.blue, DUTheme.magenta]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 140, height: 140)
                .overlay(
                    // Inner glow
                    Circle()
                        .stroke(Color.white.opacity(0.8), lineWidth: 2)
                        .blur(radius: 4)
                        .padding(2)
                )
                .overlay(
                    // Tech grid pattern/glare overlay
                    Circle()
                        .fill(LinearGradient(gradient: Gradient(colors: [.white.opacity(0.4), .clear]), startPoint: .topLeading, endPoint: .bottomTrailing))
                        .mask(Circle().padding(2))
                )
                .shadow(color: DUTheme.blue.opacity(0.6), radius: 20, x: 0, y: 10)
                .scaleEffect(isAnimatingCore ? 1.02 : 0.98)
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isAnimatingCore)
        }
    }

    private var capsulePrompts: some View {
        VStack(spacing: DUSpacing.md) {
            ForEach(Array(viewModel.suggestedPrompts.prefix(4).enumerated()), id: \.element) { index, prompt in
                Button {
                    // Send prompt action
                    viewModel.sendSuggestedPrompt(prompt)
                } label: {
                    HStack(spacing: DUSpacing.sm) {
                        Image(systemName: "waveform")
                            .font(.du(12, weight: .bold))
                            .foregroundColor(DUTheme.cyanLight)
                        
                        Text(prompt)
                            .font(.du(14, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                        
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, DUSpacing.lg)
                    .padding(.vertical, DUSpacing.md)
                    .background(.ultraThinMaterial)
                    // Customize ultraThinMaterial dark tint fallback
                    .background(Color.black.opacity(0.2))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .offset(y: promptOffsets[safe: index] ?? 0)
                .opacity(promptOpacities[safe: index] ?? 0)
            }
        }
    }

    private var voiceActionBar: some View {
        ZStack {
            // Ripple effects
            Circle()
                .stroke(DUTheme.cyanLight.opacity(rippleOpacity), lineWidth: 1)
                .frame(width: 80, height: 80)
                .scaleEffect(rippleScale)
            
            Circle()
                .fill(DUTheme.cyanLight.opacity(rippleOpacity * 0.2))
                .frame(width: 80, height: 80)
                .scaleEffect(rippleScale)
            
            // Main Voice Button
            Button {
                triggerVoiceAnimation()
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [DUTheme.cyan, DUTheme.blue]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 72, height: 72)
                        .shadow(color: DUTheme.cyan.opacity(0.5), radius: 15, x: 0, y: 8)
                    
                    Image(systemName: "mic.fill")
                        .font(.du(28, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
        }
        .onAppear {
            startRippleAnimation()
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

    private func startRippleAnimation() {
        withAnimation(.easeOut(duration: 2).repeatForever(autoreverses: false)) {
            rippleScale = 2.0
            rippleOpacity = 0.0
        }
    }
    
    private func triggerVoiceAnimation() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Reset and trigger a fast pulse
        rippleScale = 1.0
        rippleOpacity = 0.8
        withAnimation(.easeOut(duration: 0.5)) {
            rippleScale = 2.5
            rippleOpacity = 0.0
        }
        
        // Resume normal idle animation after
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.rippleScale = 1.0
            self.rippleOpacity = 0.8
            self.startRippleAnimation()
        }
    }
}

// Helper for safe array access
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

