import SwiftUI
import SceneKit

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
    let allowsInteraction: Bool

    /// Creates a SceneKit weather container with optional gesture interaction.
    ///
    /// - Parameters:
    ///   - scene: The SceneKit scene rendered by the underlying `SCNView`.
    ///   - manager: Provides the rotatable weather node and resting orientation values.
    ///   - onSunTap: Called when the interactive weather model is tapped.
    ///   - allowsInteraction: Enables drag and tap gestures when `true`.
    init(scene: SCNScene, manager: WeatherSceneManager?, onSunTap: (() -> Void)? = nil, allowsInteraction: Bool = true) {
        self.scene = scene
        self.manager = manager
        self.onSunTap = onSunTap
        self.allowsInteraction = allowsInteraction
    }

    // MARK: UIViewRepresentable

    func makeCoordinator() -> Coordinator {
        Coordinator(
            manager: manager,
            onSunTap: onSunTap,
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

            if onSunTap != nil {
                let tap = UITapGestureRecognizer(
                    target: context.coordinator,
                    action: #selector(Coordinator.handleTap(_:))
                )
                tap.require(toFail: pan)
                scnView.addGestureRecognizer(tap)
            }
        }

        context.coordinator.startDisplayLink()
        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        if uiView.scene !== scene { uiView.scene = scene }
        context.coordinator.updateSunTap(onSunTap)
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

        private let manager: WeatherSceneManager?
        private let allowsInteraction: Bool
        private var onSunTap: (() -> Void)?
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
        private var orientationAnimation: OrientationAnimation?
        private var hasUserInteracted: Bool = false

        // Tuning constants
        private let yawTurnsPerFullWidthPan: Float = 4.8
        private let minimumPanReferenceWidth: Float = 280
        private let pitchSensitivity: Float = 0.0125
        private let rollSensitivity:  Float = 0.0038
        private let horizontalPanActivationDistance: CGFloat = 10
        private let horizontalPanLockAngle: CGFloat = .pi / 10
        private let minimumHorizontalMomentumVelocity: CGFloat = 240
        private let horizontalPitchSnapStrength: Float = 0.42
        private let horizontalRollSnapStrength: Float = 0.48
        private let yawVelocityDamping: Float = 0.94
        private let tiltVelocityDamping: Float = 0.91
        private let followStrength:   Float = 0.72
        private let idleFollow:       Float = 0.36
        private let pitchReturnStrength: Float = 0.24
        private let rollReturnStrength: Float = 0.22
        private let horizontalSpinTurnRange: ClosedRange<Int> = 8...9
        private let horizontalSpinVelocityRange: ClosedRange<CGFloat> = 650...2200
        private let horizontalSpinDurationRange: ClosedRange<CFTimeInterval> = 3.3...4.4
        private let reverseReturnDurationPerTurn: Float = 0.28
        private let reverseReturnTiltWeight: Float = 0.72
        private let reverseReturnDurationRange: ClosedRange<Float> = 0.34...2.2
        private let reverseReturnVelocityRange: ClosedRange<CGFloat> = 180...2200

        init(manager: WeatherSceneManager?, onSunTap: (() -> Void)?, allowsInteraction: Bool) {
            self.manager = manager
            self.allowsInteraction = allowsInteraction
            self.onSunTap = onSunTap
            let restPitch = manager?.restTiltX ?? 0
            currentPitch = restPitch
            targetPitch = restPitch
        }

        func updateSunTap(_ onSunTap: (() -> Void)?) {
            self.onSunTap = onSunTap
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
            return (.pi * 2 * yawTurnsPerFullWidthPan) / referenceWidth
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
                currentYaw = 0
                targetYaw = 0
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

        private func startHorizontalYawMomentum(with velocityX: CGFloat, restPitch: Float) {
            let direction: Float = velocityX >= 0 ? 1 : -1
            let horizontalVelocity = abs(velocityX)
            let normalizedSpeed = normalizedProgress(
                value: horizontalVelocity,
                lowerBound: horizontalSpinVelocityRange.lowerBound,
                upperBound: horizontalSpinVelocityRange.upperBound
            )
            let turns: Int
            let duration: Float

            if horizontalVelocity < minimumHorizontalMomentumVelocity {
                turns = 0
                duration = 0.62
            } else {
                turns = normalizedSpeed >= 0.55
                    ? horizontalSpinTurnRange.upperBound
                    : horizontalSpinTurnRange.lowerBound
                duration = interpolate(
                    Float(horizontalSpinDurationRange.upperBound),
                    Float(horizontalSpinDurationRange.lowerBound),
                    progress: normalizedSpeed
                )
            }
            let destinationYaw = frontFacingYaw(from: currentYaw, direction: direction, extraTurns: turns)

            orientationAnimation = OrientationAnimation(
                yawCurve: .easeOutQuad,
                tiltCurve: .easeOutCubic,
                startYaw: currentYaw,
                endYaw: destinationYaw,
                startPitch: currentPitch,
                endPitch: restPitch,
                startRoll: currentRoll,
                endRoll: 0,
                duration: CFTimeInterval(duration)
            )
            targetYaw = currentYaw
            targetPitch = currentPitch
            targetRoll = currentRoll
            yawVelocity = 0
            pitchVelocity = 0
            rollVelocity = 0
        }

        private func startReverseReturnAnimation(with velocity: CGPoint, restPitch: Float) {
            let fullRotation = Float.pi * 2
            let yawTurns = abs(currentYaw) / fullRotation
            let tiltDistance = abs(currentPitch - restPitch) + abs(currentRoll)
            let weightedTravel = yawTurns + tiltDistance * reverseReturnTiltWeight
            let baseDuration = max(
                reverseReturnDurationRange.lowerBound,
                min(
                    reverseReturnDurationRange.upperBound,
                    Float(0.18) + weightedTravel * reverseReturnDurationPerTurn
                )
            )
            let speedProgress = normalizedProgress(
                value: hypot(velocity.x, velocity.y),
                lowerBound: reverseReturnVelocityRange.lowerBound,
                upperBound: reverseReturnVelocityRange.upperBound
            )
            let duration = interpolate(baseDuration * 0.9, baseDuration * 0.64, progress: speedProgress)

            orientationAnimation = OrientationAnimation(
                yawCurve: .easeOutQuint,
                tiltCurve: .easeOutQuart,
                startYaw: currentYaw,
                endYaw: 0,
                startPitch: currentPitch,
                endPitch: restPitch,
                startRoll: currentRoll,
                endRoll: 0,
                duration: CFTimeInterval(duration)
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

        private func normalizedProgress(value: CGFloat, lowerBound: CGFloat, upperBound: CGFloat) -> Float {
            guard upperBound > lowerBound else { return 0 }
            let clampedValue = min(max(value, lowerBound), upperBound)
            return Float((clampedValue - lowerBound) / (upperBound - lowerBound))
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
                stopMomentumAnimations()
                WeatherAudioPlayer.shared.playShapeTap()
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

                let yawSensitivity = yawSensitivity(for: gesture.view)
                let yawDelta = Float(deltaX) * yawSensitivity
                let interactionMode = panInteractionMode(for: gesture)
                let pitchDelta = interactionMode == .horizontalYawOnly ? 0 : Float(deltaY) * pitchSensitivity
                let rollDelta = interactionMode == .horizontalYawOnly ? 0 : Float(deltaX) * -rollSensitivity

                targetYaw += yawDelta
                targetPitch += pitchDelta
                targetRoll += rollDelta

                currentYaw += yawDelta * 0.34
                if interactionMode == .horizontalYawOnly {
                    settleHorizontalTilt(restPitch: restPitch)
                } else {
                    currentPitch += pitchDelta * 0.28
                    currentRoll += rollDelta * 0.30
                }
                applyOrientation(to: node)

                manager?.syncDisplayGroupRotation(to: node.eulerAngles)
            case .ended, .cancelled:
                isPanning = false
                lastPanPoint = nil
                let v = gesture.velocity(in: gesture.view)
                let interactionMode = panInteractionMode(for: gesture)
                if interactionMode == .horizontalYawOnly {
                    startHorizontalYawMomentum(with: v.x, restPitch: restPitch)
                } else {
                    startReverseReturnAnimation(with: v, restPitch: restPitch)
                }
                let fast = hypot(v.x, v.y) > 650
                WeatherAudioPlayer.shared.playSpinLoop(fast: fast)
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
            guard !hits.isEmpty else { return }

            if hits.contains(where: { isInteractiveNode($0.node) }) {
                onSunTap?()
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
    }
}
