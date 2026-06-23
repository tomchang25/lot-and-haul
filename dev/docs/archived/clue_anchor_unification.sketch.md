# Clue & Anchor Unification — Phase 1

## Goal

Remove `domain` and `scope_mode` as active category-binding constraints. Clues become a single global pool; affixes become universal. Cut condition-related clues that overlap with the `condition` multiplier system. Rename anchors to sub-type display names. Phase 2 (out of scope) will add new clues, rework combinations, deprecate `scope_mode` entirely, and rebalance.

## Requirements

1. Remove `domain` field from all clue entries in `data/yaml/clues.yaml`. Clues carry no category identity at the data layer.
2. Remove all condition/damage/wear clues that overlap with the `condition` field on `ItemEntry`. A clue whose `known_text` or effect semantics imply physical damage, wear, breakage, rust, rot, repair evidence, or replaced parts is a condition clue and must be deleted.
3. Rename all remaining clue IDs to generic form: `common_<aspect>_<detail>`, except at most one category-specific surface clue per category.
4. Merge redundant affixes, strip category prefixes from affix IDs, change all `scope_mode` to `all`, and remove `category_scope` from every affix.
5. Rename anchor IDs and `known_text_key` to sub-type display names for all categories that can express meaningful sub-types today. Oil lamp and porcelain figurine anchors retain current naming (deferred to Phase 2 when they gain 3+ variants each).
6. Update `tutorial_data.yaml` and `_test_item_generator.yaml` to match: remove `domain`, change `scope_mode` to `all`, delete `category_scope`.
7. Update `dev/tools/prompts/yaml_generation/item.md` and `base.md`: remove `domain` from schema, ban condition-language clues, update clue ID naming conventions.
8. Update `dev/tools/balance_preview.py`: remove `domain` field from `ClueData` dataclass, remove `domain`-based pool logic, use a single global surface-clue pool for Phase 1.
9. Regenerate all `.tres` via `dev/tools/yaml_to_tres.py` and validate through `validate_yaml.py`.

## Design

### Condition Clues — Removal Criteria

A clue is considered a condition clue if its `known_text` or `known_text_key` describes any of: wear (faded, worn, scratched, scuffed, tarnished), damage (cracked, chipped, pitted, broken, splintered, frayed, torn, dented, rusted), degradation (yellowed, crazed, slack, dry, rough, warped), or repair/replacement evidence (replaced, refinished, rewired, swapped, welded, filled, ground, retouched). Hidden clues following the same semantics (water_stain, movement_swap, spring_broken, repair_fill, internal_fracture, trimmed_margin, overpaint, weld_repair, cylinder_mismatch, bore_ring, bowstring_dry) are also removed.

Expected removal: approximately 28 surface clues and 12 hidden clues.

### Affix Merge

22 affixes → 18 affixes after merge:

| Merged ID | Source affixes (3 groups)                       |
| --------- | ----------------------------------------------- |
| `antique` | `bag_rustic` + `watch_vintage` + `lamp_antique` |
| `fine`    | `bag_luxury` + `poster_fine`                    |
| `service` | `pistol_service` + `rifle_service`              |

All other affix IDs keep their name after stripping the category prefix:

`modern`, `unsigned`, `grand`, `mantel`, `painted`, `pastoral`, `cameo`, `bud`, `preserved`, `cast`, `gallery`, `engraved`, `sporting`, `decorated`, `hunter`

Every affix entry: `scope_mode: all`, no `category_scope`. Merged affix entries combine the `combination_ids` arrays of their sources.

### Clue Naming Convention

```
common_<aspect>_<detail>
```

| Aspect       | Meaning                                     | Example (old → new)                                     |
| ------------ | ------------------------------------------- | ------------------------------------------------------- |
| `material`   | base material quality or type               | `bag_exterior_leather` → `common_material_leather`      |
| `detail`     | visible hardware, ornament, special feature | `bag_hardware_brass` → `common_detail_brass`            |
| `craft`      | construction method, skill signature        | `bag_stitching_handmade` → `common_craft_handmade`      |
| `mark`       | identifying mark, serial, stamp, signature  | `clock_workshop_label` → `common_mark_label`            |
| `provenance` | documentation, history, attribution trail   | `painting_provenance_label` → `common_provenance_label` |
| `medium`     | artistic or technical medium                | `painting_medium_oil` → `common_medium_oil`             |
| `form`       | shape, configuration, structural feature    | `crossbow_mech_triggered` → `common_form_trigger_mech`  |

Category-specific surface clues (at most one per category) keep the category prefix:

`handbag_monogram`, `watch_chronograph`, `lamp_blown_glass`, `clock_dovetail_joinery`, `figurine_shepherdess_form`, `vase_cameo_body`, `poster_lithograph`, `painting_craquelure`, `sculpture_lost_wax`, `pistol_lock_maker`, `rifle_precision_sight`, `crossbow_steel_prod`

Hidden authenticity clues (`_leaf_` and `_override_`) are not renamed beyond their existing IDs; they remain category-prefixed.

### Anchor Sub-Type Naming

Suffix `_NN` retains the tier number.

| Category   | Old anchor_id         | New anchor_id           | known_text  |
| ---------- | --------------------- | ----------------------- | ----------- |
| handbag    | `bag_anchor_01`       | `bag_tote_01`           | Tote        |
|            | `bag_anchor_02`       | `bag_satchel_02`        | Satchel     |
|            | `bag_anchor_03`       | `bag_clutch_03`         | Clutch      |
|            | `bag_anchor_04`       | `bag_messenger_04`      | Messenger   |
| wristwatch | `watch_anchor_01`     | `watch_diver_01`        | Diver       |
|            | `watch_anchor_02`     | `watch_field_02`        | Field       |
|            | `watch_anchor_03`     | `watch_dress_03`        | Dress       |
|            | `watch_anchor_04`     | `watch_pilot_04`        | Pilot       |
| clock      | `clock_anchor_01`     | `clock_mantel_01`       | Mantel      |
|            | `clock_anchor_02`     | `clock_tall_02`         | Tall Case   |
| vase       | `vase_anchor_01`      | `vase_bud_01`           | Bud         |
|            | `vase_anchor_02`      | `vase_urn_02`           | Urn         |
| painting   | `painting_anchor_01`  | `painting_panel_03`     | Panel       |
|            | `painting_anchor_02`  | `painting_canvas_04`    | Canvas      |
|            | `painting_anchor_03`  | `painting_framed_05`    | Framed      |
| sculpture  | `sculpture_anchor_01` | `sculpture_bust_03`     | Bust        |
|            | `sculpture_anchor_02` | `sculpture_figural_04`  | Figural     |
|            | `sculpture_anchor_03` | `sculpture_abstract_05` | Abstract    |
| poster     | `poster_anchor_01`    | `poster_onesheet_01`    | One-Sheet   |
|            | `poster_anchor_02`    | `poster_window_02`      | Window Card |
| pistol     | `pistol_anchor_01`    | `pistol_pepperbox_02`   | Pepperbox   |
|            | `pistol_anchor_02`    | `pistol_derringer_03`   | Derringer   |
| rifle      | `rifle_anchor_01`     | `rifle_carbine_02`      | Carbine     |
|            | `rifle_anchor_02`     | `rifle_musket_03`       | Musket      |
| crossbow   | `crossbow_anchor_01`  | `crossbow_target_02`    | Target      |
|            | `crossbow_anchor_02`  | `crossbow_siege_03`     | Siege       |

Oil lamp and porcelain figurine anchors retain current IDs and display names (Phase 2).

### Save Migration Safety

Existing migration code already handles null and stale IDs:

- `ItemEntry.from_dict()` L124–126: missing anchor ID → entry dropped (`ctx.info` + return `null`).
- `ItemEntry.from_dict()` L167–177: stale `revealed_clue_ids` silently stripped against known IDs from the item's active clue set.

No additional migration code is required.

## Sketch (non-normative)

### Step 1 — `data/yaml/clues.yaml`: domain + condition removal

```
# For every clue entry, delete the "domain:" line.
#
# Delete every surface clue matching condition-removal criteria:
#   - Any mul < 1.0 that names a physical defect or wear state
#   - Specific IDs: all *_faded, *_scratched, *_cracked, *_chipped,
#     *_pitted, *_frayed, *_rusty, *_splintered, *_worn, *_rough,
#     *_slack, *_crazed, *_yellowed, *_artificial_patina,
#     *_band_replaced, *_dial_refinish, *_ground
#
# Delete every hidden clue matching condition-removal criteria:
#   - *_water_stain, *_movement_swap, *_rewired, *_spring_broken,
#     *_repair_fill, *_internal_fracture, *_trimmed_margin,
#     *_overpaint, *_weld_repair, *_cylinder_mismatch,
#     *_bore_ring, *_bowstring_dry
```

### Step 2 — `data/yaml/clues.yaml`: clue ID rename

```
# For every remaining clue, rename clue_id:
#   Strip category prefix → assign aspect → prepend "common_"
#   Example: bag_exterior_leather → common_material_leather
#   Example: watch_movement_jewelled → watch_jewelled (category-specific)
#   Example: pistol_inlay_gold → common_detail_gold
#
# Hidden clues (_leaf_ / _override_) keep their existing IDs with
# category prefix. Example: bag_leaf_hermes stays bag_leaf_hermes.
#
# Update known_text_key to match the new clue_id convention.
```

### Step 3 — `data/yaml/affixes.yaml`: merge, rename, scope_mode

```
# Merge affix entries:
#   Concatenate combination_ids from all source affixes.
#   Aggregate weights (or reassign based on context).
#   Remove duplicate combination_ids if any combination is
#   referenced by multiple sources.
#
# For every affix:
#   scope_mode: "all"
#   Delete "category_scope:" block if present.
#   Rename affix_id by stripping category prefix, applying merge rules.
#
# For every combination:
#   Rename surface_clue_ids entries to match Step 2.
#   Rename hidden_clue_ids entries to match Step 2.
```

### Step 4 — `data/yaml/clues.yaml`: anchor rename

```
# For each category in the Design > Anchor table:
#   Rename anchor_id to sub-type form.
#   Rename known_text_key: ANCHOR_<CAT>_<SUBTYPE>_<TIER>
#   Example: bag_anchor_01 → bag_tote_01
#            ANCHOR_BAG_ANCHOR_01 → ANCHOR_BAG_TOTE_01
#
# Oil lamp and porcelain figurine anchors: no changes.
```

### Step 5 — tutorial and test YAML

```
# tutorial_data.yaml:
#   Delete "domain:" lines from all clues.
#   scope_mode: all (already "all" — no change needed beyond stripping
#     category_scope if present).
#   Delete "category_scope:" block if present.
#   Tutorial clue/affix IDs are already tutorial-prefixed — update
#     references if they pointed to renamed production clues.
#
# _test_item_generator.yaml:
#   Delete "domain:" lines.
#   scope_mode: categories → all.
#   Delete "category_scope:" block.
```

### Step 6 — generation prompts

```
# item.md:
#   Delete the "domain: generic | <category_id>" line from the
#     Clue Schema section.
#   Delete the domain comment from the Anchor Schema section
#     ("Anchors carry no … domain … field" — already accurate).
#   Add to Clue Schema / Surface clues section:
#     "Do not generate condition, damage, wear, or repair clues.
#      The condition system handles item condition separately.
#      Clues describe material, craftsmanship, marks, provenance,
#      medium, and form."
#   Update clue ID convention:
#     common_<aspect>_<detail> for generic clues
#     <category_id>_<detail> for category-specific clues
#   Delete "domain:" from all example outputs.
#   Update example clue IDs to match new convention.
#
# base.md:
#   Add "common_" to ID prefixes section.
#   Add to Text Standards: "Do not author clues whose known_text
#     implies physical condition, damage, wear, or repair."
```

### Step 7 — `dev/tools/balance_preview.py`: domain removal

```
# ClueData dataclass: remove "domain: str = 'generic'" field.
# from_yaml(): remove "domain=entry.get('domain', 'generic')" line.
# draw_surface_clues(): replace domain-based pool filtering with
#   full global surface-clue pool. All surface clues are eligible
#   for every category.
# _check_surface_pool(): remove per-category domain check; replace
#   with a single global surface pool size check.
```

### Step 8 — regenerate and validate

```bash
python dev/tools/yaml_to_tres.py
python dev/tools/validate_yaml.py
python dev/tools/yaml_stats.py
python dev/tools/balance_preview.py
```

### Phase 2 (out of scope for this sketch)

- Add new generic clues to restore pool depth after condition-clue removal.
- Deprecate `scope_mode` entirely; move category specificity to the combination level where some combinations carry per-category gating.
- Combination rework: ~6 common combinations usable by all categories + a few category-specific combinations.
- Rewrite `balance_preview.py` to parse affixes and build per-category clue pools from combination data (Option B).
- Expand oil lamp and porcelain figurine to 3+ anchors each with sub-type names.
- Full rebalance pass against `reference_tables.yaml`.

## Non-Goals

1. No runtime GDScript changes — `ItemGenerator`, `ItemEntry`, `ItemEntry.from_dict()`, and registries are unaffected.
2. No save compatibility burden — stale anchor IDs silently drop the entry, stale revealed clue IDs are silently stripped. Existing migration code handles both.
3. No balance tuning — rebalance deferred to Phase 2.
4. No new clues added — only removal and rename for Phase 1.
5. No `exclusive_group` field removal — kept on `ClueData` for Phase 2 review (semi-deprecate).
6. No `scope_mode` field removal — changed to uniform `all` values for Phase 1; field deprecation deferred to Phase 2 combination rework.

## Acceptance Criteria

1. `data/yaml/clues.yaml` contains zero `domain:` lines.
2. `data/yaml/clues.yaml` contains zero clues whose `known_text_key` or `known_text` implies physical damage, wear, breakage, rust, or repair.
3. All clue IDs follow `common_<aspect>_<detail>` or `<category_id>_<detail>` format.
4. `data/yaml/affixes.yaml` contains zero `scope_mode: categories` and zero `category_scope` entries.
5. `data/yaml/affixes.yaml` has 18 unique affix IDs with no category prefixes.
6. `data/yaml/affixes.yaml` combination `surface_clue_ids` and `hidden_clue_ids` reference only valid (post-rename) clue IDs.
7. `dev/tools/balance_preview.py` runs without error and contains zero references to `domain`.
8. `dev/tools/validate_yaml.py` passes on the full dataset.
9. `dev/tools/yaml_to_tres.py` regenerates all `.tres` files without error.
10. Game launches and loads without error. No hardcoded clue/anchor/affix ID references exist in GDScript (confirmed by grep audit). A fresh run generates items without errors.
