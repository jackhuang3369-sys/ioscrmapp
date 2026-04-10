import SwiftUI
import SceneKit

// MARK: - PhysicsConstants
//
// Frame-rate-independent physics parameters.
// Values are derived from original frame-based constants using exact mathematical conversion:
// - Per-frame damping → per-second rate: rate = ln(1/damping) * fps
// - Per-frame follow → per-second rate: rate = -ln(1-follow) * fps
// - Per-frame velocity → per-second velocity: velocity_per_sec = velocity_per_frame * fps
//
// Original system was designed for 60fps baseline.

private struct PhysicsConstants {
    // MARK: - Design assumptions
    /// The frame rate the original constants were designed for.
    static let designFrameRate: Float = 60.0

    // MARK: - Sensitivity (radians per pixel)
    static let yawSensitivity:   Float = 0.0155
    static let pitchSensitivity: Float = 0.0125
    static let rollSensitivity:  Float = 0.0038

    // MARK: - Velocity decay (per second)
    /// Derived from original velocityDamping = 0.96 (per frame)
    /// rate = ln(1/0.96) * 60 ≈ 2.45
    static let velocityDecayRate: Float = 2.45

    // MARK: - Follow rates (per second)
    /// Derived from original followStrength = 0.72 (per frame during pan)
    /// rate = -ln(1-0.72) * 60 = -ln(0.28) * 60 ≈ 76.3
    static let activeFollowRate: Float = 76.3

    /// Derived from original idleFollow = 0.36 (per frame during idle)
    /// rate = -ln(1-0.36) * 60 = -ln(0.64) * 60 ≈ 27.5
    static let idleFollowRate: Float = 27.5

    // MARK: - Return-to-center rates (per second)
    /// Derived from original yawReturnStrength = 0.06 (per frame)
    /// rate = -ln(1-0.06) * 60 ≈ 3.7
    static let yawReturnRate: Float = 3.7

    /// Derived from original pitchReturnStrength = 0.24
    /// rate = -ln(1-0.24) * 60 ≈ 16.5
    static let pitchReturnRate: Float = 16.5

    /// Derived from original rollReturnStrength = 0.22
    /// rate = -ln(1-0.22) * 60 ≈ 15.1
    static let rollReturnRate: Float = 15.1

    // MARK: - Velocity thresholds for return behavior
    static let yawVelocityThreshold:   Float = 0.007
    static let pitchVelocityThreshold: Float = 0.006
    static let rollVelocityThreshold:  Float = 0.005

    // MARK: - Gesture velocity conversion
    /// Converts gesture velocity (pixels/sec) to angular velocity (radians/sec).
    /// Original formula: yawVelocity_per_frame = v.x * sens / 18
    /// To convert to per-second: yawVelocity_per_sec = v.x * sens * 60 / 18
    /// So yawConversionFactor = 60 / 18 ≈ 3.333
    static let yawGestureFactor: Float = designFrameRate / 18.0   // ≈ 3.333

    /// Original: pitchVelocity = v.y * sens / 110
    /// pitchConversionFactor = 60 / 110 ≈ 0.545
    static let pitchGestureFactor: Float = designFrameRate / 110.0  // ≈ 0.545

    /// Original: rollVelocity = v.x * sens / 118
    /// rollConversionFactor = 60 / 118 ≈ 0.508
    static let rollGestureFactor: Float = designFrameRate / 118.0   // ≈ 0.508

    // MARK: - Helper functions

    /// Convert per-frame damping coefficient to per-second rate.
    static func dampingToRate(damping: Float) -> Float {
        return log(1.0 / damping) * designFrameRate
    }

    /// Convert per-frame follow coefficient to per-second rate.
    static func followToRate(follow: Float) -> Float {
        return -log(1.0 - follow) * designFrameRate
    }
}

// MARK: - WeatherSceneView
//
// Full-screen SceneKit view with pan-gesture rotation + inertial auto-spin.
// The transparent background lets the SwiftUI sky gradient show through.
// Rotation is applied to WeatherSceneManager.conditionGroup so lighting
// remains stationary while the weather model spins.
// All animations are frame-rate-independent using PhysicsConstants.

struct WeatherSceneView: UIViewRepresentable {

    let scene:   SCNScene
    /// Access to the rotatable model node. Pass nil for non-interactive scene views (e.g. Page B panels).
    let manager: WeatherSceneManager?
    let onSunTap: (() -> Void)?
    let allowsInteraction: Bool

    init(scene: SCNScene, manager: WeatherSceneManager?, onSunTap: (() -> Void)? = nil, allowsInteraction: Bool = true) {
        self.scene = scene
        self.manager = manager
        self.onSunTap = onSunTap
        self.allowsInteraction = allowsInteraction
    }

    // MARK: UIViewRepresentable

    func makeCoordinator() -> Coordinator { Coordinator(manager: manager, onSunTap: onSunTap) }

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
        context.coordinator.updateSunTap(onSunTap)
    }

    // MARK: – Coordinator (gesture + CADisplayLink spin)

    final class Coordinator: NSObject {

        private let manager:     WeatherSceneManager?
        private var onSunTap:    (() -> Void)?
        private var currentYaw:     Float = 0
        private var currentPitch:   Float = 0
        private var currentRoll:    Float = 0
        private var targetYaw:      Float = 0
        private var targetPitch:    Float = 0
        private var targetRoll:     Float = 0
        private var yawVelocity:   Float = 0    // radians per second
        private var pitchVelocity: Float = 0    // radians per second
        private var rollVelocity:  Float = 0    // radians per second
        private var isPanning:     Bool  = false
        private var displayLink: CADisplayLink?
        private var hintTimer:   Timer?
        private var lastPanPoint: CGPoint?
        private var lastFrameTime: CFTimeInterval = 0

        // Tuning constants moved to PhysicsConstants struct

        init(manager: WeatherSceneManager?, onSunTap: (() -> Void)?) {
            self.manager = manager
            self.onSunTap = onSunTap
            let restPitch = manager?.restTiltX ?? 0
            currentPitch = restPitch
            targetPitch = restPitch
        }

        func updateSunTap(_ onSunTap: (() -> Void)?) {
            self.onSunTap = onSunTap
        }

        deinit { displayLink?.invalidate(); hintTimer?.invalidate() }

        // MARK: Display link

        func startDisplayLink() {
            guard manager != nil else { return }  // no manager = no gesture/spin needed
            displayLink?.invalidate()
            displayLink = CADisplayLink(target: self, selector: #selector(step))
            displayLink?.add(to: .main, forMode: .common)
            // 延迟 0.8s 播放一次左右摇摆提示，让用户知道可以拖拽
            hintTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { [weak self] _ in
                self?.playDragHint()
            }
        }

        // 首次加载时给模型一个左右摇摆速度，提示可拖拽
        // Original: yawVelocity = 0.024 (per-frame), rollVelocity = -0.008 (per-frame)
        // Converted: yawVelocity = 0.024 * 60 = 1.44 (per-second)
        private func playDragHint() {
            guard !isPanning else { return }
            yawVelocity = 0.024 * PhysicsConstants.designFrameRate   // 1.44 radians/sec
            rollVelocity = -0.008 * PhysicsConstants.designFrameRate  // -0.48 radians/sec
        }

        @objc private func step(_ link: CADisplayLink) {
            guard let node = manager?.conditionGroup else { return }
            let restPitch = manager?.restTiltX ?? 0
            let autoSpinSpeed = manager?.autoSpinSpeed ?? 0  // radians per second
            let hasContinuousAutoSpin = abs(autoSpinSpeed) > 0.0001

            // Frame-rate-independent time calculation
            let currentTime = link.targetTimestamp
            let deltaTime: Float
            if lastFrameTime == 0 {
                // First frame: use nominal 60fps as baseline
                deltaTime = 1.0 / PhysicsConstants.designFrameRate
            } else {
                deltaTime = Float(currentTime - lastFrameTime)
            }
            lastFrameTime = currentTime

            // Clamp deltaTime to prevent physics explosion on long pauses
            let dt = min(deltaTime, 0.1)

            if !isPanning {
                // Velocity-driven target movement
                // velocity is in radians/sec, multiply by dt to get radians this frame
                targetYaw += (autoSpinSpeed + yawVelocity) * dt
                targetPitch += pitchVelocity * dt
                targetRoll += rollVelocity * dt

                // Exponential velocity decay (frame-rate independent)
                // velocity *= exp(-rate * dt)
                let velocityDecayCoeff = exp(-PhysicsConstants.velocityDecayRate * dt)
                yawVelocity *= velocityDecayCoeff
                pitchVelocity *= velocityDecayCoeff
                rollVelocity *= velocityDecayCoeff

                // Return-to-center force
                // Use stronger rate when velocity is low (already near rest)
                let yawReturnRate: Float = hasContinuousAutoSpin ? 0 :
                    (abs(yawVelocity) < PhysicsConstants.yawVelocityThreshold ?
                     PhysicsConstants.yawReturnRate : PhysicsConstants.yawReturnRate * 1.2)
                let pitchReturnRate: Float =
                    abs(pitchVelocity) < PhysicsConstants.pitchVelocityThreshold ?
                    PhysicsConstants.pitchReturnRate : PhysicsConstants.pitchReturnRate * 1.4
                let rollReturnRate: Float =
                    abs(rollVelocity) < PhysicsConstants.rollVelocityThreshold ?
                    PhysicsConstants.rollReturnRate : PhysicsConstants.rollReturnRate * 1.3

                // Apply return-to-center using exponential approach
                // target += (rest - target) * (1 - exp(-rate * dt))
                let yawReturnCoeff = 1.0 - exp(-yawReturnRate * dt)
                let pitchReturnCoeff = 1.0 - exp(-pitchReturnRate * dt)
                let rollReturnCoeff = 1.0 - exp(-rollReturnRate * dt)

                targetYaw += (0 - targetYaw) * yawReturnCoeff
                targetPitch += (restPitch - targetPitch) * pitchReturnCoeff
                targetRoll += (0 - targetRoll) * rollReturnCoeff
            }

            // Smooth follow to target (frame-rate independent)
            // current += (target - current) * (1 - exp(-rate * dt))
            let followRate = isPanning ? PhysicsConstants.activeFollowRate : PhysicsConstants.idleFollowRate
            let followCoeff = 1.0 - exp(-followRate * dt)
            currentYaw += (targetYaw - currentYaw) * followCoeff
            currentPitch += (targetPitch - currentPitch) * followCoeff
            currentRoll += (targetRoll - currentRoll) * followCoeff

            applyOrientation(to: node)

            manager?.syncDisplayGroupRotation(to: node.eulerAngles)
        }

        private func applyOrientation(to node: SCNNode) {
            let yaw = simd_quatf(angle: currentYaw, axis: SIMD3<Float>(0, 1, 0))
            let pitch = simd_quatf(angle: currentPitch, axis: SIMD3<Float>(1, 0, 0))
            let roll = simd_quatf(angle: currentRoll, axis: SIMD3<Float>(0, 0, 1))
            node.simdOrientation = simd_normalize(yaw * pitch * roll)
        }

        // MARK: Pan gesture

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let node = manager?.conditionGroup else { return }
            switch gesture.state {
            case .began:
                isPanning = true
                lastPanPoint = gesture.location(in: gesture.view)
                yawVelocity = 0
                pitchVelocity = 0
                rollVelocity = 0
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

                // Direct position update during pan (pixel to radians)
                let yawDelta = Float(deltaX) * PhysicsConstants.yawSensitivity
                let pitchDelta = Float(deltaY) * PhysicsConstants.pitchSensitivity
                let rollDelta = Float(deltaX) * -PhysicsConstants.rollSensitivity

                targetYaw += yawDelta
                targetPitch += pitchDelta
                targetRoll += rollDelta

                // Direct feedback during pan: partial immediate update for responsiveness
                // These coefficients remain frame-based (not time-dependent) for consistent feel
                currentYaw += yawDelta * 0.34
                currentPitch += pitchDelta * 0.28
                currentRoll += rollDelta * 0.30
                applyOrientation(to: node)

                manager?.syncDisplayGroupRotation(to: node.eulerAngles)
            case .ended, .cancelled:
                isPanning = false
                lastPanPoint = nil
                let v = gesture.velocity(in: gesture.view)

                // Convert gesture velocity (pixels/sec) to angular velocity (radians/sec)
                // Using exact conversion from original per-frame formula:
                // yawVelocity_per_frame = v.x * sens / 18
                // yawVelocity_per_sec = v.x * sens * 60 / 18
                yawVelocity = Float(v.x) * PhysicsConstants.yawSensitivity * PhysicsConstants.yawGestureFactor
                pitchVelocity = Float(v.y) * PhysicsConstants.pitchSensitivity * PhysicsConstants.pitchGestureFactor
                rollVelocity = Float(v.x) * PhysicsConstants.rollSensitivity * PhysicsConstants.rollGestureFactor

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