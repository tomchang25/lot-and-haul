# affix_data.gd
# Designer-authored resource representing one affix (a named item modifier drawn
# before clues). Each affix groups a set of combinations; exactly one combination
# is chosen when the affix is assigned to an item. Affixes are the primary index
# for item naming (Spec B) and the knowledge dictionary (Spec C).
class_name AffixData
extends Resource

# Unique identifier for this affix.
@export var affix_id: String = ""

# Naming slot the affix occupies ("prefix" or "suffix"). Controls display-name
# composition in Spec B; unused in the generation core.
@export var naming_slot: String = ""

# Human-readable label for debug and tooltip display.
@export var display_name: String = ""

# Categories this affix is valid for (matched at draw time).
# Empty array means the affix can appear on any category.
@export var category_scope: Array[CategoryData] = []

# Relative weight for affix draw (higher = more frequent).
@export var weight: int = 1

# The combinations this affix can produce. Exactly one is drawn per item.
@export var combinations: Array[AffixCombinationData] = []
