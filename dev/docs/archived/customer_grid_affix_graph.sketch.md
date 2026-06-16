# Customer Grid & Tags via Category-First Affix Sampling

## Goal

Replace the independent tag-generation-then-grid-sizing pipeline with category-first customer generation: pick one category, derive demand tags from affix combinations that apply to that category, and size the customer grid to fit that category's largest anchor shape. Keep the customer runtime object focused on saved customer state while generation policy moves to the appropriate generation/query collaborators.

## Requirements

1. A customer's demand tags are always two clues drawn from the combination pool of affixes scoped to a single randomly chosen category, so tags are guaranteed reachable through the affix system.
2. The customer grid is the smallest-area preset that fits the largest anchor bounding-box in the chosen category, in either orientation.
3. Category reachability comes from affix scope, not from a deprecated per-clue category mapping.
4. Customer state remains a serializable runtime value object; generation policy is not embedded in the customer instance type.
5. Existing selling, packing, and item creation behavior is unchanged.

## Design

Customer generation follows a single category-first sequence:

1. Pick a random category from all registered categories.
2. Collect all affixes scoped to that category.
3. Collect the union of all clues across every combination of those affixes.
4. Pick two distinct clues from that pool as the customer's demand tags. If the pool has fewer than 2 clues, log a developer diagnostic and pad with any globally reachable clue.
5. Look up the largest anchor shape for the chosen category.
6. Select the smallest-area customer grid preset whose dimensions meet or exceed that shape. If no preset fits, fire a developer diagnostic and use the largest preset.

Responsibility boundaries:

1. The customer runtime object owns only identity, display data, grid dimensions, demand tags, and serialization.
2. The customer generator owns random customer generation, nightly batch generation, tag sampling, and grid preset selection.
3. Affix lookup by category is owned by the affix data access layer, because it is derived from affix scope.
4. Largest shape lookup by category is owned by the anchor/data access layer, because it is derived from anchor resources.

## Sketch (non-normative)

Everything below is illustrative. Names and exact signatures should be adjusted to the codebase on contact; the key contract is the responsibility split.

### Customer entry shape

Keep `customer_entry.gd` as the runtime instance/value object:

```gdscript
# customer_entry.gd
# Runtime value object representing a single nightly customer visit.
class_name CustomerEntry
extends RefCounted

var customer_id: String = ""
var display_name: String = ""
var grid_columns: int = 2
var grid_rows: int = 2
var demand_tags: Array[String] = []

static func create(customer_id: String, display_name: String, grid_size: Vector2i, tags: Array[String]) -> CustomerEntry:
    var customer := CustomerEntry.new()
    customer.customer_id = customer_id
    customer.display_name = display_name
    customer.grid_columns = grid_size.x
    customer.grid_rows = grid_size.y
    customer.demand_tags = tags.duplicate()
    return customer

func to_dict() -> Dictionary:
    return {
        "customer_id": customer_id,
        "display_name": display_name,
        "grid_columns": grid_columns,
        "grid_rows": grid_rows,
        "demand_tags": demand_tags.duplicate(),
    }

static func from_dict(data: Dictionary) -> CustomerEntry:
    var customer := CustomerEntry.new()
    customer.customer_id = str(data.get("customer_id", ""))
    customer.display_name = str(data.get("display_name", ""))
    customer.grid_columns = int(data.get("grid_columns", 2))
    customer.grid_rows = int(data.get("grid_rows", 2))
    var raw_tags: Array = data.get("demand_tags", [])
    customer.demand_tags.assign(raw_tags.duplicate())
    return customer
```

The thin factory is allowed because it only initializes the runtime value from already-computed values. Remove customer generation constants and private generation helpers from this file. In particular, generation methods, tag vocabulary helpers, storage-entry tag extraction, biased demand selection, category selection, category demand sampling, and grid preset selection move out.

### Customer generator service

Create a stateless service for generation policy, for example `common/gameplay/service/customer_generator.gd`:

```gdscript
# customer_generator.gd
# Stateless customer generation policy for nightly customer visits.
class_name CustomerGenerator

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
    var category := _pick_category(resolved_rng)
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

static func _pick_category(rng: RandomNumberGenerator):
    var categories := CategoryRegistry.get_all_categories()
    if categories.is_empty():
        ToastManager.show_dev_error("CustomerGenerator: no categories registered")
        return null
    return categories[rng.randi() % categories.size()]

static func _sample_demand_tags(category, rng: RandomNumberGenerator) -> Array[String]:
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

static func _clue_pool_for_category(category) -> Array[String]:
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
```

This replaces the old 50/50 owned-storage bias. Storage entry tag extraction and owned-pool selection are removed unless another feature still needs them.

### Affix registry queries

Add lazy query support to the affix registry. The registry owns this because the mapping is derived from affix resources and category scope.

```gdscript
var _category_to_affixes: Dictionary = {}
var _affix_to_clue_ids: Dictionary = {}
var _affix_index_built: bool = false

func _guard_affix_query_deps() -> bool:
    if CategoryRegistry.size() == 0:
        ToastManager.show_dev_error("AffixRegistry: CategoryRegistry not loaded")
        return false
    if ClueRegistry.size() == 0:
        ToastManager.show_dev_error("AffixRegistry: ClueRegistry not loaded")
        return false
    return true

func _ensure_affix_query_index() -> void:
    if _affix_index_built:
        return
    if not _guard_affix_query_deps():
        return
    _affix_index_built = true

    var all_categories: Array = []
    for category in CategoryRegistry.get_all_categories():
        all_categories.append(category)
        _category_to_affixes[category] = []

    for affix in get_all_affixes():
        var scoped_categories: Array = []
        if affix.scope_mode == "all":
            scoped_categories.assign(all_categories)
        else:
            scoped_categories.assign(affix.category_scope)

        for category in scoped_categories:
            _category_to_affixes[category].append(affix)

        var clue_ids: Array[String] = []
        for combination in affix.combinations:
            for clue in combination.surface_clues + combination.hidden_clues:
                if clue.clue_id not in clue_ids:
                    clue_ids.append(clue.clue_id)
        _affix_to_clue_ids[affix] = clue_ids

func get_affixes_for_category(category) -> Array:
    _ensure_affix_query_index()
    return _category_to_affixes.get(category, []).duplicate()

func get_clue_ids_for_affix(affix) -> Array[String]:
    _ensure_affix_query_index()
    return _affix_to_clue_ids.get(affix, []).duplicate()

func get_all_combination_clue_ids() -> Array[String]:
    _ensure_affix_query_index()
    var result: Array[String] = []
    for clue_ids: Array[String] in _affix_to_clue_ids.values():
        for clue_id in clue_ids:
            if clue_id not in result:
                result.append(clue_id)
    return result
```

The query methods take resource references rather than ids. String ids remain appropriate for serialization boundaries only.

### Anchor registry query

Add category largest-anchor-size lookup to `AnchorRegistry` in `global/autoloads/registries/anchor_registry.gd`. The registry owns this query because it is derived from loaded `AnchorData` resources, and the result is a bounding-box size rather than a shape resource.

```gdscript
var _largest_anchor_size_for_category: Dictionary = {}
var _largest_anchor_size_index_built: bool = false

func _ensure_largest_anchor_size_index() -> void:
    if _largest_anchor_size_index_built:
        return
    _largest_anchor_size_index_built = true

    for category in CategoryRegistry.get_all_categories():
        var max_width := 1
        var max_height := 1
        for anchor in get_all_anchors():
            if anchor.category_data != category:
                continue

            var cells := CargoShapes.get_cells(anchor.shape_id)
            var width := 0
            var height := 0
            for cell in cells:
                width = maxi(width, cell.x + 1)
                height = maxi(height, cell.y + 1)

            var rotated_width := mini(width, height)
            var rotated_height := maxi(width, height)
            if rotated_width > max_width or rotated_height > max_height:
                max_width = rotated_width
                max_height = rotated_height

        _largest_anchor_size_for_category[category] = Vector2i(max_width, max_height)

func get_largest_anchor_size_for_category(category: CategoryData) -> Vector2i:
    if category == null:
        ToastManager.show_dev_error("AnchorRegistry: category is null")
        return Vector2i(1, 1)
    _ensure_largest_anchor_size_index()
    return _largest_anchor_size_for_category.get(category, Vector2i(1, 1))
```

### Call-site migration

Replace calls to customer static generation with the service:

```gdscript
var customer := CustomerGenerator.generate(resolved_rng)
var customers := CustomerGenerator.generate_for_night(count, resolved_rng)
```

If the old call sites passed storage items only for match-biased tag generation, remove that argument at the same time.

### Migration order

1. Add affix registry category/clue query helpers.
2. Add anchor/data largest-shape query helper.
3. Add the customer generator service with category-first generation.
4. Move grid preset constants and default nightly-count constants from the customer entry into the generator service.
5. Replace customer generation call sites to use the generator service.
6. Remove generation methods and private generation helpers from the customer entry.

## Non-Goals

1. Existing selling scenes and packing behavior are untouched; they read the resulting customer dimensions and demand tags.
2. The deprecated per-clue category mapping is not restored; category reachability comes from affix scope instead.
3. No cross-category customer grid sizing; each generated customer is anchored to one selected category.
4. No owned-storage match bias; demand comes from the selected category's affix-reachable clue pool.

## Acceptance Criteria

1. A generated customer whose selected category has only small anchors gets a small fitting grid, never a grid expanded for unrelated categories.
2. A generated customer whose selected category has a large anchor gets a grid large enough for that anchor.
3. A generated customer's demand tags contain exactly two clues drawn from affix combinations scoped to the selected category, except for diagnostic fallback padding when the selected category has fewer than two reachable clues.
4. Customer saved data still round-trips without generation policy dependencies.
5. When no grid preset fits the required dimensions, a developer diagnostic fires and the largest preset is assigned without crashing the game.
