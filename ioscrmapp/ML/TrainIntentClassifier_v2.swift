#!/usr/bin/env swift

import CreateML
import Foundation

private struct TrainingDataset: Decodable {
    let intentTypes: [String]
    let trainingData: [IntentSamples]
}

private struct IntentSamples: Decodable {
    let intentType: String
    let samples: [TrainingSample]
}

private struct TrainingSample: Decodable {
    let text: String
    let language: String
}

private let scriptDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
private let defaultInputURL = scriptDir.appendingPathComponent("training_data/intent_training_data_v2.json")
private let defaultOutputURL = scriptDir.appendingPathComponent("IntentClassifier_v2.mlmodel")

private let outputURL: URL = {
    guard CommandLine.arguments.count > 1 else {
        return defaultOutputURL
    }
    return URL(fileURLWithPath: CommandLine.arguments[1], relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
        .standardizedFileURL
}()

print("Loading training data from: \(defaultInputURL.path)")
guard FileManager.default.fileExists(atPath: defaultInputURL.path) else {
    fputs("ERROR: Training JSON not found at \(defaultInputURL.path)\n", stderr)
    exit(1)
}

let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase

private let dataset: TrainingDataset
do {
    let data = try Data(contentsOf: defaultInputURL)
    dataset = try decoder.decode(TrainingDataset.self, from: data)
} catch {
    fputs("ERROR: Failed to parse training data: \(error)\n", stderr)
    exit(1)
}

let flattenedSamples = dataset.trainingData.flatMap { intent in
    intent.samples.map { sample in
        (
            text: sample.text,
            label: intent.intentType,
            language: sample.language
        )
    }
}

guard !flattenedSamples.isEmpty else {
    fputs("ERROR: Training data is empty\n", stderr)
    exit(1)
}

let table = try MLDataTable(dictionary: [
    "text": flattenedSamples.map(\.text),
    "label": flattenedSamples.map(\.label),
    "language": flattenedSamples.map(\.language)
])

print("Total samples: \(flattenedSamples.count)")
print("Intent types: \(dataset.intentTypes.count)")

let (trainingData, validationData) = table.randomSplit(by: 0.85, seed: 42)
print("Training: \(trainingData.size), Validation: \(validationData.size)")

print("\nTraining MLTextClassifier...")
let classifier = try MLTextClassifier(
    trainingData: trainingData,
    textColumn: "text",
    labelColumn: "label"
)

let trainingAccuracy = (1.0 - classifier.trainingMetrics.classificationError) * 100
let validationAccuracy = (1.0 - classifier.validationMetrics.classificationError) * 100
print(String(format: "Training accuracy: %.2f%%", trainingAccuracy))
print(String(format: "Validation accuracy: %.2f%%", validationAccuracy))

try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

print("\nWriting model to: \(outputURL.path)")
try classifier.write(to: outputURL)

let attributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
let fileSize = attributes[.size] as? Int64 ?? 0
print(String(format: "Model saved: %.2f KB", Double(fileSize) / 1024.0))

print("\n=== Quick Validation ===")
let testInputs = [
    "check my data package is enough or not",
    "what about my data package",
    "check my remaining minutes",
    "how many texts do i have left",
    "view offers",
    "travel to hongkong",
    "recharge my account"
]

for text in testInputs {
    let prediction = try classifier.prediction(from: text)
    print("'\(text)' -> \(prediction)")
}

print("\n=== Training Complete ===")
