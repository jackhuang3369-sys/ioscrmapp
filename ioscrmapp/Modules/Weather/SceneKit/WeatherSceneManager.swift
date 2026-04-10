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
    private let sunSpinAnimationKey = "sun_spin"
    private let detailAutoSpinSpeed = -Float.pi * 2 / 30
    private let mainTemperatureScale: Float = 1.5
    private let mainSunScale: CGFloat = 1.12
    private let mainSunPositionY: Float = 4.40
    private let mainTemperaturePositionY: Float = -2.4
    private let mainCameraPosition = SCNVector3(0, 0.02, 24.9)

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

    func pauseAutomaticSpinForInteraction() {
        guard mode == .sunDetail else { return }

        autoSpinSpeed = 0
    }

    func resumeAutomaticSpinAfterInteraction() {
        guard mode == .sunDetail else { return }
        autoSpinSpeed = detailAutoSpinSpeed
    }

    private func buildScene() {
        scene.background.contents = UIColor.clear
        scene.rootNode.childNodes.forEach { $0.removeFromParentNode() }
        detailTitleNode = nil

        let isDetailMode = mode == .sunDetail
        restTiltX = isDetailMode ? -0.004 : -0.012
        autoSpinSpeed = isDetailMode ? detailAutoSpinSpeed : 0

        let camera = SCNCamera()
        camera.fieldOfView = isDetailMode ? 24 : 31
        camera.zNear = 0.1
        camera.zFar = 120

        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = isDetailMode
            ? SCNVector3(0, 0.38, 18.8)
            : mainCameraPosition
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
            sun.position = SCNVector3(0, mainSunPositionY, -0.1)
            rotatingGroup.addChildNode(sun)
            sunNode = sun
        }

        if mode == .main {
            let digits = makeTemperatureNode(text: "\(currentTemperature)")
            // ── 数字位置：Y 值越小越靠下（如需微调往下移，减小 Y 值）──
            digits.position = SCNVector3(0, mainTemperaturePositionY, 0.12)
            rotatingGroup.addChildNode(digits)
            temperatureNode = digits
        } else {
            temperatureNode = nil
        }

        attachFloatAnimation(to: root)
        attachSunPulse(to: sun)
        if mode == .main {
            attachSunSpin(to: sun)
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

        let sphere = SCNSphere(radius: mode == .sunDetail ? 2.37 : 2.16 * mainSunScale)
        sphere.segmentCount = 80

        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = UIColor(red: 1.0, green: 0.32, blue: 0.26, alpha: 0.96)
        material.emission.contents = UIColor(red: 1.0, green: 0.22, blue: 0.18, alpha: 0.34)
        material.roughness.contents = Float(0.68)
        material.metalness.contents = Float(0.0)
        material.transparency = 0.96
        material.blendMode = .alpha
        sphere.materials = [material]

        let body = SCNNode(geometry: sphere)
        body.name = SceneNode.sun
        root.addChildNode(body)

        let glow = SCNLight()
        glow.type = .omni
        glow.intensity = 760
        glow.color = UIColor(red: 1.0, green: 0.24, blue: 0.18, alpha: 1)
        glow.attenuationStartDistance = 0
        glow.attenuationEndDistance = 24

        let glowNode = SCNNode()
        glowNode.light = glow
        root.addChildNode(glowNode)

        return root
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
        let textGeometry = SCNText(string: text, extrusionDepth: 1.45)
        textGeometry.flatness = 0.08
        textGeometry.font = UIFont.systemFont(ofSize: 9.6, weight: .black)
        textGeometry.chamferRadius = 0.14

        let front = SCNMaterial()
        front.lightingModel = .physicallyBased
        front.diffuse.contents = UIColor(red: 0.10, green: 0.10, blue: 0.11, alpha: 1)
        front.metalness.contents = Float(0.55)
        front.roughness.contents = Float(0.24)
        front.specular.contents = UIColor(white: 0.95, alpha: 1)

        let side = SCNMaterial()
        side.lightingModel = .physicallyBased
        side.diffuse.contents = UIColor(red: 0.06, green: 0.06, blue: 0.07, alpha: 1)
        side.metalness.contents = Float(0.85)
        side.roughness.contents = Float(0.18)

        textGeometry.materials = [front, side, side, side, front]

        let node = SCNNode(geometry: textGeometry)
        node.name = SceneNode.temperature
        let (minBounds, maxBounds) = node.boundingBox
        let width = maxBounds.x - minBounds.x
        let height = maxBounds.y - minBounds.y
        node.pivot = SCNMatrix4MakeTranslation(minBounds.x + width / 2, minBounds.y + height / 2, 0)
        node.scale = SCNVector3(0.6 * mainTemperatureScale, 0.6 * mainTemperatureScale, 0.6 * mainTemperatureScale)
        node.eulerAngles = SCNVector3(0.02, -0.05, 0.01)
        return node
    }

    private func makeSunModelNode() -> SCNNode? {
        let targetHeight: Float = mode == .sunDetail ? 4.72 : 4.02 * Float(mainSunScale)
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

        container.scale = SCNVector3(mainTemperatureScale, mainTemperatureScale, mainTemperatureScale)
        container.eulerAngles = SCNVector3(0.02, -0.05, 0.01)
        return container
    }

    private func makeDigitGlyph(for character: Character) -> (node: SCNNode, width: Float)? {
        guard character.isNumber else { return nil }
        let digitName = String(character)
        // ── 数字大小调整入口：修改 targetHeight 可整体缩放字体（数值越大越大）──
        guard let payload = loadNormalizedModelNode(named: digitName, fileExtension: "obj", targetHeight: 7.5) else {
            return nil
        }

        let normalized = normalizeDigitPayload(payload, for: digitName)
        applyTemperatureDigitMaterial(to: normalized.node)
        normalized.node.name = "digit_\(digitName)"
        return normalized
    }

    private func normalizeDigitPayload(_ payload: (node: SCNNode, size: SCNVector3), for digitName: String) -> (node: SCNNode, width: Float) {
        // maxWidth/maxDepth 与 targetHeight 同步缩放，避免个别数字被过度压缩
        let maxWidth: Float = 2.68
        let maxDepth: Float = 0.88
        let widthScale = payload.size.x > maxWidth ? maxWidth / payload.size.x : 1
        let depthScale = payload.size.z > maxDepth ? maxDepth / payload.size.z : 1
        let manualScale: Float

        switch digitName {
        case "1":
            manualScale = 0.74
        case "2":
            manualScale = 0.92
        case "3":
            manualScale = 0.74
        case "4":
            manualScale = 0.74 // 字形偏宽，手动收窄保持视觉等高
        case "5":
            manualScale = 0.74
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
        guard let textureURL = Bundle.main.url(forResource: "texture", withExtension: "png", subdirectory: weatherDataSubdirectory),
              let image = UIImage(contentsOfFile: textureURL.path) else { return }
        let material = SCNMaterial()
        material.lightingModel     = .physicallyBased
        material.diffuse.contents  = image
        // emission 改为低强度暖色，避免全强度叠加纹理图片导致表面发糊
        material.emission.contents = UIColor(red: 0.55, green: 0.06, blue: 0.02, alpha: 1)
        material.metalness.contents = Float(0.0)
        material.roughness.contents = Float(0.62)  // 稍降粗糙度，纹理细节更清晰
        material.isDoubleSided     = true
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
        replacement.position = SCNVector3(0, mainTemperaturePositionY, 0.12) // 同步 buildScene 数字位置
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

    private func attachFloatAnimation(to node: SCNNode) {
        let offsetRange: Float = mode == .sunDetail ? 0.14 : 0.08
        let animation = CABasicAnimation(keyPath: "position.y")
        animation.fromValue = -offsetRange
        animation.toValue = offsetRange
        animation.duration = 4.8
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        node.addAnimation(animation, forKey: "weather_float")
    }

    private func attachSunPulse(to node: SCNNode) {
        let pulseScale: Float = mode == .sunDetail ? 1.045 : 1.03
        let pulse = CABasicAnimation(keyPath: "scale")
        pulse.fromValue = NSValue(scnVector3: SCNVector3(1, 1, 1))
        pulse.toValue = NSValue(scnVector3: SCNVector3(pulseScale, pulseScale, pulseScale))
        pulse.duration = 2.6
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        node.addAnimation(pulse, forKey: "sun_pulse")
    }

    private func attachSunSpin(to node: SCNNode) {
        let spin = CABasicAnimation(keyPath: "eulerAngles.y")
        spin.fromValue = 0
        spin.toValue = -Float.pi * 2
        spin.duration = 30   // 原 18s，降到 60% 速度
        spin.repeatCount = .infinity
        spin.timingFunction = CAMediaTimingFunction(name: .linear)
        node.addAnimation(spin, forKey: sunSpinAnimationKey)
    }

}
