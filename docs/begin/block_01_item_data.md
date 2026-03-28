# Block 01 — Item Data

Foundation for all other blocks. No dependencies.

---

## Requirements

- Define `ItemData` as a Godot `Resource`
- Fields:
    - item name
    - true value (integer)
    - weight (float, kg)
    - grid size (int, reserved for future cargo grid — unused this slice)
    - clues array (two strings: index 0 = browse description, index 1 = examine description)
    - `category: String` — fine-grained type (e.g. "Bike", "Pocket Watch")
    - `super_category: String` — broad type (e.g. "Vehicle", "Accessory")
- Create 4 preset `.tres` files with the following values:

    | Name | True Value | Weight | category | super_category |
    |---|---|---|---|---|
    | Old Bicycle | 1100 | 12.0 | Bike | Vehicle |
    | Leather Handbag | 800 | 3.0 | Handbag | Accessory |
    | Brass Lamp | 400 | 5.0 | Lamp | Furniture |
    | Wooden Clock | 200 | 4.0 | Clock | Furniture |

- Each preset must have two clue strings (browse-level and examine-level)
- No logic in this file — pure data

---

## Note

- All other blocks depend on this being done first
- `grid_size` field must exist even though it is not used in this slice
- `category` and `super_category` fields must exist even though merchant filtering is not used in this slice
- Do not add any methods or computed properties to `ItemData`

---

## MVP Todolist

- [ ] Add `category` and `super_category` fields to `ItemData`
- [ ] Update all existing `.tres` presets with category values

## Itch Demo Todolist

- [ ] Expand clues array to support 4 levels (browse / touch / examine / xray) — currently fixed at 2
- [ ] Add `ItemRunContext` resource (per-run generated state separate from static `ItemData`):
    - `is_veiled: bool` — whether the item appears as unknown size/type at run start
    - veiled items display only as "Large / Medium / Small item", no name or category shown
    - veil is lifted after first inspect action
- [ ] Define which item presets spawn as veiled by default

## Post Demo Todolist

- [ ] Clue-driven valuation: each clue tag carries its own price range estimate (replaces level-based multipliers)
- [ ] Fake / variant items: two items can share most clues but diverge on the final clue, causing a large valuation surprise at Home Appraisal
