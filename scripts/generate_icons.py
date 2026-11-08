"""Render SideScreen's geometric mark. Requires Pillow only for regeneration."""
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]


def render(path: Path, size: int):
    # Opaque full-bleed background is compatible with iOS and maskable icons.
    scale = 4
    image = Image.new("RGB", (size * scale, size * scale), "#18313F")
    draw = ImageDraw.Draw(image)
    unit = size * scale / 100
    for rect, color in [
        ((23, 24, 45, 76), "#A6D4CA"),
        ((51, 24, 77, 54), "#F5F7F9"),
        ((51, 60, 77, 76), "#6689EC"),
    ]:
        draw.rounded_rectangle(tuple(round(v * unit) for v in rect),
                               radius=round(4 * unit), fill=color)
    path.parent.mkdir(parents=True, exist_ok=True)
    image.resize((size, size), Image.Resampling.LANCZOS).save(path)


if __name__ == "__main__":
    for density, size in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        render(ROOT / f"android/app/src/main/res/mipmap-{density}/ic_launcher.png", size)
    icons = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    for spec in json.loads((icons / "Contents.json").read_text())["images"]:
        render(icons / spec["filename"], round(float(spec["size"].split("x")[0]) * float(spec["scale"][:-1])))
    render(ROOT / "web/favicon.png", 64)
    for size in (192, 512):
        render(ROOT / f"web/icons/Icon-{size}.png", size)
        render(ROOT / f"web/icons/Icon-maskable-{size}.png", size)
    print("Generated Android, iOS and web icons.")
