# item_generator.gd
# Stateless draw-time item generator: assembles an item from category, anchor,
# affixes (prefix/suffix), and combination-sourced clues using the reversed
# draw order. Called by LotEntry.create() — no side effects, no persistent state.
class_name ItemGenerator
extends RefCounted

## Draws one item from the reversed draw order:
##   category → anchor → affixes (count = rarity) → one weighted combination
##   per affix (category-scope filtered) → that combination's clues.
##
## Rarity is drawn first by LotEntry, then passed here to determine affix count.
## The caller is responsible for drawing rarity from lot_data.rarity_weights.
##
## [param rng] — optional seedable RNG for deterministic generation.
## When null, falls back to RandomUtils' shared production RNG.
## Returns a fully-formed ItemEntry (null anchor means the slot should be skipped).
static func draw(
        category: CategoryData,
        tier_weights: Dictionary,
        rarity: Economy.Rarity,
        rng: RandomNumberGenerator = null,
) -> ItemEntry:
    var resolved_rng := RandomUtils.resolve_rng(rng)

    # ── 1. Anchor ────────────────────────────────────────────────────────
    var anchor := _draw_anchor(category, tier_weights, resolved_rng)
    if anchor == null:
        return null

    # ── 2. Affixes ────────────────────────────────────────────────────────
    var affix_count := Economy.RARITY_AFFIX_COUNT.get(rarity, 1) as int
    var affixes := _draw_affixes(category, affix_count, resolved_rng)

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
    entry.rarity = rarity
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


## Draws [param count] affixes for [param category] with these limits:
## - At least 1 prefix (mandatory)
## - At most 2 prefixes total
## - At most 2 suffixes total
## - No two affixes overlap in excluded_affix_groups
## Falls back to fewer affixes when the pool cannot satisfy the count.
static func _draw_affixes(category: CategoryData, count: int, rng: RandomNumberGenerator) -> Array[AffixData]:
    var all_affixes: Array[AffixData] = AffixRegistry.get_all_affixes()
    var candidates: Array[AffixData] = []
    for a: AffixData in all_affixes:
        if _affix_matches_category(a, category):
            candidates.append(a)

    if candidates.is_empty():
        ToastManager.show_dev_error("ItemGenerator: no eligible affixes for category '%s'" % category.category_id)
        return []

    # Build prefix/suffix pools.
    var prefix_candidates: Array[AffixData] = []
    var suffix_candidates: Array[AffixData] = []
    for a: AffixData in candidates:
        if a.naming_slot == "prefix":
            prefix_candidates.append(a)
        elif a.naming_slot == "suffix":
            suffix_candidates.append(a)

    if prefix_candidates.is_empty():
        ToastManager.show_dev_error("ItemGenerator: no prefix affixes for category '%s'" % category.category_id)
        return []

    # Draw 1 prefix (mandatory, always the first affix).
    var chosen: Array[AffixData] = [_weighted_pick(prefix_candidates, rng)]

    # Draw remaining affixes one at a time up to count or until no compatible pick.
    var max_attempts := 5
    while chosen.size() < count:
        var next := _draw_compatible_affix(candidates, chosen, rng, max_attempts)
        if next == null:
            break
        # Enforce slot limits.
        if next.naming_slot == "prefix" and _slot_count(chosen, "prefix") >= 2:
            continue
        if next.naming_slot == "suffix" and _slot_count(chosen, "suffix") >= 2:
            continue
        chosen.append(next)

    return chosen


## Returns the number of affixes in [param affixes] with [param slot] naming_slot.
static func _slot_count(affixes: Array[AffixData], slot: String) -> int:
    var n := 0
    for a: AffixData in affixes:
        if a.naming_slot == slot:
            n += 1
    return n


## Picks one affix compatible with all currently chosen affixes. Retries up to
## [param max_attempts] times to avoid excluded-group conflicts. Returns null
## if no compatible affix could be drawn.
static func _draw_compatible_affix(
        candidates: Array[AffixData],
        chosen: Array[AffixData],
        rng: RandomNumberGenerator,
        max_attempts: int = 5,
) -> AffixData:
    # Collect ids to exclude.
    var chosen_ids: Dictionary = { }
    for a: AffixData in chosen:
        chosen_ids[a.affix_id] = true

    var pool: Array[AffixData] = []
    for a: AffixData in candidates:
        if chosen_ids.has(a.affix_id):
            continue
        if not _affixes_are_compatible(a, chosen):
            continue
        pool.append(a)

    if pool.is_empty():
        return null

    for attempt in range(max_attempts):
        var pick := _weighted_pick(pool, rng)
        if pick == null:
            return null
        if _affixes_are_compatible(pick, chosen):
            return pick

    return null


## Checks whether [param affix] is compatible with every affix in [param chosen].
static func _affixes_are_compatible(affix: AffixData, chosen: Array[AffixData]) -> bool:
    for c: AffixData in chosen:
        if not _affix_pair_compatible(affix, c):
            return false
    return true


## Weighted random pick from [param pool].
static func _weighted_pick(pool: Array[AffixData], rng: RandomNumberGenerator) -> AffixData:
    var total := 0
    for a: AffixData in pool:
        total += maxi(a.weight, 0)
    if total <= 0:
        return pool[rng.randi() % pool.size()]
    var roll := rng.randi_range(1, total)
    var cumulative := 0
    for a: AffixData in pool:
        cumulative += maxi(a.weight, 0)
        if roll <= cumulative:
            return a
    return pool[rng.randi() % pool.size()]


static func _affix_matches_category(affix: AffixData, category: CategoryData) -> bool:
    if affix.scope_mode == "all":
        return true
    if affix.scope_mode == "categories":
        return category in affix.category_scope
    return false


## Returns true if two affixes can co-occur. They are compatible when they
## share no overlapping excluded_affix_groups entries.
static func _affix_pair_compatible(a: AffixData, b: AffixData) -> bool:
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
