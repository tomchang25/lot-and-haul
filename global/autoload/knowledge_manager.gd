extends Node

# Flat skill registry. Returns the player's current level for the given skill.
# Always 1 for this slice — full skill progression is deferred.
func get_level(skill_id: String) -> int:
    return 1


# True if the player can advance the entry to the next identity layer.
# Checks stamina cost and skill prerequisite via KnowledgeManager.
func can_advance(entry: ItemEntry, context: LayerUnlockAction.ActionContext) -> bool:
    var action: LayerUnlockAction = entry.current_unlock_action()
    if action == null:
        return false

    if entry.is_at_final_layer():
        return false

    if action.context == LayerUnlockAction.ActionContext.AUTO:
        return false

    if action.context != context:
        return false

    # TODO: Remove it when implemented. Advance to the next layer requires time in home instead stamina in auction.
    # if RunManager.run_record.stamina < action.stamina_cost:
    #     return false

    if not action.required_skill:
        return true

    return get_level(action.required_skill.skill_id) >= action.required_level
