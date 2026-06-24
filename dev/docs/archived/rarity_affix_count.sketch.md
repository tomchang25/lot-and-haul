# Rarity-Driven Affix Count

## Goal

Rehook rarity as a generation input so that rarity controls how many affixes are drawn per item, replacing the current fixed "always ≥1 prefix + 30% chance of a second" logic. This makes `LotData.rarity_weights` meaningful again and gives designers a direct knob for item complexity: more affixes mean more clue-combination layers for the player to discover and reason about.

## Requirements

1. Rarity is drawn first from `LotData.rarity_weights` before affix drawing, so lot-authoring directly controls the complexity spread.
2. Rarity determines affix count: COMMON → 1 affix, RARE → 2 affixes, LEGENDARY → 3 affixes.
3. UNCOMMON and EPIC remain in the enum and all lookup tables but are not drawn — frozen for future use without breaking saves or data.
4. The affix draw continues to enforce that at most one affix occupies the suffix naming slot and that two affixes sharing an excluded group are never paired.
5. Rarity becomes a stored field on the item entry (not derived from hidden clue count), so rarity-based decisions in storage costs, XP gain, sorting, and UI are stable regardless of which combination is picked.
6. `LotData.rarity_weights` on lot cards now accurately reflects the lot's actual generated output; the mismatch between lot UI and generation is resolved.

## Design

### Rarity as affix layer budget

Each rarity tier translates to a fixed affix count:

| Rarity    | Affix count | Meaning                                                                   |
| --------- | ----------- | ------------------------------------------------------------------------- |
| COMMON    | 1           | One observable trait layer; simple item                                   |
| RARE      | 2           | Two layered traits; more clues to assess and cross-reference              |
| LEGENDARY | 3           | Three layered traits; the most complex items with the widest clue surface |

UNCOMMON and EPIC are not deleted — their enum values, translation keys, and lookup-table entries remain — but no generation path draws them. This preserves save compatibility and leaves room to re-introduce intermediate tiers later without a schema migration.

### Draw order

The reversed draw order changes from:

```
category → anchor → affixes (≥1 prefix, ≤2 total) → combinations → clues
```

to:

```
lot draws rarity → category → anchor → affixes (count = rarity) → combinations → clues
```

Rarity is drawn once per item slot, from the lot's `rarity_weights` dictionary. A weight of zero for a tier means that tier never appears for that lot. If all weights are zero, the draw falls back to COMMON.

### Conflicts and fallback

Higher rarity means more affixes, which makes excluded-group conflicts more likely. When drawing N affixes and no compatible set exists:

1. Retry with a different affix pick (up to a ceiling, e.g. 5 attempts).
2. If still unresolved, drop the most recently drawn affix and retry with N-1.
3. If even a single compatible affix cannot be drawn, the slot produces a COMMON item with 1 affix.

The existing conflict-insurance path that runs after combination selection (duplicate exclusive groups, double overrides) is unchanged — it already covers post-combination conflicts.

### Rarity no longer derived from hidden clues

`ItemEntry.rarity` is currently a computed getter that returns `Economy.rarity_for_clue_count(hidden_clues.size())`. After this change rarity is a stored field written once at generation time and never recomputed. Hidden clue count is free to vary per combination without accidentally re-tiering the item. This separates two concerns:

- **Rarity** = the item's structural complexity tier (how many affix layers it carries).
- **Hidden clue count** = the item's research workload (how much authentication effort it requires).

### XP, storage costs, and sorting

All downstream rarity consumers continue to read `ItemEntry.rarity` — they do not need to know how rarity was assigned. The existing `Economy.RARITY_XP_MULT`, `RARITY_SORT_WEIGHT`, and storage cost factors remain unchanged. The only difference is the source of the rarity value: a stored field set at generation instead of derived from hidden clue count.

## Sketch (non-normative)

All names and signatures below are illustrative; the codebase wins every disagreement.

### 1. New rarity draw in the lot entry factory

```
# lot_entry.gd — inside LotEntry.create(), per item slot

var rarity := _draw_rarity(data, rng)   # new step
var item_entry := ItemGenerator.draw(
    category,
    data.tier_weights,
    rarity,                             # new param
    rng,
)
```

The rarity-draw helper mirrors the existing weighted-pick pattern:

```
static func _draw_rarity(data: LotData, rng) -> Economy.Rarity:
    var active: Dictionary = {}
    for key in data.rarity_weights:
        if (data.rarity_weights[key] as int) > 0:
            active[key] = data.rarity_weights[key]
    if active.is_empty():
        return Economy.Rarity.COMMON
    var keys: Array = active.keys()
    var values: Array[int] = []
    for k in keys:
        values.append(active[k])
    var idx := RandomUtils.pick_weighted_index(values, rng)
    if idx < 0:
        return Economy.Rarity.COMMON
    return int(keys[idx]) as Economy.Rarity
```

### 2. Affix count table

```
# economy.gd or a new ItemGenerator constant

const RARITY_AFFIX_COUNT: Dictionary = {
    Economy.Rarity.COMMON: 1,
    Economy.Rarity.RARE: 2,
    Economy.Rarity.LEGENDARY: 3,
}
```

UNCOMMON and EPIC are intentionally absent from this table.

### 3. New affix draw with count parameter

The current `_draw_affixes(category, rng)` becomes `_draw_affixes(category, count, rng)`. The "always ≥1 prefix" safety net is replaced by the count parameter, which is guaranteed ≥1 by the caller.

```
static func _draw_affixes(category: CategoryData, count: int, rng) -> Array[AffixData]:
    # Build the full candidate pool as before.
    var candidates := _build_candidate_pool(category)

    # Draw at least one prefix.
    var prefix_pool := candidates.filter(func(a): return a.naming_slot == "prefix")
    if prefix_pool.is_empty():
        return []  # caller handles

    var chosen: Array[AffixData] = [_weighted_pick(prefix_pool, rng)]

    # Draw remaining slots one at a time.
    while chosen.size() < count:
        var next := _draw_compatible_affix(candidates, chosen, rng)
        if next == null:
            break  # fallback: fewer affixes than requested
        chosen.append(next)

    return chosen
```

The `_draw_compatible_affix` helper filters candidates against the already-chosen set:

- Exclude the already-chosen affix itself.
- Reject if it shares an `excluded_affix_group` with any chosen affix.
- Reject if it is a suffix and a suffix is already chosen.
- Weight-pick from the remaining pool.

If no compatible affix exists, return null.

### 4. `ItemGenerator.draw()` signature change

From:

```
static func draw(category, tier_weights, rng) -> ItemEntry
```

To:

```
static func draw(category, tier_weights, rarity, rng) -> ItemEntry
```

Inside draw:

```
var affix_count := RARITY_AFFIX_COUNT.get(rarity, 1)
var affixes := _draw_affixes(category, affix_count, resolved_rng)
# ... combinations, conflict resolution, assembly as before ...
entry.rarity = rarity   # stored field, not computed
```

### 5. ItemEntry.rarity becomes a stored field

From:

```
var rarity: Economy.Rarity:
    get:
        return Economy.rarity_for_clue_count(hidden_clues.size())
```

To:

```
var rarity: Economy.Rarity = Economy.Rarity.COMMON
```

A save migration adds the field for existing items, defaulting to the current computed value so old saves retain their rarity tier:

```
# During from_dict():
if not d.has("rarity"):
    entry.rarity = Economy.rarity_for_clue_count(entry.hidden_clues.size())
else:
    entry.rarity = int(d["rarity"])

# to_dict() adds:
d["rarity"] = rarity
```

### 6. Removals

- Remove `SECOND_AFFIX_CHANCE` constant from ItemGenerator.
- Remove the `_draw_affixes` second-affix-optional block (the `SECOND_AFFIX_CHANCE` roll and `second_pool` logic).
- `LotData.rarity_weights` gains a corrected doc comment reflecting its new role as the primary rarity input.
- `_draw_rarity` respects only the three active tiers; UNCOMMON and EPIC weights are ignored even if authored.

### 7. Migration steps (ordered)

1. Add `RARITY_AFFIX_COUNT` lookup to Economy or ItemGenerator.
2. Replace `ItemEntry.rarity` computed getter with a stored field; add save round-trip.
3. Write `_draw_rarity` helper in LotEntry.
4. Change `ItemGenerator.draw()` to accept and propagate rarity.
5. Rewrite `_draw_affixes` to accept a count parameter.
6. Remove `SECOND_AFFIX_CHANCE` and the old optional-second logic.
7. Update `LotEntry.create()` to draw rarity before calling `ItemGenerator.draw()`.
8. Update test data (`_test_item_generator.yaml`) to include RARE/LEGENDARY test combinations.
9. Update existing test call sites in `test_run_manager.gd`.

## Non-Goals

1. Do not add rarity-scoped combination filtering (e.g. LEGENDARY-only combinations) — that is future work.
2. Do not delete UNCOMMON/EPIC from the enum, lookup tables, or translation keys.
3. Do not change the existing conflict-resolution step that runs after combination selection.
4. Do not change the lot card UI beyond correcting the rarity range display — it already reads `rarity_weights`.
5. Do not change the hidden-clue count, verify logic, or research mechanics.

## Acceptance Criteria

1. A lot authored with `rarity_weights: { 0: 0, 2: 100 }` produces only RARE items (2 affixes each); a lot with `{ 0: 100 }` produces only COMMON items (1 affix).
2. A lot authored with `{ 4: 100 }` produces LEGENDARY items (3 affixes) when the category has at least 3 compatible affixes; if it has fewer, the item falls back to fewer affixes.
3. Old save files load with `ItemEntry.rarity` set to the hidden-clue-count equivalent; new items store and load rarity as a persistent field.
4. Lot card rarity range display matches the generated items — a lot labeled "Rare" actually produces RARE items.
5. XP gains, storage repair/restore factors, and sort order continue to scale with rarity.
6. Two items with the same affix count but different hidden clue counts retain their assigned rarity tier — hidden clue count does not re-tier the item.
7. Existing tests pass with updated call signatures; new test coverage verifies the rarity→affix-count mapping for all three active tiers.
