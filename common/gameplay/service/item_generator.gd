# item_generator.gd
# Stateless draw-time item generator: assembles an item from category, anchor,
# affixes (prefix/suffix), and combination-sourced clues using the reversed
# draw order. Called by LotEntry.create() — no side effects, no persistent state.
class_name ItemGenerator
extends RefCounted

## Draws one item from the reversed draw order:
##   category → anchor → affixes (0–1 prefix + 0–1 suffix)
##   → one weighted combination per affix → that combination's clues.
##
## When no affix is drawn, falls back to the plain-item baseline:
## surface clues from the generic pool and zero hidden clues.
##
## [param rng] — optional seedable RNG for deterministic generation.
## When null, creates a fresh randomized RNG (production path).
## Returns a fully-formed ItemEntry (null anchor means the slot should be skipped).
static func draw(
        category: CategoryData,
        tier_weights: Dictionary,
        surface_min: int,
        surface_max: int,
        rng: RandomNumberGenerator = null,
) -> ItemEntry:
    var resolved_rng := rng
    if resolved_rng == null:
        resolved_rng = RandomNumberGenerator.new()
        resolved_rng.randomize()

    # ── 1. Anchor ────────────────────────────────────────────────────────
    var anchor := _draw_anchor(category, tier_weights, resolved_rng)
    if anchor == null:
        return null

    # ── 2. Affixes ────────────────────────────────────────────────────────
    var affixes := _draw_affixes(category, resolved_rng)

    var surface_clues: Array[ClueData] = []
    var hidden_clues: Array[ClueData] = []
    var combination_ids: Array[String] = []

    # ── 3. Combinations → clues ──────────────────────────────────────────
    if not affixes.is_empty():
        for affix: AffixData in affixes:
            var combination := _pick_combination(affix, resolved_rng)
            if combination == null:
                continue
            combination_ids.append(combination.combination_id)
            surface_clues.append_array(combination.surface_clues)
            hidden_clues.append_array(combination.hidden_clues)

        # ── 3b. Draw-time conflict insurance ──────────────────────────
        var resolved := _resolve_conflicts(
            affixes,
            combination_ids,
            surface_clues,
            hidden_clues,
            resolved_rng,
        )
        affixes = resolved.affixes
        combination_ids = resolved.combination_ids
        surface_clues = resolved.surface_clues
        hidden_clues = resolved.hidden_clues
    else:
        # ── 4. Plain-item baseline ────────────────────────────────────
        var surface_count := clampi(
            resolved_rng.randi_range(surface_min, surface_max),
            1,
            8,
        )
        surface_clues = _draw_surface_clues(category, surface_count, resolved_rng)

    # ── 5. Assemble ItemEntry ─────────────────────────────────────────
    var entry := ItemEntry.new()
    entry.anchor = anchor
    entry.surface_clues = surface_clues
    entry.hidden_clues = hidden_clues
    entry.category_data = category
    entry.affixes = affixes
    entry.combination_ids = combination_ids
    entry.condition = resolved_rng.randf()
    entry.center_offset = resolved_rng.randf_range(-0.5, 0.5)
    entry.unveiled = false
    return entry


## Picks an anchor for [param category] using [param tier_weights].
## Empty/zero tier_weights → uniform pick from all category anchors (any tier).
## Non-empty → weight-pick tier, uniform within that tier; fall back to nearest tier.
static func _draw_anchor(category: CategoryData, tier_weights: Dictionary, rng: RandomNumberGenerator) -> AnchorData:
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
        return cat_anchors[rng.randi() % cat_anchors.size()]

    # Weight-pick tier
    var tier_keys: Array = tier_weights.keys()
    var tier_values: Array[int] = []
    for k in tier_keys:
        tier_values.append(int(tier_weights[k]))
    var tier_idx := RandomUtils.pick_weighted_index(tier_values, rng)
    if tier_idx < 0:
        return cat_anchors[rng.randi() % cat_anchors.size()]

    var picked_tier: int = int(tier_keys[tier_idx])

    # Filter anchors at this tier
    var tier_anchors: Array[AnchorData] = []
    for a: AnchorData in cat_anchors:
        if a.tier == picked_tier:
            tier_anchors.append(a)

    if not tier_anchors.is_empty():
        return tier_anchors[rng.randi() % tier_anchors.size()]

    # Fall back to nearest tier, preferring lower on ties
    var best_tier: int = -1
    var best_dist: int = 999
    for t in range(1, 6):
        var dist := abs(t - picked_tier)
        if dist > best_dist:
            continue
        var has_anchor := false
        for a: AnchorData in cat_anchors:
            if a.tier == t:
                has_anchor = true
                break
        if not has_anchor:
            continue
        if dist < best_dist or (dist == best_dist and t < best_tier):
            best_dist = dist
            best_tier = t

    if best_tier < 0:
        return cat_anchors[rng.randi() % cat_anchors.size()]

    var fallback: Array[AnchorData] = []
    for a: AnchorData in cat_anchors:
        if a.tier == best_tier:
            fallback.append(a)
    return fallback[rng.randi() % fallback.size()]


## Draws 0–1 prefix and 0–1 suffix affixes for [param category].
## Each eligible affix matches scope_mode/category_scope:
## - scope_mode == "all": eligible for every category
## - scope_mode == "categories": eligible only for category_scope entries
## is rolled independently against its weight. An affix is assigned when
##   randf() * TOTAL_WEIGHT < weight
## which gives each affix a proportional chance independent of other affixes.
static func _draw_affixes(category: CategoryData, rng: RandomNumberGenerator) -> Array[AffixData]:
    var all_affixes: Array[AffixData] = AffixRegistry.get_all_affixes()
    var candidates: Array[AffixData] = []
    for a: AffixData in all_affixes:
        if _affix_matches_category(a, category):
            candidates.append(a)

    if candidates.is_empty():
        return []

    var total_weight := 0
    for a: AffixData in candidates:
        total_weight += maxi(a.weight, 0)

    if total_weight <= 0:
        return []

    var chosen: Array[AffixData] = []
    # Prefix pool (up to 1)
    var prefix_pool: Array[AffixData] = []
    for a: AffixData in candidates:
        if a.naming_slot == "prefix":
            prefix_pool.append(a)
    if not prefix_pool.is_empty():
        var roll := rng.randi_range(1, total_weight)
        var cumulative := 0
        for a: AffixData in prefix_pool:
            cumulative += maxi(a.weight, 0)
            if roll <= cumulative:
                chosen.append(a)
                break

    # Suffix pool (up to 1)
    var suffix_pool: Array[AffixData] = []
    for a: AffixData in candidates:
        if a.naming_slot == "suffix":
            suffix_pool.append(a)
    if not suffix_pool.is_empty():
        var roll := rng.randi_range(1, total_weight)
        var cumulative := 0
        for a: AffixData in suffix_pool:
            cumulative += maxi(a.weight, 0)
            if roll <= cumulative:
                # Avoid reselecting the same affix if one was already picked.
                if not chosen.has(a):
                    chosen.append(a)
                break

    return chosen


static func _affix_matches_category(affix: AffixData, category: CategoryData) -> bool:
    if affix.scope_mode == "all":
        return true
    if affix.scope_mode == "categories":
        return category in affix.category_scope
    return false


## Weight-picks one combination from [param affix]'s combinations array.
## Returns null if the affix has no combinations (should not happen with
## validated data).
static func _pick_combination(affix: AffixData, rng: RandomNumberGenerator) -> AffixCombinationData:
    if affix.combinations.is_empty():
        ToastManager.show_dev_error("Affix '%s' has no combinations" % affix.affix_id)
        return null

    var weights: Array[int] = []
    for c: AffixCombinationData in affix.combinations:
        weights.append(maxi(c.weight, 0))

    var idx := RandomUtils.pick_weighted_index(weights, rng)
    if idx < 0 or idx >= affix.combinations.size():
        return affix.combinations[rng.randi() % affix.combinations.size()]
    return affix.combinations[idx]


## Draw-time conflict insurance. If merging both affixes' clues produces a
## duplicate exclusive_group or two overrides, re-pick one affix's combination
## or (last resort) drop one affix.
##
## This should never fire on shipped data (the build-time validator catches
## all cross-product conflicts). It exists for un-revalidated/drifted data.
##
## Returns a Dictionary with keys: affixes, combination_ids, surface_clues, hidden_clues.
static func _resolve_conflicts(
        affixes: Array[AffixData],
        combination_ids: Array[String],
        surface_clues: Array[ClueData],
        hidden_clues: Array[ClueData],
        rng: RandomNumberGenerator,
) -> Dictionary:
    var conflict = _find_first_conflict(surface_clues, hidden_clues)
    if conflict == null:
        return {
            affixes = affixes,
            combination_ids = combination_ids,
            surface_clues = surface_clues,
            hidden_clues = hidden_clues,
        }

    ToastManager.show_error(
        "ItemGenerator: draw-time conflict at affix %s: %s"
        % [combination_ids, conflict],
    )

    var affixes_out: Array[AffixData] = affixes.duplicate()
    var combination_ids_out: Array[String] = combination_ids.duplicate()
    var surface_clues_out: Array[ClueData] = surface_clues.duplicate()
    var hidden_clues_out: Array[ClueData] = hidden_clues.duplicate()

    # Attempt 1: re-pick a combination for each affix in order.
    var max_retries := 5
    for attempt in range(max_retries):
        for affix_idx in range(affixes_out.size()):
            var affix: AffixData = affixes_out[affix_idx]
            var new_comb := _pick_combination(affix, rng)
            if new_comb == null:
                continue
            if new_comb.combination_id == combination_ids_out[affix_idx]:
                continue

            # Build merged set with this replacement
            var try_surface: Array[ClueData] = []
            var try_hidden: Array[ClueData] = []
            for j in range(affixes_out.size()):
                var combo_affix: AffixData = affixes_out[j]
                var comb_id: String = combination_ids_out[j] if j != affix_idx else new_comb.combination_id
                var comb := _find_combination(combo_affix, comb_id)
                if comb == null:
                    continue
                if j == affix_idx:
                    try_surface.append_array(new_comb.surface_clues)
                    try_hidden.append_array(new_comb.hidden_clues)
                else:
                    try_surface.append_array(comb.surface_clues)
                    try_hidden.append_array(comb.hidden_clues)

            if _find_first_conflict(try_surface, try_hidden) == null:
                combination_ids_out[affix_idx] = new_comb.combination_id
                surface_clues_out = try_surface
                hidden_clues_out = try_hidden
                return {
                    affixes = affixes_out,
                    combination_ids = combination_ids_out,
                    surface_clues = surface_clues_out,
                    hidden_clues = hidden_clues_out,
                }

    # Attempt 2: drop one affix entirely.
    if affixes_out.size() > 1:
        # Pick the affix that keeps the item closest to the intended clue count.
        var scores: Array[int] = []
        for affix_idx in range(affixes_out.size()):
            var comb := _find_combination(
                affixes_out[affix_idx],
                combination_ids_out[affix_idx],
            )
            scores.append(
                (comb.surface_clues.size() + comb.hidden_clues.size()) if comb != null else 0,
            )
        var best_idx := 0
        var best_score := scores[0]
        for idx in range(1, scores.size()):
            if scores[idx] > best_score:
                best_score = scores[idx]
                best_idx = idx
        var kept_comb := _find_combination(
            affixes_out[best_idx],
            combination_ids_out[best_idx],
        )
        if kept_comb != null:
            surface_clues_out = kept_comb.surface_clues.duplicate()
            hidden_clues_out = kept_comb.hidden_clues.duplicate()
        else:
            surface_clues_out = []
            hidden_clues_out = []
        affixes_out = [affixes_out[best_idx]]
        combination_ids_out = [combination_ids_out[best_idx]]
        return {
            affixes = affixes_out,
            combination_ids = combination_ids_out,
            surface_clues = surface_clues_out,
            hidden_clues = hidden_clues_out,
        }

    # Last resort: return plain-item baseline (empty clues).
    ToastManager.show_dev_error("ItemGenerator: could not resolve affix conflict — falling back to plain item")
    return {
        affixes = [],
        combination_ids = [],
        surface_clues = [],
        hidden_clues = [],
    }


## Returns the first conflict description string, or null if no conflict.
static func _find_first_conflict(
        surface_clues: Array[ClueData],
        hidden_clues: Array[ClueData],
):
    var used_groups: Dictionary = { }
    var override_count := 0
    for clue: ClueData in surface_clues + hidden_clues:
        if not clue.exclusive_group.is_empty():
            if used_groups.has(clue.exclusive_group):
                return "duplicate exclusive_group '%s'" % clue.exclusive_group
            used_groups[clue.exclusive_group] = true
        if clue.effect_op == "override":
            override_count += 1
            if override_count > 1:
                return "double override"
    return null


## Finds the combination with [param combination_id] on [param affix].
## Returns null if not found.
static func _find_combination(affix: AffixData, combination_id: String) -> AffixCombinationData:
    for c: AffixCombinationData in affix.combinations:
        if c.combination_id == combination_id:
            return c
    return null


## Draws [param count] surface clues without replacement from valid pool.
## Valid: type == SURFACE and domain is "generic" or matches category_id.
## If pool is smaller than count, takes everything.
## This is the plain-item baseline — not used on affixed items.
static func _draw_surface_clues(category: CategoryData, count: int, rng: RandomNumberGenerator) -> Array[ClueData]:
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
        var idx := rng.randi() % pool.size()
        var attempts := 0
        while idx in used and attempts < 100:
            idx = rng.randi() % pool.size()
            attempts += 1
        if idx in used:
            continue
        used.append(idx)
        chosen.append(pool[idx])
    return chosen
