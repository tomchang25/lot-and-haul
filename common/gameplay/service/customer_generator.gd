# customer_generator.gd
# Stateless customer generation service driven by authored CustomerData
# definitions. Replaces the old category-first generator with persona-based
# demand pool selection, storage-fit-tag blending, and authored grid shapes.
class_name CustomerGenerator
extends RefCounted

const PERSONA_DRAW: int = 2
const STORAGE_DRAW: int = 2
const FALLBACK_DRAW: int = 4
const MAX_HIDDEN_TAGS: int = 1

const FALLBACK_GRID: Vector2i = Vector2i(4, 4)


## Generates a single customer from a random CustomerData matching the given
## timeslot. Draws all demand tags from the persona's pool.
static func generate(rng: RandomNumberGenerator = null, timeslot: String = "night") -> CustomerEntry:
    var resolved_rng := RandomUtils.resolve_rng(rng)
    var data := _pick_customer_data(timeslot, resolved_rng)
    if data == null:
        return _fallback_customer(resolved_rng)

    var grid := _pick_grid(data, resolved_rng)
    var tags := _draw_from_pool(data.demand_pool, FALLBACK_DRAW, resolved_rng)

    return CustomerEntry.create(
        data,
        "cust_%s" % RandomUtils.random_id(resolved_rng),
        grid,
        tags,
    )


## Generates a batch of customers for a nightly selling slot. When storage items
## have revealed fit tags, each customer draws PERSONA_DRAW from their persona
## pool and STORAGE_DRAW from storage tags; otherwise draws all FALLBACK_DRAW
## from persona pool.
static func generate_for_slot(storage_items: Array = [], count: int = -1, rng: RandomNumberGenerator = null, timeslot: String = "night") -> Array[CustomerEntry]:
    var resolved_rng := RandomUtils.resolve_rng(rng)
    if count < 0:
        count = _default_count_for_timeslot(timeslot, resolved_rng)

    if count <= 0:
        return [] as Array[CustomerEntry]

    var storage_tag_pool := _build_storage_pool(storage_items)
    var has_tags := not storage_tag_pool.is_empty()

    var result: Array[CustomerEntry] = []
    result.resize(count)
    for index in range(count):
        var data := _pick_customer_data(timeslot, resolved_rng)
        if data == null:
            result[index] = _fallback_customer(resolved_rng)
            continue

        var grid := _pick_grid(data, resolved_rng)
        var tags: Array[String]

        if has_tags:
            tags = _draw_combined(data.demand_pool, storage_tag_pool, resolved_rng)
        else:
            tags = _draw_from_pool(data.demand_pool, FALLBACK_DRAW, resolved_rng)

        result[index] = CustomerEntry.create(
            data,
            "cust_%s" % RandomUtils.random_id(resolved_rng),
            grid,
            tags,
        )

    return result

# ── Internal helpers ────────────────────────────────────────────────────────────


static func _pick_customer_data(timeslot: String, rng: RandomNumberGenerator) -> CustomerData:
    var candidates := CustomerRegistry.get_customers_for_timeslot(timeslot)
    if candidates.is_empty():
        ToastManager.show_dev_error("CustomerGenerator: no CustomerData for timeslot '%s'" % timeslot)
        return null
    return candidates[rng.randi() % candidates.size()]


static func _default_count_for_timeslot(timeslot: String, rng: RandomNumberGenerator) -> int:
    if timeslot == "day":
        return rng.randi_range(Economy.DAY_SELLING_CUSTOMER_MIN, Economy.DAY_SELLING_CUSTOMER_MAX)
    return rng.randi_range(Economy.NIGHT_SELLING_CUSTOMER_MIN, Economy.NIGHT_SELLING_CUSTOMER_MAX)


static func _pick_grid(data: CustomerData, rng: RandomNumberGenerator) -> Vector2i:
    var pool := data.grid_shape_pool
    if pool.is_empty():
        return FALLBACK_GRID
    return pool[rng.randi() % pool.size()]


static func _build_storage_pool(storage_items: Array) -> Array[String]:
    var pool: Array[String] = []
    for item in storage_items:
        if item == null or not item.has_method("fit_tags"):
            continue
        for tag: String in item.fit_tags():
            if tag not in pool:
                pool.append(tag)
    return pool


## Draws [count] unique tags from [pool] respecting MAX_HIDDEN_TAGS.
static func _draw_from_pool(pool: Array[String], count: int, rng: RandomNumberGenerator, report_underfilled: bool = true) -> Array[String]:
    var result: Array[String] = []
    var hidden_count := 0
    var remaining := pool.duplicate()
    var attempts := 0
    var max_attempts := count * 20 + 10

    while result.size() < count and not remaining.is_empty() and attempts < max_attempts:
        attempts += 1
        var idx := rng.randi() % remaining.size()
        var tag: String = remaining[idx]
        remaining.remove_at(idx)

        if tag in result:
            continue

        if _is_hidden(tag):
            if hidden_count >= MAX_HIDDEN_TAGS:
                continue
            hidden_count += 1

        result.append(tag)

    if result.size() < count and report_underfilled:
        ToastManager.show_dev_error("CustomerGenerator: pool has fewer than %d available tags after filtering (got %d)" % [count, result.size()])

    return result


## Draws persona pool tags + storage pool tags, combined, respecting hidden cap.
static func _draw_combined(persona_pool: Array[String], storage_pool: Array[String], rng: RandomNumberGenerator) -> Array[String]:
    var result: Array[String] = []

    # Draw from storage pool first (these items match known storage).
    var storage_tags := _draw_from_pool(storage_pool, STORAGE_DRAW, rng, false)
    result.append_array(storage_tags)

    # Compute remaining hidden budget after storage tags.
    var budget := MAX_HIDDEN_TAGS - _count_hidden(storage_tags)

    # Draw persona tags respecting remaining hidden budget.
    var persona_tags := _draw_with_budget(persona_pool, PERSONA_DRAW, budget, rng)
    for t in persona_tags:
        if t not in result:
            result.append(t)

    # If result is short, fill from persona pool (excluding dupes).
    if result.size() < PERSONA_DRAW + STORAGE_DRAW:
        var fill := _draw_excluding_with_budget(
            persona_pool,
            PERSONA_DRAW + STORAGE_DRAW - result.size(),
            result,
            MAX_HIDDEN_TAGS - _count_hidden(result),
            rng,
        )
        for t in fill:
            if t not in result:
                result.append(t)

    return result


## Draws up to [count] tags from [pool] with a hard cap on hidden tags.
static func _draw_with_budget(pool: Array[String], count: int, hidden_budget: int, rng: RandomNumberGenerator) -> Array[String]:
    if hidden_budget <= 0:
        # Only surface tags allowed.
        var surface_only: Array[String] = []
        for tag in pool:
            if not _is_hidden(tag):
                surface_only.append(tag)
        return _draw_from_pool(surface_only, count, rng)

    # Hidden budget > 0: use normal draw.
    return _draw_from_pool(pool, count, rng)


## Draws unique tags from [pool] excluding those in [exclude].
static func _draw_excluding(pool: Array[String], count: int, exclude: Array[String], rng: RandomNumberGenerator) -> Array[String]:
    var filtered: Array[String] = []
    for tag in pool:
        if tag not in exclude:
            filtered.append(tag)
    return _draw_from_pool(filtered, count, rng)


## Draws unique tags from [pool] excluding those in [exclude] and respecting a
## remaining hidden-tag budget.
static func _draw_excluding_with_budget(pool: Array[String], count: int, exclude: Array[String], hidden_budget: int, rng: RandomNumberGenerator) -> Array[String]:
    var filtered: Array[String] = []
    for tag in pool:
        if tag not in exclude:
            filtered.append(tag)
    return _draw_with_budget(filtered, count, hidden_budget, rng)


static func _is_hidden(clue_id: String) -> bool:
    var clue := ClueRegistry.get_clue_by_id(clue_id)
    return clue != null and clue.type == ClueData.ClueType.HIDDEN


static func _count_hidden(tags: Array[String]) -> int:
    var count := 0
    for t in tags:
        if _is_hidden(t):
            count += 1
    return count


static func _fallback_customer(rng: RandomNumberGenerator) -> CustomerEntry:
    return CustomerEntry.create(
        null,
        "cust_%s" % RandomUtils.random_id(rng),
        FALLBACK_GRID,
        [],
    )
