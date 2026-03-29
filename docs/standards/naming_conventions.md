# Lot & Haul Naming Conventions

This document defines the naming conventions used in the Lot & Haul project.

The goal is to keep the project:

- consistent
- readable
- easy to search
- aligned with Godot conventions

---

# 1. File Naming

All files use **snake_case**.

Examples:

```
cargo_scene.gd
auction_scene.gd
cargo_item_row.gd
item_display.gd
appraisal_testbed.gd
```

Scene files match their script names.

```
cargo_scene.tscn
cargo_scene.gd
```

---

# 2. Class Names

Classes use **PascalCase**.

Examples:

```
CargoScene
ItemData
CargoItemRow
AppraisalItemRow
StaminaHud
```

Only add `class_name` when the script needs to be referenced by type elsewhere.
Omit it for scene root scripts that are never typed directly.

---

# 3. Variables

Variables use **snake_case**.

Examples:

```
current_lot
paid_price
won_items
reveal_index
slots_used
```

Private variables use a leading underscore.

```
_rolled_price
_selected
_rows
_bid_enabled
```

Avoid abbreviations unless they are very common.

---

# 4. Functions

Functions use **snake_case**.

Examples:

```
setup()
reveal()
get_selected_items()
```

Private functions use a leading underscore.

```
_build_ui()
_recalc_totals()
_refresh_ui()
_init_auction()
_populate_rows()
```

Signal callbacks use `_on_` prefix.

```
_on_bid_pressed()
_on_reveal_pressed()
_on_item_toggled()
```

---

# 5. Signals

Signals use **snake_case**.

Examples:

```
item_toggled
reveal_completed
run_finished
```

---

# 6. Constants

Constants use **UPPER_SNAKE_CASE** with no leading underscore.

Examples:

```
MAX_SLOTS
MAX_WEIGHT
OPENING_BID_FACTOR
PRICE_TWEEN_SEC
COSMETIC_BUMP
```

---

# 7. Enums

Enums use **PascalCase** for the enum name and **UPPER_SNAKE_CASE** for values.

Example:

```gdscript
enum InspectionAction {
    BROWSE,
    TOUCH,
    EXAMINE,
}
```

---

# 8. Node Names

Node names in scenes use **PascalCase**.

Examples:

```
RootVBox
ItemPanel
ColumnHeader
SummaryContainer
RevealButton
ContinueButton
```

---

# Summary

| Type | Style | Example |
|---|---|---|
| Files | snake_case | `cargo_item_row.gd` |
| Classes | PascalCase | `CargoItemRow` |
| Variables | snake_case | `won_items` |
| Private variables | _snake_case | `_rolled_price` |
| Functions | snake_case | `setup()` |
| Private functions | _snake_case | `_build_ui()` |
| Signal callbacks | _on_snake_case | `_on_bid_pressed()` |
| Signals | snake_case | `item_toggled` |
| Constants | UPPER_SNAKE_CASE | `MAX_SLOTS` |
| Enums | PascalCase + UPPER_SNAKE_CASE | `InspectionAction.BROWSE` |
| Nodes | PascalCase | `RevealButton` |