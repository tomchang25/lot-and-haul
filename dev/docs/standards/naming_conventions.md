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
item_entry.gd
item_row.gd
item_view_context.gd
run_record.gd
location_browse_scene.gd
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
ItemEntry
ItemRow
ItemViewContext
RunRecord
LotEntry
StaminaHUD
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
layer_index
cargo_items
browse_index
```

Private variables use a leading underscore.

```
_rolled_price
_selected
_rows
_ctx
_tooltip
_active_item
```

Avoid abbreviations unless they are very common.

Never shorten node-reference variable names. Write the full semantic word.
```gdscript
_name_label       # ok
_name_lbl         # NEVER

_row_container    # ok
_row_cont         # NEVER

_reveal_btn       # ok — "btn" is a universally understood abbreviation
_reveal_button    # also ok
```

---

# 4. Functions

Functions use **snake_case**.

Examples:

```
setup()
refresh()
populate()
get_selected_items()
get_npc_estimate()
```

Private functions use a leading underscore.

```
_build_ui()
_recalc_totals()
_refresh_ui()
_populate_rows()
_commit_result()
_show_summary()
_inject_fake_state()
```

Signal callbacks use `_on_` prefix.

```
_on_bid_pressed()
_on_reveal_pressed()
_on_item_clicked()
_on_row_tooltip_requested()
_on_continue_pressed()
```

---

# 5. Signals

Signals use **snake_case**.

Examples:

```
item_toggled
reveal_completed
run_finished
tooltip_requested
tooltip_dismissed
row_pressed
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
ITEM_COLS
ITEM_SIZE
GRID_ORIGIN
```

**Exception — preloaded scenes and classes**: Following Godot convention, a constant that holds
a preloaded `.gd` class or `.tscn` scene uses **PascalCase** instead of UPPER_SNAKE_CASE,
because it represents a type rather than a value.

```gdscript
const ItemRowScene    := preload("uid://brx8agwvlpi3f")   # PascalCase — loaded type
const CargoScene      := preload("res://game/cargo/cargo_scene.tscn")  # PascalCase — loaded type
const MAX_SLOTS       := 6                                # UPPER_SNAKE_CASE — value
const ITEM_COLS       := 2                                # UPPER_SNAKE_CASE — value
```

---

# 7. Enums

Enum names use **PascalCase**. Enum members use **UPPER_SNAKE_CASE**.

Keep enum names singular — they represent a type.

```gdscript
enum Stage {
    INSPECTION,
    LIST_REVIEW,
    REVEAL,
    CARGO,
    RUN_REVIEW,
}

enum CargoState {
    NONE,
    SELECTED,
    AVAILABLE,
    BLOCKED,
}
```

Write each member on its own line with a trailing comma. This keeps diffs clean and
makes it easy to add documentation comments above individual members.

```gdscript
# Good
enum ConditionMode {
    RESPECT_INSPECT_LEVEL,
    FORCE_INSPECT_MAX,
    FORCE_TRUE_VALUE,
}

# Bad
enum ConditionMode { RESPECT_INSPECT_LEVEL, FORCE_INSPECT_MAX, FORCE_TRUE_VALUE }
```

---

# 8. Node Names

Node names in scenes use **PascalCase**.

Examples:

```
RootVBox
ItemPanel
RowContainer
SummaryContainer
RevealButton
ContinueButton
StaminaHUD
ActionPopup
ListReviewPopup
```

---

# Summary

| Type | Style | Example |
|---|---|---|
| Files | snake_case | `item_row.gd` |
| Classes | PascalCase | `ItemRow` |
| Variables | snake_case | `won_items` |
| Private variables | _snake_case | `_rolled_price` |
| Functions | snake_case | `setup()` |
| Private functions | _snake_case | `_populate_rows()` |
| Signal callbacks | _on_snake_case | `_on_reveal_pressed()` |
| Signals | snake_case | `tooltip_requested` |
| Constants | UPPER_SNAKE_CASE | `ITEM_COLS` |
| Preloaded types | PascalCase | `ItemRowScene` |
| Enums | PascalCase + UPPER_SNAKE_CASE | `CargoState.SELECTED` |
| Nodes | PascalCase | `RevealButton` |
