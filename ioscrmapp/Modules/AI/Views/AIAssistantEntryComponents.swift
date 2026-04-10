import SwiftUI

enum AIAssistantPreferences {
    static let isBusinessEntryHiddenKey = "assistant.businessEntry.hidden"
    static let businessEntryNormalizedXKey = "assistant.businessEntry.normalizedX"
    static let businessEntryNormalizedYKey = "assistant.businessEntry.normalizedY"
}

struct AIAssistantChatOverlay: View {
    @Binding var isPresented: Bool

    let custSubInfo: CustSubInfo
    let language: AppLanguage
    let aiChatService: any AIChatServicing
    let offersService: (any OffersServicing)?
    let onNavigate: (AIChatNavigationTarget) -> Void

    var body: some View {
        GeometryReader { proxy in
            let topInset = max(proxy.safeAreaInsets.top + 38, 52)
            let bottomSafeArea = proxy.safeAreaInsets.bottom
            let sheetHeight = max(proxy.size.height - topInset + bottomSafeArea, 620)
            let portraitWidth = min(max(proxy.size.width * 0.155, 76), 88)
            let portraitLift = portraitWidth * 1.20
            let bubbleText = AIChatLocalizedCopy
                .title(for: language)
                .replacingOccurrences(of: "\n", with: " ")
            let bubbleWidth = min(max(proxy.size.width * 0.46, 180), 250)

            ZStack(alignment: .bottom) {
                Color.black.opacity(0.3)
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismiss()
                    }

                ZStack(alignment: .topLeading) {
                    HStack(alignment: .top, spacing: 10) {
                        Image("AIChatAssistantPortrait")
                            .resizable()
                            .scaledToFit()
                            .frame(width: portraitWidth)
                            .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)

                        Text(bubbleText)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .minimumScaleFactor(0.84)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                            .frame(width: bubbleWidth, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.white.opacity(0.18))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Color.white.opacity(0.32), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                    }
                    .padding(.leading, 16)
                    .offset(x: 0, y: -portraitLift)

                    AIChatView(
                        custSubInfo: custSubInfo,
                        language: language,
                        aiChatService: aiChatService,
                        offersService: offersService
                    ) { target in
                        dismiss()
                        onNavigate(target)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: sheetHeight)
                    .background(
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
                    )
                    .clipShape(AIAssistantTopRoundedRectangle(radius: 36))
                    .overlay(
                        AIAssistantTopRoundedRectangle(radius: 36)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.45), .white.opacity(0.08), .white.opacity(0.25)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    )
                }
                .frame(maxWidth: .infinity)
                .frame(height: sheetHeight, alignment: .top)
                .shadow(color: Color(hex: 0x1E3A8A).opacity(0.4), radius: 50, x: 0, y: -12)
                .shadow(color: Color.black.opacity(0.25), radius: 20, x: 0, y: -5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(edges: .bottom)
        }
        .ignoresSafeArea(.keyboard)
        .zIndex(100)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func dismiss() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isPresented = false
        }
    }
}

struct AIAssistantFloatingButton: View {
    let accessibilityLabel: String
    let action: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.96), Color(hex: 0xECF6FF)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.88), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 20, x: 0, y: 12)

            AIAssistantOrbitalIcon()
                .scaleEffect(0.84)
                .frame(width: 56, height: 56)
        }
        .frame(width: 68, height: 68)
        .contentShape(Circle())
        .onTapGesture(perform: action)
        .onLongPressGesture(minimumDuration: 0.75, perform: onLongPress)
        .accessibilityElement()
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityAddTraits(.isButton)
    }
}

struct AIAssistantOrbitalIcon: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            AIAssistantOrbitalVisual(
                colorRotation: Angle.degrees((time * 58).truncatingRemainder(dividingBy: 360)),
                whiteRotation: Angle.degrees((time * -72).truncatingRemainder(dividingBy: 360)),
                starPhases: (0..<3).map { time * 2.2 + Double($0) * 0.75 }
            )
        }
    }
}

struct AIAssistantStaticIcon: View {
    var body: some View {
        AIAssistantOrbitalVisual(
            colorRotation: .degrees(38),
            whiteRotation: .degrees(-62),
            starPhases: [0.9, 1.3, 0.6]
        )
    }
}

struct BusinessPageAIAssistantModifier: ViewModifier {
    @EnvironmentObject private var languageStore: AppLanguageStore
    @AppStorage(AIAssistantPreferences.isBusinessEntryHiddenKey) private var isBusinessEntryHidden = false
    @AppStorage(AIAssistantPreferences.businessEntryNormalizedXKey) private var normalizedX = 0.88
    @AppStorage(AIAssistantPreferences.businessEntryNormalizedYKey) private var normalizedY = 0.78

    @State private var isAIChatPresented = false
    @State private var isHideActionVisible = false
    @State private var hideActionDismissWorkItem: DispatchWorkItem?
    @State private var dragStartCenter: CGPoint?

    let session: CustSubInfo
    let aiChatService: any AIChatServicing
    let offersService: (any OffersServicing)?
    let onNavigate: (AIChatNavigationTarget) -> Void

    func body(content: Content) -> some View {
        ZStack(alignment: .bottomTrailing) {
            content

            if !isBusinessEntryHidden && !isAIChatPresented {
                GeometryReader { proxy in
                    let buttonSize = CGSize(width: 68, height: 68)
                    let halfWidth = buttonSize.width / 2
                    let halfHeight = buttonSize.height / 2
                    let minX = halfWidth + 12
                    let maxX = max(minX, proxy.size.width - halfWidth - 12)
                    let minY = max(proxy.safeAreaInsets.top + halfHeight + 12, halfHeight + 12)
                    let maxY = max(minY, proxy.size.height - proxy.safeAreaInsets.bottom - halfHeight - 24)
                    let currentCenter = CGPoint(
                        x: clampedCenterX(width: proxy.size.width, minX: minX, maxX: maxX),
                        y: clampedCenterY(height: proxy.size.height, minY: minY, maxY: maxY)
                    )

                    HStack(spacing: 10) {
                        if isHideActionVisible {
                            Button("Hide") {
                                cancelHideActionDismiss()
                                isBusinessEntryHidden = true
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                                    isHideActionVisible = false
                                }
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.black.opacity(0.82))
                            .padding(.horizontal, 16)
                            .frame(height: 42)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.72), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 8)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }

                        AIAssistantFloatingButton(
                            accessibilityLabel: localized("home.tab.aiAgent"),
                            action: {
                                cancelHideActionDismiss()
                                isHideActionVisible = false
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                                    isAIChatPresented = true
                                }
                            },
                            onLongPress: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                                    isHideActionVisible = true
                                }
                                scheduleHideActionDismiss()
                            }
                        )
                    }
                    .position(x: currentCenter.x, y: currentCenter.y)
                    .gesture(
                        DragGesture(minimumDistance: 6)
                            .onChanged { value in
                                cancelHideActionDismiss()
                                isHideActionVisible = false
                                let origin = dragStartCenter ?? currentCenter
                                if dragStartCenter == nil {
                                    dragStartCenter = currentCenter
                                }
                                let nextX = min(max(origin.x + value.translation.width, minX), maxX)
                                let nextY = min(max(origin.y + value.translation.height, minY), maxY)
                                normalizedX = nextX / max(proxy.size.width, 1)
                                normalizedY = nextY / max(proxy.size.height, 1)
                            }
                            .onEnded { _ in
                                dragStartCenter = nil
                            }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .transition(.scale(scale: 0.92).combined(with: .opacity))
                .zIndex(10)
            }

            if isAIChatPresented {
                AIAssistantChatOverlay(
                    isPresented: $isAIChatPresented,
                    custSubInfo: session,
                    language: languageStore.currentLanguage,
                    aiChatService: aiChatService,
                    offersService: offersService,
                    onNavigate: onNavigate
                )
            }
        }
    }

    private func localized(_ key: String, arguments: [String] = []) -> String {
        languageStore.string(key, arguments: arguments)
    }

    private func scheduleHideActionDismiss() {
        cancelHideActionDismiss()
        let workItem = DispatchWorkItem {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                isHideActionVisible = false
            }
        }
        hideActionDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4, execute: workItem)
    }

    private func cancelHideActionDismiss() {
        hideActionDismissWorkItem?.cancel()
        hideActionDismissWorkItem = nil
    }

    private func clampedCenterX(width: CGFloat, minX: CGFloat, maxX: CGFloat) -> CGFloat {
        min(max(CGFloat(normalizedX) * max(width, 1), minX), maxX)
    }

    private func clampedCenterY(height: CGFloat, minY: CGFloat, maxY: CGFloat) -> CGFloat {
        min(max(CGFloat(normalizedY) * max(height, 1), minY), maxY)
    }
}

extension View {
    func businessAIAssistant(
        session: CustSubInfo,
        aiChatService: any AIChatServicing,
        offersService: (any OffersServicing)? = nil,
        onNavigate: @escaping (AIChatNavigationTarget) -> Void = { _ in }
    ) -> some View {
        modifier(
            BusinessPageAIAssistantModifier(
                session: session,
                aiChatService: aiChatService,
                offersService: offersService,
                onNavigate: onNavigate
            )
        )
    }
}

private struct AIAssistantTopRoundedRectangle: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + radius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct AIAssistantOrbitalVisual: View {
    let colorRotation: Angle
    let whiteRotation: Angle
    let starPhases: [Double]

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: 0xAB7BFF, opacity: 0.28),
                            Color(hex: 0xAB7BFF, opacity: 0)
                        ],
                        center: .center,
                        startRadius: 6,
                        endRadius: 38
                    )
                )
                .frame(width: 72, height: 72)

            Circle()
                .stroke(
                    AngularGradient(
                        gradient: Gradient(
                            colors: [
                                Color(hex: 0x2ED8FF),
                                Color(hex: 0x7A72FF),
                                Color(hex: 0xFF6FE5),
                                Color(hex: 0xFFD05E),
                                Color(hex: 0x2ED8FF)
                            ]
                        ),
                        center: .center
                    ),
                    lineWidth: 3
                )
                .frame(width: 60, height: 60)
                .rotationEffect(colorRotation)
                .shadow(color: Color(hex: 0x7A72FF, opacity: 0.22), radius: 4)

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.92), lineWidth: 2)
                    .frame(width: 44, height: 44)

                Circle()
                    .fill(Color.white)
                    .frame(width: 8, height: 8)
                    .shadow(color: Color.white.opacity(0.75), radius: 10)
                    .offset(y: -22)
                    .rotationEffect(whiteRotation)
            }

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .white,
                                Color(hex: 0x79DFFF),
                                Color(hex: 0x5B9DFF),
                                Color(hex: 0x7D65FF),
                                Color(hex: 0xFF7BDF)
                            ],
                            center: .init(x: 0.35, y: 0.3),
                            startRadius: 2,
                            endRadius: 28
                        )
                    )
                    .frame(width: 54, height: 54)
                    .shadow(color: Color(hex: 0x6E68FF, opacity: 0.34), radius: 12, x: 0, y: 8)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .white,
                                Color(hex: 0xB9F0FF),
                                Color(hex: 0x8DD2FF),
                                Color(hex: 0xB874FF),
                                Color(hex: 0xFF96E8)
                            ],
                            center: .init(x: 0.32, y: 0.28),
                            startRadius: 2,
                            endRadius: 20
                        )
                    )
                    .frame(width: 34, height: 34)

                ForEach(Array(starPhases.enumerated()), id: \.offset) { index, phase in
                    Text("✦")
                        .font(.system(size: starSize(for: index), weight: .semibold))
                        .foregroundColor(.white)
                        .shadow(color: Color.white.opacity(0.85), radius: 12)
                        .opacity(0.35 + (0.65 * max(0, sin(phase))))
                        .scaleEffect(0.75 + (0.4 * max(0, sin(phase))))
                        .offset(starOffset(for: index))
                }
            }
        }
    }

    private func starSize(for index: Int) -> CGFloat {
        switch index {
        case 0:
            return 9
        case 1:
            return 11
        default:
            return 8
        }
    }

    private func starOffset(for index: Int) -> CGSize {
        switch index {
        case 0:
            return CGSize(width: -9, height: -13)
        case 1:
            return CGSize(width: 10, height: -5)
        default:
            return CGSize(width: -1, height: 13)
        }
    }
}
