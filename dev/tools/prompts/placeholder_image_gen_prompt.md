# Placeholder Icon Generation Prompt

Use this prompt to generate flat transparent PNG placeholder icons for game UI assets. The default visual baseline is `default.png` in this folder, but the prompt is not limited to cars or item categories.

## Variables

- `ENTITY_ID`: snake_case id, for example `handbag`
- `ENTITY_KIND`: optional asset context, for example `item category`, `vehicle`, `location`, or `UI state`
- `SUBJECT`: plain-English subject, for example `a compact handbag`
- `REFERENCE_STYLE`: optional style reference image, default `default.png`
- `TARGET_SIZES`: output sizes in pixels, currently `64, 256`
- `OUTPUT_NAME`: filename stem, for example `handbag_placeholder`

## Prompt

Create a transparent PNG game UI placeholder icon for `ENTITY_ID`.

Context: `ENTITY_KIND`
Subject: `SUBJECT`
Style reference: `REFERENCE_STYLE`
Canvas sizes: `TARGET_SIZES`
Output filenames:

- 64 px: `OUTPUT_NAME`.png
- 256 px: `OUTPUT_NAME`\_256.png

Style requirements:

- Follow the project's placeholder icon style from the style reference.
- Use a simple side, front, or three-quarter icon silhouette, centered on the canvas.
- Transparent background.
- Low-detail flat-color shape language.
- Dark charcoal outline, about 6.25% of the canvas size for the main outer stroke.
- Inner detail strokes about 3.125% of the canvas size.
- No gradients, shadows, texture, antialias-heavy painterly edges, text, labels, logos, or realistic rendering.
- Use large readable shapes that still work when scaled down to 64 px.
- Keep the icon inside a safe margin of about 12.5% of the canvas size.

Palette:

- Outline: `#2b2d36`
- Main neutral fill: `#b7b9c3`
- Secondary warm fill: `#d7d3c8`
- Light highlight fill: `#eef4f8`
- Small accent fill: `#f2d56b`

Composition:

- Use a single recognizable object, emblem, or simplified scene that clearly represents the subject.
- Prefer one bold silhouette plus 2-4 interior details.
- Keep all strokes and details pixel-clean.
- Preserve the same visual weight across all placeholder icons.

Generate every requested size from the same composition.
For 64 px, simplify tiny details if needed.
For 256 px, keep the same flat icon style and do not add extra realism.

## Examples

### Handbag

- `ENTITY_ID`: `handbag`
- `ENTITY_KIND`: `item category`
- `SUBJECT`: `a compact handbag with a short handle, front flap, and small clasp`
- `REFERENCE_STYLE`: `default.png`
- `TARGET_SIZES`: `64, 256`
- `OUTPUT_NAME`: `handbag_placeholder`

### Wristwatch

- `ENTITY_ID`: `wristwatch`
- `ENTITY_KIND`: `item category`
- `SUBJECT`: `a wristwatch with a round face, short strap, two clock hands, and a small crown`
- `REFERENCE_STYLE`: `default.png`
- `TARGET_SIZES`: `64, 256`
- `OUTPUT_NAME`: `wristwatch_placeholder`

### Storage Warehouse

- `ENTITY_ID`: `storage_warehouse`
- `ENTITY_KIND`: `location`
- `SUBJECT`: `a small storage warehouse facade with a roll-up door and simple roofline`
- `REFERENCE_STYLE`: `default.png`
- `TARGET_SIZES`: `64, 256`
- `OUTPUT_NAME`: `storage_warehouse_placeholder`
