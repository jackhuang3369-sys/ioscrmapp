#!/usr/bin/env swift

import CreateML
import Foundation

// MARK: - Configuration

let scriptDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let csvURL = scriptDir.appendingPathComponent("training_data/training_data.csv")
let outputURL = scriptDir.appendingPathComponent("IntentClassifier_v2.mlmodel")

// MARK: - Load training data

print("Loading training data from: \(csvURL.path)")
guard FileManager.default.fileExists(atPath: csvURL.path) else {
    fputs("ERROR: Training CSV not found at \(csvURL.path)\n", stderr)
    exit(1)
}

guard let dataTable = try? MLDataTable(contentsOf: csvURL) else {
    fputs("ERROR: Failed to load CSV data\n", stderr)
    exit(1)
}

print("Total rows: \(dataTable.size)")

// MARK: - Split into training and validation sets

let (trainingData, validationData) = dataTable.randomSplit(by: 0.85, seed: 42)
print("Training: \(trainingData.size), Validation: \(validationData.size)")

// MARK: - Train text classifier

print("\nTraining MLTextClassifier (maxEnt algorithm)...")
let classifier = try MLTextClassifier(
    trainingData: trainingData,
    textColumn: "text",
    labelColumn: "label"
)

// MARK: - Evaluation

let trainingAccuracy = (1.0 - classifier.trainingMetrics.classificationError) * 100
let validationAccuracy = (1.0 - classifier.validationMetrics.classificationError) * 100
print(String(format: "Training accuracy: %.2f%%", trainingAccuracy))
print(String(format: "Validation accuracy: %.2f%%", validationAccuracy))

// List precision/recall per class
print("\nPer-class metrics (validation set):")
let evalMetrics = classifier.validationMetrics
print("Classification error: \(evalMetrics.classificationError)")

// MARK: - Write model

print("\nWriting model to: \(outputURL.path)")
try classifier.write(to: outputURL)

// Verify output
let attributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
let fileSize = attributes[.size] as? Int64 ?? 0
print(String(format: "Model saved: %.2f KB", Double(fileSize) / 1024.0))

// MARK: - Quick test

print("\n=== Quick Validation ===")
let testInputs = [
    "check my data package is enough or not",
    "how much data do i have left",
    "remaining data",
    "my data usage",
    "check my balance",
    "view offers",
    "travel to hongkong",
    "recharge my account"
]

for text in testInputs {
    let prediction = try classifier.prediction(from: text)
    print("'\(text)' -> \(prediction)")
}

print("\n=== Training Complete ===")
