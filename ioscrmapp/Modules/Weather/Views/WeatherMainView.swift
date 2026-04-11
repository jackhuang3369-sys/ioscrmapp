import SwiftUI
import SceneKit

struct WeatherMainView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var sceneManager = WeatherSceneManager(temperature: MockWeatherData.today.temperature, mode: .sunTransition)
    @State private var selectedTimelineID = MockWeatherData.timeline.first?.id ?? "now"
    @State private var isSunDetailPresented = false
    @State private var isSunTransitionActive = false
    @State private var detailOverlayOpacity = 0.0
    @State private var sceneInteractionResetVersion = 0
    
    private let session: CustSubInfo
    private let aiChatService: any AIChatServicing
    private let onAIChatNavigation: (AIChatNavigationTarget) -> Void
    private let weather = MockWeatherData.today
    
    init(
        session: CustSubInfo,
        aiChatService: any AIChatServicing,
        onAIChatNavigation: @escaping (AIChatNavigationTarget) -> Void = { _ in }
    ) {
        self.session = session
        self.aiChatService = aiChatService
        self.onAIChatNavigation = onAIChatNavigation
    }
    
    private var selectedEntry: WeatherTimelineEntry {
        MockWeatherData.timeline.first(where: { $0.id == selectedTimelineID }) ?? MockWeatherData.timeline[0]
    }
    
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                mainScene(in: proxy)
                    .allowsHitTesting(!isSunTransitionActive)
                
                if isSunDetailPresented {
                    WeatherSunDetailOverlay(
                        manager: sceneManager,
                        size: proxy.size,
                        safeAreaInsets: proxy.safeAreaInsets,
                        interfaceOpacity: detailOverlayOpacity,
                        allowsInteraction: !isSunTransitionActive,
                        onClose: exitSunDetail
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    .zIndex(8)
                }
            }
            .ignoresSafeArea()
        }
        .preferredColorScheme(.light)
        .onAppear {
            WeatherAudioPlayer.shared.playDetailedEnter()
            sceneManager.setTemperature(selectedEntry.temperature, animated: false)
        }
    }
    
    private func mainScene(in proxy: GeometryProxy) -> some View {
        let mainSceneHeight = mainSceneHeight(for: proxy)
        let hourlyStripBottomPadding = hourlyStripBottomPadding(for: proxy)

        return ZStack {
            background
            
            VStack(spacing: 0) {
                headerBar
                    .zIndex(2)
                
                WeatherSceneView(
                    scene: sceneManager.scene,
                    manager: sceneManager,
                    onSunTap: enterSunDetail,
                    onBackgroundTap: isSunDetailPresented ? exitSunDetail : nil,
                    interactionResetVersion: sceneInteractionResetVersion
                )
                .frame(height: mainSceneHeight)
                .padding(.top, 8)
                .padding(.horizontal, 0)
                .zIndex(1)
                
                Spacer(minLength: 0)

                mainForecastSection(
                    width: proxy.size.width * 0.8,
                    bottomPadding: hourlyStripBottomPadding
                )
            }
        }
        .ignoresSafeArea()
        .businessAIAssistant(
            session: session,
            aiChatService: aiChatService,
            onNavigate: handleAIChatNavigation(_:)
        )
    }
    
    private var background: some View {
        ZStack {
            Color.white
            
            WeatherWindBackgroundView()
                .opacity(0.95)
        }
    }

    private func mainForecastSection(width: CGFloat, bottomPadding: CGFloat) -> some View {
        VStack(spacing: 0) {
            Text(weather.title)
                .font(.du(26, weight: .bold))
                .foregroundColor(Color.black.opacity(0.92))
                .padding(.bottom, 8)

            WeatherHourlyStrip(
                timeline: MockWeatherData.timeline.map { entry in
                    WeatherTimelineEntry(
                        id: entry.id,
                        label: entry.label,
                        temperature: entry.temperature,
                        symbolName: entry.symbolName,
                        isCurrent: entry.isCurrent
                    )
                },
                selectedID: selectedTimelineID
            ) { entry in
                guard entry.id != selectedTimelineID else { return }
                WeatherAudioPlayer.shared.playShapeTap()
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    selectedTimelineID = entry.id
                }
                sceneManager.setTemperature(entry.temperature, animated: true)
            }
            .frame(width: width)
        }
        .opacity(isSunDetailPresented ? 0 : 1)
        .offset(y: isSunDetailPresented ? 138 : 0)
        .allowsHitTesting(!isSunDetailPresented)
        .animation(.easeInOut(duration: 0.24), value: isSunDetailPresented)
        .padding(.bottom, bottomPadding)
    }
    
    private var headerBar: some View {
        ZStack(alignment: .top) {
            HStack {
                backButton
                Spacer()
            }
            
            cityHeader
        }
        .padding(.horizontal, 18)
        .padding(.top, 56)
    }
    
    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Color.black.opacity(0.9))
                .frame(width: 38, height: 38)
                .background(Color.white.opacity(0.9))
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: 8)
        }
    }
    
    private var cityHeader: some View {
        VStack(spacing: 6) {
            Text(weather.city.uppercased())
                .font(.du(13, weight: .bold))
                .kerning(2.8)
                .foregroundColor(Color.black.opacity(0.44))
            
            Text(weather.dateText)
                .font(.du(11, weight: .semibold))
                .kerning(1.8)
                .foregroundColor(Color.black.opacity(0.30))
        }
        .frame(maxWidth: .infinity)
    }

    private func mainSceneHeight(for proxy: GeometryProxy) -> CGFloat {
        let adaptationProgress = heightAdaptationProgress(for: proxy.size.height)
        let sceneHeightRatio = 0.74 + adaptationProgress * 0.04
        return proxy.size.height * sceneHeightRatio
    }

    private func hourlyStripBottomPadding(for proxy: GeometryProxy) -> CGFloat {
        let adaptationProgress = heightAdaptationProgress(for: proxy.size.height)
        return 36 - adaptationProgress * 12
    }

    private func heightAdaptationProgress(for screenHeight: CGFloat) -> CGFloat {
        let minimumReferenceHeight: CGFloat = 844
        let maximumReferenceHeight: CGFloat = 956
        let clampedHeight = min(max(screenHeight, minimumReferenceHeight), maximumReferenceHeight)
        return (clampedHeight - minimumReferenceHeight) / (maximumReferenceHeight - minimumReferenceHeight)
    }
    
    private func enterSunDetail() {
        guard !isSunDetailPresented, !isSunTransitionActive else { return }

        sceneManager.prepareSunDetailTransition(
            temperature: selectedEntry.temperature,
            sourceRotation: sceneManager.displayGroupRotation
        )
        sceneManager.setTemperatureVisibility(isHidden: true, animated: true)

        detailOverlayOpacity = 0
        isSunTransitionActive = true

        withAnimation(.spring(response: 0.42, dampingFraction: 0.88, blendDuration: 0.10)) {
            isSunDetailPresented = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            guard isSunDetailPresented else { return }
            withAnimation(.easeOut(duration: 0.34)) {
                detailOverlayOpacity = 1
            }
        }

        sceneManager.startSunDetailTransition {
            guard isSunDetailPresented else { return }

            sceneInteractionResetVersion += 1
            isSunTransitionActive = false
        }
        WeatherAudioPlayer.shared.playDetailedEnter()
    }
    
    private func exitSunDetail() {
        guard isSunDetailPresented, !isSunTransitionActive else { return }

        isSunTransitionActive = true
        sceneManager.alignDetailSceneToFront()
        sceneInteractionResetVersion += 1

        withAnimation(.easeInOut(duration: 0.24)) {
            detailOverlayOpacity = 0
        }

        sceneManager.startReturnToMainTransition(temperature: selectedEntry.temperature) {
            sceneManager.setTemperatureVisibility(isHidden: false, animated: false)
            isSunDetailPresented = false
            isSunTransitionActive = false
            sceneInteractionResetVersion += 1
        }
        WeatherAudioPlayer.shared.playShapeTap()
    }
    private func handleAIChatNavigation(_ target: AIChatNavigationTarget) {
        guard shouldForwardAIChatNavigation(target) else {
            return
        }
        
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onAIChatNavigation(target)
        }
    }
    
    private func shouldForwardAIChatNavigation(_ target: AIChatNavigationTarget) -> Bool {
        switch target {
        case .external:
            return false
        default:
            return true
        }
    }
    
    
    private struct WeatherSunDetailOverlay: View {
        let manager: WeatherSceneManager
        let size: CGSize
        let safeAreaInsets: EdgeInsets
        let interfaceOpacity: Double
        let allowsInteraction: Bool
        let onClose: () -> Void
        
        var body: some View {
            let sceneViewportHeight = min(size.height * 0.56, 470)

            ZStack {
                WeatherSunDetailBackdrop()
                    .opacity(interfaceOpacity)
                
                WeatherSunDismissEdges(onDismiss: onClose)
                    .opacity(interfaceOpacity)
                    .allowsHitTesting(allowsInteraction)
                
                VStack(spacing: 0) {
                    HStack {
                        Button(action: onClose) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(Color.black.opacity(0.9))
                                .frame(width: 38, height: 38)
                                .background(Color.white.opacity(0.9))
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: 8)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 56)
                    .allowsHitTesting(allowsInteraction)

                    WeatherSunInteractionSurface(
                        sceneViewportHeight: sceneViewportHeight,
                        onDismiss: onClose
                    )
                    .padding(.top, 2)
                    .padding(.horizontal, 6)
                    .allowsHitTesting(allowsInteraction)
                    
                    WeatherSunInsightPanel()
                        .padding(.horizontal, 28)
                        .padding(.bottom, max(safeAreaInsets.bottom, 14) + 2)
                        .offset(y: (1 - interfaceOpacity) * 180)
                }
                .opacity(interfaceOpacity)
            }
            .ignoresSafeArea()
        }
    }
    
    private struct WeatherSunDetailBackdrop: View {
        var body: some View {
            GeometryReader { proxy in
                let size = proxy.size
                let shortestSide = min(size.width, size.height)
                let longestSide = max(size.width, size.height)
                let cornerRadius = shortestSide * 0.145
                
                ZStack {
                    RadialGradient(
                        stops: [
                            .init(color: .clear, location: 0.28),
                            .init(color: Color.black.opacity(0.03), location: 0.44),
                            .init(color: Color.black.opacity(0.10), location: 0.60),
                            .init(color: Color.black.opacity(0.22), location: 0.78),
                            .init(color: Color.black.opacity(0.38), location: 0.90),
                            .init(color: Color.black.opacity(0.50), location: 1.0)
                        ],
                        center: .center,
                        startRadius: shortestSide * 0.12,
                        endRadius: longestSide * 0.82
                    )
                    .blendMode(.multiply)
                    
                    VStack(spacing: 0) {
                        LinearGradient(
                            stops: [
                                .init(color: Color.black.opacity(0.34), location: 0.0),
                                .init(color: Color.black.opacity(0.20), location: 0.32),
                                .init(color: Color.black.opacity(0.08), location: 0.68),
                                .init(color: .clear, location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: size.height * 0.18)
                        .blur(radius: 10)
                        
                        Spacer(minLength: 0)
                        
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: Color.black.opacity(0.10), location: 0.30),
                                .init(color: Color.black.opacity(0.24), location: 0.66),
                                .init(color: Color.black.opacity(0.40), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: size.height * 0.22)
                        .blur(radius: 12)
                    }
                    .blendMode(.multiply)
                    
                    HStack(spacing: 0) {
                        LinearGradient(
                            stops: [
                                .init(color: Color.black.opacity(0.34), location: 0.0),
                                .init(color: Color.black.opacity(0.20), location: 0.34),
                                .init(color: Color.black.opacity(0.08), location: 0.70),
                                .init(color: .clear, location: 1.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: size.width * 0.14)
                        .blur(radius: 12)
                        
                        Spacer(minLength: 0)
                        
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: Color.black.opacity(0.08), location: 0.30),
                                .init(color: Color.black.opacity(0.20), location: 0.66),
                                .init(color: Color.black.opacity(0.34), location: 1.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: size.width * 0.14)
                        .blur(radius: 12)
                    }
                    .blendMode(.multiply)
                    
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.62), lineWidth: 12)
                        .blur(radius: 16)
                        .padding(-8)
                        .mask(
                            LinearGradient(
                                colors: [
                                    Color.white,
                                    Color.white.opacity(0.34),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .opacity(0.78)
                    
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.28), lineWidth: 18)
                        .blur(radius: 14)
                        .padding(-6)
                        .mask(
                            LinearGradient(
                                colors: [
                                    .clear,
                                    Color.white.opacity(0.45),
                                    Color.white
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .opacity(0.95)
                    
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.32), lineWidth: 28)
                        .blur(radius: 34)
                        .padding(-20)
                        .opacity(0.84)
                }
                .compositingGroup()
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
    
    private struct WeatherSunDismissEdges: View {
        let onDismiss: () -> Void
        
        var body: some View {
            GeometryReader { proxy in
                ZStack {
                    VStack(spacing: 0) {
                        Color.clear
                            .frame(height: min(150, proxy.size.height * 0.18))
                            .contentShape(Rectangle())
                            .onTapGesture(perform: onDismiss)
                        Spacer(minLength: 0)
                    }
                    
                    HStack(spacing: 0) {
                        Color.clear
                            .frame(width: 30)
                            .contentShape(Rectangle())
                            .onTapGesture(perform: onDismiss)
                        
                        Spacer(minLength: 0)
                        
                        Color.clear
                            .frame(width: 30)
                            .contentShape(Rectangle())
                            .onTapGesture(perform: onDismiss)
                    }
                }
            }
        }
    }

    private struct WeatherSunInteractionSurface: View {
        let sceneViewportHeight: CGFloat
        let onDismiss: () -> Void

        var body: some View {
            VStack(spacing: 0) {
                Color.clear
                    .frame(height: sceneViewportHeight)
                    .allowsHitTesting(false)

                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onDismiss)
            }
        }
    }
    
    private struct WeatherSunInsightPanel: View {
        private let uvCurve: [CGFloat] = [3.2, 2.4, 1.1, 0.3, 0.2, 0.2, 0.2, 1.7, 2.8, 6.1, 7.0, 8.8, 9.6, 7.8]
        
        var body: some View {
            VStack(spacing: 8) {
                metricRow(title: "UV", value: "4", highlighted: true)
                metricRow(title: "Sunrise", value: "6:06 AM", highlighted: false)
                metricRow(title: "Sunset", value: "6:36 PM", highlighted: false)
                
                HStack {
                    Text("Now")
                    Spacer()
                    Text("18")
                    Spacer()
                    Text("0")
                    Spacer()
                    Text("6")
                    Spacer()
                    Text("12")
                }
                .font(.du(9, weight: .medium))
                .foregroundColor(Color.black.opacity(0.72))
                .padding(.horizontal, 14)
                .padding(.top, 2)
                
                WeatherSunCurveView(values: uvCurve)
                    .frame(height: 78)
                
                WeatherSunTimelineSlider()
                
                HStack {
                    Spacer(minLength: 0)
                    
                    HStack(spacing: 10) {
                        Text("Day")
                            .font(.du(11, weight: .medium))
                            .foregroundColor(Color.black.opacity(0.90))
                        
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.black.opacity(0.12))
                            
                            Circle()
                                .fill(Color.black.opacity(0.88))
                                .padding(4)
                        }
                        .frame(width: 52, height: 26)
                        
                        Text("Week")
                            .font(.du(11, weight: .medium))
                            .foregroundColor(Color.black.opacity(0.18))
                    }
                    
                    Spacer(minLength: 0)
                }
                .padding(.top, 1)
            }
            .padding(.horizontal, 2)
        }
        
        private func metricRow(title: String, value: String, highlighted: Bool) -> some View {
            HStack(spacing: 8) {
                Text(title)
                    .font(.du(10, weight: .medium))
                    .kerning(0.9)
                    .foregroundColor(highlighted ? Color.white.opacity(0.96) : Color.black.opacity(0.88))
                    .frame(width: 92, alignment: .leading)
                
                Rectangle()
                    .fill(highlighted ? Color.white.opacity(0.22) : Color.black.opacity(0.12))
                    .frame(height: 1)
                
                Text(value)
                    .font(.du(highlighted ? 15 : 11, weight: .medium))
                    .foregroundColor(highlighted ? Color.white.opacity(0.96) : Color.black.opacity(0.88))
            }
            .padding(.horizontal, 12)
            .frame(height: highlighted ? 28 : 22)
            .background(
                Capsule()
                    .fill(highlighted ? Color.black.opacity(0.92) : Color.clear)
            )
        }
    }
    
    private struct WeatherSunTimelineSlider: View {
        var body: some View {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.black.opacity(0.10))
                    .frame(height: 7)
                
                HStack(spacing: 0) {
                    Circle()
                        .fill(Color.black.opacity(0.92))
                        .frame(width: 16, height: 16)
                    
                    Spacer(minLength: 0)
                }
                
                HStack(spacing: 11) {
                    Spacer().frame(width: 16)
                    ForEach(0..<17, id: \.self) { _ in
                        Circle()
                            .fill(Color.black.opacity(0.22))
                            .frame(width: 1.5, height: 1.5)
                    }
                    Spacer().frame(width: 8)
                }
            }
            .padding(.horizontal, 2)
        }
    }
    
    private struct WeatherSunCurveView: View {
        let values: [CGFloat]
        
        var body: some View {
            GeometryReader { proxy in
                let width = proxy.size.width
                let height = proxy.size.height
                let maxValue = max(values.max() ?? 1, 1)
                
                ZStack(alignment: .topLeading) {
                    Path { path in
                        for index in values.indices {
                            let x = CGFloat(index) / CGFloat(max(values.count - 1, 1)) * (width - 24) + 12
                            let y = (1 - values[index] / maxValue) * (height - 28) + 4
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(Color.black.opacity(0.88), style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round))
                    
                    VStack(alignment: .trailing, spacing: 18) {
                        Text("10")
                        Text("5")
                        Text("0")
                    }
                    .font(.du(10, weight: .medium))
                    .foregroundColor(Color.black.opacity(0.84))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, 3)
                    .padding(.trailing, -14)
                }
            }
        }
    }
}
