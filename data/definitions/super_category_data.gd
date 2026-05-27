# super_category_data.gd
# Designer-authored resource. Broad classification grouping related categories.
# Place .tres files under data/tres/super_categories/
class_name SuperCategoryData
extends Resource

# Internal identifier, snake_case. Matches the .tres filename stem.
@export var super_category_id: String = ""

# Human-readable label shown to the player.
@export var display_name: String = ""

# ── Market tuning ────────────────────────────────────────────────────────────

# Bounds for the super-category's drifting mean (MarketManager random walk).
@export var market_mean_min: float = 0.1
@export var market_mean_max: float = 4.0

# Standard deviation used when resampling daily category factors around the mean.
@export var market_stddev: float = 0.02

# Gaussian step standard deviation for the mean random walk; step fires once every 7 days.
@export var market_drift_per_week: float = 0.05
