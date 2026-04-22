# research_slot.gd
# A single slot in the research panel. Occupies one of the player's
# concurrent research slots while the targeted item is being worked on.
class_name ResearchSlot
extends RefCounted

enum SlotAction {
    STUDY,
    REPAIR,
    UNLOCK,
    RESTORE,
}

enum SlotCheck {
    OK,
    FULLY_INSPECTED,
    SCRUTINY_MAXED,
    REPAIR_COMPLETE,
    NO_UNLOCK_ACTION,
    ADVANCE_BLOCKED,
    RESTORE_COMPLETE,
    RESTORE_NOT_READY,
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
        SlotAction.RESTORE:
            return "restore"
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
        "restore":
            return SlotAction.RESTORE
        _:
            push_error("ResearchSlot: unrecognised action string '%s'" % s)
            return SlotAction.STUDY


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
    slots[idx] = { "item_id": -1, "action": "study", "completed": false }


static func purge_orphaned(slots: Array, valid_ids: Array) -> void:
    for i in range(slots.size()):
        var d: Dictionary = slots[i]
        var sid: int = int(d.get("item_id", -1))
        if sid == -1:
            continue
        if not valid_ids.has(sid):
            slots[i] = { "item_id": -1, "action": "study", "completed": false }


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


@warning_ignore("shadowed_variable")
static func check_assignable(entry: ItemEntry, action: SlotAction) -> SlotCheck:
    match action:
        SlotAction.STUDY:
            if entry.is_fully_inspected():
                return SlotCheck.FULLY_INSPECTED
            if not entry.is_condition_inspectable():
                return SlotCheck.SCRUTINY_MAXED
            return SlotCheck.OK
        SlotAction.REPAIR:
            if entry.is_repair_complete():
                return SlotCheck.REPAIR_COMPLETE
            return SlotCheck.OK
        SlotAction.UNLOCK:
            var advance: KnowledgeManager.AdvanceCheck = KnowledgeManager.can_advance(entry)
            match advance:
                KnowledgeManager.AdvanceCheck.NO_ACTION:
                    return SlotCheck.NO_UNLOCK_ACTION
                KnowledgeManager.AdvanceCheck.OK:
                    return SlotCheck.OK
                _:
                    return SlotCheck.ADVANCE_BLOCKED
        SlotAction.RESTORE:
            if entry.is_restore_complete():
                return SlotCheck.RESTORE_COMPLETE
            if entry.condition < 0.5:
                return SlotCheck.RESTORE_NOT_READY
            return SlotCheck.OK
        _:
            push_warning("ResearchSlot: unknown SlotAction %d" % action)
            return SlotCheck.OK


static func describe_blocked(check: SlotCheck, entry: ItemEntry) -> String:
    match check:
        SlotCheck.OK:
            return ""
        SlotCheck.FULLY_INSPECTED:
            return "Fully inspected"
        SlotCheck.SCRUTINY_MAXED:
            return "Scrutiny already maxed"
        SlotCheck.REPAIR_COMPLETE:
            return "Condition already at 50% — use Restore to continue"
        SlotCheck.NO_UNLOCK_ACTION:
            return "No further layers to unlock"
        SlotCheck.ADVANCE_BLOCKED:
            return AdvanceCheckLabel.describe(
                KnowledgeManager.can_advance(entry),
                entry.current_unlock_action(),
                entry,
            )
        SlotCheck.RESTORE_COMPLETE:
            return "Condition already fully restored"
        SlotCheck.RESTORE_NOT_READY:
            return "Repair to 50% before restoring"
    return ""
