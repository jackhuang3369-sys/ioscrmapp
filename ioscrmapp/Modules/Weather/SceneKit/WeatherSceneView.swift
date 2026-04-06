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
        private var yawVelocity:   Float = 0
        private var pitchVelocity: Float = 0
        private var rollVelocity:  Float = 0
        private var isPanning:     Bool  = false
        private var displayLink: CADisplayLink?
        private var hintTimer:   Timer?
        private var lastPanPoint: CGPoint?

        // Tuning constants
        private let yawSensitivity:   Float = 0.0155
        private let pitchSensitivity: Float = 0.0125
        private let rollSensitivity:  Float = 0.0038
        private let velocityDamping:  Float = 0.93
        private let followStrength:   Float = 0.72
        private let idleFollow:       Float = 0.36
        private let yawReturnStrength: Float = 0.2
        private let pitchReturnStrength: Float = 0.24
        private let rollReturnStrength: Float = 0.22

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
        private func playDragHint() {
            guard !isPanning else { return }
            yawVelocity = 0.024
            rollVelocity = -0.008
        }

        @objc private func step(_ link: CADisplayLink) {
            guard let node = manager?.conditionGroup else { return }
            let restPitch = manager?.restTiltX ?? 0
            let autoSpinSpeed = manager?.autoSpinSpeed ?? 0
            let hasContinuousAutoSpin = abs(autoSpinSpeed) > 0.0001

            if !isPanning {
                targetYaw += autoSpinSpeed + yawVelocity
                targetPitch += pitchVelocity
                targetRoll += rollVelocity

                yawVelocity *= velocityDamping
                pitchVelocity *= velocityDamping
                rollVelocity *= velocityDamping

                let yawReturn: Float = hasContinuousAutoSpin ? 0 : (abs(yawVelocity) < 0.007 ? yawReturnStrength : 0.03)
                let pitchReturn = abs(pitchVelocity) < 0.006 ? pitchReturnStrength : 0.08
                let rollReturn = abs(rollVelocity) < 0.005 ? rollReturnStrength : 0.06

                targetYaw += (0 - targetYaw) * yawReturn
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

                let yawDelta = Float(deltaX) * yawSensitivity
                let pitchDelta = Float(deltaY) * pitchSensitivity
                let rollDelta = Float(deltaX) * -rollSensitivity

                targetYaw += yawDelta
                targetPitch += pitchDelta
                targetRoll += rollDelta

                currentYaw += yawDelta * 0.34
                currentPitch += pitchDelta * 0.28
                currentRoll += rollDelta * 0.30
                applyOrientation(to: node)

                manager?.syncDisplayGroupRotation(to: node.eulerAngles)
            case .ended, .cancelled:
                isPanning = false
                lastPanPoint = nil
                let v = gesture.velocity(in: gesture.view)
                yawVelocity = Float(v.x) * yawSensitivity / 92
                pitchVelocity = Float(v.y) * pitchSensitivity / 110
                rollVelocity = Float(v.x) * -rollSensitivity / 118
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
