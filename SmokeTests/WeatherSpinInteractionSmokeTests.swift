import CoreGraphics
import Foundation

@main
struct WeatherSpinInteractionSmokeTests {
    static func main() throws {
        try testSlowDragUnderHalfReturnsBackward()
        try testSlowDragOverHalfCommitsForward()
        try testSlowDragOverOneScreenUsesCompletedTurns()
        try testFastShortDragLowSpeedReturnsBackward()
        try testFastShortDragHighSpeedCommitsTurns()
        try testFastDragMediumVelocityCommitsOneTurn()
        try testFastDragHighVelocityCommitsMultipleTurns()
        try testFastDragOverHalfCapsAtEightTurns()
        try testLiveYawUsesOneScreenOneTurnMapping()
        try testFrontFacingHelperTreatsFullTurnsAsFrontFacing()
        try testFrontFacingToleranceBlocksDetailEntryUntilAligned()
        try testDebugSnapshotReflectsTurnCap()
        try testAutoSpinResumeUsesPreInteractionSpeed()
        print("Weather spin smoke tests passed")
    }

    private static let tuning = WeatherSpinTuning.default

    private static func testSlowDragUnderHalfReturnsBackward() throws {
        let sample = WeatherSpinGestureSample(
            translationRatio: 0.24,
            predictedTranslationRatio: 0.26,
            velocityPointsPerSecond: 180,
            duration: 0.44
        )
        let decision = WeatherSpinController(tuning: tuning).settleDecision(
            currentYawDegrees: 86,
            sample: sample
        )
        try require(decision.mode == .reverseReturnToFront, "slow drag under half should return backward")
    }

    private static func testSlowDragOverHalfCommitsForward() throws {
        let sample = WeatherSpinGestureSample(
            translationRatio: 0.72,
            predictedTranslationRatio: 0.76,
            velocityPointsPerSecond: 220,
            duration: 0.47
        )
        let decision = WeatherSpinController(tuning: tuning).settleDecision(
            currentYawDegrees: 242,
            sample: sample
        )
        try require(decision.mode == .forwardCompleteToFront, "slow drag over half should complete forward")
    }

    private static func testSlowDragOverOneScreenUsesCompletedTurns() throws {
        let sample = WeatherSpinGestureSample(
            translationRatio: 1.36,
            predictedTranslationRatio: 1.38,
            velocityPointsPerSecond: 260,
            duration: 0.52
        )
        let decision = WeatherSpinController(tuning: tuning).settleDecision(
            currentYawDegrees: 492,
            sample: sample
        )
        try require(decision.targetTurnCount == 1, "slow drag over one screen should keep completed forward turn progress")
    }

    private static func testFastShortDragLowSpeedReturnsBackward() throws {
        let sample = WeatherSpinGestureSample(
            translationRatio: 0.08,
            predictedTranslationRatio: 0.10,
            velocityPointsPerSecond: 480,
            duration: 0.20
        )
        let decision = WeatherSpinController(tuning: tuning).settleDecision(
            currentYawDegrees: 40,
            sample: sample
        )
        try require(decision.mode == .reverseReturnToFront, "short low-speed drag should still return backward")
    }

    private static func testFastShortDragHighSpeedCommitsTurns() throws {
        // Under quarter-screen distance but high velocity should still commit forward turns.
        let sample = WeatherSpinGestureSample(
            translationRatio: 0.12,
            predictedTranslationRatio: 0.16,
            velocityPointsPerSecond: 2200,
            duration: 0.11
        )
        let decision = WeatherSpinController(tuning: tuning).settleDecision(
            currentYawDegrees: 55,
            sample: sample
        )
        try require(decision.mode == .forwardMomentumTurns, "short high-speed drag should use momentum turns")
        try require(decision.targetTurnCount >= 2, "short high-speed drag should commit multiple turns")
    }

    private static func testFastDragMediumVelocityCommitsOneTurn() throws {
        // ~1.4x the min-fast velocity: just one turn
        let sample = WeatherSpinGestureSample(
            translationRatio: 0.38,
            predictedTranslationRatio: 0.46,
            velocityPointsPerSecond: 1180,
            duration: 0.14
        )
        let decision = WeatherSpinController(tuning: tuning).settleDecision(
            currentYawDegrees: 128,
            sample: sample
        )
        try require(decision.targetTurnCount == 1, "medium-velocity fast drag should commit exactly one turn")
        try require(decision.mode == .forwardSingleTurn, "medium-velocity fast drag should use single-turn mode")
    }

    /// Key behaviour: a fast but short swipe (< half screen) with high velocity spins multiple turns.
    /// This matches the original app: velocity drives turn count, distance only gates the minimum.
    private static func testFastDragHighVelocityCommitsMultipleTurns() throws {
        // 0.30 screen distance — well under half screen — but 1800 px/s
        // velocityPerTurn=800 → Int(1800/800)=2 turns
        let sample = WeatherSpinGestureSample(
            translationRatio: 0.30,
            predictedTranslationRatio: 0.35,
            velocityPointsPerSecond: 1800,
            duration: 0.11
        )
        let decision = WeatherSpinController(tuning: tuning).settleDecision(
            currentYawDegrees: 108,
            sample: sample
        )
        try require(decision.targetTurnCount >= 2, "high-velocity short drag should spin 2+ turns")
        try require(decision.mode == .forwardMomentumTurns, "high-velocity short drag should use momentum mode")
    }

    private static func testFastDragOverHalfCapsAtEightTurns() throws {
        // Very high speed should be capped at eight turns.
        let sample = WeatherSpinGestureSample(
            translationRatio: 0.84,
            predictedTranslationRatio: 2.40,
            velocityPointsPerSecond: 8400,
            duration: 0.10
        )
        let decision = WeatherSpinController(tuning: tuning).settleDecision(
            currentYawDegrees: 210,
            sample: sample
        )
        try require(decision.mode == .forwardMomentumTurns, "fast long drag should use momentum turns")
        try require(decision.targetTurnCount == 8, "fast long drag should cap total turns at eight")
        try require(decision.usesFinalTurnSlowdown, "momentum settle should slow the final turn")
    }

    private static func testLiveYawUsesOneScreenOneTurnMapping() throws {
        let controller = WeatherSpinController(tuning: tuning)
        try require(controller.liveYawDegrees(for: 1.0) == 360, "full-screen drag should equal one turn")
        try require(controller.liveYawDegrees(for: 0.5) == 180, "half-screen drag should equal half turn")
    }

    private static func testFrontFacingHelperTreatsFullTurnsAsFrontFacing() throws {
        let controller = WeatherSpinController(tuning: tuning)
        try require(controller.isFrontFacing(yawDegrees: 0, toleranceDegrees: 8), "0 degrees should be front-facing")
        try require(controller.isFrontFacing(yawDegrees: 360, toleranceDegrees: 8), "360 degrees should be front-facing")
        try require(!controller.isFrontFacing(yawDegrees: 120, toleranceDegrees: 8), "off-axis yaw should not be front-facing")
    }

    private static func testFrontFacingToleranceBlocksDetailEntryUntilAligned() throws {
        let controller = WeatherSpinController(tuning: tuning)
        try require(!controller.isFrontFacing(yawDegrees: 24, toleranceDegrees: 8), "24 degrees should still block detail entry")
        try require(controller.isFrontFacing(yawDegrees: 4, toleranceDegrees: 8), "small yaw should allow detail entry")
    }

    private static func testDebugSnapshotReflectsTurnCap() throws {
        // 8400 px/s should be capped at 8 turns.
        let sample = WeatherSpinGestureSample(
            translationRatio: 0.92,
            predictedTranslationRatio: 2.8,
            velocityPointsPerSecond: 8400,
            duration: 0.10
        )
        let decision = WeatherSpinController(tuning: tuning).settleDecision(
            currentYawDegrees: 220,
            sample: sample
        )
        // 8400 px/s should be capped at 8 turns.
        let snapshot = WeatherSpinDebugSnapshot(
            translationRatio: sample.translationRatio,
            predictedTranslationRatio: sample.predictedTranslationRatio,
            velocityPointsPerSecond: sample.velocityPointsPerSecond,
            duration: sample.duration,
            targetTurnCount: decision.targetTurnCount,
            mode: decision.mode
        )
        try require(snapshot.targetTurnCount == 8, "debug snapshot should report the capped turn count")
    }

    private static func testAutoSpinResumeUsesPreInteractionSpeed() throws {
        let resumedMain = WeatherAutoSpinRecovery.resumedSpeed(
            speedBeforeInteraction: 0,
            fallbackCurrentSpeed: -Float.pi * 2 / 30
        )
        try require(resumedMain == 0, "main scene should resume to its pre-interaction speed")

        let detailSpeed = -Float.pi * 2 / 30
        let resumedDetail = WeatherAutoSpinRecovery.resumedSpeed(
            speedBeforeInteraction: detailSpeed,
            fallbackCurrentSpeed: 0
        )
        try require(resumedDetail == detailSpeed, "detail scene should resume to the pre-interaction auto spin speed")
    }
}

private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw NSError(
            domain: "WeatherSpinSmokeTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}
