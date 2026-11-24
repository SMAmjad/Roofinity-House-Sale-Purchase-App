"""Classify one image or a whole folder as real or fake.

Usage (from the ml/ folder):
    python src/predict.py path/to/photo.jpg
    python src/predict.py path/to/folder
    python src/predict.py path/to/folder --model ../assets/false_property_detector.tflite
"""
from __future__ import annotations

import argparse
from pathlib import Path

from preprocess import list_images
from tflite_model import DEFAULT_MODEL, FakeImageDetector


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("path", type=Path, help="image file or folder of images")
    parser.add_argument("--model", type=Path, default=DEFAULT_MODEL, help="TFLite model path")
    parser.add_argument("--threshold", type=float, default=None,
                        help="fake-probability threshold (default: exports/threshold.json)")
    args = parser.parse_args()

    detector = FakeImageDetector(args.model, args.threshold)
    images = list_images(args.path) if args.path.is_dir() else [args.path]
    if not images:
        raise SystemExit(f"No images found in {args.path}")

    print(f"Model: {detector.model_path}  |  threshold: {detector.threshold:.4f}\n")
    fake_count = 0
    for image in images:
        score = detector.fake_probability(image)
        verdict = "FAKE" if score > detector.threshold else "real"
        fake_count += verdict == "FAKE"
        print(f"{verdict:<4}  fake={score:6.2%}  {image}")

    print(f"\n{fake_count} of {len(images)} image(s) flagged as fake.")


if __name__ == "__main__":
    main()
