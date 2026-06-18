# store_base.gd
# Base class for all Store archetypes. Provides default no-op implementations
# of the save-section interface so subclasses only override what they need.
# Persisting Stores override all four methods; session-scoped Stores (e.g.
# RunStore) override none — they carry no save payload.
class_name StoreBase
extends RefCounted

## Returns the section key used in the save payload. Returns "" by default
## session-scoped Stores that never register with SaveManager rely on this.
func section_id() -> String:
    return ""


## Serializes this store's state to a Dictionary for saving.
## Returns an empty dict by default.
func to_dict() -> Dictionary:
    return { }


## Restores this store's state from [param data]. Threads [param ctx] for
## diagnostics (warnings and migration notes). No-op by default.
func from_dict(_data: Dictionary, _ctx: SaveLoadContext) -> void:
    pass


## Validates invariants. Returns true by default.
func validate() -> bool:
    return true


## Returns the current schema version for this store. Override in subclasses
## when bumping the version alongside a new _apply_migrations() branch.
func _store_version() -> int:
    return 1


## Transforms saved data from [param from_version] to the current store version.
## Override in subclasses to handle schema changes. Migrations chain sequentially:
##
##   func _apply_migrations(data: Dictionary, from_version: int, ctx: SaveLoadContext) -> Dictionary:
##       if from_version < 2:
##           data["new_field"] = data.get("old_field", 0)
##           data.erase("old_field")
##       if from_version < 3:
##           data["renamed"] = data.get("legacy_name", "")
##           data.erase("legacy_name")
##       data["_version"] = _store_version()
##       return data
##
## Each block transforms data one version forward. The caller (from_dict) handles
## reading _version from the payload and passing it here. The final
## `data["_version"] = _store_version()` stamp is required: without it, a re-run
## of from_dict on the same dict would re-apply earlier migrations (e.g. a v1
## payload that maps 4 → 3 would re-map 3 → 2 on the second pass). Returns the
## dict with all fields in the current version's shape, ready for field
## restoration.
func _apply_migrations(data: Dictionary, _from_version: int, _ctx: SaveLoadContext) -> Dictionary:
    return data
