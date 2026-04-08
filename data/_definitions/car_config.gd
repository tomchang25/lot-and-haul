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

## Number of independent trailer slots this car has.
## 0 = no trailer. Each slot accepts any item regardless of shape or weight.
@export var extra_slot_count: int = 0


func total_slots() -> int:
    return grid_columns * grid_rows
