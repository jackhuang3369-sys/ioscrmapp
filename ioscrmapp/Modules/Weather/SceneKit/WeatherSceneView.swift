import SwiftUI
import SceneKit

// MARK: - WeatherSceneView
//
// Full-screen SceneKit view with pan-gesture rotation and velocity-driven momentum settle.
// The transparent background lets the SwiftUI sky gradient show through.
// Rotation is applied to WeatherSceneManager.conditionGroup so lighting
// remains stationary while the weather model spins.

struct WeatherSceneView: UIViewRepresentable {

    let scene:   SCNScene
    /// Access to the rotatable model node. Pass nil for non-interactive scene views (e.g. Page B panels).
    let manager: WeatherSceneManager?
    let onSunTap: ((CGPoint) -> Void)?
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
        onSunTap: ((CGPoint) -> Void)? = nil,
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
            case easeOutDecay
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
        private var onSunTap: ((CGPoint) -> Void)?
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
        private var hasUserInteracted: Bool = false
        private var lastInteractionResetVersion: Int = 0
        private let spinController = WeatherSpinController(tuning: .default)
        private var panReferenceWidth: Float = 390

        // Tuning constants
        private let minimumPanReferenceWidth: Float = 280
        private let pitchSensitivity: Float = 0.0125
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
        private let minimumSettleDuration: Float = 0.36
        private let maximumSettleDuration: Float = 1.6

        init(
            manager: WeatherSceneManager?,
            onSunTap: ((CGPoint) -> Void)?,
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

        func updateInteractionCallbacks(onSunTap: ((CGPoint) -> Void)?, onBackgroundTap: (() -> Void)?) {
            self.onSunTap = onSunTap
            self.onBackgroundTap = onBackgroundTap
        }

        func applyInteractionResetIfNeeded(_ version: Int, rotation: SCNVector3, restPitch: Float) {
            guard version != lastInteractionResetVersion else { return }

            lastInteractionResetVersion = version
            orientationAnimation = nil
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

            // 场景动画进行中，由 SCNAction 驱动，Coordinator 不干预
            if manager?.isPlayingSceneAnimation == true {
                return
            }

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
                orientationAnimation = nil
                manager?.resumeAutomaticSpinAfterInteraction()
            } else {
                orientationAnimation = animation
            }

            return true
        }

        private func startSettlingAnimation(
            decision: WeatherSpinSettleDecision,
            direction: Float,
            velocityX: CGFloat,
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
            let velocityRadiansPerSecond = Float(abs(velocityX))
                / max(panReferenceWidth, minimumPanReferenceWidth)
                * Float.pi * 2
            let baseDuration: Float
            if decision.mode == .reverseReturnToFront {
                let settleTurns = settleDistance / (.pi * 2)
                baseDuration = max(minimumSettleDuration, 0.40 + settleTurns * 0.22)
            } else {
                let matched = velocityRadiansPerSecond > 0.5
                    ? 3.16 * settleDistance / velocityRadiansPerSecond
                    : maximumSettleDuration
                baseDuration = min(maximumSettleDuration, max(minimumSettleDuration, matched))
            }
            orientationAnimation = OrientationAnimation(
                yawCurve: decision.mode == .reverseReturnToFront ? .easeOutQuint : .easeOutDecay,
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

        private func spinSoundTier(for velocity: CGPoint) -> WeatherSpinSoundTier {
            let speed = hypot(velocity.x, velocity.y)
            if speed >= spinController.tuning.fastSwipeMinVelocity * 2 {
                return .fast
            }
            if speed >= spinController.tuning.fastSwipeMinVelocity {
                return .medium
            }
            return .slow
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

        private func easeOutDecay(_ progress: Float) -> Float {
            let k: Float = 3.0
            return (1 - exp(-k * progress)) / (1 - exp(-k))
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
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.16
                node.scale = SCNVector3(node.scale.x * 1.02, node.scale.y * 1.02, node.scale.z * 1.02)
                SCNTransaction.commit()
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
                let liveYawDegrees = spinController.liveYawDegrees(for: translationRatio)
                let liveYawRadians = Float(liveYawDegrees) * .pi / 180
                let yawTarget = (panSession?.startYaw ?? currentYaw) + liveYawRadians
                let interactionMode = panInteractionMode(for: gesture)
                let pitchDelta = interactionMode == .horizontalYawOnly ? 0 : Float(deltaY) * pitchSensitivity
                let rollDelta = interactionMode == .horizontalYawOnly ? 0 : Float(deltaX) * -rollSensitivity

                targetYaw = yawTarget
                targetPitch += pitchDelta
                targetRoll += rollDelta

                currentYaw = yawTarget
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

                currentYaw = targetYaw
                currentPitch = targetPitch
                currentRoll = targetRoll
                applyOrientation(to: node)
                manager?.syncDisplayGroupRotation(to: node.eulerAngles)

                if interactionMode == .horizontalYawOnly {
                    let referenceWidth = max(Float(gesture.view?.bounds.width ?? 0), minimumPanReferenceWidth)
                    let translation = gesture.translation(in: gesture.view).x
                    let projectionHorizonSeconds: CGFloat = 0.12
                    let predicted = translation + v.x * projectionHorizonSeconds
                    let translationRatio = CGFloat(translation) / CGFloat(referenceWidth)
                    let predictedRatio = CGFloat(predicted) / CGFloat(referenceWidth)
                    let duration = max(
                        CACurrentMediaTime() - (panSession?.startTimestamp ?? CACurrentMediaTime()),
                        0.01
                    )
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
                    let direction: Float = translationRatio == 0
                        ? (v.x >= 0 ? 1 : -1)
                        : (translationRatio > 0 ? 1 : -1)
                    debugLogSettle(
                        sample: sample,
                        decision: decision,
                        currentYawDegrees: currentYawDegrees
                    )
                    startSettlingAnimation(
                        decision: decision,
                        direction: direction,
                        velocityX: v.x,
                        restPitch: restPitch,
                    )
                    WeatherAudioPlayer.shared.playSpinLoop(
                        tier: spinController.spinSoundTier(for: sample, decision: decision)
                    )
                } else {
                    let sample = WeatherSpinGestureSample(
                        translationRatio: 0,
                        predictedTranslationRatio: 0,
                        velocityPointsPerSecond: v.x,
                        duration: max(
                            CACurrentMediaTime() - (panSession?.startTimestamp ?? CACurrentMediaTime()),
                            0.01
                        )
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
                        velocityX: v.x,
                        restPitch: restPitch
                    )
                    debugLogSettle(sample: sample, decision: decision, currentYawDegrees: 0)
                    WeatherAudioPlayer.shared.playSpinLoop(
                        tier: spinSoundTier(for: v)
                    )
                }
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.22
                let currentScale = node.scale.x / 1.02
                node.scale = SCNVector3(currentScale, currentScale, currentScale)
                SCNTransaction.commit()
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
                let screenLocation = projectedSunCenter(in: scnView)
                    ?? gesture.location(in: scnView.window)
                onSunTap?(screenLocation)
            } else {
                onBackgroundTap?()
            }
        }

        private func projectedSunCenter(in scnView: SCNView) -> CGPoint? {
            guard let sunNode = manager?.sunNode else { return nil }

            let worldPosition = sunNode.presentation.worldPosition
            let projected = scnView.projectPoint(worldPosition)
            guard projected.z.isFinite else { return nil }

            let localPoint = CGPoint(
                x: CGFloat(projected.x),
                y: CGFloat(projected.y)
            )
            return scnView.convert(localPoint, to: scnView.window)
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
