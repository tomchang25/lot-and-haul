# merchant_data.gd
# Designer-authored resource describing a merchant the player can sell to.
# Place .tres files under data/merchants/
class_name MerchantData
extends Resource

# Internal identifier. snake_case. Matches the .tres filename stem.
@export var merchant_id: String = ""

@export var display_name: String = ""

# Super-categories this merchant will buy at the specialist rate (1.2–1.5×).
# Empty array = accepts all categories at the general rate (pawn shop behaviour).
@export var accepted_super_categories: Array[SuperCategoryData] = []

# Designer-defined pool that special_orders is drawn from each Day Pass.
# Leave empty for merchants with no special orders (e.g. pawn shop).
@export var special_order_pool: Array[ItemData] = []

# How many items to draw into special_orders each Day Pass.
@export var special_order_count: int = 2

# Perk required to access this merchant.
# Empty string = no gate (accessible to all players).
@export var required_perk_id: String = ""

# Items currently on special order. Populated at runtime each Day Pass by
# drawing special_order_count items from special_order_pool.
# Not serialised — regenerated on each Day Pass.
var special_orders: Array[ItemData] = []
