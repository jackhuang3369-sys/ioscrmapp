import SceneKit
import UIKit

// MARK: - ParticleController

struct ParticleController {

    enum ParticleKind {
        case rain(intensity: Float)
        case snow
    }

    static func makeSystem(for kind: ParticleKind) -> SCNParticleSystem {
        switch kind {
        case .rain(let intensity): return makeRain(intensity: intensity)
        case .snow:                return makeSnow()
        }
    }

    @discardableResult
    static func attach(
        _ kind: ParticleKind,
        to scene: SCNScene,
        name: String = SceneNode.precipitation
    ) -> SCNNode {
        detach(from: scene, name: name)
        let emitter = SCNNode()
        emitter.name     = name
        emitter.position = SCNVector3(0, 7, 1)
        emitter.addParticleSystem(makeSystem(for: kind))
        scene.rootNode.addChildNode(emitter)
        return emitter
    }

    static func detach(from scene: SCNScene, name: String = SceneNode.precipitation) {
        scene.rootNode.childNode(withName: name, recursively: false)?.removeFromParentNode()
    }

    // MARK: - Texture Helper (snow only)

    /// 实心圆渐变：模拟雪晶小球，消除默认白色方块
    private static func makeSnowDotImage() -> UIImage {
        let size = CGSize(width: 32, height: 32)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let grd = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [UIColor.white.cgColor,
                         UIColor(white: 1, alpha: 0.6).cgColor,
                         UIColor.clear.cgColor] as CFArray,
                locations: [0, 0.55, 1]
            )!
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            ctx.cgContext.drawRadialGradient(
                grd,
                startCenter: center, startRadius: 0,
                endCenter:   center, endRadius: size.width / 2,
                options: []
            )
        }
    }

    // MARK: - Private Builders

    private static func makeRain(intensity: Float) -> SCNParticleSystem {
        let ps = SCNParticleSystem()
        ps.emitterShape              = SCNBox(width: 14, height: 0.1, length: 6, chamferRadius: 0)
        ps.birthRate                 = CGFloat(min(intensity * 1400, 2400))
        ps.particleLifeSpan          = 1.6
        ps.particleLifeSpanVariation = 0.5
        ps.particleSize              = 0.016
        ps.particleSizeVariation     = 0.004
        ps.particleColor             = UIColor(red: 0.72, green: 0.88, blue: 1.0, alpha: 0.58)
        ps.particleColorVariation    = SCNVector4(0.08, 0.06, 0.08, 0.1)
        ps.isAffectedByGravity       = false
        ps.acceleration              = SCNVector3(0.4, -10.0, 0)
        ps.particleVelocity          = 7.5
        ps.particleVelocityVariation = 2.0
        ps.orientationMode           = .free
        ps.sortingMode               = .none
        ps.loops                     = true
        return ps
    }

    private static func makeSnow() -> SCNParticleSystem {
        let ps = SCNParticleSystem()
        ps.emitterShape              = SCNBox(width: 14, height: 0.1, length: 6, chamferRadius: 0)
        ps.birthRate                 = 90
        ps.particleLifeSpan          = 7.0
        ps.particleLifeSpanVariation = 2.5
        // 圆形雪粒贴图（消除白色方块）
        ps.particleImage             = makeSnowDotImage()
        ps.particleSize              = 0.055          // 略小于原 0.06
        ps.particleSizeVariation     = 0.020
        ps.particleColor             = UIColor(red: 0.88, green: 0.94, blue: 1.0, alpha: 0.85)
        ps.particleColorVariation    = SCNVector4(0.04, 0.04, 0.04, 0.06)
        ps.emittingDirection         = SCNVector3(0, -1, 0)
        ps.spreadingAngle            = 20
        ps.isAffectedByGravity       = false
        ps.acceleration              = SCNVector3(0, 0, 0)
        ps.particleVelocity          = 0.8
        ps.particleVelocityVariation = 0.3
        ps.orientationMode           = .billboardScreenAligned
        ps.blendMode                 = .alpha
        ps.loops                     = true
        return ps
    }
}
