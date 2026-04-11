# advance_check_label.gd
# Static utility that maps AdvanceCheck enum values to player-facing tooltip strings.
class_name AdvanceCheckLabel
extends RefCounted

static func describe(check: int, action: LayerUnlockAction, entry: ItemEntry) -> String:
    if action == null or entry == null:
        return ""

    match check:
        KnowledgeManager.AdvanceCheck.OK:
            return ""
        KnowledgeManager.AdvanceCheck.NO_ACTION:
            return "Cannot advance further"
        KnowledgeManager.AdvanceCheck.WRONG_CONTEXT:
            return "Must be performed at home"
        KnowledgeManager.AdvanceCheck.INSUFFICIENT_CATEGORY_RANK:
            var cat_name: String = entry.item_data.category_data.display_name
            return "Need %s rank %d" % [cat_name, action.required_category_rank]
        KnowledgeManager.AdvanceCheck.INSUFFICIENT_SKILL:
            var skill_name: String = action.required_skill.display_name if action.required_skill != null else "Unknown"
            return "Need %s level %d" % [skill_name, action.required_level]
        KnowledgeManager.AdvanceCheck.MISSING_PERK:
            var perk: PerkData = KnowledgeManager.get_perk(action.required_perk_id)
            var perk_name: String = perk.display_name if perk != null else action.required_perk_id
            return "Requires perk: %s" % perk_name
    return ""
