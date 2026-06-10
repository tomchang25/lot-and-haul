# category_data.gd
# Designer-authored resource. Defines pool scope, super-category relationship,
# and display label for a fine-grained item type. Physical properties (shape,
# weight) have moved to per-anchor ClueData fields.
# Place .tres files under data/tres/categories/
class_name CategoryData
extends Resource

# Internal identifier. Matches the .tres filename stem and DB category_id.
@export var category_id: String = ""

# Broad item type. References a SuperCategoryData resource.
@export var super_category: SuperCategoryData = null

# Fine-grained item type shown to the player (e.g. "Painting", "Pocket Watch").
@export var display_name: String = ""
