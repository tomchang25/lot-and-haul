# commodity_data.gd
# Designer-authored resource representing fixed-market-value lot filler.
class_name CommodityData
extends Resource

# Internal identifier. Never displayed to the player.
@export var commodity_id: String = ""

@export var display_name: String = ""
@export var category_data: CategoryData = null
@export var base_value: int = 0
