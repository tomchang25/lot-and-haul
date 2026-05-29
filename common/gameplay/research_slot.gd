# research_slot.gd
# A single slot in the research panel. Occupies one of the player's
# concurrent research slots while the targeted item is being worked on.
class_name ResearchSlot
extends RefCounted

# ── Research tuning knobs ─────────────────────────────────────────────────────

const REPAIR_BASE: float = 0.15
const REPAIR_ZONE_FACTORS: Dictionary = { 0.25: 1.0, 0.50: 0.35 }
const REPAIR_RARITY_FACTOR: Dictionary = {
    ItemData.Rarity.COMMON: 1.0,
    ItemData.Rarity.UNCOMMON: 0.9,
    ItemData.Rarity.RARE: 0.8,
    ItemData.Rarity.EPIC: 0.7,
    ItemData.Rarity.LEGENDARY: 0.6,
}

const RESTORE_BASE: float = 0.10
const RESTORE_ZONE_FACTORS: Dictionary = { 0.75: 0.12, 1.0: 0.02 }
const RESTORE_RARITY_FACTOR: Dictionary = {
    ItemData.Rarity.COMMON: 1.0,
    ItemData.Rarity.UNCOMMON: 0.8,
    ItemData.Rarity.RARE: 0.6,
    ItemData.Rarity.EPIC: 0.4,
    ItemData.Rarity.LEGENDARY: 0.2,
}
const RESTORE_ATTR_COEFF: float = 0.4

enum SlotAction {
    REPAIR,
    RESTORE,
    RESEARCH,
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

# RESEARCH progress — number of days spent researching.
# Persisted as part of the slot dict because it is slot-scoped state
# that must survive day ticks and save/load cycles.
var research_days_spent: int = 0


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
        SlotAction.RESEARCH:
            return "research"
        _:
            push_error("ResearchSlot: unknown SlotAction %d" % a)
            return "unknown"


static func action_from_string(s: String) -> SlotAction:
    match s:
        "repair":
            return SlotAction.REPAIR
        "restore":
            return SlotAction.RESTORE
        "authenticate", "research":
            return SlotAction.RESEARCH
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
    if action == SlotAction.RESEARCH:
        d["research_days_spent"] = research_days_spent
    return d


static func from_dict(d: Dictionary) -> ResearchSlot:
    var slot := ResearchSlot.new()
    slot.item_id = int(d.get("item_id", -1))
    slot.action = action_from_string(d.get("action", "repair"))
    slot.completed = bool(d.get("completed", false))
    if slot.action == SlotAction.RESEARCH:
        slot.research_days_spent = int(d.get("research_days_spent", d.get("authenticate_days_spent", 0)))
    return slot


@warning_ignore("shadowed_variable")
static func check_assignable(entry: ItemEntry, action: SlotAction) -> SlotCheck:
    match action:
        SlotAction.REPAIR:
            if is_repair_complete(entry):
                return SlotCheck.REPAIR_COMPLETE
            return SlotCheck.OK
        SlotAction.RESTORE:
            if is_restore_complete(entry):
                return SlotCheck.RESTORE_COMPLETE
            if entry.condition < 0.5:
                return SlotCheck.RESTORE_NOT_READY
            return SlotCheck.OK
        SlotAction.RESEARCH:
            if entry.anchor_revealed and not entry.all_surface_revealed():
                return SlotCheck.NOT_FINAL_LAYER
            if entry.verified:
                return SlotCheck.ALREADY_VERIFIED
            if entry.condition < 0.5:
                return SlotCheck.CONDITION_TOO_LOW
            return SlotCheck.OK
        _:
            push_warning("ResearchSlot: unknown SlotAction %d" % action)
            return SlotCheck.OK


# ══ Research actions ════════════════════════════════════════════════════════════

## Applies one day of repair progress to [param entry]. Mutates condition
## and grants REPAIR knowledge XP.
static func apply_repair(entry: ItemEntry) -> void:
    var zone_factor: float = REPAIR_ZONE_FACTORS[0.50]
    if entry.condition < 0.25:
        zone_factor = REPAIR_ZONE_FACTORS[0.25]
    var rarity_factor: float = REPAIR_RARITY_FACTOR[entry.item_data.rarity]
    var delta: float = REPAIR_BASE * zone_factor * rarity_factor
    entry.condition = minf(entry.condition + delta, 0.5)
    KnowledgeManager.add_category_points(
        entry.item_data.category_data,
        entry.item_data.rarity,
        KnowledgeManager.KnowledgeAction.REPAIR,
    )


## Applies one day of restore progress to [param entry]. Mutates condition
## and grants RESTORE knowledge XP.
static func apply_restore(entry: ItemEntry) -> void:
    var zone_factor: float = RESTORE_ZONE_FACTORS[1.0]
    if entry.condition < 0.75:
        zone_factor = RESTORE_ZONE_FACTORS[0.75]
    var rarity_factor: float = RESTORE_RARITY_FACTOR[entry.item_data.rarity]
    var restoration_attr := KnowledgeManager.get_attribute_value("restoration")
    var attr_mult: float = 1.0 + restoration_attr * RESTORE_ATTR_COEFF
    var delta: float = RESTORE_BASE * zone_factor * rarity_factor * attr_mult
    entry.condition = minf(entry.condition + delta, 1.0)
    KnowledgeManager.add_category_points(
        entry.item_data.category_data,
        entry.item_data.rarity,
        KnowledgeManager.KnowledgeAction.RESTORE,
    )


## Returns true when [param entry] has been repaired to the cap (condition >= 0.5).
static func is_repair_complete(entry: ItemEntry) -> bool:
    return entry.condition >= 0.5


## Returns true when [param entry] has been fully restored (condition >= 1.0).
static func is_restore_complete(entry: ItemEntry) -> bool:
    return entry.condition >= 1.0


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
            return "Inspect all surface clues before researching"
        SlotCheck.ALREADY_VERIFIED:
            return "Already verified"
        SlotCheck.CONDITION_TOO_LOW:
            return "Repair before researching"
    return ""
