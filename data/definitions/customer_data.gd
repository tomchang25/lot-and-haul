# customer_data.gd
# Designer-authored resource defining a customer persona: their identity, demand
# preferences, grid sizes, timeslot availability, and special valuation flags.
class_name CustomerData
extends Resource

## Internal snake_case identifier. Matches the .tres filename stem.
@export var customer_id: String
## Localization key for the customer display name (e.g. CUSTOMER_REPAIR_HOBBYIST).
@export var display_name_key: String
## When this customer can appear: "day", "night", or "any".
@export var appears_in_timeslot: String = "any"
## Clue ids this persona looks for. Generation draws demand tags from this pool.
@export var demand_pool: Array[String] = []
## Possible car grid dimensions this persona can arrive with.
@export var grid_shape_pool: Array[Vector2i] = []
## Surface-negative (mul < 1.0) clue ids this customer treats as desirable.
## Used by the separate valued-negative-customer-pricing feature.
@export var valued_negative_tags: Array[String] = []
