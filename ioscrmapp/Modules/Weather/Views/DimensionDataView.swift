import SwiftUI

// MARK: - DimensionDataView（各维度下 1/3 数据展示区）

struct DimensionDataView: View {
    let dimension: WeatherDetailDimension
    let weather: CurrentWeather
    let detail: WeatherDetailData

    var body: some View {
        Group {
            switch dimension {
            case .temperature: temperatureData
            case .wind:        windData
            case .precipitation: precipitationData
            case .air:         airData
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Temperature Panel

    private var temperatureData: some View {
        HStack(alignment: .center, spacing: 0) {
            // 当前温度（大）
            VStack(alignment: .leading, spacing: 4) {
                Text("\(detail.temperature.current)°")
                    .font(.system(size: 64, weight: .thin, design: .rounded))
                    .foregroundColor(.white)
                Text(weather.condition.displayName)
                    .font(.du(14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            // 辅助数据
            VStack(alignment: .trailing, spacing: 12) {
                DataBadge(
                    label: "Feels Like",
                    value: "\(detail.temperature.feelsLike)°",
                    symbol: "thermometer.low"
                )
                DataBadge(
                    label: "High",
                    value: "\(detail.temperature.high)°",
                    symbol: "arrow.up"
                )
                DataBadge(
                    label: "Low",
                    value: "\(detail.temperature.low)°",
                    symbol: "arrow.down"
                )
            }
        }
    }

    // MARK: - Wind Panel

    private var windData: some View {
        HStack(alignment: .center, spacing: 0) {
            // 风速（大）
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(detail.wind.speed)")
                        .font(.system(size: 64, weight: .thin, design: .rounded))
                        .foregroundColor(.white)
                    Text("mph")
                        .font(.du(16, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.bottom, 8)
                }
                // 方向指示箭头
                HStack(spacing: 6) {
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.cyan)
                        .rotationEffect(.degrees(detail.wind.directionDegrees))
                    Text(detail.wind.direction)
                        .font(.du(14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
            }

            Spacer()

            // 阵风
            VStack(alignment: .trailing, spacing: 12) {
                DataBadge(
                    label: "Gusts",
                    value: "\(detail.wind.gust) mph",
                    symbol: "wind"
                )
                // 风力等级条
                WindBeaufortBar(speed: detail.wind.speed)
            }
        }
    }

    // MARK: - Precipitation Panel

    private var precipitationData: some View {
        HStack(alignment: .center, spacing: 0) {
            // 降水概率（大）
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text("\(detail.precipitation.probability)")
                        .font(.system(size: 64, weight: .thin, design: .rounded))
                        .foregroundColor(.white)
                    Text("%")
                        .font(.du(20, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.bottom, 8)
                }
                Text("Chance of Rain")
                    .font(.du(13, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            // 辅助数据 + 分钟时间轴
            VStack(alignment: .trailing, spacing: 8) {
                DataBadge(
                    label: "Accumulation",
                    value: String(format: "%.2f\"", detail.precipitation.accumulation),
                    symbol: "drop.fill"
                )
                MinutelyRainBar(minutely: detail.precipitation.minutely)
            }
        }
    }

    // MARK: - Air Quality Panel

    private var airData: some View {
        HStack(alignment: .center, spacing: 0) {
            // AQI（大）
            VStack(alignment: .leading, spacing: 4) {
                Text("\(detail.air.aqi)")
                    .font(.system(size: 64, weight: .thin, design: .rounded))
                    .foregroundColor(aqiColor)
                Text(detail.air.level)
                    .font(.du(15, weight: .semibold))
                    .foregroundColor(aqiColor.opacity(0.9))
            }

            Spacer()

            // 辅助指标
            VStack(alignment: .trailing, spacing: 10) {
                DataBadge(
                    label: "UV Index",
                    value: "\(detail.air.uv) \(detail.air.uvLevel)",
                    symbol: "sun.max.fill"
                )
                DataBadge(
                    label: "Visibility",
                    value: "\(detail.air.visibility) mi",
                    symbol: "eye.fill"
                )
                DataBadge(
                    label: "Humidity",
                    value: "\(detail.air.humidity)%",
                    symbol: "humidity.fill"
                )
            }
        }
    }

    private var aqiColor: Color {
        let aqi = detail.air.aqi
        switch aqi {
        case 0...50:   return .green
        case 51...100: return .yellow
        case 101...150: return .orange
        default:       return .red
        }
    }
}

// MARK: - Shared Sub-components

private struct DataBadge: View {
    let label: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.du(11))
                .foregroundColor(.white.opacity(0.5))
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.du(10, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))
                Text(value)
                    .font(.du(13, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
    }
}

private struct WindBeaufortBar: View {
    let speed: Int // mph

    // Beaufort 0-12 → mph: 0,1,4,8,13,19,25,32,39,47,55,64,73+
    private var beaufortLevel: Int {
        switch speed {
        case 0:     return 0
        case 1...3: return 1
        case 4...7: return 2
        case 8...12: return 3
        case 13...18: return 4
        case 19...24: return 5
        case 25...31: return 6
        case 32...38: return 7
        default:    return 8
        }
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("Beaufort \(beaufortLevel)")
                .font(.du(10))
                .foregroundColor(.white.opacity(0.5))
            HStack(spacing: 3) {
                ForEach(0..<8, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i < beaufortLevel ? Color.cyan : Color.white.opacity(0.2))
                        .frame(width: 6, height: CGFloat(8 + i * 2))
                }
            }
        }
    }
}

private struct MinutelyRainBar: View {
    let minutely: [(minute: Int, intensity: Int)]

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("Next 60 min")
                .font(.du(10))
                .foregroundColor(.white.opacity(0.5))
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(minutely.prefix(12).indices, id: \.self) { i in
                    let intensity = minutely[i].intensity
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.cyan.opacity(intensity > 0 ? 0.7 : 0.2))
                        .frame(width: 5, height: max(4, CGFloat(intensity) / 100 * 28 + 4))
                }
            }
        }
    }
}
