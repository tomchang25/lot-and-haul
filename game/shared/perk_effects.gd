# perk_effects.gd
# Centralised lookup for effect-perk modifiers — perks that tweak formulas
# rather than gate access. Each public static function returns the modified
# value when the relevant perk is unlocked, or the baseline otherwise. Perk
# IDs live exclusively inside this file, so consumers ask "what is the value?"
# without needing to know which perk drives it.
class_name PerkEffects
extends RefCounted

# ══ Internals ═════════════════════════════════════════════════════════════════

static func _has(perk_id: String) -> bool:
    var perk: PerkData = KnowledgeManager.get_perk_by_id(perk_id)
    if perk == null:
        return false
    return KnowledgeManager.has_perk(perk)
