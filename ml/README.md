# Fake Property Image Detector: model training

This folder holds the computer-vision part of Roofinity: a binary classifier that tells **real property photos** from **AI-generated (fake) ones**. The trained model ships inside the Flutter app as [`assets/false_property_detector.tflite`](../assets/false_property_detector.tflite) and runs fully on the phone.

| | |
|---|---|
| Architecture | EfficientNetB0 (ImageNet weights) + global average pooling + dropout 0.3 + 2-way softmax |
| Training | 2 stages: frozen backbone (12 epochs, lr 1e-4), then fine-tuning from layer 200 (6 epochs, lr 1e-5); early stopping and LR-on-plateau |
| Augmentation | random horizontal flip, rotation (±5%), zoom (±10%) |
| Input | `float32 [1, 224, 224, 3]`, RGB, **values 0-255** (EfficientNet rescales internally) |
| Output | `[p_real, p_fake]` |
| Decision rule | `fake` if `p_fake > 0.598`. The threshold is chosen for the best precision while catching at least 90% of fake images |
| Export | TensorFlow Lite with dynamic-range quantisation, 4.4 MB |
| Framework | TensorFlow 2.10.1 / Keras 2.10, Python 3.9 |

## Dataset

15,044 images after cleaning (images under 128×128 or corrupt files dropped, watermarked photos excluded), split 80/10/10 with stratification:

| Split | Real | Fake | Total |
|---|---:|---:|---:|
| Train | 10,469 | 1,566 | 12,035 |
| Validation | 1,308 | 196 | 1,504 |
| Test | 1,309 | 196 | 1,505 |
| **Total** | **13,086** | **1,958** | **15,044** |

* **Real:** property listing photos from Facebook and Lamudi.
* **Fake:** AI-generated property images (Perchance AI).

The classes are imbalanced (about 6.7 real images per fake one). This is why the model is judged on fake-class precision/recall and ROC-AUC rather than plain accuracy, and why the decision threshold is tuned for recall on the fake class.

> The images are third-party content and are **not** included in this repository. To retrain, place the dataset at `ml/data/raw/dataset_zip/Real Estate Property Dataset/` (with its `Images/` folder) and run the steps below.

## Folder layout

```
ml/
├── config/config.yaml          # paths + hyper-parameters
├── scripts/prep_dataset.py     # unzip → clean → route real/fake → 80/10/10 split
├── src/
│   ├── train.py                # train, pick threshold, export TFLite into ../assets
│   ├── evaluate.py             # metrics + plots on the test split → reports/
│   ├── predict.py              # CLI: classify an image or a folder
│   ├── tflite_model.py         # small TFLite wrapper used by the tools
│   └── preprocess.py           # preprocessing identical to the app
├── tools/desktop_tester.py     # Tkinter GUI to try the model on your own photos
├── tests/                      # pytest (runs in GitHub Actions)
├── exports/                    # labels.txt, threshold.json
└── models/checkpoints/efficientnet_b0/best.keras   # best checkpoint (16 MB)
```

## Setup

Python 3.9 or 3.10 (TensorFlow 2.10 does not support newer versions).

```bash
cd ml
python -m venv .venv
# Windows: .venv\Scripts\activate    macOS/Linux: source .venv/bin/activate
pip install -r requirements.txt
```

## Commands

```bash
# Try the model on your own images (no dataset needed)
python src/predict.py path/to/photo.jpg
python src/predict.py path/to/folder
python tools/desktop_tester.py

# Full pipeline (needs the dataset)
python scripts/prep_dataset.py        # build data/splits/{train,val,test}
python src/train.py                   # train (or reuse best.keras) → export ../assets/*.tflite
python src/evaluate.py                 # metrics + charts → reports/

# Tests
pytest -q
```

`train.py` skips training when `models/checkpoints/efficientnet_b0/best.keras` exists and only re-runs threshold selection and export. Delete the checkpoint to train from scratch.

After a new export, copy the printed threshold into `ImageAuthenticityService.fakeThreshold` in [`lib/utils/image_authenticity_service.dart`](../lib/utils/image_authenticity_service.dart). A test in `tests/test_preprocess.py` fails if the two values drift apart.

## Preprocessing: the one rule that matters

Keras' `EfficientNetB0` contains its own `Rescaling(1/255)` and normalisation layers, and `image_dataset_from_directory` feeds raw 0-255 pixels. **Inference code must pass raw 0-255 pixels too.** An earlier version of the app and of the test scripts divided by 255, which made the model see almost-black images. Both are fixed, and `tests/test_preprocess.py` guards against the regression.
