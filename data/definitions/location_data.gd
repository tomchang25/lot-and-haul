# location_data.gd
# Designer-authored resource defining a visitable storage location.
# Contains the pool of lots available and how many are sampled per visit.
class_name LocationData
extends Resource

# Pool of LotData to draw from when the player visits this location.
@export var lot_pool: Array[LotData] = []

# How many lots are sampled (without replacement) from lot_pool per visit.
@export var lot_number: int = 3

# Upfront cost deducted when entering this location.
@export var entry_fee: int = 0

# Number of days the round-trip to this location takes.
@export var travel_days: int = 1
