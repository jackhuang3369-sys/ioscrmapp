import Foundation
import CoreGraphics

struct WeatherHourlyStripPoint: Identifiable, Equatable {
    let id: String
    let hour24: Int
    let label: String
    let temperature: Int
    let isCurrent: Bool
}

struct WeatherHourlyTemperatureRange: Equatable {
    let high: Int
    let low: Int
}

enum WeatherSolarMarker: Equatable {
    case sunrise
    case sunset
}

enum WeatherHourlyStripCore {
    static let pointCount = 24

    static func build24HourStrip(startingAtHour startHour: Int, currentTemperature: Int) -> [WeatherHourlyStripPoint] {
        let normalizedStart = normalizeHour(startHour)
        return (0..<pointCount).map { offset in
            let hour = normalizeHour(normalizedStart + offset)
            let temperature = synthesizedTemperature(hour24: hour, startHour: normalizedStart, currentTemperature: currentTemperature)
            return WeatherHourlyStripPoint(
                id: String(format: "%02d", hour),
                hour24: hour,
                label: offset == 0 ? "NOW" : String(format: "%02d", hour),
                temperature: temperature,
                isCurrent: offset == 0
            )
        }
    }

    static func build24HourStrip(referenceDate: Date, calendar: Calendar, currentTemperature: Int) -> [WeatherHourlyStripPoint] {
        let startHour = calendar.component(.hour, from: referenceDate)
        return build24HourStrip(startingAtHour: startHour, currentTemperature: currentTemperature)
    }

    static func temperatureRange(_ points: [WeatherHourlyStripPoint]) -> WeatherHourlyTemperatureRange {
        guard let first = points.first else {
            return WeatherHourlyTemperatureRange(high: 0, low: 0)
        }

        let high = points.map(\.temperature).max() ?? first.temperature
        let low = points.map(\.temperature).min() ?? first.temperature
        return WeatherHourlyTemperatureRange(high: high, low: low)
    }

    static func grayscaleValue(temperature: Int, minTemperature: Int, maxTemperature: Int) -> Double {
        let lower = min(minTemperature, maxTemperature)
        let upper = max(minTemperature, maxTemperature)
        let span = max(upper - lower, 1)
        let normalized = Double(temperature - lower) / Double(span)
        let clamped = min(max(normalized, 0), 1)
        return 0.54 + clamped * 0.16
    }

    static func emphasisScale(index: Int, focusedIndex: Int) -> CGFloat {
        switch abs(index - focusedIndex) {
        case 0: return 1.0
        case 1: return 0.78
        case 2: return 0.62
        default: return 0.46
        }
    }

    static func barHeightScale(index: Int, focusedIndex: Int, isDragging: Bool) -> CGFloat {
        guard isDragging else { return 1.0 }
        return emphasisScale(index: index, focusedIndex: focusedIndex)
    }

    static func barTopExtension(index: Int, focusedIndex: Int, isDragging: Bool) -> CGFloat {
        guard isDragging else { return 0 }

        switch abs(index - focusedIndex) {
        case 0: return 18
        case 1: return 11
        case 2: return 6
        default: return 0
        }
    }

    static func focusedIndex(forLocationX x: CGFloat, itemWidth: CGFloat, count: Int) -> Int {
        guard count > 0, itemWidth > 0 else { return 0 }
        let raw = Int(floor(x / itemWidth))
        return min(max(raw, 0), count - 1)
    }

    static func shouldTriggerFeedback(previousFocusedIndex: Int?, nextFocusedIndex: Int) -> Bool {
        guard let previousFocusedIndex else { return true }
        return previousFocusedIndex != nextFocusedIndex
    }

    static func shouldAnimateSceneTemperatureChange(isDragging: Bool) -> Bool {
        !isDragging
    }

    static func bubbleText(hour24: Int) -> String {
        let hour = normalizeHour(hour24)
        return "\(hour):00"
    }

    static func solarMarker(forHour hour24: Int) -> WeatherSolarMarker? {
        switch normalizeHour(hour24) {
        case 6:
            return .sunrise
        case 18:
            return .sunset
        default:
            return nil
        }
    }

    private static func normalizeHour(_ value: Int) -> Int {
        let mod = value % 24
        return mod < 0 ? mod + 24 : mod
    }

    private static func synthesizedTemperature(hour24: Int, startHour: Int, currentTemperature: Int) -> Int {
        _ = startHour
        _ = currentTemperature

        // Demo profile requested by product:
        // - 31C from sunset to sunrise
        // - 34C at 14:00 (daily high)
        // - 33C for all other daytime hours
        if hour24 == 14 {
            return 34
        }

        if hour24 >= 18 || hour24 < 6 {
            return 31
        }

        return 33
    }
}
