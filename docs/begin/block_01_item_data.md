# Block 01 — Item Data

Foundation for all other blocks. No dependencies.

---

## Requirements

- Define `ItemData` as a Godot `Resource`
- Fields:
    - item name
    - true value (integer)
    - weight (float, kg)
    - grid size (Vector2i, reserved for future cargo grid — unused this slice)
    - clues array (two strings: index 0 = browse description, index 1 = examine description)
- Create 4 preset `.tres` files with the following values:

    | Name | True Value | Weight |
    |---|---|---|
    | Old Bicycle | 1100 | 12.0 |
    | Leather Handbag | 800 | 3.0 |
    | Brass Lamp | 400 | 5.0 |
    | Wooden Clock | 200 | 4.0 |

- Each preset must have two clue strings (browse-level and examine-level)
- No logic in this file — pure data

---

## Note

- All other blocks depend on this being done first
- `grid size` field must exist even though it is not used in this slice
- Do not add any methods or computed properties to `ItemData`
