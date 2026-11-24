"""Train the real-vs-fake property image classifier and export it for the app.

Pipeline:
  1. Stage 1: train a new classification head on a frozen EfficientNetB0
     (ImageNet weights).
  2. Stage 2: fine-tune the top of the backbone at a 10x lower learning rate.
  3. Pick the fake-probability threshold with the best precision while keeping
     recall on fake images >= `threshold.min_recall` (config.yaml).
  4. Export a TensorFlow Lite model (dynamic-range quantised) to the Flutter
     app's assets/ folder, plus labels.txt and threshold.json to exports/.

If a checkpoint already exists, training is skipped and only steps 3-4 run.

Input contract of the exported model: float32 [1, 224, 224, 3], RGB pixel
values in 0-255 (EfficientNetB0 rescales internally, so do NOT divide by 255).

Usage (from the ml/ folder):
    python src/train.py
"""
from __future__ import annotations
import json
from pathlib import Path
import numpy as np
import tensorflow as tf
import yaml
from sklearn.metrics import precision_recall_curve

# ---------------------------------------------------------
# Load config
# ---------------------------------------------------------
ROOT = Path(__file__).resolve().parents[1]
CFG_PATH = ROOT / "config" / "config.yaml"

with CFG_PATH.open("r", encoding="utf-8") as f:
    CFG = yaml.safe_load(f)

PATHS = CFG["paths"]
TRAIN_CFG = CFG["train"]
THRESH_CFG = CFG.get("threshold", {})

TRAIN_DIR = ROOT / PATHS["train_dir"]
VAL_DIR = ROOT / PATHS["val_dir"]
TEST_DIR = ROOT / PATHS["test_dir"]
CHECKPOINT_DIR = ROOT / PATHS["checkpoint_dir"]
EXPORT_DIR = ROOT / PATHS["export_dir"]
MOBILE_MODEL_DIR = ROOT / PATHS["mobile_model_dir"]

IMG_SIZE = tuple(TRAIN_CFG["image_size"])
BATCH_SIZE = int(TRAIN_CFG["batch_size"])
EPOCHS = int(TRAIN_CFG["epochs"])
FINE_TUNE_EPOCHS = int(TRAIN_CFG["fine_tune_epochs"])
FINE_TUNE_AT = int(TRAIN_CFG["fine_tune_at"])
BASE_LR = float(TRAIN_CFG["base_learning_rate"])
EARLY_STOP_PATIENCE = int(TRAIN_CFG["early_stopping_patience"])
LABEL_SMOOTHING = float(TRAIN_CFG["label_smoothing"])
CLASS_NAMES = list(TRAIN_CFG["class_names"])
NUM_CLASSES = len(CLASS_NAMES)
MIN_RECALL = float(THRESH_CFG.get("min_recall", 0.9))


# ---------------------------------------------------------
# Dataset builders
# ---------------------------------------------------------
def build_datasets():
    AUTOTUNE = tf.data.AUTOTUNE

    def make_ds(directory: Path, shuffle: bool) -> tf.data.Dataset:
        ds = tf.keras.utils.image_dataset_from_directory(
            directory,
            labels="inferred",
            label_mode="categorical",
            class_names=CLASS_NAMES,
            image_size=IMG_SIZE,
            batch_size=BATCH_SIZE,
            shuffle=shuffle,
        )
        # <-- IMPORTANT: skip any corrupt/unknown image files
        ds = ds.apply(tf.data.experimental.ignore_errors())
        return ds

    train_ds = make_ds(TRAIN_DIR, shuffle=True)
    val_ds = make_ds(VAL_DIR, shuffle=False)
    test_ds = make_ds(TEST_DIR, shuffle=False)

    def prep(ds: tf.data.Dataset, augment: bool) -> tf.data.Dataset:
        if augment:
            ds = ds.shuffle(1000)
        return ds.prefetch(AUTOTUNE)

    return prep(train_ds, True), prep(val_ds, False), prep(test_ds, False)


# ---------------------------------------------------------
# Model builder
# ---------------------------------------------------------
def build_model():
    img_height, img_width = IMG_SIZE
    input_shape = (img_height, img_width, 3)

    data_augmentation = tf.keras.Sequential(
        [
            tf.keras.layers.RandomFlip("horizontal"),
            tf.keras.layers.RandomRotation(0.05),
            tf.keras.layers.RandomZoom(0.1),
        ],
        name="augmentation",
    )

    base_model = tf.keras.applications.EfficientNetB0(
        include_top=False,
        weights="imagenet",
        input_shape=input_shape,
    )
    base_model.trainable = False

    inputs = tf.keras.Input(shape=input_shape)
    x = data_augmentation(inputs)
    x = tf.keras.applications.efficientnet.preprocess_input(x)
    x = base_model(x, training=False)
    x = tf.keras.layers.GlobalAveragePooling2D()(x)
    x = tf.keras.layers.Dropout(0.3)(x)
    outputs = tf.keras.layers.Dense(NUM_CLASSES, activation="softmax")(x)

    model = tf.keras.Model(inputs, outputs, name="fake_property_detector")

    loss = tf.keras.losses.CategoricalCrossentropy(label_smoothing=LABEL_SMOOTHING)
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=BASE_LR),
        loss=loss,
        metrics=[
            tf.keras.metrics.CategoricalAccuracy(name="acc"),
            tf.keras.metrics.AUC(name="auc"),
        ],
    )

    return model, base_model


# ---------------------------------------------------------
# Training stages
# ---------------------------------------------------------
def train_and_fine_tune(model, base_model, train_ds, val_ds):
    CHECKPOINT_DIR.mkdir(parents=True, exist_ok=True)
    ckpt_path = CHECKPOINT_DIR / "best.keras"

    callbacks = [
        tf.keras.callbacks.ModelCheckpoint(
            filepath=str(ckpt_path),
            monitor="val_loss",
            mode="min",
            save_best_only=True,
        ),
        tf.keras.callbacks.EarlyStopping(
            monitor="val_loss",
            mode="min",
            patience=EARLY_STOP_PATIENCE,
            restore_best_weights=True,
        ),
        tf.keras.callbacks.ReduceLROnPlateau(
            monitor="val_loss",
            factor=0.5,
            patience=2,
            verbose=1,
        ),
    ]

    print("[train] Stage 1: training with frozen backbone...")
    history1 = model.fit(
        train_ds,
        epochs=EPOCHS,
        validation_data=val_ds,
        callbacks=callbacks,
    )

    model = tf.keras.models.load_model(ckpt_path)

    print("[train] Stage 2: fine-tuning upper layers...")
    base_model.trainable = True
    for layer in base_model.layers[:FINE_TUNE_AT]:
        layer.trainable = False

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=BASE_LR / 10.0),
        loss=tf.keras.losses.CategoricalCrossentropy(label_smoothing=LABEL_SMOOTHING),
        metrics=[
            tf.keras.metrics.CategoricalAccuracy(name="acc"),
            tf.keras.metrics.AUC(name="auc"),
        ],
    )

    history2 = model.fit(
        train_ds,
        epochs=FINE_TUNE_EPOCHS,
        validation_data=val_ds,
        callbacks=callbacks,
    )

    model = tf.keras.models.load_model(ckpt_path)
    return model, history1, history2


# ---------------------------------------------------------
# Evaluation + Threshold (shape-safe)
# ---------------------------------------------------------
def evaluate_and_choose_threshold(model, test_ds):
    print("[eval] Evaluating on test set...")
    y_true, y_scores = [], []

    for batch_imgs, batch_labels in test_ds:
        # **UPDATED**: Set training=False for deterministic predictions
        probs = model.predict(batch_imgs, verbose=0, training=False)
        y_true.append(np.argmax(batch_labels.numpy(), axis=1))
        y_scores.append(probs[:, 1])  # prob of 'fake' class

    y_true = np.concatenate(y_true, axis=0)
    y_scores = np.concatenate(y_scores, axis=0)

    fake_mask = (y_true == 1).astype(int)
    precision, recall, thresholds = precision_recall_curve(fake_mask, y_scores)

    # precision/recall are length N+1, thresholds length N → align
    precision = precision[:-1]
    recall = recall[:-1]
    assert thresholds.shape[0] == recall.shape[0]

    mask = recall >= MIN_RECALL
    if np.any(mask):
        valid_thresholds = thresholds[mask]
        valid_precision = precision[mask]
        valid_recall = recall[mask]

        best_idx = np.argmax(valid_precision)
        best_thr = float(valid_thresholds[best_idx])
        best_prec = float(valid_precision[best_idx])
        best_rec = float(valid_recall[best_idx])

        print(
            f"[eval] threshold={best_thr:.3f} "
            f"precision={best_prec:.3f} "
            f"recall={best_rec:.3f} "
            f"(min_recall={MIN_RECALL})"
        )
    else:
        best_thr = 0.5
        print(f"[eval] recall < {MIN_RECALL}; using default threshold 0.5")

    return best_thr


# ---------------------------------------------------------
# Export TFLite + assets
# ---------------------------------------------------------
def export_tflite(model, threshold: float):
    EXPORT_DIR.mkdir(parents=True, exist_ok=True)
    MOBILE_MODEL_DIR.mkdir(parents=True, exist_ok=True)

    saved_model_dir = CHECKPOINT_DIR / "saved_model"
    # **NOTE**: Explicitly set training=False when saving for production/TFLite export
    # This ensures the SavedModel is in inference mode.
    tf.saved_model.save(model, saved_model_dir, signatures=None, options=tf.saved_model.SaveOptions(experimental_io_device="/job:localhost"))
    print(f"[export] SavedModel -> {saved_model_dir}")

    converter = tf.lite.TFLiteConverter.from_saved_model(str(saved_model_dir))
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()

    (EXPORT_DIR / "labels.txt").write_text("\n".join(CLASS_NAMES), encoding="utf-8")
    threshold_obj = {"fake_threshold": float(threshold)}
    (EXPORT_DIR / "threshold.json").write_text(json.dumps(threshold_obj, indent=2), encoding="utf-8")
    print(f"[export] labels.txt + threshold.json -> {EXPORT_DIR}")

    mobile_tflite_path = MOBILE_MODEL_DIR / "false_property_detector.tflite"
    mobile_tflite_path.write_bytes(tflite_model)
    print(f"[export] TFLite model -> {mobile_tflite_path}")
    print(
        "[export] REMINDER: update ImageAuthenticityService.fakeThreshold in "
        f"lib/utils/image_authenticity_service.dart to {threshold!r}"
    )


# ---------------------------------------------------------
# Main
# ---------------------------------------------------------
def main():
    print("[info] repo root :", ROOT)
    print("[info] train dir :", TRAIN_DIR)
    print("[info] val dir   :", VAL_DIR)
    print("[info] test dir  :", TEST_DIR)
    print("[info] classes   :", CLASS_NAMES)

    train_ds, val_ds, test_ds = build_datasets()
    ckpt_path = CHECKPOINT_DIR / "best.keras"

    if ckpt_path.exists():
        print(f"[info] Found checkpoint: {ckpt_path}")
        print("[info] Skipping training, loading existing model...")
        model = tf.keras.models.load_model(ckpt_path)
    else:
        model, base_model = build_model()
        model, _, _ = train_and_fine_tune(model, base_model, train_ds, val_ds)

    threshold = evaluate_and_choose_threshold(model, test_ds)
    export_tflite(model, threshold)
    print("[OK] training/eval + export complete.")


if __name__ == "__main__":
    main()