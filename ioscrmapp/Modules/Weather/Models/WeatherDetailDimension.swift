import Foundation
import CoreGraphics

enum WeatherDetailDimension: Int, CaseIterable, Identifiable, Hashable {
    case sun
    case cloud
    case air
    case moon
    case temperature
    case precipitation

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .sun:
            return "Sun"
        case .cloud:
            return "Cloud"
        case .air:
            return "Air"
        case .moon:
            return "Moon"
        case .temperature:
            return "Temp"
        case .precipitation:
            return "Rain"
        }
    }

    var subtitle: String {
        switch self {
        case .sun:
            return "Solar detail"
        case .cloud:
            return "Cloud cover"
        case .air:
            return "Wind and pressure"
        case .moon:
            return "Moon phase"
        case .temperature:
            return "Thermal range"
        case .precipitation:
            return "Precipitation"
        }
    }

    func advanced(by offset: Int) -> WeatherDetailDimension {
        let all = Self.allCases
        let nextIndex = (rawValue + offset).positiveModulo(all.count)
        return all[nextIndex]
    }

    func loopDistance(to dimension: WeatherDetailDimension) -> Int {
        let count = Self.allCases.count
        var distance = dimension.rawValue - rawValue
        if distance >= count / 2 {
            distance -= count
        }
        if distance < -count / 2 {
            distance += count
        }
        return distance
    }
}

struct WeatherDetailMetric: Identifiable {
    let id: String
    let title: String
    let value: String
}

struct WeatherDetailSnapshot: Identifiable {
    let id: WeatherDetailDimension
    let dimension: WeatherDetailDimension
    let primaryValue: String
    let primaryUnit: String
    let metrics: [WeatherDetailMetric]
    let chartLabels: [String]
    let chartValues: [CGFloat]
    let chartStyle: WeatherDetailChartStyle
}

enum WeatherDetailChartStyle: Equatable {
    case line
    case area
}

extension WeatherDetailSnapshot {
    static func mock(for dimension: WeatherDetailDimension) -> WeatherDetailSnapshot {
        switch dimension {
        case .sun:
            return WeatherDetailSnapshot(
                id: dimension,
                dimension: dimension,
                primaryValue: "4",
                primaryUnit: "UV",
                metrics: [
                    WeatherDetailMetric(id: "sunrise", title: "Sunrise", value: "6:06 AM"),
                    WeatherDetailMetric(id: "sunset", title: "Sunset", value: "6:36 PM")
                ],
                chartLabels: ["Now", "18", "0", "6", "12"],
                chartValues: [3.2, 2.4, 1.1, 0.3, 0.2, 0.2, 0.2, 1.7, 2.8, 6.1, 7.0, 8.8, 9.6, 7.8],
                chartStyle: .line
            )
        case .cloud:
            return WeatherDetailSnapshot(
                id: dimension,
                dimension: dimension,
                primaryValue: "12",
                primaryUnit: "%",
                metrics: [
                    WeatherDetailMetric(id: "cover", title: "Cloud Cover", value: "12%"),
                    WeatherDetailMetric(id: "trend", title: "Trend", value: "Light")
                ],
                chartLabels: ["Now", "6", "12", "18", "24"],
                chartValues: [10, 12, 18, 23, 16, 12, 9, 14, 20, 24, 19, 13],
                chartStyle: .area
            )
        case .air:
            return WeatherDetailSnapshot(
                id: dimension,
                dimension: dimension,
                primaryValue: "3.1",
                primaryUnit: "m/s",
                metrics: [
                    WeatherDetailMetric(id: "gust", title: "Gust", value: "5.6 m/s"),
                    WeatherDetailMetric(id: "visibility", title: "Visibility", value: "21.9 km"),
                    WeatherDetailMetric(id: "pressure", title: "Pressure", value: "1005 hPa"),
                    WeatherDetailMetric(id: "aqi", title: "AQI", value: "--")
                ],
                chartLabels: ["Now", "6", "12", "18", "24"],
                chartValues: [2.4, 2.8, 3.1, 3.7, 4.2, 3.8, 3.4, 3.1, 2.9, 3.2, 3.7, 3.3],
                chartStyle: .line
            )
        case .moon:
            return WeatherDetailSnapshot(
                id: dimension,
                dimension: dimension,
                primaryValue: "10",
                primaryUnit: "%",
                metrics: [
                    WeatherDetailMetric(id: "phase", title: "Phase", value: "Crescent"),
                    WeatherDetailMetric(id: "rise", title: "Moonrise", value: "5:44 AM"),
                    WeatherDetailMetric(id: "set", title: "Moonset", value: "10:33 PM"),
                    WeatherDetailMetric(id: "full", title: "Full Moon", value: "2/5/26")
                ],
                chartLabels: ["Now", "6", "12", "18", "24"],
                chartValues: [10, 12, 13, 15, 16, 18, 17, 16, 14, 12, 11, 10],
                chartStyle: .area
            )
        case .temperature:
            return WeatherDetailSnapshot(
                id: dimension,
                dimension: dimension,
                primaryValue: "31",
                primaryUnit: "°C",
                metrics: [
                    WeatherDetailMetric(id: "high", title: "High", value: "33°C"),
                    WeatherDetailMetric(id: "low", title: "Low", value: "25°C"),
                    WeatherDetailMetric(id: "feels", title: "Feels Like", value: "31°C"),
                    WeatherDetailMetric(id: "humidity", title: "Humidity", value: "35%")
                ],
                chartLabels: ["Now", "6", "12", "18", "24"],
                chartValues: [28, 27, 26, 29, 31, 33, 32, 30, 29, 28, 27, 26],
                chartStyle: .line
            )
        case .precipitation:
            return WeatherDetailSnapshot(
                id: dimension,
                dimension: dimension,
                primaryValue: "0.0",
                primaryUnit: "mm/h",
                metrics: [
                    WeatherDetailMetric(id: "chance", title: "Chance", value: "0%"),
                    WeatherDetailMetric(id: "type", title: "Type", value: "--")
                ],
                chartLabels: ["Now", "6", "12", "18", "24"],
                chartValues: [0, 0, 0.1, 0, 0, 0.2, 0.1, 0, 0, 0, 0.1, 0],
                chartStyle: .area
            )
        }
    }
}

private extension Int {
    func positiveModulo(_ divisor: Int) -> Int {
        let remainder = self % divisor
        return remainder >= 0 ? remainder : remainder + divisor
    }
}
