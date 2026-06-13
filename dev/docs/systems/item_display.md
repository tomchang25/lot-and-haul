# Item Display

`ItemRow`, `ItemCard`, and `ItemListPanel` under `game/shared/item_display/` are the components that render items across scenes.

The cross-cutting invariant that all consuming scenes must respect: there is **no `ItemViewContext`** — every visible value (name + colour, estimated value, base value, condition, rarity, weight, grid, inspection level, sort key) is a getter on `ItemEntry`. Components take an `ItemEntry` directly. Veil state is read via the entry's veil check: veiled items return `"???"` and hide most fields until the item is unveiled. Column visibility and left-to-right order are driven entirely by each consuming scene passing its own ordered column array to `setup()` — no component hard-codes a column set.

Component behaviour, field names, and signal signatures live in the individual `.gd` file headers (`item_row.gd`, `item_card.gd`, `item_list_panel.gd`).
