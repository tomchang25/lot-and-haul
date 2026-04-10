# identity_layer.gd
# Designer-authored resource. Represents one rung in an item's identity chain.
# Place reusable standalone .tres files under data/tres/identity_layers/
class_name IdentityLayer
extends Resource

# Internal identifier. Matches the .tres filename stem and DB layer_id.
@export var layer_id: String = ""

# The name shown to the player when this layer is the active read.
@export var display_name: String = ""

# Base market value at this layer of understanding.
# Used as the anchor for price estimates at inspection and auction.
# The last layer's base_value is the item's true value.
@export var base_value: int = 0

# Action required to advance from this layer to the next one.
# Null on the final layer — no further advancement possible.
@export var unlock_action: LayerUnlockAction = null
