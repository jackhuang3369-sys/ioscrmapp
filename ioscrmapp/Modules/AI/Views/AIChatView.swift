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
            // 1. Brighter Futuristic background (Blue - Purple - Deep Violet)
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.35, blue: 0.8),
                    Color(red: 0.35, green: 0.15, blue: 0.75),
                    Color(red: 0.25, green: 0.1, blue: 0.6)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Abstract technology mesh / background paths
            backgroundMesh

            VStack(spacing: 0) {
                // Header (Action buttons)
                header
                
                // Welcome Text at Top
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.title.replacingOccurrences(of: "\\n", with: "\n"))
                        .font(.du(34, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DUSpacing.xxl)
                .padding(.top, DUSpacing.xxl)
                
                Spacer()

                // Center Element with scattered Prompts
                ZStack {
                    // Magical Floating Orb
                    aiCoreFeature
                    
                    // Scattered Prompt Capsules (absolute positioning)
                    scatteredPrompts
                }
                .frame(height: 300)
                
                Spacer()
                
                // Bottom Voice Action
                voiceActionBar
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 10)
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

    private var backgroundMesh: some View {
        ZStack {
            // Fluid abstract lines simulating voice waves or network
            ForEach(0..<6, id: \.self) { i in
                RoundedRectangle(cornerRadius: 150)
                    .stroke(Color.white.opacity(0.04 - Double(i) * 0.005), lineWidth: 1)
                    .frame(width: 300 + CGFloat(i) * 30, height: 200 + CGFloat(i) * 40)
                    .rotationEffect(.degrees(isAnimatingCore ? 45 + Double(i) * 10 : 0 + Double(i) * 20))
                    .offset(x: isAnimatingCore ? 20 : -10, y: isAnimatingCore ? -20 : 10)
                    .animation(.easeInOut(duration: 8 + Double(i)).repeatForever(autoreverses: true), value: isAnimatingCore)
            }
            
            ForEach(0..<4, id: \.self) { i in
                Circle()
                    .stroke(Color.cyan.opacity(0.03), lineWidth: 2)
                    .frame(width: 400 + CGFloat(i) * 80)
                    .offset(y: 100)
            }
        }
    }

    private var header: some View {
        HStack {
            Spacer()
            HStack(spacing: DUSpacing.xl) {
                Button {
                    // History/Message log placeholder mapping
                    dismiss()
                } label: {
                    Image(systemName: "rectangle.3.group.bubble.left")
                        .font(.du(22, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                }
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.du(24, weight: .light))
                        .foregroundColor(.white.opacity(0.85))
                }
            }
            .padding(.trailing, DUSpacing.xl)
            .padding(.top, DUSpacing.lg)
        }
    }

    private var aiCoreFeature: some View {
        ZStack {
            // Bright aura
            Circle()
                .fill(RadialGradient(gradient: Gradient(colors: [Color(red: 0.4, green: 0.1, blue: 0.9).opacity(0.7), .clear]), center: .center, startRadius: 40, endRadius: 180))
                .frame(width: 360, height: 360)
                .scaleEffect(isAnimatingCore ? 1.08 : 0.92)
                .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: isAnimatingCore)
            
            // Core Magical Sphere (simulating colorful liquid glass)
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.cyan, Color.blue, Color.purple]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Vibrant color blobs to simulate thick gradient mesh
                Circle()
                    .fill(Color.pink)
                    .frame(width: 90, height: 90)
                    .blur(radius: 20)
                    .offset(x: isAnimatingCore ? -30 : 20, y: isAnimatingCore ? -40 : 10)
                
                Circle()
                    .fill(Color(red: 0.1, green: 0.9, blue: 0.8))
                    .frame(width: 80, height: 80)
                    .blur(radius: 25)
                    .offset(x: isAnimatingCore ? 30 : -20, y: isAnimatingCore ? 30 : -10)

                Circle()
                    .fill(Color.orange)
                    .frame(width: 60, height: 60)
                    .blur(radius: 20)
                    .offset(x: 10, y: -40)
            }
            .frame(width: 170, height: 170)
            .clipShape(Circle())
            // Top specular highlight
            .overlay(
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.white.opacity(0.8), .clear, .clear]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .padding(2)
            )
            .shadow(color: Color.purple.opacity(0.4), radius: 30, x: 0, y: 10)
            .scaleEffect(isAnimatingCore ? 1.03 : 0.97)
            .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: isAnimatingCore)
        }
    }

    private var scatteredPrompts: some View {
        Group {
            if viewModel.suggestedPrompts.count >= 1 {
                promptCapsule(viewModel.suggestedPrompts[0])
                    .offset(x: -80, y: -60)
            }
            if viewModel.suggestedPrompts.count >= 2 {
                promptCapsule(viewModel.suggestedPrompts[1])
                    .offset(x: 110, y: 20)
            }
            if viewModel.suggestedPrompts.count >= 3 {
                promptCapsule(viewModel.suggestedPrompts[2])
                    .offset(x: -60, y: 80)
            }
        }
    }

    private func promptCapsule(_ text: String) -> some View {
        Button {
            viewModel.sendSuggestedPrompt(text)
        } label: {
            Text(text)
                .font(.du(13, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .background(Color.white.opacity(0.1))
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    private var voiceActionBar: some View {
        VStack(spacing: DUSpacing.sm) {
            Text("Hold to Talk ~")
                .font(.du(14, weight: .regular))
                .foregroundColor(.white.opacity(0.75))
            
            ZStack {
                // Outer subtle rings 
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    .frame(width: 130, height: 130)
                
                Circle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 100, height: 100)
                
                // Ripple effect
                Circle()
                    .stroke(Color.cyan.opacity(rippleOpacity), lineWidth: 1.5)
                    .frame(width: 76, height: 76)
                    .scaleEffect(rippleScale)
                
                // Main Voice Button
                Button {
                    triggerVoiceAnimation()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(hex: 0x2A1559)) // Base dark purple center
                            .frame(width: 76, height: 76)
                        
                        Circle()
                            // Colorful conic gradient border exactly like image
                            .strokeBorder(
                                AngularGradient(
                                    gradient: Gradient(colors: [.cyan, .blue, .purple, .pink, .orange, .cyan]),
                                    center: .center
                                ),
                                lineWidth: 4
                            )
                            .frame(width: 76, height: 76)
                            .shadow(color: Color.purple.opacity(0.5), radius: 10, x: 0, y: 4)
                        
                        Image(systemName: "mic.fill")
                            .font(.du(24, weight: .medium))
                            .foregroundColor(.cyan)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, DUSpacing.xl)
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

