# market_manager.gd
# Autoload that drives daily market fluctuations per super-category.
# Each super-category has a drifting mean; each category samples a daily
# factor from N(super_mean, stddev). Persisted via SaveManager.
extends Node

# Loaded SuperCategoryData resources, keyed by super_category_id.
var _super_cats: Dictionary = {}

# Persisted state — written/read by SaveManager.
var super_cat_means: Dictionary = {}           # super_category_id → float
var category_factors_today: Dictionary = {}    # category_id → float


func _ready() -> void:
	_super_cats = ResourceDirLoader.load_by_id(
		DataPaths.SUPER_CATEGORIES_DIR,
		func(r: Resource) -> String:
			return (r as SuperCategoryData).super_category_id if r is SuperCategoryData else ""
	)
	_init_defaults()


func _init_defaults() -> void:
	for sc_id: String in _super_cats:
		if not super_cat_means.has(sc_id):
			super_cat_means[sc_id] = 1.0
	_resample_category_factors()


# Called by SaveManager.advance_days() alongside MerchantRegistry.roll_special_orders().
func advance_market(days: int) -> void:
	for _day in range(days):
		for sc_id: String in super_cat_means:
			var sc: SuperCategoryData = _super_cats.get(sc_id)
			if sc == null:
				continue
			var drift := randf_range(-sc.market_drift_per_day, sc.market_drift_per_day)
			super_cat_means[sc_id] = clampf(
				super_cat_means[sc_id] + drift,
				sc.market_mean_min,
				sc.market_mean_max,
			)
	_resample_category_factors()


func get_category_factor(category_id: String) -> float:
	return category_factors_today.get(category_id, 1.0)


func get_super_category_trend(super_cat_id: String) -> float:
	return super_cat_means.get(super_cat_id, 1.0)


func _resample_category_factors() -> void:
	for sc_id: String in _super_cats:
		var sc: SuperCategoryData = _super_cats[sc_id]
		var mean: float = super_cat_means.get(sc_id, 1.0)
		for cat_id: String in ItemRegistry.get_categories_for_super(sc_id):
			category_factors_today[cat_id] = _randf_normal(mean, sc.market_stddev)


static func _randf_normal(mean: float, stddev: float) -> float:
	var u1 := maxf(randf(), 1e-10)
	var u2 := randf()
	var z := sqrt(-2.0 * log(u1)) * cos(TAU * u2)
	return mean + stddev * z
