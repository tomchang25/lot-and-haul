# economy_store.gd
# Economy runtime store: cash. Serializable state slice held by MetaManager.
# Owns the field, its save payload, and all operations that mutate it.
#
# Fields are read-public via getters. Mutation goes through the owning Manager only.
class_name EconomyStore
extends StoreBase

var _cash: int = 0

## Cash on hand. Read-only externally — no setter means no external write path.
var cash: int:
    get:
        return _cash


## Returns true if [param amount] can be spent without going negative.
func can_afford(amount: int) -> bool:
    return _cash >= amount


## Deducts [param amount] from cash. Refuses if cash would go negative.
## Returns true when the spend happened, false when rejected.
## Asserts non-negative input — negative amounts are a caller bug.
func spend(amount: int) -> bool:
    assert(amount >= 0, "spend() expects a non-negative amount")
    if _cash < amount:
        return false
    _cash -= amount
    return true


## Adds [param amount] to cash. Asserts non-negative input.
func earn(amount: int) -> void:
    assert(amount >= 0, "earn() expects a non-negative amount")
    _cash += amount


## Applies a signed [param delta] atomically. Use sparingly; prefer earn/spend.
## Allowed to drive cash negative (e.g. daily living cost, run losses).
func apply_delta(delta: int) -> void:
    _cash += delta


## Section id for the economy save payload.
func section_id() -> String:
    return "economy"


## Serializes economy state to a save payload.
func to_dict() -> Dictionary:
    return { "_version": _store_version(), "cash": _cash }


## Restores economy state. Unrecognised keys are silently ignored.
func from_dict(data: Dictionary) -> void:
    var version: int = int(data.get("_version", 1))
    data = _apply_migrations(data, version)
    if data.has("cash") and data["cash"] is float:
        _cash = int(data["cash"])
