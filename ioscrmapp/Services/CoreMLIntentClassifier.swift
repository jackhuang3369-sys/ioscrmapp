import Foundation
import NaturalLanguage

actor CoreMLIntentClassifier: IntentClassifierServicing {
    private let modelProvider: any IntentModelProviding
    private let minimumAcceptedConfidence: Double
    private var cachedModel: NLModel?
    private var attemptedLoad = false

    init(
        modelProvider: any IntentModelProviding = BundleIntentModelProvider(),
        minimumAcceptedConfidence: Double = IntentClassifierConfiguration.default.minimumAcceptedCoreMLConfidence
    ) {
        self.modelProvider = modelProvider
        self.minimumAcceptedConfidence = minimumAcceptedConfidence
    }

    func classify(text: String, language: AppLanguage) async -> IntentClassificationCandidate? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        guard let model = loadModelIfNeeded() else {
            return nil
        }

        guard let predictedLabel = model.predictedLabel(for: trimmed) else {
            return nil
        }

        let hypotheses = model.predictedLabelHypotheses(for: trimmed, maximumCount: 3)
        guard let intentType = UserIntentType(rawValue: predictedLabel) else {
            return nil
        }

        let confidence = hypotheses[predictedLabel] ?? 0
        let requiresConfirmation = confidence < minimumAcceptedConfidence

        return IntentClassificationCandidate(
            intentType: intentType,
            confidence: confidence,
            source: .coreml,
            navigationTarget: intentType.defaultNavigationTarget,
            businessParameters: [:],
            requiresConfirmation: requiresConfirmation
        )
    }

    private func loadModelIfNeeded() -> NLModel? {
        if let cachedModel {
            return cachedModel
        }

        guard !attemptedLoad else {
            return nil
        }

        attemptedLoad = true

        guard let modelURL = modelProvider.compiledModelURL() else {
            return nil
        }

        guard let model = try? NLModel(contentsOf: modelURL) else {
            return nil
        }

        cachedModel = model
        return model
    }
}
