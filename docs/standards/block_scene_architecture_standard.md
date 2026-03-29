# Block Scene Architecture Standard

This document defines the structural rules for block scene scripts in the **Lot & Haul** project.

Applies to:

- Stage-level block scenes (`stage/levels/*/`)
- Testbed scenes (`stage/testbeds/*/`)
- Reusable UI component scripts (`stage/levels/*/`)

Does **not** apply to:

- `GameManager` and other autoloads
- Resource definitions under `data/`
- Common framework scripts

---

# 1. File Header

Every script must begin with a file header comment block.

Format:

```gdscript
# script_name.gd
# Block XX — One-line description of this block's responsibility.
# Reads:  GameManager.field_name
# Writes: GameManager.field_name
```

Rules:

- The first line is the filename.
- The second line is the block number and a single-sentence description.
- `Reads` and `Writes` list every `GameManager` field this script touches.
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

Declarations at the top of the file follow this order, matching GDScript convention:

```
extends
class_name (if needed)

signals

@export / @export_group / @onready

const
preload constants

private variables
```

Signals are declared before exports so they appear first in the class contract.

`class_name` is only added when the script needs to be referenced by type elsewhere.
Omit it for scene root scripts that are never typed directly.

---

# 3. Variable Block Headers (single-line)

Variable groups at the top of the file use the **single-line** (`──`) format.

```gdscript
# ── Group name ────────────────────────────────────────────────────────────────
```

The dashes extend to column 80. Use a consistent label from the table below.

Standard variable groups, in order:

| Header | Contents |
| --- | --- |
| `# ── Exports ──...` | `@export` vars (if any) |
| `# ── Constants ──...` | `const` and `preload` |
| `# ── State ──...` | Runtime logic variables |
| `# ── Timer / tween handles ──...` | `Timer`, `Tween` vars |
| `# ── UI references ──...` | Node reference vars assigned in `_build_ui()` |
| `# ── Testbed configuration ──...` | Testbed `@export` vars (testbed scripts only) |

Rules:

- Only include groups that have at least one variable.
- `@onready` vars do not get a separate header — they belong to `# ── Exports ──` if they are effectively public, or sit immediately before the function section if there are very few.
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
UI builder        (if the script builds UI in code)
```

### Inner classes

Placed above all function sections, immediately after the variable blocks.

```gdscript
# ══ Inner class: description ══════════════════════════════════════════════════
class _ClassName extends BaseClass:
    ...
```

### Lifecycle

Contains only `_ready()` and any other built-in Godot lifecycle callbacks (`_process`, `_physics_process`, etc.).
No private helpers here — helpers belong in their feature section.

```gdscript
# ══ Lifecycle ═════════════════════════════════════════════════════════════════

func _ready() -> void:
    ...
```

### Signal handlers

Contains only `_on_xxx()` callbacks.
No public functions. No logic helpers.

```gdscript
# ══ Signal handlers ════════════════════════════════════════════════════════════

func _on_confirm_pressed() -> void:
    ...
```

### Common API

Public functions that do not belong to a specific feature domain.
Used when the script exposes a surface that other scripts call.

```gdscript
# ══ Common API ════════════════════════════════════════════════════════════════

func setup(item: ItemData) -> void:
    ...
```

### Feature sections

Domain-specific groups. Each section may contain both public and private functions.
Private helpers follow their public counterparts within the same section.

```gdscript
# ══ State helpers ══════════════════════════════════════════════════════════════

func get_selected_items() -> Array[ItemData]:   # public
    ...

func _recalc_totals() -> void:                  # private helper
    ...

func _refresh_ui() -> void:                     # private helper
    ...
```

Use descriptive domain names. Examples:

```
# ══ State helpers ══════════════════════════════════════════════════════════════
# ══ NPC logic ═════════════════════════════════════════════════════════════════
# ══ Circle animation ══════════════════════════════════════════════════════════
# ══ Resolution ════════════════════════════════════════════════════════════════
# ══ Reveal sequence ═══════════════════════════════════════════════════════════
# ══ Display helpers ═══════════════════════════════════════════════════════════
```

### UI builder

Always the last section when present.
Contains `_build_ui()` and any private builder helpers it calls.

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
# ══ State helpers ══════════════════════════════════════════════════════════════

func get_slots_used() -> int:       # public
    return _slots_used

func _recalc_totals() -> void:      # private — lives here, not at file bottom
    ...

func _refresh_ui() -> void:         # private — lives here, not at file bottom
    ...
```

Exception: `_on_xxx` signal callbacks always go in `# ══ Signal handlers ══`, regardless of which feature they relate to.

---

# 8. Complete Layout Reference

```gdscript
# script_name.gd
# Block XX — Description.
# Reads:  GameManager.field_a
# Writes: GameManager.field_b
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────

const MAX_SLOTS := 6
const ItemRowScene := preload("res://...")

# ── State ─────────────────────────────────────────────────────────────────────

var _items: Array[ItemData] = []
var _selected: Dictionary = {}

# ── UI references ─────────────────────────────────────────────────────────────

var _slots_label: Label = null
var _list_container: VBoxContainer = null


# ══ Lifecycle ═════════════════════════════════════════════════════════════════

func _ready() -> void:
    _items = GameManager.cargo_items
    _build_ui()
    _refresh_ui()


# ══ Signal handlers ════════════════════════════════════════════════════════════

func _on_confirm_pressed() -> void:
    ...


# ══ State helpers ══════════════════════════════════════════════════════════════

func get_selected_items() -> Array[ItemData]:
    ...

func _recalc_totals() -> void:
    ...

func _refresh_ui() -> void:
    ...


# ══ UI builder ════════════════════════════════════════════════════════════════

func _build_ui() -> void:
    # ── Background ────────────────────────────────────────────────────────────
    ...

    # ── Title ─────────────────────────────────────────────────────────────────
    ...

    # ── Item list ─────────────────────────────────────────────────────────────
    ...
```

---

# 9. Header Length Reference

Both formats should reach approximately **column 80** (including indent for inline variants).

```
# ── Label ────────────────────────────────────────────────────────────────────   ← variable block (col 80)
# ══ Label ════════════════════════════════════════════════════════════════════   ← function section (col 80)
    # ── Label ────────────────────────────────────────────────────────────────   ← inline sub-section (col 80 from indent)
```

Use a consistent character count per format rather than eyeballing it each time.
The exact dash count matters less than visual consistency — copy from an existing header.
