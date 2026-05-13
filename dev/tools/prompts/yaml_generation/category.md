# Lot & Haul - Category YAML Generation Standard

Use this with `base.md` when generating `categories:` data.

## Output Root

The YAML must begin with:

```yaml
categories:
```

Do not include `identity_layers:` or `items:` unless the user explicitly asks for complete item-category output and the item prompt is also provided.

## Schema

```yaml
categories:
  - category_id: snake_case string
    super_category: string
    display_name: string
    weight: float
    shape_id: string
```

## Fields

- `category_id`: unique snake_case ID. Must match the `.tres` filename stem.
- `super_category`: broad type shown in UI, such as `Fine Art`, `Weapon`, `Furniture`, `Decorative`, `Fashion`.
- `display_name`: fine-grained player-facing category label, such as `Oil Lamp`, `Pocket Watch`, `Handbag`.
- `weight`: typical item weight in kilograms for this category.
- `shape_id`: cargo grid footprint.

## Valid Shape IDs

- `s1x1`: 1 cell. Coin, keychain, small figurine.
- `s1x2`: 2 cells. Oil lamp, pocket watch, small vase.
- `s1x3`: 3 cells. Clock, poster, typewriter.
- `s1x4`: 4 cells. Very long thin object.
- `s2x2`: 4 cells square. Compact square item, small crate.
- `s2x3`: 6 cells rectangle. Bicycle, sewing machine.
- `s2x4`: 8 cells rectangle. Motorcycle, automobile, large machine.
- `sL11`: 3 cells, small L. Pistol, short tool with grip.
- `sL12`: 4 cells, tall L. Rifle, walking cane, long tool with handle.
- `sT3`: 4 cells, T shape. Crossbow, wide object with central stem.

## Design Rules

- Choose the shape that best matches the real-world silhouette, not just the item's value.
- Use one category per coherent physical form. Do not merge unrelated forms just because they share a theme.
- Keep `display_name` specific enough for UI filtering but broad enough to contain many items.
- Use realistic weights. Avoid exaggerated weights unless the category is genuinely heavy.

## Validation Checklist

- `categories:` block is present.
- Every `category_id` is unique.
- Every `category_id` is snake_case.
- Every category has `super_category`, `display_name`, `weight`, and `shape_id`.
- Every `shape_id` is one of the valid IDs.
- Every `weight` is a positive number.
