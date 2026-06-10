# gen_placeholder_backgrounds.py
# Dev tool — generate simple 1920x1080 placeholder location backgrounds.
# Output: assets/backgrounds/<location_id>_exterior.png
#         assets/backgrounds/<location_id>_interior.png
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


# ── Suburban Storage ──────────────────────────────────────────────────────────


def suburban_storage_exterior(title: str = "Suburban Storage") -> Image.Image:
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


def suburban_storage_interior(title: str = "Suburban Storage — Inside") -> Image.Image:
    """Inside a storage hallway: concrete floor, unit doors lining both walls."""
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)

    # Background wall / ceiling: warm dim concrete.
    vgradient(d, (38, 32, 30), (28, 24, 24), 0, H)

    # Ceiling strip lights.
    light_y = 40
    light_h = 18
    for lx in range(200, W - 200, 320):
        d.rectangle([lx, light_y, lx + 180, light_y + light_h], fill=(220, 210, 185))

    # Vanishing-point corridor: floor perspective lines.
    cx, cy = W // 2, int(H * 0.52)
    vgradient(d, (34, 29, 27), (18, 15, 14), cy, H)
    for i in range(0, W, 80):
        d.line([(i, H), (cx, cy)], fill=(26, 22, 20), width=1)

    # Left wall — row of orange-accented roll-up doors.
    door_w = 180
    door_h = int(H * 0.48)
    door_top = int(H * 0.08)
    for i in range(6):
        dx = i * door_w
        d.rectangle(
            [dx, door_top, dx + door_w - 4, door_top + door_h], fill=(44, 36, 32)
        )
        d.rectangle(
            [dx + 6, door_top + 4, dx + door_w - 10, door_top + 24], fill=(160, 80, 30)
        )
        for ry in range(door_top + 30, door_top + door_h - 6, 20):
            d.line([(dx + 6, ry), (dx + door_w - 10, ry)], fill=(34, 28, 24), width=2)

    # Right wall — mirror set, slightly darker.
    for i in range(6):
        dx = W - (i + 1) * door_w
        d.rectangle(
            [dx + 4, door_top, dx + door_w, door_top + door_h], fill=(38, 32, 28)
        )
        d.rectangle(
            [dx + 10, door_top + 4, dx + door_w - 6, door_top + 24], fill=(140, 70, 26)
        )
        for ry in range(door_top + 30, door_top + door_h - 6, 20):
            d.line([(dx + 10, ry), (dx + door_w - 6, ry)], fill=(30, 24, 20), width=2)

    draw_title(d, title)
    return img


# ── Midtown Warehouse ─────────────────────────────────────────────────────────


def midtown_warehouse_exterior(title: str = "Midtown Warehouse") -> Image.Image:
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


def midtown_warehouse_interior(
    title: str = "Midtown Warehouse — Inside",
) -> Image.Image:
    """Inside a large commercial warehouse: high ceiling, shelving rows, cold blue light."""
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)

    # Background wall / ceiling: cool dark blue-grey.
    vgradient(d, (14, 18, 28), (22, 26, 36), 0, H)

    # High ceiling — industrial strip lighting in two rows.
    for row_y in (30, 80):
        for lx in range(80, W - 80, 280):
            d.rectangle([lx, row_y, lx + 220, row_y + 16], fill=(180, 200, 230))

    # Concrete floor with perspective.
    floor_y = int(H * 0.55)
    vgradient(d, (28, 32, 40), (16, 18, 24), floor_y, H)
    cx = W // 2
    for i in range(0, W, 100):
        d.line([(i, H), (cx, floor_y)], fill=(20, 24, 32), width=1)

    # Heavy metal shelving units receding into the distance.
    shelf_top = int(H * 0.10)
    shelf_h = int(H * 0.45)
    shelf_w = 260
    gap = 40

    # Left column of shelves.
    for col in range(5):
        sx = col * (shelf_w + gap)
        d.rectangle(
            [sx, shelf_top, sx + shelf_w, shelf_top + shelf_h], fill=(22, 28, 38)
        )
        # Shelf rails.
        for ry in range(shelf_top + 20, shelf_top + shelf_h, 60):
            d.rectangle([sx + 4, ry, sx + shelf_w - 4, ry + 8], fill=(34, 42, 56))
        # Cargo boxes on shelves.
        for ry in range(shelf_top + 28, shelf_top + shelf_h - 20, 60):
            for bx in range(sx + 8, sx + shelf_w - 8, 54):
                d.rectangle([bx, ry, bx + 46, ry + 34], fill=(48, 44, 36))
                d.rectangle([bx + 4, ry + 4, bx + 42, ry + 12], fill=(58, 54, 44))

    # Right column of shelves.
    for col in range(5):
        sx = W - (col + 1) * (shelf_w + gap)
        d.rectangle(
            [sx, shelf_top, sx + shelf_w, shelf_top + shelf_h], fill=(18, 24, 34)
        )
        for ry in range(shelf_top + 20, shelf_top + shelf_h, 60):
            d.rectangle([sx + 4, ry, sx + shelf_w - 4, ry + 8], fill=(28, 36, 50))
        for ry in range(shelf_top + 28, shelf_top + shelf_h - 20, 60):
            for bx in range(sx + 8, sx + shelf_w - 8, 54):
                d.rectangle([bx, ry, bx + 46, ry + 34], fill=(40, 38, 30))
                d.rectangle([bx + 4, ry + 4, bx + 42, ry + 12], fill=(50, 48, 38))

    draw_title(d, title)
    return img


# ── Entry point ───────────────────────────────────────────────────────────────


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    builders = {
        "suburban_storage_exterior": suburban_storage_exterior,
        "suburban_storage_interior": suburban_storage_interior,
        "midtown_warehouse_exterior": midtown_warehouse_exterior,
        "midtown_warehouse_interior": midtown_warehouse_interior,
    }
    for name, fn in builders.items():
        path = os.path.normpath(os.path.join(OUT_DIR, f"{name}.png"))
        fn().save(path)
        print(f"wrote {path}")


if __name__ == "__main__":
    main()
