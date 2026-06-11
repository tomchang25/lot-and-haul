# ItemEntry Layer Split & Manager-Mediated Mutations — Implementation Spec

## Goal

Split the ItemEntry instance into clean layers — data + price logic stays on the instance, presentation moves to a UI-side display helper — and route all scene-side mutations through the owning Manager so the instance follows the same discipline as Stores.

## Relational Context

- ItemEntry is the single authority for its own state fields (`unveiled`, `condition`, `revealed_clue_ids`, `research_progress`, `center_offset`, `id`) and for its price pipeline (`resolve_price()`, `appraised_with_hidden()`, `_raw_appraised_value()`, `get_condition_multiplier()`, `full_true_value()`, `roll_npc_estimate()`). No other system may write these fields directly — mutators on ItemEntry are the only write path, and after this refactor only the owning Manager may call them.
- Ownership decides the mediator: items currently in a run are owned by RunManager; items in storage are owned by MetaManager. A scene calls the owning Manager's wrapper; the wrapper calls the entry's mutator and emits any resulting EventBus signal.
- The current cross-manager convention for XP is: transactional dependency → direct call; the mutation is correct regardless of XP → EventBus signal. All three reveal-type XP sources (unveil, clue reveal, research reveal) are notifications — the reveal is correct whether or not XP lands. They must become EventBus signals, matching the existing pattern for `item_repaired` / `item_restored` / `sale_resolved`.
- ItemEntry currently has a hard compile-time dependency on the `KnowledgeManager` autoload (calls `add_category_points` in `unveil()`, `attempt_clue()`, `advance_research()`) and a UI-type dependency on `ItemRow.Column` enum (in `sort_value()`). Both must be removed. After the refactor, ItemEntry has zero dependencies on any Manager autoload or any UI type. (The serialization layer's `ItemRegistry.get_item_by_id()` lookup in `from_dict()` remains — the Plan's Req 6 explicitly defers replacing registry-id lookup to the pool-based generation work.)
- The Plan's "hidden reveal" mutator is `reveal_all_hidden()`. Its only caller is `from_dict()`'s legacy `verified`-flag migration — serialization-layer internal, no scene path. It stays on ItemEntry unchanged; no wrapper needed.
- The new display helper (`ItemEntryDisplayHelper`) lives at `game/shared/item_display/` — UI-side, so it may reference `ItemRow.Column` and any other UI type. It is a `class_name RefCounted` with static methods; it never mutates state. Every consumer that currently calls `entry.display_name`, `entry.estimated_value_text()`, `entry.sort_value(col)`, etc. instead calls `ItemEntryDisplayHelper.display_name(entry)`, `ItemEntryDisplayHelper.estimated_value_text(entry)`, `ItemEntryDisplayHelper.sort_value(entry, col)`, etc.
- `_naming_clue_pool()` stays on ItemEntry as a gameplay query (it reads state and designer data to assemble the participating naming entries). It is renamed to `get_naming_clue_pool()` and made public. The display helper consumes it for name composition.
- The `sort_value()` call chain is: `ItemListPanel.get_sort_value(entry, col)` delegates to `ItemEntryDisplayHelper.sort_value(entry, col)`, which dispatches on `ItemRow.Column`. The thin `get_sort_value` static on `ItemListPanel` continues wrapping, just redirects to the helper instead of `entry.sort_value()`.
- The Plan explicitly permits system-level direct writes: lot generation (`lot_entry.gd:53`) setting `unveiled = true` to bypass XP, and `storage_store.gd` setting `entry.id` during registration and calling `apply_storage_migration()` on load. These remain unchanged — the mediation rule governs scenes, not the Managers and pipelines that own the data.
- Constants that are presentation-only (`UNKNOWN_TEXT`, `RARITY_NAMES`, `PRICE_COLOR`, `PRICE_UNKNOWN_COLOR`) move from ItemEntry to the helper. External hardcoded duplicates of these values in scenes (`lot_card.gd`, `item_card.gd`, `storage_scene.gd`, `run_review_scene.gd`, `day_summary_scene.gd`) are replaced with references to the helper.
- `ResearchSlot` already has no autoload references — it only reads ItemEntry fields and writes `condition`. Its contract is unchanged. The `repair_item` and `restore_item` wrappers on MetaManager already own XP signalling via EventBus — no change needed there.

## Scope

### Included

- Strip all presentation logic from `item_entry.gd` into a new `ItemEntryDisplayHelper` class: formatted text methods, color methods/properties/constants, display-name composition, sort-key dispatch, veiled-masking constants, and rarity names.
- Remove the three `KnowledgeManager.add_category_points()` calls from ItemEntry (`unveil`, `attempt_clue`, `advance_research`).
- Add `item_unveiled` and `item_revealed` signals to EventBus; subscribe KnowledgeManager to them with handlers that delegate to `add_category_points(..., KnowledgeAction.REVEAL)`.
- Add an `apply_damage(ratio)` invariant-guarding mutator to ItemEntry (clamps `condition` at 0.0) — Managers never write `condition` directly.
- Add mutation wrappers to RunManager: `unveil_item(entry)`, `attempt_clue(entry, clue)`, `auto_reveal_all_surface(entry)`, `apply_trailer_damage()`. Each calls the entry's mutator and emits the appropriate EventBus signal on success (except trailer damage, which has no signal). `attempt_clue` computes the attribute bonus internally via `KnowledgeManager.get_attribute_value()` so the scene doesn't need to.
- Update `meta_manager.gd:research_item()` to emit `EventBus.item_revealed` when `advance_research()` returns true.
- Route all scene-side mutations through the owning Manager wrappers: `inspection_scene.gd` (unveil + clue chain), `reveal_scene.gd` (unveil + auto-reveal), `run_review_scene.gd` (trailer damage).
- Update all consumers of removed ItemEntry display methods/constants to call the helper instead.
- Deduplicate hardcoded presentation values (`"???"`, `Color(0.4, 1.0, 0.5)`, `RARITY_NAMES`) in scenes by referencing the helper.
- Create `dev/standards/runtime_type_archetypes.md` documenting the four archetypes and the mutation-mediation rule.
- Update `CLAUDE.md` conventions section to point to the new archetype standard.

### Excluded

- No change to any price formula, roll math, XP amounts, or player-visible behavior.
- No migration of other Entry types (LotEntry, CustomerEntry) to the new standard.
- No mid-run persistence or save-on-inspect.
- No serialization format change (clue-list storage for generated items belongs to pool-based generation work).
- No validation logic or unit test changes (behavior is intended to be identical).

## Files to Change

| File                                                          | Change Size | Purpose                                                                                                                                                                                                                                                                 |
| ------------------------------------------------------------- | ----------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `common/gameplay/instance/item_entry.gd`                      | Large       | Strip presentation methods/constants, remove 3 KnowledgeManager calls, make `_naming_clue_pool()` public as `get_naming_clue_pool()`, make `unveil()` return bool, add `apply_damage(ratio)` mutator, keep mutators/price-pipeline/factory/serialization intact         |
| `game/shared/item_display/item_entry_display_helper.gd`       | New         | Host all presentation logic: formatted texts, colors, display-name composition, sort-key dispatch, `UNKNOWN_TEXT`, `RARITY_NAMES`, `PRICE_COLOR`, `PRICE_UNKNOWN_COLOR`                                                                                                 |
| `global/autoloads/managers/run_manager.gd`                    | Large       | Add mutation wrappers: `unveil_item`, `attempt_clue`, `auto_reveal_all_surface`; each emits the appropriate EventBus signal after mutator success. Add `apply_trailer_damage()` — bulk convenience that iterates `run.trailer_items`, rolls against `car.trailer_damage_chance`, applies random ratio via `entry.apply_damage()`, and returns the cracked count. The entire trailer-damage loop moves here from `run_review_scene.gd`. |
| `global/autoloads/managers/meta_manager.gd`                   | Small       | Emit `EventBus.item_revealed` after `advance_research()` succeeds in `research_item()`                                                                                                                                                                                  |
| `global/autoloads/event_bus.gd`                               | Small       | Add `item_unveiled(category, rarity)` and `item_revealed(category, rarity)` signals                                                                                                                                                                                     |
| `global/autoloads/managers/knowledge_manager.gd`              | Small       | Subscribe to `item_unveiled` and `item_revealed` in `_ready()`; add handler methods that call `add_category_points(..., REVEAL)`                                                                                                                                        |
| `game/run/inspection/inspection_scene.gd`                     | Medium      | Route `unveil()` → `RunManager.unveil_item()`, `attempt_clue()` → `RunManager.attempt_clue()`, update display calls to use helper, update stale comment at line 257 ("XP is granted inside attempt_clue()") to describe the wrapper+signal flow                         |
| `game/run/reveal/reveal_scene.gd`                             | Small       | Route `entry.unveil()` → `RunManager.unveil_item()`, `entry.auto_reveal_all_surface()` → `RunManager.auto_reveal_all_surface()`                                                                                                                                         |
| `game/run/run_review/run_review_scene.gd`                     | Small       | Remove `_apply_trailer_damage()` (the entire loop moves into RunManager), call `RunManager.apply_trailer_damage()` instead, replace hardcoded `Color(0.4, 1.0, 0.5)` with `ItemEntryDisplayHelper.PRICE_COLOR`                                                                                             |
| `game/shared/item_display/item_row.gd`                        | Medium      | Replace all `_entry.display_name` / `_entry.condition_text()` / etc. with `ItemEntryDisplayHelper.*(_entry)` calls                                                                                                                                                      |
| `game/shared/item_display/item_card.gd`                       | Small       | Replace display method calls with helper, use `ItemEntryDisplayHelper.UNKNOWN_TEXT` instead of hardcoded `"???"`                                                                                                                                                        |
| `game/shared/item_display/item_row_tooltip.gd`                | Small       | Replace display method calls with helper                                                                                                                                                                                                                                |
| `game/shared/item_display/item_list_panel/item_list_panel.gd` | Small       | `get_sort_value` → delegate to `ItemEntryDisplayHelper.sort_value` instead of `entry.sort_value`                                                                                                                                                                        |
| `game/meta/storage/storage_scene.gd`                          | Small       | Replace display method/property calls with helper, replace hardcoded `"???"` with `UNKNOWN_TEXT` and `Color(0.4, 1.0, 0.5)` with `PRICE_COLOR`. The `"Verified"` / `"Converged"` labels are scene-local UI strings, not ItemEntry presentation — they stay in the scene |
| `game/run/cargo/cargo_item_row.gd`                            | Small       | Replace display method calls with helper                                                                                                                                                                                                                                |
| `game/run/cargo/cargo_scene.gd`                               | Small       | Replace `entry.display_name` (line 541) with helper                                                                                                                                                                                                                     |
| `game/run/auction/auction_scene.gd`                           | Small       | Replace `entry.display_name` / `entry.estimated_value_text()` with helper                                                                                                                                                                                               |
| `game/meta/customer_sell/customer_sell_scene.gd`              | Small       | Replace `entry.display_name` with helper                                                                                                                                                                                                                                |
| `game/run/lot_browse/lot_card/lot_card.gd`                    | Small       | Replace local `RARITY_NAMES` duplicate with `ItemEntryDisplayHelper.RARITY_NAMES`                                                                                                                                                                                       |
| `game/meta/day_summary/day_summary_scene.gd`                  | Small       | Replace hardcoded `Color(0.4, 1.0, 0.5)` with helper constant                                                                                                                                                                                                           |
| `dev/standards/runtime_type_archetypes.md`                    | New         | Document the four archetypes (Entry/Instance, Store, Snapshot, Service) and the mutation-mediation rule                                                                                                                                                                 |
| `CLAUDE.md`                                                   | Small       | Update conventions section to point to the new archetype standard, replace existing inline taxonomy description with a pointer                                                                                                                                          |

## Implementation Notes

### ItemEntryDisplayHelper design

The helper is a `class_name ItemEntryDisplayHelper extends RefCounted` with only static methods and consts. It takes an `ItemEntry` as the first parameter of every method and reads its public API (`is_veiled()`, `resolve_price()`, `item_data`, `unveiled`, `verified`, `revealed_clue_ids`, `condition`, etc.) to produce formatted output. It never mutates.

The display-name composition moves in full: the helper calls `entry.get_naming_clue_pool()`, then runs the prefix/body/suffix priority selection and the `"Unknown "` prepend logic identically to the current `display_name` property getter on ItemEntry.

The `sort_value(entry, column)` method dispatches on `ItemRow.Column` — the same match block that currently lives on ItemEntry, unchanged in logic.

### Mutation wrapper contract (RunManager)

Each new RunManager wrapper follows the pattern: guard → call entry mutator → emit EventBus signal on success → return result. The wrappers do not spend AP — AP deduction remains the scene's concern, matching the existing `spend_ap()` + action separation already in `inspection_scene.gd`.

- `unveil_item(entry)`: call `entry.unveil()` (now returns bool — true when the flag actually flipped). On true, emit `EventBus.item_unveiled` **only if** `entry.item_data != null and entry.item_data.category_data != null` — this mirrors the guard currently inside `unveil()` (item_entry.gd:672); `add_category_points()` has no null-category guard of its own, so dropping it would change behavior.
- `attempt_clue(entry, clue)`: looks up the attribute bonus for `clue.attribute` via `KnowledgeManager.get_attribute_value()`, then captures `var before := entry.revealed_clue_ids.size()`, calls `entry.attempt_clue()`, emits `EventBus.item_revealed` **only when `revealed_clue_ids` grew** — NOT whenever the return is true. `attempt_clue()` returns the roll result (`succeeded`) even when the clue was already revealed and nothing was appended; today that path grants no XP, and emitting on `true` would change that. Returns `succeeded` to the scene unchanged.
- `auto_reveal_all_surface(entry)`: call `entry.auto_reveal_all_surface()`. No signal — this is a bulk reveal, not a player-triggered discovery.
- `apply_trailer_damage()`: bulk convenience on RunManager. Iterates `run.trailer_items`, rolls each against `car.trailer_damage_chance`, applies a random ratio in `[trailer_damage_ratio_min, trailer_damage_ratio_max]` via `entry.apply_damage()`, and returns the cracked count. Returns 0 when there is no active run or the car's damage chance ≤ 0.0. No EventBus signal — trailer damage grants no XP. The entire loop previously lived in `run_review_scene.gd:_apply_trailer_damage()` and moved here to keep the scene side minimal.

### ItemEntry mutator changes

- `unveil()`: remove the `KnowledgeManager.add_category_points()` call and its `category_data` guard (lines 672-677 — the guard moves to the RunManager wrapper's emit). Change the return type to `bool`: the `if not is_veiled()` guard returns false, the flag set returns true. No current caller reads the return, so this is behavior-neutral; it lets the wrapper emit without duplicating the veil check.
- `attempt_clue()`: remove the `KnowledgeManager.add_category_points()` call (lines 371-375). Keep the roll, the `succeeded and not has()` guard, and `revealed_clue_ids.append()`. Return semantics unchanged (returns `succeeded`, the roll result).
- `advance_research()`: remove the `KnowledgeManager.add_category_points()` call (lines 432-436). Keep all progress math and `revealed_clue_ids.append()`.
- `apply_damage(ratio)` (new): `condition = maxf(0.0, condition - ratio)` — replaces run_review_scene's direct field write (run_review_scene.gd:86).
- `reveal_all_hidden()`: unchanged — serialization-layer internal (legacy migration in `from_dict()`).

### KnowledgeManager subscription

The two new signal handlers follow the exact same pattern as the existing `_on_item_repaired` / `_on_item_restored` / `_on_sale_resolved` handlers (lines 225-234): accept `(category: CategoryData, rarity: ItemData.Rarity)`, call `add_category_points(category, rarity, KnowledgeAction.REVEAL)`. Connect both in `_ready()` alongside the existing three.

### Mediation for items in storage during run resolution

`reveal_scene.gd` runs during the run phase — the items are in `RunManager.lot.won_items`, owned by the run. Call `RunManager.unveil_item()` and `RunManager.auto_reveal_all_surface()`.

`run_review_scene.gd` also runs during the run phase — items are in `RunManager.run.cargo_items` / `trailer_items`. Call `RunManager.apply_trailer_damage()` (the entire loop lives in the Manager now).

Storage mutations (`repair_item`, `restore_item`, `research_item`) are already wrapped by MetaManager — only the internal KnowledgeManager call inside `advance_research()` needs removal with the signal emission moved up to MetaManager's wrapper.

### Existing manager-to-entry mutator calls (no change needed)

`RunManager.take_run_result():47` calls `entry.auto_reveal_all_surface()` directly — this is a manager mutating its own items, legitimate under the new standard. No signal emission; the hub-return reveal is not a player-triggered discovery.

`storage_store.gd:30` (`entry.id = _next_entry_id`) and `storage_store.gd:82` (`entry.apply_storage_migration()`) — store-level operations, not scenes. Unchanged.

`lot_entry.gd:53` (`item_entry.unveiled = true`) — system-level pre-unveil during lot generation. Unchanged; the comment documents the intentional bypass of XP.

## Edge Cases

| Case                                                                                    | Expected Handling                                                                                                                                                                                                                                                                                           |
| --------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Scene calls `RunManager.unveil_item()` on already-unveiled item                         | ItemEntry's `unveil()` guard returns false; no signal emitted                                                                                                                                                                                                                                               |
| Scene calls `RunManager.unveil_item()` on entry with null `item_data` / `category_data` | Flag still flips, but the wrapper's null guard skips the signal — same as today's no-XP path                                                                                                                                                                                                                |
| Scene calls `RunManager.attempt_clue()` with null clue                                  | Returns false; no mutation; no signal                                                                                                                                                                                                                                                                       |
| Scene calls `RunManager.attempt_clue()` on already-revealed clue                        | `attempt_clue()` may still return true (the roll result) but appends nothing — the wrapper's size check sees no growth and emits no signal, matching today's no-XP behavior. (In practice unreachable: `get_inspection_clues()` only offers unrevealed clues.)                                              |
| `reveal_scene.gd` processes an empty won_items list                                     | `_show_auction_lost_state()` path — no mutations, no signals                                                                                                                                                                                                                                                |
| `advance_research()` called when all hidden clues are already revealed                  | Returns false (loop finds no unrevealed clue); no signal emitted by MetaManager                                                                                                                                                                                                                             |
| `advance_research()` makes progress but doesn't reach dc                                | Returns false; `research_progress` dict is updated but no clue revealed; no signal                                                                                                                                                                                                                          |
| Trailer damage with `car.trailer_damage_chance <= 0.0`                                  | `RunManager.apply_trailer_damage()` returns 0 without mutating any item                                                                                                                                                                                                                                     |
| Display helper called with veiled item                                                  | All text methods return `"???"`; color methods return veiled colors; `display_name()` returns `"Unknown Item"` — identical to current behavior                                                                                                                                                              |
| Display helper called with null entry                                                   | Sort value returns 0 (existing guard in `ItemListPanel.get_sort_value` stays at that level); other helper methods return safe defaults (`""`, `Color.WHITE`, etc.)                                                                                                                                          |
| Save/load round-trip                                                                    | No serialization format changes; `from_dict` / `to_dict` are untouched; legacy migrations (stale clue stripping, legacy-key decoding) unchanged                                                                                                                                                             |
| Hardcoded `"Verified"` / `"Converged"` in storage_scene                                 | They stay in the scene. They are scene-local UI labels, not duplicates of ItemEntry presentation — the Plan's display-helper scope covers ItemEntry's presentation only. The adjacent `"???"` (line 232) and `Color(0.4, 1.0, 0.5)` (lines 229/237) ARE ItemEntry duplicates and move to helper references. |

## Acceptance Criteria

1. Behavior is identical before and after: same prices, same ranges, same names, same colors, same sort orders, same XP awards in the same situations.
2. No scene mutates an item instance directly — every scene-side mutation goes through a RunManager or MetaManager wrapper.
3. Reveal-type XP arrives via EventBus signals (`item_unveiled`, `item_revealed`) from the mediating Manager, not from inside the ItemEntry instance.
4. Shared gameplay code (`common/gameplay/instance/item_entry.gd`) no longer references `KnowledgeManager`, `ItemRow.Column`, or any other Manager autoload or UI type. (Sole remaining autoload reference: `ItemRegistry` inside `from_dict()` — serialization layer, deferred to pool-based generation work per Plan Req 6.)
5. Save/load round-trips unchanged, including all legacy-key migrations and stale-clue stripping.
6. The runtime-type archetype standard exists at `dev/standards/runtime_type_archetypes.md` with the four archetypes and the mutation-mediation rule, and `CLAUDE.md` conventions point to it.
