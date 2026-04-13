import SceneKit
import SwiftUI
import UIKit

enum WeatherSceneMode {
    case main
    case sunDetail
    case sunTransition
}

final class WeatherSceneManager: ObservableObject {

    private struct SunLandingSpringTuning {
        let approachFraction: Double = 0.74
        let controlYFraction: Float = 0.44
        let controlDepthOffset: Float = -0.42
        let overshootYOffset: Float = -0.34
        let overshootZOffset: Float = -0.14
        let overshootScale: Float = 0.63
        let overshootEulerAngles = SCNVector3(0.14, -0.06, 0.13)
        let settleOvershoot: CGFloat = 0.82
    }

    static let sunDetailTransitionDuration: TimeInterval = 0.5 //入场动画，第一屏到第二屏的时间。
    static let sunDetailCrossfadeDuration: TimeInterval = 0.20
    static let sunReturnTransitionDuration: TimeInterval = 0.2 //回场动画，第二屏回到第一屏的时间。

    @Published private(set) var displayGroupRotation: SCNVector3 = SCNVector3(0, 0, 0)
    private(set) var scene: SCNScene
    private(set) var conditionGroup: SCNNode?
    private(set) var sunNode: SCNNode?
    private(set) var restTiltX: Float = -0.012
    private(set) var autoSpinSpeed: Float = 0
    private(set) var currentTemperature: Int
    /// 场景动画进行中时为 true，Coordinator 不应写入方向。
    private(set) var isPlayingSceneAnimation = false

    private let mode: WeatherSceneMode
    private var cameraNode: SCNNode?
    private var sceneRootNode: SCNNode?
    private var detailTitleNode: SCNNode?
    private var sunBurstNode: SCNNode?
    private var temperatureNode: SCNNode?
    private var pendingTemperatureNode: SCNNode?
    // Cache assembled temperature node trees by full text (for example "31").
    // This avoids reparsing the OBJ digits on every timeline scrub update.
    private var temperatureNodeCache: [String: SCNNode] = [:]
    // Tracks what value is currently rendered so we can skip no-op updates.
    private var displayedTemperature: Int?
    private var sunModelNode: SCNNode?
    private var sunBurstRayDirections: [ObjectIdentifier: SCNVector3] = [:]
    private var sunBurstRayStartPositions: [ObjectIdentifier: SCNVector3] = [:]
    private var sunBurstRayBaseOpacities: [ObjectIdentifier: CGFloat] = [:]
    private var transitionSourceRotation = SCNVector3(0, 0, 0)
    private var isTemperatureHidden: Bool = false
    private var autoSpinSpeedBeforeInteraction: Float?
    private var transitionCompletionWorkItem: DispatchWorkItem?
    private var entrySpinWorkItem: DispatchWorkItem?
    private var _birdsScene: SCNScene?   // 防止 ARC 过早释放鸟群场景
    private let weatherDataSubdirectory = "WeatherData"
    private let sunSpinAnimationKey = "sun_spin"
    private let sunTitleSpinAnimationKey = "sun_title_spin"
    private let detailIntroSpinTurns: Float = 2
    private let detailIntroSpinDuration: TimeInterval = 20
    private let mainTemperatureScale: Float = 1.5
    private let mainSunScale: CGFloat = 1.12
    private let mainSunPositionY: Float = 4.45
    private let mainTemperaturePositionY: Float = -2.4
    private let mainCameraPosition = SCNVector3(0, 0.02, 24.9)
    private let detailCameraPosition = SCNVector3(0, 0.38, 18.8)
    private let mainRootPosition = SCNVector3(0, -1.94, 0)
    private let detailRootPosition = SCNVector3(0, -0.42, 0)
    private let mainPresentationRotation = SCNVector3(-0.012, 0, 0)
    private let detailSunPosition = SCNVector3(0, 1.4, -0.1) //太阳落点位置
    private let detailSunScale: Float = 0.68
    private let detailTitlePosition = SCNVector3(0, 4.0, 0.34)
    private let transitionRestRotation = SCNVector3(-0.004, 0, 0)
    private let sunLandingSpringTuning = SunLandingSpringTuning()

    init(temperature: Int = MockWeatherData.today.temperature, mode: WeatherSceneMode = .main) {
        self.scene = SCNScene()
        self.currentTemperature = temperature
        self.mode = mode
        buildScene()
    }

    func setTemperature(_ temperature: Int, animated: Bool) {
        currentTemperature = temperature
        // Timeline dragging can hit the same value repeatedly. If the rendered
        // node already matches and is still attached, there is nothing to rebuild.
        if displayedTemperature == temperature, temperatureNode?.parent != nil {
            return
        }
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

    func applyDisplayGroupRotation(_ angles: SCNVector3) {
        displayGroupRotation = angles
        conditionGroup?.eulerAngles = angles
    }

    func prepareSunDetailTransition(temperature: Int, sourceRotation: SCNVector3) {
        guard mode == .sunTransition else { return }

        currentTemperature = temperature
        isTemperatureHidden = false
        cancelPendingTransitionWork()
        transitionSourceRotation = sourceRotation
        applyDisplayGroupRotation(sourceRotation)
        resetSunBurstState()
    }

    func alignDetailSceneToFront() {
        guard mode == .sunTransition else { return }

        autoSpinSpeed = 0
        applyDisplayGroupRotation(transitionRestRotation)
    }

    func isDisplayGroupFrontFacing(toleranceDegrees: CGFloat = 8) -> Bool {
        let yawDegrees = CGFloat(displayGroupRotation.y) * 180 / .pi
        return WeatherSpinController(tuning: .default).isFrontFacing(
            yawDegrees: yawDegrees,
            toleranceDegrees: toleranceDegrees
        )
    }

    func alignDisplayGroupToFrontForDetail(
        duration: TimeInterval = 0.24,
        completion: @escaping () -> Void
    ) {
        guard mode == .sunTransition, let rotatingGroup = conditionGroup else {
            completion()
            return
        }

        autoSpinSpeed = 0
        rotatingGroup.removeAllActions()
        let nearestFrontYaw = nearestFrontFacingYaw(from: rotatingGroup.eulerAngles.y)
        SCNTransaction.begin()
        SCNTransaction.animationDuration = duration
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeOut)
        SCNTransaction.completionBlock = { [weak self] in
            self?.syncDisplayGroupRotation(to: rotatingGroup.eulerAngles)
            completion()
        }
        rotatingGroup.eulerAngles = SCNVector3(restTiltX, nearestFrontYaw, 0)
        SCNTransaction.commit()
    }

    func resetToMainPresentation(temperature: Int) {
        guard mode == .sunTransition else { return }

        currentTemperature = temperature
        isTemperatureHidden = false
        autoSpinSpeed = 0
        buildScene()
    }

    func startReturnToMainTransition(temperature: Int, completion: @escaping () -> Void) {
        guard mode == .sunTransition,
              let rotatingGroup = conditionGroup,
              let root = sceneRootNode,
              let cameraNode,
              let sunNode,
              let detailTitleNode
        else {
            completion()
            return
        }

        currentTemperature = temperature
        cancelPendingTransitionWork()
        cancelEntryAnimation()
        isPlayingSceneAnimation = true
        reattachSunSpinAnimations()
        autoSpinSpeed = 0
        stopDetailIntroSpin(resetOrientation: true)
        restTiltX = -0.012
        applyDisplayGroupRotation(transitionRestRotation)

        rotatingGroup.removeAllActions()
        root.removeAllActions()
        cameraNode.removeAllActions()
        sunNode.removeAllActions()
        detailTitleNode.removeAllActions()
        resetSunBurstState()

        if let digits = prepareTemperatureNodeForReturn() {
            runTemperatureReturnAnimation(on: digits)
        }

        runSunReturnAnimation(on: sunNode)
        runSceneReturnAnimation(
            root: root,
            cameraNode: cameraNode,
            rotatingGroup: rotatingGroup
        )
        runDetailTitleHide(on: detailTitleNode)

        let completionWorkItem = DispatchWorkItem { [weak self] in
            self?.isPlayingSceneAnimation = false
            self?.applyDisplayGroupRotation(self?.mainPresentationRotation ?? SCNVector3(0, 0, 0))
            if let root = self?.sceneRootNode {
                self?.attachFloatAnimation(to: root)
            }
            completion()
        }
        transitionCompletionWorkItem = completionWorkItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.sunReturnTransitionDuration,
            execute: completionWorkItem
        )
    }

    func startSunDetailTransition(completion: @escaping () -> Void) {
        guard mode == .sunTransition,
              let rotatingGroup = conditionGroup,
              let root = sceneRootNode,
              let cameraNode,
              let sunNode,
              let temperatureNode,
              let detailTitleNode
        else {
            completion()
            return
        }

        cancelPendingTransitionWork()
        cancelEntryAnimation()
        // 抑制 Coordinator，避免和 SCNAction 冲突
        isPlayingSceneAnimation = true
        rotatingGroup.removeAllActions()
        sunNode.removeAllActions()
        root.removeAllActions()
        // 捕获浮动动画当前位置后移除，避免跳变
        let presentationPosition = root.presentation.position
        root.removeAnimation(forKey: "weather_float")
        root.position = presentationPosition
        cameraNode.removeAllActions()
        temperatureNode.removeAllActions()
        detailTitleNode.removeAllActions()
        resetSunBurstState()

        runTemperatureDepartureAnimation(on: temperatureNode)
        runSunExpansionAnimation(on: sunNode)
        runSceneShiftAnimation(root: root, cameraNode: cameraNode, rotatingGroup: rotatingGroup)
        runDetailTitleReveal(on: detailTitleNode)
        runSunBurstAnimation()

        let completionWorkItem = DispatchWorkItem { [weak self] in
            self?.restTiltX = -0.004
            self?.autoSpinSpeed = 0
            self?.applyDisplayGroupRotation(self?.transitionRestRotation ?? SCNVector3(0, 0, 0))
            self?.stopSunAmbientAnimations(resetOrientation: true, resetScale: true)
            self?.startDetailIntroSpinIfNeeded()
            completion()
        }
        transitionCompletionWorkItem = completionWorkItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.sunDetailTransitionDuration,
            execute: completionWorkItem
        )
    }

    func pauseAutomaticSpinForInteraction() {
        guard mode == .sunDetail || mode == .sunTransition else { return }
        cancelEntryAnimation()
        autoSpinSpeedBeforeInteraction = autoSpinSpeed
        autoSpinSpeed = 0
        stopSunAmbientAnimations(resetOrientation: true, resetScale: true)
        stopDetailIntroSpin(resetOrientation: true)
    }

    func resumeAutomaticSpinAfterInteraction() {
        guard mode == .sunDetail || mode == .sunTransition else { return }
        autoSpinSpeed = WeatherAutoSpinRecovery.resumedSpeed(
            speedBeforeInteraction: autoSpinSpeedBeforeInteraction,
            fallbackCurrentSpeed: autoSpinSpeed
        )
        autoSpinSpeedBeforeInteraction = nil
    }

    private func nearestFrontFacingYaw(from yaw: Float) -> Float {
        let fullRotation = Float.pi * 2
        let nearestTurn = round(yaw / fullRotation)
        return nearestTurn * fullRotation
    }

    private func buildScene() {
        cancelPendingTransitionWork()
        scene.background.contents = UIColor.clear
        scene.rootNode.childNodes.forEach { $0.removeFromParentNode() }
        cameraNode = nil
        sceneRootNode = nil
        detailTitleNode = nil
        sunBurstNode = nil
        temperatureNode = nil
        pendingTemperatureNode = nil
        displayedTemperature = nil
        sunNode = nil
        sunModelNode = nil
        sunBurstRayDirections.removeAll()
        sunBurstRayStartPositions.removeAll()
        sunBurstRayBaseOpacities.removeAll()

        let isDetailMode = mode == .sunDetail
        let isTransitionMode = mode == .sunTransition
        restTiltX = isDetailMode ? -0.004 : -0.012
        autoSpinSpeed = 0

        let camera = SCNCamera()
        camera.fieldOfView = isDetailMode ? 24 : 31
        camera.zNear = 0.1
        camera.zFar = 120

        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = isDetailMode
            ? detailCameraPosition
            : mainCameraPosition
        scene.rootNode.addChildNode(cameraNode)
        self.cameraNode = cameraNode

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = isDetailMode ? 1120 : (isTransitionMode ? 1080 : 1000)
        ambient.color = UIColor(white: 0.85, alpha: 1)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        let key = SCNLight()
        key.type = .directional
        key.intensity = isDetailMode ? 1380 : (isTransitionMode ? 1320 : 1200)
        key.color = UIColor(red: 1.0, green: 0.96, blue: 0.90, alpha: 1)
        let keyNode = SCNNode()
        keyNode.light = key
        keyNode.eulerAngles = SCNVector3(-0.4, 0.55, 0)
        scene.rootNode.addChildNode(keyNode)

        // ── 右侧棱角补光：从摄像机右上方照射，照亮数字有棱角的右侧面 ──
        // 调整 intensity 控制强度，eulerAngles.y 控制左右方向（负值=来自右侧）
        let rightFill = SCNLight()
        rightFill.type = .directional
        rightFill.intensity = isDetailMode ? 840 : (isTransitionMode ? 780 : 700)
        rightFill.color = UIColor(red: 0.95, green: 0.97, blue: 1.0, alpha: 1)
        let rightFillNode = SCNNode()
        rightFillNode.light = rightFill
        // Y=-0.6 ≈ 来自右前方约 34°，既补右侧面又不造成过度阴影
        rightFillNode.eulerAngles = SCNVector3(-0.2, -0.6, 0)
        scene.rootNode.addChildNode(rightFillNode)

        let root = SCNNode()
        root.name = "weather_root"
        root.position = isDetailMode
            ? detailRootPosition
            : mainRootPosition
        scene.rootNode.addChildNode(root)
        sceneRootNode = root

        let rotatingGroup = SCNNode()
        rotatingGroup.name = "weather_rotating_group"
        let initialRotation = isDetailMode ? transitionRestRotation : mainPresentationRotation
        rotatingGroup.eulerAngles = initialRotation
        root.addChildNode(rotatingGroup)
        conditionGroup = rotatingGroup
        displayGroupRotation = initialRotation

        let sun = makeSunNode()
        if isDetailMode {
            let sunAssembly = SCNNode()
            sunAssembly.name = "weather_sun_detail_assembly"
            sunAssembly.position = detailSunPosition

            sun.position = SCNVector3(0, 0, 0)
            sunAssembly.addChildNode(sun)
            rotatingGroup.addChildNode(sunAssembly)

            let title = makeSunDetailTitleNode(text: "SUN")
            title.position = detailTitlePosition
            rotatingGroup.addChildNode(title)
            detailTitleNode = title

            sunNode = sunAssembly
            sunModelNode = sun
        } else if isTransitionMode {
            let sunAssembly = SCNNode()
            sunAssembly.name = "weather_sun_transition_assembly"
            sunAssembly.position = SCNVector3(0, mainSunPositionY, -0.1)

            sun.position = SCNVector3(0, 0, 0)
            sunAssembly.addChildNode(sun)

            let burstNode = makeSunBurstNode()
            burstNode.position = SCNVector3(0, 0, 0)
            sunAssembly.addChildNode(burstNode)
            sunBurstNode = burstNode

            rotatingGroup.addChildNode(sunAssembly)

            let title = makeSunDetailTitleNode(text: "SUN")
            title.name = SceneNode.sunTitle
            title.position = detailTitlePosition
            title.opacity = 0
            title.scale = SCNVector3(1, 1, 1)
            rotatingGroup.addChildNode(title)
            detailTitleNode = title

            sunNode = sunAssembly
            sunModelNode = sun
        } else {
            sun.position = SCNVector3(0, mainSunPositionY, -0.1)
            rotatingGroup.addChildNode(sun)
            sunNode = sun
            sunModelNode = sun
        }

        if mode == .main || mode == .sunTransition {
            let digits = makeTemperatureNode(text: "\(currentTemperature)")
            // ── 数字位置：Y 值越小越靠下（如需微调往下移，减小 Y 值）──
            digits.position = SCNVector3(0, mainTemperaturePositionY, 0.12)
            rotatingGroup.addChildNode(digits)
            temperatureNode = digits
            displayedTemperature = currentTemperature
        }

        if mode != .sunDetail {
            attachFloatAnimation(to: root)
            attachSunPulse(to: sun)
        }
        if mode == .main || mode == .sunTransition {
            attachSunSpin(to: sun, animationKey: sunSpinAnimationKey)
        }
        if mode == .sunDetail {
            DispatchQueue.main.async { [weak self] in
                self?.startDetailIntroSpinIfNeeded()
            }
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
        // Cache the fully assembled temperature subtree so scrubbing the hourly
        // timeline reuses cloned nodes instead of rebuilding OBJ content each time.
        if let cachedNode = temperatureNodeCache[text] {
            return cachedNode.clone()
        }

        let templateNode: SCNNode
        if let modelNode = makeTemperatureModelNode(text: text) {
            templateNode = modelNode
        } else {
            templateNode = makeFallbackTemperatureNode(text: text)
        }
        temperatureNodeCache[text] = templateNode
        return templateNode.clone()
    }

    private func makeSunDetailTitleNode(text: String) -> SCNNode {
        let container = SCNNode()
        container.name = SceneNode.sunTitle
        let frontTitle = makeSingleSunDetailTitleNode(text: text)
        frontTitle.position.z = 0
        container.addChildNode(frontTitle)

        container.eulerAngles = SCNVector3(0.02, -0.04, 0.01)
        container.castsShadow = false
        return container
    }

    private func makeSunBurstNode() -> SCNNode {
        let container = SCNNode()
        container.name = SceneNode.sunBurst
        container.opacity = 0
        container.isHidden = true

        let directions: [SIMD3<Float>] = [
            SIMD3<Float>(0.00, 1.00, 0.32),
            SIMD3<Float>(0.44, 0.92, 0.26),
            SIMD3<Float>(0.82, 0.48, 0.18),
            SIMD3<Float>(0.98, 0.06, -0.05),
            SIMD3<Float>(0.72, -0.52, 0.16),
            SIMD3<Float>(0.34, -0.92, 0.24),
            SIMD3<Float>(-0.05, -1.00, -0.10),
            SIMD3<Float>(-0.40, -0.86, -0.24),
            SIMD3<Float>(-0.84, -0.44, 0.04),
            SIMD3<Float>(-1.00, 0.04, -0.12),
            SIMD3<Float>(-0.76, 0.58, -0.26),
            SIMD3<Float>(-0.30, 0.94, 0.08)
        ]

        for (index, direction) in directions.enumerated() {
            container.addChildNode(
                makeSunBurstRayNode(
                    direction: direction,
                    index: index
                )
            )
        }

        return container
    }

    private func makeSunBurstRayNode(direction: SIMD3<Float>, index: Int) -> SCNNode {
        let normalizedDirection = simd_normalize(direction)
        let isFrontRay = normalizedDirection.z >= 0
        let length = CGFloat(isFrontRay ? 2.73 : 2.31) + CGFloat(index % 3) * 0.14
        let thickness = CGFloat(isFrontRay ? 0.052 : 0.038)

        let rayGeometry = SCNBox(
            width: thickness,
            height: length,
            length: thickness * 1.35,
            chamferRadius: thickness * 0.4
        )

        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = UIColor(
            white: 0.03,
            alpha: isFrontRay ? 0.88 : 0.36
        )
        material.emission.contents = UIColor(
            white: 0.0,
            alpha: isFrontRay ? 0.08 : 0.02
        )
        material.metalness.contents = Float(0.05)
        material.roughness.contents = Float(0.95)
        material.isDoubleSided = true
        rayGeometry.materials = Array(repeating: material, count: 6)

        let rayNode = SCNNode(geometry: rayGeometry)
        let sunRadius: Float = 2.44
        let halfLength = Float(length) / 2
        let distanceFromCenter = sunRadius + halfLength
        let placement = normalizedDirection * distanceFromCenter
        rayNode.position = SCNVector3(placement.x, placement.y, placement.z)
        rayNode.simdOrientation = simd_quatf(
            from: SIMD3<Float>(0, 1, 0),
            to: normalizedDirection
        )
        rayNode.scale = SCNVector3(1, 1, 1)
        rayNode.opacity = isFrontRay ? 1 : 0.82
        sunBurstRayDirections[ObjectIdentifier(rayNode)] = SCNVector3(
            normalizedDirection.x,
            normalizedDirection.y,
            normalizedDirection.z
        )
        sunBurstRayStartPositions[ObjectIdentifier(rayNode)] = rayNode.position
        sunBurstRayBaseOpacities[ObjectIdentifier(rayNode)] = rayNode.opacity
        return rayNode
    }

    private func makeSingleSunDetailTitleNode(text: String) -> SCNNode {
        let font = UIFont.systemFont(ofSize: 10.8, weight: .black)
        let container = SCNNode()
        var cursorX: Float = 0
        let letterSpacing: Float = 0.18

        for character in text {
            let letterNode = makeSunDetailTitleLetterNode(character: String(character), font: font)
            let (minBounds, maxBounds) = letterNode.boundingBox
            let width = maxBounds.x - minBounds.x
            letterNode.position = SCNVector3(cursorX - minBounds.x, -minBounds.y, 0)
            container.addChildNode(letterNode)
            cursorX += width + letterSpacing
        }

        let (minBounds, maxBounds) = container.boundingBox
        let width = maxBounds.x - minBounds.x
        let height = maxBounds.y - minBounds.y
        container.pivot = SCNMatrix4MakeTranslation(
            minBounds.x + width / 2,
            minBounds.y + height / 2,
            0
        )
        container.scale = SCNVector3(0.09, 0.09, 0.09)
        return container
    }

    private func makeSunDetailTitleLetterNode(character: String, font: UIFont) -> SCNNode {
        let textGeometry = makeSunDetailTitleLetterGeometry(character: character, font: font)
        let measureNode = SCNNode(geometry: textGeometry)
        let (minBounds, maxBounds) = measureNode.boundingBox
        let centerX = minBounds.x + (maxBounds.x - minBounds.x) / 2
        let centerY = minBounds.y + (maxBounds.y - minBounds.y) / 2

        let container = SCNNode()

        // Build a visible faux-bold outline with several enlarged underlays.
        let outlineOffsets: [SCNVector3] = [
            SCNVector3(0, 0, -0.06),
            SCNVector3(-0.38, 0, -0.08),
            SCNVector3(0.38, 0, -0.08),
            SCNVector3(0, -0.32, -0.08),
            SCNVector3(0, 0.32, -0.08),
            SCNVector3(-0.28, -0.28, -0.08),
            SCNVector3(0.28, -0.28, -0.08),
            SCNVector3(-0.28, 0.28, -0.08),
            SCNVector3(0.28, 0.28, -0.08)
        ]
        for offset in outlineOffsets {
            let outlineGeometry = textGeometry.copy() as? SCNGeometry
                ?? makeSunDetailTitleLetterGeometry(character: character, font: font)
            let outlineNode = SCNNode(geometry: outlineGeometry)
            outlineNode.pivot = SCNMatrix4MakeTranslation(centerX, centerY, 0)
            outlineNode.position = SCNVector3(centerX + offset.x, centerY + offset.y, offset.z)
            outlineNode.scale = SCNVector3(1.18, 1.18, 1)
            container.addChildNode(outlineNode)
        }

        let foregroundNode = SCNNode(geometry: textGeometry)
        foregroundNode.pivot = SCNMatrix4MakeTranslation(centerX, centerY, 0)
        foregroundNode.position = SCNVector3(centerX, centerY, 0)
        container.addChildNode(foregroundNode)

        return container
    }

    private func makeSunDetailTitleLetterGeometry(character: String, font: UIFont) -> SCNText {
        let textGeometry = SCNText(string: character, extrusionDepth: 0.9)
        textGeometry.font = font
        textGeometry.flatness = 0.06
        textGeometry.chamferRadius = 0.10
        textGeometry.truncationMode = CATextLayerTruncationMode.none.rawValue
        textGeometry.alignmentMode = CATextLayerAlignmentMode.left.rawValue
        textGeometry.isWrapped = false
        textGeometry.materials = makeSunDetailTitleMaterials()
        return textGeometry
    }

    private func makeSunDetailTitleMaterials() -> [SCNMaterial] {
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

        return [front, side, side, side, front]
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

    private func cancelPendingTransitionWork() {
        transitionCompletionWorkItem?.cancel()
        transitionCompletionWorkItem = nil
    }

    // MARK: - 入场动画（正面复位 → 静止2秒 → 旋转3圈 → 停止）

    private func removeSunSpinAnimationsAndResetFront() {
        sunModelNode?.removeAnimation(forKey: sunSpinAnimationKey)
        sunModelNode?.eulerAngles.y = 0
        detailTitleNode?.removeAnimation(forKey: sunTitleSpinAnimationKey)
        detailTitleNode?.eulerAngles.y = 0
    }

    private func reattachSunSpinAnimations() {
        if let sun = sunModelNode {
            attachSunSpin(to: sun, animationKey: sunSpinAnimationKey)
        }
        if let title = detailTitleNode {
            attachSunSpin(to: title, animationKey: sunTitleSpinAnimationKey)
        }
    }

    private func scheduleEntrySpinAnimation() {
        entrySpinWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.runEntrySpinAnimation()
        }
        entrySpinWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: workItem)
    }

    private func runEntrySpinAnimation() {
        guard let sunNode, let titleNode = detailTitleNode else { return }

        let totalYawRotation = -Float.pi * 2 * 2  // 2圈
        let spinDuration: TimeInterval = 60.0  // 30秒/圈 × 2圈

        // 太阳旋转2圈
        let sunStart = sunNode.eulerAngles
        let sunEnd = SCNVector3(sunStart.x, sunStart.y + totalYawRotation, sunStart.z)
        let sunSpin = makeEulerAnglesAction(
            from: sunStart, to: sunEnd,
            duration: spinDuration,
            easing: { $0 }  // 线性匀速
        )

        let titleStart = titleNode.eulerAngles
        let titleEnd = SCNVector3(titleStart.x, titleStart.y + totalYawRotation, titleStart.z)
        let titleSpin = makeEulerAnglesAction(
            from: titleStart, to: titleEnd,
            duration: spinDuration,
            easing: { $0 }
        )

        // 太阳旋转完成后解除 Coordinator 抑制
        sunNode.runAction(sunSpin) { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                self.sunNode?.eulerAngles.y = 0
                self.isPlayingSceneAnimation = false
                self.applyDisplayGroupRotation(self.transitionRestRotation)
            }
        }

        titleNode.runAction(titleSpin) { [weak self] in
            DispatchQueue.main.async {
                self?.detailTitleNode?.eulerAngles.y = 0
            }
        }
    }

    func cancelEntryAnimation() {
        entrySpinWorkItem?.cancel()
        entrySpinWorkItem = nil
        if isPlayingSceneAnimation {
            sunNode?.removeAllActions()
            detailTitleNode?.removeAllActions()
            isPlayingSceneAnimation = false
        }
    }

    private func runTemperatureDepartureAnimation(on node: SCNNode) {
        let moveAction = SCNAction.move(to: SCNVector3(-10.4, mainTemperaturePositionY, -1.9), duration: 0.42)
        moveAction.timingMode = .easeOut

        let spinAction = makeEulerAnglesAction(
            from: node.eulerAngles,
            to: SCNVector3(0.16, -Float.pi * 1.42, -0.18),
            duration: 0.42,
            easing: easeOutCubic
        )

        let scaleAction = makeScaleAction(
            from: node.scale,
            to: SCNVector3(0.54, 0.54, 0.54),
            duration: 0.42,
            easing: easeOutCubic
        )

        let fadeAction = SCNAction.fadeOut(duration: 0.30)
        fadeAction.timingMode = .easeOut

        node.runAction(
            .group([moveAction, spinAction, scaleAction, fadeAction])
        ) { [weak self, weak node] in
            node?.removeFromParentNode()
            if self?.temperatureNode === node {
                self?.temperatureNode = nil
            }
        }
    }

    private func runSunExpansionAnimation(on node: SCNNode) {
        let tuning = sunLandingSpringTuning
        let approachDuration = max(
            Self.sunDetailTransitionDuration * tuning.approachFraction,
            0.01
        )
        let settleDuration = max(
            Self.sunDetailTransitionDuration - approachDuration,
            0.01
        )
        let startPosition = node.position
        let controlPosition = SCNVector3(
            startPosition.x,
            startPosition.y + (detailSunPosition.y - startPosition.y) * tuning.controlYFraction,
            startPosition.z + tuning.controlDepthOffset
        )
        let overshootPosition = SCNVector3(
            detailSunPosition.x,
            detailSunPosition.y + tuning.overshootYOffset,
            detailSunPosition.z + tuning.overshootZOffset
        )
        let settleEasing: (CGFloat) -> CGFloat = { [self] value in
            easeOutBack(value, overshoot: tuning.settleOvershoot)
        }
        let moveAction = SCNAction.sequence([
            makeQuadraticMoveAction(
                from: startPosition,
                control: controlPosition,
                to: overshootPosition,
                duration: approachDuration,
                easing: easeInOutCubic
            ),
            makeMoveAction(
                from: overshootPosition,
                to: detailSunPosition,
                duration: settleDuration,
                easing: settleEasing
            )
        ])
        let startScale = node.scale
        let overshootScale = SCNVector3(
            tuning.overshootScale,
            tuning.overshootScale,
            tuning.overshootScale
        )
        let finalScale = SCNVector3(detailSunScale, detailSunScale, detailSunScale)
        let scaleAction = SCNAction.sequence([
            makeScaleAction(
                from: startScale,
                to: overshootScale,
                duration: approachDuration,
                easing: easeInOutCubic
            ),
            makeScaleAction(
                from: overshootScale,
                to: finalScale,
                duration: settleDuration,
                easing: settleEasing
            )
        ])
        let startAngles = node.eulerAngles
        let overshootAngles = SCNVector3(
            startAngles.x + tuning.overshootEulerAngles.x,
            startAngles.y + tuning.overshootEulerAngles.y,
            startAngles.z + tuning.overshootEulerAngles.z
        )
        let finalAngles = SCNVector3(0, 0, 0)
        let rotationAction = SCNAction.sequence([
            makeEulerAnglesAction(
                from: startAngles,
                to: overshootAngles,
                duration: approachDuration,
                easing: easeInOutCubic
            ),
            makeEulerAnglesAction(
                from: overshootAngles,
                to: finalAngles,
                duration: settleDuration,
                easing: settleEasing
            )
        ])

        node.runAction(.group([moveAction, scaleAction, rotationAction]))
    }

    private func runSunReturnAnimation(on node: SCNNode) {
        let moveAction = SCNAction.move(
            to: SCNVector3(0, mainSunPositionY, -0.1),
            duration: Self.sunReturnTransitionDuration
        )
        moveAction.timingMode = .easeInEaseOut

        let scaleAction = makeScaleAction(
            from: node.scale,
            to: SCNVector3(1, 1, 1),
            duration: Self.sunReturnTransitionDuration,
            easing: easeInOutCubic
        )
        let rotationAction = makeEulerAnglesAction(
            from: node.eulerAngles,
            to: SCNVector3(0, 0, 0),
            duration: Self.sunReturnTransitionDuration,
            easing: easeInOutCubic
        )

        node.runAction(.group([moveAction, scaleAction, rotationAction]))
    }

    private func runSceneShiftAnimation(root: SCNNode, cameraNode: SCNNode, rotatingGroup: SCNNode) {
        let rootMove = SCNAction.move(to: detailRootPosition, duration: Self.sunDetailTransitionDuration)
        rootMove.timingMode = .easeInEaseOut
        root.runAction(rootMove)

        let cameraMove = SCNAction.move(to: detailCameraPosition, duration: Self.sunDetailTransitionDuration)
        cameraMove.timingMode = .easeInEaseOut
        let fieldOfViewAction = makeFieldOfViewAction(
            from: cameraNode.camera?.fieldOfView ?? 31,
            to: 24,
            duration: Self.sunDetailTransitionDuration
        )
        cameraNode.runAction(.group([cameraMove, fieldOfViewAction]))

        rotatingGroup.runAction(
            makeEulerAnglesAction(
                from: rotatingGroup.eulerAngles,
                to: transitionRestRotation,
                duration: Self.sunDetailTransitionDuration,
                easing: easeInOutCubic
            )
        )
    }

    private func runSceneReturnAnimation(root: SCNNode, cameraNode: SCNNode, rotatingGroup: SCNNode) {
        let rootMove = SCNAction.move(
            to: mainRootPosition,
            duration: Self.sunReturnTransitionDuration
        )
        rootMove.timingMode = .easeInEaseOut
        root.runAction(rootMove)

        let cameraMove = SCNAction.move(
            to: mainCameraPosition,
            duration: Self.sunReturnTransitionDuration
        )
        cameraMove.timingMode = .easeInEaseOut
        let fieldOfViewAction = makeFieldOfViewAction(
            from: cameraNode.camera?.fieldOfView ?? 24,
            to: 31,
            duration: Self.sunReturnTransitionDuration
        )
        cameraNode.runAction(.group([cameraMove, fieldOfViewAction]))

        rotatingGroup.runAction(
            makeEulerAnglesAction(
                from: rotatingGroup.eulerAngles,
                to: mainPresentationRotation,
                duration: Self.sunReturnTransitionDuration,
                easing: easeInOutCubic
            )
        )
    }

    private func runDetailTitleReveal(on node: SCNNode) {
        let revealDelay = Self.sunDetailTransitionDuration * 0.60
        let revealDuration = Self.sunDetailTransitionDuration * 0.24

        let moveAction = SCNAction.move(
            to: detailTitlePosition,
            duration: revealDuration
        )
        moveAction.timingMode = .easeOut

        let fadeAction = SCNAction.fadeOpacity(to: 1, duration: revealDuration * 0.78)
        fadeAction.timingMode = .easeOut

        node.position = SCNVector3(
            detailTitlePosition.x,
            detailTitlePosition.y + 0.18,
            detailTitlePosition.z
        )

        node.runAction(
            .sequence([
                .wait(duration: revealDelay),
                .group([moveAction, fadeAction])
            ])
        )
    }

    private func runDetailTitleHide(on node: SCNNode) {
        let fadeAction = SCNAction.fadeOut(duration: 0.18)
        fadeAction.timingMode = .easeIn
        let moveAction = SCNAction.move(
            to: SCNVector3(
                detailTitlePosition.x,
                detailTitlePosition.y - 0.14,
                detailTitlePosition.z
            ),
            duration: 0.18
        )
        moveAction.timingMode = .easeIn

        node.runAction(.group([fadeAction, moveAction]))
    }

    private func runSunBurstAnimation() {
        guard let sunBurstNode else { return }

        resetSunBurstState()
        sunBurstNode.isHidden = false
        sunBurstNode.opacity = 0

        let burstDelay = Self.sunDetailTransitionDuration * 0.30
        let burstFlyDuration = Self.sunDetailTransitionDuration * 0.38
        let burstFadeDuration = Self.sunDetailTransitionDuration * 0.18
        let burstStagger = Self.sunDetailTransitionDuration * 0.022
        let fadeInDuration = Self.sunDetailTransitionDuration * 0.10
        let maxRayWaveOffset = burstStagger * 4
        let burstHoldDuration = max(
            burstFlyDuration + maxRayWaveOffset - fadeInDuration,
            Self.sunDetailTransitionDuration * 0.08
        )

        let fadeInAction = SCNAction.fadeOpacity(to: 1, duration: fadeInDuration)
        fadeInAction.timingMode = .easeOut
        let fadeOutAction = SCNAction.fadeOut(duration: burstFadeDuration)
        fadeOutAction.timingMode = .easeIn

        sunBurstNode.runAction(
            .sequence([
                .wait(duration: burstDelay),
                fadeInAction,
                .wait(duration: burstHoldDuration),
                fadeOutAction,
                .run { node in
                    node.opacity = 0
                    node.isHidden = true
                }
            ])
        )

        for (index, rayNode) in sunBurstNode.childNodes.enumerated() {
            let rayDelay = burstDelay + Double(index % 5) * burstStagger
            let outwardDistance = Float(0.66 + Double(index % 3) * 0.08)
            let direction = rayDirection(for: rayNode)
            let startPosition = initialRayPosition(for: rayNode)
            let endPosition = SCNVector3(
                startPosition.x + direction.x * outwardDistance,
                startPosition.y + direction.y * outwardDistance,
                startPosition.z + direction.z * outwardDistance
            )

            rayNode.runAction(
                .sequence([
                    .wait(duration: rayDelay),
                    .group([
                        makeMoveAction(
                            from: startPosition,
                            to: endPosition,
                            duration: burstFlyDuration,
                            easing: easeOutCubic
                        ),
                        makeScaleYAction(
                            from: 1,
                            to: 0.5,
                            duration: burstFlyDuration,
                            easing: easeInOutCubic
                        )
                    ]),
                    SCNAction.fadeOut(duration: burstFadeDuration)
                ])
            )
        }
    }

    private func prepareTemperatureNodeForReturn() -> SCNNode? {
        guard let root = conditionGroup else { return nil }

        if let existingNode = temperatureNode, existingNode.parent != nil {
            return existingNode
        }

        let digits = makeTemperatureNode(text: "\(currentTemperature)")
        digits.position = SCNVector3(-1.2, mainTemperaturePositionY, -0.48)
        digits.scale = SCNVector3(0.54, 0.54, 0.54)
        digits.opacity = 0
        root.addChildNode(digits)
        temperatureNode = digits
        displayedTemperature = currentTemperature
        return digits
    }

    private func runTemperatureReturnAnimation(on node: SCNNode) {
        let moveAction = SCNAction.move(to: SCNVector3(0, mainTemperaturePositionY, 0.12), duration: 0.38)
        moveAction.timingMode = .easeOut

        let scaleAction = makeScaleAction(
            from: node.scale,
            to: SCNVector3(mainTemperatureScale, mainTemperatureScale, mainTemperatureScale),
            duration: 0.38,
            easing: easeOutCubic
        )

        let rotationAction = makeEulerAnglesAction(
            from: node.eulerAngles,
            to: SCNVector3(0, 0, 0),
            duration: 0.38,
            easing: easeOutCubic
        )

        let fadeAction = SCNAction.fadeOpacity(to: 1, duration: 0.26)
        fadeAction.timingMode = .easeOut

        node.runAction(.group([moveAction, scaleAction, rotationAction, fadeAction]))
    }

    private func startDetailIntroSpinIfNeeded() {
        guard mode == .sunDetail || mode == .sunTransition else { return }
        guard let sunNode, let detailTitleNode else { return }

        isPlayingSceneAnimation = true
        stopSunAmbientAnimations(resetOrientation: true, resetScale: true)
        stopDetailIntroSpin(resetOrientation: true)
        applyDisplayGroupRotation(transitionRestRotation)
        runDetailIntroSpin(on: sunNode, actionKey: sunSpinAnimationKey) { [weak self] in
            guard let self else { return }
            self.isPlayingSceneAnimation = false
            self.applyDisplayGroupRotation(self.transitionRestRotation)
        }
        runDetailIntroSpin(on: detailTitleNode, actionKey: sunTitleSpinAnimationKey)
    }

    private func stopDetailIntroSpin(resetOrientation: Bool) {
        sunNode?.removeAction(forKey: sunSpinAnimationKey)
        detailTitleNode?.removeAction(forKey: sunTitleSpinAnimationKey)
        isPlayingSceneAnimation = false

        guard resetOrientation else { return }

        if let sunNode {
            sunNode.eulerAngles = SCNVector3(sunNode.eulerAngles.x, 0, sunNode.eulerAngles.z)
        }

        if let detailTitleNode {
            detailTitleNode.eulerAngles = SCNVector3(
                detailTitleNode.eulerAngles.x,
                0,
                detailTitleNode.eulerAngles.z
            )
        }
    }

    private func runDetailIntroSpin(
        on node: SCNNode,
        actionKey: String,
        completion: (() -> Void)? = nil
    ) {
        let startAngles = node.eulerAngles
        let endAngles = SCNVector3(
            startAngles.x,
            startAngles.y - Float.pi * 2 * detailIntroSpinTurns,
            startAngles.z
        )
        let spinAction = makeEulerAnglesAction(
            from: startAngles,
            to: endAngles,
            duration: detailIntroSpinDuration,
            easing: { $0 }
        )

        node.runAction(spinAction, forKey: actionKey) { [weak node] in
            guard let node else { return }
            node.eulerAngles = SCNVector3(node.eulerAngles.x, 0, node.eulerAngles.z)
            completion?()
        }
    }

    private func stopSunAmbientAnimations(resetOrientation: Bool, resetScale: Bool) {
        sunModelNode?.removeAnimation(forKey: sunSpinAnimationKey, blendOutDuration: 0)
        sunModelNode?.removeAnimation(forKey: "sun_pulse", blendOutDuration: 0)

        guard let sunModelNode else { return }

        if resetOrientation {
            sunModelNode.eulerAngles = SCNVector3(
                sunModelNode.eulerAngles.x,
                0,
                sunModelNode.eulerAngles.z
            )
        }

        if resetScale {
            sunModelNode.scale = SCNVector3(1, 1, 1)
        }
    }

    private func rayDirection(for node: SCNNode) -> SCNVector3 {
        sunBurstRayDirections[ObjectIdentifier(node)] ?? SCNVector3(0, 1, 0)
    }

    private func initialRayPosition(for node: SCNNode) -> SCNVector3 {
        sunBurstRayStartPositions[ObjectIdentifier(node)] ?? node.position
    }

    private func baseRayOpacity(for node: SCNNode) -> CGFloat {
        sunBurstRayBaseOpacities[ObjectIdentifier(node)] ?? 1
    }

    private func resetSunBurstState() {
        guard let sunBurstNode else { return }

        sunBurstNode.removeAllActions()
        sunBurstNode.opacity = 0
        sunBurstNode.isHidden = true
        sunBurstNode.childNodes.forEach { rayNode in
            rayNode.removeAllActions()
            rayNode.position = initialRayPosition(for: rayNode)
            rayNode.scale = SCNVector3(1, 1, 1)
            rayNode.opacity = baseRayOpacity(for: rayNode)
        }
    }

    private func makeMoveAction(
        from startPosition: SCNVector3,
        to endPosition: SCNVector3,
        duration: TimeInterval,
        easing: @escaping (CGFloat) -> CGFloat
    ) -> SCNAction {
        SCNAction.customAction(duration: duration) { node, elapsed in
            let rawProgress = elapsed / CGFloat(max(duration, 0.0001))
            let progress = easing(rawProgress)
            node.position = SCNVector3(
                startPosition.x + Float(progress) * (endPosition.x - startPosition.x),
                startPosition.y + Float(progress) * (endPosition.y - startPosition.y),
                startPosition.z + Float(progress) * (endPosition.z - startPosition.z)
            )
        }
    }

    private func makeQuadraticMoveAction(
        from startPosition: SCNVector3,
        control controlPosition: SCNVector3,
        to endPosition: SCNVector3,
        duration: TimeInterval,
        easing: @escaping (CGFloat) -> CGFloat
    ) -> SCNAction {
        SCNAction.customAction(duration: duration) { [self] node, elapsed in
            let rawProgress = elapsed / CGFloat(max(duration, 0.0001))
            let progress = easing(rawProgress)
            node.position = self.quadraticBezierPoint(
                from: startPosition,
                control: controlPosition,
                to: endPosition,
                progress: progress
            )
        }
    }

    private func makeFieldOfViewAction(
        from startFieldOfView: CGFloat,
        to endFieldOfView: CGFloat,
        duration: TimeInterval
    ) -> SCNAction {
        SCNAction.customAction(duration: duration) { [weak self] node, elapsed in
            let rawProgress = elapsed / CGFloat(max(duration, 0.0001))
            let progress = self?.easeInOutCubic(rawProgress) ?? rawProgress
            node.camera?.fieldOfView = startFieldOfView + (endFieldOfView - startFieldOfView) * progress
        }
    }

    private func makeEulerAnglesAction(
        from startAngles: SCNVector3,
        to endAngles: SCNVector3,
        duration: TimeInterval,
        easing: @escaping (CGFloat) -> CGFloat
    ) -> SCNAction {
        SCNAction.customAction(duration: duration) { node, elapsed in
            let rawProgress = elapsed / CGFloat(max(duration, 0.0001))
            let progress = easing(rawProgress)
            node.eulerAngles = SCNVector3(
                startAngles.x + Float(progress) * (endAngles.x - startAngles.x),
                startAngles.y + Float(progress) * (endAngles.y - startAngles.y),
                startAngles.z + Float(progress) * (endAngles.z - startAngles.z)
            )
        }
    }

    private func makeScaleAction(
        from startScale: SCNVector3,
        to endScale: SCNVector3,
        duration: TimeInterval,
        easing: @escaping (CGFloat) -> CGFloat
    ) -> SCNAction {
        SCNAction.customAction(duration: duration) { node, elapsed in
            let rawProgress = elapsed / CGFloat(max(duration, 0.0001))
            let progress = easing(rawProgress)
            node.scale = SCNVector3(
                startScale.x + Float(progress) * (endScale.x - startScale.x),
                startScale.y + Float(progress) * (endScale.y - startScale.y),
                startScale.z + Float(progress) * (endScale.z - startScale.z)
            )
        }
    }

    private func makeScaleYAction(
        from startScaleY: Float,
        to endScaleY: Float,
        duration: TimeInterval,
        easing: @escaping (CGFloat) -> CGFloat
    ) -> SCNAction {
        SCNAction.customAction(duration: duration) { node, elapsed in
            let rawProgress = elapsed / CGFloat(max(duration, 0.0001))
            let progress = easing(rawProgress)
            node.scale.y = startScaleY + Float(progress) * (endScaleY - startScaleY)
        }
    }

    private func quadraticBezierPoint(
        from startPosition: SCNVector3,
        control controlPosition: SCNVector3,
        to endPosition: SCNVector3,
        progress: CGFloat
    ) -> SCNVector3 {
        let clamped = min(max(progress, 0), 1)
        let inverse = 1 - clamped
        let startWeight = inverse * inverse
        let controlWeight = 2 * inverse * clamped
        let endWeight = clamped * clamped

        return SCNVector3(
            Float(startWeight) * startPosition.x
                + Float(controlWeight) * controlPosition.x
                + Float(endWeight) * endPosition.x,
            Float(startWeight) * startPosition.y
                + Float(controlWeight) * controlPosition.y
                + Float(endWeight) * endPosition.y,
            Float(startWeight) * startPosition.z
                + Float(controlWeight) * controlPosition.z
                + Float(endWeight) * endPosition.z
        )
    }

    private func easeOutCubic(_ value: CGFloat) -> CGFloat {
        let clamped = min(max(value, 0), 1)
        return 1 - pow(1 - clamped, 3)
    }

    private func easeInOutCubic(_ value: CGFloat) -> CGFloat {
        let clamped = min(max(value, 0), 1)
        if clamped < 0.5 {
            return 4 * clamped * clamped * clamped
        }

        let offset = -2 * clamped + 2
        return 1 - pow(offset, 3) / 2
    }

    private func easeOutBack(_ value: CGFloat, overshoot: CGFloat) -> CGFloat {
        let clamped = min(max(value, 0), 1)
        let shifted = clamped - 1
        let coefficient = overshoot + 1
        return 1 + coefficient * pow(shifted, 3) + overshoot * pow(shifted, 2)
    }

    private func updateTemperature(animated: Bool) {
        guard mode == .main || mode == .sunTransition else { return }
        guard let root = conditionGroup else { return }
        guard displayedTemperature != currentTemperature || temperatureNode?.parent == nil else { return }

        pendingTemperatureNode?.removeAllActions()
        pendingTemperatureNode?.removeFromParentNode()
        pendingTemperatureNode = nil

        let replacement = makeTemperatureNode(text: "\(currentTemperature)")
        replacement.name = SceneNode.temperature
        replacement.position = SCNVector3(0, mainTemperaturePositionY, 0.12) // 同步 buildScene 数字位置
        let targetOpacity: CGFloat = isTemperatureHidden ? 0 : 1
        replacement.opacity = animated ? 0 : targetOpacity
        root.addChildNode(replacement)

        if animated {
            pendingTemperatureNode = replacement
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.12
            temperatureNode?.opacity = 0
            replacement.opacity = targetOpacity
            SCNTransaction.completionBlock = { [weak self] in
                guard let self else { return }
                self.temperatureNode?.removeFromParentNode()
                self.temperatureNode = replacement
                if self.pendingTemperatureNode === replacement {
                    self.pendingTemperatureNode = nil
                }
                self.displayedTemperature = self.currentTemperature
            }
            SCNTransaction.commit()
        } else {
            temperatureNode?.removeFromParentNode()
            pendingTemperatureNode = nil
            temperatureNode = replacement
            displayedTemperature = currentTemperature
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

    private func attachSunSpin(to node: SCNNode, animationKey: String = "sun_spin") {
        let spin = CABasicAnimation(keyPath: "eulerAngles.y")
        spin.fromValue = 0
        spin.toValue = -Float.pi * 2
        spin.duration = 30   // 原 18s，降到 60% 速度
        spin.repeatCount = .infinity
        spin.timingFunction = CAMediaTimingFunction(name: .linear)
        node.addAnimation(spin, forKey: animationKey)
    }

}
