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

## Finished Todolist

- [x] Add `category` and `super_category` fields to `ItemData`
- [x] Update all existing `.tres` presets with category values

## Itch Demo Todolist

- [ ] Expand clues array to support 4 levels (browse / touch / examine / xray) — currently fixed at 2
- [ ] Add `veiled_types: Array[VeiledType]` field to `ItemData`
    - Lists all possible veiled appearances this item can resolve to at run start
    - One is picked at random (uniform) when `ItemEntry` is generated
    - Define which item presets can spawn as veiled, and assign their candidate `VeiledType` arrays
- [ ] Define `VeiledType` as a designer-authored Resource (`data/_definitions/veiled_type.gd`):
    - `type_id: String` — identifier (e.g. `"unknown_book"`, `"medium_thing"`)
    - `display_label: String` — atmosphere text shown to player (e.g. `"unknown book"`, `"medium thing"`)
    - `base_veiled_price: int` — NPC base estimate used in rolled_price calculation when item is veiled
    - Create `.tres` files under `data/veiled_types/`
- [ ] Define `ItemEntry` as a code-generated runtime class (`game/warehouse/item_entry.gd`):
    - `item_data: ItemData` — reference to the static preset
    - `is_veiled: bool` — whether the item is currently hidden from the player
    - `resolved_veiled_type: VeiledType` — the picked VeiledType (null if not veiled)
    - `inspection_level: int` — 0 / 1 / 2, replaces `inspection_results` Dictionary entry
    - Generated at run start; persists through the full run until appraisal settles
    - Future: may persist into `SaveData` until sold at a shop

## Post Demo Todolist

- [ ] Clue-driven valuation: each clue tag carries its own price range estimate (replaces level-based multipliers)
- [ ] Fake / variant items: two items can share most clues but diverge on the final clue, causing a large valuation surprise at Home Appraisal
