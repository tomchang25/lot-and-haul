# research_slot.gd
# A single slot in the research panel. Occupies one of the player's
# concurrent research slots while the targeted item is being worked on.
class_name ResearchSlot
extends RefCounted

enum SlotAction {
    STUDY,
    REPAIR,
    UNLOCK,
}

# -1 means the slot is empty.
var item_id: int = -1
var action: SlotAction = SlotAction.STUDY

# Set by the day-tick dispatch when the slot finishes its work. Persisted
# because UNLOCK resets ItemEntry.unlock_progress on advance, so completion
# cannot be derived from ItemEntry state alone.
var completed: bool = false


func is_empty() -> bool:
    return item_id == -1


static func create(a: SlotAction, id: int) -> ResearchSlot:
    var slot := ResearchSlot.new()
    slot.action = a
    slot.item_id = id
    slot.completed = false
    return slot


static func action_to_string(a: SlotAction) -> String:
    match a:
        SlotAction.STUDY:
            return "study"
        SlotAction.REPAIR:
            return "repair"
        SlotAction.UNLOCK:
            return "unlock"
        _:
            push_error("ResearchSlot: unknown SlotAction %d" % a)
            return "unknown"


static func action_from_string(s: String) -> SlotAction:
    match s:
        "study":
            return SlotAction.STUDY
        "repair":
            return SlotAction.REPAIR
        "unlock":
            return SlotAction.UNLOCK
        _:
            push_error("ResearchSlot: unrecognised action string '%s'" % s)
            return SlotAction.STUDY


static func find_index(slots: Array, item_id: int) -> int:
    for i in range(slots.size()):
        var d: Dictionary = slots[i]
        if int(d.get("item_id", -1)) == item_id:
            return i
    return -1


static func action_for_item(slots: Array, item_id: int) -> String:
    for d: Dictionary in slots:
        if int(d.get("item_id", -1)) != item_id:
            continue
        if bool(d.get("completed", false)):
            continue
        return d.get("action", "")
    return ""


static func clear_for_item(slots: Array, item_id: int) -> void:
    var idx: int = find_index(slots, item_id)
    if idx < 0:
        return
    slots[idx] = {"item_id": -1, "action": "study", "completed": false}


static func purge_orphaned(slots: Array, valid_ids: Array) -> void:
    for i in range(slots.size()):
        var d: Dictionary = slots[i]
        var sid: int = int(d.get("item_id", -1))
        if sid == -1:
            continue
        if not valid_ids.has(sid):
            slots[i] = {"item_id": -1, "action": "study", "completed": false}


func to_dict() -> Dictionary:
    return {
        "item_id": item_id,
        "action": action_to_string(action),
        "completed": completed,
    }


static func from_dict(d: Dictionary) -> ResearchSlot:
    var slot := ResearchSlot.new()
    slot.item_id = int(d.get("item_id", -1))
    slot.action = action_from_string(d.get("action", "study"))
    slot.completed = bool(d.get("completed", false))
    return slot
