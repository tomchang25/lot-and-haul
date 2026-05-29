# super_category_data.gd
# Designer-authored resource. Broad classification grouping related categories.
# Place .tres files under data/tres/super_categories/
class_name SuperCategoryData
extends Resource

# Internal identifier, snake_case. Matches the .tres filename stem.
@export var super_category_id: String = ""

# Human-readable label shown to the player.
@export var display_name: String = ""
