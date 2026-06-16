# Scene Node Source Standard

This document defines where scene nodes come from in `.tscn`-backed scenes and
components.

Plain-language rule: do not dynamically build or instantiate persistent `.tscn` objects in GDScript unless there is a concrete runtime reason.

For reusable component root sizing, previewable defaults, default visibility, and fixture/debug data boundaries, see `dev/standards/component_scene_standard.md`.

Applies to:

- Block scene root scripts
- Testbed scenes
- Reusable UI component scripts
- Any scene script that owns or populates a `.tscn` node tree

Does **not** apply to:

- Autoloads and global managers
- Resource definitions under `data/`
- Pure framework scripts with no `.tscn` owner

---

# 1. Core Rule

All persistent nodes in a `.tscn`-backed scene or component **must be defined in the `.tscn` file**.

This includes fixed child components and popups. If the parent scene always owns one instance for the full scene lifetime, pre-place that instance in the parent `.tscn` and reference it with `@onready`; do not `preload()`, `instantiate()`, and `add_child()` it from `_ready()`.

Reference them from the script using `@onready` variables under the standard
`Node references` variable group.

Persistent means the node exists for the full lifetime of the scene or component, even if it starts hidden, disabled, empty, or filled with placeholder content.

Do **not** use `_build_ui()` to construct persistent structural nodes in code.

---

# 2. Node Reference Style

Preferred for new scenes and any scene being actively edited:

```gdscript
# Node references

@onready var _confirm_button: Button = %ConfirmButton
@onready var _row_container: VBoxContainer = %RowContainer
```

Each referenced node must have `unique_name_in_owner = true` set in the `.tscn`
as a **property line**, not a header attribute:

```text
[node name="ConfirmButton" type="Button" parent="..." unique_id=...]
unique_name_in_owner = true
```

Legacy `$RootVBox/...` full paths are allowed in existing scenes that have not
been touched. Do not mix `%UniqueName` and `$RootVBox/...` within a single
script.

---

# 3. Prohibited Patterns

Do not create these in GDScript with `.new()` or `.instantiate()` plus `add_child()`:

- A known root layout, panel, toolbar, form, footer, modal shell, or rail
- A button, label, container, or separator that is always part of the scene
- A fixed child component, popup, dialog, or `Window` owned by the parent scene
- A fixed set of rows or cells whose count is known at edit time
- Static styling nodes that are only configured once in `_ready()`

Move those nodes into `.tscn` and reference them with `@onready` instead.

---

# 4. Permitted Runtime Creation

The following may be created at runtime in code:

| Case                                    | Example                                                     | Reason                                                                                               |
| --------------------------------------- | ----------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| Runtime-variable packed scene instances | `ItemRowScene.instantiate()` for data-driven rows or cards  | Count, type, or identity unknown at edit time                                                        |
| Ephemeral display nodes                 | Tooltips, empty-state labels, `HSeparator` in dynamic lists | Created and destroyed during the scene's lifetime                                                    |
| Custom-drawn controls                   | Inner class with `_draw()` override                         | Requires `_draw()` override; cannot be defined in `.tscn`                                            |
| Debug-only display                      | `_debug_label` behind `Debug.enabled` guard                 | Never shipped; polluting `.tscn` with invisible nodes is misleading. See `debug_standard.md`.        |
| Timer nodes                             | `Timer.new()` for timed logic                               | Godot scene timers fire during tool mode, causing phantom ticks in the editor; always create in code |

The key question: **does this node exist for the full lifetime of the scene?**

If yes, define it in `.tscn`. If no, creating it in code is acceptable when it matches one of the permitted cases above.

Packed scenes are not automatically a runtime-creation exception. A one-off component or popup whose presence is fixed by the parent scene is a pre-place-only node, even when implemented as its own `.tscn`.

---

# 5. `node-src` Markers

Whether an `add_child(...)` is a violation depends on whether the node is
persistent, which a linter cannot decide from the call site alone. To make the
rule machine-checkable, every runtime `add_child` of a node that is **not** a
`.instantiate()`'d packed scene must carry a marker declaring which permitted
exception applies.

Put the marker on the comment line **directly above** the call. The linter also
accepts a trailing marker, but above-the-call is preferred because it keeps the
call clean and gives the note room.

```gdscript
# node-src: timer
add_child(_npc_timer)

# node-src: ephemeral - separator in rebuilt list
_lot_summary.add_child(HSeparator.new())

# node-src: drawn
price_area.add_child(_circle_node)

# node-src: debug
add_child(_debug_label)

# node-src: instance - packed scene not auto-detected
my_container.add_child(thing)
```

An optional note may follow the tag after `-`. Keep the note to a short phrase,
such as `empty-state label` or `per-grid cell, dynamic W x H`.

If a marker needs a full-sentence justification to feel honest, treat that as a
signal the node should be extracted into a `.tscn` component rather than
annotated. A long excuse is the smell, not the fix.

Tags map 1:1 to the permitted-exceptions table above:

| Tag         | Case                                                                  |
| ----------- | --------------------------------------------------------------------- |
| `instance`  | Packed scene instance not auto-detected from a local `.instantiate()` |
| `ephemeral` | Tooltip, empty-state label, separator in a dynamic list               |
| `drawn`     | Custom-drawn control with `_draw()`                                   |
| `debug`     | Debug-only display behind `Debug.enabled`                             |
| `timer`     | `Timer` node, always created in code                                  |

`add_child(SomeScene.instantiate())` and any local variable assigned from `.instantiate()` need **no** marker; they are recognised automatically.

This marker exemption is only a linter convenience. It does not permit fixed persistent components to be instantiated in code; those must still be pre-placed in the parent `.tscn`.

An unmarked, non-instantiate `add_child` is a lint failure. The marker does not
prove the node is genuinely ephemeral; it forces the author to declare intent so
a reviewer can see and judge the claim. See
`dev/standards/standards_enforcement.md`.

---

# 6. Review Test

Before creating a node in GDScript, ask:

- Will this node exist for the full scene lifetime?
- Is this a fixed part of the UI shell rather than runtime data?
- Would this be clearer to inspect, wire, theme, or localize in the editor?

If any answer is yes, define the node in `.tscn`.
