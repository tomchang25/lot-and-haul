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
	c.demand_tags = d.get("demand_tags", []).duplicate()
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

# ══ Internal ═══════════════════════════════════════════════════════════════════


## Picks 1-3 unique category IDs from the given pool.
static func _pick_demand(
	rng: RandomNumberGenerator,
	pool: Array[String],
) -> Array[String]:
	var count := rng.randi_range(1, mini(3, pool.size()))
	return RandomUtils.pick_unique(rng, pool, count) as Array[String]
