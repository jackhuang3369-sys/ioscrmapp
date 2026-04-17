import CoreGraphics
import Foundation

enum WeatherSpinSettleMode: Equatable {
    case reverseReturnToFront
    case forwardCompleteToFront
    case forwardSingleTurn
    case forwardMomentumTurns
}

struct WeatherSpinTuning {
    let fullScreenTurnDegrees: CGFloat
    let slowSwipeMaxDuration: TimeInterval
    let fastSwipeMinVelocity: CGFloat
    let fastSwipeMinDistanceRatio: CGFloat
    let quarterScreenFlickThreshold: CGFloat
    let halfScreenCommitThreshold: CGFloat
    let projectedDistanceMultiplier: CGFloat
    let maxMomentumTurns: Int
    let finalTurnSlowdownStartRatio: CGFloat
    /// Velocity (px/s) required to earn one additional turn during a fast swipe.
    let velocityPerTurn: CGFloat
    /// Under quarter-screen distance, swipes faster than this still commit forward turns.
    let shortSwipeSpinMinVelocity: CGFloat
    /// Shared settle model target speed in rad/s.
    let targetAngularSpeedRadPerSec: Float
    /// Shared settle model minimum duration.
    let minimumSettleDuration: Float
    /// Shared settle model maximum duration.
    let maximumSettleDuration: Float

    static let `default` = WeatherSpinTuning(
        fullScreenTurnDegrees: 360,
        slowSwipeMaxDuration: 0.48,
        fastSwipeMinVelocity: 900,
        fastSwipeMinDistanceRatio: 0.04,
        quarterScreenFlickThreshold: 0.20,
        halfScreenCommitThreshold: 0.5,
        projectedDistanceMultiplier: 1.22,
        maxMomentumTurns: 8,
        finalTurnSlowdownStartRatio: 0.82,
        velocityPerTurn: 800,
        shortSwipeSpinMinVelocity: 1650,
        targetAngularSpeedRadPerSec: 4.8,
        minimumSettleDuration: 0.48,
        maximumSettleDuration: 1.45
    )
}

struct WeatherSpinGestureSample {
    let translationRatio: CGFloat
    let predictedTranslationRatio: CGFloat
    let velocityPointsPerSecond: CGFloat
    let duration: TimeInterval

    func isFast(using tuning: WeatherSpinTuning) -> Bool {
        duration <= tuning.slowSwipeMaxDuration
            && abs(velocityPointsPerSecond) >= tuning.fastSwipeMinVelocity
            && abs(translationRatio) >= tuning.fastSwipeMinDistanceRatio
    }
}

struct WeatherSpinSettleDecision: Equatable {
    let mode: WeatherSpinSettleMode
    let targetTurnCount: Int
    let targetYawDegrees: CGFloat
    let usesFinalTurnSlowdown: Bool
}

struct WeatherSpinDebugSnapshot {
    let translationRatio: CGFloat
    let predictedTranslationRatio: CGFloat
    let velocityPointsPerSecond: CGFloat
    let duration: TimeInterval
    let targetTurnCount: Int
    let mode: WeatherSpinSettleMode
}

enum WeatherSpinReleaseAudioVariant: Equatable {
    case none
    case slow
    case fast
}

struct WeatherAutoSpinRecovery {
    static func resumedSpeed(speedBeforeInteraction: Float?, fallbackCurrentSpeed: Float) -> Float {
        speedBeforeInteraction ?? fallbackCurrentSpeed
    }
}

struct WeatherSpinController {
    let tuning: WeatherSpinTuning

    func settleDuration(distanceRadians: Float) -> Float {
        let unclamped = distanceRadians / tuning.targetAngularSpeedRadPerSec
        return min(tuning.maximumSettleDuration, max(tuning.minimumSettleDuration, unclamped))
    }

    func releaseAudioVariant(for decision: WeatherSpinSettleDecision) -> WeatherSpinReleaseAudioVariant {
        if decision.targetTurnCount >= 2 {
            return .fast
        }
        if decision.targetTurnCount == 1 {
            return .slow
        }
        return .none
    }

    /// Returns a front-facing destination yaw that preserves release direction.
    /// This avoids reversing through all accumulated turns when settling to 0/360.
    func sunDetailSnapYaw(currentYaw: Float, direction: Float) -> Float {
        frontFacingYaw(from: currentYaw, direction: direction >= 0 ? 1 : -1, extraTurns: 0)
    }

    /// Second-screen settle target using the shared 180-degree rule.
    /// <180° returns to start yaw, >=180° continues in release direction to one full turn.
    func sunDetailSettleTargetYaw(startYaw: Float, currentYaw: Float, direction: Float) -> Float {
        let absoluteDelta = abs(currentYaw - startYaw)
        if absoluteDelta < Float.pi {
            return startYaw
        }
        let fullTurn = Float.pi * 2
        return startYaw + (direction >= 0 ? fullTurn : -fullTurn)
    }

    /// Collapses accumulated yaw to an equivalent front-facing angle near zero.
    /// This prevents post-settle stabilization from unwinding historical turns.
    func collapsedFrontFacingYaw(_ yaw: Float) -> Float {
        let fullRotation = Float.pi * 2
        let normalized = positiveRemainder(yaw, divisor: fullRotation)
        if abs(normalized - fullRotation) < 0.0001 || abs(normalized) < 0.0001 {
            return 0
        }
        return normalized > Float.pi ? normalized - fullRotation : normalized
    }

    func liveYawDegrees(for translationRatio: CGFloat) -> CGFloat {
        translationRatio * tuning.fullScreenTurnDegrees
    }

    func settleDecision(currentYawDegrees: CGFloat, sample: WeatherSpinGestureSample) -> WeatherSpinSettleDecision {
        let absoluteTranslation = abs(sample.translationRatio)
        let completedTurns = max(Int(floor(abs(currentYawDegrees) / tuning.fullScreenTurnDegrees)), 0)

        if sample.isFast(using: tuning) {
            if absoluteTranslation < tuning.quarterScreenFlickThreshold,
               abs(sample.velocityPointsPerSecond) < tuning.shortSwipeSpinMinVelocity {
                return WeatherSpinSettleDecision(
                    mode: .reverseReturnToFront,
                    targetTurnCount: 0,
                    targetYawDegrees: 0,
                    usesFinalTurnSlowdown: false
                )
            }

            // Velocity drives turn count directly: each ~velocityPerTurn px/s earns one full turn.
            // This matches the original app's behaviour: a fast short swipe can spin multiple turns.
            let velocityTurns = Int(abs(sample.velocityPointsPerSecond) / tuning.velocityPerTurn)
            let cappedTurns = max(1, min(velocityTurns, tuning.maxMomentumTurns))
            return WeatherSpinSettleDecision(
                mode: cappedTurns == 1 ? .forwardSingleTurn : .forwardMomentumTurns,
                targetTurnCount: cappedTurns,
                targetYawDegrees: CGFloat(cappedTurns) * tuning.fullScreenTurnDegrees,
                usesFinalTurnSlowdown: true
            )
        }

        if absoluteTranslation < tuning.halfScreenCommitThreshold {
            return WeatherSpinSettleDecision(
                mode: .reverseReturnToFront,
                targetTurnCount: 0,
                targetYawDegrees: 0,
                usesFinalTurnSlowdown: false
            )
        }

        if absoluteTranslation < 1 {
            return WeatherSpinSettleDecision(
                mode: .forwardCompleteToFront,
                targetTurnCount: 1,
                targetYawDegrees: tuning.fullScreenTurnDegrees,
                usesFinalTurnSlowdown: true
            )
        }

        let forwardTurns = max(completedTurns, 1)
        return WeatherSpinSettleDecision(
            mode: .forwardCompleteToFront,
            targetTurnCount: forwardTurns,
            targetYawDegrees: CGFloat(forwardTurns) * tuning.fullScreenTurnDegrees,
            usesFinalTurnSlowdown: true
        )
    }

    func isFrontFacing(yawDegrees: CGFloat, toleranceDegrees: CGFloat) -> Bool {
        let normalized = abs(yawDegrees.truncatingRemainder(dividingBy: tuning.fullScreenTurnDegrees))
        return normalized <= toleranceDegrees
            || abs(normalized - tuning.fullScreenTurnDegrees) <= toleranceDegrees
    }

    private func frontFacingYaw(from yaw: Float, direction: Float, extraTurns: Int) -> Float {
        let fullRotation = Float.pi * 2
        let normalizedYaw = positiveRemainder(yaw, divisor: fullRotation)

        if direction >= 0 {
            let offsetToFront = normalizedYaw == 0 ? 0 : fullRotation - normalizedYaw
            return yaw + offsetToFront + Float(extraTurns) * fullRotation
        }

        let offsetToFront = normalizedYaw == 0 ? 0 : normalizedYaw
        return yaw - offsetToFront - Float(extraTurns) * fullRotation
    }

    private func positiveRemainder(_ value: Float, divisor: Float) -> Float {
        let remainder = value.truncatingRemainder(dividingBy: divisor)
        return remainder >= 0 ? remainder : remainder + divisor
    }
}
