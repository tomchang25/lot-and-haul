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
@export var required_count_min: int = 1
@export var required_count_max: int = 1

# Pool of categories a generated slot may target.
@export var allowed_categories: Array[CategoryData] = []

# Probability that a generated slot gets a rarity gate (>= UNCOMMON).
@export var rarity_gate_chance: float = 0.0

# Probability that a generated slot gets a condition gate (>= 0.6).
@export var condition_gate_chance: float = 0.0

# ── Pricing & turn-in flags ──────────────────────────────────────────────────

@export var buff_min: float = 1.0
@export var buff_max: float = 1.0

# If true, per-item price uses entry.get_condition_multiplier().
# Otherwise condition is ignored (flat-rate bulk).
@export var uses_condition_pricing: bool = false

# If true, confirm works with any non-empty assignment and slot progress
# persists across sessions. If false, confirm is disabled until every slot
# is fully filled in one session.
@export var allow_partial_delivery: bool = false

# ── Completion ───────────────────────────────────────────────────────────────

@export var completion_bonus: int = 0
@export var deadline_days: int = 5
