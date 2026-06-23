# item_generator.gd
# Stateless draw-time item generator: assembles an item from category, anchor,
# affixes (prefix/suffix), and combination-sourced clues using the reversed
# draw order. Called by LotEntry.create() — no side effects, no persistent state.
class_name ItemGenerator
extends RefCounted

# Probability threshold for drawing a second affix (0.0–1.0).
# A random roll ≤ this threshold triggers the second-affix draw.
const SECOND_AFFIX_CHANCE: float = 0.3


## Draws one item from the reversed draw order:
##   category → anchor → affixes (≥1 prefix, ≤2 total, ≤1 suffix)
##   → one weighted combination per affix (category-scope filtered)
##   → that combination's clues.
##
## [param rng] — optional seedable RNG for deterministic generation.
## When null, falls back to RandomUtils' shared production RNG.
## Returns a fully-formed ItemEntry (null anchor means the slot should be skipped).
static func draw(
        category: CategoryData,
        tier_weights: Dictionary,
        rng: RandomNumberGenerator = null,
) -> ItemEntry:
    var resolved_rng := RandomUtils.resolve_rng(rng)

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
    for affix: AffixData in affixes:
        var combination := _pick_combination(affix, category, resolved_rng)
        if combination == null:
            continue
        combination_ids.append(combination.combination_id)
        surface_clues.append_array(combination.surface_clues)
        hidden_clues.append_array(combination.hidden_clues)

    # ── 4. Draw-time conflict insurance ──────────────────────────────
    if not affixes.is_empty():
        var resolved := _resolve_conflicts(
            affixes,
            combination_ids,
            surface_clues,
            hidden_clues,
            category,
            resolved_rng,
        )
        affixes = resolved.affixes
        combination_ids = resolved.combination_ids
        surface_clues = resolved.surface_clues
        hidden_clues = resolved.hidden_clues

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


## Draws ≥1 prefix, ≤2 total, ≤1 suffix affixes for [param category].
## Phase 2 rules:
## - Always draw at least 1 prefix.
## - Optionally draw a second affix (prefix or suffix, not already drawn).
## - Two affixes are rejected if they share an excluded_affix_groups entry.
## Falls back to single-prefix if no compatible pair is found.
static func _draw_affixes(category: CategoryData, rng: RandomNumberGenerator) -> Array[AffixData]:
    var all_affixes: Array[AffixData] = AffixRegistry.get_all_affixes()
    var candidates: Array[AffixData] = []
    for a: AffixData in all_affixes:
        if _affix_matches_category(a, category):
            candidates.append(a)

    var total_weight := 0
    for a: AffixData in candidates:
        total_weight += maxi(a.weight, 0)

    if total_weight <= 0 or candidates.is_empty():
        # Should not happen with a populated registry, but guard anyway.
        ToastManager.show_dev_error("ItemGenerator: no eligible affixes for category '%s'" % category.category_id)
        return []

    # ── Draw 1 prefix (mandatory) ─────────────────────────────────
    var prefix_pool: Array[AffixData] = []
    for a: AffixData in candidates:
        if a.naming_slot == "prefix":
            prefix_pool.append(a)

    var first: AffixData
    if prefix_pool.is_empty():
        ToastManager.show_dev_error("ItemGenerator: no prefix affixes for category '%s'" % category.category_id)
        return []

    var prefix_total := 0
    for a: AffixData in prefix_pool:
        prefix_total += maxi(a.weight, 0)
    var first_roll := rng.randi_range(1, prefix_total) if prefix_total > 0 else 1
    var cumulative := 0
    for a: AffixData in prefix_pool:
        cumulative += maxi(a.weight, 0)
        if first_roll <= cumulative:
            first = a
            break
    if first == null:
        first = prefix_pool[rng.randi() % prefix_pool.size()]

    var chosen: Array[AffixData] = [first]

    # ── Optionally draw a 2nd affix ────────────────────────────────
    var second_pool: Array[AffixData] = []
    for a: AffixData in candidates:
        if a == first:
            continue
        # At most 1 suffix total
        if a.naming_slot == "suffix" and first.naming_slot == "suffix":
            continue
        # Check compatibility via excluded_affix_groups
        if _affixes_are_compatible(first, a):
            second_pool.append(a)

    if not second_pool.is_empty() and rng.randf() <= SECOND_AFFIX_CHANCE:
        var second_total := 0
        for a: AffixData in second_pool:
            second_total += maxi(a.weight, 0)
        var second_roll := rng.randi_range(1, second_total) if second_total > 0 else 1
        var second_cumulative := 0
        for a: AffixData in second_pool:
            second_cumulative += maxi(a.weight, 0)
            if second_roll <= second_cumulative:
                chosen.append(a)
                break

    return chosen


static func _affix_matches_category(affix: AffixData, category: CategoryData) -> bool:
    if affix.scope_mode == "all":
        return true
    if affix.scope_mode == "categories":
        return category in affix.category_scope
    return false


## Returns true if two affixes can co-occur. They are compatible when they
## share no overlapping excluded_affix_groups entries.
static func _affixes_are_compatible(a: AffixData, b: AffixData) -> bool:
    if a.excluded_affix_groups.is_empty() or b.excluded_affix_groups.is_empty():
        return true
    for group_a in a.excluded_affix_groups:
        for group_b in b.excluded_affix_groups:
            if group_a == group_b:
                return false
    return true


## Weight-picks one combination from [param affix]'s combinations array,
## filtered by [param category] via combination-level category_scope.
## Returns null if the affix has no eligible combinations.
static func _pick_combination(affix: AffixData, category: CategoryData, rng: RandomNumberGenerator) -> AffixCombinationData:
    var eligible: Array[AffixCombinationData] = []
    for c: AffixCombinationData in affix.combinations:
        if _combination_matches_category(c, category):
            eligible.append(c)

    if eligible.is_empty():
        ToastManager.show_dev_error("Affix '%s' has no combination matching category '%s'" % [affix.affix_id, category.category_id])
        return null

    var weights: Array[int] = []
    for c: AffixCombinationData in eligible:
        weights.append(maxi(c.weight, 0))

    var idx := RandomUtils.pick_weighted_index(weights, rng)
    if idx < 0 or idx >= eligible.size():
        return eligible[rng.randi() % eligible.size()]
    return eligible[idx]


## Returns true if the combination is eligible for the given category.
## Empty category_scope = universal (all categories). Populated = membership check.
static func _combination_matches_category(combo: AffixCombinationData, category: CategoryData) -> bool:
    if combo.category_scope.is_empty():
        return true
    return category in combo.category_scope


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
        category: CategoryData,
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

    var affixes_out: Array[AffixData] = affixes.duplicate()
    var combination_ids_out: Array[String] = combination_ids.duplicate()
    var surface_clues_out: Array[ClueData] = surface_clues.duplicate()
    var hidden_clues_out: Array[ClueData] = hidden_clues.duplicate()

    # Attempt 1: re-pick a combination for each affix in order.
    var max_retries := 5
    for attempt in range(max_retries):
        for affix_idx in range(affixes_out.size()):
            var affix: AffixData = affixes_out[affix_idx]
            var new_comb := _pick_combination(affix, category, rng)
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

    # Last resort: return empty clues.
    ToastManager.show_dev_error("ItemGenerator: could not resolve affix conflict — falling back to empty item")
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
