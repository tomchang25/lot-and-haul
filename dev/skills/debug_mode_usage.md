# Debug Mode Usage

Use this when adding debug-only UI, shortcuts, or diagnostics.

## Check debug state

```gdscript
if not Debug.enabled:
    return
```

Do not check `OS.is_debug_build()` or `SettingsStore.debug_mode` directly from scene/gameplay code.

## React to toggles

```gdscript
func _ready() -> void:
    visible = Debug.enabled
    Debug.toggled.connect(_on_debug_toggled)


func _on_debug_toggled(is_enabled: bool) -> void:
    visible = is_enabled
```

## Add debug-only nodes

```gdscript
if Debug.enabled:
    var button := Button.new()
    button.text = "Debug Action"
    # node-src: debug
    add_child(button)
```

Every debug button handler that mutates game state must guard again:

```gdscript
func _on_debug_action_pressed() -> void:
    if not Debug.enabled:
        return
    _mutate_debug_state()
```

Reusable debug panels may be `.tscn` components only when they are hidden by default, self-gated from `Debug.enabled`, and every mutating handler has the guard above.

## Prefer the shared `DebugPanel` over a one-off block scene

Do not build a new debug block scene from scratch. Instance
`res://game/shared/debug_panel/debug_panel.tscn` (`class_name DebugPanel`) —
already wired into `hub_scene.tscn` as `%DebugPanel`, hidden by default — and
register actions from `_ready()`:

```gdscript
@onready var _debug_panel: DebugPanel = %DebugPanel


func _wire_debug_panel() -> void:
    _debug_panel.add_action(TranslationServer.translate("UI_DEBUG_ADD_RANDOM"), _on_debug_add_item)
    _debug_panel.add_action(TranslationServer.translate("UI_DEBUG_CLEAR_STORAGE"), _on_debug_clear_storage)


func _on_debug_add_item() -> void:
    if not Debug.enabled:
        return
    # mutate debug state here, then update the scene's own display directly
    _refresh_display()
```

`DebugPanel.add_action()` already wraps the callback with a `Debug.enabled`
check, so the button can never fire while debug is off — the guard in the
handler is the belt-and-suspenders copy required by `debug_standard.md` §4a,
not the only line of defense. `DebugPanel` owns no game state and has no
`storage_changed`-style signal; handlers call back into the scene's own
refresh method directly instead. See `debug_standard.md` §5 for the full
contract and `hub_scene.gd`'s `_wire_debug_panel()` for the live example
(Add Random Item, Clear All Storage).
