# merchant_data.gd
# Designer-authored resource describing a merchant the player can sell to.
# Place .tres files under data/tres/merchants/
class_name MerchantData
extends Resource

# ── Identity ─────────────────────────────────────────────────────────────────

# Internal identifier. snake_case. Matches the .tres filename stem.
@export var merchant_id: String = ""

@export var display_name: String = ""

# Short flavour text shown on the merchant hub card.
@export var description: String = ""

# ── Category focus ───────────────────────────────────────────────────────────

# Super-categories this merchant will buy at the specialist rate.
# Empty array = accepts all categories at the general rate (pawn shop behaviour).
@export var accepted_super_categories: Array[SuperCategoryData] = []

# ── Pricing ──────────────────────────────────────────────────────────────────

# Multiplier applied to appraised_value for items in accepted super-categories
# (or all items when accepted_super_categories is empty).
@export var price_multiplier: float = 1.0

# ── Off-category handling ────────────────────────────────────────────────────

# Whether this merchant buys items outside their specialty.
@export var accepts_off_category: bool = false

# Multiplier for off-category items. Only used when accepts_off_category is true.
@export var off_category_multiplier: float = 0.5

# ── Negotiation ──────────────────────────────────────────────────────────────

# Base probability (0.0–1.0) the merchant accepts the player's ask price at 100%.
@export var accept_base_chance: float = 0.8

# How much the accept chance drops per 10% above the merchant's base offer.
@export var haggle_penalty_per_10pct: float = 0.15

# Maximum counter-offers before the merchant says "final offer".
@export var max_counter_offers: int = 2

# ── Special orders ───────────────────────────────────────────────────────────

# Designer-defined pool that special_orders is drawn from each Day Pass.
# Leave empty for merchants with no special orders (e.g. pawn shop).
@export var special_order_pool: Array[ItemData] = []

# How many items to draw into special_orders each Day Pass.
@export var special_order_count: int = 2

# Bonus multiplier added on top of sale price when fulfilling a special order.
# e.g. 0.25 = 25% bonus.
@export var special_order_bonus: float = 0.25

# ── Access gate ──────────────────────────────────────────────────────────────

# Perk required to access this merchant.
# Empty string = no gate (accessible to all players).
@export var required_perk_id: String = ""

# ── Runtime state (not serialised) ───────────────────────────────────────────

# Items currently on special order. Populated at runtime each Day Pass by
# drawing special_order_count items from special_order_pool.
var special_orders: Array[ItemData] = []

# Item IDs of completed special orders this Day Pass. Reset on day advance.
var completed_order_ids: Array[String] = []
