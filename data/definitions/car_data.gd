# car_data.gd
# Designer-authored resource defining a car's gameplay properties.
#
# TODO: If non-car vehicles (trucks, boats, planes, etc.) are eventually added
# to the game, revisit this class name at that point. `Vehicle` is already
# taken by an item super_category, so `Rig` or similar may be the answer.
# Do not rename preemptively — wait until a concrete second vehicle type
# actually exists.
class_name CarData
extends Resource

@export var car_id: String
@export var display_name: String
@export var grid_columns: int
@export var grid_rows: int
@export var max_weight: float
@export var stamina_cap: int
@export var fuel_cost_per_day: int = 0

## Number of independent trailer slots this car has.
## 0 = no trailer. Each slot accepts any item regardless of shape or weight.
@export var extra_slot_count: int = 0

## Cost to buy this car in the Car Shop. Starter cars use 0.
@export var price: int = 0

## Icon shown in the Car Select / Car Shop UI. May be null for cars with no art.
@export var icon: Texture2D


func total_slots() -> int:
    return grid_columns * grid_rows


func stats_line() -> String:
    return (
        "Grid: %d×%d    Weight: %d    Stamina: %d    Fuel/day: %d    Extra slots: %d"
        % [
            grid_columns,
            grid_rows,
            int(max_weight),
            stamina_cap,
            fuel_cost_per_day,
            extra_slot_count,
        ]
    )
