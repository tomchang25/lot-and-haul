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

# Super-categories this merchant buys at specialist rate.
# Items outside this list fall through to off-category handling.
@export var accepted_super_categories: Array[SuperCategoryData] = []

# ── Pricing ──────────────────────────────────────────────────────────────────

# Multiplier applied to appraised_value for items in accepted super-categories.
@export var price_multiplier: float = 1.0

# ── Off-category handling ────────────────────────────────────────────────────

# Whether this merchant buys items outside their specialty.
@export var accepts_off_category: bool = false

# Multiplier for off-category items. Only used when accepts_off_category is true.
@export var off_category_multiplier: float = 0.5

# ── Negotiation ──────────────────────────────────────────────────────────────

# Ceiling rolled uniformly per session within these bounds, applied to the
# basket initial offer. Determines maximum price the merchant will consider.
@export var ceiling_multiplier_min: float = 1.1
@export var ceiling_multiplier_max: float = 1.3

# Session anger cap. When anger reaches this value the merchant makes a
# final offer at the current counter-offer price.
@export var anger_max: float = 100.0

# Gain coefficient for the proposal-greed term of the anger formula.
@export var anger_k: float = 20.0

# Flat anger added every submission regardless of proposal size.
# anger_max / anger_per_round is the hard round ceiling.
@export var anger_per_round: float = 20.0

# Fraction of the gap the shopkeeper closes each counter round, in (0, 1].
@export var counter_aggressiveness: float = 0.3

# How many negotiation sessions this merchant allows per day.
@export var negotiation_per_day: int = 1

# ── Special orders ───────────────────────────────────────────────────────────

# Pool of order templates this merchant draws from on each roll.
# Empty = no orders (pawn shop).
@export var special_orders: Array[SpecialOrderData] = []

# Days between roll attempts. 0 = no orders.
@export var order_roll_cadence: int = 0

# Cap on simultaneously active orders. Typically 1-2.
@export var max_active_orders: int = 1

# ── Access gate ──────────────────────────────────────────────────────────────

# Perk required to access this merchant.
# Empty string = no gate (accessible to all players).
@export var required_perk_id: String = ""

# ── Offer logic ──────────────────────────────────────────────────────────────


func offer_for(entry: ItemEntry) -> int:
    var base: int = entry.market_price
    if accepted_super_categories.has(entry.item_data.category_data.super_category):
        return int(base * price_multiplier)
    elif accepts_off_category:
        return int(base * off_category_multiplier)
    else:
        return 0

# ── Runtime state (not exported, persisted via SaveManager) ──────────────────

var active_orders: Array[SpecialOrder] = []
var completed_order_ids: Array[String] = [] # accumulates; never cleared
var last_order_roll_day: int = -1

# How many negotiation sessions have been used today. Persisted via SaveManager.
var negotiations_used_today: int = 0
