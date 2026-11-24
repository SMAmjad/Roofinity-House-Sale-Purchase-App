"""Checks that inference preprocessing matches the training contract.

These tests need only numpy + Pillow + pytest (no TensorFlow), so they run fast in CI.
"""
import json
from pathlib import Path

import numpy as np
import pytest
from PIL import Image

from preprocess import list_images, preprocess_file, to_model_input

ML_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = ML_ROOT.parent


def test_output_shape_and_dtype():
    batch = to_model_input(Image.new("RGB", (640, 480), (10, 20, 30)))
    assert batch.shape == (1, 224, 224, 3)
    assert batch.dtype == np.float32


def test_pixels_stay_in_0_255_range_not_normalised():
    # EfficientNetB0 rescales internally; dividing by 255 here was the bug
    # that made the app's AI check unreliable.
    batch = to_model_input(Image.new("RGB", (300, 300), (255, 128, 0)))
    assert batch.max() == pytest.approx(255.0)
    assert batch[0, 0, 0].tolist() == pytest.approx([255.0, 128.0, 0.0])


def test_rgba_and_grayscale_become_rgb():
    for image in (Image.new("RGBA", (50, 50), (1, 2, 3, 0)), Image.new("L", (50, 50), 7)):
        assert to_model_input(image).shape == (1, 224, 224, 3)


def test_exif_rotation_is_applied(tmp_path):
    # A 40x20 landscape image tagged "rotate 90" (EXIF orientation 6)
    # must be read as 20x40 portrait, like a phone gallery shows it.
    image = Image.new("RGB", (40, 20), (0, 0, 0))
    exif = image.getexif()
    exif[0x0112] = 6
    path = tmp_path / "rotated.jpg"
    image.save(path, exif=exif.tobytes())

    from preprocess import load_image
    assert load_image(path).size == (20, 40)
    assert preprocess_file(path).shape == (1, 224, 224, 3)


def test_list_images_filters_extensions(tmp_path):
    for name in ("a.jpg", "b.PNG", "c.txt", "sub/d.webp"):
        path = tmp_path / name
        path.parent.mkdir(parents=True, exist_ok=True)
        if path.suffix.lower() == ".txt":
            path.write_text("not an image")
        else:
            Image.new("RGB", (8, 8)).save(path)
    assert [p.name for p in list_images(tmp_path)] == ["a.jpg", "b.PNG", "d.webp"]


def test_exported_threshold_matches_the_app():
    threshold = json.loads((ML_ROOT / "exports" / "threshold.json").read_text())["fake_threshold"]
    dart = (REPO_ROOT / "lib" / "utils" / "image_authenticity_service.dart").read_text(encoding="utf-8")
    assert f"fakeThreshold = {threshold}" in dart


def test_labels_order_is_real_then_fake():
    labels = (ML_ROOT / "exports" / "labels.txt").read_text().split()
    assert labels == ["real", "fake"]


def test_model_file_is_shipped_with_the_app():
    model = REPO_ROOT / "assets" / "false_property_detector.tflite"
    assert model.exists() and model.stat().st_size > 1_000_000
