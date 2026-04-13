import SwiftUI
import SceneKit

// MARK: - WeatherSceneView
//
// Full-screen SceneKit view with pan-gesture rotation and rule-based snapback/spin.
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

        private struct HorizontalSpinResolution {
            let destinationYaw: Float
            let duration: CFTimeInterval
            let yawCurve: EasingCurve
            let tiltCurve: EasingCurve
            let prefersFastAudio: Bool
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
        private var orientationAnimation: OrientationAnimation?
        private var hasUserInteracted: Bool = false
        private var lastInteractionResetVersion: Int = 0

        // Tuning constants
        private let freeformYawTurnsPerFullWidthPan: Float = 4.8
        private let horizontalYawTurnsPerFullWidthPan: Float = 1
        private let minimumPanReferenceWidth: Float = 280
        private let pitchSensitivity: Float = 0.0125
        private let rollSensitivity:  Float = 0.0038
        private let horizontalPanActivationDistance: CGFloat = 10
        private let horizontalPanLockAngle: CGFloat = .pi / 10
        private let fastHorizontalPanVelocity: CGFloat = 650
        private let assistedFastHorizontalPanVelocity: CGFloat = 380
        private let fastHorizontalQuarterTurnRatio: CGFloat = 0.25
        private let fastHorizontalHalfTurnRatio: CGFloat = 0.5
        private let maximumFastHorizontalTurns: Int = 4
        private let horizontalPitchSnapStrength: Float = 0.42
        private let horizontalRollSnapStrength: Float = 0.48
        private let yawVelocityDamping: Float = 0.94
        private let tiltVelocityDamping: Float = 0.91
        private let followStrength:   Float = 0.72
        private let idleFollow:       Float = 0.36
        private let pitchReturnStrength: Float = 0.24
        private let rollReturnStrength: Float = 0.22
        private let reverseReturnDurationPerTurn: Float = 0.28
        private let reverseReturnTiltWeight: Float = 0.72
        private let reverseReturnDurationRange: ClosedRange<Float> = 0.34...2.2
        private let reverseReturnVelocityRange: ClosedRange<CGFloat> = 180...2200

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
            isPanning = false
            lastPanPoint = nil
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

        private func freeformYawSensitivity(for view: UIView?) -> Float {
            let referenceWidth = max(Float(view?.bounds.width ?? 0), minimumPanReferenceWidth)
            return (.pi * 2 * freeformYawTurnsPerFullWidthPan) / referenceWidth
        }

        private func horizontalYawSensitivity(for view: UIView?) -> Float {
            let referenceWidth = max(Float(view?.bounds.width ?? 0), minimumPanReferenceWidth)
            return (.pi * 2 * horizontalYawTurnsPerFullWidthPan) / referenceWidth
        }

        private func horizontalPanReferenceWidth(for view: UIView?) -> CGFloat {
            max(view?.bounds.width ?? 0, CGFloat(minimumPanReferenceWidth))
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

        private func startHorizontalSpinAnimation(
            translation: CGPoint,
            velocity: CGPoint,
            restPitch: Float,
            view: UIView?
        ) -> Bool {
            guard let resolution = resolveHorizontalSpin(
                translation: translation,
                velocity: velocity,
                view: view
            ) else {
                return false
            }

            orientationAnimation = OrientationAnimation(
                yawCurve: resolution.yawCurve,
                tiltCurve: resolution.tiltCurve,
                startYaw: currentYaw,
                endYaw: resolution.destinationYaw,
                startPitch: currentPitch,
                endPitch: restPitch,
                startRoll: currentRoll,
                endRoll: 0,
                duration: resolution.duration
            )
            targetYaw = currentYaw
            targetPitch = currentPitch
            targetRoll = currentRoll
            yawVelocity = 0
            pitchVelocity = 0
            rollVelocity = 0
            WeatherAudioPlayer.shared.playSpinLoop(
                tier: spinSoundTier(
                    prefersFastAudio: resolution.prefersFastAudio,
                    translation: translation,
                    view: view
                )
            )
            return true
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

        private func positiveRemainder(_ value: Float, divisor: Float) -> Float {
            let remainder = value.truncatingRemainder(dividingBy: divisor)
            return remainder >= 0 ? remainder : remainder + divisor
        }

        private func forwardFrontFacingYaw(
            from yaw: Float,
            direction: Float,
            extraTurns: Int
        ) -> Float {
            let fullRotation = Float.pi * 2
            let normalizedYaw = positiveRemainder(yaw, divisor: fullRotation)

            if direction >= 0 {
                let offsetToFront = normalizedYaw == 0 ? 0 : fullRotation - normalizedYaw
                return yaw + offsetToFront + Float(extraTurns) * fullRotation
            }

            let offsetToFront = normalizedYaw == 0 ? 0 : normalizedYaw
            return yaw - offsetToFront - Float(extraTurns) * fullRotation
        }

        private func reverseFrontFacingYaw(from yaw: Float, dragDirection: Float) -> Float {
            let reverseDirection: Float = dragDirection >= 0 ? -1 : 1
            return forwardFrontFacingYaw(from: yaw, direction: reverseDirection, extraTurns: 0)
        }

        private func signedFrontFacingYaw(turnCount: Int, direction: Float) -> Float {
            let clampedTurnCount = max(0, turnCount)
            let signedDirection: Float = direction >= 0 ? 1 : -1
            return signedDirection * Float(clampedTurnCount) * (.pi * 2)
        }

        private func fastReleaseExtraTurns(for distanceRatio: CGFloat) -> Int {
            let distancePastHalf = max(0, distanceRatio - fastHorizontalHalfTurnRatio)
            let additionalTurns = Int(ceil(distancePastHalf / fastHorizontalHalfTurnRatio))
            return min(maximumFastHorizontalTurns, max(2, additionalTurns + 1))
        }

        private func resolveHorizontalSpin(
            translation: CGPoint,
            velocity: CGPoint,
            view: UIView?
        ) -> HorizontalSpinResolution? {
            let horizontalDistance = abs(translation.x)
            guard horizontalDistance > 0.5 else { return nil }

            let referenceWidth = horizontalPanReferenceWidth(for: view)
            let distanceRatio = horizontalDistance / referenceWidth
            let qualifiesForSingleTurnDistance = distanceRatio >= fastHorizontalQuarterTurnRatio
            let effectiveFastVelocity = qualifiesForSingleTurnDistance
                ? assistedFastHorizontalPanVelocity
                : fastHorizontalPanVelocity
            let isFastPan = abs(velocity.x) >= effectiveFastVelocity
            let direction = resolvedHorizontalDirection(translationX: translation.x, velocityX: velocity.x)
            let distanceBasedTurns = min(
                maximumFastHorizontalTurns,
                max(1, Int(ceil(distanceRatio)))
            )
            let destinationYaw: Float
            let duration: CFTimeInterval
            let yawCurve: EasingCurve
            let tiltCurve: EasingCurve
            let prefersFastAudio = isFastPan

            if isFastPan {
                if distanceRatio < fastHorizontalQuarterTurnRatio {
                    destinationYaw = reverseFrontFacingYaw(from: currentYaw, dragDirection: direction)
                    let travelTurns = abs(destinationYaw - currentYaw) / (.pi * 2)
                    duration = CFTimeInterval(min(max(0.22, 0.18 + Double(travelTurns) * 0.42), 0.6))
                    yawCurve = .easeOutQuart
                    tiltCurve = .easeOutQuart
                } else if distanceRatio <= fastHorizontalHalfTurnRatio {
                    destinationYaw = signedFrontFacingYaw(turnCount: 1, direction: direction)
                    let travelTurns = abs(destinationYaw - currentYaw) / (.pi * 2)
                    duration = CFTimeInterval(min(max(0.62, 0.3 + Double(travelTurns) * 0.36), 1.05))
                    yawCurve = .easeOutQuart
                    tiltCurve = .easeOutQuart
                } else {
                    destinationYaw = signedFrontFacingYaw(turnCount: distanceBasedTurns, direction: direction)
                    let travelTurns = abs(destinationYaw - currentYaw) / (.pi * 2)
                    duration = CFTimeInterval(min(max(1.05, 0.42 + Double(travelTurns) * 0.42), 2.8))
                    yawCurve = .easeOutQuint
                    tiltCurve = .easeOutQuart
                }
            } else if distanceRatio <= fastHorizontalHalfTurnRatio {
                destinationYaw = reverseFrontFacingYaw(from: currentYaw, dragDirection: direction)
                let travelTurns = abs(destinationYaw - currentYaw) / (.pi * 2)
                duration = CFTimeInterval(min(max(0.28, 0.22 + Double(travelTurns) * 0.5), 0.82))
                yawCurve = .easeOutCubic
                tiltCurve = .easeOutQuart
            } else {
                destinationYaw = signedFrontFacingYaw(turnCount: distanceBasedTurns, direction: direction)
                let travelTurns = abs(destinationYaw - currentYaw) / (.pi * 2)
                duration = CFTimeInterval(min(max(0.38, 0.28 + Double(travelTurns) * 0.52), 1.4))
                yawCurve = .easeOutCubic
                tiltCurve = .easeOutQuart
            }

            return HorizontalSpinResolution(
                destinationYaw: destinationYaw,
                duration: duration,
                yawCurve: yawCurve,
                tiltCurve: tiltCurve,
                prefersFastAudio: prefersFastAudio
            )
        }

        private func resolvedHorizontalDirection(translationX: CGFloat, velocityX: CGFloat) -> Float {
            if abs(translationX) > 0.5 {
                return translationX >= 0 ? 1 : -1
            }

            if abs(velocityX) > 0.5 {
                return velocityX >= 0 ? 1 : -1
            }

            return currentYaw >= 0 ? 1 : -1
        }

        private func spinSoundTier(
            prefersFastAudio: Bool,
            translation: CGPoint,
            view: UIView?
        ) -> WeatherSpinSoundTier {
            guard prefersFastAudio else { return .slow }

            let referenceWidth = horizontalPanReferenceWidth(for: view)
            let distanceRatio = abs(translation.x) / max(referenceWidth, 1)
            return distanceRatio > fastHorizontalHalfTurnRatio ? .fast : .medium
        }

        private func spinSoundTier(for velocity: CGPoint) -> WeatherSpinSoundTier {
            let speed = hypot(velocity.x, velocity.y)
            if speed >= fastHorizontalPanVelocity * 1.6 {
                return .fast
            }
            if speed >= fastHorizontalPanVelocity {
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
                return easeOutQuad(progress)
            case .easeOutCubic:
                return easeOutCubic(progress)
            case .easeOutQuart:
                return easeOutQuart(progress)
            case .easeOutQuint:
                return easeOutQuint(progress)
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

                let interactionMode = panInteractionMode(for: gesture)
                let yawSensitivity = interactionMode == .horizontalYawOnly
                    ? horizontalYawSensitivity(for: gesture.view)
                    : freeformYawSensitivity(for: gesture.view)
                let yawDelta = Float(deltaX) * yawSensitivity
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
                let translation = gesture.translation(in: gesture.view)
                let interactionMode = panInteractionMode(for: gesture)
                if interactionMode == .horizontalYawOnly {
                    if !startHorizontalSpinAnimation(
                        translation: translation,
                        velocity: v,
                        restPitch: restPitch,
                        view: gesture.view
                    ) {
                        startReverseReturnAnimation(with: v, restPitch: restPitch)
                        WeatherAudioPlayer.shared.playSpinLoop(
                            tier: spinSoundTier(for: v)
                        )
                    }
                } else {
                    startReverseReturnAnimation(with: v, restPitch: restPitch)
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
            if hits.contains(where: { isInteractiveNode($0.node) }) {
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
    }
}
