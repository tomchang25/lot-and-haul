# market_manager.gd
# Autoload that drives category price drift over time.
# Owns two dictionaries: per-super-category means and per-category daily factors.
# Persisted via SaveManager; advanced via advance_market() on day pass.
extends Node

const MIN_CATEGORY_FACTOR := 0.5
const MAX_CATEGORY_FACTOR := 2.0

# { super_category_id: String → float } — drifting mean per super-category.
var super_cat_means: Dictionary = { }

# { category_id: String → float } — today's price factor per category.
var category_factors_today: Dictionary = { }


func _ready() -> void:
    if super_cat_means.is_empty():
        _initialise_means()
    if category_factors_today.is_empty():
        _resample_today()


func get_category_factor(category_id: String) -> float:
    return category_factors_today.get(category_id, 1.0)


func get_super_category_trend(super_cat_id: String) -> float:
    return super_cat_means.get(super_cat_id, 1.0)


func advance_market(days: int) -> void:
    if days <= 0:
        return
    _walk_means(days)
    _resample_today()

# ── Private ──────────────────────────────────────────────────────────────────


func _initialise_means() -> void:
    for sc_id: String in SuperCategoryRegistry.get_all_super_category_ids():
        super_cat_means[sc_id] = 1.0


func _walk_means(days: int) -> void:
    for sc_id: String in super_cat_means.keys():
        var sc: SuperCategoryData = SuperCategoryRegistry.get_super_category(sc_id)
        if sc == null:
            continue
        var mean: float = super_cat_means[sc_id]
        for d in range(days):
            mean += randfn(0.0, sc.market_drift_per_day)
            mean = clampf(mean, sc.market_mean_min, sc.market_mean_max)
        super_cat_means[sc_id] = mean


func _resample_today() -> void:
    for cat: CategoryData in CategoryRegistry.get_all_categories():
        var sc: SuperCategoryData = cat.super_category
        if sc == null:
            continue
        var sc_id: String = sc.super_category_id
        var mean: float = super_cat_means.get(sc_id, 1.0)
        var factor: float = randfn(mean, sc.market_stddev)
        factor = clampf(factor, MIN_CATEGORY_FACTOR, MAX_CATEGORY_FACTOR)
        category_factors_today[cat.category_id] = factor
