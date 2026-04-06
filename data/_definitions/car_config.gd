# car_config.gd
# Designer-authored resource defining a car's gameplay properties.
class_name CarConfig
extends Resource

@export var car_id: String
@export var display_name: String
@export var max_slots: int
@export var max_weight: float
@export var stamina_cap: int
@export var travel_cost: int
