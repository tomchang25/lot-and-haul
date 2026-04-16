# special_order_data.gd
# Designer-authored Resource template for special orders.
# Place .tres files under data/tres/special_orders/
# Naming convention: {merchant_id}_{archetype}.tres
class_name SpecialOrderData
extends Resource

# Internal identifier. snake_case. Matches the .tres filename stem.
@export var special_order_id: String = ""

# ── Slot generation ──────────────────────────────────────────────────────────

@export var slot_count_min: int = 1
@export var slot_count_max: int = 1

# Pool of slot profiles. Each generated slot picks one entry uniformly at
# random and inherits its categories, rarity/condition floors, and count range.
@export var slot_pool: Array[SpecialOrderSlotData] = []

# ── Pricing & turn-in flags ──────────────────────────────────────────────────

@export var buff_min: float = 1.0
@export var buff_max: float = 1.0

# Pricing preset name. Maps to a PriceConfig at order creation time.
# Accepted values: "flat", "condition", "appraised", "market".
@export var pricing_mode: String = "flat"

# If true, confirm works with any non-empty assignment and slot progress
# persists across sessions. If false, confirm is disabled until every slot
# is fully filled in one session.
@export var allow_partial_delivery: bool = false

# ── Completion ───────────────────────────────────────────────────────────────

@export var completion_bonus: int = 0
@export var deadline_days: int = 5
