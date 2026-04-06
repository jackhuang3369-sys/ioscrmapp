import SwiftUI
import SceneKit

struct WeatherMainView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var sceneManager = WeatherSceneManager(temperature: MockWeatherData.today.temperature, mode: .main)
    @StateObject private var detailSceneManager = WeatherSceneManager(temperature: MockWeatherData.today.temperature, mode: .sunDetail)
    @State private var selectedTimelineID = MockWeatherData.timeline.first?.id ?? "now"
    @State private var isSunDetailPresented = false

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
                    .scaleEffect(isSunDetailPresented ? 0.985 : 1)
                    .blur(radius: isSunDetailPresented ? 6 : 0)
                    .opacity(isSunDetailPresented ? 0.22 : 1)
                    .allowsHitTesting(!isSunDetailPresented)
                    .animation(.easeInOut(duration: 0.24), value: isSunDetailPresented)

                if isSunDetailPresented {
                    WeatherSunDetailOverlay(
                        manager: detailSceneManager,
                        size: proxy.size,
                        safeAreaInsets: proxy.safeAreaInsets,
                        onClose: exitSunDetail
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    .zIndex(10)
                }
            }
            .ignoresSafeArea()
        }
        .preferredColorScheme(.light)
        .onAppear {
            WeatherAudioPlayer.shared.playDetailedEnter()
            sceneManager.setTemperature(selectedEntry.temperature, animated: false)
            detailSceneManager.setTemperature(selectedEntry.temperature, animated: false)
        }
    }

    private func mainScene(in proxy: GeometryProxy) -> some View {
        ZStack {
            background

            VStack(spacing: 0) {
                topBar
                cityHeader
                    .zIndex(2)

                WeatherSceneView(
                    scene: sceneManager.scene,
                    manager: sceneManager,
                    onSunTap: enterSunDetail
                )
                .frame(height: proxy.size.height * 0.59)
                .padding(.top, 28)
                .padding(.horizontal, 10)
                .zIndex(1)

                Spacer(minLength: max(4, proxy.size.height * 0.01))

                Text(weather.title)
                    .font(.du(24, weight: .bold))
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
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        selectedTimelineID = entry.id
                    }
                    sceneManager.setTemperature(entry.temperature, animated: true)
                    detailSceneManager.setTemperature(entry.temperature, animated: false)
                }
                .frame(width: proxy.size.width * 0.8)
                .padding(.bottom, max(proxy.safeAreaInsets.bottom, 12) + 24)
            }
        }
        .businessAIAssistant(
            session: session,
            aiChatService: aiChatService,
            onNavigate: handleAIChatNavigation(_:)
        )
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0xFCFCFA), Color(hex: 0xF2F0EB)],
                startPoint: .top,
                endPoint: .bottom
            )

            WeatherWindBackgroundView()
                .opacity(0.95)

            RadialGradient(
                colors: [Color(hex: 0xFF6B6B, opacity: 0.08), .clear],
                center: .top,
                startRadius: 10,
                endRadius: 280
            )
        }
    }

    private var topBar: some View {
        HStack {
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

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 56)
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
        .padding(.top, 12)
    }

    private func enterSunDetail() {
        guard !isSunDetailPresented else { return }
        detailSceneManager.setTemperature(selectedEntry.temperature, animated: false)
        sceneManager.setTemperatureVisibility(isHidden: true, animated: true)
        withAnimation(.spring(response: 0.56, dampingFraction: 0.88, blendDuration: 0.12)) {
            isSunDetailPresented = true
        }
        WeatherAudioPlayer.shared.playDetailedEnter()
    }

    private func exitSunDetail() {
        guard isSunDetailPresented else { return }
        sceneManager.setTemperatureVisibility(isHidden: false, animated: true)
        withAnimation(.spring(response: 0.48, dampingFraction: 0.86, blendDuration: 0.08)) {
            isSunDetailPresented = false
        }
        WeatherAudioPlayer.shared.playShapeTap()
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
}

private struct WeatherSunDetailOverlay: View {
    let manager: WeatherSceneManager
    let size: CGSize
    let safeAreaInsets: EdgeInsets
    let onClose: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0xFBFBF8), Color(hex: 0xF0ECE7)],
                startPoint: .top,
                endPoint: .bottom
            )

            WeatherWindBackgroundView()
                .opacity(0.95)

            WeatherSunDynamicBackdrop(glowStrength: 0.18)

            WeatherSunDismissEdges(onDismiss: onClose)

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

                WeatherSceneView(
                    scene: manager.scene,
                    manager: manager,
                    onSunTap: nil,
                    allowsInteraction: false
                )
                .frame(height: min(size.height * 0.56, 470))
                .padding(.top, 2)
                .padding(.horizontal, 6)

                Spacer(minLength: 0)

                WeatherSunInsightPanel()
                    .padding(.horizontal, 28)
                    .padding(.bottom, max(safeAreaInsets.bottom, 14) + 2)
            }
        }
        .ignoresSafeArea()
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

private struct WeatherSunDynamicBackdrop: View {
    let glowStrength: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let drift = CGFloat(sin(t * 0.36))
            let glowOffset = CGFloat(cos(t * 0.24))

            ZStack {
                RadialGradient(
                    colors: [Color(hex: 0xFF2A2A, opacity: glowStrength), .clear],
                    center: .init(x: 0.48 + drift * 0.03, y: 0.2 + glowOffset * 0.02),
                    startRadius: 22,
                    endRadius: 360
                )

                RadialGradient(
                    colors: [.clear, Color.black.opacity(glowStrength * 0.82)],
                    center: .center,
                    startRadius: 180,
                    endRadius: 860
                )
            }
        }
    }
}

private struct WeatherSunInsightPanel: View {
    private let uvCurve: [CGFloat] = [3.2, 2.4, 1.1, 0.3, 0.2, 0.2, 0.2, 1.7, 2.8, 6.1, 7.0, 8.8, 9.6, 7.8]

    var body: some View {
        VStack(spacing: 8) {
            metricRow(title: "紫外线指数", value: "4", highlighted: true)
            metricRow(title: "日出", value: "6:06上午", highlighted: false)
            metricRow(title: "日落", value: "6:36下午", highlighted: false)

            HStack {
                Text("现在")
                Spacer()
                Text("18时")
                Spacer()
                Text("0时")
                Spacer()
                Text("6时")
                Spacer()
                Text("12时")
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
                    Text("天")
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

                    Text("星期")
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