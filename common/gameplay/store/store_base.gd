# store_base.gd
# Base class for all Store archetypes. Provides default no-op implementations
# of the save-section interface so subclasses only override what they need.
# Persisting Stores override the relevant save methods; session-scoped Stores
# can still be serialized as part of an owning provider's save section.
class_name StoreBase
extends RefCounted

## Returns the section key used in the save payload. Returns "" by default
## session-scoped Stores that never register with SaveManager rely on this.
func section_id() -> String:
    return ""


## Serializes this store's state to a Dictionary for saving. Persisting stores
## override this. Session-scoped stores usually do not because an owning save
## provider encodes them as part of a larger payload.
func to_dict() -> Dictionary:
    return { }


## Restores this store's state from [param data]. Persisting stores override
## this. Session-scoped stores restored by an owning provider should expose an
## explicit helper for that payload shape instead.
func from_dict(_data: Dictionary, _ctx: SaveLoadContext) -> void:
    pass


## Serializes this Store into an owning aggregate snapshot. Persisting Stores
## usually do not override this; session-scoped aggregate Stores override it
## with a project-specific context cast from [param snapshot_ctx].
func encode_snapshot(_snapshot_ctx: RefCounted) -> Dictionary:
    return { }


## Restores this Store from an owning aggregate snapshot. Store-to-Store restore
## dependencies should flow through [param snapshot_ctx], not direct Store
## parameters, so the owning System remains the aggregate coordinator.
func restore_snapshot(_data: Dictionary, _snapshot_ctx: RefCounted, _ctx: SaveLoadContext) -> bool:
    return true


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
