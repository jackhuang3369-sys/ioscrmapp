import SwiftUI

// MARK: - WeatherConditionOverlay（温度 / 城市 / 天气叠加层）

struct WeatherConditionOverlay: View {
    let weather: CurrentWeather

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 城市名
            Text(weather.city)
                .font(.du(18, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))

            // 大温度
            Text("\(weather.temperature)°")
                .font(.system(size: 88, weight: .thin, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            // 天气状况描述
            Text(weather.condition.displayName)
                .font(.du(20, weight: .medium))
                .foregroundColor(.white.opacity(0.85))

            // 高低温
            HStack(spacing: 12) {
                Label("H:\(weather.high)°", systemImage: "arrow.up")
                    .font(.du(15, weight: .medium))
                    .foregroundColor(.white.opacity(0.75))
                Label("L:\(weather.low)°", systemImage: "arrow.down")
                    .font(.du(15, weight: .medium))
                    .foregroundColor(.white.opacity(0.75))
                Label("Feels \(weather.feelsLike)°", systemImage: "thermometer.medium")
                    .font(.du(15, weight: .medium))
                    .foregroundColor(.white.opacity(0.75))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
