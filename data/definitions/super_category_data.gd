# super_category_data.gd
# Designer-authored resource. Broad classification grouping related categories.
# Place .tres files under data/tres/super_categories/
class_name SuperCategoryData
extends Resource

# Internal identifier, snake_case. Matches the .tres filename stem.
@export var super_category_id: String = ""

# Human-readable label shown to the player.
@export var display_name: String = ""

# ── Market parameters ────────────────────────────────────────────────────────
# Used by MarketManager to drive the random-walk pricing per super-category.

@export var market_mean_min: float = 0.7
@export var market_mean_max: float = 1.3
@export var market_stddev: float = 0.08
@export var market_drift_per_day: float = 0.05
