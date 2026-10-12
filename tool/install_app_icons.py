"""Install user-edited launcher icon PNGs into assets/branding and Android splash."""

from __future__ import annotations

import shutil
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "branding"
SPLASH = (
    ROOT / "android" / "app" / "src" / "main" / "res" / "drawable" / "splash_icon.png"
)
SIZE = 1024


def _normalize(path: Path, *, keep_alpha: bool) -> Image.Image:
    image = Image.open(path).convert("RGBA")
    if image.size != (SIZE, SIZE):
        image = image.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    if not keep_alpha:
        flat = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 255))
        flat.alpha_composite(image)
        return flat
    return image


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit(
            "Usage: python tool/install_app_icons.py <app_icon.png> <app_icon_foreground.png>",
        )

    icon_src = Path(sys.argv[1]).resolve()
    foreground_src = Path(sys.argv[2]).resolve()
    OUT.mkdir(parents=True, exist_ok=True)

    _normalize(icon_src, keep_alpha=False).save(OUT / "app_icon.png", optimize=True)
    foreground = _normalize(foreground_src, keep_alpha=True)
    foreground.save(OUT / "app_icon_foreground.png", optimize=True)
    # Native splash must use the transparent foreground — opaque app_icon
    # paints a black square on the launch screen.
    SPLASH.parent.mkdir(parents=True, exist_ok=True)
    foreground.save(SPLASH, optimize=True)

    shutil.copy2(icon_src, OUT / "app_icon_source.png")
    shutil.copy2(foreground_src, OUT / "app_icon_foreground_source.png")

    print(f"Wrote {OUT / 'app_icon.png'}")
    print(f"Wrote {OUT / 'app_icon_foreground.png'}")
    print(f"Wrote {SPLASH}")


if __name__ == "__main__":
    main()
