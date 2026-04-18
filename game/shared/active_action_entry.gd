# active_action_entry.gd
# Runtime representation of one queued hub action.
# Deserialised from SaveManager.active_actions on load; serialised back on save.
class_name ActiveActionEntry
extends RefCounted

enum ActionType {
    UNLOCK,
}

var action_type: ActionType = ActionType.UNLOCK
var item_id: int = -1 # matches ItemEntry.id of the target item
var days_remaining: int = 0


static func create(type: ActionType, id: int, days: int) -> ActiveActionEntry:
    var a := ActiveActionEntry.new()
    a.action_type = type
    a.item_id = id
    a.days_remaining = days
    return a


# Returns the string key used when serialising to SaveManager.active_actions.
static func action_type_to_string(type: ActionType) -> String:
    match type:
        ActionType.UNLOCK:
            return "unlock"
        _:
            push_error("ActiveActionEntry: unknown ActionType %d" % type)
            return "unknown"


# Returns ActionType from the string key stored in save data.
# Returns UNLOCK and pushes an error on unrecognised input.
static func action_type_from_string(s: String) -> ActionType:
    match s:
        "unlock":
            return ActionType.UNLOCK
        _:
            push_error("ActiveActionEntry: unrecognised action_type string '%s'" % s)
            return ActionType.UNLOCK


func to_dict() -> Dictionary:
    return {
        "action_type": action_type_to_string(action_type),
        "item_id": item_id,
        "days_remaining": days_remaining,
    }


static func from_dict(d: Dictionary) -> ActiveActionEntry:
    var a := ActiveActionEntry.new()
    a.action_type = action_type_from_string(d.get("action_type", "unlock"))
    a.item_id = int(d.get("item_id", -1))
    a.days_remaining = int(d.get("days_remaining", 0))
    return a
