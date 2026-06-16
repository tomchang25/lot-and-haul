# Plain-Item Baseline Removal

## Goal

Remove the legacy plain-item baseline path from ItemGenerator — every item must now go through the affix → combination → clues pipeline. The dead `_draw_surface_clues()` function, its `surface_min`/`surface_max` parameters, and their associated constants are cleaned up across all callers.

## Requirements

1. `ItemGenerator.draw()` no longer accepts `surface_min`/`surface_max` parameters — the plain-item baseline `else` branch is removed and replaced with a dev-error toast if it somehow fires.
2. `_draw_surface_clues()` is removed — no callers remain after the baseline branch is deleted.
3. All existing callers of `ItemGenerator.draw()` are updated to match the new signature: `LotEntry.create()`, all unit tests, and `StorageFixtures.seed_storage_state()`.
4. `Economy.SURFACE_CLUE_MIN` and `Economy.SURFACE_CLUE_MAX` are removed — they were only referenced by the now-removed baseline path.

## Design

No behavioral change to items that go through affixes — the `if not affixes.is_empty()` branch is untouched. The only difference is that the `else` branch (no affix drawn) now logs a dev-error toast instead of silently generating surface clues from the generic pool. This is safe because the production `_draw_affixes()` always returns at least one affix when the registry is populated; the else branch only fires on empty registry data, a programmer error.

## Sketch (non-normative)

**Files to change (6):**

```
common/gameplay/service/item_generator.gd      # draw() params + else branch + _draw_surface_clues
common/gameplay/instance/lot_entry.gd           # caller params
test/unit/test_run_manager.gd                   # 6 callers
game/meta/storage/storage_fixtures.gd           # caller params
global/constants/economy.gd                     # SURFACE_CLUE_MIN/MAX
dev/docs/plans/plain_item_baseline_removal.sketch.md  # this file
TODO.md                                         # Active entry
```

**Signature change (item_generator.gd:18-24):**

```gdscript
# Before:
static func draw(category, tier_weights, surface_min, surface_max, rng = null)

# After:
static func draw(category, tier_weights, rng = null)
```

**Else branch (item_generator.gd:61-68):**

```gdscript
# Before:
else:
    var surface_count := clampi(
        resolved_rng.randi_range(surface_min, surface_max), 1, 8,
    )
    surface_clues = _draw_surface_clues(category, surface_count, resolved_rng)

# After:
else:
    ToastManager.show_dev_error(
        "ItemGenerator: plain-item baseline (no affixes) is legacy — should not reach here with populated registry"
    )
```

**_draw_surface_clues() (item_generator.gd:386-416) — remove entirely.**

**Caller pattern (lot_entry.gd, test files, storage_fixtures):**

```gdscript
# Before:
ItemGenerator.draw(cat, tier_weights, SURFACE_CLUE_MIN, SURFACE_CLUE_MAX, rng)

# After:
ItemGenerator.draw(cat, tier_weights, rng)
```

**Economy constants:**

```gdscript
# Remove:
const SURFACE_CLUE_MIN: int = 2
const SURFACE_CLUE_MAX: int = 4
```

## Non-Goals

1. No new test fixture affix/combination/clue resources — the tests already produce items that exercise the affix path when affixes exist in the registry. The `else` branch was only ever a fallback for empty-registry scenarios, which are programmer error.
2. No test-behavior changes — only signature updates.

## Acceptance Criteria

1. `ItemGenerator.draw()` compiles without `surface_min`/`surface_max` parameters.
2. `_draw_surface_clues()` does not exist in the codebase.
3. `LotEntry.create()` compiles without `Economy.SURFACE_CLUE_MIN/MAX` references.
4. All six `test_run_manager.gd` callers of `draw()` compile without extra args.
5. `StorageFixtures.seed_storage_state()` compiles without extra args.
6. `Economy.SURFACE_CLUE_MIN` and `SURFACE_CLUE_MAX` no longer exist.
7. If `_draw_affixes()` somehow returns empty (empty registry), `draw()` logs a dev-error toast and returns an item with zero clues rather than crashing.
