"""Image preprocessing shared by every inference tool.

Mirrors what the model saw during training (tf.keras
`image_dataset_from_directory`) and what the Flutter app does in
`lib/utils/image_authenticity_service.dart`:

* RGB, EXIF rotation applied
* bilinear resize to the model's input size (224x224)
* float32 values in 0-255. EfficientNetB0 rescales internally,
  so the image must NOT be divided by 255.
"""
from __future__ import annotations

from pathlib import Path
from typing import Tuple, Union

import numpy as np
from PIL import Image, ImageOps

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}


def load_image(path: Union[str, Path]) -> Image.Image:
    """Open an image upright (EXIF rotation applied) in RGB."""
    with Image.open(path) as im:
        im = ImageOps.exif_transpose(im)
        return im.convert("RGB")


def to_model_input(image: Image.Image, size: Tuple[int, int] = (224, 224)) -> np.ndarray:
    """Return a float32 batch of shape (1, height, width, 3) with values in 0-255.

    `size` is (width, height), as used by PIL.
    """
    resized = image.convert("RGB").resize(size, Image.Resampling.BILINEAR)
    array = np.asarray(resized, dtype=np.float32)
    return np.expand_dims(array, axis=0)


def preprocess_file(path: Union[str, Path], size: Tuple[int, int] = (224, 224)) -> np.ndarray:
    return to_model_input(load_image(path), size)


def list_images(folder: Union[str, Path]) -> list[Path]:
    """All image files in `folder` (recursive), sorted for repeatable runs."""
    return sorted(
        p for p in Path(folder).rglob("*")
        if p.is_file() and p.suffix.lower() in IMAGE_EXTENSIONS
    )
