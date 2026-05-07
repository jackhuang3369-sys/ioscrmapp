import Foundation
@preconcurrency import NaturalLanguage

// MARK: - ONB Persona Classifier Service

protocol ONBPersonaClassifying: Sendable {
    /// 分类用户人格画像
    func classifyPersona(text: String) async -> ONBPersonaResult?
}

// MARK: - NLModel ONB Classifier

final class CoreMLONBPersonaClassifier: ONBPersonaClassifying {
    private let nlModel: NLModel?

    init(modelURL: URL? = nil) {
        let url = modelURL ?? Bundle.main.url(
            forResource: ONBModelDescriptor.current.resourceName,
            withExtension: "mlmodelc"
        )
        self.nlModel = url.flatMap { try? NLModel(contentsOf: $0) }
    }

    func classifyPersona(text: String) async -> ONBPersonaResult? {
        guard let model = nlModel else { return nil }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        guard let predictedLabel = model.predictedLabel(for: trimmed),
              let persona = ONBPersonaIntent(rawValue: predictedLabel) else {
            return nil
        }

        let hypotheses = model.predictedLabelHypotheses(for: trimmed, maximumCount: 3)
        let confidence = hypotheses[predictedLabel] ?? 0.5

        return ONBPersonaResult(persona: persona, confidence: confidence)
    }
}

// MARK: - ONB Model Provider Protocol

protocol ONBModelProviding: Sendable {
    var descriptor: ONBModelDescriptor { get }
    func compiledModelURL() -> URL?
}

// MARK: - Bundle Provider

struct BundleONBModelProvider: ONBModelProviding {
    let bundle: Bundle
    let descriptor: ONBModelDescriptor

    init(
        bundle: Bundle = .main,
        descriptor: ONBModelDescriptor = .current
    ) {
        self.bundle = bundle
        self.descriptor = descriptor
    }

    func compiledModelURL() -> URL? {
        let bundles = [bundle] + Bundle.allBundles + Bundle.allFrameworks
        for candidateBundle in bundles {
            if let url = candidateBundle.url(
                forResource: descriptor.resourceName,
                withExtension: "mlmodelc"
            ) {
                return url
            }
        }
        return nil
    }
}

// MARK: - Mock Classifier (for development/testing)

struct MockONBPersonaClassifier: ONBPersonaClassifying {
    func classifyPersona(text: String) async -> ONBPersonaResult? {
        let lowercased = text.lowercased()

        if lowercased.contains("travel") || lowercased.contains("abroad") {
            return ONBPersonaResult(persona: .travelFrequent, confidence: 0.85)
        }
        if lowercased.contains("game") || lowercased.contains("gaming") {
            return ONBPersonaResult(persona: .gamingHeavy, confidence: 0.85)
        }
        if lowercased.contains("video") || lowercased.contains("netflix") || lowercased.contains("stream") {
            return ONBPersonaResult(persona: .videoStreamingHeavy, confidence: 0.85)
        }
        if lowercased.contains("unlimited") {
            return ONBPersonaResult(persona: .unlimitedPreference, confidence: 0.85)
        }
        if lowercased.contains("budget") || lowercased.contains("cheap") || lowercased.contains("affordable") {
            return ONBPersonaResult(persona: .budgetSensitive, confidence: 0.85)
        }
        return nil
    }
}