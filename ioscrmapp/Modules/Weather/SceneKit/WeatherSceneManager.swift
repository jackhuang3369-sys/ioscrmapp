import SceneKit
import SwiftUI
import UIKit

final class WeatherSceneManager: ObservableObject {

    private(set) var scene: SCNScene
    private(set) var conditionGroup: SCNNode?
    private(set) var restTiltX: Float = -0.012
    private(set) var currentTemperature: Int

    private var temperatureNode: SCNNode?
    private let weatherDataSubdirectory = "WeatherData"

    init(temperature: Int = MockWeatherData.today.temperature) {
        self.scene = SCNScene()
        self.currentTemperature = temperature
        buildScene()
    }

    func setTemperature(_ temperature: Int, animated: Bool) {
        currentTemperature = temperature
        updateTemperature(animated: animated)
    }

    func syncDisplayGroupRotation(to angles: SCNVector3) {
    }

    private func buildScene() {
        scene.background.contents = UIColor.clear
        scene.rootNode.childNodes.forEach { $0.removeFromParentNode() }

        let camera = SCNCamera()
        camera.fieldOfView = 31
        camera.zNear = 0.1
        camera.zFar = 120

        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0.02, 20.8)
        scene.rootNode.addChildNode(cameraNode)

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 700
        ambient.color = UIColor(white: 0.85, alpha: 1)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        let key = SCNLight()
        key.type = .directional
        key.intensity = 1200
        key.color = UIColor(red: 1.0, green: 0.96, blue: 0.90, alpha: 1)
        let keyNode = SCNNode()
        keyNode.light = key
        keyNode.eulerAngles = SCNVector3(-0.4, 0.55, 0)
        scene.rootNode.addChildNode(keyNode)

        let rim = SCNLight()
        rim.type = .directional
        rim.intensity = 420
        rim.color = UIColor(red: 0.92, green: 0.94, blue: 1.0, alpha: 1)
        let rimNode = SCNNode()
        rimNode.light = rim
        rimNode.eulerAngles = SCNVector3(0.35, -.pi + 0.3, 0)
        scene.rootNode.addChildNode(rimNode)

        let root = SCNNode()
        root.name = "weather_root"
        root.position = SCNVector3(0, -1.82, 0)
        scene.rootNode.addChildNode(root)

        let rotatingGroup = SCNNode()
        rotatingGroup.name = "weather_rotating_group"
        root.addChildNode(rotatingGroup)
        conditionGroup = rotatingGroup

        let sun = makeSunNode()
        sun.position = SCNVector3(0, 3.46, -0.1)
        rotatingGroup.addChildNode(sun)

        let digits = makeTemperatureNode(text: "\(currentTemperature)")
        digits.position = SCNVector3(0, -2.0, 0.12)
        rotatingGroup.addChildNode(digits)
        temperatureNode = digits

        attachFloatAnimation(to: root)
        attachSunPulse(to: sun)
        attachSunSpin(to: sun)
    }

    private func makeSunNode() -> SCNNode {
        if let loadedSun = makeSunModelNode() {
            return loadedSun
        }

        return makeFallbackSunNode()
    }

    private func makeFallbackSunNode() -> SCNNode {
        let root = SCNNode()

        let sphere = SCNSphere(radius: 2.16)
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
        let (minBounds, maxBounds) = node.boundingBox
        let width = maxBounds.x - minBounds.x
        let height = maxBounds.y - minBounds.y
        node.pivot = SCNMatrix4MakeTranslation(minBounds.x + width / 2, minBounds.y + height / 2, 0)
        node.scale = SCNVector3(0.6, 0.6, 0.6)
        node.eulerAngles = SCNVector3(0.02, -0.05, 0.01)
        return node
    }

    private func makeSunModelNode() -> SCNNode? {
        guard let payload = loadNormalizedModelNode(named: "sun", fileExtension: "obj", targetHeight: 4.02) else {
            return nil
        }

        let root = SCNNode()
        let model = payload.node
        model.name = SceneNode.sun
        model.opacity = 0.97
        model.eulerAngles = SCNVector3(0.0, 0.08, 0.0)
        applySunMaterial(to: model)
        root.addChildNode(model)

        let glow = SCNLight()
        glow.type = .omni
        glow.intensity = 700
        glow.color = UIColor(red: 1.0, green: 0.44, blue: 0.28, alpha: 1)
        glow.attenuationStartDistance = 0
        glow.attenuationEndDistance = 26

        let glowNode = SCNNode()
        glowNode.light = glow
        root.addChildNode(glowNode)

        return root
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
        guard let payload = loadNormalizedModelNode(named: digitName, fileExtension: "obj", targetHeight: 6.15) else {
            return nil
        }

        applyTemperatureDigitMaterial(to: payload.node)
        payload.node.name = "digit_\(digitName)"
        return (payload.node, payload.size.x)
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
        guard let textureURL = Bundle.main.url(forResource: "texture", withExtension: "png", subdirectory: weatherDataSubdirectory),
              let image = UIImage(contentsOfFile: textureURL.path) else {
            return
        }

        node.enumerateChildNodes { child, _ in
            guard let geometry = child.geometry else { return }
            let material = SCNMaterial()
            material.lightingModel = .physicallyBased
            material.diffuse.contents = image
            material.emission.contents = image
            material.metalness.contents = Float(0.0)
            material.roughness.contents = Float(0.72)
            material.isDoubleSided = true
            geometry.materials = [material]
        }
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
        material.lightingModel = .physicallyBased
        material.diffuse.contents = UIColor(red: 0.10, green: 0.10, blue: 0.11, alpha: 1)
        material.metalness.contents = Float(0.52)
        material.roughness.contents = Float(0.22)
        material.specular.contents = UIColor(white: 0.96, alpha: 1)
        return material
    }

    private func updateTemperature(animated: Bool) {
        guard let root = conditionGroup else { return }

        let replacement = makeTemperatureNode(text: "\(currentTemperature)")
        replacement.position = SCNVector3(0, -2.0, 0.12)
        replacement.opacity = animated ? 0 : 1
        root.addChildNode(replacement)

        if animated {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.22
            temperatureNode?.opacity = 0
            replacement.opacity = 1
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
        spin.duration = 18
        spin.repeatCount = .infinity
        spin.timingFunction = CAMediaTimingFunction(name: .linear)
        node.addAnimation(spin, forKey: "sun_spin")
    }
}