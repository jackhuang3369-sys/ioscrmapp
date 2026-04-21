import CoreGraphics
import Foundation

@main
struct WeatherSpinInteractionSmokeTests {
    static func main() throws {
        try testSecondScreenCanCycleAllSixFrontDimensions()
        try testSecondScreenSlowOrbitUnderStayThreshold_returnsCurrentFront()
        try testSecondScreenSlowOrbitOverAdvanceThreshold_advancesSingleStep()
        try testSecondScreenMiddleBandOrbit_doesNotSkipPastNearestNextFront()
        try testSecondScreenFastOrbit_capsAtTenTurns()
        try testSecondScreenAutoSpinDelay_waitsForTwoSeconds()
        try testSecondScreenHitZones_keepSelfSpinSeparateFromOrbit()
        try testSecondScreenHitZones_keepTimelineAndDayWeekOutOfOrbit()
        print("Weather second-screen smoke tests passed")
    }

    private static let tuning = WeatherSecondScreenMotionTuning.default
    private static let orbitController = WeatherSecondScreenOrbitController(tuning: tuning)

    private static func testSecondScreenCanCycleAllSixFrontDimensions() throws {
        let visited = Set(WeatherDetailDimension.allCases.map { WeatherDetailDimension.sun.advanced(by: $0.rawValue) })
        try require(
            visited.count == WeatherDetailDimension.allCases.count,
            "all six weather dimensions should be reachable as front-facing items"
        )
    }

    private static func testSecondScreenSlowOrbitUnderStayThreshold_returnsCurrentFront() throws {
        let decision = orbitController.settleDecision(
            sample: WeatherSecondScreenOrbitGestureSample(
                translationRatio: 0.72,
                predictedTranslationRatio: 0.82,
                velocityPointsPerSecond: 220,
                duration: 0.42
            )
        )
        try require(
            decision.stepOffset == 0,
            "slow orbit drag below the 3/4-screen threshold should return to the current front"
        )
    }

    private static func testSecondScreenSlowOrbitOverAdvanceThreshold_advancesSingleStep() throws {
        let decision = orbitController.settleDecision(
            sample: WeatherSecondScreenOrbitGestureSample(
                translationRatio: 1.38,
                predictedTranslationRatio: 1.45,
                velocityPointsPerSecond: 260,
                duration: 0.40
            )
        )
        try require(
            decision.stepOffset == 1,
            "slow orbit drag over the 4/3-screen threshold should advance exactly one front item"
        )
    }

    private static func testSecondScreenMiddleBandOrbit_doesNotSkipPastNearestNextFront() throws {
        let advanceDecision = orbitController.settleDecision(
            sample: WeatherSecondScreenOrbitGestureSample(
                translationRatio: 0.96,
                predictedTranslationRatio: 1.06,
                velocityPointsPerSecond: 240,
                duration: 0.44
            )
        )
        try require(
            advanceDecision.stepOffset == 1,
            "middle-band drags may only resolve to the current or nearest next front"
        )

        let stayDecision = orbitController.settleDecision(
            sample: WeatherSecondScreenOrbitGestureSample(
                translationRatio: 0.94,
                predictedTranslationRatio: 0.98,
                velocityPointsPerSecond: 210,
                duration: 0.46
            )
        )
        try require(
            stayDecision.stepOffset == 0,
            "middle-band drags below the projected next-front threshold should snap back to the current front"
        )
    }

    private static func testSecondScreenFastOrbit_capsAtTenTurns() throws {
        let decision = orbitController.settleDecision(
            sample: WeatherSecondScreenOrbitGestureSample(
                translationRatio: 0.52,
                predictedTranslationRatio: 2.8,
                velocityPointsPerSecond: 12_500,
                duration: 0.12
            )
        )
        try require(decision.usesMomentum, "fast orbit drags should enter momentum mode")
        try require(decision.stepOffset == 10, "fast orbit drags should cap planned turns at ten")
    }

    private static func testSecondScreenAutoSpinDelay_waitsForTwoSeconds() throws {
        try require(
            !orbitController.shouldStartAutoSpin(after: 1.99),
            "front-facing self-spin should remain paused before the 2s idle delay"
        )
        try require(
            orbitController.shouldStartAutoSpin(after: 2.0),
            "front-facing self-spin should resume once the 2s idle delay elapses"
        )
    }

    private static func testSecondScreenHitZones_keepSelfSpinSeparateFromOrbit() throws {
        let zones = WeatherSecondScreenHitZones(
            closeZone: .null,
            dayWeekZone: .null,
            nowTimelineZone: .null,
            selfSpinZone: CGRect(x: 80, y: 40, width: 220, height: 320),
            orbitZone: CGRect(x: 0, y: 0, width: 390, height: 600)
        )

        try require(
            zones.zone(at: CGPoint(x: 190, y: 180)) == .selfSpin,
            "drags starting in the front self-spin area should stay owned by self-spin"
        )
        try require(
            zones.zone(at: CGPoint(x: 28, y: 220)) == .orbit,
            "blank-space drags outside the self-spin area should route to orbit"
        )
    }

    private static func testSecondScreenHitZones_keepTimelineAndDayWeekOutOfOrbit() throws {
        let zones = WeatherSecondScreenHitZones(
            closeZone: .null,
            dayWeekZone: CGRect(x: 110, y: 196, width: 170, height: 34),
            nowTimelineZone: CGRect(x: 0, y: 162, width: 390, height: 28),
            selfSpinZone: .null,
            orbitZone: CGRect(x: 0, y: 0, width: 390, height: 232)
        )

        try require(
            zones.zone(at: CGPoint(x: 150, y: 205)) == .dayWeek,
            "Day/Week control hits should not leak into orbit ownership"
        )
        try require(
            zones.zone(at: CGPoint(x: 100, y: 172)) == .nowTimeline,
            "Now timeline hits should remain display-only and not trigger orbit"
        )
        try require(
            zones.zone(at: CGPoint(x: 52, y: 60)) == .orbit,
            "the UV card region outside Now/DayWeek should still drive orbit"
        )
    }
}

private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw NSError(
            domain: "WeatherSecondScreenSmokeTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}
