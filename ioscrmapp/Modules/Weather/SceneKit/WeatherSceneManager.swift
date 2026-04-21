import SceneKit
import SwiftUI
import UIKit

enum WeatherSceneMode {
    case main
    case sunDetail
    case sunTransition
}

final class WeatherSceneManager: ObservableObject {

    private enum SunBurstTuning {
        static let rayCount = WeatherSunBurstCore.rayCount
        static let minLength = WeatherSunBurstCore.minRayLength
        static let maxLength = WeatherSunBurstCore.maxRayLength
        static let minJitter = WeatherSunBurstCore.minJitter
        static let maxJitter = WeatherSunBurstCore.maxJitter
        static let sunRadius = WeatherSunBurstCore.sunRadius
        static let burstZOffset = WeatherSunBurstCore.burstZOffset
        static let layerDelayStep = WeatherSunBurstCore.layerDelayStep
        static let springMainDuration = WeatherSunBurstCore.springMainDuration
        static let springBounceDuration = WeatherSunBurstCore.springBounceDuration
        static let springOvershootY = WeatherSunBurstCore.springOvershootY
        static let springOvershootScale = WeatherSunBurstCore.springOvershootScale
        static let maxElevation: Float = Float.pi / 2   // 完整球面，保留兼容

        static func colorWhite(forZ z: Float) -> Float {
            WeatherSunBurstCore.colorWhite(forZ: z)
        }

        static func materialAlpha(forZ z: Float) -> Float {
            WeatherSunBurstCore.materialAlpha(forZ: z)
        }

        static func thickness(forZ z: Float) -> Float {
            WeatherSunBurstCore.thickness(forZ: z)
        }

        static func outwardDistance(forLength length: Float) -> Float {
            WeatherSunBurstCore.outwardDistance(forLength: length)
        }

        static func delayOffset(forZ z: Float) -> TimeInterval {
            WeatherSunBurstCore.delayOffset(forZ: z)
        }
    }

    static let sunDetailTransitionDuration: TimeInterval = 0.25 //入场动画，第一屏到第二屏的时间（原0.38s缩短为2/3）。
    static let sunDetailCrossfadeDuration: TimeInterval = 0.20
    static let sunReturnTransitionDuration: TimeInterval = 0.2 //回场动画，第二屏回到第一屏的时间。

    @Published private(set) var displayGroupRotation: SCNVector3 = SCNVector3(0, 0, 0)
    @Published private(set) var currentDetailDimension: WeatherDetailDimension = .sun
    @Published private(set) var presentedDetailDimension: WeatherDetailDimension = .sun
    private var currentDetailOrbitIndex: Int = 0
    private(set) var scene: SCNScene
    private(set) var conditionGroup: SCNNode?
    private(set) var sunNode: SCNNode?
    private(set) var restTiltX: Float = -0.012
    private(set) var autoSpinSpeed: Float = 0
    private(set) var currentTemperature: Int
    /// 入场旋转动画进行中时为 true，Coordinator 不应写入方向。
    private(set) var isPlayingEntryAnimation = false

    private let mode: WeatherSceneMode
    var isSunDetailMode: Bool {
        mode == .sunDetail || (mode == .sunTransition && detailDimensionRingNode?.isHidden == false)
    }
    private var cameraNode: SCNNode?
    private var sceneRootNode: SCNNode?
    private var detailTitleNode: SCNNode?
    private var detailDimensionRingNode: SCNNode?
    private var detailDimensionItemNodes: [WeatherDetailDimension: SCNNode] = [:]
    private var detailDimensionInteractionNodes: [WeatherDetailDimension: SCNNode] = [:]
    private var detailDimensionSpinNodes: [WeatherDetailDimension: SCNNode] = [:]
    private var detailDimensionTitleNodes: [WeatherDetailDimension: SCNNode] = [:]
    private var sunBurstNode: SCNNode?
    private var sunTapBurstOverlayNode: SCNNode?
    private var temperatureNode: SCNNode?
    private var temperatureNodePrototypeCache: [String: SCNNode] = [:]
    private var weatherAssetPrototypeCache: [String: SCNNode] = [:]
    private var sunNodePrototypeCache: [String: SCNNode] = [:]
    private var homeSceneAccessoryNode: SCNNode?
    private var homeNightGlowNode: SCNNode?
    private var sunModelNode: SCNNode?
    private var sunBurstRayDirections: [ObjectIdentifier: SCNVector3] = [:]
    private var sunBurstRayStartPositions: [ObjectIdentifier: SCNVector3] = [:]
    private var sunBurstRayBaseOpacities: [ObjectIdentifier: CGFloat] = [:]
    private var transitionSourceRotation = SCNVector3(0, 0, 0)
    private var isTemperatureHidden: Bool = false
    private var currentHomeScenePreset: WeatherHomeScenePreset = .sunny
    private var transitionCompletionWorkItem: DispatchWorkItem?
    private var burstAnimationWorkItem: DispatchWorkItem?
    private var entrySpinWorkItem: DispatchWorkItem?
    private var detailAutoSpinWorkItem: DispatchWorkItem?
    private var detailSpinGestureBaseModelAngles = SCNVector3Zero
    private var detailSpinGestureBaseTitleAngles = SCNVector3Zero
    private var isDetailOrbitFeedbackSessionActive = false
    private var lastOrbitFeedbackDimension: WeatherDetailDimension?
    private var _birdsScene: SCNScene?   // 防止 ARC 过早释放鸟群场景
    private let weatherDataSubdirectory = "WeatherData"
    private let sunSpinAnimationKey = "sun_spin"
    private let sunTitleSpinAnimationKey = "sun_title_spin"
    private let secondScreenMotionTuning = WeatherSecondScreenMotionTuning.default
    private lazy var secondScreenOrbitController = WeatherSecondScreenOrbitController(
        tuning: secondScreenMotionTuning
    )
    private let detailOrbitMotionActionKey = "detail_dimension_orbit_motion"
    private let detailDimensionSpinAnimationKey = "detail_dimension_spin"
    private let mainTemperatureScale: Float = 1.5
    private let mainSunScale: CGFloat = 1.12
    private let mainSunPositionY: Float = 4.40
    private let mainTemperaturePositionY: Float = -2.4
    private let mainCameraPosition = SCNVector3(0, 0.02, 24.9)
    private let detailCameraPosition = SCNVector3(0, -0.8, 23.4)
    private let mainRootPosition = SCNVector3(0, -1.94, 0)
    private let detailRootPosition = SCNVector3(0, -0.42, 0)
    private let mainPresentationRotation = SCNVector3(-0.012, 0, 0)
    private let detailSunPosition = SCNVector3(0, 0.39, -0.1) //太阳离SUN的距离
    private let detailSunScale: Float = 0.84
    private let detailTitlePosition = SCNVector3(0, 3.37, -0.1)
    private let detailRainScaleCorrection: Float = 0.44
    private let moonCrescentModelEulerAngles = SCNVector3(0, -2.36, 0)
    private let homeNightGlowIntensity: CGFloat = 700
    private let transitionRestRotation = SCNVector3(0, 0, 0)

    init(temperature: Int = MockWeatherData.today.temperature, mode: WeatherSceneMode = .main) {
        self.scene = SCNScene()
        self.currentTemperature = temperature
        self.mode = mode
        preloadWeatherModelCaches()
        buildScene()
    }

    private var detailDimensionRingRadius: Float {
        secondScreenMotionTuning.orbitRadius
    }

    private var detailDimensionAngleStep: Float {
        secondScreenMotionTuning.orbitAngleStep
    }

    private func preloadWeatherModelCaches() {
        _ = ensureSunNodePrototype()

        let homeAssets: [(name: String, fileExtension: String, targetHeight: Float)] = [
            ("moon", "usdz", homePrimaryModelHeight),
            ("cloudy", "usdz", homeAttachedCloudHeight),
            ("cloudy2", "usdz", homeAttachedCloudHeight),
            ("cloud", "usdz", homeStandaloneCloudHeight)
        ]

        let detailTargetHeight = detailDimensionModelTargetHeight()
        let detailAssets: [(name: String, fileExtension: String, targetHeight: Float)] = [
            ("cloud", "usdz", detailTargetHeight),
            ("air", "usdz", detailTargetHeight),
            ("moon", "usdz", detailTargetHeight),
            ("rain", "usdz", detailTargetHeight)
        ]

        (homeAssets + detailAssets).forEach { asset in
            _ = ensureWeatherAssetPrototype(
                named: asset.name,
                fileExtension: asset.fileExtension,
                targetHeight: asset.targetHeight
            )
        }
    }

    func setTemperature(_ temperature: Int, animated: Bool) {
        guard temperature != currentTemperature || temperatureNode == nil else {
            return
        }
        currentTemperature = temperature
        updateTemperature(animated: animated)
    }

    func setHomeScenePreset(_ preset: WeatherHomeScenePreset, animated: Bool) {
        guard mode == .main || mode == .sunTransition else { return }
        let shouldAnimate = animated && preset != currentHomeScenePreset
        currentHomeScenePreset = preset
        applyHomeScenePreset(animated: shouldAnimate)
    }

    func setDetailDimensionTitle(_ title: String) {
        guard mode == .sunDetail || mode == .sunTransition else { return }
        guard let detailTitleNode else { return }

        detailTitleNode.childNodes.forEach { $0.removeFromParentNode() }
        let frontTitle = makeSingleSunDetailTitleNode(text: title)
        frontTitle.position.z = 0
        detailTitleNode.addChildNode(frontTitle)
    }

    func setDetailDimensionProgress(
        selectedDimension: WeatherDetailDimension,
        dragProgress: CGFloat,
        animated: Bool
    ) {
        let orbitIndex = resolvedDetailOrbitIndex(for: selectedDimension)
        setDetailOrbitPosition(
            orbitIndex: orbitIndex,
            selectedDimension: selectedDimension,
            dragProgress: dragProgress,
            animated: animated
        )
    }

    private func setDetailOrbitPosition(
        orbitIndex: Int,
        selectedDimension: WeatherDetailDimension,
        dragProgress: CGFloat,
        animated: Bool
    ) {
        guard mode == .sunDetail || mode == .sunTransition else { return }
        guard let detailDimensionRingNode else { return }

        let offset = Float(orbitIndex) + Float(dragProgress)
        let targetYaw = -offset * detailDimensionAngleStep
        let visibleYaw = detailDimensionRingNode.presentation.eulerAngles.y

        detailDimensionRingNode.removeAction(forKey: detailOrbitMotionActionKey)
        detailDimensionRingNode.removeAllAnimations()
        detailDimensionRingNode.removeAllActions()
        detailDimensionRingNode.eulerAngles = SCNVector3(0, visibleYaw, 0)
        updateDetailDimensionPresentation(ringYaw: visibleYaw)

        if animated, abs(dragProgress) < 0.001 {
            animateDetailOrbit(
                ringNode: detailDimensionRingNode,
                from: visibleYaw,
                to: targetYaw,
                settledDimension: selectedDimension,
                settledOrbitIndex: orbitIndex,
                decision: WeatherSecondScreenOrbitDecision(
                    stepOffset: orbitIndex - currentDetailOrbitIndex,
                    usesMomentum: abs(orbitIndex - currentDetailOrbitIndex) > 1
                )
            )
            return
        }

        detailDimensionRingNode.eulerAngles = SCNVector3(0, targetYaw, 0)
        updateDetailDimensionPresentation(ringYaw: targetYaw)

        if abs(dragProgress) < 0.001 {
            currentDetailDimension = selectedDimension
            setPresentedDetailDimension(selectedDimension)
            currentDetailOrbitIndex = orbitIndex
            updateDetailDimensionSelfSpin(selectedDimension: selectedDimension, autoSpinEnabled: false)
            scheduleDetailAutoSpin()
        }
    }

    func prepareDetailSecondScreen() {
        guard mode == .sunDetail || mode == .sunTransition else { return }
        cancelDetailAutoSpin()
        endDetailOrbitFeedbackSession()
        WeatherAudioPlayer.shared.resetOrbitCheckpointSequence()
        currentDetailDimension = .sun
        setPresentedDetailDimension(.sun)
        currentDetailOrbitIndex = 0
        setDetailOrbitPosition(
            orbitIndex: 0,
            selectedDimension: .sun,
            dragProgress: 0,
            animated: false
        )
        scheduleDetailAutoSpin()
    }

    func beginDetailOrbitInteraction() {
        guard mode == .sunDetail || mode == .sunTransition else { return }
        cancelDetailAutoSpin()
        if let detailDimensionRingNode {
            let visibleYaw = detailDimensionRingNode.presentation.eulerAngles.y
            detailDimensionRingNode.removeAction(forKey: detailOrbitMotionActionKey)
            detailDimensionRingNode.removeAllAnimations()
            detailDimensionRingNode.removeAllActions()
            detailDimensionRingNode.eulerAngles = SCNVector3(0, visibleYaw, 0)
            let visibleOrbitIndex = roundedOrbitIndex(for: visibleYaw)
            currentDetailOrbitIndex = visibleOrbitIndex
            currentDetailDimension = WeatherDetailDimension.allCases[
                positiveModulo(visibleOrbitIndex, WeatherDetailDimension.allCases.count)
            ]
            updateDetailDimensionPresentation(ringYaw: visibleYaw)
        }
        updateDetailDimensionSelfSpin(selectedDimension: currentDetailDimension, autoSpinEnabled: false)
    }

    func updateDetailOrbitInteraction(progress: CGFloat) {
        setDetailOrbitPosition(
            orbitIndex: currentDetailOrbitIndex,
            selectedDimension: currentDetailDimension,
            dragProgress: progress,
            animated: false
        )
    }

    @discardableResult
    func settleDetailOrbitInteraction(
        sample: WeatherSecondScreenOrbitGestureSample
    ) -> WeatherSecondScreenOrbitDecision {
        let decision = secondScreenOrbitController.settleDecision(sample: sample)
        guard let detailDimensionRingNode else { return decision }

        let visibleYaw = detailDimensionRingNode.presentation.eulerAngles.y
        detailDimensionRingNode.removeAction(forKey: detailOrbitMotionActionKey)
        detailDimensionRingNode.removeAllAnimations()
        detailDimensionRingNode.removeAllActions()
        detailDimensionRingNode.eulerAngles = SCNVector3(0, visibleYaw, 0)
        updateDetailDimensionPresentation(ringYaw: visibleYaw)

        let nextOrbitIndex = currentDetailOrbitIndex + decision.stepOffset
        let nextDimension = WeatherDetailDimension.allCases[
            positiveModulo(nextOrbitIndex, WeatherDetailDimension.allCases.count)
        ]
        let targetYaw = -Float(nextOrbitIndex) * detailDimensionAngleStep
        if decision.stepOffset != 0 {
            beginDetailOrbitFeedbackSessionIfNeeded()
        } else {
            endDetailOrbitFeedbackSession()
        }
        if abs(decision.stepOffset) >= secondScreenMotionTuning.orbitWhooshMinimumTurns,
           secondScreenOrbitController.isFastOrbitGesture(sample) {
            WeatherAudioPlayer.shared.playOrbitWhoosh()
        }
        animateDetailOrbit(
            ringNode: detailDimensionRingNode,
            from: visibleYaw,
            to: targetYaw,
            settledDimension: nextDimension,
            settledOrbitIndex: nextOrbitIndex,
            decision: decision
        )
        return decision
    }

    func beginDetailSelfSpinInteraction() {
        guard mode == .sunDetail || mode == .sunTransition else { return }
        detailAutoSpinWorkItem?.cancel()
        detailAutoSpinWorkItem = nil
        capturePresentationAnglesForCurrentDetailDimension()
    }

    func updateDetailSelfSpinInteraction(translation: CGSize) {
        guard mode == .sunDetail || mode == .sunTransition else { return }

        let yawDelta = Float(translation.width) * 0.0105
        let pitchDelta = Float(-translation.height) * 0.0054
        let clampedPitch = max(-0.7, min(0.7, pitchDelta))
        applyDetailSelfSpinAngles(yawDelta: yawDelta, pitchDelta: clampedPitch)
    }

    func endDetailSelfSpinInteraction() {
        guard mode == .sunDetail || mode == .sunTransition else { return }
        animateCurrentDetailDimensionBackToStablePitch()
    }

    func currentSceneInteractionNode() -> SCNNode? {
        if isSunDetailMode {
            return detailDimensionInteractionNodes[currentDetailDimension]
        }
        return conditionGroup
    }

    func currentSceneInteractionAngles(restPitch: Float) -> SCNVector3 {
        guard let node = currentSceneInteractionNode() else {
            return SCNVector3(restPitch, 0, 0)
        }

        let angles = node.presentation.eulerAngles
        return SCNVector3(
            abs(angles.x) < 0.0001 ? restPitch : angles.x,
            angles.y,
            angles.z
        )
    }

    func isInteractiveWeatherNode(_ node: SCNNode?) -> Bool {
        var current = node
        while let value = current {
            if let conditionGroup, value === conditionGroup {
                return true
            }
            if let detailDimensionRingNode, value === detailDimensionRingNode {
                return true
            }
            current = value.parent
        }
        return false
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
        setHomeSceneAccessoryVisibility(isHidden: true, animated: false)
        setHomeNightGlowVisible(false, animated: false)
        sunNode?.opacity = 1
        setSunEmbeddedLightsHidden(false)
    }

    func alignDetailSceneToFront() {
        guard mode == .sunTransition else { return }

        autoSpinSpeed = 0
        applyDisplayGroupRotation(transitionRestRotation)
    }

    func isDisplayGroupFrontFacing(toleranceDegrees: CGFloat = 8) -> Bool {
        let yawDegrees = CGFloat(displayGroupRotation.y) * 180 / .pi
        let normalized = normalizeDegrees(yawDegrees)
        return abs(normalized) <= toleranceDegrees
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
        resumeSunSpinAnimations()
        autoSpinSpeed = 0
        restTiltX = -0.012
        applyDisplayGroupRotation(transitionRestRotation)

        rotatingGroup.removeAllActions()
        root.removeAllActions()
        root.removeAnimation(forKey: "weather_float")
        // Reset root to exact detailRootPosition to clear any float offset before animating back
        root.position = detailRootPosition
        cameraNode.removeAllActions()
        sunNode.removeAllActions()
        detailTitleNode.removeAllActions()
        resetSunBurstState()
        hideDetailDimensionRingForReturn()

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
            guard let self else { return }
            self.applyDisplayGroupRotation(self.mainPresentationRotation)
            if let root = self.sceneRootNode {
                self.attachFloatAnimation(to: root)
            }
            self.applyHomeScenePreset(animated: false)
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
        rotatingGroup.removeAllActions()
        sunNode.removeAllActions()
        root.removeAllActions()
        root.removeAnimation(forKey: "weather_float")
        cameraNode.removeAllActions()
        temperatureNode.removeAllActions()
        detailTitleNode.removeAllActions()
        resetSunBurstState()

        runTemperatureDepartureAnimation(on: temperatureNode)
        runSunExpansionAnimation(on: sunNode)
        runSceneShiftAnimation(root: root, cameraNode: cameraNode, rotatingGroup: rotatingGroup)
        detailTitleNode.opacity = 0

        // Burst 提前触发，与 sun-detail-enter.wav 峰值（t=100ms）对齐
        // 80ms 延迟 + 20ms burstDelay = 100ms 首帧可见
        let burstWorkItem = DispatchWorkItem { [weak self] in
            self?.runSunBurstAnimation()
        }
        burstAnimationWorkItem = burstWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: burstWorkItem)

        let completionWorkItem = DispatchWorkItem { [weak self] in
            self?.restTiltX = -0.004
            self?.autoSpinSpeed = 0
            self?.applyDisplayGroupRotation(self?.transitionRestRotation ?? SCNVector3(0, 0, 0))
            self?.sunModelNode?.eulerAngles = SCNVector3(0, 0, 0)
            self?.detailTitleNode?.eulerAngles = SCNVector3(0, 0, 0)
            self?.pauseSunSpinAnimations()
            self?.showDetailDimensionRingIfNeeded()
            self?.prepareDetailSecondScreen()
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
        autoSpinSpeed = 0
        cancelDetailAutoSpin()
    }

    func resumeAutomaticSpinAfterInteraction() {
        guard mode == .sunDetail || mode == .sunTransition else { return }
        guard isSunDetailMode else { return }
        scheduleDetailAutoSpin()
    }

    func triggerDetailSunTapBurst() {
        guard mode == .sunTransition,
              let root = sceneRootNode,
              let sunRef = sunNode
        else { return }

        resetSunBurstState()

        // Cancel any previous tap burst still animating
        sunTapBurstOverlayNode?.removeFromParentNode()

        let rayCount = WeatherSunDetailTapBurstCore.rayCount
        let totalDuration = WeatherSunDetailTapBurstCore.totalDuration
        let staggerStep = WeatherSunDetailTapBurstCore.staggerStep
        let maxDelay = staggerStep * Double(rayCount - 1)

        // Place overlay at sun center in sceneRootNode-local space, pushed toward camera
        let sunCenterInRoot = sunRef.convertPosition(SCNVector3Zero, to: root)
        let overlayNode = SCNNode()
        overlayNode.position = SCNVector3(
            sunCenterInRoot.x,
            sunCenterInRoot.y,
            sunCenterInRoot.z + WeatherSunDetailTapBurstCore.overlayZOffset
        )
        root.addChildNode(overlayNode)
        sunTapBurstOverlayNode = overlayNode

        overlayNode.runAction(.sequence([
            .wait(duration: maxDelay + totalDuration),
            .run { [weak self] node in
                node.removeFromParentNode()
                if self?.sunTapBurstOverlayNode === node {
                    self?.sunTapBurstOverlayNode = nil
                }
            }
        ]))

        let tapThickness = CGFloat(WeatherSunDetailTapBurstCore.tapRayThickness)
        let flyDist = WeatherSunDetailTapBurstCore.tapOutwardDistance
        let tailFrac = WeatherSunDetailTapBurstCore.tailStartFraction
        let cs = WeatherSunDetailTapBurstCore.crossScale

        for index in 0 ..< rayCount {
            let flatDir = WeatherSunDetailTapBurstCore.planarDirection(index: index, totalCount: rayCount)
            let elevation = Float.random(in: WeatherSunDetailTapBurstCore.tapMinElevation ... WeatherSunDetailTapBurstCore.tapMaxElevation)
            let cosEl = cos(elevation)
            let sinEl = sin(elevation)
            // Hemisphere direction: radial XY component scaled by cosEl, +Z by sinEl
            let dir3D = SIMD3<Float>(flatDir.x * cosEl, flatDir.y * cosEl, sinEl)

            let origLength = Float.random(in: WeatherSunDetailTapBurstCore.tapRayMinLength ... WeatherSunDetailTapBurstCore.tapRayMaxLength)
            let innerOffset = Float.random(in: WeatherSunDetailTapBurstCore.tapMinStartOffset ... WeatherSunDetailTapBurstCore.tapMaxStartOffset)
            let zVar = Float.random(in: WeatherSunDetailTapBurstCore.minZVariation ... WeatherSunDetailTapBurstCore.maxZVariation)
            let rayGeometry = SCNBox(
                width: tapThickness,
                height: CGFloat(origLength),
                length: tapThickness * 1.2,
                chamferRadius: tapThickness * 0.4
            )
            let material = SCNMaterial()
            material.lightingModel = .constant
            material.diffuse.contents = UIColor.black
            material.emission.contents = UIColor(white: 0.0, alpha: 0.0)
            material.isDoubleSided = true
            rayGeometry.firstMaterial = material

            let rayNode = SCNNode(geometry: rayGeometry)
            rayNode.simdOrientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: dir3D)
            // Start collapsed at innerOffset along hemisphere direction
            rayNode.position = SCNVector3(dir3D.x * innerOffset, dir3D.y * innerOffset, zVar + dir3D.z * innerOffset)
            rayNode.opacity = 0
            rayNode.scale = SCNVector3(cs, 0.001, cs)
            overlayNode.addChildNode(rayNode)

            let delay = Double(index) * staggerStep
            // Capture loop variables for closure
            let capturedFlyDist = flyDist
            let capturedInnerOffset = innerOffset
            let capturedOrigLength = origLength
            let capturedZVar = zVar
            let capturedDir3D = dir3D
            let capturedCs = cs

            rayNode.runAction(.sequence([
                .wait(duration: delay),
                SCNAction.customAction(duration: totalDuration) { node, elapsed in
                    let t = Double(elapsed) / totalDuration

                    // Head (outer tip): easeOut from innerOffset outward
                    let headT = Float(WeatherSunDetailTapBurstCore.easeOut(t))
                    let headDist = capturedInnerOffset + headT * capturedFlyDist

                    // Tail (inner tip): stationary until tailFrac, then constant speed
                    let tFloat = Float(t)
                    let tailFracF = Float(tailFrac)
                    let tailT: Float = tFloat < tailFracF ? 0.0 : (tFloat - tailFracF) / (1.0 - tailFracF)
                    let tailDist = capturedInnerOffset + tailT * capturedFlyDist

                    let lineLength = max(0.0, headDist - tailDist)
                    let centerDist = tailDist + lineLength / 2.0

                    node.position = SCNVector3(
                        capturedDir3D.x * centerDist,
                        capturedDir3D.y * centerDist,
                        capturedZVar + capturedDir3D.z * centerDist
                    )
                    let scaleY = capturedOrigLength > 0 ? lineLength / capturedOrigLength : 0.0
                    node.scale = SCNVector3(capturedCs, max(0.001, scaleY), capturedCs)
                    node.opacity = lineLength > 0.05 ? 1.0 : 0.0
                }
            ]))
        }
    }

    private func nearestFrontFacingYaw(from currentYaw: Float) -> Float {
        let fullTurn = Float.pi * 2
        let normalized = fmodf(currentYaw, fullTurn)
        let candidates: [Float] = [0, fullTurn, -fullTurn]
        return candidates.min(by: { abs($0 - normalized) < abs($1 - normalized) }) ?? 0
    }

    private func normalizeDegrees(_ value: CGFloat) -> CGFloat {
        var normalized = value.truncatingRemainder(dividingBy: 360)
        if normalized > 180 { normalized -= 360 }
        if normalized < -180 { normalized += 360 }
        return normalized
    }

    private func showDetailDimensionRingIfNeeded() {
        guard let detailDimensionRingNode else { return }

        cancelDetailAutoSpin()
        setDetailDimensionProgress(selectedDimension: .sun, dragProgress: 0, animated: false)

        detailTitleNode?.removeAllActions()
        detailTitleNode?.opacity = 0
        detailTitleNode?.isHidden = true

        detailDimensionRingNode.removeAllActions()
        detailDimensionRingNode.isHidden = false
        detailDimensionRingNode.opacity = 0

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.18
        detailDimensionRingNode.opacity = 1
        sunNode?.opacity = 0
        setSunEmbeddedLightsHidden(true)
        SCNTransaction.completionBlock = { [weak self] in
            self?.scheduleDetailAutoSpin()
        }
        SCNTransaction.commit()
    }

    private func hideDetailDimensionRingForReturn() {
        cancelDetailAutoSpin()
        setDetailDimensionTitle(WeatherDetailDimension.sun.title)
        setDetailDimensionProgress(selectedDimension: .sun, dragProgress: 0, animated: false)
        detailDimensionSpinNodes.values.forEach { resetDetailDimensionSpinNode($0) }
        detailDimensionTitleNodes.values.forEach { resetDetailDimensionSpinNode($0) }
        detailDimensionRingNode?.removeAllActions()
        detailDimensionRingNode?.opacity = 0
        detailDimensionRingNode?.isHidden = true
        sunNode?.opacity = 1
        setSunEmbeddedLightsHidden(false)
        detailTitleNode?.isHidden = false
        detailTitleNode?.opacity = 1
    }

    private func updateDetailDimensionSelfSpin(
        selectedDimension: WeatherDetailDimension,
        autoSpinEnabled: Bool
    ) {
        for dimension in WeatherDetailDimension.allCases {
            let nodes = [
                detailDimensionSpinNodes[dimension],
                detailDimensionTitleNodes[dimension]
            ].compactMap { $0 }

            nodes.forEach { resetDetailDimensionSpinNode($0) }

            guard dimension == selectedDimension, autoSpinEnabled else { continue }
            nodes.forEach { node in
                attachSunSpin(to: node, animationKey: detailDimensionSpinAnimationKey)
            }
        }
    }

    private func resetDetailDimensionSpinNode(_ node: SCNNode) {
        node.removeAnimation(forKey: detailDimensionSpinAnimationKey)
        node.eulerAngles = SCNVector3Zero
    }

    private func currentDetailSpinNodes() -> [SCNNode] {
        [
            detailDimensionSpinNodes[currentDetailDimension],
            detailDimensionTitleNodes[currentDetailDimension]
        ]
        .compactMap { $0 }
    }

    private func capturePresentationAnglesForCurrentDetailDimension() {
        if let modelNode = detailDimensionSpinNodes[currentDetailDimension] {
            let presentationAngles = modelNode.presentation.eulerAngles
            modelNode.removeAnimation(forKey: detailDimensionSpinAnimationKey)
            modelNode.eulerAngles = presentationAngles
            detailSpinGestureBaseModelAngles = presentationAngles
        }

        if let titleNode = detailDimensionTitleNodes[currentDetailDimension] {
            let presentationAngles = titleNode.presentation.eulerAngles
            titleNode.removeAnimation(forKey: detailDimensionSpinAnimationKey)
            titleNode.eulerAngles = presentationAngles
            detailSpinGestureBaseTitleAngles = presentationAngles
        }
    }

    private func applyDetailSelfSpinAngles(yawDelta: Float, pitchDelta: Float) {
        guard let modelNode = detailDimensionSpinNodes[currentDetailDimension] else { return }
        modelNode.eulerAngles = SCNVector3(
            detailSpinGestureBaseModelAngles.x + pitchDelta,
            detailSpinGestureBaseModelAngles.y + yawDelta,
            0
        )

        if let titleNode = detailDimensionTitleNodes[currentDetailDimension] {
            titleNode.eulerAngles = SCNVector3(
                detailSpinGestureBaseTitleAngles.x + pitchDelta * 0.18,
                detailSpinGestureBaseTitleAngles.y + yawDelta,
                0
            )
        }
    }

    private func animateCurrentDetailDimensionBackToStablePitch() {
        let nodes = currentDetailSpinNodes()
        guard !nodes.isEmpty else { return }

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.22
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeOut)
        SCNTransaction.completionBlock = { [weak self] in
            self?.scheduleDetailAutoSpin()
        }
        for node in nodes {
            node.eulerAngles = SCNVector3(0, node.eulerAngles.y, 0)
        }
        SCNTransaction.commit()
    }

    private func scheduleDetailAutoSpin() {
        guard mode == .sunDetail || mode == .sunTransition else { return }
        cancelDetailAutoSpin()
        updateDetailDimensionSelfSpin(
            selectedDimension: currentDetailDimension,
            autoSpinEnabled: false
        )

        let workItem = DispatchWorkItem { [weak self] in
            self?.updateDetailDimensionSelfSpin(
                selectedDimension: self?.currentDetailDimension ?? .sun,
                autoSpinEnabled: true
            )
        }
        detailAutoSpinWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + secondScreenMotionTuning.idleDelay,
            execute: workItem
        )
    }

    private func cancelDetailAutoSpin() {
        detailAutoSpinWorkItem?.cancel()
        detailAutoSpinWorkItem = nil
        if mode == .sunDetail || mode == .sunTransition {
            updateDetailDimensionSelfSpin(
                selectedDimension: currentDetailDimension,
                autoSpinEnabled: false
            )
        }
    }

    private func updateDetailDimensionPresentation(ringYaw: Float) {
        var nearestDimension = presentedDetailDimension
        var nearestAngle = CGFloat.greatestFiniteMagnitude

        for dimension in WeatherDetailDimension.allCases {
            guard let itemNode = detailDimensionItemNodes[dimension] else { continue }
            let interactionNode = detailDimensionInteractionNodes[dimension]
            let spinNode = detailDimensionSpinNodes[dimension]
            let baseAngle = Float(dimension.rawValue) * detailDimensionAngleStep
            let normalizedAngle = normalizedOrbitAngle(baseAngle + ringYaw)
            let absoluteAngle = CGFloat(abs(normalizedAngle))
            let stepAngle = CGFloat(detailDimensionAngleStep)
            let frontBand = stepAngle * secondScreenMotionTuning.frontBandRatio
            let adjacentBand = stepAngle * secondScreenMotionTuning.adjacentBandRatio

            let scale: CGFloat
            let opacity: CGFloat
            if absoluteAngle <= frontBand {
                let progress = absoluteAngle / max(frontBand, 0.001)
                scale = interpolated(
                    from: secondScreenMotionTuning.frontScale,
                    to: secondScreenMotionTuning.adjacentScale,
                    progress: progress
                )
                opacity = interpolated(
                    from: secondScreenMotionTuning.frontOpacity,
                    to: secondScreenMotionTuning.adjacentOpacity,
                    progress: progress
                )
            } else if absoluteAngle <= adjacentBand {
                let progress = (absoluteAngle - frontBand) / max(adjacentBand - frontBand, 0.001)
                scale = interpolated(
                    from: secondScreenMotionTuning.adjacentScale,
                    to: secondScreenMotionTuning.rearScale,
                    progress: progress
                )
                opacity = interpolated(
                    from: secondScreenMotionTuning.adjacentOpacity,
                    to: secondScreenMotionTuning.rearOpacity,
                    progress: progress
                )
            } else {
                scale = secondScreenMotionTuning.rearScale
                opacity = secondScreenMotionTuning.rearOpacity
            }

            itemNode.eulerAngles = SCNVector3(0, baseAngle, 0)
            interactionNode?.eulerAngles = SCNVector3Zero
            if dimension == .sun, let spinNode {
                setEmbeddedLightsHidden(in: spinNode, isHidden: absoluteAngle > frontBand)
            }
            itemNode.opacity = opacity
            itemNode.scale = SCNVector3(Float(scale), Float(scale), Float(scale))
            itemNode.renderingOrder = Int((10 - absoluteAngle).rounded())

            if absoluteAngle < nearestAngle {
                nearestAngle = absoluteAngle
                nearestDimension = dimension
            }
        }

        if presentedDetailDimension != nearestDimension {
            setPresentedDetailDimension(nearestDimension)
        }
    }

    private func roundedOrbitIndex(for ringYaw: Float) -> Int {
        Int(round(Double(-ringYaw / detailDimensionAngleStep)))
    }

    private func animateDetailOrbit(
        ringNode: SCNNode,
        from startYaw: Float,
        to endYaw: Float,
        settledDimension: WeatherDetailDimension,
        settledOrbitIndex: Int,
        decision: WeatherSecondScreenOrbitDecision
    ) {
        let duration = orbitSettleDuration(for: decision)
        let action = SCNAction.customAction(duration: duration) { [weak self] node, elapsed in
            guard let self else { return }
            let rawProgress = elapsed / CGFloat(max(duration, 0.0001))
            let progress = decision.usesMomentum
                ? self.orbitEaseOutDecay(
                    rawProgress,
                    decayFactor: self.secondScreenMotionTuning.orbitMomentumDecayFactor
                )
                : self.easeOutCubic(rawProgress)
            let yaw = startYaw + Float(progress) * (endYaw - startYaw)
            node.eulerAngles = SCNVector3(0, yaw, 0)
            self.updateDetailDimensionPresentation(ringYaw: yaw)
        }
        let settle = SCNAction.run { [weak self] node in
            guard let self else { return }
            node.eulerAngles = SCNVector3(0, endYaw, 0)
            self.currentDetailDimension = settledDimension
            self.setPresentedDetailDimension(settledDimension)
            self.currentDetailOrbitIndex = settledOrbitIndex
            self.updateDetailDimensionPresentation(ringYaw: endYaw)
            self.updateDetailDimensionSelfSpin(selectedDimension: settledDimension, autoSpinEnabled: false)
            self.scheduleDetailAutoSpin()
            self.endDetailOrbitFeedbackSession()
        }
        ringNode.runAction(.sequence([action, settle]), forKey: detailOrbitMotionActionKey)
    }

    private func orbitSettleDuration(for decision: WeatherSecondScreenOrbitDecision) -> TimeInterval {
        let stepCount = max(abs(decision.stepOffset), 1)
        let duration = secondScreenMotionTuning.orbitSettleBaseDuration
            + Double(stepCount - 1) * secondScreenMotionTuning.orbitSettleTurnDuration
        return min(duration, secondScreenMotionTuning.orbitSettleMaxDuration)
    }

    private func orbitEaseOutDecay(_ value: CGFloat, decayFactor: CGFloat) -> CGFloat {
        let safeValue = min(max(value, 0), 1)
        let safeDecayFactor = max(decayFactor, 0.001)
        return (1 - exp(-safeDecayFactor * safeValue)) / (1 - exp(-safeDecayFactor))
    }

    private func setPresentedDetailDimension(_ dimension: WeatherDetailDimension) {
        if Thread.isMainThread {
            guard presentedDetailDimension != dimension else { return }
            presentedDetailDimension = dimension
            handleDetailOrbitFeedback(for: dimension)
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self, self.presentedDetailDimension != dimension else { return }
            self.presentedDetailDimension = dimension
            self.handleDetailOrbitFeedback(for: dimension)
        }
    }

    private func beginDetailOrbitFeedbackSessionIfNeeded() {
        guard !isDetailOrbitFeedbackSessionActive else { return }
        isDetailOrbitFeedbackSessionActive = true
        lastOrbitFeedbackDimension = presentedDetailDimension
        WeatherHapticPlayer.shared.prepareOrbitCheckpoint()
    }

    private func endDetailOrbitFeedbackSession() {
        isDetailOrbitFeedbackSessionActive = false
        lastOrbitFeedbackDimension = nil
    }

    private func handleDetailOrbitFeedback(for dimension: WeatherDetailDimension) {
        guard isDetailOrbitFeedbackSessionActive else { return }
        guard lastOrbitFeedbackDimension != dimension else { return }

        lastOrbitFeedbackDimension = dimension
        WeatherHapticPlayer.shared.playOrbitCheckpoint()
        WeatherAudioPlayer.shared.playOrbitCheckpoint()
    }

    private func normalizedOrbitAngle(_ angle: Float) -> Float {
        var normalized = angle.truncatingRemainder(dividingBy: Float.pi * 2)
        if normalized > Float.pi {
            normalized -= Float.pi * 2
        }
        if normalized < -Float.pi {
            normalized += Float.pi * 2
        }
        return normalized
    }

    private func interpolated(from start: CGFloat, to end: CGFloat, progress: CGFloat) -> CGFloat {
        start + (end - start) * min(max(progress, 0), 1)
    }

    private func resolvedDetailOrbitIndex(for selectedDimension: WeatherDetailDimension) -> Int {
        let count = WeatherDetailDimension.allCases.count
        let currentNormalized = positiveModulo(currentDetailOrbitIndex, count)
        var delta = selectedDimension.rawValue - currentNormalized
        let halfCount = count / 2

        if delta > halfCount {
            delta -= count
        } else if delta < -halfCount {
            delta += count
        }

        return currentDetailOrbitIndex + delta
    }

    private func positiveModulo(_ value: Int, _ divisor: Int) -> Int {
        let remainder = value % divisor
        return remainder >= 0 ? remainder : remainder + divisor
    }

    private func buildScene() {
        cancelPendingTransitionWork()
        scene.background.contents = UIColor.clear
        scene.rootNode.childNodes.forEach { $0.removeFromParentNode() }
        cameraNode = nil
        sceneRootNode = nil
        detailTitleNode = nil
        detailDimensionRingNode = nil
        detailDimensionItemNodes = [:]
        detailDimensionInteractionNodes = [:]
        detailDimensionSpinNodes = [:]
        detailDimensionTitleNodes = [:]
        sunBurstNode = nil
        sunTapBurstOverlayNode?.removeFromParentNode()
        sunTapBurstOverlayNode = nil
        temperatureNode = nil
        homeSceneAccessoryNode = nil
        homeNightGlowNode = nil
        sunNode = nil
        sunModelNode = nil
        sunBurstRayDirections.removeAll()
        sunBurstRayStartPositions.removeAll()
        sunBurstRayBaseOpacities.removeAll()

        let isDetailMode = mode == .sunDetail
        let isTransitionMode = mode == .sunTransition
        restTiltX = isDetailMode ? -0.004 : -0.012
        autoSpinSpeed = isDetailMode ? secondScreenMotionTuning.autoSpinSpeedRadPerSec : 0

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

            let title = makeSunDetailTitleNode(text: "Sun")
            title.position = detailTitlePosition
            rotatingGroup.addChildNode(title)
            detailTitleNode = title
            attachSunSpin(to: title, animationKey: sunTitleSpinAnimationKey)

            sunNode = sunAssembly
            sunModelNode = sun
        } else if isTransitionMode {
            let sunAssembly = SCNNode()
            sunAssembly.name = "weather_sun_transition_assembly"
            sunAssembly.position = SCNVector3(0, mainSunPositionY, -0.1)

            sun.position = SCNVector3(0, 0, 0)
            // 先于射线渲染并写入深度缓冲，确保太阳完全遮挡后方射线
            // 需递归设置子节点，因为实际几何体在 child nodes 上
            sun.renderingOrder = -1
            sun.enumerateChildNodes { child, _ in child.renderingOrder = -1 }
            sunAssembly.addChildNode(sun)

            let burstNode = makeSunBurstNode()
            burstNode.position = SCNVector3(0, 0, WeatherSunBurstCore.burstZOffset)
            burstNode.renderingOrder = 0
            sunAssembly.addChildNode(burstNode)
            sunBurstNode = burstNode

            rotatingGroup.addChildNode(sunAssembly)

            let title = makeSunDetailTitleNode(text: "Sun")
            title.name = SceneNode.sunTitle
            title.position = detailTitlePosition
            title.opacity = 0
            title.scale = SCNVector3(0.88, 0.88, 0.88)
            rotatingGroup.addChildNode(title)
            detailTitleNode = title
            attachSunSpin(to: title, animationKey: sunTitleSpinAnimationKey)

            sunNode = sunAssembly
            sunModelNode = sun
        } else {
            sun.position = SCNVector3(0, mainSunPositionY, -0.1)
            rotatingGroup.addChildNode(sun)
            sunNode = sun
            sunModelNode = sun
        }

        if mode == .main || mode == .sunTransition {
            let nightGlow = makeHomeNightGlowNode()
            rotatingGroup.addChildNode(nightGlow)
            homeNightGlowNode = nightGlow
            setHomeNightGlowVisible(false, animated: false)
        }

        if isDetailMode || isTransitionMode {
            let dimensionRing = makeDetailDimensionRingNode()
            dimensionRing.opacity = isDetailMode ? 1 : 0
            dimensionRing.isHidden = !isDetailMode
            root.addChildNode(dimensionRing)
            detailDimensionRingNode = dimensionRing

            if isDetailMode {
                sunNode?.opacity = 0
                setSunEmbeddedLightsHidden(true)
                detailTitleNode?.opacity = 0
            }
        }

        if mode == .main || mode == .sunTransition {
            let digits = makeTemperatureNode(text: "\(currentTemperature)")
            // ── 数字位置：Y 值越小越靠下（如需微调往下移，减小 Y 值）──
            digits.position = SCNVector3(0, mainTemperaturePositionY, 0.12)
            rotatingGroup.addChildNode(digits)
            temperatureNode = digits
            applyHomeScenePreset(animated: false)
        }

        if mode != .sunDetail {
            attachFloatAnimation(to: root)
        }
        attachSunPulse(to: sun)
        if mode == .main || mode == .sunTransition {
            attachSunSpin(to: sun, animationKey: sunSpinAnimationKey)
        }
    }

    private func makeSunNode() -> SCNNode {
        ensureSunNodePrototype().clone()
    }

    private func ensureSunNodePrototype() -> SCNNode {
        let cacheKey = "\(mode == .sunDetail ? "detail" : "main").\(sunModelTargetHeight)"
        if let prototype = sunNodePrototypeCache[cacheKey] {
            return prototype
        }

        let prototype = makeSunModelNode() ?? makeFallbackSunNode()
        sunNodePrototypeCache[cacheKey] = prototype
        return prototype
    }

    private func makeFallbackSunNode() -> SCNNode {
        let root = SCNNode()
        root.name = SceneNode.sun

        let sphere = SCNSphere(radius: mode == .sunDetail ? 3.107 : 2.16 * mainSunScale)
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
        if let prototype = temperatureNodePrototypeCache[text] {
            return prototype.clone()
        }

        let prototype: SCNNode
        if let modelNode = makeTemperatureModelNode(text: text) {
            prototype = modelNode
        } else {
            prototype = makeFallbackTemperatureNode(text: text)
        }
        temperatureNodePrototypeCache[text] = prototype
        return prototype.clone()
    }

    private func makeSunDetailTitleNode(text: String) -> SCNNode {
        let container = SCNNode()
        container.name = SceneNode.sunTitle
        let frontTitle = makeSingleSunDetailTitleNode(text: text)
        frontTitle.position.z = 0
        container.addChildNode(frontTitle)

        container.eulerAngles = SCNVector3(0, 0, 0)
        container.castsShadow = false
        return container
    }

    private func makeDetailDimensionRingNode() -> SCNNode {
        let ring = SCNNode()
        ring.name = "weather_detail_dimension_ring"
        ring.position = SCNVector3(0, 0, detailSunPosition.z - detailDimensionRingRadius)

        for dimension in WeatherDetailDimension.allCases {
            let angle = Float(dimension.rawValue) * detailDimensionAngleStep
            let item = SCNNode()
            item.name = "weather_detail_dimension_\(dimension.title.lowercased())"
            item.position = SCNVector3(
                sin(angle) * detailDimensionRingRadius,
                0,
                cos(angle) * detailDimensionRingRadius
            )
            item.eulerAngles = SCNVector3(0, angle, 0)

            let model = makeDetailDimensionModelNode(for: dimension)
            model.position = SCNVector3(0, 0, 0)
            detailDimensionSpinNodes[dimension] = model

            let interactionContainer = SCNNode()
            interactionContainer.name = "weather_detail_interaction_\(dimension.title.lowercased())"

            let modelContainer = SCNNode()
            modelContainer.position = SCNVector3(0, detailSunPosition.y, 0)
            modelContainer.addChildNode(model)
            interactionContainer.addChildNode(modelContainer)

            let title = makeSunDetailTitleNode(text: dimension.title)
            title.position = SCNVector3(0, detailTitlePosition.y, 0)
            detailDimensionTitleNodes[dimension] = title
            interactionContainer.addChildNode(title)
            detailDimensionInteractionNodes[dimension] = interactionContainer
            item.addChildNode(interactionContainer)
            detailDimensionItemNodes[dimension] = item

            ring.addChildNode(item)
        }

        updateDetailDimensionPresentation(ringYaw: 0)

        return ring
    }

    private func makeDetailDimensionModelNode(for dimension: WeatherDetailDimension) -> SCNNode {
        let targetHeight = detailDimensionModelTargetHeight()

        switch dimension {
        case .sun:
            let node = makeSunNode()
            if mode != .sunDetail {
                multiplyScale(of: node, by: detailSunScale)
            }
            return node
        case .cloud:
            return makeNormalizedWeatherAssetNode(named: "cloud", targetHeight: targetHeight)
        case .air:
            return makeNormalizedWeatherAssetNode(named: "air", targetHeight: targetHeight)
        case .moon:
            return makeMoonCrescentAssetNode(targetHeight: targetHeight, wrapsModelForSpin: true) ?? makeSunNode()
        case .temperature:
            let node = makeTemperatureNode(text: "\(currentTemperature)")
            scaleNodeToHeight(node, targetHeight: targetHeight)
            return node
        case .precipitation:
            let node = makeNormalizedWeatherAssetNode(named: "rain", targetHeight: targetHeight)
            multiplyScale(of: node, by: detailRainScaleCorrection)
            return node
        }
    }

    private func detailDimensionModelTargetHeight() -> Float {
        if mode == .sunDetail {
            return 6.192
        }
        return 4.02 * Float(mainSunScale) * detailSunScale
    }

    private func makeNormalizedWeatherAssetNode(named name: String, targetHeight: Float) -> SCNNode {
        guard let node = makeWeatherAssetNode(
            named: name,
            fileExtension: "usdz",
            targetHeight: targetHeight
        ) else {
            return makeSunNode()
        }

        node.name = "weather_detail_\(name)"
        return node
    }

    private func applyHomeScenePreset(animated: Bool) {
        guard mode == .main || mode == .sunTransition else { return }
        guard let rotatingGroup = conditionGroup else { return }

        let accessory = makeHomeSceneAccessoryNode(for: currentHomeScenePreset)
        accessory?.opacity = animated ? 0 : 1

        let previousAccessory = homeSceneAccessoryNode
        homeSceneAccessoryNode = accessory
        if let accessory {
            rotatingGroup.addChildNode(accessory)
        }

        let sunOpacity: CGFloat = currentHomeScenePreset.showsSunPrimary ? 1 : 0
        setSunEmbeddedLightsHidden(!currentHomeScenePreset.showsSunPrimary)
        setHomeNightGlowVisible(currentHomeScenePreset.usesDarkBackground, animated: animated)
        if animated {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.22
            previousAccessory?.opacity = 0
            accessory?.opacity = 1
            sunNode?.opacity = sunOpacity
            SCNTransaction.completionBlock = {
                previousAccessory?.removeFromParentNode()
            }
            SCNTransaction.commit()
        } else {
            previousAccessory?.removeFromParentNode()
            sunNode?.opacity = sunOpacity
        }
    }

    private func makeHomeNightGlowNode() -> SCNNode {
        let glow = SCNLight()
        glow.type = .omni
        glow.intensity = 0
        glow.color = UIColor(red: 0.86, green: 0.92, blue: 1.0, alpha: 1)
        glow.attenuationStartDistance = 0
        glow.attenuationEndDistance = 26

        let node = SCNNode()
        node.name = "weather_home_night_glow"
        node.light = glow
        node.position = SCNVector3(0, mainSunPositionY, -0.1)
        node.isHidden = true
        return node
    }

    private func setHomeNightGlowVisible(_ isVisible: Bool, animated: Bool) {
        guard let homeNightGlowNode,
              let light = homeNightGlowNode.light else {
            return
        }

        if isVisible {
            homeNightGlowNode.isHidden = false
        }

        SCNTransaction.begin()
        SCNTransaction.animationDuration = animated ? 0.22 : 0
        light.intensity = isVisible ? homeNightGlowIntensity : 0
        SCNTransaction.completionBlock = {
            if !isVisible {
                homeNightGlowNode.isHidden = true
            }
        }
        SCNTransaction.commit()
    }

    private func setSunEmbeddedLightsHidden(_ isHidden: Bool) {
        guard let sunNode else { return }
        setEmbeddedLightsHidden(in: sunNode, isHidden: isHidden)
    }

    private func setEmbeddedLightsHidden(in node: SCNNode, isHidden: Bool) {
        if node.light != nil {
            node.isHidden = isHidden
        }
        node.enumerateChildNodes { child, _ in
            if child.light != nil {
                child.isHidden = isHidden
            }
        }
    }

    private func setHomeSceneAccessoryVisibility(isHidden: Bool, animated: Bool) {
        guard let homeSceneAccessoryNode else { return }
        let targetOpacity: CGFloat = isHidden ? 0 : 1
        if animated {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.18
            homeSceneAccessoryNode.opacity = targetOpacity
            SCNTransaction.commit()
        } else {
            homeSceneAccessoryNode.opacity = targetOpacity
        }
        homeSceneAccessoryNode.isHidden = isHidden
    }

    private func makeHomeSceneAccessoryNode(for preset: WeatherHomeScenePreset) -> SCNNode? {
        switch preset {
        case .sunny:
            return nil
        case .sunCloudy:
            return makeHomeAttachedCloudNode(named: "cloudy")
        case .sunCloudy2:
            return makeHomeAttachedCloudNode(named: "cloudy2")
        case .moon:
            return makeHomeMoonSceneNode(cloudName: nil)
        case .moonCloudy:
            return makeHomeMoonSceneNode(cloudName: "cloudy")
        case .moonCloudy2:
            return makeHomeMoonSceneNode(cloudName: "cloudy2")
        case .cloud:
            return makeHomeStandaloneCloudNode()
        }
    }

    private func makeHomeMoonSceneNode(cloudName: String?) -> SCNNode? {
        let container = SCNNode()
        container.name = "weather_home_moon_scene"

        guard let moon = makeMoonCrescentAssetNode(targetHeight: homePrimaryModelHeight, wrapsModelForSpin: false) else {
            return nil
        }
        moon.name = "weather_home_moon"
        moon.position = SCNVector3(0, mainSunPositionY, -0.1)
        container.addChildNode(moon)

        if let cloudName,
           let cloud = makeHomeAttachedCloudNode(named: cloudName) {
            container.addChildNode(cloud)
        }

        return container
    }

    private func makeMoonCrescentAssetNode(targetHeight: Float, wrapsModelForSpin: Bool) -> SCNNode? {
        guard let moon = makeWeatherAssetNode(named: "moon", fileExtension: "usdz", targetHeight: targetHeight) else {
            return nil
        }

        // The USDZ faces forward as a half-lit moon; yaw it so the front reads as a crescent.
        moon.eulerAngles = moonCrescentModelEulerAngles

        guard wrapsModelForSpin else {
            return moon
        }

        let container = SCNNode()
        container.name = "weather_detail_moon"
        container.addChildNode(moon)
        return container
    }

    private func makeHomeAttachedCloudNode(named name: String) -> SCNNode? {
        guard let cloud = makeWeatherAssetNode(named: name, fileExtension: "usdz", targetHeight: homeAttachedCloudHeight) else {
            return nil
        }
        cloud.name = "weather_home_attached_\(name)"
        cloud.position = SCNVector3(1.22, mainSunPositionY - 0.70, 0.54)
        cloud.eulerAngles = SCNVector3(-0.03, -0.18, 0.02)
        return cloud
    }

    private func makeHomeStandaloneCloudNode() -> SCNNode? {
        guard let cloud = makeWeatherAssetNode(named: "cloud", fileExtension: "usdz", targetHeight: homeStandaloneCloudHeight) else {
            return nil
        }
        cloud.name = "weather_home_cloud"
        cloud.position = SCNVector3(0, mainSunPositionY - 0.28, -0.06)
        cloud.eulerAngles = SCNVector3(-0.02, 0.12, 0.01)
        return cloud
    }

    private var homePrimaryModelHeight: Float {
        4.02 * Float(mainSunScale)
    }

    private var homeAttachedCloudHeight: Float {
        3.08
    }

    private var homeStandaloneCloudHeight: Float {
        4.2
    }

    private func makeWeatherAssetNode(named name: String, fileExtension: String, targetHeight: Float) -> SCNNode? {
        ensureWeatherAssetPrototype(named: name, fileExtension: fileExtension, targetHeight: targetHeight)?.clone()
    }

    private func ensureWeatherAssetPrototype(named name: String, fileExtension: String, targetHeight: Float) -> SCNNode? {
        let cacheKey = "\(name).\(fileExtension).\(targetHeight)"
        if let prototype = weatherAssetPrototypeCache[cacheKey] {
            return prototype
        }

        guard let payload = loadNormalizedModelNode(
            named: name,
            fileExtension: fileExtension,
            targetHeight: targetHeight
        ) else {
            return nil
        }

        applyWeatherAssetMaterialCorrection(named: name, to: payload.node)

        weatherAssetPrototypeCache[cacheKey] = payload.node
        return payload.node
    }

    private func multiplyScale(of node: SCNNode, by multiplier: Float) {
        node.scale = SCNVector3(
            node.scale.x * multiplier,
            node.scale.y * multiplier,
            node.scale.z * multiplier
        )
    }

    private func scaleNodeToHeight(_ node: SCNNode, targetHeight: Float) {
        let (minBounds, maxBounds) = node.boundingBox
        let height = maxBounds.y - minBounds.y
        guard height > 0.0001 else { return }
        multiplyScale(of: node, by: targetHeight / height)
    }

    private func makeSunBurstNode() -> SCNNode {
        let container = SCNNode()
        container.name = SceneNode.sunBurst
        container.opacity = 0
        container.isHidden = true

        for index in 0 ..< SunBurstTuning.rayCount {
            // XY 平面方位角均匀分布，每个方向都有射线，叠加小随机抖动避免过于规则
            let baseAzimuth = Float(index) / Float(SunBurstTuning.rayCount) * Float.pi * 2
            let azimuthJitter = Float.random(in: -0.18 ... 0.18)
            let azimuth = baseAzimuth + azimuthJitter
            // 仅后半球采样（z≤0），避免射线向相机方向延伸穿透太阳正面
            let u = Float.random(in: -1 ... 0)
            let elevation = asin(u)
            let planarRadius = cos(elevation)
            let direction = SIMD3<Float>(
                planarRadius * cos(azimuth),
                planarRadius * sin(azimuth),
                sin(elevation)              // Z 轴方向 = 深度
            )

            let lengthRoll = Float.random(in: 0 ... 1)
            let length: Float
            switch lengthRoll {
            case ..<0.20:
                length = Float.random(in: 2.0 ... 3.0)
            case ..<0.80:
                length = Float.random(in: 3.0 ... 4.8)
            default:
                length = Float.random(in: 4.8 ... 6.5)
            }

            let jitter = Float.random(in: SunBurstTuning.minJitter ... SunBurstTuning.maxJitter)

            container.addChildNode(
                makeSunBurstRayNode(
                    direction: direction,
                    length: length,
                    jitter: jitter
                )
            )
        }

        return container
    }

    private func makeSunBurstRayNode(direction: SIMD3<Float>, length: Float, jitter: Float) -> SCNNode {
        let normalizedDirection = simd_normalize(direction)
        // 后半球采样 z∈[-1,0]，线性重映射到 [-1,+1] 供颜色/厚度函数使用
        // z=0（赤道，可见）→ colorZ=+1（近黑），z=-1（深后，隐藏）→ colorZ=-1（近白）
        let colorZ = normalizedDirection.z * 2 + 1
        let thickness = CGFloat(SunBurstTuning.thickness(forZ: colorZ)) * 1.5
        let rayLength = CGFloat(length)
        let rayGeometry = SCNBox(
            width: thickness,
            height: rayLength,
            length: thickness * 1.35,
            chamferRadius: thickness * 0.4
        )

        let material = SCNMaterial()
        configureBaseRayMaterial(material, for: colorZ)
        material.isDoubleSided = true
        rayGeometry.firstMaterial = material

        let rayNode = SCNNode(geometry: rayGeometry)
        let halfLength = length / 2
        let distanceFromCenter = SunBurstTuning.sunRadius * jitter + halfLength
        let placement = normalizedDirection * distanceFromCenter
        rayNode.position = SCNVector3(placement.x, placement.y, placement.z)
        rayNode.simdOrientation = simd_quatf(
            from: SIMD3<Float>(0, 1, 0),
            to: normalizedDirection
        )
        rayNode.scale = SCNVector3(1, 1, 1)
        rayNode.opacity = 1
        sunBurstRayDirections[ObjectIdentifier(rayNode)] = SCNVector3(
            normalizedDirection.x,
            normalizedDirection.y,
            normalizedDirection.z
        )
        sunBurstRayStartPositions[ObjectIdentifier(rayNode)] = rayNode.position
        sunBurstRayBaseOpacities[ObjectIdentifier(rayNode)] = 1
        return rayNode
    }

    private func makeSingleSunDetailTitleNode(text: String) -> SCNNode {
        let textGeometry = SCNText(string: text, extrusionDepth: 1.8)
        textGeometry.flatness = 0.06
        textGeometry.font = UIFont.systemFont(ofSize: 9.2, weight: .black)
        textGeometry.chamferRadius = 0.10

        let front = SCNMaterial()
        front.lightingModel = .physicallyBased
        front.diffuse.contents = UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)
        front.metalness.contents = Float(0.26)
        front.roughness.contents = Float(0.50)
        front.specular.contents = UIColor(white: 0.70, alpha: 1)
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
        node.scale = SCNVector3(0.1088, 0.1088, 0.1088)
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
        guard let payload = loadNormalizedModelNode(named: "sun", fileExtension: "obj", targetHeight: sunModelTargetHeight) else {
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

    private var sunModelTargetHeight: Float {
        mode == .sunDetail ? 6.192 : 4.02 * Float(mainSunScale)
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

    private struct WeatherAssetMaterialCorrection {
        let diffuseContents: Any
        let normalTextureName: String?
        let metalness: Float
        let roughness: Float
    }

    private func applyWeatherAssetMaterialCorrection(named name: String, to node: SCNNode) {
        guard let correction = weatherAssetMaterialCorrection(named: name) else {
            return
        }

        let normalTextureURL = correction.normalTextureName.flatMap {
            Bundle.main.url(forResource: $0, withExtension: "png", subdirectory: weatherDataSubdirectory)
        }

        node.enumerateChildNodes { child, _ in
            guard let geometry = child.geometry else { return }
            let material = SCNMaterial()
            material.lightingModel = .physicallyBased
            material.diffuse.contents = correction.diffuseContents
            material.normal.contents = normalTextureURL
            material.metalness.contents = correction.metalness
            material.roughness.contents = correction.roughness
            material.emission.contents = UIColor(white: 0, alpha: 0)
            material.isDoubleSided = true
            geometry.materials = Array(repeating: material, count: max(geometry.materials.count, 1))
        }
    }

    private func weatherAssetMaterialCorrection(named name: String) -> WeatherAssetMaterialCorrection? {
        switch name {
        case "moon":
            guard let baseColorURL = Bundle.main.url(
                forResource: "moon_baseColor",
                withExtension: "png",
                subdirectory: weatherDataSubdirectory
            ) else {
                return nil
            }
            return WeatherAssetMaterialCorrection(
                diffuseContents: baseColorURL,
                normalTextureName: "moon_normal",
                metalness: 0,
                roughness: 0.94
            )
        case "cloud":
            return WeatherAssetMaterialCorrection(
                diffuseContents: UIColor(red: 0.13, green: 0.13, blue: 0.14, alpha: 1),
                normalTextureName: "cloud_normal",
                metalness: 0,
                roughness: 0.98
            )
        case "cloudy":
            return WeatherAssetMaterialCorrection(
                diffuseContents: UIColor(red: 0.13, green: 0.13, blue: 0.14, alpha: 1),
                normalTextureName: "cloudy_normal",
                metalness: 0,
                roughness: 0.98
            )
        case "cloudy2":
            return WeatherAssetMaterialCorrection(
                diffuseContents: UIColor(red: 0.13, green: 0.13, blue: 0.14, alpha: 1),
                normalTextureName: "cloudy2_normal",
                metalness: 0,
                roughness: 0.98
            )
        case "air":
            return WeatherAssetMaterialCorrection(
                diffuseContents: UIColor(red: 0.12, green: 0.12, blue: 0.13, alpha: 1),
                normalTextureName: "air_normal",
                metalness: 0,
                roughness: 0.99
            )
        case "rain":
            return WeatherAssetMaterialCorrection(
                diffuseContents: UIColor(red: 0.15, green: 0.15, blue: 0.16, alpha: 1),
                normalTextureName: "rain_normal",
                metalness: 0,
                roughness: 0.99
            )
        default:
            return nil
        }
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
        material.isDoubleSided      = true
        material.writesToDepthBuffer = true        // 确保遮挡后方射线
        material.readsFromDepthBuffer = true
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
        burstAnimationWorkItem?.cancel()
        burstAnimationWorkItem = nil
    }

    // MARK: - 入场旋转动画（静止2秒 → 转4圈 → 正面停止）

    private func pauseSunSpinAnimations() {
        // 移除 CAAnimation（而非暂停），让 model layer eulerAngles 生效
        sunModelNode?.removeAnimation(forKey: sunSpinAnimationKey)
        detailTitleNode?.removeAnimation(forKey: sunTitleSpinAnimationKey)
    }

    private func resumeSunSpinAnimations() {
        sunModelNode?.animationPlayer(forKey: sunSpinAnimationKey)?.paused = false
        detailTitleNode?.animationPlayer(forKey: sunTitleSpinAnimationKey)?.paused = false
    }

    private func scheduleEntrySpinAnimation() {
        entrySpinWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.runEntrySpinAnimation()
        }
        entrySpinWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: workItem)
    }

    private func runEntrySpinAnimation() {
        guard let rotatingGroup = conditionGroup else { return }
        isPlayingEntryAnimation = true

        let startAngles = rotatingGroup.eulerAngles
        let totalYawRotation = -Float.pi * 2 * 2  // 2圈向左
        let endAngles = SCNVector3(
            startAngles.x,
            startAngles.y + totalYawRotation,
            startAngles.z
        )
        let spinDuration: TimeInterval = 60.0  // 30秒/圈 × 2圈，缓慢匀速

        let spinAction = makeEulerAnglesAction(
            from: startAngles,
            to: endAngles,
            duration: spinDuration,
            easing: { $0 }  // 线性匀速
        )

        rotatingGroup.runAction(spinAction) { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                // 2圈转完，归零使 Sun 文字面向 0°
                self.isPlayingEntryAnimation = false
                self.applyDisplayGroupRotation(self.transitionRestRotation)
            }
        }
    }

    func cancelEntryAnimation() {
        entrySpinWorkItem?.cancel()
        entrySpinWorkItem = nil
        if isPlayingEntryAnimation {
            conditionGroup?.removeAllActions()
            isPlayingEntryAnimation = false
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
        let moveToDest = SCNAction.move(to: detailSunPosition, duration: Self.sunDetailTransitionDuration)
        moveToDest.timingMode = .easeInEaseOut

        let scaleToDest = makeScaleAction(
            from: node.scale,
            to: SCNVector3(detailSunScale, detailSunScale, detailSunScale),
            duration: Self.sunDetailTransitionDuration,
            easing: easeInOutCubic
        )

        node.runAction(.group([moveToDest, scaleToDest]))
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

        node.runAction(.group([moveAction, scaleAction]))
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
        // Animate root to the float operating center (y=0) instead of mainRootPosition (y=-1.94).
        // The float animation is non-additive and operates at absolute y ∈ [-0.08, +0.08], so
        // ending at y=0 ensures attachFloatAnimation starts without a visible jump.
        let rootMove = SCNAction.move(
            to: SCNVector3(0, 0, 0),
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
        // 标题显示使用固定时长，而非按比例计算
        // 入场速度缩短后（0.25s），保持标题出场时机不变，避免太快看不清
        let revealDelay: TimeInterval = 0.06   // 固定 60ms 延迟（原 0.38×0.17≈64ms）
        let revealDuration: TimeInterval = 0.08 // 固定 80ms 时长（原 0.38×0.20≈76ms）

        let scaleAction = makeScaleAction(
            from: node.scale,
            to: SCNVector3(1, 1, 1),
            duration: revealDuration,
            easing: easeOutCubic
        )

        let fadeAction = SCNAction.fadeOpacity(to: 1, duration: revealDuration)
        fadeAction.timingMode = .easeOut

        node.position = detailTitlePosition

        node.runAction(
            .sequence([
                .wait(duration: revealDelay),
                .group([scaleAction, fadeAction])
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
        sunBurstNode.opacity = 1

        // 与点击太阳效果相同：前端 easeOut 飞出，后端延迟追赶，两端相遇后线段消失
        let burstDelay: TimeInterval = 0.02
        let burstFlyDuration: TimeInterval = 0.38
        let tailFrac: Float = 0.50   // 后端在 50% 进度后开始追赶（比前端快，线段更长）

        for rayNode in sunBurstNode.childNodes {
            // 初始状态：折叠不可见，80% 黑色 / 20% 灰色
            rayNode.scale = SCNVector3(1, 0.001, 1)
            rayNode.opacity = 0
            if let material = rayNode.geometry?.firstMaterial {
                let isGray = Float.random(in: 0..<1) < 0.4
                material.diffuse.contents = isGray ? UIColor(white: 0.55, alpha: 1) : UIColor.black
            }

            let direction = rayDirection(for: rayNode)
            let dir3D = SIMD3<Float>(direction.x, direction.y, direction.z)
            let startPos = initialRayPosition(for: rayNode)
            let startPosSIMD = SIMD3<Float>(startPos.x, startPos.y, startPos.z)

            let rayLength: Float
            if let box = rayNode.geometry as? SCNBox {
                rayLength = Float(box.height)
            } else {
                rayLength = 3.0
            }

            // innerOffset：射线内端到 burstNode 中心的距离
            // 同时用球面交叉公式确保内端点 ≥ 太阳球面（避免线段起点在太阳内部）
            // burstNode 位于 sunAssembly (0,0,burstZOffset)，太阳球半径 sunRadius
            // 沿 dir3D 方向到球面的距离：t = -oz*d.z + sqrt(R²- oz²*(dx²+dy²))
            let oz = SunBurstTuning.burstZOffset    // -1.22
            let sunR = SunBurstTuning.sunRadius      // 2.44
            let planarSq: Float = dir3D.x * dir3D.x + dir3D.y * dir3D.y
            let discriminant: Float = sunR * sunR - oz * oz * planarSq
            let sphereSurfaceDist: Float = (-oz) * dir3D.z + sqrt(max(0, discriminant))
            let rawInnerOffset = simd_length(startPosSIMD) - rayLength / 2
            let innerOffset = max(rawInnerOffset, sphereSurfaceDist + 0.05)
            let flyDist = SunBurstTuning.outwardDistance(forLength: rayLength) * 7
            let rayDelay = burstDelay + SunBurstTuning.delayOffset(forZ: direction.z * 2 + 1)

            let capturedDir = dir3D
            let capturedInnerOffset = innerOffset
            let capturedFlyDist = flyDist
            let capturedOrigLength = rayLength
            let capturedTailFrac = tailFrac

            rayNode.runAction(.sequence([
                .wait(duration: rayDelay),
                SCNAction.customAction(duration: burstFlyDuration) { node, elapsed in
                    let t = Float(elapsed) / Float(burstFlyDuration)

                    // 前端（外端）：三次方 easeOut 向外飞出
                    let eased: Float = 1 - pow(1 - min(t, 1), 3)
                    let headDist = capturedInnerOffset + eased * capturedFlyDist

                    // 后端（内端）：延迟到 tailFrac 后匀速追赶，追上后线段消失
                    let tailT: Float = t < capturedTailFrac ? 0 : (t - capturedTailFrac) / (1 - capturedTailFrac)
                    let tailDist = capturedInnerOffset + tailT * capturedFlyDist

                    let lineLength = max(0, headDist - tailDist)
                    let centerDist = tailDist + lineLength / 2

                    node.position = SCNVector3(
                        capturedDir.x * centerDist,
                        capturedDir.y * centerDist,
                        capturedDir.z * centerDist
                    )
                    let scaleY = capturedOrigLength > 0 ? lineLength / capturedOrigLength : 0.001
                    node.scale = SCNVector3(1, max(0.001, scaleY), 1)
                    node.opacity = lineLength > 0.05 ? 1.0 : 0.0
                },
                .run { node in
                    node.opacity = 0
                    node.scale = SCNVector3(1, 0.001, 1)
                }
            ]))
        }

        // 全部射线结束后隐藏容器
        let cleanupDelay = burstDelay + SunBurstTuning.layerDelayStep * 3 + burstFlyDuration + 0.05
        sunBurstNode.runAction(.sequence([
            .wait(duration: cleanupDelay),
            .run { node in
                node.opacity = 0
                node.isHidden = true
            }
        ]))
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
            to: SCNVector3(0.02, -0.05, 0.01),
            duration: 0.38,
            easing: easeOutCubic
        )

        let fadeAction = SCNAction.fadeOpacity(to: 1, duration: 0.26)
        fadeAction.timingMode = .easeOut

        node.runAction(.group([moveAction, scaleAction, rotationAction, fadeAction]))
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
            let dir = rayDirection(for: rayNode)
            let dirSIMD = SIMD3<Float>(dir.x, dir.y, dir.z)
            let safeDir = simd_length(dirSIMD) > 0.001 ? simd_normalize(dirSIMD) : SIMD3<Float>(0, 1, 0)
            rayNode.simdOrientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: safeDir)
            if let material = rayNode.geometry?.firstMaterial {
                configureBaseRayMaterial(material, for: dir.z * 2 + 1)
            }
        }
    }

    private func configureBaseRayMaterial(_ material: SCNMaterial, for z: Float) {
        material.lightingModel = .constant
        material.diffuse.contents = UIColor(
            white: CGFloat(SunBurstTuning.colorWhite(forZ: z)),
            alpha: CGFloat(SunBurstTuning.materialAlpha(forZ: z))
        )
        material.emission.contents = UIColor(white: 0.0, alpha: 0.0)
        material.metalness.contents = Float(0)
        material.roughness.contents = Float(1)
    }

    private func applyDetailTapAppearance(to rayNode: SCNNode) {
        guard let material = rayNode.geometry?.firstMaterial else { return }

        material.lightingModel = .constant
        material.diffuse.contents = UIColor(white: 0.98, alpha: 0.94)
        material.emission.contents = UIColor(white: 1.0, alpha: 0.10)
        material.metalness.contents = Float(0)
        material.roughness.contents = Float(1)
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

    private func updateTemperature(animated: Bool) {
        guard mode == .main || mode == .sunTransition else { return }
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
        // Start at the midpoint of the oscillation cycle (offset = 0) to avoid
        // a sudden dip when the animation is re-attached after a transition.
        animation.timeOffset = animation.duration / 2
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
        spin.byValue = -Float.pi * 2
        spin.isAdditive = true
        spin.duration = TimeInterval((Float.pi * 2) / abs(secondScreenMotionTuning.autoSpinSpeedRadPerSec))
        spin.repeatCount = .infinity
        spin.timingFunction = CAMediaTimingFunction(name: .linear)
        node.addAnimation(spin, forKey: animationKey)
    }

}
