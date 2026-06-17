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

const MATCH_FLOOR_RATIO: float = 0.5
const MATCH_FLOOR_MIN: int = 1


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


static func generate_for_night(storage_items: Array = [], count: int = -1, rng: RandomNumberGenerator = null) -> Array[CustomerEntry]:
    var resolved_rng := RandomUtils.resolve_rng(rng)
    if count < 0:
        count = resolved_rng.randi_range(DEFAULT_NIGHT_MIN, DEFAULT_NIGHT_MAX)

    if count <= 0:
        return [] as Array[CustomerEntry]

    if not _has_any_fit_tags(storage_items):
        return _generate_unconstrained(count, resolved_rng)

    var target_matches := _match_floor_for_count(count)
    var result: Array[CustomerEntry] = []
    var targeted := _generate_targeted_matches(storage_items, target_matches, resolved_rng)
    result.assign(targeted)
    while result.size() < count:
        result.append(generate(resolved_rng))

    return result


static func _generate_unconstrained(count: int, rng: RandomNumberGenerator) -> Array[CustomerEntry]:
    var result: Array[CustomerEntry] = []
    result.resize(count)
    for index in range(count):
        result[index] = generate(rng)
    return result


static func _match_floor_for_count(count: int) -> int:
    return clampi(ceili(float(count) * MATCH_FLOOR_RATIO), MATCH_FLOOR_MIN, count)


## Builds the guaranteed-match portion of a night from storage tags. If any
## generated customer fails the same SellMath check used by selling, callers
## should discard the batch and fall back to unconstrained generation.
static func _generate_targeted_matches(storage_items: Array, count: int, rng: RandomNumberGenerator) -> Array[CustomerEntry]:
    var specs := _target_specs_for_storage(storage_items)
    var result: Array[CustomerEntry] = []
    if specs.is_empty():
        return result

    for index in range(count):
        var spec: Dictionary = specs[index % specs.size()]
        var customer := _make_targeted_customer(spec["category"], spec["tag"], rng)
        if not _customer_matches_storage(customer, storage_items):
            return [] as Array[CustomerEntry]
        result.append(customer)
    return result


static func _target_specs_for_storage(storage_items: Array) -> Array[Dictionary]:
    var specs: Array[Dictionary] = []
    for item in storage_items:
        if item == null or not item.has_method("fit_tags"):
            continue
        var item_tags: Array = item.fit_tags()
        if item_tags.is_empty():
            continue
        var cat: CategoryData = item.category_data if item is ItemEntry else null
        for raw_tag in item_tags:
            var tag := String(raw_tag)
            var tag_cat := cat if cat != null else _find_category_for_clue(tag)
            if tag_cat != null:
                specs.append({ "category": tag_cat, "tag": tag })
    return specs


static func _make_targeted_customer(category: CategoryData, tag: String, rng: RandomNumberGenerator) -> CustomerEntry:
    var required_size := AnchorRegistry.get_largest_anchor_size_for_category(category)
    var preset := _pick_min_preset(required_size, rng)
    var tags := _sample_demand_tags(category, rng)
    if not tags.is_empty() and tag not in tags:
        tags[0] = tag

    return CustomerEntry.create(
        "cust_%s" % RandomUtils.random_id(rng),
        RandomUtils.random_name(rng),
        preset,
        tags,
    )


static func _find_category_for_clue(clue_id: String) -> CategoryData:
    var categories := CategoryRegistry.get_all_categories()
    for cat in categories:
        var pool := _clue_pool_for_category(cat)
        if clue_id in pool:
            return cat
    return null


static func _customer_matches_storage(customer: CustomerEntry, storage_items: Array) -> bool:
    return not SellMath.matched_items(customer, storage_items).is_empty()


static func _has_any_fit_tags(storage_items: Array) -> bool:
    for entry in storage_items:
        if entry != null and entry.has_method("fit_tags") and not entry.fit_tags().is_empty():
            return true
    return false


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
