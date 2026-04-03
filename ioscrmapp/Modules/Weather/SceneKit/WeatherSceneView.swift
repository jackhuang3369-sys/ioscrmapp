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

    // MARK: UIViewRepresentable

    func makeCoordinator() -> Coordinator { Coordinator(manager: manager) }

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene                    = scene
        scnView.backgroundColor          = .clear
        scnView.isOpaque                 = false
        scnView.allowsCameraControl      = false
        scnView.antialiasingMode         = .multisampling4X
        scnView.rendersContinuously      = true
        scnView.autoenablesDefaultLighting = false

        let pan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        pan.maximumNumberOfTouches = 1
        scnView.addGestureRecognizer(pan)

        context.coordinator.startDisplayLink()
        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        if uiView.scene !== scene { uiView.scene = scene }
    }

    // MARK: – Coordinator (gesture + CADisplayLink spin)

    final class Coordinator: NSObject {

        private let manager:     WeatherSceneManager?
        private var velX:        Float = 0
        private var velY:        Float = 0
        private var isPanning:   Bool  = false
        private var displayLink: CADisplayLink?
        private var hintTimer:   Timer?
        private var hintPhase:   Float = 0

        // Tuning constants
        private let sensitivity: Float = 0.0054  // rad per screen-point
        private let friction:    Float = 0.90    // per-frame velocity decay
        private let autoSpin:    Float = 0.0     // keep the model still unless the user drags it
        private let tiltLimit:   Float = 0.30    // 上下旋转范围（约±17度）

        init(manager: WeatherSceneManager?) {
            self.manager = manager
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
            velX = 0.018
        }

        @objc private func step(_ link: CADisplayLink) {
            guard let node = manager?.conditionGroup else { return }
            if !isPanning {
                velX *= friction
                velY *= friction
            }
            // Horizontal spin (Y-axis)
            node.eulerAngles.y += velX + autoSpin
            // Vertical tilt returns slowly to the manager's preferred rest angle.
            let restTilt = manager?.restTiltX ?? 0
            let newX = node.eulerAngles.x + velY + ((restTilt - node.eulerAngles.x) * 0.08)
            node.eulerAngles.x = max(restTilt - tiltLimit, min(restTilt + tiltLimit, newX))
            // 同步数字显示组旋转，让数字与天气模型看起来是一体的
            manager?.syncDisplayGroupRotation(to: node.eulerAngles)
        }

        // MARK: Pan gesture

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let node = manager?.conditionGroup else { return }
            switch gesture.state {
            case .began:
                isPanning = true
                velX = 0
                velY = 0
                WeatherAudioPlayer.shared.playShapeTap()
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.16
                node.scale = SCNVector3(node.scale.x * 1.02, node.scale.y * 1.02, node.scale.z * 1.02)
                SCNTransaction.commit()
            case .changed:
                let d = gesture.translation(in: gesture.view)
                node.eulerAngles.y += Float(d.x) * sensitivity
                let restTilt = manager?.restTiltX ?? 0
                let newX = node.eulerAngles.x + Float(d.y) * sensitivity * 0.5
                node.eulerAngles.x = max(restTilt - tiltLimit, min(restTilt + tiltLimit, newX))
                gesture.setTranslation(.zero, in: gesture.view)
                manager?.syncDisplayGroupRotation(to: node.eulerAngles)
            case .ended, .cancelled:
                isPanning = false
                let v = gesture.velocity(in: gesture.view)
                velX = Float(v.x) * sensitivity / 60
                velY = 0
                let fast = abs(v.x) > 600
                WeatherAudioPlayer.shared.playSpinLoop(fast: fast)
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.22
                let currentScale = node.scale.x / 1.02
                node.scale = SCNVector3(currentScale, currentScale, currentScale)
                SCNTransaction.commit()
            default:
                isPanning = false
            }
        }
    }
}
