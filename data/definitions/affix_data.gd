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

# Localization key for the display name.
@export var display_name_key: String = ""

# Scope mode for draw eligibility.
# "all" means this affix can appear on any category.
# "categories" means this affix can appear only on category_scope entries.
@export var scope_mode: String = "categories"

# Categories this affix is valid for (matched at draw time).
# Only used when scope_mode == "categories".
@export var category_scope: Array[CategoryData] = []

# Relative weight for affix draw (higher = more frequent).
@export var weight: int = 1

# The combinations this affix can produce. Exactly one is drawn per item.
@export var combinations: Array[AffixCombinationData] = []
