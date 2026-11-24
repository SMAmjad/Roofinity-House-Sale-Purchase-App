# -*- coding: utf-8 -*-
"""
Prep Real-vs-Fake Property Images
- Unzips dataset archives under:
    data/raw/dataset_zip/Real Estate Property Dataset/Images/
- Routes images to:
    data/raw/real/   and   data/raw/fake/
- Skips tiny/corrupt files, optionally skips watermarked real images
- Creates 80/10/10 train/val/test split in data/splits/...
- Writes data/metadata.csv

Usage (from the ml/ folder):
  python scripts/prep_dataset.py
Optional flags:
  --dry-run                : preview only, no file moves/copies
  --keep-source-subdirs    : keep one source-level folder inside real/fake (e.g., real/Facebook)
  --include-watermarked    : include "watermarked" real images
  --min-size 128 128       : change minimum accepted width/height
"""
from __future__ import annotations
import argparse
import csv
import hashlib
import re
import shutil
import zipfile
from pathlib import Path
from typing import List, Tuple

from PIL import Image
from sklearn.model_selection import train_test_split


# ------------------ Defaults (match your screenshots) ------------------
REPO = Path(__file__).resolve().parents[1]
DATASET_ROOT = REPO / "data" / "raw" / "dataset_zip" / "Real Estate Property Dataset"
IMAGES_DIR = DATASET_ROOT / "Images"

RAW_DIR   = REPO / "data" / "raw"
REAL_DIR  = RAW_DIR / "real"
FAKE_DIR  = RAW_DIR / "fake"
SPLITS_DIR = REPO / "data" / "splits"
METADATA_CSV = REPO / "data" / "metadata.csv"

ALLOWED_EXT = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}
REAL_KEYS   = [r"facebook", r"lamudi", r"oh\s*my\s*home"]     # case-insensitive
FAKE_KEYS   = [r"perchance", r"ai\-generated"]                # case-insensitive

TRAIN_PCT, VAL_PCT, TEST_PCT = 0.8, 0.1, 0.1
RANDOM_SEED = 42
# ----------------------------------------------------------------------


def parse_args():
    p = argparse.ArgumentParser(description="Prepare real-vs-fake property dataset")
    p.add_argument("--dry-run", action="store_true", help="Preview actions; do not move/copy files")
    p.add_argument("--keep-source-subdirs", action="store_true",
                   help="Keep one source-level folder inside real/fake (e.g., real/Facebook)")
    p.add_argument("--include-watermarked", action="store_true",
                   help="Include 'watermarked' real images (default: skipped)")
    p.add_argument("--min-size", type=int, nargs=2, metavar=("W", "H"), default=(128, 128),
                   help="Minimum accepted image size (width height). Default 128 128")
    return p.parse_args()


def log(msg: str):
    print(msg, flush=True)


def unzip_all_archives(dry_run: bool):
    """Unzip any .zip under IMAGES_DIR (and one level below)."""
    zips: List[Path] = list(IMAGES_DIR.glob("*.zip")) + list(IMAGES_DIR.glob("*/*.zip"))
    if not zips:
        log("[unzip] no zip archives found (that's fine if already extracted).")
        return
    for z in zips:
        out_dir = z.with_suffix("")
        if out_dir.exists() and any(out_dir.iterdir()):
            log(f"[unzip] skip (already extracted): {z.name}")
            continue
        log(f"[unzip] extract: {z.name} -> {out_dir}")
        if dry_run:
            continue
        out_dir.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(z, "r") as zf:
            zf.extractall(out_dir)


def collect_images() -> List[Path]:
    files: List[Path] = []
    for p in IMAGES_DIR.rglob("*"):
        if p.is_file() and p.suffix.lower() in ALLOWED_EXT:
            files.append(p)
    return files


def is_real_path(path_str: str, include_watermarked: bool) -> bool:
    s = path_str.lower()
    if not include_watermarked and "watermarked" in s:
        return False
    return any(re.search(k, s) for k in REAL_KEYS)


def is_fake_path(path_str: str) -> bool:
    s = path_str.lower()
    return any(re.search(k, s) for k in FAKE_KEYS)


def ensure_dir(d: Path, dry_run: bool):
    if dry_run:
        return
    d.mkdir(parents=True, exist_ok=True)


def destination_path(src: Path, label_dir: Path, keep_source_subdirs: bool) -> Path:
    """Optionally preserve one source-level folder name; de-dupe filename on clashes."""
    ext = src.suffix.lower()
    stem = src.stem
    # derive a source folder (one level below the extracted root) if requested
    subdir = None
    if keep_source_subdirs:
        # try to find folder right under IMAGES_DIR (e.g., 'Facebook Images', 'Perchance AI-Generated Images')
        try:
            relative = src.relative_to(IMAGES_DIR)
            parts = relative.parts
            if len(parts) >= 2:  # e.g., 'Facebook Images' / 'images' / file.png
                subdir = parts[0]
        except Exception:
            pass

    out_dir = label_dir / (subdir or "")
    out = out_dir / f"{stem}{ext}"
    idx = 1
    while out.exists():
        # clash: append short hash to keep both
        h = hashlib.md5(str(src).encode()).hexdigest()[:6]
        out = out_dir / f"{stem}_{h}_{idx}{ext}"
        idx += 1
    return out


def is_valid_image(p: Path, min_w: int, min_h: int) -> bool:
    try:
        with Image.open(p) as im:
            w, h = im.size
            if w < min_w or h < min_h:
                return False
            im.verify()
        return True
    except Exception:
        return False


def route_images(
    files: List[Path],
    include_watermarked: bool,
    keep_source_subdirs: bool,
    min_w: int,
    min_h: int,
    dry_run: bool
) -> List[Tuple[Path, str, int, int]]:
    """
    Move routed images into data/raw/real or data/raw/fake.
    Returns rows for metadata: (dst_path, label, width, height)
    """
    rows: List[Tuple[Path, str, int, int]] = []

    for src in files:
        rel = str(src).lower()

        label = None
        if is_real_path(rel, include_watermarked):
            label = "real"
            dst_dir = REAL_DIR
        elif is_fake_path(rel):
            label = "fake"
            dst_dir = FAKE_DIR
        else:
            # Unknown category -> skip quietly
            continue

        dst = destination_path(src, dst_dir, keep_source_subdirs)
        ensure_dir(dst.parent, dry_run=dry_run)

        # Move file
        log(f"[route] {label:<4} :: {src} -> {dst}")
        if not dry_run:
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(src), str(dst))

            # validate & size
            if not is_valid_image(dst, min_w, min_h):
                log(f"[drop] invalid/tiny/corrupt: {dst}")
                try:
                    dst.unlink()
                except Exception:
                    pass
                continue

            with Image.open(dst) as im:
                w, h = im.size
        else:
            # approximate size check in dry-run (skip open)
            w, h = (min_w, min_h)

        rows.append((dst, label, w, h))

    return rows


def write_metadata(rows: List[Tuple[Path, str, int, int]], out_csv: Path, dry_run: bool):
    log(f"[meta] writing: {out_csv}")
    if dry_run:
        return
    out_csv.parent.mkdir(parents=True, exist_ok=True)
    with out_csv.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["path", "label", "width", "height"])
        for p, label, w0, h0 in rows:
            # store path relative to repo
            w.writerow([str(p.relative_to(REPO)), label, w0, h0])


def make_splits(rows: List[Tuple[Path, str, int, int]], dry_run: bool):
    if not rows:
        log("[splits] no rows to split; nothing to do.")
        return

    paths = [str(p) for p, _, _, _ in rows]
    labels = [lbl for _, lbl, _, _ in rows]

    # 80/10/10 with stratification
    X_train, X_tmp, y_train, y_tmp = train_test_split(
        paths, labels, test_size=(1 - TRAIN_PCT), stratify=labels, random_state=RANDOM_SEED
    )
    test_ratio = TEST_PCT / (VAL_PCT + TEST_PCT)
    X_val, X_test, y_val, y_test = train_test_split(
        X_tmp, y_tmp, test_size=test_ratio, stratify=y_tmp, random_state=RANDOM_SEED
    )

    if not dry_run:
        if SPLITS_DIR.exists():
            shutil.rmtree(SPLITS_DIR)
        SPLITS_DIR.mkdir(parents=True, exist_ok=True)

    def copy_split(split: str, X: List[str], y: List[str]):
        log(f"[copy] {split:<5} -> {len(X)} files")
        if dry_run:
            return
        for p, lbl in zip(X, y):
            src = Path(p)
            dst_dir = SPLITS_DIR / split / lbl
            dst_dir.mkdir(parents=True, exist_ok=True)
            dst = dst_dir / src.name
            if not dst.exists():
                shutil.copy2(src, dst)

    copy_split("train", X_train, y_train)
    copy_split("val",   X_val,   y_val)
    copy_split("test",  X_test,  y_test)

    log(f"[splits] train={len(X_train)}  val={len(X_val)}  test={len(X_test)}")
    log(f"[done] splits at: {SPLITS_DIR}")


def main():
    args = parse_args()
    min_w, min_h = args.min_size

    log(f"[info] repo:           {REPO}")
    log(f"[info] dataset root:   {DATASET_ROOT}")
    log(f"[info] images root:    {IMAGES_DIR}")
    log(f"[info] dry-run:         {args.dry_run}")
    log(f"[info] keep-subdir:     {args.keep_source_subdirs}")
    log(f"[info] include-watermk: {args.include_watermarked}")
    log(f"[info] min-size (w,h):  {min_w},{min_h}")

    # 1) Unzip any archives
    unzip_all_archives(dry_run=args.dry_run)

    # 2) Collect files and route to raw/real|fake
    files = collect_images()
    log(f"[scan] found {len(files)} image candidates.")
    rows = route_images(
        files,
        include_watermarked=args.include_watermarked,
        keep_source_subdirs=args.keep_source_subdirs,
        min_w=min_w,
        min_h=min_h,
        dry_run=args.dry_run,
    )
    log(f"[route] kept {len(rows)} valid images.")

    # 3) Metadata
    write_metadata(rows, METADATA_CSV, dry_run=args.dry_run)

    # 4) Train/val/test splits
    make_splits(rows, dry_run=args.dry_run)

    log("[OK] dataset prepared.")


if __name__ == "__main__":
    main()