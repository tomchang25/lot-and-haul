# item_data.gd
# Static data resource representing a single auctionable item.
# Contains only intrinsic item properties — no inspection logic or action rules.
# Clue tags are ordered by discovery depth: earlier tags are revealed by lighter
# inspection actions, later tags require deeper investigation.
# Reveal counts per action are defined externally in InspectionActionData (Block 02).

class_name ItemData
extends Resource

# Display name shown in UI
@export var item_name: String = ""

# Ground-truth market value in currency units; never shown directly to the player
@export var true_value: int = 0

# Weight in kilograms; used for cargo weight limit checks
@export var weight: float = 0.0

# Number of inventory grid cells this item occupies (1-dimensional for now)
@export var grid_size: int = 1

# Ordered list of descriptive tags representing this item's characteristics.
# Sequence implies information depth: index 0 is the most surface-level clue,
# higher indices require more thorough inspection to uncover.
# Examples: "antique", "1870s", "brass", "functional", "rare", "damaged"
@export var clues: Array[String] = []
