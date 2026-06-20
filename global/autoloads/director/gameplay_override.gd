# gameplay_override.gd
# Runtime-only store of active gameplay overrides. Not persisted.
# The tutorial flow layer pushes overrides; gameplay scenes read them.
# Cleared on save_runtime_reset so a slot switch cannot leak overrides.
# Autoloaded after ScriptDirector, before GameManager.
extends Node

## Shared vocabulary of gameplay overrides that scenes and the tutorial flow
## layer reference through this store. Named for the gameplay concern,
## not the tutorial that currently controls it.
const ASSISTED_AUCTION := &"assisted_auction"
const LOT_PASS_LOCKED := &"lot_pass_locked"
const CONSERVATIVE_SALE_LOCKED := &"conservative_sale_locked"
const FORCED_ACTIVITY := &"forced_activity"
const FORCED_TUTORIAL_LOCATION := &"forced_tutorial_location"
const INSPECTION_REVIEW_GATED := &"inspection_review_gated"

signal override_changed(id: StringName, active: bool, payload: Variant)

var _active: Dictionary = { }


func _ready() -> void:
    EventBus.save_runtime_reset.connect(clear_all)


## Returns true when the named override is currently active.
func is_active(id: StringName) -> bool:
    return _active.has(id)


## Returns the payload stored for the named override, or null when inactive.
func payload(id: StringName) -> Variant:
    return _active.get(id, null)


## Activates the named override with an optional payload. Emits
## [signal override_changed] with active=true.
func activate(id: StringName, _payload: Variant = null) -> void:
    _active[id] = _payload
    override_changed.emit(id, true, _payload)


## Deactivates the named override. Emits [signal override_changed] with
## active=false. Safe to call when already inactive (no-op).
func deactivate(id: StringName) -> void:
    var had := _active.erase(id)
    if had:
        override_changed.emit(id, false, null)


## Clears every active override and emits one [signal override_changed] per
## cleared id. Called on save_runtime_reset.
func clear_all() -> void:
    var ids := _active.keys()
    _active.clear()
    for id in ids:
        override_changed.emit(id, false, null)
