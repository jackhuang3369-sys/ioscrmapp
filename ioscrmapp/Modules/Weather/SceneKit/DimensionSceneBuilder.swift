import SceneKit
import UIKit

// MARK: - DimensionSceneBuilder
//
// Loads real 3D models from normal_models.dae for each Page B dimension panel.
// Falls back to improved programmatic geometry if the bundle resource is absent.

struct DimensionSceneBuilder {

    // MARK: - Public entry point

    static func buildScene(
        for dimension: WeatherDetailDimension,
        data: WeatherDetailData
    ) -> SCNScene {
        let scene = baseScene()
        loadModel(for: dimension, data: data, into: scene)
        return scene
    }

    // MARK: - Base scene (camera + 3-point lighting)

    private static func baseScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor.clear

        // Camera
        let cam           = SCNCamera()
        cam.fieldOfView   = 62
        cam.zNear         = 0.1
        cam.zFar          = 60
        let camNode       = SCNNode()
        camNode.camera    = cam
        camNode.position  = SCNVector3(0, 0, 6)
        scene.rootNode.addChildNode(camNode)

        // Ambient
        let amb       = SCNLight(); amb.type = .ambient
        amb.intensity = 280
        amb.color     = UIColor(red: 0.5, green: 0.55, blue: 0.72, alpha: 1)
        let ambNode   = SCNNode(); ambNode.light = amb
        scene.rootNode.addChildNode(ambNode)

        // Key — upper right, warm
        let key       = SCNLight(); key.type = .directional
        key.intensity = 1100
        key.color     = UIColor(red: 1.0, green: 0.95, blue: 0.82, alpha: 1)
        let keyNode   = SCNNode(); keyNode.light = key
        keyNode.eulerAngles = SCNVector3(-0.55, 0.7, 0)
        scene.rootNode.addChildNode(keyNode)

        // Rim — cool blue from behind
        let rim       = SCNLight(); rim.type = .directional
        rim.intensity = 320
        rim.color     = UIColor(red: 0.38, green: 0.62, blue: 1.0, alpha: 1)
        let rimNode   = SCNNode(); rimNode.light = rim
        rimNode.eulerAngles = SCNVector3(0.4, Float.pi - 0.5, 0)
        scene.rootNode.addChildNode(rimNode)

        return scene
    }

    // MARK: - Model loading

    /// Picks the right node name from normal_models.dae per dimension.
    private static func modelNodeName(for dimension: WeatherDetailDimension) -> String {
        switch dimension {
        case .temperature:   return "sun"
        case .wind:          return "air-day"
        case .precipitation: return "precip-day"
        case .air:           return "air-day"
        }
    }

    private static func loadModel(
        for dimension: WeatherDetailDimension,
        data: WeatherDetailData,
        into scene: SCNScene
    ) {
        // Try real asset first
        if let models = sharedModelsScene(),
           let src = models.rootNode.childNode(
               withName: modelNodeName(for: dimension),
               recursively: true
           ) {
            let clone = src.clone()
            // Scale to fill the 2/3 scene area nicely
            clone.scale    = SCNVector3(1.5, 1.5, 1.5)
            clone.position = SCNVector3(0, -0.2, 0)
            addRotation(to: clone, dimension: dimension)
            scene.rootNode.addChildNode(clone)
            return
        }

        // Fallback: PBR-shaded programmatic geometry
        fallback(for: dimension, data: data, into: scene)
    }

    private static func addRotation(to node: SCNNode, dimension: WeatherDetailDimension) {
        let rot         = CABasicAnimation(keyPath: "rotation")
        let axis: SCNVector4
        switch dimension {
        case .temperature:
            axis = SCNVector4(0, 1, 0.1, Float.pi * 2)   // slow Y
        case .wind:
            axis = SCNVector4(0, 0, 1, Float.pi * 2)      // spin like a compass
        case .precipitation:
            axis = SCNVector4(0, 1, 0.05, Float.pi * 2)
        case .air:
            axis = SCNVector4(0, 1, 0.2, Float.pi * 2)
        }
        rot.toValue     = NSValue(scnVector4: axis)
        rot.duration    = dimension == .wind ? 8 : 22
        rot.repeatCount = .infinity
        node.addAnimation(rot, forKey: "dim_rotate")

        // Gentle float
        let bob           = CABasicAnimation(keyPath: "position.y")
        bob.fromValue     = Float(-0.15)
        bob.toValue       = Float(0.15)
        bob.duration      = 4.2
        bob.autoreverses  = true
        bob.repeatCount   = .infinity
        bob.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        node.addAnimation(bob, forKey: "dim_float")
    }

    // MARK: - Shared models scene cache

    private static var _cachedModels: SCNScene?
    private static func sharedModelsScene() -> SCNScene? {
        if _cachedModels == nil {
            guard let url = Bundle.main.url(
                forResource: "normal_models", withExtension: "dae",
                subdirectory: "WeatherData/Scenes") else { return nil }
            _cachedModels = try? SCNScene(url: url, options: [.checkConsistency: false])
        }
        return _cachedModels
    }

    // MARK: - Fallback programmatic scenes

    private static func fallback(
        for dimension: WeatherDetailDimension,
        data: WeatherDetailData,
        into scene: SCNScene
    ) {
        switch dimension {
        case .temperature:   fallbackTemperature(data.temperature, into: scene)
        case .wind:          fallbackWind(data.wind,               into: scene)
        case .precipitation: fallbackPrecipitation(data.precipitation, into: scene)
        case .air:           fallbackAir(data.air,                 into: scene)
        }
    }

    // MARK: Temperature fallback — glowing PBR sun orb

    private static func fallbackTemperature(_ data: WeatherTempDetail, into scene: SCNScene) {
        let sphere = SCNSphere(radius: 1.2); sphere.segmentCount = 48
        let mat    = SCNMaterial()
        mat.lightingModel     = .physicallyBased
        mat.diffuse.contents  = UIColor(red: 1.0, green: 0.80, blue: 0.20, alpha: 1)
        mat.emission.contents = UIColor(red: 0.9, green: 0.55, blue: 0.00, alpha: 0.5)
        mat.metalness.contents = Float(0.1)
        mat.roughness.contents = Float(0.3)
        sphere.materials = [mat]
        let node = SCNNode(geometry: sphere)
        addRotation(to: node, dimension: .temperature)
        scene.rootNode.addChildNode(node)

        // Warm point light pulsing
        let light       = SCNLight(); light.type = .omni
        light.color     = UIColor(red: 1.0, green: 0.78, blue: 0.4, alpha: 1)
        light.intensity = 1000
        light.attenuationStartDistance = 0.5; light.attenuationEndDistance = 14
        let lNode       = SCNNode(); lNode.light = light
        lNode.position  = SCNVector3(0, 0, 2)
        let pulse       = CABasicAnimation(keyPath: "light.intensity")
        pulse.fromValue = 600; pulse.toValue = 1600
        pulse.duration  = 2.5; pulse.autoreverses = true; pulse.repeatCount = .infinity
        lNode.addAnimation(pulse, forKey: "pulse")
        scene.rootNode.addChildNode(lNode)
    }

    // MARK: Wind fallback — spinning torus compass

    private static func fallbackWind(_ data: WeatherWindDetail, into scene: SCNScene) {
        // Outer ring
        let torus = SCNTorus(ringRadius: 1.0, pipeRadius: 0.09)
        torus.ringSegmentCount = 48; torus.pipeSegmentCount = 16
        let mat   = SCNMaterial()
        mat.lightingModel     = .physicallyBased
        mat.diffuse.contents  = UIColor(red: 0.55, green: 0.92, blue: 0.88, alpha: 1)
        mat.metalness.contents = Float(0.6)
        mat.roughness.contents = Float(0.25)
        torus.materials = [mat]
        let ring = SCNNode(geometry: torus)
        ring.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)

        // Arrow inside the ring
        let cone = SCNCone(topRadius: 0, bottomRadius: 0.22, height: 0.55)
        let mat2 = SCNMaterial()
        mat2.lightingModel     = .physicallyBased
        mat2.diffuse.contents  = UIColor(red: 0.2, green: 0.85, blue: 0.75, alpha: 1)
        mat2.metalness.contents = Float(0.3)
        mat2.roughness.contents = Float(0.4)
        cone.materials = [mat2]
        let arrow = SCNNode(geometry: cone)
        arrow.position = SCNVector3(0, 0.7, 0)

        let group = SCNNode()
        group.addChildNode(ring)
        group.addChildNode(arrow)
        addRotation(to: group, dimension: .wind)
        scene.rootNode.addChildNode(group)
    }

    // MARK: Precipitation fallback — rain particles

    private static func fallbackPrecipitation(_ data: WeatherPrecipDetail, into scene: SCNScene) {
        let intensity = Float(max(data.probability, 15)) / 100.0
        let emitter   = SCNNode()
        emitter.name  = SceneNode.dimRain
        emitter.position = SCNVector3(0, 5, 2)
        emitter.addParticleSystem(ParticleController.makeSystem(for: .rain(intensity: intensity)))
        scene.rootNode.addChildNode(emitter)

        // Cloud sphere above
        let sphere = SCNSphere(radius: 1.1); sphere.segmentCount = 24
        let mat    = SCNMaterial()
        mat.lightingModel     = .physicallyBased
        mat.diffuse.contents  = UIColor(red: 0.55, green: 0.65, blue: 0.80, alpha: 1)
        mat.metalness.contents = Float(0.0)
        mat.roughness.contents = Float(0.8)
        sphere.materials = [mat]
        let node = SCNNode(geometry: sphere)
        node.position = SCNVector3(0, 0.5, 0)
        addRotation(to: node, dimension: .precipitation)
        scene.rootNode.addChildNode(node)
    }

    // MARK: Air quality fallback — AQI-coloured floating particles

    private static func fallbackAir(_ data: WeatherAirDetail, into scene: SCNScene) {
        let aqiColor = uiColor(forAQI: data.aqi)
        let count    = min(12 + data.aqi / 10, 30)
        for _ in 0..<count {
            let r    = CGFloat.random(in: 0.07...0.22)
            let sph  = SCNSphere(radius: r); sph.segmentCount = 10
            let mat  = SCNMaterial()
            mat.lightingModel     = .physicallyBased
            mat.diffuse.contents  = aqiColor.withAlphaComponent(CGFloat.random(in: 0.4...0.75))
            mat.emission.contents = aqiColor.withAlphaComponent(0.18)
            mat.metalness.contents = Float(0.2)
            mat.roughness.contents = Float(0.5)
            sph.materials = [mat]
            let node = SCNNode(geometry: sph)
            node.position = SCNVector3(
                Float.random(in: -2.8...2.8),
                Float.random(in: -2.0...2.0),
                Float.random(in: -2.5...0)
            )
            let flt           = CABasicAnimation(keyPath: "position.y")
            flt.fromValue     = node.position.y - Float.random(in: 0.3...0.85)
            flt.toValue       = node.position.y + Float.random(in: 0.3...0.85)
            flt.duration      = Double.random(in: 1.4...3.6)
            flt.autoreverses  = true; flt.repeatCount = .infinity
            flt.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            node.addAnimation(flt, forKey: "float")
            scene.rootNode.addChildNode(node)
        }
    }

    // MARK: - AQI colour mapping

    static func uiColor(forAQI aqi: Int) -> UIColor {
        switch aqi {
        case ..<51:  return UIColor(red: 0.00, green: 0.88, blue: 0.44, alpha: 1)
        case ..<101: return UIColor(red: 1.00, green: 0.85, blue: 0.00, alpha: 1)
        case ..<151: return UIColor(red: 1.00, green: 0.55, blue: 0.00, alpha: 1)
        case ..<201: return UIColor(red: 1.00, green: 0.22, blue: 0.22, alpha: 1)
        default:     return UIColor(red: 0.58, green: 0.00, blue: 0.50, alpha: 1)
        }
    }
}
