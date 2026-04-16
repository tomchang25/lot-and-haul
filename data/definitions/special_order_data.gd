# special_order_data.gd
# Designer-authored Resource template for special orders.
# Place .tres files under data/tres/special_orders/
# Naming convention: {merchant_id}_{archetype}.tres
class_name SpecialOrderData
extends Resource

# Internal identifier. snake_case. Matches the .tres filename stem.
@export var special_order_id: String = ""

# ── Slot generation ──────────────────────────────────────────────────────────

# Total slot count range for the order. Each slot picks a pool entry uniformly
# from `slot_pool` and uses that entry's floors/categories/count range.
@export var slot_count_min: int = 1
@export var slot_count_max: int = 1

# Pool of slot profiles. Must be non-empty. Each slot in a generated order
# picks one entry uniformly at random.
@export var slot_pool: Array[SpecialOrderSlotPoolEntry] = []

# ── Pricing & turn-in flags ──────────────────────────────────────────────────

@export var buff_min: float = 1.0
@export var buff_max: float = 1.0

# Per-factor pricing flags. These map one-to-one to the same-named fields on
# SpecialOrder and feed the order's PriceConfig.
@export var uses_condition: bool = false
@export var uses_knowledge: bool = false
@export var uses_market: bool = false

# If true, confirm works with any non-empty assignment and slot progress
# persists across sessions. If false, confirm is disabled until every slot
# is fully filled in one session.
@export var allow_partial_delivery: bool = false

# ── Completion ───────────────────────────────────────────────────────────────

@export var completion_bonus: int = 0
@export var deadline_days: int = 5
