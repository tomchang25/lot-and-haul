# category_data.gd
# Designer-authored resource. Holds physical properties shared by all items of
# the same fine-grained type. ItemData holds a direct reference.
# Place .tres files under data/categories/
class_name CategoryData
extends Resource

# Internal identifier. Matches the .tres filename stem and DB category_id.
@export var category_id: String = ""

# Broad item type (e.g. "Fine Art", "Vehicle").
@export var super_category: String = ""

# Fine-grained item type shown to the player (e.g. "Painting", "Pocket Watch").
@export var display_name: String = ""

# Weight in kilograms.
@export var weight: float = 0.0

# Number of inventory grid cells this item occupies.
@export var grid_size: int = 1
