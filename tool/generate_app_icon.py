"""Generate Almanac launcher icons matching in-app Icons.today_rounded."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

SIZE = 1024
OUT = Path(__file__).resolve().parent.parent / "assets" / "branding"
VIEWBOX = 24.0

# AlmanacBrand.accentEnd
BRAND = (207, 46, 100)
BORDER = (0, 0, 0)
GLYPH = (255, 255, 255)

SQUARE_INSET = 52
BORDER_WIDTH = 36
CORNER_RADIUS = 204
GLYPH_INSET = 28


def _outer_box(square_inset: int) -> tuple[int, int, int, int]:
    return square_inset, square_inset, SIZE - square_inset, SIZE - square_inset


def _brand_box(square_inset: int) -> tuple[int, int, int, int]:
    return (
        square_inset + BORDER_WIDTH,
        square_inset + BORDER_WIDTH,
        SIZE - square_inset - BORDER_WIDTH,
        SIZE - square_inset - BORDER_WIDTH,
    )


def _glyph_box(square_inset: int, glyph_inset: int) -> tuple[int, int, int, int]:
    left, top, right, bottom = _brand_box(square_inset)
    return (
        left + glyph_inset,
        top + glyph_inset,
        right - glyph_inset,
        bottom - glyph_inset,
    )


def _draw_shell(draw: ImageDraw.ImageDraw, square_inset: int) -> None:
    outer = _outer_box(square_inset)
    brand = _brand_box(square_inset)
    inner_radius = max(CORNER_RADIUS - BORDER_WIDTH, 0)

    draw.rounded_rectangle(outer, radius=CORNER_RADIUS, fill=BORDER)
    draw.rounded_rectangle(brand, radius=inner_radius, fill=BRAND)


def _draw_glyph(
    draw: ImageDraw.ImageDraw,
    square_inset: int,
    glyph_inset: int,
) -> None:
    """Draw Icons.today_rounded as a white outline on the brand fill."""
    left, top, right, bottom = _glyph_box(square_inset, glyph_inset)
    scale = min(right - left, bottom - top) / VIEWBOX
    offset_x = left + ((right - left) - scale * VIEWBOX) / 2
    offset_y = top + ((bottom - top) - scale * VIEWBOX) / 2

    def box(
        x1: float,
        y1: float,
        x2: float,
        y2: float,
    ) -> tuple[float, float, float, float]:
        return (
            offset_x + x1 * scale,
            offset_y + y1 * scale,
            offset_x + x2 * scale,
            offset_y + y2 * scale,
        )

    stroke = max(int(round(scale * 1.65)), 4)
    small_radius = max(int(round(scale * 0.9)), 2)
    body_radius = max(int(round(scale * 2.0)), 4)
    marker_radius = max(int(round(scale * 0.55)), 2)

    # Calendar body — stroke only, brand color shows through the inside.
    draw.rounded_rectangle(
        box(5, 4, 19, 20),
        radius=body_radius,
        outline=GLYPH,
        width=stroke,
    )

    # Binding tabs at the top.
    for tab_left in (7.0, 13.0):
        draw.rounded_rectangle(
            box(tab_left, 2.2, tab_left + 2, 4.8),
            radius=small_radius,
            fill=GLYPH,
        )

    # Header divider.
    x_left, y_header, x_right, _ = box(5.5, 8, 18.5, 8)
    draw.line(
        [(x_left, y_header), (x_right, y_header)],
        fill=GLYPH,
        width=stroke,
    )

    # Today marker — filled square, visible on the brand background.
    draw.rounded_rectangle(
        box(8, 10, 11, 13),
        radius=marker_radius,
        fill=GLYPH,
    )


def build_icon(*, adaptive_safe_zone: bool = False) -> Image.Image:
    square_inset = 96 if adaptive_safe_zone else SQUARE_INSET
    glyph_inset = 44 if adaptive_safe_zone else GLYPH_INSET

    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    _draw_shell(draw, square_inset)
    _draw_glyph(draw, square_inset, glyph_inset)
    return image


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    build_icon().save(OUT / "app_icon.png", optimize=True)
    build_icon(adaptive_safe_zone=True).save(
        OUT / "app_icon_foreground.png",
        optimize=True,
    )
    print(f"Wrote {OUT / 'app_icon.png'}")
    print(f"Wrote {OUT / 'app_icon_foreground.png'}")


if __name__ == "__main__":
    main()
