# Block Scene Architecture Standard

This document defines the structural rules for block scene scripts.

Applies to:

- Block scene root scripts
- Testbed scenes
- Reusable UI component scripts

Does **not** apply to:

- Autoloads and global managers
- Resource definitions under `data/`
- Common framework scripts

---

# 1. File Header

Every script must begin with a file header comment block.

Format:

```gdscript
# script_name.gd
# Block XX — One-line description of this block's responsibility.
# Reads:  StateManager.state.field_name
# Writes: StateManager.state.field_name
```

Rules:

- The first line is the filename.
- The second line is the block number and a single-sentence description.
- `Reads` and `Writes` list every managed state field this script touches.
- If the script reads nothing, omit the `Reads` line.
- If the script writes nothing, omit the `Writes` line.

Testbed variant:

```gdscript
# script_name.gd
# Block XX testbed — one-line description of what it bypasses and tests.
#
# Run this scene to test [Feature] in isolation.
# Edit the @export fields in the Inspector to configure fake state.
```

---

# 2. Declaration Order

Declarations at the top of the file follow this order:

```
@tool (if needed)
extends
class_name (if needed)

signals
enums

const
preload constants

@export / @export_group

private variables

@onready
```

Rules:

- `@tool` goes on the very first line when present, before `extends`.
- Signals are declared before constants so they appear first in the class contract.
- Enums follow signals, as they can be used as export type hints and const initializers.
- Constants and preloads come before `@export` so export default values can reference them.
- `@onready` goes last because it is resolved after `_ready()` enters the scene tree.
- `class_name` is only added when the script needs to be referenced by type elsewhere.
  Omit it for scene root scripts that are never typed directly.

---

# 3. Variable Block Headers (single-line)

Variable groups at the top of the file use the **single-line** (`──`) format.

```gdscript
# ── Group name ────────────────────────────────────────────────────────────────
```

The dashes extend to column 80. Use a consistent label from the table below.

Standard variable groups, in order:

| Header                             | Contents                                          |
| ---------------------------------- | ------------------------------------------------- |
| `# ── Constants ──...`             | `const` and `preload`                             |
| `# ── Exports ──...`               | `@export` vars                                    |
| `# ── State ──...`                 | Runtime logic variables                           |
| `# ── Timer / tween handles ──...` | `Timer`, `Tween` vars                             |
| `# ── Node references ──...`       | `@onready` node references bound to `.tscn` nodes |

Rules:

- Only include groups that have at least one variable.
- Do not create custom group names unless no standard label fits.

---

# 4. Function Section Headers (double-line)

Function groups use the **double-line** (`══`) format.

```gdscript
# ══ Section name ══════════════════════════════════════════════════════════════
```

The `═` characters extend to column 80.

---

# 5. Section Order

Sections appear in this fixed order:

```
Inner classes (if any)

Lifecycle
Signal handlers
Common API        (if the script has public functions)
Feature section 1
Feature section 2
...
UI builder        (only when runtime node construction is required — see Section 11)
```

### Inner classes

Placed above all function sections, immediately after the variable blocks.

```gdscript
# ══ Inner class: description ══════════════════════════════════════════════════
class _ClassName extends BaseClass:
    ...
```

### Lifecycle

Contains only `_ready()`, `_unhandled_input()`, and any other built-in Godot lifecycle callbacks (`_process`, `_physics_process`, etc.).
No private helpers here — helpers belong in their feature section.

```gdscript
# ══ Lifecycle ═════════════════════════════════════════════════════════════════

func _ready() -> void:
    ...

func _unhandled_input(event: InputEvent) -> void:
    ...
```

### Signal handlers

Contains only `_on_xxx()` callbacks.
No public functions. No logic helpers.

```gdscript
# ══ Signal handlers ════════════════════════════════════════════════════════════

func _on_confirm_pressed() -> void:
    ...

func _on_cancel_pressed() -> void:
    ...
```

### Common API

Public functions that do not belong to a specific feature domain.
Used when the script exposes a surface that other scripts call.

```gdscript
# ══ Common API ════════════════════════════════════════════════════════════════

func setup(entry: EntryType, ctx: ContextType) -> void:
    ...

func refresh() -> void:
    ...
```

### Feature sections

Domain-specific groups. Each section may contain both public and private functions.
Private helpers follow their public counterparts within the same section.

```gdscript
# ══ Rows ══════════════════════════════════════════════════════════════════════

func _populate_rows() -> void:
    ...

# ══ Result ════════════════════════════════════════════════════════════════════

func _commit_result() -> void:
    ...

func _show_summary() -> void:
    ...
```

Use descriptive domain names that reflect the feature, not the project's current block list.

### UI builder

Always the last section when present.
Contains `_build_ui()` and any private builder helpers it calls.

Only include this section when runtime node construction is genuinely required (see Section 11).
Most block scenes should not have this section at all.

```gdscript
# ══ UI builder ════════════════════════════════════════════════════════════════

func _build_ui() -> void:
    ...

func _make_column_header() -> HBoxContainer:
    ...
```

---

# 6. Inline Sub-section Comments (inside functions)

Long functions — especially `_build_ui()` — use inline sub-section comments to mark regions.

Format:

```gdscript
    # ── Sub-section label ─────────────────────────────────────────────────────
```

Note: indented to match the function body. Dashes extend to column 80 from the indent level.

Example:

```gdscript
func _build_ui() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    # ── Background ────────────────────────────────────────────────────────────
    var bg := ColorRect.new()
    ...

    # ── Title ─────────────────────────────────────────────────────────────────
    var title := Label.new()
    ...

    # ── Item list panel ───────────────────────────────────────────────────────
    var panel := PanelContainer.new()
    ...
```

Only add inline sub-sections when the function is long enough to need navigation.
Short functions (under ~15 lines) do not need them.

---

# 7. Private vs Public Placement Rule

Private functions belong **inside the section they serve**, not in a global private section at the bottom.

```gdscript
# ══ Result ════════════════════════════════════════════════════════════════════

func _commit_result() -> void:   # private — lives here, not at file bottom
    ...

func _show_summary() -> void:    # private — lives here, not at file bottom
    ...
```

Exception: `_on_xxx` signal callbacks always go in `# ══ Signal handlers ══`, regardless of which feature they relate to.

---

# 8. State Manager Separation

Block scenes read run-time state from the **run state manager**, not from the **scene transition manager**.

The scene transition manager is responsible for scene transitions only.
The run state manager holds all per-run state.

```gdscript
# ✅ Correct — read state from the state manager
_items = RunManager.run_record.items
SceneManager.go_to_next_block()

# ❌ Incorrect — scene transition manager does not hold run state
_items = SceneManager.items
```

The file header `Reads` / `Writes` annotations should reference the run state manager's fields accordingly.

---

# 9. Complete Layout Reference

```gdscript
# script_name.gd
# Block XX — Description.
# Reads:  RunManager.state.field_a
# Writes: RunManager.state.field_b
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────

const MAX_SLOTS    := 6
const ItemRowScene := preload("uid://...")   # PascalCase — loaded type

# ── State ─────────────────────────────────────────────────────────────────────

var _items: Array[ItemEntry] = []
var _ctx: ContextType = null

# ── Node references ───────────────────────────────────────────────────────────

@onready var _row_container: VBoxContainer = $RootVBox/Panel/RowContainer
@onready var _continue_btn: Button = $RootVBox/Footer/ContinueButton


# ══ Lifecycle ═════════════════════════════════════════════════════════════════

func _ready() -> void:
    _continue_btn.pressed.connect(_on_continue_pressed)

    _items = RunManager.state.items
    _populate_rows()


# ══ Signal handlers ════════════════════════════════════════════════════════════

func _on_continue_pressed() -> void:
    SceneManager.go_to_next_block()


# ══ Rows ══════════════════════════════════════════════════════════════════════

func _populate_rows() -> void:
    for entry: ItemEntry in _items:
        var row: ItemRow = ItemRowScene.instantiate()
        row.setup(entry, _ctx)
        _row_container.add_child(row)
```

Note: `_build_ui()` is absent from this reference layout. It only appears when runtime node
construction is required (see Section 11). Most block scenes will match this layout exactly.

---

# 10. Header Length Reference

Both formats should reach approximately **column 80** (including indent for inline variants).

```
# ── Label ────────────────────────────────────────────────────────────────────   ← variable block (col 80)
# ══ Label ════════════════════════════════════════════════════════════════════   ← function section (col 80)
    # ── Label ────────────────────────────────────────────────────────────────   ← inline sub-section (col 80 from indent)
```

Use a consistent character count per format rather than eyeballing it each time.
The exact dash count matters less than visual consistency — copy from an existing header.

---

# 11. Node Source Rule

All persistent nodes in a block scene **must be defined in the `.tscn` file**.
Reference them at the top of the script using `@onready` under `# ── Node references ──`.

```gdscript
# ── Node references ───────────────────────────────────────────────────────────

@onready var _confirm_button: Button = $RootVBox/Footer/ConfirmButton
@onready var _row_container: VBoxContainer = $RootVBox/Panel/RowContainer
```

**Do not use `_build_ui()`** to construct persistent structural nodes in code.

---

## Signal connections

Connect signals between a scene's own nodes in `_ready()`, not in the `.tscn`.
This keeps the full connection surface visible in code without IDE dependency for wiring.

Connections go at the top of `_ready()`, before any logic or node setup:

```gdscript
func _ready() -> void:
    _confirm_button.pressed.connect(_on_confirm_pressed)
    _cancel_button.pressed.connect(_on_cancel_pressed)
    # ... rest of setup
```

This applies to all signal connections — buttons, custom signals from child nodes, and
connections to autoloads.

---

## Permitted exceptions

The following may still be created at runtime in code:

| Case                    | Example                                                     | Reason                                                     |
| ----------------------- | ----------------------------------------------------------- | ---------------------------------------------------------- |
| Packed scene instances  | `ItemRowScene.instantiate()`                                | Count unknown at edit time                                 |
| Ephemeral display nodes | Tooltips, empty-state labels, `HSeparator` in dynamic lists | Created and destroyed during the scene's lifetime          |
| Custom-drawn controls   | Inner class with `_draw()` override                         | Requires `_draw()` override — cannot be defined in `.tscn` |

The key question: **does this node exist for the full lifetime of the scene?**
If yes → define it in `.tscn`. If no → creating it in code is acceptable.
