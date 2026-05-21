# research_slot.gd
# A single slot in the research panel. Occupies one of the player's
# concurrent research slots while the targeted item is being worked on.
class_name ResearchSlot
extends RefCounted

enum SlotAction {
    REPAIR,
    RESTORE,
    AUTHENTICATE,
}

enum SlotCheck {
    OK,
    REPAIR_COMPLETE,
    RESTORE_COMPLETE,
    RESTORE_NOT_READY,
    NOT_FINAL_LAYER,
    ALREADY_VERIFIED,
    CONDITION_TOO_LOW,
}

# -1 means the slot is empty.
var item_id: int = -1
var action: SlotAction = SlotAction.REPAIR

# Set by the day-tick dispatch when the slot finishes its work.
var completed: bool = false

# AUTHENTICATE progress — number of days spent authenticating.
# Persisted as part of the slot dict because it is slot-scoped state
# that must survive day ticks and save/load cycles.
var authenticate_days_spent: int = 0


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
        SlotAction.REPAIR:
            return "repair"
        SlotAction.RESTORE:
            return "restore"
        SlotAction.AUTHENTICATE:
            return "authenticate"
        _:
            push_error("ResearchSlot: unknown SlotAction %d" % a)
            return "unknown"


static func action_from_string(s: String) -> SlotAction:
    match s:
        "repair":
            return SlotAction.REPAIR
        "restore":
            return SlotAction.RESTORE
        "authenticate":
            return SlotAction.AUTHENTICATE
        _:
            push_error("ResearchSlot: unrecognised action string '%s'" % s)
            return SlotAction.REPAIR


@warning_ignore("shadowed_variable")
static func find_index(slots: Array, item_id: int) -> int:
    for i in range(slots.size()):
        var d: Dictionary = slots[i]
        if int(d.get("item_id", -1)) == item_id:
            return i
    return -1


@warning_ignore("shadowed_variable")
static func action_for_item(slots: Array, item_id: int) -> String:
    for d: Dictionary in slots:
        if int(d.get("item_id", -1)) != item_id:
            continue
        if bool(d.get("completed", false)):
            continue
        return d.get("action", "")
    return ""


@warning_ignore("shadowed_variable")
static func clear_for_item(slots: Array, item_id: int) -> void:
    var idx: int = find_index(slots, item_id)
    if idx < 0:
        return
    slots[idx] = ResearchSlot.new().to_dict()


static func purge_orphaned(slots: Array, valid_ids: Array) -> void:
    for i in range(slots.size()):
        var d: Dictionary = slots[i]
        var sid: int = int(d.get("item_id", -1))
        if sid == -1:
            continue
        if not valid_ids.has(sid):
            slots[i] = ResearchSlot.new().to_dict()


func to_dict() -> Dictionary:
    var d: Dictionary = {
        "item_id": item_id,
        "action": action_to_string(action),
        "completed": completed,
    }
    if action == SlotAction.AUTHENTICATE:
        d["authenticate_days_spent"] = authenticate_days_spent
    return d


static func from_dict(d: Dictionary) -> ResearchSlot:
    var slot := ResearchSlot.new()
    slot.item_id = int(d.get("item_id", -1))
    slot.action = action_from_string(d.get("action", "repair"))
    slot.completed = bool(d.get("completed", false))
    if slot.action == SlotAction.AUTHENTICATE:
        slot.authenticate_days_spent = int(d.get("authenticate_days_spent", 0))
    return slot


@warning_ignore("shadowed_variable")
static func check_assignable(entry: ItemEntry, action: SlotAction) -> SlotCheck:
    match action:
        SlotAction.REPAIR:
            if entry.is_repair_complete():
                return SlotCheck.REPAIR_COMPLETE
            return SlotCheck.OK
        SlotAction.RESTORE:
            if entry.is_restore_complete():
                return SlotCheck.RESTORE_COMPLETE
            if entry.condition < 0.5:
                return SlotCheck.RESTORE_NOT_READY
            return SlotCheck.OK
        SlotAction.AUTHENTICATE:
            if not entry.is_at_final_layer():
                return SlotCheck.NOT_FINAL_LAYER
            if entry.verified:
                return SlotCheck.ALREADY_VERIFIED
            if entry.condition < 0.5:
                return SlotCheck.CONDITION_TOO_LOW
            return SlotCheck.OK
        _:
            push_warning("ResearchSlot: unknown SlotAction %d" % action)
            return SlotCheck.OK


static func describe_blocked(check: SlotCheck, entry: ItemEntry) -> String:
    match check:
        SlotCheck.OK:
            return ""
        SlotCheck.REPAIR_COMPLETE:
            return "Condition already at 50% — use Restore to continue"
        SlotCheck.RESTORE_COMPLETE:
            return "Condition already fully restored"
        SlotCheck.RESTORE_NOT_READY:
            return "Repair to 50% before restoring"
        SlotCheck.NOT_FINAL_LAYER:
            return "Must be at final perceived layer"
        SlotCheck.ALREADY_VERIFIED:
            return "Already verified"
        SlotCheck.CONDITION_TOO_LOW:
            return "Repair before authenticating"
    return ""
