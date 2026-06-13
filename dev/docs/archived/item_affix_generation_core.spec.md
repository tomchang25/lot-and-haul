# Affix-Driven Item Generation — Core (Spec A)

Implements the generation half of `item_affix_generation.sketch.md`: affix/combination designer resources, the reversed generator draw order, the runtime/save plumbing that carries affixes on an item, and the build-time conflict validator. Naming (Spec B) and the knowledge dictionary (deferred Spec C) build on the data this spec produces.

## Goal

Reverse item generation so an item's clues are sourced from affixes drawn first: draw category → anchor → affixes → one weighted combination per affix → that combination's surface + hidden clues. This makes the affix set (and therefore, in Spec B, the name) a real index into the item's possible contents, and turns Authenticate into a bet on which combination an item actually holds.

## Relational Context

- `LotEntry.create()` is the sole caller of `ItemGenerator.draw()` (`lot_entry.gd:57-64`) and immediately feeds the result into `ItemEntry.from_generation()` (`lot_entry.gd:68-74`). Both call sites change in this spec; nothing else calls `draw()` or `from_generation()`.
- `ItemGenerator` is a stateless service (`item_generator.gd:5-6`, `extends RefCounted`, all `static`). It reads designer data only through registries (`ClueRegistry.get_all_clues()` at `item_generator.gd:128`, `AnchorRegistry.get_all_anchors()` at `:56`). It must gain a read of a new `AffixRegistry` the same way — registries are the only data source a service may touch.
- `ItemEntry` is the runtime owner of an item's identity (`item_entry.gd:21-24`: `anchor`, `surface_clues`, `hidden_clues`, `category_data`). Affix identity (`affixes`, chosen `combination_ids`) is added here as new owned state. Per `dev/standards/runtime_type_archetypes.md`, scenes never construct or mutate an `ItemEntry` directly — only the `from_generation()` factory (`item_entry.gd:471-488`) and `from_dict()` (`:516-574`) set this state.
- `ItemEntry.rarity` is a computed property equal to the hidden-clue count (`item_entry.gd:43-45`, `Economy.rarity_for_clue_count(hidden_clues.size())`). This spec changes the _source_ of `hidden_clues` (now from combinations) but does not touch the rarity mechanism. A no-affix item has zero hidden clues and is therefore lowest rarity — an intended consequence, not a regression.
- Conflict authority is the clue-level `exclusive_group` (`clue_data.gd:48-50`), today enforced at draw time inside `_draw_hidden_clues` (`item_generator.gd:199-209`: at most one per group, at most one override). With clues now arriving bundled in combinations, that invariant moves to a build-time validator over the affix×combination cross-product, plus a draw-time insurance re-pick. There is deliberately no affix-level conflict field (see sketch §"Conflict authority").
- Designer resources are authored in YAML and generated to `.tres` by the pipeline's `EntitySpec` pattern (`dev/tools/tres_lib/entities/anchor_data.py`). Cross-resource references are authored as string ids in YAML and resolved to `ExtResource` refs in `.tres` (anchor's `category_scope` string → `category_data: CategoryData` ref, `anchor_data.py:52-76`). New affix/combination resources follow this exact convention. Never hand-edit `.tres` (`CLAUDE.md` data-pipeline rule).
- Registries are autoloads extending `ResourceRegistry` that load a directory of `.tres` at boot (`clue_registry.gd`). A new `AffixRegistry` joins the autoload order (`CLAUDE.md` lists the order; it must load before `RunManager`, which drives generation, and after the registries it depends on — `ClueRegistry`, `CategoryRegistry`).
- Save round-trips an item through string ids resolved against registries on load (`item_entry.gd:493-510` writes `anchor_id`/`surface_ids`/`hidden_ids`/`category_id`; `:516-574` resolves them back, dropping the entry if the anchor is unresolvable). New affix/combination ids serialize and resolve the same way; missing keys must default to empty so pre-affix saves load unchanged.

## Plan Friction

- Settled: `GenerationResult` (`item_generator.gd:9-12`) has only `anchor`, `surface_clues`, `hidden_clues`. Add `affixes: Array[AffixData]` and `combination_ids: Array[String]` (or `combinations: Array[AffixCombinationData]` carrying their ids); the generator populates them so downstream naming and the dictionary can index by affix.
- Settled: `ItemEntry` (`item_entry.gd:21-24`) carries no affix state. Add owned `affixes: Array[AffixData]` and `combination_ids: Array[String]`; set them in `from_generation()` (`:471-488`) and round-trip them in `to_dict()`/`from_dict()` (`:493-574`).
- Settled: the combination system does not exist — zero matches for a combination concept in any `.gd`. It is created here as a designer resource (see Design Gaps for representation). The "Combination Naming Rules" / "Anchor-Conditioned Surface Draw" `TODO.md` Draft entries are superseded by this spec (already annotated in `TODO.md`).
- Settled: `from_generation()` (`item_entry.gd:471-488`) and `LotEntry.create()` (`lot_entry.gd:57-80`) take no affix parameters and `to_dict`/`from_dict` have no affix fields — all three are rewritten to thread affix data through. `LotEntry.create()` still passes `data.tier_weights` for the anchor draw but no longer needs `data.rarity_weights`/`Economy.SURFACE_CLUE_MIN/MAX` for the hidden/surface draw on affixed items (those drove the retired uniform path).
- Settled: the old rarity/hidden path is retired for generation. `_pick_rarity` (`item_generator.gd:157-167`) and `_draw_hidden_clues` (`:174-211`) are removed or reduced to the plain-item baseline; hidden clues now come only from drawn combinations. `_draw_surface_clues` (`:126-152`) survives only as the plain-item surface baseline. This is folded into the sketch's "Generator" section.
- Settled: `balance_preview.py` (`dev/tools/balance_preview.py`) simulates the uniform pool draw and has no affix concept. It is **out of scope** here (sketch Non-Goal 1, Stage 2); note only that it will read stale behavior until upgraded.
- No further friction found between the sketch and the codebase for the generation core.

## Design Gaps

- **Affix YAML location.** YAML is one flat file per type under `data/yaml/` (`clues.yaml` holds both `anchors:` and clues; confirmed `data/yaml/` listing). Resolution: a new top-level file `data/yaml/affixes.yaml` with `affixes:` and `affix_combinations:` keys, kept separate from `clues.yaml` because affixes are a distinct authoring surface.
- **Cross-reference representation.** Anchor resolves `category_scope` (yaml string) → `ExtResource` → `category_data: CategoryData` (`anchor_data.py:52-76`). Resolution: affixes follow the same convention — author `category_scope`, `surface_clue_ids`, `hidden_clue_ids` as string ids in YAML; the pipeline resolves them to `ExtResource` refs so the runtime `AffixCombinationData` holds direct `Array[ClueData]` and the generator reads them without a registry lookup.
- **Combination as resource shape.** The `TresWriter` emits one flat `Resource` with `ExtResource` refs and has no demonstrated nested `[sub_resource]` support (`anchor_data.py` writes a single resource). Resolution: model `AffixCombinationData` as its own flat designer resource (own `.tres` under `data/tres/affix_combinations/`, ext-refs to its clues), and have `AffixData.combinations` be an `Array[AffixCombinationData]` of ext-refs — mirroring how an anchor ext-refs its category. Each combination carries `combination_id`, `weight: int`, `surface_clues`, `hidden_clues`. Avoids extending the writer with sub-resources.
- **New `AffixRegistry` autoload.** Mirror `clue_registry.gd`: `extends ResourceRegistry`, `_dir_path()` returns a new `DataPaths.AFFIXES_DIR` (add alongside `DataPaths.CLUES_DIR`, referenced at `clue_registry.gd:8`), `_id_of()` returns `affix_id`, plus `get_affix_by_id()` / `get_all_affixes()`. Combinations are reached through their parent affix, so they need no separate registry. Register the autoload after `CategoryRegistry` and before `RunManager` in the load order.
- **Save compatibility.** `from_dict` already tolerates absent keys with defaults (`item_entry.gd:543-546`). Resolution: add `affix_ids: []` and `combination_ids: []` to `to_dict` and read them with `d.get(..., [])` in `from_dict`, resolving affix ids via `AffixRegistry` and dropping any unresolved id with a `ctx.info(...)` note (the anchor-drop pattern at `:522-524`). No `schema_version` bump and no `StorageStore` migration pass — missing fields simply yield empty affix lists, which render as plain items.
- **Affix frequency control.** The sketch puts a global `weight` on each affix and excludes lot-level biasing. Resolution: `_draw_affixes` weights affix appearance by `AffixData.weight` filtered to the item's category (`category_scope`), independent of `LotData`. `LotData.rarity_weights` becomes unused by generation; leave the field in place (out-of-scope cleanup) rather than removing it here.

## Scope

### Included

- New designer resources `AffixData` and `AffixCombinationData` (definitions, YAML source, pipeline `EntitySpec`s, validation).
- New `AffixRegistry` autoload + `DataPaths.AFFIXES_DIR`.
- Reversed `ItemGenerator.draw()`: category → anchor → affixes → combination → clues, with the plain-item baseline and draw-time conflict insurance.
- `GenerationResult`, `ItemEntry`, `LotEntry.create()`, and `ItemEntry` serialization threaded with affix/combination data.
- Build-time cross-product conflict validator (clue `exclusive_group` doubling + double-override) in the YAML pipeline.
- 5–8 authored playtest affixes with 2–3 combinations each (playtest content cut).

### Excluded

- All naming changes — display composition, removal of clue/anchor naming fields (Spec B).
- The knowledge dictionary — `KnowledgeStore` state, recording on verify, `knowledge_hub` UI (deferred Spec C).
- `balance_preview.py` upgrade, EV/info-content validator, sample stats, probability perk (Stage 2 Non-Goals).
- Lot-level affix biasing and removal of the now-unused `LotData.rarity_weights`.

## Files to Change

| File                                            | Change Size  | Purpose                                                                                                                                                                          |
| ----------------------------------------------- | ------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `data/definitions/affix_data.gd`                | Medium (new) | `AffixData` resource: `affix_id`, `naming_slot`, `display_name`, `category_scope`, `weight`, `combinations: Array[AffixCombinationData]`.                                        |
| `data/definitions/affix_combination_data.gd`    | Small (new)  | `AffixCombinationData` resource: `combination_id`, `weight`, `surface_clues`, `hidden_clues`.                                                                                    |
| `data/yaml/affixes.yaml`                        | Medium (new) | Authored playtest affixes + combinations (string-id refs).                                                                                                                       |
| `dev/tools/tres_lib/entities/affix.py`          | Medium (new) | `EntitySpec` for affixes + combinations: build/parse/validate, including the cross-product conflict validator.                                                                   |
| `dev/tools/tres_lib/registry.py`                | Small        | Register the new affix `EntitySpec`(s).                                                                                                                                          |
| `global/autoloads/registries/affix_registry.gd` | Small (new)  | `AffixRegistry` autoload.                                                                                                                                                        |
| `global/constants/...` (DataPaths)              | Small        | Add `AFFIXES_DIR`.                                                                                                                                                               |
| `project.godot`                                 | Small        | Register `AffixRegistry` in autoload order.                                                                                                                                      |
| `common/gameplay/service/item_generator.gd`     | Large        | Reverse draw order; add `_draw_affixes` / `_pick_combination` / conflict insurance; retire `_pick_rarity` + rarity-based `_draw_hidden_clues`; keep plain-item surface baseline. |
| `common/gameplay/instance/item_entry.gd`        | Medium       | Add `affixes` + `combination_ids` state; thread through `from_generation`, `to_dict`, `from_dict`.                                                                               |
| `common/gameplay/instance/lot_entry.gd`         | Small        | Update `create()` call into `draw()` + `from_generation()` for the new shape.                                                                                                    |

## Implementation Notes

- **Draw order and the plain-item branch.** Anchor is drawn first (keep `_draw_anchor`, `item_generator.gd:55-120`, unchanged — `tier_weights` still applies). Then `_draw_affixes` returns 0–1 prefix and 0–1 suffix (sparse, weighted by `weight`, filtered by `category_scope`). For each drawn affix, `_pick_combination` weight-picks one combination and its clues are appended. If no affix is drawn, run the plain-item baseline: a thin `_draw_surface_clues` pass (reuse the surviving helper) and **no** hidden clues.
- **Draw-time conflict insurance (not the guarantee).** After merging both affixes' clues, if any clue-level `exclusive_group` is doubled or two overrides collide, re-pick one affix's combination, or drop one affix — never strip an individual clue (it would corrupt that combination's surface/hidden balance and its future dictionary slot). The exhaustive build-time validator means this branch should never fire on shipped data; it exists for un-revalidated/drifted data. Use the project's guard idiom (`push_error` + `ToastManager`, never `assert`), per `dev/standards/error_guard_standard.md`.
- **Validator (the guarantee).** In `affix.py`'s `validate()`, enumerate every legal affix pair (any prefix × any suffix that share a category scope) × the cross-product of their combinations; assert the merged clue set never doubles a clue `exclusive_group` and never carries two `effect_op == "override"` clues. Reuse the override/exclusive semantics already encoded at `item_generator.gd:199-209`. Also validate referential integrity (every `*_clue_id` exists, `category_scope` ids exist) following `anchor_data.py:109-178`.
- **Serialization.** Mirror the id-list pattern (`item_entry.gd:501-509` write, `:526-540` read). Resolve affix ids via `AffixRegistry`; combinations resolve through their parent affix by `combination_id`. An unresolved affix id is dropped with `ctx.info(...)`, never silently kept.
- **Rarity is untouched.** Do not modify `ItemEntry.rarity` (`:43-45`) or `Economy.rarity_for_clue_count`. Rarity correctly follows from the hidden-clue count the combinations produce.

## Edge Cases

| Case                                                                               | Expected Handling                                                                                          |
| ---------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| No affix drawn (the common case)                                                   | Plain item: baseline surface clues, zero hidden, lowest rarity.                                            |
| Both a prefix and a suffix drawn whose combinations share a clue `exclusive_group` | Build-time validator rejects the data; at runtime the insurance re-picks a combination or drops one affix. |
| Old save with no affix fields                                                      | Loads as a plain item — `affix_ids`/`combination_ids` default to empty; no migration pass.                 |
| Affix or combination id in a save no longer exists in data                         | Drop the affix with a `ctx.info(...)` note; keep the rest of the item.                                     |
| Combination references a clue id that was deleted                                  | Build-time validation error; never reaches runtime.                                                        |

## Acceptance Criteria

1. Generating an affixed item produces clues sourced from that affix's drawn combination, not from a uniform clue pool; two items sharing an affix share that combination family's symptom clues while differing on the distinguishing clue when their combinations differ.
2. Most generated items are plain (no affix) and carry no hidden clues; an item carries at most one prefix and one suffix under the current draw policy.
3. No generated item ever carries two clues that share a clue-level exclusive group, nor two override clues — guaranteed by the build-time validator and held by the draw-time insurance.
4. Affix and combination identity round-trips through save/load; a save written before this change loads as plain items with no errors.
5. Item rarity continues to equal the hidden-clue count, now sourced entirely from drawn combinations.
