# item_data.gd
# Designer-authored resource representing a single auctionable item.
# Contains only intrinsic item properties — no inspection logic or action rules.
class_name ItemData
extends Resource

enum Rarity {
    COMMON,
    UNCOMMON,
    RARE,
    EPIC,
    LEGENDARY,
}

# Internal identifier. Never displayed to the player.
@export var item_id: String = ""

## DEPRECATED — Phase 8
# True item name. Shown only after verification (all hidden clues revealed).
@export var item_name: String = ""

## DEPRECATED — Phase 7 moved true value into clue modifiers
## (anchor + surface + hidden). Retained only for YAML pipeline validation
## and debug sanity checks. Will be removed once pool-based item generation
## (item_system.md draft) replaces hand-curated ItemData.
@export var base_price: int = 0

# Physical classification. Holds super_category, category, weight, grid_size.
@export var category_data: CategoryData = null

# Clue-based identity data. Each item has one anchor clue, zero or more
# surface clues, and zero or more hidden clues.
@export var clues: Array[ClueData] = []

# Lot-draw weighting tier and player-facing display tier.
@export var rarity: Rarity = Rarity.COMMON

# If true, entry.verified is set immediately when this item enters storage.
@export var auto_verify: bool = false
