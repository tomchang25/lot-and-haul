# research_slot.gd
# Static condition-math helpers for storage Repair and Restore actions.
# The day-ticker slot lifecycle (item_id, action, completed, research_days_spent)
# was removed in the time-slot economy rewrite — storage now runs on a per-slot
# AP pool with immediate execution. Only the math survives here.
class_name ResearchSlot
extends RefCounted

# ── Repair tuning ─────────────────────────────────────────────────────────────

const REPAIR_BASE: float = 0.15
const REPAIR_ZONE_FACTORS: Dictionary = { 0.25: 1.0, 0.50: 0.35 }
const REPAIR_RARITY_FACTOR: Dictionary = {
    ItemData.Rarity.COMMON: 1.0,
    ItemData.Rarity.UNCOMMON: 0.9,
    ItemData.Rarity.RARE: 0.8,
    ItemData.Rarity.EPIC: 0.7,
    ItemData.Rarity.LEGENDARY: 0.6,
}

# ── Restore tuning ────────────────────────────────────────────────────────────

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

# ══ Research actions ═══════════════════════════════════════════════════════════


## Applies one AP-unit of repair progress to [param entry]. Mutates condition
## toward the 0.5 cap and grants REPAIR knowledge XP.
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


## Applies one AP-unit of restore progress to [param entry]. Mutates condition
## toward 1.0 using the Restoration attribute and grants RESTORE knowledge XP.
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
