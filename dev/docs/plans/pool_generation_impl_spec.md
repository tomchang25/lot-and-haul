# Pool-Based Item Generation — Implementation Spec

## Goal

Replace authored-per-item definitions with draw-time generation so items are assembled from category, anchor tier, surface clues, rarity, and hidden clues at lot-draw time. This spec covers the generator service, composition-based persistence, the legacy-to-composition migration, LotData tier control, the Rarity enum extraction, and the Python balance preview tool — across two phases, with hard ordering: Phase 1 (generator + persistence + migration + tier_weights) ships while authored ItemData still loads; Phase 2 deletes the authored data.

## Relational Context

- **Generation is a Service (stateless)**: `ItemGenerator` in `common/gameplay/service/` takes lot config params and returns a triplet `(AnchorData, Array[ClueData] surface, Array[ClueData] hidden)` — no side effects, no persistent state. Called by `LotEntry.create()` in place of the current `_draw_item()` private methods.
- **LotEntry owns the draw orchestration**: `LotEntry.create()` extracts the category draw (currently buried inside `_draw_item_by_rarity_and_category()`), then calls the generator service once per item slot. The category draw logic itself is unchanged — same weighted super-category/category path from `lot_data` → registries.
- **ItemEntry owns its definition directly**: after this change, `item_data` becomes optional (populated only during legacy load / migration), and the live fields are `anchor`, `surface_clues`, `hidden_clues`, and `category_data` held directly on the entry. The `rarity` computed property returns `hidden_clues.size()`. All existing code that reads `item_data.anchor`, `item_data.surface_clues`, `item_data.hidden_clues`, or `item_data.rarity` switches to reading the instance fields.
- **Rarity enum moves to Economy**: `ItemData.Rarity` (COMMON–LEGENDARY, values 0–4) is extracted to `Economy.Rarity` so it survives the deletion of `ItemData`. Six files reference the enum by name: `event_bus.gd` (signal params), `knowledge_manager.gd` (XP calc), `meta_manager.gd` (signal emitters), `item_entry_display_helper.gd` (text/color/sort), `research_slot.gd` (rarity factor lookup tables), and `economy.gd` itself (frozen `RESEARCH_DAYS`). All call sites switch to `Economy.Rarity`.
- **StorageStore migration is versioned inside `from_dict()`**: the current store version is 1. Phase 1 bumps it to 2. The `_apply_migrations()` branch for `from_version < 2` rewrites each serialized entry from `item_id`-based shape to composition shape by resolving the id through `ItemRegistry` (still loaded) and copying its anchor + clue lists. Migration does not touch `Economy.RESEARCH_DAYS` — that dict is frozen and stays.
- **ItemRegistry remains loaded during Phase 1**: it is NOT removed yet — the migration in Phase 1 depends on it. It's deleted only in Phase 2, after every save is guaranteed to have been migrated.
- **LotData gets `tier_weights` and keeps `item_weights` during Phase 1**: both fields coexist. `item_weights` continues to work for any lot that hasn't been updated to use the generator. Phase 2 removes `item_weights` from LotData and the YAML pipeline.
- **AnchorRegistry and ClueRegistry are already available**: `AnchorRegistry.get_all_anchors()` returns all `AnchorData` (each with `tier`, `category_data`). `ClueRegistry.get_all_clues()` returns all `ClueData` (each with `type`, `domain`, `exclusive_group`, `effect_op`, `naming_slot`). The generator service calls these without introducing new registry queries.
- **CategoryRegistry exists**: `CategoryRegistry.get_category_by_id()` — used by the generator to validate the category roll against the drawn anchor's category. SuperCategoryRegistry exists for the super-category → category dispatch path.
- **Display name composition is already anchor/clue-driven**: `ItemEntryDisplayHelper.display_name()` at `game/shared/item_display/item_entry_display_helper.gd:21` reads `get_naming_clue_pool()` which returns a mixed array of `AnchorData` and `ClueData`. After the change, `get_naming_clue_pool()` reads instance fields instead of `item_data` — the display helper itself needs no change.
- **EventBus signals carry `rarity` but NOT ItemData**: `sale_resolved(category, rarity)`, `item_repaired(category, rarity)`, `item_restored(category, rarity)` at `event_bus.gd:15–25` — the signals pass by-value types (enum + resource ref), not ItemData. Only the enum's namespace changes from `ItemData.Rarity` to `Economy.Rarity`.
- **Wrong shape to avoid**: do not create a `Rarity` class or autoload. Rarity is a pure enum — it has no associated logic beyond being an integer 0–4. Keep it in `Economy` alongside the frozen migration table that already references it.

## Plan Friction

- Settled: `ItemEntry.verified` at `item_entry.gd:43` currently null-guards through `item_data` (`item_data == null or item_data.hidden_clues.is_empty()`); it becomes `hidden_clues.is_empty()` on the instance field.
- Settled: the price pipeline needs no formula change — `_raw_appraised_value`, `appraised_with_hidden`, `full_true_value` (`item_entry.gd:141–153`, `173–186`, `193–209`) change only their data access from `item_data.xxx` to instance fields.
- Settled: `Economy.RESEARCH_DAYS` (`economy.gd:31`, frozen, migration-only) changes only its enum namespace to `Economy.Rarity`; values are untouched.
- Settled: `ResearchSlot` rarity factor tables at `research_slot.gd:13–19` and `25–31` (live constants, not frozen) switch keys to `Economy.Rarity`; `apply_repair()` (`research_slot.gd:44`) and `apply_restore()` (`research_slot.gd:57`) read `entry.rarity` instead of `entry.item_data.rarity`.
- Settled: `func category_data()` at `item_entry.gd:407` collides with the new `category_data` instance field and is deleted; internal callers at `item_entry.gd:411` and `item_entry.gd:419` switch to bare field access.
- Settled: all three `MetaManager` signal emits (`meta_manager.gd:246`, `265`, `286`) switch from `entry.item_data.category_data` / `entry.item_data.rarity` to instance fields in Phase 1 — generated items have null `item_data`.
- Settled: `KnowledgeManager._on_item_unveiled` (`knowledge_manager.gd:243–244`) and `_on_item_revealed` (`knowledge_manager.gd:248`) switch to instance fields in Phase 1, same reason.
- Settled: five files read `entry.item_data.*` directly even though the plan's non-goal #4 declares their flows unchanged — `inspection_scene.gd:569–574` (anchor, surface_clues, no null guard), `item_row_tooltip.gd:106–109` (all_clues), `storage_scene.gd:204–206, 249` (category_data, hidden_clues), `run_manager.gd:71` (unveil emit guard), `auction_scene.gd:371` (debug guard). All five switch to instance fields in Phase 1; formulas and mechanics are unchanged — only the data access path.

## Design Gaps

No outstanding design gaps — the plan fully specifies all new elements. (Two gaps were found and folded back into the Plan during review: the surface-count constants, now specified in Requirement 3, and the Phase-2 removal of the legacy `item_data` field and its null-guards, now specified in the migration phase ordering.)

## Scope

### Included (Phase 1)

- New `ItemGenerator` service in `common/gameplay/service/`
- `LotEntry.create()` rewritten to use generator instead of `_draw_item*`
- `LotData.tier_weights` field, YAML pipeline, and existing lot YAML entries
- `Economy.Rarity` enum extracted from `ItemData.Rarity`; all call sites updated
- `Economy.SURFACE_CLUE_MIN` / `Economy.SURFACE_CLUE_MAX` constants
- `ItemEntry` holds `anchor`, `surface_clues`, `hidden_clues`, `category_data` directly; `item_data` becomes optional (populated by legacy load / pre-migration entry); computed `rarity` returns `hidden_clues.size()`
- `ItemEntry.to_dict()` writes composition form (anchor id, surface/hidden clue id lists) + `item_id` during Phase 1 for migration compatibility
- `StorageStore._apply_migrations()` version-2 branch: id→composition rewrite, preserving instance state
- `ItemEntry.from_dict()` handles both legacy `item_id` shape and new composition shape
- Update `EventBus` signals, `KnowledgeManager`, `MetaManager`, `ItemEntryDisplayHelper`, `ResearchSlot` to use `Economy.Rarity`
- Python balance preview tool in `dev/tools/`

### Included (Phase 2)

- Delete `data/definitions/item_data.gd`
- Delete `data/yaml/items/*.yaml` and `data/tres/items/*.tres`
- Delete `global/autoloads/registries/item_registry.gd`
- Remove `LotData.item_weights` field; update lot YAML to drop per-item weight tables
- Remove `ItemEntry.item_data` field and all `item_data == null` guards
- Remove `item_id` key from `ItemEntry.to_dict()` / `from_dict()`
- Remove `ItemRegistry` from autoload load order
- Update `dev/tools/tres_lib/entities/lot.py` (drop `item_weights`); delete `item.py`

### Excluded

- Anchor-conditioned surface draw (uniform only)
- Tier-linked surface clue counts (global range only)
- Combination naming rules
- Changes to price formulas, inspection math, research mechanics, or selling
- Location-level tier curves
- Director system fixed-lot injection (will construct instances directly later)
- Removal of `dev/tools/tres_lib/entities/item.py` validation that cross-checks rarity == hidden count (removed in Phase 2 only)
- `Economy.RESEARCH_DAYS` changes (already frozen, irrelevant to live system)

## Files to Change

### Phase 1

| File                                                    | Change Size | Purpose                                                                                                                                                                                                                                             |
| ------------------------------------------------------- | ----------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `common/gameplay/service/item_generator.gd`             | Large (new) | Stateless draw-sequence: category → tier-weighted anchor → surface clue draw → rarity roll → constrained hidden clue draw                                                                                                                           |
| `common/gameplay/instance/lot_entry.gd`                 | Large       | Replace `_draw_item()` / `_draw_item_by_weight()` / `_draw_item_by_rarity_and_category()` with generator call; extract category-draw logic into a shared helper                                                                                     |
| `common/gameplay/instance/item_entry.gd`                | Large       | Add `anchor`, `surface_clues`, `hidden_clues`, `category_data` instance fields; make `item_data` optional; add `rarity` computed property; update `to_dict()`/`from_dict()` for both shapes; update all internal accessors to check instance fields |
| `data/definitions/lot_data.gd`                          | Small       | Add `tier_weights: Dictionary = {}`                                                                                                                                                                                                                 |
| `common/gameplay/store/storage_store.gd`                | Small       | Bump `_store_version()` to 2; add `_apply_migrations()` branch for id→composition rewrite                                                                                                                                                           |
| `global/constants/economy.gd`                           | Medium      | Extract `Rarity` enum; add `SURFACE_CLUE_MIN`/`SURFACE_CLUE_MAX`; keep frozen `RESEARCH_DAYS`                                                                                                                                                       |
| `global/autoloads/event_bus.gd`                         | Small       | Change signal param types from `ItemData.Rarity` to `Economy.Rarity`                                                                                                                                                                                |
| `global/autoloads/managers/knowledge_manager.gd`        | Small       | Change `ItemData.Rarity` → `Economy.Rarity` in signatures; switch `_on_item_unveiled`/`_on_item_revealed` from `entry.item_data.category_data`/`.rarity` to instance fields                                                                         |
| `global/autoloads/managers/meta_manager.gd`             | Small       | Switch all three signal emits from `entry.item_data.category_data`/`.rarity` to `entry.category_data`/`entry.rarity`; enum namespace change                                                                                                         |
| `global/autoloads/managers/run_manager.gd`              | Small       | Switch `unveil_item()` guard from `entry.item_data` to instance field checks                                                                                                                                                                        |
| `game/shared/item_display/item_entry_display_helper.gd` | Small       | Read `entry.rarity` and `entry.category_data` instead of `entry.item_data.rarity`/`.category_data`; update null guards                                                                                                                              |
| `common/gameplay/service/research_slot.gd`              | Small       | Change dict keys from `ItemData.Rarity` to `Economy.Rarity`; change `entry.item_data.rarity` to `entry.rarity` in `apply_repair()` and `apply_restore()`                                                                                            |
| `game/run/inspection/inspection_scene.gd`               | Small       | Switch `entry.item_data.anchor` and `entry.item_data.surface_clues` reads to instance fields                                                                                                                                                        |
| `game/shared/item_display/item_row_tooltip.gd`          | Small       | Switch `item.item_data.all_clues` to `item.all_clues` (public computed property on ItemEntry)                                                                                                                                                       |
| `game/meta/storage/storage_scene.gd`                    | Small       | Switch `entry.item_data.category_data` and `entry.item_data.hidden_clues` reads to instance fields                                                                                                                                                  |
| `game/run/auction/auction_scene.gd`                     | Small       | Switch debug `entry.item_data` guard to instance field check                                                                                                                                                                                        |
| `dev/tools/tres_lib/entities/lot.py`                    | Small       | Add `tier_weights` build/parse/validate; keep `item_weights`                                                                                                                                                                                        |
| `data/yaml/location_data.yaml`                          | Small       | Add `tier_weights` to each lot definition                                                                                                                                                                                                           |
| `dev/tools/balance_preview.py`                          | Large (new) | Python balance preview tool: simulates N draws per lot config, reports value distributions and content-health flags                                                                                                                                 |

### Phase 2

| File                                             | Change Size | Purpose                                                                          |
| ------------------------------------------------ | ----------- | -------------------------------------------------------------------------------- |
| `data/definitions/item_data.gd`                  | Delete      | Authored item type no longer used                                                |
| `data/yaml/items/*.yaml`                         | Delete      | Authored per-item sources                                                        |
| `data/tres/items/*.tres`                         | Delete      | Generated item resources                                                         |
| `global/autoloads/registries/item_registry.gd`   | Delete      | Registry no longer loaded                                                        |
| `common/gameplay/instance/item_entry.gd`         | Medium      | Remove `item_data` field, all null-guards, and migration-only serialization keys |
| `data/definitions/lot_data.gd`                   | Small       | Remove `item_weights` field                                                      |
| `dev/tools/tres_lib/entities/item.py`            | Delete      | Pipeline item spec                                                               |
| `dev/tools/tres_lib/entities/lot.py`             | Small       | Remove `item_weights` from build/parse/validate                                  |
| `data/yaml/location_data.yaml`                   | Small       | Drop all `item_weights` keys from lot definitions                                |
| `global/autoloads/managers/knowledge_manager.gd` | Small       | Remove `entry.item_data` fallback in `_on_item_unveiled`/`_on_item_revealed`     |

## Implementation Notes

### ItemGenerator (new service)

The generator is a single static method returning a struct-like result. Rough shape:

```
class ItemGeneratorResult:
    var anchor: AnchorData
    var surface_clues: Array[ClueData]
    var hidden_clues: Array[ClueData]

static func draw(category: CategoryData, tier_weights: Dictionary, rarity_weights: Dictionary,
                  surface_min: int, surface_max: int, rng_seed: int = 0) -> ItemGeneratorResult
```

Draw sequence (matching plan §Design):

1. **Anchor**: weight-pick a tier (1–5) from `tier_weights`; filter `AnchorRegistry.get_all_anchors()` to `category_data == category` and `tier == picked`; if empty, fall to nearest tier preferring lower (bisect 1–5 outward from picked tier); pick uniformly from survivors. Fail = return null anchor — caller (`LotEntry.create()`) skips the item slot.

2. **Surface clues**: roll count `randi_range(surface_min, surface_max)` clamped to `[1, 8]`. Collect valid surface pool: `ClueRegistry.get_all_clues()` filtered to `type == SURFACE` and `domain == "generic" or domain == category.category_id`. Weight-pick uniformly without replacement up to the rolled count. If pool is smaller than rolled count, take everything.

3. **Rarity**: weight-pick from `rarity_weights` (same logic as current `_draw_item_by_rarity_and_category()` — weighted index from int-keyed dict). Rarity value = number of hidden clues to draw.

4. **Hidden clues**: collect valid hidden pool: `ClueRegistry.get_all_clues()` filtered to `type == HIDDEN` and `domain == "generic" or domain == category.category_id`. Draw sequentially without replacement, uniform among survivors, skipping any candidate whose `exclusive_group` is already claimed on the item, and skipping any second candidate with `effect_op == "override"`. Stop when rarity-many clues are drawn or the pool is exhausted. Effective rarity = actual drawn count.

Debug: when `Debug.enabled`, use `rng_seed` (optional param, defaults to `0` which means random) to seed the generator's RNG so devs can reproduce draws. Real calls never pass a seed.

### LotEntry.create() rewrite

Current flow (lines 35–61) rolls item count → calls `_draw_item(data)` → creates `ItemEntry.create(item)` for each → shuffles. New flow:

1. Item count roll unchanged.
2. For each slot: roll category (existing logic, extracted to private static `_draw_category(data) -> CategoryData`), call `ItemGenerator.draw(category, data.tier_weights, data.rarity_weights, Economy.SURFACE_CLUE_MIN, Economy.SURFACE_CLUE_MAX)`. If generator returns null anchor, skip slot.
3. Create `ItemEntry.from_generation(anchor, surface_clues, hidden_clues, category)` — a new factory that sets instance fields directly, bypassing `item_data`.
4. Veiled-chance roll, condition roll, center_offset roll unchanged.
5. Shuffle unchanged.
6. NPC estimate unchanged (reads `ItemEntry` instance fields).

The `_draw_item`, `_draw_item_by_weight`, and `_draw_item_by_rarity_and_category` private methods are deleted. `item_weights`-based draw (the legacy path) is removed in Phase 1 — `item_weights` stays on `LotData` only as a field that exists but is no longer read by `LotEntry`.

### ItemEntry shape changes

New instance fields (on the instance, not through ItemData):

```
var anchor: AnchorData = null
var surface_clues: Array[ClueData] = []
var hidden_clues: Array[ClueData] = []
var category_data: CategoryData = null
var item_data: ItemData = null  # Phase 1 only: populated by legacy load; null for generated entries

## Rarity equals the number of hidden clues on this instance.
var rarity: int:
    get:
        return hidden_clues.size()
```

The `func category_data()` method at `item_entry.gd:407` is deleted — replaced by the `var category_data` field. Internal callers at `item_entry.gd:411` (`super_category_text`) and `item_entry.gd:419` (`category_text`) switch from `category_data()` to the bare field `category_data`.

Internal accessor changes: everywhere `item_data.anchor` was read, read `anchor` (or fall back to `item_data.anchor` during Phase 1 migration window). Same pattern for `surface_clues`, `hidden_clues`, `category_data`. A public computed property `all_clues` (mirroring `ItemData.all_clues`) replaces `item_data.all_clues` for external callers (`item_row_tooltip.gd`, `inspection_scene.gd`). Internally, a private helper `_get_all_clues() -> Array[ClueData]` provides the same:

```
## All clues on this item — surface and hidden combined, surface-first.
var all_clues: Array[ClueData]:
    get:
        var result: Array[ClueData] = []
        result.assign(surface_clues + hidden_clues)
        return result
```

`get_naming_clue_pool()` at `item_entry.gd:96` reads anchor from instance field, surface/hidden from `all_clues`.

`fit_tags()` at `item_entry.gd:84` iterates `all_clues` instead of `item_data.all_clues`.

`verified` getter at `item_entry.gd:41` checks `hidden_clues.is_empty()`.

### Migration (StorageStore version 2)

`StorageStore._store_version()` returns 2. `_apply_migrations()`:

```
if from_version < 2:
    var migrated: Array = []
    for d in data.get("storage_items", []):
        if d.has("item_id") and not d.has("anchor_id"):
            # Legacy entry: resolve against still-loaded ItemRegistry.
            var item: ItemData = ItemRegistry.get_item_by_id(d["item_id"])
            if item == null:
                push_warning("Migration: item_id '%s' not found — entry dropped" % d["item_id"])
                continue
            d["anchor_id"] = item.anchor.anchor_id if item.anchor else ""
            d["surface_ids"] = _clue_ids(item.surface_clues)
            d["hidden_ids"] = _clue_ids(item.hidden_clues)
            d["category_id"] = item.category_data.category_id if item.category_data else ""
        migrated.append(d)
    data["storage_items"] = migrated
return data
```

`ItemEntry.from_dict()` accepts both shapes: new entries have `anchor_id` / `surface_ids` / `hidden_ids` / `category_id` keys (resolved via registries); legacy entries have `item_id` (already rewritten by migration above). During Phase 1, `from_dict` supports both; in Phase 2, only the composition shape remains.

### tier_weights field

LotData gets `@export var tier_weights: Dictionary = {}` — int keys 1–5, int values (weights). In existing lot YAML, add `tier_weights: { 1: 50, 2: 30, 3: 15, 4: 5, 5: 0 }` or similar; missing tiers default to weight 0 (never drawn). The field mirrors `rarity_weights` in shape and default behavior.

### Balance preview tool

New Python script `dev/tools/balance_preview.py`. Reads same YAML sources as `yaml_to_tres.py` (anchors, clues, categories, locations/lots). Per lot configuration:

- Simulates N draws (default 10 000).
- Reports: appraised value percentiles (p10/p50/p90), verified value percentiles, mean value per tier×rarity cell, surface/hidden count distributions.
- Content-health flags: categories whose surface pool is below `SURFACE_CLUE_MAX`, categories that cannot reach each rarity, tiers missing anchors, exclusive groups that never co-draw.
- Output format: terminal table + optional JSON dump for CI consumption.

Implementation mirrors the generator's draw logic in Python. Acceptance criteria pin the two implementations to the same distribution — this is verified manually during Phase 1 by running both against the same configuration and comparing output stats.

## Edge Cases

| Case                                                                          | Expected Handling                                                                                      |
| ----------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| Category with no anchors at rolled tier                                       | Fall back to nearest tier (prefer lower); if no anchors exist at any tier, skip item slot              |
| Surface clue valid pool smaller than rolled count                             | Take entire pool; `debug.warning` if debug enabled                                                     |
| Hidden clue valid pool runs dry before rarity count met                       | Keep drawn clues; effective rarity = actual count                                                      |
| Two hidden clues with override op                                             | Only first drawn; subsequent override candidates are filtered                                          |
| Lot with empty `tier_weights`                                                 | All tiers weight 0 → no anchor drawn → item slot skipped; logged                                       |
| Lot with empty `category_weights` and empty `super_category_weights`          | No category drawn → item slot skipped; logged                                                          |
| Legacy save with unresolvable `item_id`                                       | Entry dropped with `push_warning` (same posture as current `ItemEntry.from_dict()`)                    |
| Migration hits `item_id` whose `ItemData` has null anchor or empty clues      | Anchor/IDs set to empty string / empty array; entry creates but may show as "Unknown Item"             |
| Generated item with 0 surface clues and 0 hidden clues                        | "Unknown Item" with only anchor body text visible — same as today's COMMON item with no revealed clues |
| Anchor with no `naming_slot` participation (all anchors default to body slot) | Body text comes from `anchor.known_text` or empty; display helper returns "Unknown BodyText"           |
| Generated item where `rarity == 0` but has no hidden clues                    | `verified` getter returns `true` (empty hidden list is trivially revealed)                             |

## Acceptance Criteria

1. Lots with `tier_weights` defined generate items through the draw sequence; lots without `tier_weights` define it (but not `item_weights`) still generate items from `rarity_weights` + `category_weights` + uniform anchor pick across all tiers — the `tier_weights`-empty fallback does uniform tier selection.
2. Generated items flow through inspection, auction, cargo, storage, research, and customer sell with no behavioral difference from the current authored items.
3. A pre-migration save loads once, migrates all `item_id`-based entries to composition form, and round-trips in the new format thereafter; all instance state (condition, revealed_clue_ids, research_progress, unveiled) is preserved.
4. Every generated item has a well-formed composed display name when fully revealed, and its value resolves through the existing price pipeline with no per-type special cases.
5. Across a large sampled run, no generated item violates the hidden-draw constraints: domain scope is respected, at most one clue per exclusive group, at most one override clue, and effective rarity always equals actual hidden clue count.
6. The balance tool's simulated distributions match the runtime generator's observed distributions on the same lot configuration.
7. After Phase 2, `ItemData`, `ItemRegistry`, authored item YAML/TRES, and `item_weights` are gone; no code references them, and the game boots and runs correctly.
