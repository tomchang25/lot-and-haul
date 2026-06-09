# location_data.gd
# Designer-authored resource defining a visitable storage location.
# Contains the pool of lots available and how many are sampled per visit.
class_name LocationData
extends Resource

# Stable identifier for this location. Must match the .tres filename stem.
@export var location_id: String = ""

# Player-facing name shown on the location selection screen.
@export var display_name: String = ""

# One-line flavor / summary shown on the location selection screen.
@export var description: String = ""

# Upfront cost deducted when entering this location.
@export var entry_fee: int = 0

# Number of days the round-trip to this location takes.
@export var travel_days: int = 1

# How many lots are sampled (without replacement) from lot_pool per visit.
@export var lot_number: int = 3

# Pool of LotData to draw from when the player visits this location.
@export var lot_pool: Array[LotData] = []

# ── Arrival visuals ───────────────────────────────────────────────────────────

# Background shown before the transition wipe (the exterior / outside view).
# Null falls back to the plain ColorRect background.
@export var bg_exterior: Texture2D

# Background revealed after the transition wipe (the interior / inside view).
# Null falls back to the plain ColorRect background.
@export var bg_interior: Texture2D

## Which transition wipe to play on arrival. "sliding_door" or "fade".
## Defaults to "sliding_door" when unset.
@export var transition_type: String = "sliding_door"
