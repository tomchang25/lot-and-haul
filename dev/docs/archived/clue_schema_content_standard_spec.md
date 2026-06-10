# Clue Schema & Content Standard Overhaul — Implementation Spec

> **Superseded** by `../plans/clue_schema_cleanup.md` — see the banner in `clue_schema_content_standard.md` for why.

Plan: `clue_schema_content_standard.md`

## Goal

Move all physical and base-value data onto category-derived anchor clue variants, redefine rarity as hidden-clue count, add negative and base-replacement effects, and regenerate the YAML content set under a single generation standard with reference tables.

## Relational Context

- The runtime item instance is the sole resolver of physical data (shape cells, weight, sprite), sourcing its anchor clue. Scenes (cargo, customer sell, inspection, item display) currently read `entry.item_data.category_data` directly for cells/weight — after this change they call new accessors on the instance and never touch the category for physical data. The category definition keeps only id, super-category reference, and display name.
- All value resolves through the instance's single price pipeline. The override branch lands inside it; sell math stays a stateless consumer of the resolved price and owns only transaction multipliers (the verified bonus constant changes 1.2 → 1.05 there; bonus dice unchanged).
- Verified aggregation contract changes from `((anchor + Σs_add) × Πs_mul + Σh_add) × Πh_mul` to global add-then-mul: `(base + Σs_add + Σh_add) × Πs_mul × Πh_mul`, where base = revealed override amount, else anchor flat. Appraised (surface-only) math is unchanged. An unrevealed override contributes nothing.
- `flat` effect op becomes legal on anchor and hidden only; on hidden it means override. Validator enforces: max one override per item, flat forbidden on surface.
- Verified means "all hidden revealed"; zero hidden ⇒ verified at creation. The storage store's auto-verify branch is deleted with the flag — no replacement path.
- Entries serialize by item id + revealed clue ids; loading already strips unknown clue ids and drops unknown item ids with a warning. Content regeneration relies on this existing behavior — no migration code.
- YAML is the only authoring surface; `.tres` is generated. Field read/write/validate for each resource lives in the pipeline entity specs; the validator runs standalone and inside generation.
- Removing the authored item name removes the composed==authored naming check. Replace with structural checks: exactly one anchor, anchor occupies the body slot, full-reveal composition non-empty.
- Draw-control metadata (anchor tier, surface affinity tags, anchor tag-weight map, exclusive groups) and the sprite reference have **no runtime consumer** in this change — authored and validated only. Lot draw (rarity weights → item) is untouched. Do not invent UI or generator code for them.
- Knowledge XP calls keyed by rarity are untouched.

## Scope

### Included

- Schema changes to clue/category/item definitions and their pipeline entity specs.
- Runtime: anchor-sourced physical accessors + call-site switch, override branch, verified bonus value, auto-verify removal.
- New validations, reference-table comparison in the stats tool, regenerated generation prompts, regenerated YAML content, authored reference tables.

### Excluded

- Pool generator, lot/location tier curves, rarity frequency tables.
- ItemEntry layer split / manager-mediated mutations.
- Combination naming rules; any sprite rendering.

## Files to Change

| File | Change Size | Purpose |
| --- | --- | --- |
| `data/definitions/clue_data.gd` | Medium | New fields: shape_id, sprite, weight_kg, tier (anchor); exclusive_group (hidden); affinity tags / tag weights |
| `data/definitions/category_data.gd` | Small | Drop weight, shape_id, get_cells |
| `data/definitions/item_data.gd` | Small | Drop item_name, base_price, auto_verify |
| `common/gameplay/instance/item_entry.gd` | Medium | Physical accessors from anchor; override branch; new verified aggregation |
| `game/run/cargo/cargo_scene.gd` | Small | Use instance accessors |
| `game/run/cargo/cargo_item_row.gd` | Small | Use instance accessors |
| `game/meta/customer_sell/customer_sell_scene.gd` | Small | Use instance accessors |
| `game/run/inspection/inspection_scene.gd` | Small | Use instance accessors |
| `common/gameplay/store/storage_store.gd` | Small | Remove auto_verify branch |
| `common/utils/sell_math.gd` | Small | VERIFIED_PRICE_BONUS → 1.05 |
| `dev/tools/tres_lib/entities/clue.py` | Medium | New fields + per-clue validations |
| `dev/tools/tres_lib/entities/item.py` | Medium | Drop fields; hidden-count==rarity, one-override, exclusive-group, structural naming checks |
| `dev/tools/tres_lib/entities/category.py` | Small | Drop physical fields |
| `dev/tools/yaml_stats.py` | Medium | Compare actuals vs reference tables, out-of-band warnings |
| `dev/tools/prompts/yaml_generation/*.md` | Large | New schema, effect budgets per tier, positive/negative mix, shape conventions |
| `data/yaml/clues.yaml`, `data/yaml/items/*.yaml`, `data/yaml/category_data.yaml` | Large | Regenerated content |
| `data/yaml/reference_tables.yaml` (new) | Medium | Authored per-category balance targets (tooling-only, not converted to tres) |

## Implementation Notes

- Physical accessors return safe defaults when no anchor exists (empty cells, 0 weight) — registry audit should make this unreachable in shipped data.
- Veiled display behavior is preserved: placement logic may use real shape/weight; display text helpers keep returning the unknown marker while veiled.
- Validator additions are errors; reference-table band violations in the stats tool are warnings (balance signals, not build breaks).
- Zero `effect_amount` on non-anchor clues is a validator error (anchor uses flat, never zero).
- `exclusive_group` empty string = no group; uniqueness check is per item across its hidden clues.

## Edge Cases

| Case | Expected Handling |
| --- | --- |
| Override hidden unrevealed | Appraised and verified math use anchor base until revealed |
| Item with 0 hidden (Common) | Verified at creation; ×1.05 applies in sell flow |
| Save referencing removed items/clues | Stale clue ids stripped, missing items dropped with warning (existing behavior) |
| Anchor missing physical fields in YAML | Validator error at pipeline time |

## Acceptance Criteria

1. Cargo packing, weight limits, and item display work with physical data sourced from anchors; categories carry no physical data.
2. Every item's hidden count equals its rarity; validation fails otherwise; zero-hidden items are verified by default.
3. A revealed override replaces the anchor base with all other modifiers applied on top; no item carries two same-group hidden clues; no non-anchor clue has zero effect.
4. Verified sell bonus is ×1.05 everywhere it previously applied at ×1.2.
5. Validation and stats tooling pass on the regenerated set, reporting out-of-band categories against reference tables.
6. Pre-overhaul saves load without crashing.
