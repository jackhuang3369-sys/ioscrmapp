#!/usr/bin/env python3
"""
Merge semantic distinction samples into v2 training data and export for CreateML.

Usage:
    python3 merge_and_retrain.py [--output-dir OUTPUT_DIR]

This script:
1. Reads intent_training_data_v2.json as the base
2. Merges in semantic_distinction_samples.json
3. Deduplicates by (normalized text, intent_type)
4. Exports merged JSON + CSV for CreateML training
"""
import json
import os
import re
import sys
from collections import defaultdict


def normalize(text: str) -> str:
    """Normalize text for dedup comparison."""
    return re.sub(r"\s+", " ", text.strip().casefold())


def load_json(path: str) -> dict | list:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def merge_samples(
    base_data: list[dict],
    new_data: dict,
) -> dict[str, list[dict]]:
    """Merge samples by intent_type, deduplicating on normalized text."""
    merged: dict[str, list[dict]] = defaultdict(list)
    seen: set[tuple[str, str]] = set()

    # Load base data (v2 format: {"training_data": [{intent_type, samples: [{text, language}]}]})
    base_entries = base_data.get("training_data", base_data) if isinstance(base_data, dict) else base_data
    for entry in base_entries:
        intent = entry["intent_type"]
        for sample in entry.get("samples", []):
            key = (normalize(sample["text"]), intent)
            if key not in seen:
                seen.add(key)
                merged[intent].append({"text": sample["text"], "language": sample.get("language", "english")})

    # Merge new samples
    for entry in new_data.get("samples", []):
        intent = entry["intent_type"]
        for sample in entry.get("samples", []):
            key = (normalize(sample["text"]), intent)
            if key not in seen:
                seen.add(key)
                merged[intent].append({"text": sample["text"], "language": sample.get("language", "english")})

    return merged


def export_as_v3_json(merged: dict[str, list[dict]], path: str, base_data: dict) -> None:
    """Export in the same top-level format as intent_training_data_v2.json."""
    output = {
        "version": "3.0",
        "dataset_metadata": {
            "focus": base_data.get("dataset_metadata", {}).get("focus", "telecom_operator_business"),
            "language_priority": ["english", "simplifiedChinese", "arabic"],
            "notes": [
                "Enhanced with semantic distinction training data.",
                "Key focus: QUERY vs PURCHASE intent disambiguation.",
                f"Merged from v{base_data.get('version', '2.2')} + semantic_distinction_samples.json."
            ]
        },
        "business_domains": base_data.get("business_domains", []),
        "intent_types": base_data.get("intent_types", {}),
        "training_data": [
            {"intent_type": intent, "samples": samples}
            for intent, samples in sorted(merged.items())
        ]
    }
    with open(path, "w", encoding="utf-8") as f:
        json.dump(output, f, indent=2, ensure_ascii=False)
    total = sum(len(s['samples']) for s in output["training_data"])
    print(f"  JSON (v3 format): {path} ({len(output['training_data'])} intents, {total} samples)")


def export_csv(merged: dict[str, list[dict]], path: str) -> None:
    """Export CSV for CreateML: text,label (language is ignored for MLTextClassifier)."""
    with open(path, "w", encoding="utf-8") as f:
        f.write("text,label\n")
        for intent_type, samples in sorted(merged.items()):
            for sample in samples:
                text = sample["text"].replace('"', '""')
                f.write(f'"{text}",{intent_type}\n')
    total = sum(len(s) for s in merged.values())
    print(f"  CSV: {path} ({total} rows)")


def print_stats(merged: dict[str, list[dict]]) -> None:
    """Print distribution statistics."""
    print("\n  Intent distribution:")
    total = sum(len(s) for s in merged.values())
    for intent_type in sorted(merged.keys()):
        samples = merged[intent_type]
        lang_counts = defaultdict(int)
        for s in samples:
            lang_counts[s.get("language", "english")] += 1
        lang_str = ", ".join(f"{lang}: {count}" for lang, count in sorted(lang_counts.items()))
        print(f"    {intent_type}: {len(samples)} ({lang_str})")
    print(f"  TOTAL: {total} samples across {len(merged)} intents")


def main() -> None:
    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_dir = sys.argv[2] if len(sys.argv) > 2 and sys.argv[1] == "--output-dir" else script_dir

    base_path = os.path.join(script_dir, "intent_training_data_v2.json")
    new_path = os.path.join(script_dir, "semantic_distinction_samples.json")

    print(f"Loading base data: {base_path}")
    base_data = load_json(base_path)

    print(f"Loading new samples: {new_path}")
    new_data = load_json(new_path)

    print(f"Merging and deduplicating...")
    merged = merge_samples(base_data, new_data)

    print_stats(merged)

    v2_path = os.path.join(output_dir, "intent_training_data_v3.json")
    csv_path = os.path.join(output_dir, "training_data_v3.csv")

    print(f"\nExporting:")
    export_as_v3_json(merged, v2_path, base_data)
    export_csv(merged, csv_path)

    print(f"\nDone. Use the CSV with CreateML to retrain IntentClassifier_v3.mlmodel.")
    print(f"Or run: swift TrainIntentClassifier_v2.swift {csv_path}")


if __name__ == "__main__":
    main()
