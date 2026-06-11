# item_generator.gd
# Stateless draw-time item generator: assembles an item from category, anchor,
# surface clues, rarity, and hidden clues using pool-based draws.
# Called by LotEntry.create() — no side effects, no persistent state.
class_name ItemGenerator
extends RefCounted

## Result of one generate call. All arrays are owned by the caller.
class GenerationResult extends RefCounted:
    var anchor: AnchorData = null
    var surface_clues: Array[ClueData] = []
    var hidden_clues: Array[ClueData] = []


## Draws one item from the configured pools.
## Returns a GenerationResult (null anchor means the slot should be skipped).
static func draw(
        category: CategoryData,
        tier_weights: Dictionary,
        rarity_weights: Dictionary,
        surface_min: int,
        surface_max: int,
) -> GenerationResult:
    var result := GenerationResult.new()

    # ── 1. Anchor ────────────────────────────────────────────────────────
    result.anchor = _draw_anchor(category, tier_weights)
    if result.anchor == null:
        return result

    # ── 2. Surface clues ─────────────────────────────────────────────────
    var surface_count := clampi(randi_range(surface_min, surface_max), 1, 8)
    result.surface_clues = _draw_surface_clues(category, surface_count)

    # ── 3. Rarity ────────────────────────────────────────────────────────
    var rarity := _pick_rarity(rarity_weights)

    # ── 4. Hidden clues ──────────────────────────────────────────────────
    result.hidden_clues = _draw_hidden_clues(category, rarity)

    return result


## Picks an anchor for [param category] using [param tier_weights].
## Empty/zero tier_weights → uniform pick from all category anchors (any tier).
## Non-empty → weight-pick tier, uniform within that tier; fall back to nearest tier.
static func _draw_anchor(category: CategoryData, tier_weights: Dictionary) -> AnchorData:
    var all_anchors: Array[AnchorData] = AnchorRegistry.get_all_anchors()
    var cat_anchors: Array[AnchorData] = []
    for a: AnchorData in all_anchors:
        if a.category_data == category:
            cat_anchors.append(a)

    if cat_anchors.is_empty():
        return null

    # Empty or all-zero tier_weights → uniform pick across all tiers.
    var has_weight := false
    for v in tier_weights.values():
        if int(v) > 0:
            has_weight = true
            break

    if not has_weight:
        return cat_anchors[randi() % cat_anchors.size()]

    # Weight-pick tier
    var tier_keys: Array = tier_weights.keys()
    var tier_values: Array[int] = []
    for k in tier_keys:
        tier_values.append(int(tier_weights[k]))
    var tier_idx := RandomUtils.pick_weighted_index(tier_values)
    if tier_idx < 0:
        return cat_anchors[randi() % cat_anchors.size()]

    var picked_tier: int = int(tier_keys[tier_idx])

    # Filter anchors at this tier
    var tier_anchors: Array[AnchorData] = []
    for a: AnchorData in cat_anchors:
        if a.tier == picked_tier:
            tier_anchors.append(a)

    if not tier_anchors.is_empty():
        return tier_anchors[randi() % tier_anchors.size()]

    # Fall back to nearest tier, preferring lower on ties
    var best_tier: int = -1
    var best_dist: int = 999
    for t in range(1, 6):
        var dist := abs(t - picked_tier)
        if dist > best_dist:
            continue
        # Check if any anchors exist at this tier
        var has := false
        for a: AnchorData in cat_anchors:
            if a.tier == t:
                has = true
                break
        if not has:
            continue
        if dist < best_dist or (dist == best_dist and t < best_tier):
            best_dist = dist
            best_tier = t

    if best_tier < 0:
        return cat_anchors[randi() % cat_anchors.size()]

    var fallback: Array[AnchorData] = []
    for a: AnchorData in cat_anchors:
        if a.tier == best_tier:
            fallback.append(a)
    return fallback[randi() % fallback.size()]


## Draws [param count] surface clues without replacement from valid pool.
## Valid: type == SURFACE and domain is "generic" or matches category_id.
## If pool is smaller than count, takes everything.
static func _draw_surface_clues(category: CategoryData, count: int) -> Array[ClueData]:
    var pool: Array[ClueData] = []
    for c: ClueData in ClueRegistry.get_all_clues():
        if c.type != ClueData.ClueType.SURFACE:
            continue
        if c.domain == "generic" or c.domain == category.category_id:
            pool.append(c)

    var actual := mini(count, pool.size())
    if actual == 0:
        return [] as Array[ClueData]
    if actual == pool.size():
        return pool.duplicate()

    var chosen: Array[ClueData] = []
    var used: Array[int] = []
    for i in range(actual):
        var idx := randi() % pool.size()
        var attempts := 0
        while idx in used and attempts < 100:
            idx = randi() % pool.size()
            attempts += 1
        if idx in used:
            continue
        used.append(idx)
        chosen.append(pool[idx])
    return chosen


## Picks a rarity value from [param rarity_weights] weighted table.
## Returns int 0–4 matching Economy.Rarity enum values.
static func _pick_rarity(rarity_weights: Dictionary) -> int:
    if rarity_weights.is_empty():
        return 0
    var keys: Array = rarity_weights.keys()
    var values: Array[int] = []
    for k in keys:
        values.append(int(rarity_weights[k]))
    var idx := RandomUtils.pick_weighted_index(values)
    if idx < 0:
        return 0
    return int(keys[idx])


## Draws [param count] hidden clues from valid pool, respecting constraints.
## Valid: type == HIDDEN and domain is "generic" or matches category_id.
## Constraints: at most one per exclusive_group, at most one override.
## If pool dries before count is met, returns what was drawn.
static func _draw_hidden_clues(category: CategoryData, count: int) -> Array[ClueData]:
    if count <= 0:
        return [] as Array[ClueData]

    var pool: Array[ClueData] = []
    for c: ClueData in ClueRegistry.get_all_clues():
        if c.type != ClueData.ClueType.HIDDEN:
            continue
        if c.domain == "generic" or c.domain == category.category_id:
            pool.append(c)

    if pool.is_empty():
        return [] as Array[ClueData]

    var chosen: Array[ClueData] = []
    var used_groups: Array[String] = []
    var has_override := false

    # Shuffle pool copy for uniform draw without replacement
    var shuffled := pool.duplicate()
    shuffled.shuffle()

    for clue: ClueData in shuffled:
        if chosen.size() >= count:
            break

        # Skip if exclusive_group already used
        if not clue.exclusive_group.is_empty() and clue.exclusive_group in used_groups:
            continue

        # Skip second override
        if clue.effect_op == "override":
            if has_override:
                continue
            has_override = true

        chosen.append(clue)
        if not clue.exclusive_group.is_empty():
            used_groups.append(clue.exclusive_group)

    return chosen
