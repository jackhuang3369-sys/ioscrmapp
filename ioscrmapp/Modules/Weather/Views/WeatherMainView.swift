import SwiftUI
import SceneKit

struct WeatherMainView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var sceneManager = WeatherSceneManager(temperature: MockWeatherData.today.temperature)
    @State private var selectedTimelineID = MockWeatherData.timeline.first?.id ?? "now"

    private let weather = MockWeatherData.today

    private var selectedEntry: WeatherTimelineEntry {
        MockWeatherData.timeline.first(where: { $0.id == selectedTimelineID }) ?? MockWeatherData.timeline[0]
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                background

                VStack(spacing: 0) {
                    topBar
                    cityHeader
                        .zIndex(2)

                    WeatherSceneView(scene: sceneManager.scene, manager: sceneManager)
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
                    }
                    .frame(width: proxy.size.width * 0.8)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom, 12) + 24)
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
                .tracking(2.8)
                .foregroundColor(Color.black.opacity(0.44))

            Text(weather.dateText)
                .font(.du(11, weight: .semibold))
                .tracking(1.8)
                .foregroundColor(Color.black.opacity(0.30))
        }
        .padding(.top, 12)
    }
}
