"""Evaluate the exported TFLite model on the held-out test split.

Runs the exact model shipped in the app (assets/false_property_detector.tflite)
over data/splits/test/{real,fake} and writes to reports/:

    metrics.json              accuracy, precision, recall, F1, ROC-AUC, confusion matrix
    metrics.md                the same as a Markdown table (paste into the README)
    confusion_matrix.png
    roc_curve.png
    precision_recall_curve.png
    score_distribution.png
    predictions.csv           per-image scores (git-ignored)

Usage (from the ml/ folder):
    python src/evaluate.py
    python src/evaluate.py --test-dir data/splits/test --model ../assets/false_property_detector.tflite
"""
from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

import numpy as np

from preprocess import list_images
from tflite_model import DEFAULT_MODEL, ML_ROOT, FakeImageDetector

REPORTS_DIR = ML_ROOT / "reports"


def collect(detector: FakeImageDetector, test_dir: Path):
    paths, labels, scores = [], [], []
    for label_name, label in (("real", 0), ("fake", 1)):
        folder = test_dir / label_name
        images = list_images(folder)
        if not images:
            raise SystemExit(f"No images found in {folder}")
        print(f"[eval] scoring {len(images)} {label_name} images...")
        for i, image in enumerate(images, 1):
            scores.append(detector.fake_probability(image))
            labels.append(label)
            paths.append(image)
            if i % 250 == 0:
                print(f"         {i}/{len(images)}")
    return paths, np.array(labels), np.array(scores)


def compute_metrics(y_true: np.ndarray, scores: np.ndarray, threshold: float) -> dict:
    from sklearn.metrics import (accuracy_score, confusion_matrix, f1_score,
                                 precision_score, recall_score, roc_auc_score)

    y_pred = (scores > threshold).astype(int)
    tn, fp, fn, tp = confusion_matrix(y_true, y_pred, labels=[0, 1]).ravel()
    return {
        "threshold": threshold,
        "test_images": int(len(y_true)),
        "real_images": int((y_true == 0).sum()),
        "fake_images": int((y_true == 1).sum()),
        "accuracy": float(accuracy_score(y_true, y_pred)),
        "fake_precision": float(precision_score(y_true, y_pred, zero_division=0)),
        "fake_recall": float(recall_score(y_true, y_pred, zero_division=0)),
        "fake_f1": float(f1_score(y_true, y_pred, zero_division=0)),
        "real_recall": float(tn / (tn + fp)) if (tn + fp) else 0.0,
        "roc_auc": float(roc_auc_score(y_true, scores)),
        "confusion_matrix": {"true_real_pred_real": int(tn), "true_real_pred_fake": int(fp),
                             "true_fake_pred_real": int(fn), "true_fake_pred_fake": int(tp)},
    }


def write_markdown(m: dict, out: Path) -> None:
    cm = m["confusion_matrix"]
    lines = [
        f"Test set: **{m['test_images']:,}** images ({m['real_images']:,} real / {m['fake_images']:,} fake), "
        f"threshold **{m['threshold']:.3f}**",
        "",
        "| Metric | Value |",
        "|---|---|",
        f"| Accuracy | {m['accuracy']:.2%} |",
        f"| Fake precision | {m['fake_precision']:.2%} |",
        f"| Fake recall | {m['fake_recall']:.2%} |",
        f"| Fake F1 | {m['fake_f1']:.2%} |",
        f"| Real recall (specificity) | {m['real_recall']:.2%} |",
        f"| ROC-AUC | {m['roc_auc']:.4f} |",
        "",
        "| | Predicted real | Predicted fake |",
        "|---|---|---|",
        f"| **Actual real** | {cm['true_real_pred_real']:,} | {cm['true_real_pred_fake']:,} |",
        f"| **Actual fake** | {cm['true_fake_pred_real']:,} | {cm['true_fake_pred_fake']:,} |",
    ]
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")


def plot_all(y_true: np.ndarray, scores: np.ndarray, m: dict, out_dir: Path) -> None:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from sklearn.metrics import precision_recall_curve, roc_curve

    threshold = m["threshold"]
    cm = m["confusion_matrix"]
    matrix = np.array([[cm["true_real_pred_real"], cm["true_real_pred_fake"]],
                       [cm["true_fake_pred_real"], cm["true_fake_pred_fake"]]])

    fig, ax = plt.subplots(figsize=(4.8, 4.2))
    ax.imshow(matrix, cmap="Blues")
    for (r, c), v in np.ndenumerate(matrix):
        ax.text(c, r, f"{v:,}", ha="center", va="center",
                color="white" if v > matrix.max() / 2 else "black", fontsize=13)
    ax.set_xticks([0, 1], ["real", "fake"])
    ax.set_yticks([0, 1], ["real", "fake"])
    ax.set_xlabel("Predicted")
    ax.set_ylabel("Actual")
    ax.set_title("Confusion matrix (test set)")
    fig.tight_layout()
    fig.savefig(out_dir / "confusion_matrix.png", dpi=160)
    plt.close(fig)

    fpr, tpr, _ = roc_curve(y_true, scores)
    fig, ax = plt.subplots(figsize=(4.8, 4.2))
    ax.plot(fpr, tpr, linewidth=2, label=f"AUC = {m['roc_auc']:.3f}")
    ax.plot([0, 1], [0, 1], linestyle="--", color="grey", linewidth=1)
    ax.set_xlabel("False positive rate")
    ax.set_ylabel("True positive rate")
    ax.set_title("ROC curve")
    ax.legend(loc="lower right")
    fig.tight_layout()
    fig.savefig(out_dir / "roc_curve.png", dpi=160)
    plt.close(fig)

    precision, recall, _ = precision_recall_curve(y_true, scores)
    fig, ax = plt.subplots(figsize=(4.8, 4.2))
    ax.plot(recall, precision, linewidth=2)
    ax.scatter([m["fake_recall"]], [m["fake_precision"]], color="red", zorder=3,
               label=f"threshold {threshold:.3f}")
    ax.set_xlabel("Recall (fake)")
    ax.set_ylabel("Precision (fake)")
    ax.set_title("Precision-recall curve")
    ax.legend(loc="lower left")
    fig.tight_layout()
    fig.savefig(out_dir / "precision_recall_curve.png", dpi=160)
    plt.close(fig)

    fig, ax = plt.subplots(figsize=(6, 3.6))
    bins = np.linspace(0, 1, 41)
    ax.hist(scores[y_true == 0], bins=bins, alpha=0.7, label="real images")
    ax.hist(scores[y_true == 1], bins=bins, alpha=0.7, label="fake images")
    ax.axvline(threshold, color="red", linestyle="--", label=f"threshold {threshold:.3f}")
    ax.set_yscale("log")
    ax.set_xlabel("Predicted fake probability")
    ax.set_ylabel("Images (log scale)")
    ax.set_title("Score distribution")
    ax.legend()
    fig.tight_layout()
    fig.savefig(out_dir / "score_distribution.png", dpi=160)
    plt.close(fig)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--test-dir", type=Path, default=ML_ROOT / "data" / "splits" / "test")
    parser.add_argument("--model", type=Path, default=DEFAULT_MODEL)
    parser.add_argument("--threshold", type=float, default=None)
    args = parser.parse_args()

    detector = FakeImageDetector(args.model, args.threshold)
    paths, y_true, scores = collect(detector, args.test_dir)
    metrics = compute_metrics(y_true, scores, detector.threshold)

    REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    (REPORTS_DIR / "metrics.json").write_text(json.dumps(metrics, indent=2), encoding="utf-8")
    write_markdown(metrics, REPORTS_DIR / "metrics.md")
    plot_all(y_true, scores, metrics, REPORTS_DIR)
    with (REPORTS_DIR / "predictions.csv").open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["path", "label", "fake_probability"])
        for p, label, score in zip(paths, y_true, scores):
            writer.writerow([str(p), "fake" if label else "real", f"{score:.6f}"])

    print("\n" + (REPORTS_DIR / "metrics.md").read_text(encoding="utf-8"))
    print(f"[eval] reports written to {REPORTS_DIR}")


if __name__ == "__main__":
    main()
