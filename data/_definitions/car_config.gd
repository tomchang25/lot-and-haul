# car_config.gd
# Designer-authored resource defining a car's gameplay properties.
class_name CarConfig
extends Resource

@export var car_id: String
@export var display_name: String
@export var grid_columns: int
@export var grid_rows: int
@export var max_weight: float
@export var stamina_cap: int
@export var travel_cost: int


func total_slots() -> int:
    return grid_columns * grid_rows
