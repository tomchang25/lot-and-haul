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

# ── Knowledge ─────────────────────────────────────────────────────
# ── NPC knowledge (placeholder) ───────────────────────────────────────────────

# Probability that the NPC sees one layer deeper than the item's starting layer.
# Applied repeatedly — each tick has this chance to advance one more layer.
# Placeholder for full NPC knowledge system. 0.0 = sees only starting layer.
@export var npc_layer_sight_chance: float = 0.5

# ── Auction ───────────────────────────────────────────────────────────────────

# Fraction of npc_estimate used as the opening bid.
# Shared by the pre-auction review (Block 03) and the auction itself (Block 04).
@export var opening_bid_factor: float = 0.25

# ── Item pool ─────────────────────────────────────────────────────────────────

# Chance (0.0–1.0) that any item in this lot spawns veiled.
@export var veiled_chance: float = 0.4

# DEPRECATED: direct item list — use category_weights / rarity_weights instead.
# Kept for legacy .tres files; LotEntry ignores this when weight tables are non-empty.
@export var item_pool: Array[ItemData] = []

# Number of items drawn for this lot. Actual count is randi_range(min, max).
@export var item_count_min: int = 3
@export var item_count_max: int = 5

# Weighted rarity table for item draws.
# Key: ItemData.Rarity (int enum value), Value: weight (int).
# Example: { 0: 60, 1: 25, 2: 10, 3: 4, 4: 1 }
@export var rarity_weights: Dictionary = {}

# Weighted category table for item draws.
# Key: category_id (String), Value: weight (int).
# Example: { "bicycle": 1, "handbag": 1, "oil_lamp": 1, "painting": 1 }
@export var category_weights: Dictionary = {}

# ── Price estimation ──────────────────────────────────────────────────────────
# Multiplier bounds applied to npc_estimate when rolling the final price.
# rolled_price is clamped to [npc_estimate * price_floor, npc_estimate * price_ceiling].
@export var price_floor_factor: float = 0.6
@export var price_ceiling_factor: float = 1.4

# Per-run price noise. Rolled close to 1.0 — adds slight variance across runs
# without systematic bias. Not tied to demand or NPC knowledge.
@export var price_variance_min: float = 0.85
@export var price_variance_max: float = 1.15

# ── Action limits ─────────────────────────────────────────────────────────────
@export var action_quota: int = 6 # per-lot action limit
