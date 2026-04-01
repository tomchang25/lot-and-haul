# inspection_rules.gd
# Centralised policy for all inspection-related actions.
# Stateless — all methods are static. No imports needed; consumers call
# InspectionRules.xxx() directly.
class_name InspectionRules
extends RefCounted


# ── Eligibility ────────────────────────────────────────────────────────────────


# True if the player can advance the entry to the next identity layer.
# Checks stamina cost and skill prerequisite via KnowledgeManager.
static func can_advance(entry: ItemEntry, stamina: int) -> bool:
    var action := entry.current_unlock_action()
    if action == null:
        return false
    if stamina < action.stamina_cost:
        return false
    if action.required_skill.is_empty():
        return true
    return KnowledgeManager.get_level(action.required_skill) >= action.required_level

# ── Display helpers ────────────────────────────────────────────────────────────


# Returns the display name for the item at its current layer.
static func get_display_name(entry: ItemEntry) -> String:
    if entry.item_data.identity_layers.is_empty():
        return entry.item_data.item_id
    return entry.active_layer().display_label


# Returns a short status label for the item's current layer depth.
static func level_label(entry: ItemEntry) -> String:
    if entry.item_data.identity_layers.is_empty():
        return "Unknown"
    if entry.is_at_final_layer():
        return "Identified"
    return "Layer %d" % entry.layer_index
