# Collapse ItemGenerator / ItemEntry Factory Split

## Goal

Eliminate the two-phase item-generation pipeline (`ItemGenerator.draw()` → `GenerationResult` → `ItemEntry.from_generation()`) so there is a single entry point for creating items. `ItemGenerator.draw()` returns `ItemEntry` directly; `GenerationResult` and `ItemEntry.from_generation()` are deleted. All callers — production, tests, and fixtures — go through `ItemGenerator`.

Test data is authored as YAML and built through the standard YAML → tres pipeline (`yaml_to_tres.py`). No in-memory fakes (`_make_anchor()`, `_make_clue()`, etc.) or hand-constructed entries.

## Background

The current pipeline has two steps that are always paired in production (`LotEntry.create()` calls both back-to-back) and never paired in tests/fixtures (which call `from_generation()` directly with hand-picked parts). `GenerationResult` is a pass-through bag-of-fields that maps 1:1 to `from_generation()`'s parameters — it adds no abstraction. The split means tests stub data mid-pipeline, never exercising the real generator logic (affix draws, conflict resolution, tier-weight picks).

Tests currently construct in-memory anchors/clues/categories via `_make_*()` helpers that exist only in the test file — they are not registered in any registry and bypass the YAML pipeline entirely. This means `ItemGenerator.draw()` (which reads from registries) cannot be used in tests without an alternative test-data strategy.

## Design

### `ItemGenerator.draw()` returns `ItemEntry`

The `draw()` function absorbs the assembly logic currently in `ItemEntry.from_generation()`:

- After drawing anchor, affixes, and clues, it creates `ItemEntry.new()` directly
- Rolls `condition` (uniform 0.0–1.0) and `center_offset` (uniform –0.5–0.5)
- Sets `unveiled = false`
- Returns `ItemEntry` (null anchor → returns null, caller skips)

The internal `_resolve_conflicts()` helper operates on local variables (affixes, surface_clues, hidden_clues, combination_ids) instead of a `GenerationResult` object.

`ItemGenerator` remains a Service (stateless, no mutable state). It reads from registries and returns a runtime Entry — the same pattern `LotEntry.create()` already follows.

### Delete `GenerationResult`

The nested class is removed. No callers reference it after the refactor.

### Delete `ItemEntry.from_generation()`

All callers migrate to `ItemGenerator.draw()`:

| Caller                                         | Current                                                | After                               |
| ---------------------------------------------- | ------------------------------------------------------ | ----------------------------------- |
| `LotEntry.create()`                            | `ItemGenerator.draw()` + `ItemEntry.from_generation()` | `ItemGenerator.draw()` only         |
| `test/unit/test_run_manager.gd` (6 call sites) | `ItemEntry.from_generation(anchor, clues, ...)`        | `ItemGenerator.draw(category, ...)` |
| `game/meta/storage/storage_fixtures.gd`        | `ItemEntry.from_generation(anchor, clues, ...)`        | `ItemGenerator.draw(category, ...)` |

### Test data as YAML — the standard port

Tests must not construct in-memory stub resources (`_make_anchor()`, `_make_clue()`, `_make_category()`) or inject fake data into registries. Instead, test data is authored as a YAML file under `data/yaml/` (the single YAML source directory), run through the standard `yaml_to_tres.py` pipeline, and loaded by the same registries production uses.

**Why this approach:**

- Tests exercise the exact same resource-loading path as production — same registries, same `ResourceDirLoader`, same `.tres` format
- The `ItemGenerator.draw()` function reads from registries natively, so no shim or adapter layer is needed
- Adding test data to `data/yaml/` is zero-cost — the pipeline already scans `**/*.yaml` recursively from that directory
- The `--force` flag regenerates all `.tres` from all YAML sources, including test data
- Test data is committed alongside production YAML (prefixed distinctively, e.g. `_test_item_generator.yaml`) and is version-controlled

**What goes in the test YAML:**

- One super-category, one category (minimal — enough for a category_scope reference)
- One anchor (base_value 100, tier 1, shape_id s1x1)
- Two surface clues (one easy dc=5, one hard dc=19, both "add" effect_op)
- One hidden clue (dc=15, "mul" effect_op)
- Zero affixes (plain-item baseline is the only path tests exercise)
- All clues use a dedicated `domain` matching the test category so they don't leak into production pool draws

Test IDs are prefixed with `test_` to avoid any collision with production data:

```
super_category_id: test_super
category_id: test_category
anchor_id: test_anchor_01
clue_id: test_surface_easy, test_surface_hard, test_hidden_gem
```

**Build step:** Before running tests, run `python3 dev/tools/yaml_to_tres.py --godot-root /workspace --force` to regenerate all `.tres` from YAML (production + test data together). This is part of the test bootstrap — see the concept doc `dev/standards/test_data.md` for the full workflow.

### Fixture migration

`storage_fixtures.gd` currently samples clues manually via `_sample_clues()` then calls `from_generation()`. After the refactor, it calls `ItemGenerator.draw()` with a category from the production registries. The fixture uses a seeded RNG for deterministic visual output. `_sample_clues()` is deleted.

### Test changes

The existing `_make_*()`, `_seed_rng()`, and all `ItemEntry.from_generation()` call sites in `test_run_manager.gd` are removed. Tests construct a `LotData` with appropriate weights, then call `ItemGenerator.draw()` with the test category and a seeded RNG. The generator selects from the test anchor and test clues registered in the data pipeline.

To test specific clue mechanics (`attempt_clue` hit/miss), tests modify the returned `ItemEntry` directly — calling `entry.unveil()` and `entry.attempt_clue()` on the live entry. The anchor and clues on the entry come from the generator draw, not from hand-picked objects.

## Non-normative code

### `item_generator.gd` (after)

```gdscript
# item_generator.gd
# Stateless draw-time item generator. Returns a fully-formed ItemEntry.
class_name ItemGenerator
extends RefCounted

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

    var anchor := _draw_anchor(category, tier_weights, resolved_rng)
    if anchor == null:
        return null

    var affixes := _draw_affixes(category, resolved_rng)
    var surface_clues: Array[ClueData] = []
    var hidden_clues: Array[ClueData] = []
    var combination_ids: Array[String] = []

    if not affixes.is_empty():
        for affix in affixes:
            var combination := _pick_combination(affix, resolved_rng)
            if combination == null:
                continue
            combination_ids.append(combination.combination_id)
            surface_clues.append_array(combination.surface_clues)
            hidden_clues.append_array(combination.hidden_clues)
        var resolved := _resolve_conflicts(
            affixes, combination_ids, surface_clues, hidden_clues, resolved_rng,
        )
        affixes = resolved.affixes
        combination_ids = resolved.combination_ids
        surface_clues = resolved.surface_clues
        hidden_clues = resolved.hidden_clues
    else:
        var surface_count := clampi(
            resolved_rng.randi_range(surface_min, surface_max), 1, 8,
        )
        surface_clues = _draw_surface_clues(category, surface_count, resolved_rng)

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
```

### `_resolve_conflicts` signature change

```gdscript
static func _resolve_conflicts(
        affixes: Array[AffixData],
        combination_ids: Array[String],
        surface_clues: Array[ClueData],
        hidden_clues: Array[ClueData],
        rng: RandomNumberGenerator,
) -> Dictionary:
    # ... returns { affixes, combination_ids, surface_clues, hidden_clues }
```

### `lot_entry.gd` (after)

```gdscript
    for i in range(item_count):
        var category := _draw_category(data, rng)
        if category == null:
            continue

        var item_entry := ItemGenerator.draw(
            category, data.tier_weights,
            Economy.SURFACE_CLUE_MIN, Economy.SURFACE_CLUE_MAX, rng,
        )
        if item_entry == null:
            continue

        if data.veiled_chance < 1.0 and (rng.randf() if rng else randf()) > data.veiled_chance:
            item_entry.unveiled = true
        entry.item_entries.append(item_entry)
```

### `item_entry.gd` (after)

The `from_generation()` static factory and the `# ══ Factory ══` section are deleted. `PriceView` and all other code is unchanged.

### test data YAML (`data/yaml/_test_item_generator.yaml`)

```yaml
super_categories:
  - super_category_id: test_super
    display_name: Test

categories:
  - category_id: test_category
    super_category: test_super
    display_name: Test Category

anchors:
  - anchor_id: test_anchor_01
    known_text: Test Box
    category_scope: test_category
    base_value: 100
    shape_id: s1x1
    weight_kg: 1.0
    tier: 1

clues:
  - clue_id: test_surface_easy
    known_text: Easy
    type: surface
    domain: test_category
    attribute: appraisal
    dc: 5
    effect_op: add
    effect_amount: 50
  - clue_id: test_surface_hard
    known_text: Hard
    type: surface
    domain: test_category
    attribute: appraisal
    dc: 19
    effect_op: add
    effect_amount: 100
  - clue_id: test_hidden_gem
    known_text: Hidden Gem
    type: hidden
    domain: test_category
    attribute: investigation
    dc: 15
    effect_op: mul
    effect_amount: 2.0
```

## Migration steps

1. Create `dev/standards/test_data.md` — concept doc describing the test-data-as-YAML workflow.
2. Create `data/yaml/_test_item_generator.yaml` with test super-category, category, anchor, and clues.
3. Run `python3 dev/tools/yaml_to_tres.py --godot-root /workspace --force` to generate `.tres` for test data alongside production data.
4. Rewrite `ItemGenerator.draw()` to return `ItemEntry` — absorb assembly, delete `GenerationResult`, refactor `_resolve_conflicts`.
5. Update `LotEntry.create()` — remove `from_generation()` call, check `item_entry == null`.
6. Delete `ItemEntry.from_generation()` and its factory section.
7. Migrate `test_run_manager.gd` — remove all `_make_*()` helpers, replace with `ItemGenerator.draw()` against test data with seeded RNG.
8. Migrate `storage_fixtures.gd` — replace `from_generation()` + `_sample_clues()` with `ItemGenerator.draw()`, use seeded RNG.
9. Run the GUT unit suite and CI smoke test to verify.

## Acceptance criteria

1. `ItemGenerator.draw()` returns a fully-formed `ItemEntry` (or null) — no `GenerationResult`.
2. `GenerationResult` does not exist anywhere in the codebase.
3. `ItemEntry.from_generation()` does not exist anywhere in the codebase.
4. `LotEntry.create()` calls `ItemGenerator.draw()` exactly once per item slot.
5. Tests in `test_run_manager.gd` use `ItemGenerator.draw()` and pass.
6. No `_make_anchor()`, `_make_clue()`, or `_make_category()` helpers remain in test code.
7. Storage fixtures produce deterministic items with seeded RNG and use production registries.
8. `dev/standards/test_data.md` describes the test-data-as-YAML workflow.
