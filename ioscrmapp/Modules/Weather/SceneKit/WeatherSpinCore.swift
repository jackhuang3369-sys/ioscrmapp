import CoreGraphics
import Foundation

enum WeatherSpinSettleMode: Equatable {
    case reverseReturnToFront
    case forwardCompleteToFront
    case forwardSingleTurn
    case forwardMomentumTurns
}

enum WeatherSpinSoundTier: Hashable {
    case slow
    case medium
    case fast
}

struct WeatherSpinSoundTuning {
    /// Minimum planned turns required before the medium sound tier can play.
    let mediumMinimumTurnCount: Int
    /// Planned turns above this value use the fastest sound tier.
    let mediumMaximumTurnCount: Int

    static let `default` = WeatherSpinSoundTuning(
        mediumMinimumTurnCount: 3,   //<mediumMinimumTurnCount,低速 ; mediumMinimumTurnCount<=x<=mediumMaximumTurnCount 中速；>mediumMaximumTurnCount,高速
        mediumMaximumTurnCount: 6
    )
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
    let soundTuning: WeatherSpinSoundTuning

    static let `default` = WeatherSpinTuning(
        fullScreenTurnDegrees: 360,
        slowSwipeMaxDuration: 0.48,
        fastSwipeMinVelocity: 900,
        fastSwipeMinDistanceRatio: 0.04,
        quarterScreenFlickThreshold: 0.20,
        halfScreenCommitThreshold: 0.5,
        projectedDistanceMultiplier: 1.22,
        maxMomentumTurns: 12,
        finalTurnSlowdownStartRatio: 0.82,
        velocityPerTurn: 800,
        shortSwipeSpinMinVelocity: 1650,
        soundTuning: .default
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

struct WeatherAutoSpinRecovery {
    static func resumedSpeed(speedBeforeInteraction: Float?, fallbackCurrentSpeed: Float) -> Float {
        speedBeforeInteraction ?? fallbackCurrentSpeed
    }
}

struct WeatherSpinController {
    let tuning: WeatherSpinTuning

    func liveYawDegrees(for translationRatio: CGFloat) -> CGFloat {
        translationRatio * tuning.fullScreenTurnDegrees
    }

    func spinSoundTier(
        for sample: WeatherSpinGestureSample,
        decision: WeatherSpinSettleDecision
    ) -> WeatherSpinSoundTier {
        _ = sample
        let soundTuning = tuning.soundTuning
        let plannedTurns = decision.targetTurnCount

        if plannedTurns > soundTuning.mediumMaximumTurnCount {
            return .fast
        }

        if plannedTurns >= soundTuning.mediumMinimumTurnCount {
            return .medium
        }

        return .slow
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
}
