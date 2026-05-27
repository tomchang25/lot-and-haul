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

# True item name. Shown only after verification/authentication.
@export var item_name: String = ""

# True item base price. Must stay above the final perceived layer value.
@export var base_price: int = 0

# Physical classification. Holds super_category, category, weight, grid_size.
@export var category_data: CategoryData = null

# Clue-based identity data. Each item has one anchor clue, zero or more
# surface clues, and zero or more hidden clues.
@export var clues: Array[ClueData] = []

@export var rarity: Rarity = Rarity.COMMON

# If true, entry.verified is set immediately when this item enters storage.
@export var auto_verify: bool = false
