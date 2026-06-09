# Debug Standard

This document defines how debug-conditional code works in this project.

---

# 1. Architecture

Debug state is managed by two layers:

- **`OS.is_debug_build()`** — Engine-level gate. True in editor and debug exports, false in release exports. Not a runtime toggle — determined at build time.
- **`SettingsStore.debug_mode`** — User-facing preference. Persisted to `user://settings.json`. Toggled via the Settings Overlay checkbox (Gameplay → Debug Mode).

The **`Debug` autoload** combines both into a single runtime check:

```
Debug.enabled = OS.is_debug_build() AND SettingsStore.debug_mode
```

`Debug.enabled` is the **only check** debug-conditional code should use. Do not call `OS.is_debug_build()` or `SettingsStore.debug_mode` directly in scene or gameplay code.

---

# 2. Autoload Details

`Debug` loads immediately after `SettingsStore` in the autoload order. It connects to `SettingsStore.debug_mode_changed` (fired by the setter on `debug_mode`) and recomputes `enabled` on every change.

**Signal:** `Debug.toggled(is_enabled: bool)` — emitted when `enabled` changes. Scenes that create debug UI should connect to this for reactive show/hide.

**Mutator:** `Debug.set_debug_mode(value: bool)` — the canonical way to change the debug preference. Writes `SettingsStore.debug_mode`, persists, and triggers the signal chain. The Settings Overlay calls this; other code generally should not.

---

# 3. How to Write Debug-Conditional Code

## One-shot init (most common)

Check `Debug.enabled` when building the scene. If off, skip debug node creation entirely:

```gdscript
func _init_debug_overlay() -> void:
    if not Debug.enabled:
        return
    _debug_label = Label.new()
    # ... configure label ...
    # node-src: debug
    add_child(_debug_label)
```

## Reactive toggle

If a scene should respond to mid-scene debug toggles, connect to `Debug.toggled`:

```gdscript
func _init_debug_overlay() -> void:
    if not Debug.enabled:
        return
    _debug_label = Label.new()
    # ... configure label ...
    # node-src: debug
    add_child(_debug_label)
    Debug.toggled.connect(_on_debug_toggled)


func _on_debug_toggled(is_enabled: bool) -> void:
    if _debug_label != null:
        _debug_label.visible = is_enabled
```

## Conditional logic (no UI)

For gameplay shortcuts (e.g. instant auction, auto-pack cargo), guard with `Debug.enabled`:

```gdscript
if Debug.enabled:
    _auto_pack_cargo()
```

---

# 4. Node Source Rule

Debug-only nodes must always be created in code, never placed in `.tscn`. They carry the `# node-src: debug` marker for the linter. See `block_scene_architecture_standard.md` § Node Source Rule for full details.

---

# 5. Release Safety

In release exports, `OS.is_debug_build()` returns false, so `Debug.enabled` is always false regardless of the persisted `debug_mode` value. The Settings Overlay checkbox remains visible but has no effect — this is intentional (the preference persists for the next debug build).

Never expose sensitive gameplay internals (e.g. rolled auction prices, hidden clue values) outside a `Debug.enabled` guard.

---

# 6. Summary

| Want to…                         | Use                               |
| -------------------------------- | --------------------------------- |
| Check if debug is active         | `Debug.enabled`                   |
| React to debug toggle mid-scene  | `Debug.toggled.connect(callback)` |
| Change the debug preference      | `Debug.set_debug_mode(value)`     |
| Gate debug node creation         | `if not Debug.enabled: return`    |
| Mark a debug node for the linter | `# node-src: debug`               |
