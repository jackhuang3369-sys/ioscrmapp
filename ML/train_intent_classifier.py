#!/usr/bin/env python3
"""
Intent Classifier Core ML Model Training Script
Generates IntentClassifier.mlmodel from training data
"""

import json
import os
import sys

def check_coremltools():
    """Check if coremltools is installed"""
    try:
        import coremltools as ct
        return ct
    except ImportError:
        print("ERROR: coremltools is not installed")
        print("Install with: pip install coremltools")
        sys.exit(1)

def load_training_data(filepath):
    """Load training data from JSON file"""
    with open(filepath, 'r', encoding='utf-8') as f:
        return json.load(f)

def prepare_training_samples(data):
    """Prepare training samples in format for Create ML"""
    samples = []
    labels = []

    for item in data['training_data']:
        intent_type = item['intent_type']
        for sample in item['samples']:
            samples.append(sample['text'])
            labels.append(intent_type)

    return samples, labels

def train_model(ct, samples, labels, output_path):
    """Train text classifier model using Create ML"""
    print(f"Training with {len(samples)} samples...")

    # Create ML text classifier
    from coremltools.models.text_classifier import create_text_classifier

    # Create training data DataFrame
    import pandas as pd
    df = pd.DataFrame({
        'text': samples,
        'label': labels
    })

    # Train model
    model = create_text_classifier(
        training_data=df,
        text_column='text',
        label_column='label',
        maximum_iterations=50
    )

    # Set model metadata
    model.short_description = "Intent classifier for telecom mobile app (version 2)"
    model.author = "ioscrmapp"
    model.version = "2.0"

    # Save model
    model.save(output_path)
    print(f"Model saved to: {output_path}")

    return model

def validate_model(model, test_inputs):
    """Validate model with test inputs"""
    print("\n=== Model Validation ===")
    for text in test_inputs:
        result = model.predict({'text': text})
        label = result.get('label', 'unknown')
        print(f"Input: '{text}'")
        print(f"  → Predicted: {label}")
        print()

def main():
    # Paths
    script_dir = os.path.dirname(os.path.abspath(__file__))
    training_data_path = os.path.join(script_dir, 'training_data', 'intent_training_data_v2.json')
    output_path = os.path.join(script_dir, 'IntentClassifier_v2.mlmodel')

    # Check coremltools
    ct = check_coremltools()

    # Load training data
    print(f"Loading training data from: {training_data_path}")
    data = load_training_data(training_data_path)
    print(f"Intent types: {data['intent_types']}")

    # Prepare samples
    samples, labels = prepare_training_samples(data)
    print(f"Total training samples: {len(samples)}")

    # Train model
    model = train_model(ct, samples, labels, output_path)

    # Validate with user's problematic input
    test_inputs = [
        "check my data package is enough or not",
        "how much data do i have left",
        "remaining data",
        "my data usage",
        "is my data package enough",
        "check my balance",
        "view offers",
        "travel to hongkong"
    ]
    validate_model(model, test_inputs)

    print("\n=== Training Complete ===")
    print(f"Output model: {output_path}")
    print("\nNext steps:")
    print("1. Replace ioscrmapp/ML/IntentClassifier.mlmodel with the new model")
    print("2. Update UserIntentType enum to add data_usage_query")
    print("3. Update IntentRoutingService to handle data_usage_query")

if __name__ == '__main__':
    main()