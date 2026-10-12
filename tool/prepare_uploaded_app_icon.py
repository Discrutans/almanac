"""Prepare uploaded app icon: remove background and export launcher assets."""

from __future__ import annotations

import shutil
from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "branding" / "app_icon_upload.jpg"
OUT = ROOT / "assets" / "branding"
SIZE = 1024
ADAPTIVE_INSET = 96


def _luma(r: int, g: int, b: int) -> float:
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def _is_background(r: int, g: int, b: int, a: int) -> bool:
    if a < 8:
        return True
    lum = _luma(r, g, b)
    spread = max(r, g, b) - min(r, g, b)
    # Soft studio backdrop and drop shadow near edges.
    if lum > 238 and spread < 28:
        return True
    if lum > 220 and spread < 18:
        return True
    return False


def remove_background(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    w, h = rgba.size
    pixels = rgba.load()
    visited = [[False] * w for _ in range(h)]
    queue: deque[tuple[int, int]] = deque()

    for x in range(w):
        queue.append((x, 0))
        queue.append((x, h - 1))
    for y in range(h):
        queue.append((0, y))
        queue.append((w - 1, y))

    while queue:
        x, y = queue.popleft()
        if x < 0 or y < 0 or x >= w or y >= h or visited[y][x]:
            continue
        visited[y][x] = True
        r, g, b, a = pixels[x, y]
        if not _is_background(r, g, b, a):
            continue
        pixels[x, y] = (r, g, b, 0)
        queue.append((x - 1, y))
        queue.append((x + 1, y))
        queue.append((x, y - 1))
        queue.append((x, y + 1))

    return rgba


def trim_transparent(image: Image.Image, *, pad: int = 8) -> Image.Image:
    bbox = image.getbbox()
    if bbox is None:
        return image
    left, top, right, bottom = bbox
    left = max(0, left - pad)
    top = max(0, top - pad)
    right = min(image.width, right + pad)
    bottom = min(image.height, bottom + pad)
    return image.crop((left, top, right, bottom))


def fit_square(image: Image.Image, size: int, *, inset: int = 0) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    inner = size - inset * 2
    scale = min(inner / image.width, inner / image.height)
    draw_w = max(1, round(image.width * scale))
    draw_h = max(1, round(image.height * scale))
    resized = image.resize((draw_w, draw_h), Image.Resampling.LANCZOS)
    offset_x = (size - draw_w) // 2
    offset_y = (size - draw_h) // 2
    canvas.paste(resized, (offset_x, offset_y), resized)
    return canvas


def main() -> None:
    if not SRC.exists():
        raise SystemExit(f"Missing source image: {SRC}")

    OUT.mkdir(parents=True, exist_ok=True)
    cutout = trim_transparent(remove_background(Image.open(SRC)))
    icon = fit_square(cutout, SIZE, inset=40)
    foreground = fit_square(cutout, SIZE, inset=ADAPTIVE_INSET)

    icon.save(OUT / "app_icon.png", optimize=True)
    foreground.save(OUT / "app_icon_foreground.png", optimize=True)
    cutout.save(OUT / "app_icon_cutout.png", optimize=True)

    print(f"Wrote {OUT / 'app_icon.png'}")
    print(f"Wrote {OUT / 'app_icon_foreground.png'}")


if __name__ == "__main__":
    main()
