import CoreGraphics
import Foundation

@main
struct WeatherHourlyStripSmokeTests {
    static func main() throws {
        try testBuild24HourWindowCountAndOrder()
        try testDemoTemperatureProfile()
        try testSolarMarkers()
        try testWindowHighLowComputation()
        try testCenterTallHeightProfile()
        try testBarHeightScaleOnlyActivatesDuringDrag()
        try testDragProtrusionExtendsAboveBaseline()
        try testGrayscaleGetsLighterWithHigherTemperature()
        try testFeedbackGateFiresOnlyOnIndexChange()
        try testSceneTemperatureAnimationStopsDuringDrag()
        try testBubbleTextUsesNonPaddedHour()
        print("Weather hourly strip smoke tests passed")
    }

    private static func testBuild24HourWindowCountAndOrder() throws {
        let points = WeatherHourlyStripCore.build24HourStrip(startingAtHour: 16, currentTemperature: 25)
        try require(points.count == 24, "24-hour strip must contain exactly 24 points")
        try require(points.first?.hour24 == 16, "first point must match the start hour")
        try require(points[1].hour24 == 17, "hours must be consecutive")
        try require(points[7].hour24 == 23, "hours must progress up to 23")
        try require(points[8].hour24 == 0, "hours must wrap after 23")
    }

    private static func testWindowHighLowComputation() throws {
        let points = [
            WeatherHourlyStripPoint(id: "a", hour24: 10, label: "10", temperature: 20, isCurrent: false),
            WeatherHourlyStripPoint(id: "b", hour24: 11, label: "11", temperature: 28, isCurrent: false),
            WeatherHourlyStripPoint(id: "c", hour24: 12, label: "12", temperature: 15, isCurrent: false)
        ]
        let range = WeatherHourlyStripCore.temperatureRange(points)
        try require(range.high == 28, "high must be max temperature")
        try require(range.low == 15, "low must be min temperature")
    }

    private static func testSolarMarkers() throws {
        try require(WeatherHourlyStripCore.solarMarker(forHour: 6) == .sunrise, "06:00 should be sunrise marker")
        try require(WeatherHourlyStripCore.solarMarker(forHour: 18) == .sunset, "18:00 should be sunset marker")
        try require(WeatherHourlyStripCore.solarMarker(forHour: 12) == nil, "non sunrise/sunset hours should have no marker")
    }

    private static func testDemoTemperatureProfile() throws {
        let points = WeatherHourlyStripCore.build24HourStrip(startingAtHour: 0, currentTemperature: 33)
        let temperatures = Set(points.map(\.temperature))

        try require(temperatures == Set([31, 33, 34]), "demo profile must only use 31, 33 and 34")

        let byHour = Dictionary(uniqueKeysWithValues: points.map { ($0.hour24, $0.temperature) })
        try require(byHour[14] == 34, "14:00 must be the daily high 34")
        try require(byHour[18] == 31, "18:00 must be night low 31")
        try require(byHour[0] == 31, "00:00 must be night low 31")
        try require(byHour[5] == 31, "05:00 must be night low 31")
        try require(byHour[6] == 33, "06:00 must return to daytime 33")
    }

    private static func testCenterTallHeightProfile() throws {
        let center = WeatherHourlyStripCore.emphasisScale(index: 8, focusedIndex: 8)
        let near = WeatherHourlyStripCore.emphasisScale(index: 9, focusedIndex: 8)
        let far = WeatherHourlyStripCore.emphasisScale(index: 10, focusedIndex: 8)
        let outside = WeatherHourlyStripCore.emphasisScale(index: 13, focusedIndex: 8)

        try require(center > near, "center must be taller than immediate neighbor")
        try require(near > far, "first side level must be taller than second side level")
        try require(far > outside, "second side level must be taller than outside levels")
    }

    private static func testBarHeightScaleOnlyActivatesDuringDrag() throws {
        let idle = WeatherHourlyStripCore.barHeightScale(index: 10, focusedIndex: 8, isDragging: false)
        let draggingCenter = WeatherHourlyStripCore.barHeightScale(index: 8, focusedIndex: 8, isDragging: true)
        let draggingNear = WeatherHourlyStripCore.barHeightScale(index: 9, focusedIndex: 8, isDragging: true)

        try require(idle == 1.0, "idle strip should keep full-height bars")
        try require(draggingCenter == 1.0, "focused dragging bar should stay at full height")
        try require(draggingNear < draggingCenter, "adjacent dragging bar should step down from the center")
    }

    private static func testDragProtrusionExtendsAboveBaseline() throws {
        let idle = WeatherHourlyStripCore.barTopExtension(index: 8, focusedIndex: 8, isDragging: false)
        let center = WeatherHourlyStripCore.barTopExtension(index: 8, focusedIndex: 8, isDragging: true)
        let near = WeatherHourlyStripCore.barTopExtension(index: 9, focusedIndex: 8, isDragging: true)
        let far = WeatherHourlyStripCore.barTopExtension(index: 10, focusedIndex: 8, isDragging: true)
        let outside = WeatherHourlyStripCore.barTopExtension(index: 13, focusedIndex: 8, isDragging: true)

        try require(idle == 0, "idle strip should not protrude above the baseline rail")
        try require(center > 0, "focused dragging bar should protrude above the baseline rail")
        try require(center > near, "center protrusion must exceed the adjacent bar protrusion")
        try require(near > far, "adjacent protrusion must exceed the second-ring protrusion")
        try require(far > outside, "second-ring protrusion must exceed outside bars")
        try require(outside == 0, "outside bars should stay on the baseline rail")
    }

    private static func testGrayscaleGetsLighterWithHigherTemperature() throws {
        let dark = WeatherHourlyStripCore.grayscaleValue(
            temperature: 10,
            minTemperature: 10,
            maxTemperature: 30
        )
        let light = WeatherHourlyStripCore.grayscaleValue(
            temperature: 30,
            minTemperature: 10,
            maxTemperature: 30
        )
        try require(light > dark, "higher temperature should map to lighter grayscale")
    }

    private static func testFeedbackGateFiresOnlyOnIndexChange() throws {
        let first = WeatherHourlyStripCore.shouldTriggerFeedback(previousFocusedIndex: nil, nextFocusedIndex: 0)
        let same = WeatherHourlyStripCore.shouldTriggerFeedback(previousFocusedIndex: 0, nextFocusedIndex: 0)
        let changed = WeatherHourlyStripCore.shouldTriggerFeedback(previousFocusedIndex: 0, nextFocusedIndex: 1)

        try require(first, "initial focus should trigger feedback")
        try require(!same, "same index must not trigger feedback")
        try require(changed, "changed index must trigger feedback")
    }

    private static func testSceneTemperatureAnimationStopsDuringDrag() throws {
        try require(
            !WeatherHourlyStripCore.shouldAnimateSceneTemperatureChange(isDragging: true),
            "scene temperature should update without animation during drag scrubbing"
        )
        try require(
            WeatherHourlyStripCore.shouldAnimateSceneTemperatureChange(isDragging: false),
            "scene temperature may animate for non-drag selections"
        )
    }

    private static func testBubbleTextUsesNonPaddedHour() throws {
        try require(WeatherHourlyStripCore.bubbleText(hour24: 3) == "3:00", "bubble text should not use leading zero")
        try require(WeatherHourlyStripCore.bubbleText(hour24: 18) == "18:00", "bubble text should preserve two-digit evening hour")
    }
}

private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw NSError(
            domain: "WeatherHourlyStripSmokeTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}
