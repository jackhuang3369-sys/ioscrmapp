import SwiftUI
import SceneKit
import CoreGraphics
import Foundation

// MARK: - WeatherSpinCore types
enum WeatherSpinSettleMode: Equatable {
    case reverseReturnToFront
    case forwardCompleteToFront
    case forwardSingleTurn
    case forwardMomentumTurns
}

struct WeatherSpinTuning {
    let fullScreenTurnDegrees: CGFloat
    /// 第二屏（Sun Detail）专用：滑动屏幕高度对应的旋转角度
    /// 设为 180 度表示滑到屏幕底部时旋转半圈，比第一屏更慢、更可控
    let sunDetailFullScreenTurnDegrees: CGFloat
    let slowSwipeMaxDuration: TimeInterval
    let fastSwipeMinVelocity: CGFloat
    let fastSwipeMinDistanceRatio: CGFloat
    let quarterScreenFlickThreshold: CGFloat
    let halfScreenCommitThreshold: CGFloat
    let projectedDistanceMultiplier: CGFloat
    let maxMomentumTurns: Int
    let finalTurnSlowdownStartRatio: CGFloat
    let velocityPerTurn: CGFloat
    let shortSwipeSpinMinVelocity: CGFloat
    let targetAngularSpeedRadPerSec: Float
    let minimumSettleDuration: Float
    let maximumSettleDuration: Float

    static let `default` = WeatherSpinTuning(
        fullScreenTurnDegrees: 360,
        sunDetailFullScreenTurnDegrees: 180,  // 第二屏灵敏度减半，滑动更慢、更可控
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

    /// 第二屏专用：使用更低的灵敏度（sunDetailFullScreenTurnDegrees）
    /// 滑动屏幕高度 = 180 度（半圈），比第一屏更慢、更可控
    func sunDetailLiveYawDegrees(for translationRatio: CGFloat) -> CGFloat {
        translationRatio * tuning.sunDetailFullScreenTurnDegrees
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

// MARK: - WeatherSceneView
//
// Full-screen SceneKit view with pan-gesture rotation + inertial auto-spin.
// The transparent background lets the SwiftUI sky gradient show through.
// Rotation is applied to WeatherSceneManager.conditionGroup so lighting
// remains stationary while the weather model spins.

struct WeatherSceneView: UIViewRepresentable {

    let scene:   SCNScene
    /// Access to the rotatable model node. Pass nil for non-interactive scene views (e.g. Page B panels).
    let manager: WeatherSceneManager?
    let onSunTap: (() -> Void)?
    let onBackgroundTap: (() -> Void)?
    let allowsInteraction: Bool
    let interactionResetVersion: Int

    /// Creates a SceneKit weather container with optional gesture interaction.
    ///
    /// - Parameters:
    ///   - scene: The SceneKit scene rendered by the underlying `SCNView`.
    ///   - manager: Provides the rotatable weather node and resting orientation values.
    ///   - onSunTap: Called when the interactive weather model is tapped.
    ///   - allowsInteraction: Enables drag and tap gestures when `true`.
    init(
        scene: SCNScene,
        manager: WeatherSceneManager?,
        onSunTap: (() -> Void)? = nil,
        onBackgroundTap: (() -> Void)? = nil,
        allowsInteraction: Bool = true,
        interactionResetVersion: Int = 0
    ) {
        self.scene = scene
        self.manager = manager
        self.onSunTap = onSunTap
        self.onBackgroundTap = onBackgroundTap
        self.allowsInteraction = allowsInteraction
        self.interactionResetVersion = interactionResetVersion
    }

    // MARK: UIViewRepresentable

    func makeCoordinator() -> Coordinator {
        Coordinator(
            manager: manager,
            onSunTap: onSunTap,
            onBackgroundTap: onBackgroundTap,
            allowsInteraction: allowsInteraction
        )
    }

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene                    = scene
        scnView.backgroundColor          = .clear
        scnView.isOpaque                 = false
        scnView.allowsCameraControl      = false
        scnView.antialiasingMode         = .multisampling4X
        scnView.rendersContinuously      = true
        scnView.autoenablesDefaultLighting = false

        if allowsInteraction {
            let pan = UIPanGestureRecognizer(
                target: context.coordinator,
                action: #selector(Coordinator.handlePan(_:))
            )
            pan.maximumNumberOfTouches = 1
            scnView.addGestureRecognizer(pan)

            let tap = UITapGestureRecognizer(
                target: context.coordinator,
                action: #selector(Coordinator.handleTap(_:))
            )
            tap.require(toFail: pan)
            scnView.addGestureRecognizer(tap)
        }

        context.coordinator.startDisplayLink()
        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        if uiView.scene !== scene { uiView.scene = scene }
        context.coordinator.updateInteractionCallbacks(
            onSunTap: onSunTap,
            onBackgroundTap: onBackgroundTap
        )
        context.coordinator.applyInteractionResetIfNeeded(
            interactionResetVersion,
            rotation: manager?.displayGroupRotation ?? SCNVector3(0, 0, 0),
            restPitch: manager?.restTiltX ?? 0
        )
    }

    // MARK: – Coordinator (gesture + CADisplayLink spin)

    final class Coordinator: NSObject {

        private enum PanInteractionMode {
            case freeform
            case horizontalYawOnly
        }

        private enum EasingCurve {
            case easeOutQuad
            case easeOutCubic
            case easeOutQuart
            case easeOutQuint
            case easeOutDecay   // physical exponential deceleration (k=3)
        }

        private struct OrientationAnimation {
            let yawCurve: EasingCurve
            let tiltCurve: EasingCurve
            let startYaw: Float
            let endYaw: Float
            let startPitch: Float
            let endPitch: Float
            let startRoll: Float
            let endRoll: Float
            let duration: CFTimeInterval
            var elapsed: CFTimeInterval = 0
        }

        private struct PanSession {
            let startPoint: CGPoint
            let startYaw: Float
            let startTimestamp: CFTimeInterval
        }

        private let manager: WeatherSceneManager?
        private let allowsInteraction: Bool
        private var onSunTap: (() -> Void)?
        private var onBackgroundTap: (() -> Void)?
        private var currentYaw:     Float = 0
        private var currentPitch:   Float = 0
        private var currentRoll:    Float = 0
        private var targetYaw:      Float = 0
        private var targetPitch:    Float = 0
        private var targetRoll:     Float = 0
        private var yawVelocity:   Float = 0
        private var pitchVelocity: Float = 0
        private var rollVelocity:  Float = 0
        private var isPanning:     Bool  = false
        private var displayLink: CADisplayLink?
        private var lastPanPoint: CGPoint?
        private var panSession: PanSession?
        private var orientationAnimation: OrientationAnimation?
        private var pendingOrientationAnimation: OrientationAnimation?
        private var hasUserInteracted: Bool = false
        private var lastInteractionResetVersion: Int = 0
        private let spinController = WeatherSpinController(tuning: .default)
        private var panReferenceWidth: Float = 390

        // Tuning constants
        private let minimumPanReferenceWidth: Float = 280
        // Pitch 灵敏度：滑动屏幕高度对应 180 度（π radians）pitch 倾斜
        // 计算公式：pitchSensitivity = π / 屏幕高度 ≈ 3.14 / 800 ≈ 0.0039
        // 原值 0.0125 导致滑动屏幕高度 ≈ 573 度，太快
        private let pitchSensitivity: Float = 0.0039
        private let rollSensitivity:  Float = 0.0038
        private let horizontalPanActivationDistance: CGFloat = 10
        private let horizontalPanLockAngle: CGFloat = .pi / 10
        private let horizontalPitchSnapStrength: Float = 0.42
        private let horizontalRollSnapStrength: Float = 0.48
        private let yawVelocityDamping: Float = 0.94
        private let tiltVelocityDamping: Float = 0.91
        private let followStrength:   Float = 0.72
        private let idleFollow:       Float = 0.36
        private let pitchReturnStrength: Float = 0.24
        private let rollReturnStrength: Float = 0.22

        init(
            manager: WeatherSceneManager?,
            onSunTap: (() -> Void)?,
            onBackgroundTap: (() -> Void)?,
            allowsInteraction: Bool
        ) {
            self.manager = manager
            self.allowsInteraction = allowsInteraction
            self.onSunTap = onSunTap
            self.onBackgroundTap = onBackgroundTap
            let restPitch = manager?.restTiltX ?? 0
            currentPitch = restPitch
            targetPitch = restPitch
        }

        func updateInteractionCallbacks(onSunTap: (() -> Void)?, onBackgroundTap: (() -> Void)?) {
            self.onSunTap = onSunTap
            self.onBackgroundTap = onBackgroundTap
        }

        func applyInteractionResetIfNeeded(_ version: Int, rotation: SCNVector3, restPitch: Float) {
            guard version != lastInteractionResetVersion else { return }

            lastInteractionResetVersion = version
            orientationAnimation = nil
            pendingOrientationAnimation = nil
            isPanning = false
            lastPanPoint = nil
            panSession = nil
            hasUserInteracted = false
            yawVelocity = 0
            pitchVelocity = 0
            rollVelocity = 0
            currentYaw = rotation.y
            targetYaw = rotation.y
            currentPitch = abs(rotation.x) < 0.0001 ? restPitch : rotation.x
            targetPitch = currentPitch
            currentRoll = rotation.z
            targetRoll = rotation.z

            if let node = manager?.conditionGroup {
                applyOrientation(to: node)
                manager?.syncDisplayGroupRotation(to: node.eulerAngles)
            }
        }

        deinit { displayLink?.invalidate() }

        // MARK: Display link

        func startDisplayLink() {
            guard manager != nil else { return }  // no manager = no gesture/spin needed
            displayLink?.invalidate()
            displayLink = CADisplayLink(target: self, selector: #selector(step))
            displayLink?.add(to: .main, forMode: .common)
        }

        /// Advances inertial motion and eases the model back toward its resting pose.
        @objc private func step(_ link: CADisplayLink) {
            guard let node = manager?.conditionGroup else { return }
            let restPitch = manager?.restTiltX ?? 0
            let autoSpinSpeed = manager?.autoSpinSpeed ?? 0
            let frameDuration = max(link.targetTimestamp - link.timestamp, 1.0 / 60.0)

            if !isPanning {
                if advanceOrientationAnimation(by: frameDuration) {
                    applyOrientation(to: node)
                    manager?.syncDisplayGroupRotation(to: node.eulerAngles)
                    return
                }

                targetYaw += autoSpinSpeed * Float(frameDuration) + yawVelocity
                targetPitch += pitchVelocity
                targetRoll += rollVelocity

                yawVelocity *= yawVelocityDamping
                pitchVelocity *= tiltVelocityDamping
                rollVelocity *= tiltVelocityDamping

                if !hasUserInteracted {
                    let yawReturn = abs(yawVelocity) < 0.004 ? Float(0.08) : Float(0.02)
                    targetYaw += (0 - targetYaw) * yawReturn
                }

                let pitchReturn = abs(pitchVelocity) < 0.006 ? pitchReturnStrength : 0.08
                let rollReturn = abs(rollVelocity) < 0.005 ? rollReturnStrength : 0.06

                targetPitch += (restPitch - targetPitch) * pitchReturn
                targetRoll += (0 - targetRoll) * rollReturn
            }

            let follow = isPanning ? followStrength : idleFollow
            currentYaw += (targetYaw - currentYaw) * follow
            currentPitch += (targetPitch - currentPitch) * follow
            currentRoll += (targetRoll - currentRoll) * follow

            applyOrientation(to: node)

            manager?.syncDisplayGroupRotation(to: node.eulerAngles)
        }

        private func applyOrientation(to node: SCNNode) {
            let yaw = simd_quatf(angle: currentYaw, axis: SIMD3<Float>(0, 1, 0))
            let pitch = simd_quatf(angle: currentPitch, axis: SIMD3<Float>(1, 0, 0))
            let roll = simd_quatf(angle: currentRoll, axis: SIMD3<Float>(0, 0, 1))
            node.simdOrientation = simd_normalize(yaw * pitch * roll)
        }

        private func yawSensitivity(for view: UIView?) -> Float {
            let referenceWidth = max(Float(view?.bounds.width ?? 0), minimumPanReferenceWidth)
            return (.pi * 2) / referenceWidth
        }

        /// Treats nearly horizontal drags as yaw-only interactions so the model does not tilt diagonally.
        ///
        /// - Parameter gesture: The active pan gesture used to infer drag direction.
        /// - Returns: `.horizontalYawOnly` for mostly horizontal drags, otherwise `.freeform`.
        private func panInteractionMode(for gesture: UIPanGestureRecognizer) -> PanInteractionMode {
            let translation = gesture.translation(in: gesture.view)
            let horizontalDistance = abs(translation.x)
            let verticalDistance = abs(translation.y)
            let dominantDistance = max(horizontalDistance, verticalDistance)

            guard dominantDistance >= horizontalPanActivationDistance else {
                return .freeform
            }

            let dragAngle = atan2(verticalDistance, horizontalDistance)
            return dragAngle <= horizontalPanLockAngle ? .horizontalYawOnly : .freeform
        }

        /// Pulls pitch and roll back toward the resting pose while the user is dragging horizontally.
        ///
        /// - Parameter restPitch: The default X-axis tilt configured by the scene manager.
        private func settleHorizontalTilt(restPitch: Float) {
            pitchVelocity = 0
            rollVelocity = 0
            targetPitch += (restPitch - targetPitch) * horizontalPitchSnapStrength
            targetRoll += (0 - targetRoll) * horizontalRollSnapStrength
            currentPitch += (restPitch - currentPitch) * horizontalPitchSnapStrength
            currentRoll += (0 - currentRoll) * horizontalRollSnapStrength
        }

        private func advanceOrientationAnimation(by deltaTime: CFTimeInterval) -> Bool {
            guard var animation = orientationAnimation else { return false }

            animation.elapsed = min(animation.elapsed + deltaTime, animation.duration)
            let progress = max(0, min(Float(animation.elapsed / animation.duration), 1))
            let easedYaw = easedProgress(for: animation.yawCurve, progress: progress)
            let easedTilt = easedProgress(
                for: animation.tiltCurve,
                progress: min(progress * 1.12, 1)
            )

            currentYaw = interpolate(animation.startYaw, animation.endYaw, progress: easedYaw)
            targetYaw = currentYaw
            currentPitch = interpolate(animation.startPitch, animation.endPitch, progress: easedTilt)
            targetPitch = currentPitch
            currentRoll = interpolate(animation.startRoll, animation.endRoll, progress: easedTilt)
            targetRoll = currentRoll
            yawVelocity = 0
            pitchVelocity = 0
            rollVelocity = 0

            if progress >= 0.999 {
                currentYaw = animation.endYaw
                targetYaw = animation.endYaw
                currentPitch = animation.endPitch
                targetPitch = animation.endPitch
                currentRoll = animation.endRoll
                targetRoll = animation.endRoll
                if let pending = pendingOrientationAnimation {
                    pendingOrientationAnimation = nil
                    orientationAnimation = pending
                } else {
                    orientationAnimation = nil
                    let collapsedYaw = spinController.collapsedFrontFacingYaw(currentYaw)
                    currentYaw = collapsedYaw
                    targetYaw = collapsedYaw
                    hasUserInteracted = false
                    manager?.resumeAutomaticSpinAfterInteraction()
                }
            } else {
                orientationAnimation = animation
            }

            return true
        }

        private func startSettlingAnimation(
            decision: WeatherSpinSettleDecision,
            direction: Float,
            restPitch: Float
        ) {
            let settleDirection: Float = decision.mode == .reverseReturnToFront
                ? (direction >= 0 ? -1 : 1)
                : (direction >= 0 ? 1 : -1)
            let extraTurns = max(decision.targetTurnCount - 1, 0)
            let destinationYaw = frontFacingYaw(
                from: currentYaw,
                direction: settleDirection,
                extraTurns: extraTurns
            )
            let settleDistance = abs(destinationYaw - currentYaw)
            let baseDuration = spinController.settleDuration(distanceRadians: settleDistance)

            pendingOrientationAnimation = nil
            orientationAnimation = OrientationAnimation(
                yawCurve: .easeOutDecay,
                tiltCurve: .easeOutCubic,
                startYaw: currentYaw,
                endYaw: destinationYaw,
                startPitch: currentPitch,
                endPitch: restPitch,
                startRoll: currentRoll,
                endRoll: 0,
                duration: CFTimeInterval(baseDuration)
            )

            targetYaw = currentYaw
            targetPitch = currentPitch
            targetRoll = currentRoll
            yawVelocity = 0
            pitchVelocity = 0
            rollVelocity = 0
        }

        private func stopMomentumAnimations() {
            orientationAnimation = nil
            pendingOrientationAnimation = nil
            targetYaw = currentYaw
            targetPitch = currentPitch
            targetRoll = currentRoll
            yawVelocity = 0
            pitchVelocity = 0
            rollVelocity = 0
        }

        /// 第二屏专用：按共享 180° 阈值规则，<180 回起始朝向，>=180 沿释放方向补到 360。
        private func snapBackToZero(restPitch: Float, direction: Float, panStartYaw: Float) {
            let destinationYaw = spinController.sunDetailSettleTargetYaw(
                startYaw: panStartYaw,
                currentYaw: currentYaw,
                direction: direction
            )
            let distance = abs(destinationYaw - currentYaw)
            let duration = spinController.settleDuration(distanceRadians: distance)
            orientationAnimation = OrientationAnimation(
                yawCurve: .easeOutDecay,
                tiltCurve: .easeOutCubic,
                startYaw: currentYaw,
                endYaw: destinationYaw,
                startPitch: currentPitch,
                endPitch: restPitch,
                startRoll: currentRoll,
                endRoll: 0,
                duration: CFTimeInterval(duration)
            )
            pendingOrientationAnimation = nil
            targetYaw = currentYaw
            targetPitch = currentPitch
            targetRoll = currentRoll
            yawVelocity = 0
            pitchVelocity = 0
            rollVelocity = 0
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

        private func interpolate(_ start: Float, _ end: Float, progress: Float) -> Float {
            start + (end - start) * progress
        }

        private func easedProgress(for curve: EasingCurve, progress: Float) -> Float {
            switch curve {
            case .easeOutQuad:
                easeOutQuad(progress)
            case .easeOutCubic:
                easeOutCubic(progress)
            case .easeOutQuart:
                easeOutQuart(progress)
            case .easeOutQuint:
                easeOutQuint(progress)
            case .easeOutDecay:
                easeOutDecay(progress)
            }
        }

        private func easeOutCubic(_ progress: Float) -> Float {
            let reversed = 1 - progress
            return 1 - reversed * reversed * reversed
        }

        private func easeOutQuart(_ progress: Float) -> Float {
            let reversed = 1 - progress
            return 1 - reversed * reversed * reversed * reversed
        }

        private func easeOutQuint(_ progress: Float) -> Float {
            let reversed = 1 - progress
            return 1 - reversed * reversed * reversed * reversed * reversed
        }

        private func easeOutQuad(_ progress: Float) -> Float {
            let reversed = 1 - progress
            return 1 - reversed * reversed
        }

        /// Exponential deceleration matching physical friction: v(t) = v₀·e^(−kt).
        /// k=3 evenly distributes motion over time — 59% at t=0.3, 82% at t=0.5, 94% at t=0.7
        /// vs easeOutQuint's 83% / 97% / 99.7% (far less front-loaded).
        private func easeOutDecay(_ progress: Float) -> Float {
            let k: Float = 3.0
            return (1.0 - exp(-k * progress)) / (1.0 - exp(-k))
        }

        private func debugLogSettle(
            sample: WeatherSpinGestureSample,
            decision: WeatherSpinSettleDecision,
            currentYawDegrees: CGFloat
        ) {
#if DEBUG
            let snapshot = WeatherSpinDebugSnapshot(
                translationRatio: sample.translationRatio,
                predictedTranslationRatio: sample.predictedTranslationRatio,
                velocityPointsPerSecond: sample.velocityPointsPerSecond,
                duration: sample.duration,
                targetTurnCount: decision.targetTurnCount,
                mode: decision.mode
            )
            let distance = String(format: "%.3f", snapshot.translationRatio)
            let predicted = String(format: "%.3f", snapshot.predictedTranslationRatio)
            let duration = String(format: "%.3f", snapshot.duration)
            let yaw = String(format: "%.1f", currentYawDegrees)
            print(
                "[WeatherSpin] distance=\(distance) predicted=\(predicted) " +
                "velocity=\(Int(snapshot.velocityPointsPerSecond)) duration=\(duration) " +
                "mode=\(snapshot.mode) turns=\(snapshot.targetTurnCount) yaw=\(yaw)"
            )
#endif
        }

        // MARK: Pan gesture

        /// Maps pan gestures to model rotation, locking pure horizontal drags to yaw-only motion.
        ///
        /// - Parameter gesture: The pan gesture attached to the SceneKit view.
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let node = manager?.conditionGroup else { return }
            let restPitch = manager?.restTiltX ?? 0
            switch gesture.state {
            case .began:
                isPanning = true
                hasUserInteracted = true
                manager?.pauseAutomaticSpinForInteraction()
                lastPanPoint = gesture.location(in: gesture.view)
                panSession = PanSession(
                    startPoint: gesture.location(in: gesture.view),
                    startYaw: currentYaw,
                    startTimestamp: CACurrentMediaTime()
                )
                stopMomentumAnimations()
            case .changed:
                let point = gesture.location(in: gesture.view)
                let previousPoint = lastPanPoint ?? point
                let deltaX = point.x - previousPoint.x
                let deltaY = point.y - previousPoint.y
                lastPanPoint = point

                let liveTranslationX = point.x - (panSession?.startPoint.x ?? point.x)
                let referenceWidth = max(Float(gesture.view?.bounds.width ?? 0), minimumPanReferenceWidth)
                panReferenceWidth = referenceWidth
                let translationRatio = CGFloat(liveTranslationX) / CGFloat(referenceWidth)
                // 第二屏使用更低的灵敏度（滑动屏幕宽度 = 180 度），第一屏保持原灵敏度（360 度）
                let liveYawDegrees: CGFloat
                if manager?.isSunDetailMode == true {
                    liveYawDegrees = spinController.sunDetailLiveYawDegrees(for: translationRatio)
                } else {
                    liveYawDegrees = spinController.liveYawDegrees(for: translationRatio)
                }
                let liveYawRadians = Float(liveYawDegrees) * .pi / 180
                let yawTarget = (panSession?.startYaw ?? currentYaw) + liveYawRadians
                let interactionMode = panInteractionMode(for: gesture)

                // Yaw 只在水平拖动模式下生效，斜向拖动时不应该有 yaw 变化
                // 这样斜向拖动只产生 pitch + roll 组合，实现"向左下/右下低头"效果
                if interactionMode == .horizontalYawOnly {
                    targetYaw = yawTarget
                    currentYaw = yawTarget
                }

                let pitchDelta = interactionMode == .horizontalYawOnly ? 0 : Float(deltaY) * pitchSensitivity
                let rollDelta = interactionMode == .horizontalYawOnly ? 0 : Float(deltaX) * -rollSensitivity

                targetPitch += pitchDelta
                targetRoll += rollDelta

                // Direct tracking: finger ↔ model 1:1, zero perceptible lag
                if interactionMode == .horizontalYawOnly {
                    settleHorizontalTilt(restPitch: restPitch)
                } else {
                    currentPitch += pitchDelta * 0.45
                    currentRoll += rollDelta * 0.45
                }
                applyOrientation(to: node)

                manager?.syncDisplayGroupRotation(to: node.eulerAngles)
            case .ended, .cancelled:
                isPanning = false
                lastPanPoint = nil
                defer { panSession = nil }
                let v = gesture.velocity(in: gesture.view)
                let interactionMode = panInteractionMode(for: gesture)

                // Keep the release frame continuous with the drag frame to avoid a visible hitch
                // when settle animation takes over near threshold distances.
                currentYaw = targetYaw
                currentPitch = targetPitch
                currentRoll = targetRoll
                applyOrientation(to: node)
                manager?.syncDisplayGroupRotation(to: node.eulerAngles)

                // 第二屏：保持当前旋转方向，滑行到最近的 0/360 朝向（不反向吐圈）
                if manager?.isSunDetailMode == true {
                    let panStartYaw = panSession?.startYaw ?? currentYaw
                    let yawDelta = targetYaw - (panSession?.startYaw ?? targetYaw)
                    let settleDirection: Float = yawDelta == 0
                        ? (v.x >= 0 ? 1 : -1)
                        : (yawDelta > 0 ? 1 : -1)
                    snapBackToZero(restPitch: restPitch, direction: settleDirection, panStartYaw: panStartYaw)
                    break
                }
                if interactionMode == .horizontalYawOnly {
                    let referenceWidth = max(Float(gesture.view?.bounds.width ?? 0), minimumPanReferenceWidth)
                    let translation = gesture.translation(in: gesture.view).x
                    let projectionHorizonSeconds: CGFloat = 0.12
                    let predicted = translation + v.x * projectionHorizonSeconds
                    let translationRatio = CGFloat(translation) / CGFloat(referenceWidth)
                    let predictedRatio = CGFloat(predicted) / CGFloat(referenceWidth)
                    let duration = max(CACurrentMediaTime() - (panSession?.startTimestamp ?? CACurrentMediaTime()), 0.01)
                    let sample = WeatherSpinGestureSample(
                        translationRatio: translationRatio,
                        predictedTranslationRatio: predictedRatio,
                        velocityPointsPerSecond: v.x,
                        duration: duration
                    )
                    let yawSincePanStart = targetYaw - (panSession?.startYaw ?? 0)
                    let currentYawDegrees = CGFloat(yawSincePanStart) * 180 / .pi
                    let decision = spinController.settleDecision(
                        currentYawDegrees: currentYawDegrees,
                        sample: sample
                    )
                    debugLogSettle(sample: sample, decision: decision, currentYawDegrees: currentYawDegrees)
                    let direction: Float = (translationRatio == 0)
                        ? (v.x >= 0 ? 1 : -1)
                        : (translationRatio > 0 ? 1 : -1)
                    startSettlingAnimation(
                        decision: decision,
                        direction: direction,
                        restPitch: restPitch
                    )
                    switch spinController.releaseAudioVariant(for: decision) {
                    case .none:
                        break
                    case .slow:
                        WeatherAudioPlayer.shared.playSpinLoop(fast: false)
                    case .fast:
                        WeatherAudioPlayer.shared.playSpinLoop(fast: true)
                    }
                } else {
                    let sample = WeatherSpinGestureSample(
                        translationRatio: 0,
                        predictedTranslationRatio: 0,
                        velocityPointsPerSecond: v.x,
                        duration: max(CACurrentMediaTime() - (panSession?.startTimestamp ?? CACurrentMediaTime()), 0.01)
                    )
                    let decision = WeatherSpinSettleDecision(
                        mode: .reverseReturnToFront,
                        targetTurnCount: 0,
                        targetYawDegrees: 0,
                        usesFinalTurnSlowdown: false
                    )
                    startSettlingAnimation(
                        decision: decision,
                        direction: v.x >= 0 ? 1 : -1,
                        restPitch: restPitch
                    )
                    debugLogSettle(sample: sample, decision: decision, currentYawDegrees: 0)
                    let fast = hypot(v.x, v.y) > 650
                    WeatherAudioPlayer.shared.playSpinLoop(fast: fast)
                }
            default:
                isPanning = false
                lastPanPoint = nil
            }
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended,
                  let scnView = gesture.view as? SCNView else { return }

            let location = gesture.location(in: scnView)
            let hits = scnView.hitTest(location, options: [SCNHitTestOption.searchMode: SCNHitTestSearchMode.all.rawValue])
            // Ignore temperature digits so tapping numbers does not trigger sun interaction.
            if hits.contains(where: { isInteractiveNode($0.node) && !isTemperatureNode($0.node) }) {
                onSunTap?()
            } else {
                onBackgroundTap?()
            }
        }

        private func isInteractiveNode(_ node: SCNNode?) -> Bool {
            guard let group = manager?.conditionGroup else { return false }
            var current = node
            while let value = current {
                if value === group {
                    return true
                }
                current = value.parent
            }
            return false
        }

        private func isTemperatureNode(_ node: SCNNode?) -> Bool {
            var current = node
            while let value = current {
                if value.name == SceneNode.temperature || (value.name?.hasPrefix("digit_") ?? false) {
                    return true
                }
                current = value.parent
            }
            return false
        }
    }
}
