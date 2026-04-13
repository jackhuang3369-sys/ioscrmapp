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

struct WeatherHourlyBubbleState: Equatable {
    let isVisible: Bool
    let bubbleTopY: CGFloat
}

enum WeatherHourlyStripCore {
    static let pointCount = 24
    static let clearSkyLiftAboveBubble: CGFloat = 3
    static let clearSkyLiftOutlineWidth: CGFloat = 1
    static let clearSkyRestoreAnimationDuration: Double = 0.10

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

    static func normalizedTemperatureValue(temperature: Int, minTemperature: Int, maxTemperature: Int) -> Double {
        let lower = min(minTemperature, maxTemperature)
        let upper = max(minTemperature, maxTemperature)
        let span = max(upper - lower, 1)
        let normalized = Double(temperature - lower) / Double(span)
        return min(max(normalized, 0), 1)
    }

    static func groupedTemperatures(_ points: [WeatherHourlyStripPoint], blockSize: Int) -> [Int] {
        guard blockSize > 1, !points.isEmpty else {
            return points.map(\.temperature)
        }

        var grouped = points.map(\.temperature)

        for groupStart in stride(from: 0, to: points.count, by: blockSize) {
            let groupEnd = min(groupStart + blockSize, points.count)
            let groupPoints = points[groupStart..<groupEnd]
            let average = Int(round(Double(groupPoints.map(\.temperature).reduce(0, +)) / Double(groupPoints.count)))

            for index in groupStart..<groupEnd {
                grouped[index] = average
            }
        }

        return grouped
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
        case 0: return 9
        case 1: return 6
        case 2: return 3
        default: return 0
        }
    }

    static func directionalTopExtension(
        index: Int,
        focusedPosition: CGFloat,
        directionSign: CGFloat,
        isDragging: Bool,
        maxExtension: CGFloat = 9
    ) -> CGFloat {
        guard isDragging else { return 0 }

        let distance = abs(CGFloat(index) - focusedPosition)
        let base: CGFloat

        if distance < 1 {
            base = (maxExtension - 4) + (1 - distance) * 4
        } else if distance < 2 {
            base = (maxExtension - 7) + (2 - distance) * 3
        } else if distance < 3 {
            base = (3 - distance) * 2
        } else {
            base = 0
        }

        let side = CGFloat(index) - focusedPosition
        var directionalDelta: CGFloat = 0
        if directionSign > 0.1 {
            if side > 0, side <= 2.5 {
                directionalDelta = side <= 1.5 ? 1.2 : 0.6
            } else if side < 0, side >= -2.5 {
                directionalDelta = side >= -1.5 ? -1.1 : -0.55
            }
        } else if directionSign < -0.1 {
            if side < 0, side >= -2.5 {
                directionalDelta = side >= -1.5 ? 1.2 : 0.6
            } else if side > 0, side <= 2.5 {
                directionalDelta = side <= 1.5 ? -1.1 : -0.55
            }
        }

        return min(maxExtension, max(0, base + directionalDelta))
    }

    static func bubbleCenterX(
        sidePadding: CGFloat,
        endCapWidth: CGFloat,
        itemWidth: CGFloat,
        focusedPosition: CGFloat
    ) -> CGFloat {
        sidePadding + endCapWidth + itemWidth * focusedPosition + itemWidth / 2
    }

    static func bubbleCenterY(
        topOverlayHeight: CGFloat,
        focusedTopExtension: CGFloat,
        bubbleDiameter: CGFloat,
        offsetAboveTop: CGFloat
    ) -> CGFloat {
        let focusedBarTopY = topOverlayHeight - focusedTopExtension
        return focusedBarTopY - offsetAboveTop - bubbleDiameter / 2
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

    static func clearSkyLiftTargetBaselineY(
        stripMinY: CGFloat,
        bubbleTopY: CGFloat,
        liftAboveBubble: CGFloat = clearSkyLiftAboveBubble
    ) -> CGFloat {
        stripMinY + bubbleTopY - liftAboveBubble
    }

    static func clearSkyLiftOffset(
        idleTitleBaselineY: CGFloat,
        targetTitleBaselineY: CGFloat,
        bubbleVisible: Bool
    ) -> CGFloat {
        guard bubbleVisible else { return 0 }
        return targetTitleBaselineY - idleTitleBaselineY
    }

    static func clearSkyOutlineWidth(isLifted: Bool) -> CGFloat {
        isLifted ? clearSkyLiftOutlineWidth : 0
    }

    static func maxSingleFrameStep(in samples: [CGFloat]) -> CGFloat {
        guard samples.count > 1 else { return 0 }
        var maxStep: CGFloat = 0
        for index in 1..<samples.count {
            maxStep = max(maxStep, abs(samples[index] - samples[index - 1]))
        }
        return maxStep
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
        // - 34C at 14:00 (daily high)
        // - 31C from 22:00 to sunrise (lowest arrives 4 hours after sunset)
        // - 33C for all other hours
        // The current 3D temperature assets only cover the digits used by 31...35,
        // so this profile stays within that range.
        if hour24 == 14 {
            return 34
        }

        if hour24 >= 22 || hour24 < 6 {
            return 31
        }

        switch hour24 {
        case 5...7:
            return 31
        case 8...10:
            return 33
        case 11...13:
            return 34
        case 14...15:
            return 31
        case 16...17:
            return 34
        case 18...20:
            return 33
        default:
            return 33
        }
    }
}
