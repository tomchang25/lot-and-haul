# customer.gd
# Runtime value object representing a single nightly customer visit.
# Each customer arrives with demand tags (what categories they want to buy)
# and a car grid (how much cargo space they have).
class_name Customer
extends RefCounted

# ── State ──────────────────────────────────────────────────────────────────────

var customer_id: String = ""
var display_name: String = ""
var grid_columns: int = 2
var grid_rows: int = 2

## Category IDs (or super-category IDs) the customer is looking to buy.
var demand_tags: Array[String] = []

# ══ Serialisation ══════════════════════════════════════════════════════════════


func to_dict() -> Dictionary:
    return {
        "customer_id": customer_id,
        "display_name": display_name,
        "grid_columns": grid_columns,
        "grid_rows": grid_rows,
        "demand_tags": demand_tags.duplicate(),
    }


static func from_dict(d: Dictionary) -> Customer:
    var c := Customer.new()
    c.customer_id = str(d.get("customer_id", ""))
    c.display_name = str(d.get("display_name", ""))
    c.grid_columns = int(d.get("grid_columns", 2))
    c.grid_rows = int(d.get("grid_rows", 2))
    var raw: Array = d.get("demand_tags", [])
    c.demand_tags.assign(raw.duplicate())
    return c

# ══ Generator — 50/50 match-biased creation ═══════════════════════════════════

const GRID_PRESETS: Array[Vector2i] = [
    Vector2i(2, 2),
    Vector2i(3, 2),
    Vector2i(3, 3),
    Vector2i(4, 3),
    Vector2i(4, 4),
    Vector2i(5, 4),
]


## Generates a single customer.
##
## [param rng] — seedable RNG for deterministic generation.
## [param inventory_category_ids] — categories the player currently has in
##   storage. When non-empty, there's a 50% chance demand_tags are biased
##   toward matching these.
## [param all_category_ids] — full pool of available category IDs to draw from
##   for random demand. Defaults to CategoryRegistry when empty.
static func generate(
        rng: RandomNumberGenerator,
        inventory_category_ids: Array[String] = [],
        all_category_ids: Array[String] = [],
) -> Customer:
    var c := Customer.new()
    c.customer_id = "cust_%s" % RandomUtils.random_id(rng)
    c.display_name = RandomUtils.random_name(rng)

    var preset: Vector2i = GRID_PRESETS[rng.randi_range(0, GRID_PRESETS.size() - 1)]
    c.grid_columns = preset.x
    c.grid_rows = preset.y

    if all_category_ids.is_empty():
        all_category_ids = CategoryRegistry.get_all_category_ids()

    var use_match := (
        not inventory_category_ids.is_empty()
        and all_category_ids.size() > 0
        and rng.randf() < 0.5
    )

    if use_match:
        c.demand_tags = _pick_demand(rng, inventory_category_ids)
    else:
        c.demand_tags = _pick_demand(rng, all_category_ids)

    return c


## Generates multiple customers in one call.
static func generate_batch(
        rng: RandomNumberGenerator,
        count: int,
        inventory_category_ids: Array[String] = [],
        all_category_ids: Array[String] = [],
) -> Array[Customer]:
    var result: Array[Customer] = []
    result.resize(count)
    for i in range(count):
        result[i] = generate(rng, inventory_category_ids, all_category_ids)
    return result

# ══ Nightly generation ═══════════════════════════════════════════════════════


## Generates 3–5 customers for a night.
##
## Builds the owned-pool from storage items' category IDs (50/50 match bias).
## Each customer gets 2–4 demand tags.
static func generate_for_night(
        rng: RandomNumberGenerator,
        storage_items: Array = [],
        all_category_ids: Array[String] = [],
) -> Array[Customer]:
    var count := rng.randi_range(3, 5)

    if all_category_ids.is_empty():
        all_category_ids = CategoryRegistry.get_all_category_ids()

    var owned_pool: Array[String] = []
    for entry in storage_items:
        var cat_id := _entry_category_id(entry)
        if cat_id != "" and not owned_pool.has(cat_id):
            owned_pool.append(cat_id)

    var result: Array[Customer] = []
    result.resize(count)
    for i in range(count):
        result[i] = generate(rng, owned_pool, all_category_ids)
        if owned_pool.is_empty():
            result[i].demand_tags = _pick_demand(rng, all_category_ids, 2, 4)
        else:
            var use_match := rng.randf() < 0.5
            var pool: Array[String] = owned_pool if use_match else all_category_ids
            result[i].demand_tags = _pick_demand(rng, pool, 2, 4)
    return result


## Returns the category_id for an ItemEntry or similar duck-typed object.
static func _entry_category_id(entry) -> String:
    if entry is ItemEntry and entry.item_data != null:
        var item: ItemEntry = entry
        if item.item_data.category_data != null:
            return item.item_data.category_data.category_id
    return ""

# ══ Internal ═══════════════════════════════════════════════════════════════════


## Picks unique category IDs from the given pool.
## Clamps counts so the range never exceeds pool size.
static func _pick_demand(
        rng: RandomNumberGenerator,
        pool: Array[String],
        min_count: int = 1,
        max_count: int = 3,
) -> Array[String]:
    if pool.is_empty():
        return []

    var hi := mini(max_count, pool.size())
    var lo := mini(min_count, hi)
    var count := rng.randi_range(lo, hi)

    var result: Array[String] = []
    result.assign(RandomUtils.pick_unique(rng, pool, count))

    return result
