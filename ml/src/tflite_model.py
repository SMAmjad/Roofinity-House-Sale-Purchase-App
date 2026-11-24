"""Thin wrapper around the exported TensorFlow Lite model."""
from __future__ import annotations

import json
from pathlib import Path
from typing import Union

import numpy as np

from preprocess import preprocess_file

ML_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MODEL = ML_ROOT.parent / "assets" / "false_property_detector.tflite"
DEFAULT_THRESHOLD_FILE = ML_ROOT / "exports" / "threshold.json"
FAKE_INDEX = 1  # class order: 0 = real, 1 = fake


def load_threshold(path: Union[str, Path] = DEFAULT_THRESHOLD_FILE) -> float:
    return float(json.loads(Path(path).read_text(encoding="utf-8"))["fake_threshold"])


class FakeImageDetector:
    def __init__(self, model_path: Union[str, Path] = DEFAULT_MODEL,
                 threshold: Union[float, None] = None):
        import tensorflow as tf  # imported lazily so preprocess tests need no TF

        self.model_path = Path(model_path)
        self.interpreter = tf.lite.Interpreter(model_path=str(self.model_path))
        self.interpreter.allocate_tensors()
        self._input = self.interpreter.get_input_details()[0]
        self._output = self.interpreter.get_output_details()[0]
        _, height, width, _ = self._input["shape"]
        self.size = (int(width), int(height))
        self.threshold = load_threshold() if threshold is None else float(threshold)

    def fake_probability(self, image_path: Union[str, Path]) -> float:
        batch = preprocess_file(image_path, self.size)
        self.interpreter.set_tensor(self._input["index"], batch)
        self.interpreter.invoke()
        probs = self.interpreter.get_tensor(self._output["index"])[0]
        return float(probs[FAKE_INDEX])

    def is_fake(self, image_path: Union[str, Path]) -> bool:
        return self.fake_probability(image_path) > self.threshold
