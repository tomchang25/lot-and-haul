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
