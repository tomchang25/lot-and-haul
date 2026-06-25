# GDScript Naming Conventions

This document defines the naming conventions used in this project.

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
player_controller.gd
item_entry.gd
item_row.gd
run_store.gd
lot_browse_scene.gd
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
PlayerController
ItemData
ItemEntry
ItemRow
RunStore
StaminaHUD
```

Only add `class_name` when the script needs to be referenced by type elsewhere.
Omit it for scene root scripts that are never typed directly.

---

# 3. Variables

Variables use **snake_case**.

Examples:

```
current_slot
paid_price
won_items
layer_index
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
_on_confirm_pressed()
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
action_completed
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

**Exception — preloaded scenes and classes**: Following Godot convention, a constant that holds a preloaded `.gd` class or `.tscn` scene uses **PascalCase** instead of UPPER_SNAKE_CASE, because it represents a type rather than a value.

```gdscript
const ItemRowScene := preload("uid://...")          # PascalCase — loaded type
const DialogScene  := preload("res://ui/dialog.tscn") # PascalCase — loaded type
const MAX_SLOTS    := 6                              # UPPER_SNAKE_CASE — value
const ITEM_COLS    := 2                              # UPPER_SNAKE_CASE — value
```

---

# 7. Enums

Enum names use **PascalCase**. Enum members use **UPPER_SNAKE_CASE**.

Keep enum names singular — they represent a type.

```gdscript
enum Phase {
    SETUP,
    ACTIVE,
    RESOLVE,
    COMPLETE,
}

enum SelectionState {
    NONE,
    SELECTED,
    AVAILABLE,
    BLOCKED,
}
```

Write each member on its own line with a trailing comma. This keeps diffs clean and makes it easy to add documentation comments above individual members.

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
ConfirmButton
ContinueButton
StatusHUD
ActionPopup
```

---

# 9. Indentation

All GDScript files use **4 spaces** per indent level. Tabs are not used.

---

# 10. Folder Naming

All folders use **snake_case**. Whether a folder is **singular** or **plural** is
decided by one semantic test:

> **Is every direct child of this folder an instance of the folder's name (singularized)?**
>
> - **Yes → plural** (the folder is a _collection_ of like things).
> - **No → singular** (the folder is a _namespace / grouping_ of different things).

```
systems/                   # each child IS a system          → plural
  knowledge_system.gd
  meta_system.gd

data/tres/items/           # each child IS an item           → plural
  rusty_sword.tres
  antique_clock.tres

gameplay/                  # children are NOT "gameplays"    → singular
  entry/                   #   ...each folder holds one archetype type → singular
  service/
  snapshot/
```

Notes:

- The test is **semantic**, not lexical. `items/` holds `rusty_sword.tres` (the
  filename does not contain "item") yet is still a collection, so it is plural.
  The easy-to-spot sub-case — children sharing a type suffix like
  `managers/*_manager` — is just the most obvious instance of the same rule.
- **Each folder is judged independently.** Mixed singular/plural siblings under
  one parent are correct, not an inconsistency. `global/` legitimately holds
  `autoloads/` (a collection) next to `theme/` (a single theme).
- A folder holding exactly one canonical resource stays **singular**
  (e.g. `theme/`).

---

# 11. Match Wildcard Rule

The wildcard arm `_:` in `match` statements is reserved for **error handling and truly unexpected values**. Do not use it as the default for a value that is a normal, expected member of the enum or type being matched.

Every expected case must have its own explicit arm. This ensures the compiler
(and the reader) can verify that all cases are covered, and that adding a new
enum member later will surface unhandled branches.

If a `match` covers all members of a known enum exhaustively, the wildcard arm should either be omitted entirely or contain only a `ToastManager.show_dev_error()` / `push_warning` to flag unexpected values at runtime (Recommend). Bare `push_error` is banned by the error-guard standard (`error_guard_standard.md` §3a) — an unexpected match value is a programmer error, so the guard is `show_dev_error`.

---

# Summary

| Type                 | Style                         | Example                   |
| -------------------- | ----------------------------- | ------------------------- |
| Files                | snake_case                    | `item_row.gd`             |
| Classes              | PascalCase                    | `ItemRow`                 |
| Variables            | snake_case                    | `won_items`               |
| Private variables    | \_snake_case                  | `_rolled_price`           |
| Functions            | snake_case                    | `setup()`                 |
| Private functions    | \_snake_case                  | `_populate_rows()`        |
| Signal callbacks     | \_on_snake_case               | `_on_confirm_pressed()`   |
| Signals              | snake_case                    | `tooltip_requested`       |
| Constants            | UPPER_SNAKE_CASE              | `ITEM_COLS`               |
| Preloaded types      | PascalCase                    | `ItemRowScene`            |
| Enums                | PascalCase + UPPER_SNAKE_CASE | `SelectionState.SELECTED` |
| Nodes                | PascalCase                    | `ConfirmButton`           |
| Folders (collection) | snake_case, plural            | `managers/`, `items/`     |
| Folders (namespace)  | snake_case, singular          | `gameplay/`, `theme/`     |
