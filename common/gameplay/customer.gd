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


## Default demand-tag count range per customer.
const DEFAULT_TAG_MIN: int = 2
const DEFAULT_TAG_MAX: int = 4

## Default nightly customer count range. Used when generate_for_night is
## called without an explicit count (the time-slot economy will later pass a
## slot-derived count here instead — see dev/docs/draft/time_slot_economy.md).
const DEFAULT_NIGHT_MIN: int = 3
const DEFAULT_NIGHT_MAX: int = 5


## Generates a single customer.
##
## [param rng] — seedable RNG for deterministic generation.
## [param inventory_category_ids] — categories the player currently has in
##   storage. Each demand tag has a 50% chance of being drawn from this pool
##   (guaranteed-matchable) and 50% from the full vocabulary — a per-tag bias,
##   so roughly half of a customer's tags match current storage.
## [param all_category_ids] — full pool of available category IDs to draw from
##   for random demand. Defaults to CategoryRegistry when empty.
static func generate(
        rng: RandomNumberGenerator,
        inventory_category_ids: Array[String] = [],
        all_category_ids: Array[String] = [],
        tag_min: int = DEFAULT_TAG_MIN,
        tag_max: int = DEFAULT_TAG_MAX,
) -> Customer:
    var c := Customer.new()
    c.customer_id = "cust_%s" % RandomUtils.random_id(rng)
    c.display_name = RandomUtils.random_name(rng)

    var preset: Vector2i = GRID_PRESETS[rng.randi_range(0, GRID_PRESETS.size() - 1)]
    c.grid_columns = preset.x
    c.grid_rows = preset.y

    if all_category_ids.is_empty():
        all_category_ids = CategoryRegistry.get_all_category_ids()

    c.demand_tags = _pick_biased_demand(
        rng, inventory_category_ids, all_category_ids, tag_min, tag_max,
    )
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


## Generates a night's worth of customers.
##
## Builds the owned-pool from storage items' category IDs (per-tag 50/50 match
## bias inside [method generate]). Each customer gets 2–4 demand tags.
##
## [param count] — number of customers. When negative, a random
##   DEFAULT_NIGHT_MIN..DEFAULT_NIGHT_MAX count is rolled. The time-slot economy
##   feature passes a slot-derived count here.
static func generate_for_night(
        rng: RandomNumberGenerator,
        storage_items: Array = [],
        count: int = -1,
        all_category_ids: Array[String] = [],
) -> Array[Customer]:
    if count < 0:
        count = rng.randi_range(DEFAULT_NIGHT_MIN, DEFAULT_NIGHT_MAX)

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
    return result


## Returns the category_id for an ItemEntry or similar duck-typed object.
static func _entry_category_id(entry) -> String:
    if entry is ItemEntry and entry.item_data != null:
        var item: ItemEntry = entry
        if item.item_data.category_data != null:
            return item.item_data.category_data.category_id
    return ""

# ══ Internal ═══════════════════════════════════════════════════════════════════


## Picks unique demand tags with a per-tag 50/50 match bias.
## For each slot, draws from [param owned_pool] (guaranteed-matchable) with
## 50% probability, otherwise from [param all_pool]. Dedupes across slots.
## Falls back entirely to all_pool when owned_pool is empty.
static func _pick_biased_demand(
        rng: RandomNumberGenerator,
        owned_pool: Array[String],
        all_pool: Array[String],
        min_count: int,
        max_count: int,
) -> Array[String]:
    if all_pool.is_empty():
        return []

    var hi := mini(max_count, all_pool.size())
    var lo := clampi(min_count, 0, hi)
    var count := rng.randi_range(lo, hi)

    var result: Array[String] = []
    # Bounded attempts: dedupe can reject draws, so cap iterations defensively.
    var attempts := 0
    var max_attempts := count * 20 + 10
    while result.size() < count and attempts < max_attempts:
        attempts += 1
        var use_owned := not owned_pool.is_empty() and rng.randf() < 0.5
        var src: Array[String] = owned_pool if use_owned else all_pool
        var pick: String = src[rng.randi_range(0, src.size() - 1)]
        if pick not in result:
            result.append(pick)
    return result
