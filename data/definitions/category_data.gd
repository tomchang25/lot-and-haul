# category_data.gd
# Designer-authored resource. Holds physical properties shared by all items of
# the same fine-grained type. ItemData holds a direct reference.
# Place .tres files under data/tres/categories/
class_name CategoryData
extends Resource

# Internal identifier. Matches the .tres filename stem and DB category_id.
@export var category_id: String = ""

# Broad item type. References a SuperCategoryData resource.
@export var super_category: SuperCategoryData = null

# Fine-grained item type shown to the player (e.g. "Painting", "Pocket Watch").
@export var display_name: String = ""

# Weight in kilograms.
@export var weight: float = 0.0

# Shape key into CargoShapes.SHAPES.
@export var shape_id: String = "s1x1"


func get_cells() -> Array[Vector2i]:
    return CargoShapes.get_cells(shape_id)
