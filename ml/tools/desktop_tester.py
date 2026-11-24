"""Desktop GUI to try the model on your own photos (Tkinter).

Usage (from the ml/ folder):
    python tools/desktop_tester.py
"""
from __future__ import annotations

import platform
import sys
import tkinter as tk
from pathlib import Path
from tkinter import filedialog, messagebox

from PIL import ImageTk

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from preprocess import IMAGE_EXTENSIONS, list_images, load_image  # noqa: E402
from tflite_model import FakeImageDetector  # noqa: E402

LIGHT = {"bg": "#f4f4f4", "fg": "#222222", "panel": "#dcdcdc"}
DARK = {"bg": "#222222", "fg": "#f1f1f1", "panel": "#333333"}


class DesktopTester:
    def __init__(self, root: tk.Tk, detector: FakeImageDetector):
        self.root = root
        self.detector = detector
        self.theme = LIGHT
        self._photo = None

        root.title("Roofinity - Fake Property Image Detector")
        root.geometry("900x700")
        root.minsize(700, 550)

        toolbar = tk.Frame(root)
        toolbar.pack(side="top", fill="x", padx=8, pady=6)
        tk.Button(toolbar, text="Choose Image", width=16, bg="#005D8C", fg="white",
                  command=self.open_image).pack(side="left", padx=4)
        tk.Button(toolbar, text="Batch Test Folder", width=16, bg="#1E8E3E", fg="white",
                  command=self.batch_test).pack(side="left", padx=4)
        tk.Button(toolbar, text="Toggle Theme", width=14,
                  command=self.toggle_theme).pack(side="left", padx=4)

        content = tk.Frame(root)
        content.pack(fill="both", expand=True, padx=12, pady=8)
        self.preview = tk.Label(content, relief="ridge", bd=2, text="No image selected")
        self.preview.pack(side="left", fill="both", expand=True, padx=(0, 12))

        side = tk.Frame(content, width=260)
        side.pack(side="right", fill="y")
        self.result = tk.Label(side, text="", font=("Arial", 16, "bold"), wraplength=240, justify="left")
        self.result.pack(pady=(10, 6), anchor="w")
        self.details = tk.Label(side, text=f"Threshold: {detector.threshold:.3f}",
                                font=("Arial", 10), wraplength=240, justify="left")
        self.details.pack(anchor="w")

        self.status = tk.Label(root, text=f"Model: {detector.model_path}", bd=1, relief="sunken", anchor="w")
        self.status.pack(side="bottom", fill="x")

        shortcut = "<Command-o>" if platform.system() == "Darwin" else "<Control-o>"
        root.bind_all(shortcut, lambda _e: self.open_image())
        self.frames = [root, toolbar, content, side, self.result, self.details]
        self.apply_theme()

    def apply_theme(self) -> None:
        for widget in self.frames:
            widget.configure(bg=self.theme["bg"])
        for label in (self.result, self.details):
            label.configure(fg=self.theme["fg"])
        self.preview.configure(bg=self.theme["panel"], fg=self.theme["fg"])

    def toggle_theme(self) -> None:
        self.theme = DARK if self.theme is LIGHT else LIGHT
        self.apply_theme()

    def open_image(self) -> None:
        patterns = " ".join(f"*{ext}" for ext in sorted(IMAGE_EXTENSIONS))
        path = filedialog.askopenfilename(title="Open image", filetypes=[("Images", patterns)])
        if path:
            self.show_prediction(Path(path))

    def show_prediction(self, path: Path) -> None:
        try:
            image = load_image(path)
            score = self.detector.fake_probability(path)
        except Exception as exc:  # show any read/inference error to the user
            messagebox.showerror("Error", f"Could not process image:\n{exc}")
            return

        image.thumbnail((620, 560))
        self._photo = ImageTk.PhotoImage(image)
        self.preview.configure(image=self._photo, text="")

        is_fake = score > self.detector.threshold
        self.result.configure(text="FAKE image" if is_fake else "Real image",
                              fg="#d93025" if is_fake else "#1e8e3e")
        self.details.configure(text=f"Fake probability: {score:.2%}\nThreshold: {self.detector.threshold:.3f}")
        self.status.configure(text=f"{path.name} -> {'FAKE' if is_fake else 'real'} ({score:.2%})")

    def batch_test(self) -> None:
        folder = filedialog.askdirectory(title="Select a folder of images")
        if not folder:
            return
        images = list_images(folder)
        if not images:
            messagebox.showinfo("Batch test", "No images found in that folder.")
            return

        lines, fake = [], 0
        for path in images:
            try:
                score = self.detector.fake_probability(path)
                verdict = "FAKE" if score > self.detector.threshold else "real"
                fake += verdict == "FAKE"
                lines.append(f"{verdict:<4}  {score:6.2%}  {path.name}")
            except Exception as exc:
                lines.append(f"ERROR  {path.name}: {exc}")

        report = Path(folder) / "batch_test_results.txt"
        report.write_text("\n".join(lines), encoding="utf-8")
        messagebox.showinfo("Batch test",
                            f"{fake} of {len(images)} image(s) flagged as fake.\n\nFull results: {report}")


def main() -> None:
    root = tk.Tk()
    DesktopTester(root, FakeImageDetector())
    root.mainloop()


if __name__ == "__main__":
    main()
