# economy_owner.gd
# Economy domain owner: cash. Owns the field and its save payload.
# Held by MetaManager; not a global singleton.
class_name EconomyOwner
extends RefCounted

var cash: int = 0


## Section id for the economy save payload.
func section_id() -> String:
    return "economy"


## Serializes economy state to a save payload.
func to_dict() -> Dictionary:
    return { "cash": cash }


## Restores economy state. Unrecognised keys are silently ignored.
func from_dict(data: Dictionary) -> void:
    if data.has("cash") and data["cash"] is float:
        cash = int(data["cash"])
