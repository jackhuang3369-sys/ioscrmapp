#!/usr/bin/env python3
"""Compatibility wrapper for the canonical Swift/CreateML trainer."""

import os
import subprocess
import sys


def main() -> None:
    script_dir = os.path.dirname(os.path.abspath(__file__))
    swift_script = os.path.join(script_dir, "TrainIntentClassifier_v2.swift")

    if not os.path.exists(swift_script):
        print(f"ERROR: Swift trainer not found at {swift_script}")
        sys.exit(1)

    command = ["swift", swift_script, *sys.argv[1:]]
    print("Delegating intent model training to the Swift/CreateML trainer:")
    print(" ".join(command))
    completed = subprocess.run(command, check=False)
    sys.exit(completed.returncode)


if __name__ == "__main__":
    main()
