# customer_generator.gd
# Stateless customer generation policy for nightly customer visits.
# Generates customers with category-first affix-scoped demand tags and
# category-sized customer grids.
class_name CustomerGenerator
extends RefCounted

const GRID_PRESETS: Array[Vector2i] = [
    Vector2i(2, 2),
    Vector2i(3, 2),
    Vector2i(3, 3),
    Vector2i(4, 3),
    Vector2i(4, 4),
    Vector2i(5, 4),
]

const DEFAULT_NIGHT_MIN: int = 3
const DEFAULT_NIGHT_MAX: int = 5
const DEMAND_TAG_COUNT: int = 2


static func generate(rng: RandomNumberGenerator = null) -> CustomerEntry:
    var resolved_rng := RandomUtils.resolve_rng(rng)
    var category: CategoryData = _pick_category(resolved_rng)
    var required_size := AnchorRegistry.get_largest_anchor_size_for_category(category)
    var preset := _pick_min_preset(required_size, resolved_rng)

    return CustomerEntry.create(
        "cust_%s" % RandomUtils.random_id(resolved_rng),
        RandomUtils.random_name(resolved_rng),
        preset,
        _sample_demand_tags(category, resolved_rng),
    )


static func generate_for_night(count: int = -1, rng: RandomNumberGenerator = null) -> Array[CustomerEntry]:
    var resolved_rng := RandomUtils.resolve_rng(rng)
    if count < 0:
        count = resolved_rng.randi_range(DEFAULT_NIGHT_MIN, DEFAULT_NIGHT_MAX)

    var result: Array[CustomerEntry] = []
    result.resize(count)
    for index in range(count):
        result[index] = generate(resolved_rng)
    return result


static func _pick_category(rng: RandomNumberGenerator) -> CategoryData:
    var categories := CategoryRegistry.get_all_categories()
    if categories.is_empty():
        ToastManager.show_dev_error("CustomerGenerator: no categories registered")
        return null
    return categories[rng.randi() % categories.size()]


static func _sample_demand_tags(category: CategoryData, rng: RandomNumberGenerator) -> Array[String]:
    if category == null:
        return [] as Array[String]

    var pool := _clue_pool_for_category(category)
    if pool.size() < DEMAND_TAG_COUNT:
        ToastManager.show_dev_error("CustomerGenerator: category '%s' has only %d reachable clues; padding" % [category.category_id, pool.size()])
        for clue_id in AffixRegistry.get_all_combination_clue_ids():
            if clue_id not in pool:
                pool.append(clue_id)
            if pool.size() >= DEMAND_TAG_COUNT:
                break

    return _pick_unique(pool, DEMAND_TAG_COUNT, rng)


static func _clue_pool_for_category(category: CategoryData) -> Array[String]:
    var pool: Array[String] = []
    for affix in AffixRegistry.get_affixes_for_category(category):
        for clue_id in AffixRegistry.get_clue_ids_for_affix(affix):
            if clue_id not in pool:
                pool.append(clue_id)
    return pool


static func _pick_unique(pool: Array[String], count: int, rng: RandomNumberGenerator) -> Array[String]:
    var result: Array[String] = []
    var attempts := 0
    var max_attempts := count * 20 + 10
    while result.size() < count and not pool.is_empty() and attempts < max_attempts:
        attempts += 1
        var clue_id: String = pool[rng.randi() % pool.size()]
        if clue_id not in result:
            result.append(clue_id)
    return result


static func _pick_min_preset(required: Vector2i, rng: RandomNumberGenerator) -> Vector2i:
    var candidates: Array[Vector2i] = []
    for preset in GRID_PRESETS:
        if (preset.x >= required.x and preset.y >= required.y) or (preset.x >= required.y and preset.y >= required.x):
            candidates.append(preset)

    if candidates.is_empty():
        ToastManager.show_dev_error("CustomerGenerator: no grid preset fits %dx%d; using largest" % [required.x, required.y])
        return GRID_PRESETS.back()

    candidates.sort_custom(func(left, right): return left.x * left.y < right.x * right.y)
    var smallest_area := candidates[0].x * candidates[0].y
    var tied: Array[Vector2i] = []
    for preset in candidates:
        if preset.x * preset.y == smallest_area:
            tied.append(preset)
    return tied[rng.randi() % tied.size()]
