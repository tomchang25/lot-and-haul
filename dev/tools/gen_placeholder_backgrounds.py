# gen_placeholder_backgrounds.py
# Dev tool — generate simple 1920x1080 placeholder location backgrounds.
# Output: assets/backgrounds/<location_id>.png
# Re-run after tweaking palettes; safe to delete the PNGs and regenerate.

from __future__ import annotations

import os
from PIL import Image, ImageDraw, ImageFont

W, H = 1920, 1080
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "backgrounds")


def lerp(
    a: tuple[int, int, int], b: tuple[int, int, int], t: float
) -> tuple[int, int, int]:
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def vgradient(draw: ImageDraw.ImageDraw, top, bottom, y0: int, y1: int) -> None:
    span = max(1, y1 - y0)
    for y in range(y0, y1):
        t = (y - y0) / span
        draw.line([(0, y), (W, y)], fill=lerp(top, bottom, t))


def draw_title(draw: ImageDraw.ImageDraw, title: str) -> None:
    """Draw a centered title with a dark background pill near the top."""
    try:
        font = ImageFont.truetype("arial.ttf", 48)
    except OSError:
        try:
            font = ImageFont.truetype(
                "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 48
            )
        except OSError:
            font = ImageFont.load_default()

    bbox = draw.textbbox((0, 0), title, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    pad_x, pad_y = 32, 14
    tx = (W - tw) // 2
    ty = 48

    # Dark background pill.
    draw.rounded_rectangle(
        [tx - pad_x, ty - pad_y, tx + tw + pad_x, ty + th + pad_y],
        radius=12,
        fill=(16, 14, 18),
    )
    # Subtle border.
    draw.rounded_rectangle(
        [tx - pad_x, ty - pad_y, tx + tw + pad_x, ty + th + pad_y],
        radius=12,
        outline=(60, 54, 50),
        width=2,
    )
    draw.text((tx, ty), title, font=font, fill=(230, 220, 200))


def suburban_storage(title: str = "Suburban Storage") -> Image.Image:
    """Quiet self-storage at dusk: warm sky, a low row of roll-up doors."""
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)

    # Sky: deep indigo -> warm amber at the horizon.
    horizon = int(H * 0.62)
    vgradient(d, (38, 32, 58), (214, 126, 64), 0, horizon)
    # Ground: dim asphalt.
    vgradient(d, (40, 34, 34), (22, 19, 20), horizon, H)

    # Distant tree/hill silhouette band just above the units.
    band = horizon - 28
    d.rectangle([0, band, W, horizon], fill=(28, 24, 34))

    # Row of storage units (silhouette block with roll-up door seams).
    unit_top = horizon - 150
    d.rectangle([0, unit_top, W, horizon], fill=(20, 17, 22))
    # Roof line highlight catching the last light.
    d.rectangle([0, unit_top, W, unit_top + 6], fill=(150, 96, 70))
    # Door seams + faint highlight per unit.
    door_w = 150
    x = 40
    while x < W:
        d.line([(x, unit_top + 10), (x, horizon)], fill=(8, 7, 10), width=3)
        d.rectangle(
            [x + 8, unit_top + 18, x + door_w - 8, horizon - 6], fill=(30, 25, 30)
        )
        for ry in range(unit_top + 30, horizon - 6, 18):
            d.line([(x + 8, ry), (x + door_w - 8, ry)], fill=(22, 18, 23), width=2)
        x += door_w

    draw_title(d, title)
    return img


def midtown_warehouse(title: str = "Midtown Warehouse") -> Image.Image:
    """Commercial district at night: cool sky, city skyline, big warehouse block."""
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)

    horizon = int(H * 0.70)
    # Sky: near-black blue -> teal city glow.
    vgradient(d, (12, 16, 30), (36, 58, 78), 0, horizon)
    # Ground: cold concrete.
    vgradient(d, (30, 34, 40), (16, 18, 22), horizon, H)

    # Far skyline: staggered building silhouettes with lit windows.
    import random

    random.seed(7)
    x = -20
    while x < W:
        bw = random.randint(70, 150)
        bh = random.randint(160, 380)
        top = horizon - bh
        d.rectangle([x, top, x + bw, horizon], fill=(18, 22, 34))
        for wy in range(top + 16, horizon - 12, 22):
            for wx in range(x + 10, x + bw - 10, 20):
                if random.random() < 0.35:
                    d.rectangle([wx, wy, wx + 7, wy + 11], fill=(210, 190, 120))
        x += bw + random.randint(4, 16)

    # Foreground warehouse block (big, dark, dominant).
    wh_top = horizon - 120
    d.rectangle([0, wh_top, W, horizon], fill=(14, 16, 22))
    # Sawtooth roof line.
    step = 160
    for sx in range(0, W, step):
        d.polygon(
            [(sx, wh_top), (sx + step // 2, wh_top - 46), (sx + step, wh_top)],
            fill=(14, 16, 22),
        )
    # Loading-bay doors glowing faintly.
    bay_w = 220
    for bx in range(120, W - 120, 360):
        d.rectangle([bx, wh_top + 30, bx + bay_w, horizon - 8], fill=(34, 40, 52))
        d.rectangle(
            [bx + 6, wh_top + 36, bx + bay_w - 6, horizon - 14], fill=(46, 56, 72)
        )

    draw_title(d, title)
    return img


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    builders = {
        "suburban_storage": suburban_storage,
        "midtown_warehouse": midtown_warehouse,
    }
    for name, fn in builders.items():
        path = os.path.normpath(os.path.join(OUT_DIR, f"{name}.png"))
        fn().save(path)
        print(f"wrote {path}")


if __name__ == "__main__":
    main()
