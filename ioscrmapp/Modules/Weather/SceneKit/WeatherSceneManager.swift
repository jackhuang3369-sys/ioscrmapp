import SceneKit
import UIKit

// MARK: - WeatherSceneManager
//
// Page A 的场景驱动器。
//
// 主路径：加载 normal_main.dae（Not Boring Weather 原始主场景），其中包含：
//   • cameraContainer / camera   — 已定位好的摄像机（Z=30, Y=1.2）
//   • ambient / directional      — 光源
//   • plane-day / plane-night    — 日 / 夜背景面板
//   • rotatingContent            — 空容器，天气模型注入到此处
//
// 从 normal_models.dae 克隆对应天气节点，保留其 DAE 原始位置（sun/moon Y=8），
// 插入 rotatingContent，由 WeatherSceneView 的 Coordinator 旋转此容器。
//
// 后备路径：若 DAE 加载失败，使用程序化球体场景。

final class WeatherSceneManager: ObservableObject {

    // MARK: Public

    private(set) var scene: SCNScene
    private(set) var condition: WeatherCondition
    private(set) var isNight: Bool

    /// 由 WeatherSceneView 旋转的节点（= rotatingContent 或后备 group）
    private(set) var conditionGroup: SCNNode?
    private(set) var restTiltX: Float = 0.0
    private(set) var currentTemperature: Int = MockWeatherData.current.temperature

    // MARK: Private

    private var planeDay:    SCNNode?
    private var planeNight:  SCNNode?
    private var ambientNode: SCNNode?
    private var keyNode:     SCNNode?
    private var cameraContainer: SCNNode?
    private var cameraNode: SCNNode?
    private var thunderNode: SCNNode!
    private var usingMainScene = false
    /// 数字显示组（主 scene 的固定子节点，不随天气模型旋转）
    private var displayGroup: SCNNode?

    // OBJ 模型缓存（按文件名键）
    private static var _objNodeCache: [String: SCNNode] = [:]

    // 模型库（normal_models.dae），整个会话只解析一次
    private static var _modelsCache: SCNScene?
    private static var modelsScene: SCNScene? {
        if _modelsCache == nil {
            if let url = Bundle.main.url(
                forResource: "normal_models", withExtension: "dae",
                subdirectory: "WeatherData/Scenes"
            ) {
                _modelsCache = try? SCNScene(url: url, options: [.checkConsistency: false])
            }
        }
        return _modelsCache
    }

    // MARK: Init

    init(
        condition: WeatherCondition = MockWeatherData.current.condition,
        isNight: Bool               = MockWeatherData.current.isNight
    ) {
        self.condition = condition
        self.isNight   = isNight
        self.scene     = SCNScene()  // 占位，下面立即替换

        if let mainScene = Self.loadMainScene() {
            buildWithMainScene(mainScene)
        } else {
            buildFallbackScene()
        }
    }

    // MARK: Public API

    func setCondition(_ newCondition: WeatherCondition, animated: Bool) {
        condition = newCondition
        if usingMainScene {
            injectModels(animated: animated)
        } else {
            applyFallbackCondition(animated: animated)
        }
    }

    func setNightMode(_ night: Bool, animated: Bool) {
        isNight = night
        if usingMainScene {
            applyDayNight(animated: animated)
            injectModels(animated: animated)
        } else {
            applyFallbackCondition(animated: animated)
            applyFallbackNightMode(animated: animated)
        }
        updateDisplayModel(animated: animated)
    }

    func setTemperature(_ temperature: Int, animated: Bool) {
        currentTemperature = temperature
        updateDisplayModel(animated: animated)
    }

    /// 将数字显示组的旋转角度同步到与天气模型相同，让数字和天气看起来是一体的
    func syncDisplayGroupRotation(to angles: SCNVector3) {
        displayGroup?.eulerAngles = angles
    }

    // MARK: - 主场景路径

    private static func loadMainScene() -> SCNScene? {
        guard let url = Bundle.main.url(
            forResource: "normal_main", withExtension: "dae",
            subdirectory: "WeatherData/Scenes"
        ) else { return nil }
        return try? SCNScene(url: url, options: [.checkConsistency: false])
    }

    private func buildWithMainScene(_ main: SCNScene) {
        // 场景背景透明，由 plane-day/plane-night 几何体提供视觉背景
        main.background.contents = UIColor.clear
        self.scene          = main
        self.usingMainScene = true

        conditionGroup = main.rootNode.childNode(withName: "rotatingContent", recursively: true)
        planeDay       = nil
        planeNight     = nil
        ambientNode    = main.rootNode.childNode(withName: "ambient",         recursively: true)
        keyNode        = main.rootNode.childNode(withName: "directional",     recursively: true)
        cameraContainer = main.rootNode.childNode(withName: "cameraContainer", recursively: true)
        cameraNode      = main.rootNode.childNode(withName: "camera",          recursively: true)

        main.rootNode.enumerateChildNodes { node, _ in
            guard let name = node.name else { return }
            if name == "plane-day" || name == "plane-night" {
                node.removeFromParentNode()
            }
        }

        configureMainScenePresentation()

        // 闪电光（NTW DAE 中没有，手动添加）
        let tLight           = SCNLight()
        tLight.type          = .omni
        tLight.color         = UIColor(red: 0.88, green: 0.92, blue: 1.0, alpha: 1)
        tLight.intensity     = 0
        tLight.attenuationStartDistance = 2
        tLight.attenuationEndDistance   = 35
        let tNode            = SCNNode()
        tNode.light          = tLight
        tNode.position       = SCNVector3(0, 12, 5)
        main.rootNode.addChildNode(tNode)
        self.thunderNode = tNode

        applyDayNight(animated: false)
        injectModels(animated: false)
        setupDisplayGroup(in: self.scene)
        updateDisplayModel(animated: false)
    }

    // MARK: - 日夜切换

    private func applyDayNight(animated: Bool) {
        let dur: CFTimeInterval = animated ? 0.8 : 0
        SCNTransaction.begin()
        SCNTransaction.animationDuration = dur
        planeDay?.isHidden    = true
        planeNight?.isHidden  = true
        planeDay?.opacity     = 0
        planeNight?.opacity   = 0
        // 降低环境光、提高定向光对比，让 OBJ 模型有更明显的明暗渐变
        ambientNode?.light?.intensity = isNight ? 80  : 160
        keyNode?.light?.intensity     = isNight ? 220 : 1100
        ambientNode?.light?.color = isNight
            ? UIColor(red: 0.30, green: 0.36, blue: 0.62, alpha: 1)
            : UIColor(red: 0.68, green: 0.72, blue: 0.88, alpha: 1)
        keyNode?.light?.color = isNight
            ? UIColor(red: 0.72, green: 0.82, blue: 1.0, alpha: 1)
            : UIColor(red: 1.0, green: 0.92, blue: 0.80, alpha: 1)
        SCNTransaction.commit()
    }

    // MARK: - 模型注入

    private let knownWeatherNames: Set<String> = [
        "sun", "moon",
        "cloud-day", "cloud-night", "cloud-wisp-day", "cloud-wisp-night",
        "precip-day", "precip-night",
        "fog-day", "fog-night",
        "air-day", "air-night",
        "partly-cloudy-custom"
    ]

    // MARK: - OBJ 模型名称映射

    /// 根据当前天气状态返回对应的 Blender OBJ 文件名
    private func objFileName() -> String {
        switch condition {
        case .clear:        return isNight ? "night0"  : "day0"
        case .partlyCloudy: return isNight ? "night1"  : "day1"
        case .cloudy:       return isNight ? "night2"  : "cloudly1"
        case .drizzle:      return isNight ? "night5"  : "day5"
        case .rain:         return isNight ? "night7"  : "day7"
        case .snow:         return isNight ? "night9"  : "snow1"
        case .thunderstorm: return isNight ? "night8"  : "day8"
        case .fog:          return isNight ? "night12" : "day12"
        }
    }

    /// 从 WeatherData/OBJ/ 加载 OBJ，归一化到 3.5 最大边长、中心在原点，缓存后返回克隆体
    private func loadOBJNode(named name: String) -> SCNNode? {
        // 命中缓存直接返回克隆
        if let cached = Self._objNodeCache[name] {
            return cached.clone()
        }
        guard let url = Bundle.main.url(forResource: name, withExtension: "obj",
                                         subdirectory: "WeatherData/OBJ") else { return nil }
        guard let objScene = try? SCNScene(url: url, options: [
            SCNSceneSource.LoadingOption.createNormalsIfAbsent: true
        ]) else { return nil }

        // 收集所有子节点到 wrapper
        let wrapper = SCNNode()
        wrapper.name = name
        for child in objScene.rootNode.childNodes {
            wrapper.addChildNode(child.clone())
        }

        // 应用颜色/材质
        applyOBJMaterialStyling(to: wrapper)

        // 计算包围盒，归一化到 3.5 单位最大边长并居中
        let bbox   = wrapper.boundingBox
        let minB   = bbox.min
        let maxB   = bbox.max
        let dimMax = max(maxB.x - minB.x, max(maxB.y - minB.y, maxB.z - minB.z))
        let normScale = Float(dimMax > 0 ? 3.5 / dimMax : 1.0)
        let cx = (minB.x + maxB.x) / 2
        let cy = (minB.y + maxB.y) / 2
        let cz = (minB.z + maxB.z) / 2
        wrapper.position = SCNVector3(-cx, -cy, -cz)
        wrapper.scale    = SCNVector3(normScale, normScale, normScale)

        let root = SCNNode()
        root.name = "obj-\(name)"
        root.addChildNode(wrapper)

        Self._objNodeCache[name] = root
        return root.clone()
    }

    /// 按材质名称给 OBJ 模型上色，使其接近 Blender 预览图效果
    private func applyOBJMaterialStyling(to node: SCNNode) {
        node.enumerateChildNodes { child, _ in
            guard let geo = child.geometry else { return }
            for mat in geo.materials {
                mat.lightingModel  = .physicallyBased
                mat.roughness.contents = Float(0.40)
                mat.metalness.contents = Float(0.05)
                switch mat.name {
                case "glossy_soundcloud":          // 太阳球体
                    mat.diffuse.contents   = UIColor(red: 1.00, green: 0.68, blue: 0.14, alpha: 1)
                    mat.roughness.contents = Float(0.12)
                    mat.emission.contents  = UIColor(red: 0.55, green: 0.22, blue: 0.0,  alpha: 0.55)
                case "glossy_cloud":                // 白云 — 低粗糙度让光照有高光，云体更立体
                    mat.diffuse.contents   = UIColor(red: 0.90, green: 0.94, blue: 1.00, alpha: 1)
                    mat.roughness.contents = Float(0.20)
                    mat.metalness.contents = Float(0.04)
                case "moon":                        // 月亮（大）
                    mat.diffuse.contents   = UIColor(red: 0.84, green: 0.92, blue: 1.00, alpha: 1)
                    mat.roughness.contents = Float(0.25)
                    mat.metalness.contents = Float(0.10)
                    mat.emission.contents  = UIColor(red: 0.10, green: 0.18, blue: 0.55, alpha: 0.30)
                case "moon_kecil":                  // 月亮（小）
                    mat.diffuse.contents   = UIColor(red: 0.72, green: 0.84, blue: 1.00, alpha: 1)
                    mat.roughness.contents = Float(0.30)
                case "lightning":                   // 闪电
                    mat.diffuse.contents   = UIColor(red: 1.00, green: 0.78, blue: 0.10, alpha: 1)
                    mat.roughness.contents = Float(0.10)
                    mat.emission.contents  = UIColor(red: 0.80, green: 0.46, blue: 0.0,  alpha: 0.90)
                case "Crystal":                     // 雨滴（水晶）
                    mat.diffuse.contents   = UIColor(red: 0.52, green: 0.80, blue: 1.00, alpha: 0.85)
                    mat.roughness.contents = Float(0.08)
                    mat.isDoubleSided      = true
                case "blue_glass":                  // 雨滴（透明蓝）
                    mat.diffuse.contents   = UIColor(red: 0.35, green: 0.65, blue: 1.00, alpha: 0.72)
                    mat.roughness.contents = Float(0.10)
                    mat.isDoubleSided      = true
                case "snow":                        // 雪花
                    mat.diffuse.contents   = UIColor(red: 0.88, green: 0.96, blue: 1.00, alpha: 1)
                    mat.roughness.contents = Float(0.20)
                    mat.emission.contents  = UIColor(red: 0.18, green: 0.42, blue: 0.88, alpha: 0.25)
                case "hurricane":                   // 风暴/雾旋
                    mat.diffuse.contents   = UIColor(white: 0.74, alpha: 1)
                    mat.roughness.contents = Float(0.62)
                default:
                    mat.diffuse.contents   = UIColor(white: 0.86, alpha: 1)
                }
            }
        }
    }

    private func nodeNamesForCurrentState() -> [String] {
        switch condition {
        case .clear:        return [isNight ? "moon" : "sun"]
        case .partlyCloudy: return [isNight ? "cloud-night" : "cloud-day",
                                    isNight ? "cloud-wisp-night" : "cloud-wisp-day"]
        case .cloudy:       return [isNight ? "cloud-night" : "cloud-day",
                                    isNight ? "cloud-wisp-night" : "cloud-wisp-day"]
        case .drizzle,
             .rain:         return [isNight ? "precip-night" : "precip-day"]
        case .snow:         return [isNight ? "cloud-night"  : "cloud-day"]
        case .thunderstorm: return [isNight ? "cloud-night"  : "cloud-day"]
        case .fog:          return [isNight ? "fog-night"    : "fog-day"]
        }
    }

    private func injectModels(animated: Bool) {
        guard let container = conditionGroup else { return }

        stopThunder()
        ParticleController.detach(from: scene)
        scene.fogStartDistance = 100
        scene.fogEndDistance   = 200

        // 移除旧天气节点（含 OBJ 节点名前缀 "obj-"）
        container.childNodes
            .filter { knownWeatherNames.contains($0.name ?? "") || ($0.name?.hasPrefix("obj-") == true) }
            .forEach { $0.removeFromParentNode() }

        // 优先使用 OBJ 模型；OBJ 加载失败时回退到 DAE 模型
        if let objNode = loadOBJNode(named: objFileName()) {
            container.addChildNode(objNode)
        } else if condition == .partlyCloudy {
            let cluster = makePartlyCloudyCluster()
            container.addChildNode(cluster)
        } else if let models = Self.modelsScene {
            for name in nodeNamesForCurrentState() {
                if let src = models.rootNode.childNode(withName: name, recursively: true) {
                    container.addChildNode(src.clone())
                }
            }
        } else {
            let fb = makeFallbackSphere(named: isNight ? "moon" : "sun")
            fb.position = SCNVector3(0, 8, 0)
            container.addChildNode(fb)
        }

        applyPresentationTuning(to: container)

        // 粒子 / 雾 / 闪电
        switch condition {
        case .drizzle:
            ParticleController.attach(.rain(intensity: 0.35), to: scene)
            repositionParticleEmitter(y: 18)
        case .rain:
            ParticleController.attach(.rain(intensity: 0.85), to: scene)
            repositionParticleEmitter(y: 18)
        case .snow:
            ParticleController.attach(.snow, to: scene)
            repositionParticleEmitter(y: 18)
        case .thunderstorm:
            ParticleController.attach(.rain(intensity: 1.4), to: scene)
            repositionParticleEmitter(y: 18)
            startThunder()
        case .fog:
            // 主场景摄像机 Z=31.5，物体在 Z≈0，距离约 31.5。原 fogEnd=22 会让所有物体 100% 雾化
            // 现在调远：物体处于雾化起点刚过，仅呈现轻薄薄雾效果
            scene.fogStartDistance   = 25
            scene.fogEndDistance     = 55
            scene.fogColor           = UIColor(white: 0.80, alpha: 1)
            scene.fogDensityExponent = 0.35
        default:
            break
        }

        if animated {
            container.opacity = 0
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.45
            container.opacity = 1
            SCNTransaction.commit()
        }
    }

    private func repositionParticleEmitter(y: Float) {
        scene.rootNode
            .childNode(withName: SceneNode.precipitation, recursively: false)?
            .position = SCNVector3(0, y, 0)
    }

    /// 为节点添加轻柔浮动动画（±0.1 单位，4.8 秒周期）
    private func attachFloat(to node: SCNNode) {
        let base           = node.position.y
        let bob            = CABasicAnimation(keyPath: "position.y")
        bob.fromValue      = base - 0.1
        bob.toValue        = base + 0.1
        bob.duration       = 4.8
        bob.autoreverses   = true
        bob.repeatCount    = .infinity
        bob.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        node.addAnimation(bob, forKey: "float")
    }

    // MARK: - 后备场景（normal_main.dae 加载失败时）

    private func buildFallbackScene() {
        scene.background.contents = UIColor.clear
        usingMainScene = false
        setupFallbackCamera()
        setupFallbackLighting()
        setupFallbackThunder()
        applyFallbackCondition(animated: false)
        setupDisplayGroup(in: scene)
        updateDisplayModel(animated: false)
    }

    private func setupFallbackCamera() {
        let cam = SCNCamera(); cam.fieldOfView = 52; cam.zNear = 0.1; cam.zFar = 100
        let node = SCNNode(); node.camera = cam
        // 摄像机正对模型，平视（不仰视）
        node.position = SCNVector3(0, 0.5, 8.5)
        node.look(at: SCNVector3(0, 0.5, 0))
        scene.rootNode.addChildNode(node)
        cameraNode = node
    }

    private func setupFallbackLighting() {
        let ambient = SCNLight(); ambient.type = .ambient
        ambient.color = UIColor(red: 0.55, green: 0.60, blue: 0.75, alpha: 1)
        ambient.intensity = 500
        ambientNode = SCNNode(); ambientNode!.light = ambient
        scene.rootNode.addChildNode(ambientNode!)

        let key = SCNLight(); key.type = .directional
        key.color = UIColor(red: 1.0, green: 0.95, blue: 0.88, alpha: 1); key.intensity = 1000
        keyNode = SCNNode(); keyNode!.light = key
        keyNode!.eulerAngles = SCNVector3(-0.5, 0.60, 0)
        scene.rootNode.addChildNode(keyNode!)

        let rim = SCNLight(); rim.type = .directional
        rim.color = UIColor(red: 0.38, green: 0.62, blue: 1.0, alpha: 1); rim.intensity = 380
        let rimNode = SCNNode(); rimNode.light = rim
        rimNode.eulerAngles = SCNVector3(0.4, Float.pi - 0.5, 0)
        scene.rootNode.addChildNode(rimNode)

        scene.lightingEnvironment.contents  = UIColor(red: 0.38, green: 0.45, blue: 0.62, alpha: 1)
        scene.lightingEnvironment.intensity = 0.70
    }

    private func setupFallbackThunder() {
        let tLight = SCNLight(); tLight.type = .omni
        tLight.color = UIColor(red: 0.88, green: 0.92, blue: 1.0, alpha: 1); tLight.intensity = 0
        tLight.attenuationStartDistance = 1; tLight.attenuationEndDistance = 22
        thunderNode = SCNNode(); thunderNode.light = tLight
        thunderNode.position = SCNVector3(0, 3, 2)
        scene.rootNode.addChildNode(thunderNode)
    }

    private func applyFallbackCondition(animated: Bool) {
        stopThunder()
        ParticleController.detach(from: scene)
        scene.fogStartDistance = 100; scene.fogEndDistance = 200

        conditionGroup?.removeFromParentNode()
        let group = SCNNode(); group.name = "weather_model_group"

        // 优先使用 OBJ 模型；失败时回退程序化几何体
        if let objNode = loadOBJNode(named: objFileName()) {
            group.addChildNode(objNode)
        } else {
            let modelName: String
            switch condition {
            case .drizzle, .rain: modelName = isNight ? "precip-night" : "precip-day"
            case .fog:            modelName = isNight ? "fog-night"    : "fog-day"
            case .clear:          modelName = isNight ? "moon"         : "sun"
            default:              modelName = isNight ? "cloud-night"  : "cloud-day"
            }
            let sphere = makeFallbackSphere(named: modelName)
            group.addChildNode(sphere)
        }

        // ⚠️ 必须先 applyPresentationTuning 设好最终位置，再 attachFloat；
        // 反序时 attachFloat 会以临时值(1.2)为 base，CAAnimation 覆盖 presentation
        // layer，使 applyPresentationTuning 对视觉位置完全无效。
        applyPresentationTuning(to: group)          // 设 position / scale / tilt（无动画，0s）
        attachFloat(to: group)                       // 读取已正确设好的 position.y 为 base

        if animated {
            group.opacity = 0
            SCNTransaction.begin(); SCNTransaction.animationDuration = 0.45
            group.opacity = 1; SCNTransaction.commit()
        }
        scene.rootNode.addChildNode(group)
        conditionGroup = group

        switch condition {
        case .drizzle:      ParticleController.attach(.rain(intensity: 0.35), to: scene)
        case .rain:         ParticleController.attach(.rain(intensity: 0.85), to: scene)
        case .snow:         ParticleController.attach(.snow, to: scene)
        case .thunderstorm: ParticleController.attach(.rain(intensity: 1.4),  to: scene); startThunder()
        case .fog:
            // 后备摄像机 Z=8.5，物体在 Z≈0，距离约 8.5。原 fogEnd=9 会让物体 94% 雾化
            // 现在调远：让模型保持基本可见，仅背景有薄雾感
            scene.fogStartDistance = 6.5; scene.fogEndDistance = 20
            scene.fogColor = UIColor(white: 0.78, alpha: 1)
        default: break
        }
    }

    /// 返回单个球体 fallback 节点（仅用于 sun/moon/precip），云类改用 makeFallbackCloud
    private func makeFallbackSphere(named name: String) -> SCNNode {
        switch name {
        case "sun":
            return makeFallbackSun(night: false)
        case "moon":
            return makeFallbackSun(night: true)
        case "precip-day", "precip-night":
            let sphere = SCNSphere(radius: 1.65); sphere.segmentCount = 72
            let mat = SCNMaterial(); mat.lightingModel = .physicallyBased
            mat.diffuse.contents   = UIColor(red: 0.26, green: 0.58, blue: 0.92, alpha: 1)
            mat.metalness.contents = Float(0.05)
            mat.roughness.contents = Float(0.40)
            sphere.materials = [mat]
            let node = SCNNode(geometry: sphere); node.name = name
            return node
        default:
            // 云类：多球体构成可识别的云形
            return makeFallbackCloud(name: name)
        }
    }

    /// 太阳/月亮：鲜明颜色 + 自发光光晕，让用户一眼识别
    private func makeFallbackSun(night: Bool) -> SCNNode {
        let root = SCNNode()
        root.name = night ? "moon" : "sun"

        let sphere = SCNSphere(radius: 1.55); sphere.segmentCount = 72
        let mat = SCNMaterial(); mat.lightingModel = .physicallyBased
        if night {
            mat.diffuse.contents   = UIColor(red: 0.82, green: 0.90, blue: 1.0, alpha: 1)
            mat.metalness.contents = Float(0.18)
            mat.roughness.contents = Float(0.22)
            mat.emission.contents  = UIColor(red: 0.20, green: 0.28, blue: 0.55, alpha: 0.55)
        } else {
            mat.diffuse.contents   = UIColor(red: 1.0,  green: 0.72, blue: 0.20, alpha: 1)
            mat.metalness.contents = Float(0.0)
            mat.roughness.contents = Float(0.10)
            mat.emission.contents  = UIColor(red: 0.95, green: 0.45, blue: 0.02, alpha: 0.70)
        }
        sphere.materials = [mat]
        let body = SCNNode(geometry: sphere)
        root.addChildNode(body)

        // 点光源增强发光感
        let glow = SCNLight(); glow.type = .omni
        glow.color = night
            ? UIColor(red: 0.60, green: 0.72, blue: 1.0, alpha: 1)
            : UIColor(red: 1.0, green: 0.82, blue: 0.30, alpha: 1)
        glow.intensity = night ? 600 : 1100
        glow.attenuationStartDistance = 0; glow.attenuationEndDistance = 12
        let glowNode = SCNNode(); glowNode.light = glow
        root.addChildNode(glowNode)

        // 脉冲动画给发光感
        let pulse = CABasicAnimation(keyPath: "light.intensity")
        pulse.fromValue = glow.intensity * 0.7
        pulse.toValue   = glow.intensity * 1.3
        pulse.duration  = 2.8; pulse.autoreverses = true; pulse.repeatCount = .infinity
        glowNode.addAnimation(pulse, forKey: "glow_pulse")

        return root
    }

    /// 云：由多个大小不同的球体拼成可识别云形
    private func makeFallbackCloud(name: String) -> SCNNode {
        let root = SCNNode(); root.name = name
        let isNightCloud = name.contains("night")

        let cloudColor = isNightCloud
            ? UIColor(red: 0.55, green: 0.62, blue: 0.80, alpha: 1)
            : UIColor(red: 0.88, green: 0.92, blue: 0.98, alpha: 1)

        // 各球体：(位置x, y, 半径) — 适当缩小，不遮挡整个屏幕
        let blobs: [(Float, Float, Float)] = [
            (0.0,   0.0,  0.78),
            (-0.88, -0.2, 0.58),
            (0.88,  -0.2, 0.58),
            (-0.50,  0.4, 0.50),
            (0.50,   0.3, 0.48),
            (-1.35, -0.38, 0.40),
            (1.35,  -0.38, 0.38),
        ]
        for (x, y, r) in blobs {
            let sphere = SCNSphere(radius: CGFloat(r)); sphere.segmentCount = 32
            let mat = SCNMaterial(); mat.lightingModel = .physicallyBased
            mat.diffuse.contents   = cloudColor
            mat.metalness.contents = Float(0.0)
            mat.roughness.contents = Float(0.72)
            sphere.materials = [mat]
            let node = SCNNode(geometry: sphere)
            node.position = SCNVector3(x, y, 0)
            root.addChildNode(node)
        }
        return root
    }

    private func configureMainScenePresentation() {
        scene.lightingEnvironment.contents = UIColor(red: 0.48, green: 0.58, blue: 0.82, alpha: 1)
        scene.lightingEnvironment.intensity = 0.4   // 降低 IBL 填充光，增强方向光塑形感
        scene.fogColor = UIColor.clear

        // 摄像机平视，不仰视
        cameraContainer?.position = SCNVector3(0, 0, 31.5)
        cameraNode?.position = SCNVector3(0, 0, 0)
        cameraNode?.eulerAngles = SCNVector3(0, 0, 0)
        cameraNode?.camera?.fieldOfView = 27
        cameraNode?.camera?.zNear = 0.1
        cameraNode?.camera?.zFar = 140
        cameraNode?.camera?.wantsHDR = true

        conditionGroup?.position = SCNVector3(0, 0, 0)
    }

    // MARK: - 数字显示组（直接挂在主场景根节点，不随 conditionGroup 旋转）

    private func setupDisplayGroup(in targetScene: SCNScene) {
        displayGroup?.removeFromParentNode()
        let g = SCNNode()
        g.name = "display-group"
        // 主场景：camera center Y=0，Y=0.0 → 屏幕 50% 处（文字居中偏下）
        // 后备场景：camera center Y=0.5，Y=-0.1 → 屏幕中偏下，避免遮挡底部面板
        g.position = SCNVector3(0, usingMainScene ? 0.0 : -0.1, 0)
        targetScene.rootNode.addChildNode(g)
        displayGroup = g
    }

    private func updateDisplayModel(animated: Bool) {
        guard let g = displayGroup else { return }
        g.childNodes.forEach { $0.removeFromParentNode() }

        // 字体设置：加粗，主场景稍缩避免与模型重叠
        let fontSize: CGFloat = usingMainScene ? 4.5 : 2.2
        let depth: CGFloat    = usingMainScene ? 0.50 : 0.30
        let textGeo = SCNText(string: "\(currentTemperature)", extrusionDepth: depth)
        textGeo.flatness = 0.06
        textGeo.font = UIFont(
            descriptor: UIFontDescriptor.preferredFontDescriptor(withTextStyle: .largeTitle)
                .withSymbolicTraits(.traitBold) ?? UIFontDescriptor(),
            size: fontSize
        )
        textGeo.chamferRadius = depth * 0.12

        // 正面：冰白色 + 自发光，确保在任何光照下都清晰可见
        let front = SCNMaterial()
        front.lightingModel  = .physicallyBased
        front.diffuse.contents   = UIColor(red: 0.96, green: 0.97, blue: 1.00, alpha: 1)
        front.roughness.contents = Float(0.16)
        front.metalness.contents = Float(0.14)
        front.emission.contents  = UIColor(red: 0.72, green: 0.78, blue: 0.95, alpha: 0.60)
        // 侧面：浅蓝灰 + 轻微自发光，冰晶深度感
        let side = SCNMaterial()
        side.lightingModel  = .physicallyBased
        side.diffuse.contents   = UIColor(red: 0.58, green: 0.74, blue: 0.96, alpha: 1)
        side.roughness.contents = Float(0.28)
        side.metalness.contents = Float(0.20)
        side.emission.contents  = UIColor(red: 0.28, green: 0.44, blue: 0.78, alpha: 0.45)
        textGeo.materials = [front, side]

        let textNode = SCNNode(geometry: textGeo)
        // 居中
        let (mn, mx) = textNode.boundingBox
        textNode.pivot = SCNMatrix4MakeTranslation(
            (mn.x + mx.x) * 0.5,
            (mn.y + mx.y) * 0.5,
            mn.z
        )
        textNode.eulerAngles.x = 0
        textNode.castsShadow = false
        g.addChildNode(textNode)

        if animated {
            g.opacity = 0
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.35
            g.opacity = 1
            SCNTransaction.commit()
        }
    }

    private func applyPresentationTuning(to container: SCNNode) {
        let tuning = presentationTuning()
        // 初始放置用 0 动画时长（避免与 attachFloat 产生冲突）；
        // 条件切换（animated=true）时 injectModels 有淡入保护，无需位置动画。
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0
        container.position = tuning.position
        container.scale    = SCNVector3(tuning.scale, tuning.scale, tuning.scale)
        container.eulerAngles.x = tuning.restTilt
        restTiltX = tuning.restTilt
        SCNTransaction.commit()
    }

    /// OBJ 模型已归一化到 3.5 单位最大边长、居中于原点。
    /// 主场景（cam Z=31.5, FOV=27°）可视宽≈7 单位；
    /// 后备场景（cam Z=8.5,  FOV=52°）可视宽≈3.8 单位（宽高比 9:19.5）。
    /// sm = scale base，pm = positionY base
    private func presentationTuning() -> PresentationTuning {
        let sm: Float = usingMainScene ? 1.28 : 0.70
        // pm：模型中心 Y 基准值（所有天气统一，消除大小/高低不一致感）
        // 主场景  cam Z=31.5 FOV=27°，可视高≈15.1 单位，pm=6.0 → 屏幕上方 ~20%
        // 后备场景 cam Z=8.5  FOV=52°，可视高≈8.3 单位，pm=3.0 → 屏幕上方 ~20%
        let pm: Float = usingMainScene ? 6.0 : 3.0
        // pz：模型 Z 轴后退，与文字深度对齐
        let pz: Float = usingMainScene ? -1.5 : -0.8

        switch condition {
        case .clear:
            return PresentationTuning(
                position: SCNVector3(0, pm, pz),
                scale: sm,
                restTilt: -0.05
            )
        case .partlyCloudy:
            return PresentationTuning(
                position: SCNVector3(0, pm, pz),
                scale: sm,
                restTilt: -0.04
            )
        case .cloudy:
            return PresentationTuning(
                position: SCNVector3(0, pm, pz),
                scale: sm,
                restTilt: -0.04
            )
        case .drizzle:
            return PresentationTuning(
                position: SCNVector3(0, pm, pz),
                scale: sm,
                restTilt: -0.04
            )
        case .rain:
            return PresentationTuning(
                position: SCNVector3(0, pm, pz),
                scale: sm,
                restTilt: -0.04
            )
        case .snow:
            return PresentationTuning(
                position: SCNVector3(0, pm, pz),
                scale: sm,
                restTilt: -0.04
            )
        case .thunderstorm:
            return PresentationTuning(
                position: SCNVector3(0, pm, pz),
                scale: sm,
                restTilt: -0.03
            )
        case .fog:
            return PresentationTuning(
                position: SCNVector3(0, pm, pz),
                scale: sm,
                restTilt: -0.02
            )
        }
    }

    private struct PresentationTuning {
        let position:  SCNVector3
        let scale:     Float
        let restTilt:  Float
    }

    private func makePartlyCloudyCluster() -> SCNNode {
        let root = SCNNode()
        root.name = "partly-cloudy-custom"

        if let models = Self.modelsScene {
            if let sun = models.rootNode.childNode(withName: isNight ? "moon" : "sun", recursively: true)?.clone() {
                sun.position = SCNVector3(isNight ? 1.3 : 1.15, isNight ? 2.65 : 2.45, -0.12)
                let factor: Float = isNight ? 0.34 : 0.30
                sun.scale = SCNVector3(sun.scale.x * factor, sun.scale.y * factor, sun.scale.z * factor)
                root.addChildNode(sun)
            }

            if let cloud = models.rootNode.childNode(withName: isNight ? "cloud-night" : "cloud-day", recursively: true)?.clone() {
                cloud.position = SCNVector3(-0.18, 1.22, 0.0)
                let factor: Float = 130.0
                cloud.scale = SCNVector3(cloud.scale.x * factor, cloud.scale.y * factor, cloud.scale.z * factor)
                root.addChildNode(cloud)
            }

            if let wisp = models.rootNode.childNode(withName: isNight ? "cloud-wisp-night" : "cloud-wisp-day", recursively: true)?.clone() {
                wisp.position = SCNVector3(0.62, 0.78, 0.06)
                let factor: Float = 112.0
                wisp.scale = SCNVector3(wisp.scale.x * factor, wisp.scale.y * factor, wisp.scale.z * factor)
                root.addChildNode(wisp)
            }
        }

        if root.childNodes.isEmpty {
            let fallbackSun = makeFallbackSphere(named: isNight ? "moon" : "sun")
            fallbackSun.position = SCNVector3(1.1, 2.45, -0.1)
            fallbackSun.scale = SCNVector3(0.56, 0.56, 0.56)
            root.addChildNode(fallbackSun)

            let fallbackCloud = makeFallbackSphere(named: isNight ? "cloud-night" : "cloud-day")
            fallbackCloud.position = SCNVector3(-0.12, 1.18, 0.02)
            fallbackCloud.scale = SCNVector3(1.2, 0.76, 0.88)
            root.addChildNode(fallbackCloud)
        }

        return root
    }

    private func applyFallbackNightMode(animated: Bool) {
        let dur: CFTimeInterval = animated ? 1.0 : 0
        SCNTransaction.begin(); SCNTransaction.animationDuration = dur
        ambientNode?.light?.intensity = isNight ? 220 : 500
        ambientNode?.light?.color = isNight
            ? UIColor(red: 0.30, green: 0.38, blue: 0.70, alpha: 1)
            : UIColor(red: 0.55, green: 0.60, blue: 0.75, alpha: 1)
        keyNode?.light?.intensity = isNight ? 250 : 1000
        SCNTransaction.commit()
    }

    // MARK: - 闪电

    private func startThunder() {
        let flash = SCNAction.sequence([
            SCNAction.run { $0.light?.intensity = 3200 },
            SCNAction.wait(duration: 0.07),
            SCNAction.run { $0.light?.intensity = 0    },
            SCNAction.wait(duration: 0.11),
            SCNAction.run { $0.light?.intensity = 2200 },
            SCNAction.wait(duration: 0.05),
            SCNAction.run { $0.light?.intensity = 0    },
            SCNAction.wait(duration: 5.0, withRange: 5.0),
        ])
        thunderNode.runAction(.repeatForever(flash), forKey: "thunder_loop")
    }

    private func stopThunder() {
        thunderNode?.removeAction(forKey: "thunder_loop")
        thunderNode?.light?.intensity = 0
    }
}
