# item_data.gd
# Designer-authored resource representing a single auctionable item.
# Contains only intrinsic item properties — no inspection logic or action rules.
class_name ItemData
extends Resource

## Rarity also equals the number of hidden clues on the item.
## COMMON = 0 hidden (verified immediately); LEGENDARY = 4 hidden.
enum Rarity {
    COMMON,
    UNCOMMON,
    RARE,
    EPIC,
    LEGENDARY,
}

# Internal identifier. Never displayed to the player.
@export var item_id: String = ""

# Physical classification. Defines pool scope and display label.
@export var category_data: CategoryData = null

# Anchor variant for this item. Carries base value, physical identity (shape,
# weight, sprite), and the default body naming slot.
@export var anchor: AnchorData = null

# Surface clues: discovered via dice during inspection or auto-revealed on hub return.
@export var surface_clues: Array[ClueData] = []

# Hidden clues: revealed only by Storage Authenticate. Count must equal rarity value.
@export var hidden_clues: Array[ClueData] = []

## Rarity == hidden clue count. COMMON (0 hidden) items are verified by default.
@export var rarity: Rarity = Rarity.COMMON

## All clues on this item — surface and hidden combined, surface-first.
## Use when iterating all clues and the surface/hidden distinction is irrelevant.
var all_clues: Array[ClueData]:
    get:
        var result: Array[ClueData] = []
        result.assign(surface_clues + hidden_clues)
        return result
