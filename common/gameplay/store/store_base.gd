# store_base.gd
# Base class for all Store archetypes. Provides default no-op implementations
# of the save-section interface so subclasses only override what they need.
# Persisting Stores override all five methods; session-scoped Stores (e.g.
# RunStore) override none — they carry no save payload.
class_name StoreBase
extends RefCounted


## Returns the section key used in the save payload. Returns "" by default;
## session-scoped Stores that never register with SaveManager rely on this.
func section_id() -> String:
	return ""


## Serializes this store's state to a Dictionary for saving.
## Returns an empty dict by default.
func to_dict() -> Dictionary:
	return {}


## Restores this store's state from [param data]. No-op by default.
func from_dict(_data: Dictionary) -> void:
	pass


## Idempotent migration pass. No-op by default.
func migrate() -> void:
	pass


## Validates invariants. Returns true by default.
func validate() -> bool:
	return true
