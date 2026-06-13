# affix_combination_data.gd
# Designer-authored resource representing one possible clue set for an affix.
# When an affix is drawn on an item, one combination is weight-picked and its
# surface + hidden clues become the item's secondary clue set (clues from the
# anchor and plain-item baseline still apply).
class_name AffixCombinationData
extends Resource

# Unique identifier for this combination (scoped within its parent affix).
@export var combination_id: String = ""

# Relative weight when picking among this affix's combinations.
@export var weight: int = 1

# Surface clues contributed by this combination.
@export var surface_clues: Array[ClueData] = []

# Hidden clues contributed by this combination.
@export var hidden_clues: Array[ClueData] = []
