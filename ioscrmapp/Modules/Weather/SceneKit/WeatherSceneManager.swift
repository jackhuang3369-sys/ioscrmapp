import SceneKit
import SwiftUI
import UIKit

enum WeatherSceneMode {
    case main
    case sunDetail
}

final class WeatherSceneManager: ObservableObject {

    @Published private(set) var displayGroupRotation: SCNVector3 = SCNVector3(0, 0, 0)
    private(set) var scene: SCNScene
    private(set) var conditionGroup: SCNNode?
    private(set) var sunNode: SCNNode?
    private(set) var restTiltX: Float = -0.012
    private(set) var autoSpinSpeed: Float = 0
    private(set) var currentTemperature: Int

    private let mode: WeatherSceneMode
    private var detailTitleNode: SCNNode?
    private var temperatureNode: SCNNode?
    private var isTemperatureHidden: Bool = false
    private var _birdsScene: SCNScene?   // 防止 ARC 过早释放鸟群场景
    private let weatherDataSubdirectory = "WeatherData"

    init(temperature: Int = MockWeatherData.today.temperature, mode: WeatherSceneMode = .main) {
        self.scene = SCNScene()
        self.currentTemperature = temperature
        self.mode = mode
        buildScene()
    }

    func setTemperature(_ temperature: Int, animated: Bool) {
        currentTemperature = temperature
        updateTemperature(animated: animated)
    }

    func setTemperatureVisibility(isHidden: Bool, animated: Bool) {
        isTemperatureHidden = isHidden
        guard let node = temperatureNode else { return }

        let targetOpacity: CGFloat = isHidden ? 0 : 1
        if animated {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.2
            node.opacity = targetOpacity
            SCNTransaction.commit()
        } else {
            node.opacity = targetOpacity
        }
    }

    func syncDisplayGroupRotation(to angles: SCNVector3) {
        displayGroupRotation = angles
    }

    private func buildScene() {
        scene.background.contents = UIColor.clear
        scene.rootNode.childNodes.forEach { $0.removeFromParentNode() }

        let isDetailMode = mode == .sunDetail
        restTiltX = isDetailMode ? -0.004 : -0.012
        autoSpinSpeed = 0

        let camera = SCNCamera()
        camera.fieldOfView = isDetailMode ? 24 : 31
        camera.zNear = 0.1
        camera.zFar = 120

        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = isDetailMode
            ? SCNVector3(0, 0.38, 18.8)
            : SCNVector3(0, 0.02, 20.8)
        scene.rootNode.addChildNode(cameraNode)

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = isDetailMode ? 1120 : 1000   // 提高环境光，防止暗部全黑
        ambient.color = UIColor(white: 0.85, alpha: 1)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        let key = SCNLight()
        key.type = .directional
        key.intensity = isDetailMode ? 1380 : 1200
        key.color = UIColor(red: 1.0, green: 0.96, blue: 0.90, alpha: 1)
        let keyNode = SCNNode()
        keyNode.light = key
        keyNode.eulerAngles = SCNVector3(-0.4, 0.55, 0)
        scene.rootNode.addChildNode(keyNode)

        let rim = SCNLight()
        rim.type = .directional
        rim.intensity = isDetailMode ? 520 : 420
        rim.color = UIColor(red: 0.92, green: 0.94, blue: 1.0, alpha: 1)
        let rimNode = SCNNode()
        rimNode.light = rim
        rimNode.eulerAngles = SCNVector3(0.35, -.pi + 0.3, 0)
        scene.rootNode.addChildNode(rimNode)

        // ── 右侧棱角补光：从摄像机右上方照射，照亮数字有棱角的右侧面 ──
        // 调整 intensity 控制强度，eulerAngles.y 控制左右方向（负值=来自右侧）
        let rightFill = SCNLight()
        rightFill.type = .directional
        rightFill.intensity = isDetailMode ? 840 : 700
        rightFill.color = UIColor(red: 0.95, green: 0.97, blue: 1.0, alpha: 1)
        let rightFillNode = SCNNode()
        rightFillNode.light = rightFill
        // Y=-0.6 ≈ 来自右前方约 34°，既补右侧面又不造成过度阴影
        rightFillNode.eulerAngles = SCNVector3(-0.2, -0.6, 0)
        scene.rootNode.addChildNode(rightFillNode)

        let root = SCNNode()
        root.name = "weather_root"
        root.position = isDetailMode
            ? SCNVector3(0, -0.42, 0)
            : SCNVector3(0, -1.94, 0)
        scene.rootNode.addChildNode(root)

        let rotatingGroup = SCNNode()
        rotatingGroup.name = "weather_rotating_group"
        root.addChildNode(rotatingGroup)
        conditionGroup = rotatingGroup

        let sun = makeSunNode()
        if isDetailMode {
            let sunAssembly = SCNNode()
            sunAssembly.name = "weather_sun_detail_assembly"
            sunAssembly.position = SCNVector3(0, -0.44, -0.1)

            sun.position = SCNVector3(0, 0, 0)
            sunAssembly.addChildNode(sun)
            rotatingGroup.addChildNode(sunAssembly)

            let title = makeSunDetailTitleNode(text: "Sun")
            title.position = SCNVector3(0, 2.9, 0.34)
            rotatingGroup.addChildNode(title)
            detailTitleNode = title

            sunNode = sunAssembly
        } else {
            // 太阳位置：Y 值向上调整，让太阳位于城市名下方、数字上方
            sun.position = SCNVector3(0, 3.8, -0.1)  // 原来 3.26 → 3.8（向上移动）
            rotatingGroup.addChildNode(sun)
            sunNode = sun
        }

        if mode == .main {
            let digits = makeTemperatureNode(text: "\(currentTemperature)")
            // 数字位置：Y 值调整后让数字位于太阳下方、屏幕垂直中心偏下
            digits.position = SCNVector3(0, -1.2, 0.12)  // 原来 -2.3 → -1.2（向上移动，更接近太阳）
            rotatingGroup.addChildNode(digits)
            temperatureNode = digits
        } else {
            temperatureNode = nil
        }

        attachFloatAnimation(to: root)
        attachSunPulse(to: sun)
        attachSunSpin(to: sun)
        if let detailTitleNode {
            attachSunSpin(to: detailTitleNode)
        }
    }

    private func makeSunNode() -> SCNNode {
        if let loadedSun = makeSunModelNode() {
            return loadedSun
        }

        return makeFallbackSunNode()
    }

    private func makeFallbackSunNode() -> SCNNode {
        let root = SCNNode()
        root.name = SceneNode.sun

        // 太阳规格：直径为屏幕宽度的 55-60%
        // 在 SceneKit 中，radius 2.4 对应约 58% 屏幕宽度（iPhone 15 Pro）
        let sphere = SCNSphere(radius: mode == .sunDetail ? 2.6 : 2.4)
        sphere.segmentCount = 100  // 提高细分度，让圆形更平滑

        // 生成颗粒噪波纹理
        let noiseImage = createGrainNoiseImage(size: 256)

        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        // 高饱和度红色 #FF2B2B 近似值
        material.diffuse.contents = UIColor(red: 1.0, green: 0.17, blue: 0.17, alpha: 0.98)
        material.emission.contents = UIColor(red: 0.85, green: 0.0, blue: 0.0, alpha: 0.28)
        material.roughness.contents = Float(0.72)  // 稍高粗糙度，营造磨砂质感
        material.metalness.contents = Float(0.0)
        material.transparency = 0.98
        material.blendMode = .alpha

        // 将噪波纹理应用到粗糙度，创造表面颗粒感
        if let noiseImage {
            material.roughness.contents = noiseImage
        }

        sphere.materials = [material]

        let body = SCNNode(geometry: sphere)
        body.name = SceneNode.sun
        root.addChildNode(body)

        let glow = SCNLight()
        glow.type = .omni
        glow.intensity = 820
        glow.color = UIColor(red: 1.0, green: 0.17, blue: 0.17, alpha: 1)
        glow.attenuationStartDistance = 0
        glow.attenuationEndDistance = 28

        let glowNode = SCNNode()
        glowNode.light = glow
        root.addChildNode(glowNode)

        return root
    }

    /// 创建颗粒噪波纹理（用于太阳表面磨砂质感）
    private func createGrainNoiseImage(size: Int) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { ctx in
            for _ in 0..<(size * size / 4) {
                let x = CGFloat.random(in: 0..<CGFloat(size))
                let y = CGFloat.random(in: 0..<CGFloat(size))
                let alpha = CGFloat.random(in: 0.08..<0.18)
                UIColor(white: CGFloat.random(in: 0.7...1.0), alpha: alpha).setFill()
                let rect = CGRect(x: x, y: y, width: 1.5, height: 1.5)
                ctx.fill(rect)
            }
        }
    }

    private func makeTemperatureNode(text: String) -> SCNNode {
        if let modelNode = makeTemperatureModelNode(text: text) {
            return modelNode
        }

        return makeFallbackTemperatureNode(text: text)
    }

    private func makeSunDetailTitleNode(text: String) -> SCNNode {
        let container = SCNNode()
        let frontTitle = makeSingleSunDetailTitleNode(text: text)
        frontTitle.position.z = 0
        container.addChildNode(frontTitle)

        container.eulerAngles = SCNVector3(0.02, -0.04, 0.01)
        container.castsShadow = false
        return container
    }

    private func makeSingleSunDetailTitleNode(text: String) -> SCNNode {
        let textGeometry = SCNText(string: text, extrusionDepth: 0.9)
        textGeometry.flatness = 0.06
        textGeometry.font = UIFont.systemFont(ofSize: 10.8, weight: .black)
        textGeometry.chamferRadius = 0.10

        let front = SCNMaterial()
        front.lightingModel = .physicallyBased
        front.diffuse.contents = UIColor(red: 0.16, green: 0.16, blue: 0.17, alpha: 1)
        front.metalness.contents = Float(0.52)
        front.roughness.contents = Float(0.24)
        front.specular.contents = UIColor(white: 0.98, alpha: 1)
        front.isDoubleSided = false

        let side = SCNMaterial()
        side.lightingModel = .physicallyBased
        side.diffuse.contents = UIColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1)
        side.metalness.contents = Float(0.84)
        side.roughness.contents = Float(0.20)
        side.isDoubleSided = false

        textGeometry.materials = [front, side, side, side, front]

        let node = SCNNode(geometry: textGeometry)
        let (minBounds, maxBounds) = node.boundingBox
        let width = maxBounds.x - minBounds.x
        let height = maxBounds.y - minBounds.y
        node.pivot = SCNMatrix4MakeTranslation(minBounds.x + width / 2, minBounds.y + height / 2, 0)
        node.scale = SCNVector3(0.16, 0.16, 0.16)
        return node
    }

    private func makeFallbackTemperatureNode(text: String) -> SCNNode {
        // 数字规格：高度为屏幕高度的 35-40%，3D 厚度为数字宽度的 15-20%
        // extrusionDepth 1.85 提供约 18% 的厚度比
        let textGeometry = SCNText(string: text, extrusionDepth: 1.85)
        textGeometry.flatness = 0.06  // 提高平滑度
        // 使用更粗的字体，System Ultra Thin 改为 Black
        textGeometry.font = UIFont.systemFont(ofSize: 10.5, weight: .black)
        textGeometry.chamferRadius = 0.18  // 增大倒角，让边缘更圆润

        let front = SCNMaterial()
        front.lightingModel = .physicallyBased
        front.diffuse.contents = UIColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1)
        front.metalness.contents = Float(0.45)
        front.roughness.contents = Float(0.28)
        front.specular.contents = UIColor(white: 0.92, alpha: 1)
        // 顶部红色反光效果：通过环境光遮蔽模拟
        front.ambient.contents = UIColor(red: 0.18, green: 0.0, blue: 0.0, alpha: 0.12)

        let side = SCNMaterial()
        side.lightingModel = .physicallyBased
        side.diffuse.contents = UIColor(red: 0.05, green: 0.05, blue: 0.06, alpha: 1)
        side.metalness.contents = Float(0.75)
        side.roughness.contents = Float(0.22)

        textGeometry.materials = [front, side, side, side, front]

        let node = SCNNode(geometry: textGeometry)
        node.name = SceneNode.temperature
        let (minBounds, maxBounds) = node.boundingBox
        let width = maxBounds.x - minBounds.x
        let height = maxBounds.y - minBounds.y
        node.pivot = SCNMatrix4MakeTranslation(minBounds.x + width / 2, minBounds.y + height / 2, 0)
        // scale 0.72 让数字高度达到约 38% 屏幕高度
        node.scale = SCNVector3(0.72, 0.72, 0.72)
        node.eulerAngles = SCNVector3(0.02, -0.05, 0.01)
        return node
    }

    private func makeSunModelNode() -> SCNNode? {
        let targetHeight: Float = mode == .sunDetail ? 4.72 : 4.02
        guard let payload = loadNormalizedModelNode(named: "sun", fileExtension: "obj", targetHeight: targetHeight) else {
            return nil
        }

        let root = SCNNode()
        root.name = SceneNode.sun
        let model = payload.node
        model.name = SceneNode.sun
        model.opacity = 0.97
        model.eulerAngles = SCNVector3(0.0, 0.08, 0.0)
        applySunMaterial(to: model)
        root.addChildNode(model)

        // 鸟群：作为太阳 root 的子节点，自动跟随太阳的一切动画（自旋、脉冲、浮动）
        // 太阳球半径 2.16，x=3.2 在球体右侧外沿，y=0.3 约在球体中部偏上
        if let birdsNode = loadBirdsNode() {
            birdsNode.position = mode == .sunDetail
                ? SCNVector3(-4.1, -0.55, 0)
                : SCNVector3(3.2, -0.8, 0)
            root.addChildNode(birdsNode)
        }

        let glow = SCNLight()
        glow.type = .omni
        glow.intensity = mode == .sunDetail ? 860 : 700
        glow.color = UIColor(red: 1.0, green: 0.44, blue: 0.28, alpha: 1)
        glow.attenuationStartDistance = 0
        glow.attenuationEndDistance = mode == .sunDetail ? 34 : 26

        let glowNode = SCNNode()
        glowNode.light = glow
        root.addChildNode(glowNode)

        return root
    }

    /// 加载鸟群节点（birds2.usdz）。
    private func loadBirdsNode() -> SCNNode? {
        let loadOpts: [SCNSceneSource.LoadingOption: Any] = [
            .animationImportPolicy: SCNSceneSource.AnimationImportPolicy.playRepeatedly
        ]
        guard let url = Bundle.main.url(forResource: "birds2", withExtension: "usdz",
                                        subdirectory: weatherDataSubdirectory),
              let src = SCNSceneSource(url: url, options: loadOpts),
              let loadedScene = src.scene(options: loadOpts),
              !loadedScene.rootNode.childNodes.isEmpty else {
            print("[Birds] ❌ birds2.usdz 加载失败")
            return nil
        }
        let animCount = src.identifiersOfEntries(withClass: CAAnimation.self).count
        print("[Birds] ✅ birds2.usdz  children=\(loadedScene.rootNode.childNodes.count)  CAAnims=\(animCount)")
        return makeBirdsContainer(from: loadedScene)
    }

    private func makeBirdsContainer(from loadedScene: SCNScene) -> SCNNode? {
        _birdsScene = loadedScene
        let container = SCNNode()
        container.name = SceneNode.birds

        // 不要直接复用其他 SCNScene 的 rootNode；把 child clone 到新容器里，
        // 否则在 addChildNode 时会触发“removing the root node of a scene”错误。
        let sourceNodes = loadedScene.rootNode.childNodes.isEmpty ? [loadedScene.rootNode] : loadedScene.rootNode.childNodes
        for node in sourceNodes {
            container.addChildNode(node.clone())
        }

        // 打印节点树（便于调试，找到界面中多余节点的名称）
        print("[Birds] --- node tree ---")
        printBirdsNodeTree(container, indent: "  ")

        // 移除球体：按名称关键字过滤
        removeBallNodes(from: container)

        let (bmin, bmax) = container.boundingBox
        let xSpan = bmax.x - bmin.x
        guard xSpan > 0.001 else { return nil }
        let cx = (bmin.x + bmax.x) / 2
        let cy = (bmin.y + bmax.y) / 2
        let cz = (bmin.z + bmax.z) / 2
        container.pivot = SCNMatrix4MakeTranslation(cx, cy, cz)
        let targetWidth: Float = mode == .sunDetail ? 1.45 : 1.8
        container.scale = SCNVector3(targetWidth / xSpan, targetWidth / xSpan, targetWidth / xSpan)
        applyBirdsDarkMaterial(to: container)
        container.enumerateHierarchy { node, _ in
            for key in node.animationKeys { node.animationPlayer(forKey: key)?.play() }
        }
        return container
    }

    /// 递归打印节点树，帮助识别多余的球体节点。
    private func printBirdsNodeTree(_ node: SCNNode, indent: String) {
        let geo  = node.geometry  != nil ? " [geo]"  : ""
        let skin = node.skinner   != nil ? " [skin]" : ""
        let kids = node.childNodes.count
        print("\(indent)\(node.name ?? "<nil>")\(geo)\(skin)  children=\(kids)")
        for child in node.childNodes {
            printBirdsNodeTree(child, indent: indent + "  ")
        }
    }

    /// 移除球体节点：按常见命名关键字匹配，或按「有几何体且无子节点且边界盒近似球形」的几何特征匹配。
    private func removeBallNodes(from root: SCNNode) {
        let keywords = ["sphere", "ball", "icosphere", "uvsphere", "circle"]
        var toRemove: [SCNNode] = []
        root.enumerateChildNodes { node, _ in
            // 1) 名称关键字
            if let name = node.name?.lowercased(),
               keywords.contains(where: { name.contains($0) }) {
                toRemove.append(node)
                return
            }
            // 2) 几何特征：有 geometry、无子节点、且边界盒 X/Y/Z 较均匀（宽高比接近 1）
            if node.geometry != nil, node.childNodes.isEmpty {
                let (lo, hi) = node.boundingBox
                let dx = hi.x - lo.x, dy = hi.y - lo.y, dz = hi.z - lo.z
                let maxD = max(dx, dy, dz)
                let minD = min(dx, dy, dz)
                if maxD > 0.001, minD / maxD > 0.75 {
                    toRemove.append(node)
                }
            }
        }
        for node in toRemove {
            print("[Birds] 🗑 removing node: \(node.name ?? "<nil>")")
            node.removeFromParentNode()
        }
    }

    /// 为鸟群节点应用深色哑光 PBR 材质
    private func applyBirdsDarkMaterial(to node: SCNNode) {
        node.enumerateChildNodes { child, _ in
            guard let geo = child.geometry else { return }
            let mat = SCNMaterial()
            mat.lightingModel      = .physicallyBased
            mat.diffuse.contents   = UIColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 1)
            mat.metalness.contents = Float(0.10)
            mat.roughness.contents = Float(0.90)
            mat.isDoubleSided      = true
            geo.materials = [mat]
        }
    }

    private func makeTemperatureModelNode(text: String) -> SCNNode? {
        let characters = Array(text)
        guard !characters.isEmpty else { return nil }

        var glyphs: [(node: SCNNode, width: Float)] = []
        for character in characters {
            guard let glyph = makeDigitGlyph(for: character) else {
                return nil
            }
            glyphs.append(glyph)
        }

        let container = SCNNode()
        container.name = SceneNode.temperature
        var cursor: Float = 0
        let spacing: Float = 0.18

        for glyph in glyphs {
            let node = glyph.node
            node.position.x = cursor + glyph.width / 2
            cursor += glyph.width + spacing
            container.addChildNode(node)
        }

        let totalWidth = max(cursor - spacing, 0)
        for child in container.childNodes {
            child.position.x -= totalWidth / 2
        }

        container.eulerAngles = SCNVector3(0.02, -0.05, 0.01)
        return container
    }

    private func makeDigitGlyph(for character: Character) -> (node: SCNNode, width: Float)? {
        guard character.isNumber else { return nil }
        let digitName = String(character)

        // 尝试加载 OBJ 模型
        if let payload = loadNormalizedModelNode(named: digitName, fileExtension: "obj", targetHeight: 7.5) {
            let normalized = normalizeDigitPayload(payload, for: digitName)
            applyTemperatureDigitMaterial(to: normalized.node)
            normalized.node.name = "digit_\(digitName)"
            return normalized
        }

        // OBJ 模型不存在时，使用 SCNText 作为 fallback
        return makeFallbackDigitGlyph(for: digitName)
    }

    private func makeFallbackDigitGlyph(for digitName: String) -> (node: SCNNode, width: Float)? {
        let textGeometry = SCNText(string: digitName, extrusionDepth: 1.85)
        textGeometry.flatness = 0.06
        textGeometry.font = UIFont.systemFont(ofSize: 10.5, weight: .black)
        textGeometry.chamferRadius = 0.18

        let front = SCNMaterial()
        front.lightingModel = .physicallyBased
        front.diffuse.contents = UIColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1)
        front.metalness.contents = Float(0.45)
        front.roughness.contents = Float(0.28)
        front.specular.contents = UIColor(white: 0.92, alpha: 1)

        let side = SCNMaterial()
        side.lightingModel = .physicallyBased
        side.diffuse.contents = UIColor(red: 0.05, green: 0.05, blue: 0.06, alpha: 1)
        side.metalness.contents = Float(0.75)
        side.roughness.contents = Float(0.22)

        textGeometry.materials = [front, side, side, side, front]

        let node = SCNNode(geometry: textGeometry)
        let (minBounds, maxBounds) = node.boundingBox
        let width = maxBounds.x - minBounds.x
        let height = maxBounds.y - minBounds.y
        node.pivot = SCNMatrix4MakeTranslation(minBounds.x + width / 2, minBounds.y + height / 2, 0)
        node.scale = SCNVector3(0.72, 0.72, 0.72)
        return (node, width * 0.72)
    }

    private func normalizeDigitPayload(_ payload: (node: SCNNode, size: SCNVector3), for digitName: String) -> (node: SCNNode, width: Float) {
        // maxWidth/maxDepth 与 targetHeight 同步缩放，避免个别数字被过度压缩
        let maxWidth: Float = 2.68
        let maxDepth: Float = 0.88
        let widthScale = payload.size.x > maxWidth ? maxWidth / payload.size.x : 1
        let depthScale = payload.size.z > maxDepth ? maxDepth / payload.size.z : 1
        let manualScale: Float

        // 数字 1 偏窄，需要缩小；数字 2 偏宽，保持原样；其他数字统一缩放
        switch digitName {
        case "1":
            manualScale = 0.72
        case "2":
            manualScale = 0.90
        case "3":
            manualScale = 0.72
        case "4":
            manualScale = 0.72
        case "5":
            manualScale = 0.72
        case "6":
            manualScale = 0.72
        case "7":
            manualScale = 0.88
        case "8":
            manualScale = 0.72
        case "9":
            manualScale = 0.72
        case "0":
            manualScale = 0.75
        default:
            manualScale = 1
        }

        let correction = min(widthScale, depthScale, manualScale)
        if correction >= 0.999 {
            return (payload.node, payload.size.x)
        }

        payload.node.scale = SCNVector3(correction, correction, correction)
        return (payload.node, payload.size.x * correction)
    }

    private func loadNormalizedModelNode(named name: String, fileExtension: String, targetHeight: Float) -> (node: SCNNode, size: SCNVector3)? {
        guard let url = Bundle.main.url(forResource: name, withExtension: fileExtension, subdirectory: weatherDataSubdirectory),
              let sceneSource = SCNSceneSource(url: url, options: nil),
              let scene = sceneSource.scene(options: nil) else {
            return nil
        }
        let contentRoot = SCNNode()

        let sourceNodes = scene.rootNode.childNodes.isEmpty ? [scene.rootNode] : scene.rootNode.childNodes
        for sourceNode in sourceNodes {
            contentRoot.addChildNode(sourceNode.clone())
        }

        let (minBounds, maxBounds) = contentRoot.boundingBox
        let rawSize = SCNVector3(
            maxBounds.x - minBounds.x,
            maxBounds.y - minBounds.y,
            maxBounds.z - minBounds.z
        )

        guard rawSize.y > 0.0001 else { return nil }

        contentRoot.pivot = SCNMatrix4MakeTranslation(
            minBounds.x + rawSize.x / 2,
            minBounds.y + rawSize.y / 2,
            minBounds.z + rawSize.z / 2
        )

        let scale = targetHeight / rawSize.y
        contentRoot.scale = SCNVector3(scale, scale, scale)

        let wrapper = SCNNode()
        wrapper.addChildNode(contentRoot)
        let normalizedSize = SCNVector3(rawSize.x * scale, rawSize.y * scale, rawSize.z * scale)
        return (wrapper, normalizedSize)
    }

    private func applySunMaterial(to node: SCNNode) {
        node.enumerateChildNodes { child, _ in
            guard let geometry = child.geometry else { return }
            self.applySunMaterialToGeometry(geometry)
        }
    }

    private func applySunMaterialToGeometry(_ geometry: SCNGeometry) {
        // 尝试加载纹理图片，如果不存在则使用程序化噪声
        let textureImage: UIImage? = Bundle.main.url(forResource: "texture", withExtension: "png", subdirectory: weatherDataSubdirectory)
            .flatMap { UIImage(contentsOfFile: $0.path) }

        let material = SCNMaterial()
        material.lightingModel = .physicallyBased

        if let texture = textureImage {
            // 有纹理图片时使用
            material.diffuse.contents = texture
            material.emission.contents = UIColor(red: 0.45, green: 0.0, blue: 0.0, alpha: 0.18)
            material.roughness.contents = Float(0.68)
        } else {
            // 无纹理图片时，使用程序化噪声模拟颗粒质感
            material.diffuse.contents = UIColor(red: 1.0, green: 0.17, blue: 0.17, alpha: 0.98)
            material.emission.contents = UIColor(red: 0.65, green: 0.0, blue: 0.0, alpha: 0.22)
            material.roughness.contents = Float(0.75)

            // 使用生成的噪波图像应用到粗糙度
            if let noiseImage = createGrainNoiseImage(size: 256) {
                material.roughness.contents = noiseImage
            }
        }

        material.metalness.contents = Float(0.0)
        material.isDoubleSided = true
        geometry.materials = [material]
    }

    private func applyTemperatureDigitMaterial(to node: SCNNode) {
        node.enumerateChildNodes { child, _ in
            guard let geometry = child.geometry else { return }

            let materialTemplate = self.makeTemperatureDigitMaterial()
            let materialCount = max(geometry.materials.count, 1)
            geometry.materials = (0..<materialCount).map { _ in
                materialTemplate.copy() as? SCNMaterial ?? materialTemplate
            }
        }
    }

    private func makeTemperatureDigitMaterial() -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel      = .physicallyBased
        material.diffuse.contents   = UIColor(red: 0.10, green: 0.10, blue: 0.11, alpha: 1)
        // metalness 0.18：OBJ 网格没有切线数据，纯非金属+高粗糙度会导致侧面全黑；
        // 适量金属度借助 Fresnel 效应补亮边缘面，同时保留磨砂哑光整体质感
        material.metalness.contents = Float(0.18)
        material.roughness.contents = Float(0.90)  // 高粗糙度 = 哑光磨砂感
        material.specular.contents  = UIColor(white: 0.28, alpha: 1) // 微弱高光定义棱角
        return material
    }

    private func updateTemperature(animated: Bool) {
        guard mode == .main else { return }
        guard let root = conditionGroup else { return }

        let replacement = makeTemperatureNode(text: "\(currentTemperature)")
        replacement.name = SceneNode.temperature
        replacement.position = SCNVector3(0, -1.2, 0.12) // 同步 buildScene 数字位置
        let targetOpacity: CGFloat = isTemperatureHidden ? 0 : 1
        replacement.opacity = animated ? 0 : targetOpacity
        root.addChildNode(replacement)

        if animated {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.22
            temperatureNode?.opacity = 0
            replacement.opacity = targetOpacity
            SCNTransaction.completionBlock = { [weak self] in
                self?.temperatureNode?.removeFromParentNode()
                self?.temperatureNode = replacement
            }
            SCNTransaction.commit()
        } else {
            temperatureNode?.removeFromParentNode()
            temperatureNode = replacement
        }
    }

    // MARK: - Sun Transition Animations

    /// 点击太阳时的即时反馈动画（放大）
    func applySunTapFeedback() {
        guard let sunNode = sunNode else { return }

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.15
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        sunNode.scale = SCNVector3(
            sunNode.scale.x * 1.15,
            sunNode.scale.y * 1.15,
            sunNode.scale.z * 1.15
        )

        SCNTransaction.commit()
    }

    /// 进入详情页前的推进动画（太阳继续放大）
    func applyEnterDetailPushAnimation(completion: (() -> Void)? = nil) {
        guard let sunNode = sunNode else { return }

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.40
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        SCNTransaction.completionBlock = completion

        sunNode.scale = SCNVector3(1.6, 1.6, 1.6)

        SCNTransaction.commit()
    }

    /// 从详情页返回时恢复太阳状态
    func resetSunFromDetail() {
        guard let sunNode = sunNode else { return }

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.28
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        sunNode.scale = SCNVector3(1.0, 1.0, 1.0)

        SCNTransaction.commit()
    }

    private func attachFloatAnimation(to node: SCNNode) {
        let animation = CABasicAnimation(keyPath: "position.y")
        animation.fromValue = Float(-0.14)
        animation.toValue = Float(0.14)
        animation.duration = 4.8
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        node.addAnimation(animation, forKey: "weather_float")
    }

    private func attachSunPulse(to node: SCNNode) {
        let pulse = CABasicAnimation(keyPath: "scale")
        pulse.fromValue = NSValue(scnVector3: SCNVector3(1, 1, 1))
        pulse.toValue = NSValue(scnVector3: SCNVector3(1.045, 1.045, 1.045))
        pulse.duration = 2.6
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        node.addAnimation(pulse, forKey: "sun_pulse")
    }

    private func attachSunSpin(to node: SCNNode) {
        let spin = CABasicAnimation(keyPath: "rotation")
        spin.fromValue = NSValue(scnVector4: SCNVector4(0, 1, 0, 0))
        spin.toValue = NSValue(scnVector4: SCNVector4(0, 1, 0, -Float.pi * 2))
        spin.duration = 30   // 原 18s，降到 60% 速度
        spin.repeatCount = .infinity
        spin.timingFunction = CAMediaTimingFunction(name: .linear)
        node.addAnimation(spin, forKey: "sun_spin")
    }

}