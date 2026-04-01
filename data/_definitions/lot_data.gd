# lot_data.gd
# Designer-authored resource defining the properties of a storage lot.
# Contains only static configuration — ranges and item pool definitions.
# Runtime values (rolled factors, item entries) live in LotEntry.
class_name LotData
extends Resource

# ── NPC aggression ────────────────────────────────────────────────────────────

# Range from which aggressive_factor is rolled at run start.
# Controls how aggressively NPCs bid relative to item value.
@export var aggressive_factor_min: float = 0.3
@export var aggressive_factor_max: float = 0.7

# Bounds for the aggressive_lerp multiplier applied during rolled_price calculation.
# Narrows or widens NPC estimate variance per location.
# Easy location example : Vector2(0.7, 1.05) — rarely overbid, safe for beginners.
# Hard location example : Vector2(0.6, 1.40) — player must judge if the lot is overpriced.
# Upper bound caps rolled_price growth; 1.4 is the recommended ceiling.
@export var aggressive_lerp_min: float = 0.8
@export var aggressive_lerp_max: float = 1.2

# ── Demand ────────────────────────────────────────────────────────────────────

# Range from which demand_factor is rolled at run start.
# Represents irrational or enthusiasm-driven demand (rookies, collectors, hype).
# Lerp weight between unveiled base_price and total_true_value.
@export var demand_factor_min: float = 0.3
@export var demand_factor_max: float = 0.7

# ── Knowledge (post-demo) ─────────────────────────────────────────────────────

# Range from which knowledge_factor is rolled at run start.
# Placeholder — ignored until the knowledge system is implemented.
@export var knowledge_factor_min: float = 0.4
@export var knowledge_factor_max: float = 0.6

# ── Item pool ─────────────────────────────────────────────────────────────────

# Chance (0.0–1.0) that any item in this lot spawns veiled.
@export var veiled_chance: float = 0.4

# Item presets available in this lot. Runtime selection and ordering is handled by LotEntry.
# TODO: replace with weighted pool once item randomization is implemented.
@export var item_pool: Array[ItemData] = []
