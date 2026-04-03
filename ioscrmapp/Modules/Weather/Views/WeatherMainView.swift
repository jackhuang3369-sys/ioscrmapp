import SwiftUI
import SceneKit

// MARK: - WeatherMainView（Page A 根视图 — Not Boring Weather 风格）
//
// 布局层次（从下到上）：
//   1. 天空渐变背景
//   2. 全屏 SceneKit 3D（仅占上半区，可拖拽旋转）
//   3. 顶部 overlay：城市名 + 返回按钮
//   4. 中部 SwiftUI：超大温度数字 + 天气状态标签
//   5. 底部面板：日期选择 + 逐小时预报

struct WeatherMainView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var current          = MockWeatherData.current
    @State private var hourly           = MockWeatherData.hourly
    @State private var daily            = MockWeatherData.daily
    @State private var selectedDayIndex = 0

    @StateObject private var sceneManager = WeatherSceneManager()

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                // 层 1：天空背景
                skyBackground

                // 层 2：全屏 SceneKit（3D 天气模型 + 数字，共用一个描渲和视口）
                WeatherSceneView(scene: sceneManager.scene, manager: sceneManager)
                    .ignoresSafeArea()

                // 层 3：顶部大气光晕
                atmosphereGlow(proxy: proxy)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                // 层 4：顶部 SwiftUI 文字（城市名 + 日期）
                VStack(spacing: 0) {
                    headerSection
                    Spacer(minLength: 0)
                    // 条件文字浮在底部面板上方
                    conditionLabel
                        .padding(.bottom, 18)
                }
                .ignoresSafeArea(edges: .top)
            }
        }
        .ignoresSafeArea()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomPanel
                .padding(.bottom, 8)
                .background(Color.clear)
        }
        .preferredColorScheme(.dark)
        .onAppear(perform: syncSceneWithCurrentWeather)
        .onChange(of: selectedDayIndex) { newValue in
            WeatherAudioPlayer.shared.playDaySelect()
            applySelection(for: newValue)
        }
        .onChange(of: current.isNight) { isNight in
            sceneManager.setNightMode(isNight, animated: true)
        }
    }

    // MARK: - Sub-views

    private var headerSection: some View {
        VStack(spacing: 8) {
            topBar

            VStack(spacing: 6) {
                Text(current.city)
                    .font(.du(18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.88))

                Text(dayDescriptor)
                    .font(.du(11, weight: .semibold))
                    .tracking(1.6)
                    .foregroundColor(.white.opacity(0.58))
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    // 天空渐变
    private var skyBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    current.isNight
                        ? Color(hex: 0x08111F)
                        : current.condition.skyColors.top,
                    current.isNight
                        ? Color(hex: 0x10233B)
                        : current.condition.skyColors.bottom,
                    Color(hex: 0x041827)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [Color.clear, Color.black.opacity(current.isNight ? 0.30 : 0.14)],
                startPoint: .top,
                endPoint: .bottom
            )
            .blendMode(.multiply)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 1.0), value: current.condition)
        .animation(.easeInOut(duration: 1.0), value: current.isNight)
    }

    private func atmosphereGlow(proxy: GeometryProxy) -> some View {
        RadialGradient(
            colors: current.condition.glowColors,
            center: .top,
            startRadius: 20,
            endRadius: proxy.size.width * 0.70
        )
        .frame(width: proxy.size.width, height: proxy.size.height)
        .offset(y: 0)
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.9), value: current.condition)
    }

    private var bottomPanel: some View {
        VStack(spacing: 0) {
            WeatherDatePicker(days: daily, selectedIndex: $selectedDayIndex)
            WeatherHourlyStrip(hourly: hourly)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 天气条件标签（浮在底部面板上方）

    private var conditionLabel: some View {
        Text(current.condition.eyebrowTitle)
            .font(.system(size: 13, weight: .semibold, design: .default))
            .tracking(2.4)
            .foregroundColor(.white.opacity(0.65))
            .allowsHitTesting(false)
    }

    // 顶部控制栏
    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 56)
    }

    private var dayDescriptor: String {
        let selectedDay = daily[selectedDayIndex]
        return "\(selectedDay.weekday.uppercased())  •  \(selectedDay.date.uppercased())"
    }

    private func syncSceneWithCurrentWeather() {
        WeatherAudioPlayer.shared.playDetailedEnter()
        WeatherAudioPlayer.shared.playAmbient(for: current.condition.rawValue)
        sceneManager.setCondition(current.condition, animated: false)
        sceneManager.setNightMode(current.isNight, animated: false)
        applySelection(for: selectedDayIndex, animated: false)
    }

    private func applySelection(for index: Int, animated: Bool = true) {
        guard daily.indices.contains(index) else { return }

        let day = daily[index]
        let nextWeather = CurrentWeather(
            city: current.city,
            temperature: blendedTemperature(high: day.high, low: day.low, index: index),
            feelsLike: blendedFeelsLike(high: day.high, low: day.low, condition: day.condition),
            high: day.high,
            low: day.low,
            condition: day.condition,
            isNight: current.isNight
        )

        let update = {
            current = nextWeather
            hourly = makeHourlyForecast(for: day, dayOffset: index)
        }

        if animated {
            withAnimation(.spring(response: 0.68, dampingFraction: 0.86)) {
                update()
            }
        } else {
            update()
        }

        sceneManager.setCondition(day.condition, animated: animated)
        sceneManager.setTemperature(nextWeather.temperature, animated: animated)
        if animated {
            WeatherAudioPlayer.shared.playSting(for: day.condition.rawValue)
            WeatherAudioPlayer.shared.playAmbient(for: day.condition.rawValue)
        }
        let nextNight = index == 0 ? current.isNight : derivedNightMode(for: index, condition: day.condition)
        if current.isNight != nextNight {
            current.isNight = nextNight
        }
    }

    private func blendedTemperature(high: Int, low: Int, index: Int) -> Int {
        if index == 0 {
            return MockWeatherData.current.temperature
        }
        return Int(round(Double(high + low) / 2.0 + 1.5))
    }

    private func blendedFeelsLike(high: Int, low: Int, condition: WeatherCondition) -> Int {
        let base = Int(round(Double(high + low) / 2.0))
        switch condition {
        case .clear, .partlyCloudy:
            return base - 1
        case .snow, .fog:
            return base - 3
        case .rain, .drizzle, .thunderstorm:
            return base - 2
        case .cloudy:
            return base - 1
        }
    }

    private func makeHourlyForecast(for day: DayForecast, dayOffset: Int) -> [HourlyForecast] {
        let labels = MockWeatherData.hourly.map(\.hour)
        return labels.enumerated().map { index, label in
            let progress = Double(index) / Double(max(labels.count - 1, 1))
            let tempSpan = day.high - day.low
            let swing = sin(progress * .pi) * Double(tempSpan)
            let temp = Int(round(Double(day.low) + swing))

            return HourlyForecast(
                hour: label,
                condition: shiftedCondition(from: day.condition, index: index, dayOffset: dayOffset),
                temperature: temp
            )
        }
    }

    private func shiftedCondition(from base: WeatherCondition, index: Int, dayOffset: Int) -> WeatherCondition {
        switch base {
        case .clear:
            return index < 3 ? .clear : .partlyCloudy
        case .partlyCloudy:
            return index % 4 == 3 ? .cloudy : .partlyCloudy
        case .cloudy:
            return index > 7 ? .partlyCloudy : .cloudy
        case .drizzle:
            return index > 6 ? .cloudy : .drizzle
        case .rain:
            return index < 8 ? .rain : .drizzle
        case .snow:
            return index < 7 ? .snow : .cloudy
        case .thunderstorm:
            return index < 5 ? .thunderstorm : .rain
        case .fog:
            return index < 4 ? .fog : .cloudy
        }
    }

    private func derivedNightMode(for dayOffset: Int, condition: WeatherCondition) -> Bool {
        if dayOffset == 0 {
            return current.isNight
        }

        switch condition {
        case .clear, .partlyCloudy:
            return dayOffset >= 5
        case .rain, .drizzle, .thunderstorm, .fog, .cloudy, .snow:
            return dayOffset >= 4
        }
    }
}
