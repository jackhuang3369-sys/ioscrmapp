import Foundation

enum IntentClassifierRolloutMode: String, Codable, Sendable, Equatable {
    case disabled
    case shadow
    case fusedAuthoritative = "fused_authoritative"
}

struct IntentClassifierConfiguration: Sendable, Equatable {
    let rolloutMode: IntentClassifierRolloutMode
    let minimumAcceptedCoreMLConfidence: Double
    let minimumAcceptedFusedConfidence: Double
    let enableRemoteFallbackOnConflict: Bool

    static let `default` = IntentClassifierConfiguration(
        rolloutMode: .shadow,
        minimumAcceptedCoreMLConfidence: 0.8,
        minimumAcceptedFusedConfidence: 0.75,
        enableRemoteFallbackOnConflict: true
    )

    static let disabled = IntentClassifierConfiguration(
        rolloutMode: .disabled,
        minimumAcceptedCoreMLConfidence: 1.0,
        minimumAcceptedFusedConfidence: 1.0,
        enableRemoteFallbackOnConflict: true
    )

    static func current(serviceMode: AppServiceMode) -> IntentClassifierConfiguration {
        let processInfo = ProcessInfo.processInfo
        let rolloutModeOverride = processInfo.environment["IOSCRMAPP_INTENT_MODEL_MODE"]
            .flatMap { IntentClassifierRolloutMode(rawValue: $0.lowercased()) }

        let minimumCoreMLConfidence = processInfo.environment["IOSCRMAPP_INTENT_MODEL_MIN_CONFIDENCE"]
            .flatMap(Double.init) ?? 0.8
        let minimumFusedConfidence = processInfo.environment["IOSCRMAPP_INTENT_MODEL_MIN_FUSED_CONFIDENCE"]
            .flatMap(Double.init) ?? 0.75
        let enableRemoteFallbackOnConflict = processInfo.environment["IOSCRMAPP_INTENT_MODEL_REMOTE_FALLBACK_ON_CONFLICT"]
            .map { ["1", "true", "yes"].contains($0.lowercased()) } ?? true

        return IntentClassifierConfiguration(
            rolloutMode: rolloutModeOverride ?? defaultRolloutMode(for: serviceMode),
            minimumAcceptedCoreMLConfidence: minimumCoreMLConfidence,
            minimumAcceptedFusedConfidence: minimumFusedConfidence,
            enableRemoteFallbackOnConflict: enableRemoteFallbackOnConflict
        )
    }

    private static func defaultRolloutMode(for serviceMode: AppServiceMode) -> IntentClassifierRolloutMode {
        switch serviceMode {
        case .mock:
            return .fusedAuthoritative
        case .remote:
            return .shadow
        }
    }
}

struct IntentModelDescriptor: Sendable, Equatable {
    let resourceName: String
    let version: String

    static let current = IntentModelDescriptor(
        resourceName: "IntentClassifier",
        version: "2.2"
    )
}

protocol IntentModelProviding: Sendable {
    var descriptor: IntentModelDescriptor { get }
    func compiledModelURL() -> URL?
}

protocol IntentClassifierServicing: Sendable {
    func classify(text: String, language: AppLanguage) async -> IntentClassificationCandidate?
}

struct BundleIntentModelProvider: IntentModelProviding {
    let bundle: Bundle
    let descriptor: IntentModelDescriptor

    init(
        bundle: Bundle = .main,
        descriptor: IntentModelDescriptor = .current
    ) {
        self.bundle = bundle
        self.descriptor = descriptor
    }

    func compiledModelURL() -> URL? {
        let bundles = [bundle] + Bundle.allBundles + Bundle.allFrameworks

        for candidateBundle in bundles {
            if let url = candidateBundle.url(forResource: descriptor.resourceName, withExtension: "mlmodelc") {
                return url
            }
        }

        return nil
    }
}
