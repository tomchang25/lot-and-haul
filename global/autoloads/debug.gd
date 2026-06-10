# debug.gd
# Unified debug gate. `enabled` is true only when both OS.is_debug_build() and
# SettingsStore.debug_mode are true. All debug-conditional code should check
# Debug.enabled (or connect to Debug.toggled) instead of calling
# OS.is_debug_build() directly.
extends Node

## Emitted when the effective debug state changes.
signal toggled(is_enabled: bool)

## True when this is a debug-capable build AND the user has debug_mode on.
var enabled: bool = false


func _ready() -> void:
    SettingsStore.debug_mode_changed.connect(_on_source_changed)
    _refresh()


## Sets the persisted debug_mode preference. The setter on
## SettingsStore.debug_mode triggers debug_mode_changed → _refresh
## automatically; this method only adds persistence.
func set_debug_mode(value: bool) -> void:
    SettingsStore.debug_mode = value
    SettingsStore.save_settings()


func _on_source_changed(_value: bool) -> void:
    _refresh()


## Recomputes `enabled` from the two sources and emits `toggled` on change.
func _refresh() -> void:
    var new_value := OS.is_debug_build() and SettingsStore.debug_mode
    if enabled == new_value:
        return
    enabled = new_value
    toggled.emit(enabled)
