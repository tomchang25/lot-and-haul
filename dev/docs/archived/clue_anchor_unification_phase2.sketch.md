# Clue & Anchor Unification — Phase 2

## Goal

Restore the clue pool after Phase 1's condition-clue removal. Expand `exclusive_group` to all clues (surface + hidden) and add an affix-level conflict exclusion system so the draw engine can prevent semantically impossible combinations. Change affix draw rules to allow at most 2 affixes with at least 1 prefix. Add combination-level `category_scope` as an optional supplementary gate. Expand oil lamp and porcelain figurine to 3+ sub-type anchors. Rewrite `balance_preview.py` to simulate the full affix→combination→clue flow with conflict rejection. Rebalance the full dataset against `reference_tables.yaml`.

`scope_mode` is kept — `all` is the recommended default, `categories` remains a valid special case for test data and tightly-scoped designs. No field deletion.

This sketch builds on Phase 1's output: domain is removed, all clues are generic-named, affix scope is uniform, and anchors for most categories already carry sub-type names.

## Requirements

1. Add new generic surface and hidden clues to fill the pool emptied by Phase 1's condition-clue removal, maintaining or exceeding original pool depth.
2. Expand `exclusive_group` field semantics from hidden-only to all clues (surface and hidden). Use exclusive groups as the primary semantic conflict check — at most one clue per group per item. Assign groups for common mutually-exclusive pairs (signed vs unsigned, premium vs budget material, handmade vs machine, authenticity leaf vs override).
3. Add affix-level conflict exclusion system so the draw engine rejects incompatible affix pairs. Use a group-based model over per-ID exclusion lists.
4. Change affix draw rules: every item draws at most 2 affixes (≥1 prefix; suffix capped at 1). Legal patterns: 1 prefix, 2 prefixes, 1 prefix + 1 suffix.
5. Add combination-level `category_scope: [<category_id>]` to `AffixCombinationData` as an optional supplementary gate. Empty or absent = universal.
6. Design ~6–8 common combinations that span all categories, plus ~12 category-specific combinations for truly category-bound clues (brand authenticity, form-specific traits).
7. Expand oil lamp and porcelain figurine to 3+ sub-type anchors each, matching Phase 1's naming pattern.
8. Rewrite `balance_preview.py` to simulate the full generation flow (affix draw → combination pick → clue assignment → conflict rejection) and report per-category statistics against `reference_tables.yaml`.
9. Run a full rebalance pass against `reference_tables.yaml`, adjusting clue effect amounts, combination weights, and anchor base values so every category falls within its target bands.
10. Update generation prompts (`item.md`, `base.md`, `affix.md`) to reflect expanded exclusive_group, affix exclusion, new draw rules, and combination-level `category_scope`.
11. Update `AffixCombinationData` resource to expose `category_scope`. Update `AffixData` to expose `excluded_affix_groups`. Update `ClueData` docstring to note `exclusive_group` applies to all clue types.

## Design

### Expanded exclusive_group — All Clues

The existing `exclusive_group` on `ClueData` is broadened from hidden-only to all clues. At most one clue per group per item across both surface and hidden.

This replaces the need for per-ID exclusion lists. Example groups:

| Group                 | Mutually-exclusive clues                              |
| --------------------- | ----------------------------------------------------- |
| `mark_signature`      | `common_mark_signed_*` vs `common_mark_unsigned_*`    |
| `material_quality`    | `common_material_premium` vs `common_material_budget` |
| `production_method`   | `common_craft_handmade` vs `common_craft_machine`     |
| `identity_handbag`    | `bag_leaf_*` vs `common_override_reproduce`           |
| `identity_wristwatch` | `watch_leaf_*` vs `common_override_fake`              |
| `identity_oil_lamp`   | `lamp_leaf_*` vs `common_override_kit`                |
| `identity_clock`      | `clock_leaf_*` vs `common_override_kit`               |
| `identity_figurine`   | `figurine_leaf_*` vs `common_override_reproduce`      |
| `identity_vase`       | `vase_leaf_*` vs `common_override_reproduce`          |
| `identity_poster`     | `poster_leaf_*` vs `common_override_reproduce`        |
| `identity_painting`   | `painting_leaf_*` vs `common_override_fake`           |
| `identity_sculpture`  | `sculpture_leaf_*` vs `common_override_reproduce`     |
| `identity_pistol`     | `pistol_leaf_*` vs `common_override_kit`              |
| `identity_rifle`      | `rifle_leaf_*` vs `common_override_kit`               |
| `identity_crossbow`   | `crossbow_leaf_*` vs `common_override_reproduce`      |

Existing authenticity groups (`authenticity_handbag`, etc.) remain on hidden clues. Phase 2 adds semantic groups on surface clues that can collide across affix-combination boundaries.

### Affix Exclusion System

Each affix carries an optional `excluded_affix_groups: [<string>]` array. When two affixes share at least one excluded group, they cannot be drawn together on the same item.

Example:

```yaml
# Fine and signed-work affixes are incompatible with budget/unsigned.
- affix_id: fine
  excluded_affix_groups: [budget_production]

- affix_id: antique
  excluded_affix_groups: [modern_production]
```

Groups partition the affix space into mutually-exclusive families. A new affix just declares which families it's incompatible with — no per-ID maintenance.

### Affix Draw Rules (≥1 prefix, ≤2 total)

Replaces the current "0–1 prefix + 0–1 suffix" rule:

1. At least 1 prefix is always drawn.
2. At most 2 affixes total per item.
3. At most 1 suffix per item.
4. Affixes sharing an `excluded_affix_groups` entry are rejected.
5. After drawing, if the pair is invalid, re-pick the second affix (up to N retries), then drop to single-affix if no valid pair is found.

Legal draw outcomes:

| Pattern | Example                |
| ------- | ---------------------- |
| 1-P     | `Antique Lamp`         |
| 2-P     | `Fine Engraved Pistol` |
| 1-P-S   | `Fine Vase Cameo`      |

### scope_mode Policy

`scope_mode` and `category_scope` on `AffixData` are kept. No deprecation, no field deletion.

- `scope_mode: all` is the recommended default for the 18 Phase 1 affixes.
- `scope_mode: categories` remains valid for test affixes and tightly-scoped designs.
- Most category filtering is handled by combination-level `category_scope` (below) and `exclusive_group` rejection — affix-level scope is a coarse pre-filter, not the primary constraint.

### Combination-Level category_scope

`AffixCombinationData` gains `category_scope: Array[CategoryData]` (exported, empty by default). Empty or absent means universal — any category can draw this combination. Populated means only those categories can draw it.

This is supplementary to `exclusive_group` and `excluded_affix_groups` — it gates which combinations a category sees, not whether the affix itself is eligible.

### Common Combinations

Six to eight common combinations (prefixed `comb_common_*` to avoid collision with existing IDs like `comb_fine_01`):

| Combination                 | Surface clues                                           | Hidden clues                  | Story                           |
| --------------------------- | ------------------------------------------------------- | ----------------------------- | ------------------------------- |
| `comb_common_fine_material` | common_material_crocodile, common_detail_brass          | common_leaf_atelier           | Premium materials and finish    |
| `comb_common_budget`        | common_material_synthetic, common_craft_offset_print    | common_override_assembly_line | Cheap production, possible fake |
| `comb_common_signed`        | common*mark_signed*\*, common_provenance_label          | common_leaf_studio            | Signed, documented, genuine     |
| `comb_common_unsigned`      | common*mark_unsigned*\*, common_craft_quartz            | common_leaf_factory           | No attribution, mass-produced   |
| `comb_common_ornate`        | common_detail_gilded_case, common_craft_handmade        | common_leaf_atelier           | Elaborate craftsmanship         |
| `comb_common_plain`         | common_form_short_barrel, common_detail_iron_fittings   | common_leaf_workshop          | Functional, unadorned           |
| `comb_common_edition`       | common_mark_edition, common_provenance_tagged           | common_provenance_exhibition  | Numbered, documented run        |
| `comb_common_aged`          | common_finish_patina_dial, common_finish_patina_natural | common_leaf_heritage          | Natural age character           |

### Category-Specific Combinations

Each category keeps 1–2 combinations for clues that only make sense on that item type. These carry `category_scope: [<category_id>]` at the combination level.

| Category           | Combination                | category_scope         | Key clues                                                                 |
| ------------------ | -------------------------- | ---------------------- | ------------------------------------------------------------------------- |
| handbag            | `comb_handbag_branded`     | `[handbag]`            | handbag_monogram, common_mark_blind_stamp, bag_leaf_hermes                |
| wristwatch         | `comb_watch_movement`      | `[wristwatch]`         | watch_chronograph, common_detail_jewelled, watch_leaf_roleex              |
| oil_lamp           | `comb_lamp_glasswork`      | `[oil_lamp]`           | lamp_blown_glass, common_detail_scrollwork, lamp_leaf_moser               |
| clock              | `comb_clock_casework`      | `[clock]`              | clock_dovetail_joinery, common_detail_gilded_case, clock_leaf_graham      |
| porcelain_figurine | `comb_figurine_pastoral`   | `[porcelain_figurine]` | figurine_shepherdess_form, common_material_celadon, figurine_leaf_meissen |
| vase               | `comb_vase_cameo`          | `[vase]`               | vase_cameo_body, common_material_cased_glass, vase_leaf_tiffany           |
| poster             | `comb_poster_print`        | `[poster]`             | poster_lithograph, common_material_linen, poster_leaf_lautrec             |
| painting           | `comb_painting_medium`     | `[painting]`           | painting_craquelure, common_medium_oil, painting_leaf_monet               |
| sculpture          | `comb_sculpture_technique` | `[sculpture]`          | sculpture_lost_wax, common_medium_bronze, sculpture_leaf_rodin            |
| pistol             | `comb_pistol_lockwork`     | `[pistol]`             | pistol_lock_maker, common_craft_lock_fitted, pistol_leaf_boutet           |
| rifle              | `comb_rifle_marksman`      | `[rifle]`              | rifle_precision_sight, common_mark_proof_stamped_rifle, rifle_leaf_purdey |
| crossbow           | `comb_crossbow_prod`       | `[crossbow]`           | crossbow_steel_prod, common_form_trigger_mech, crossbow_leaf_balestrier   |

### Anchor Expansion

Oil lamp and porcelain figurine each gain a third anchor variant with sub-type names:

| Category           | New anchor                  | known_text | base_value | tier |
| ------------------ | --------------------------- | ---------- | ---------- | ---- |
| oil_lamp           | `lamp_hurricane_01`         | Hurricane  | 90         | 1    |
|                    | `lamp_student_02`           | Student    | 310        | 2    |
|                    | `lamp_parlor_03` (new)      | Parlor     | 550        | 3    |
| porcelain_figurine | `figurine_bisque_01`        | Bisque     | 55         | 1    |
|                    | `figurine_glazed_02`        | Glazed     | 270        | 2    |
|                    | `figurine_cabinet_03` (new) | Cabinet    | 480        | 3    |

### New Clue Additions

Phase 1 removes ~28 surface and ~12 hidden clues. Phase 2 adds ~20 new surface and ~10 new hidden clues distributed across aspects. IDs that clash with existing Phase 1 output are renamed (see examples — names marked `?`).

New surface clue examples:

```yaml
# Material range
- clue_id: common_material_fine_wood
- clue_id: common_material_lacquer
- clue_id: common_material_compressed
# Detail range
- clue_id: common_detail_enamel
- clue_id: common_detail_marble
- clue_id: common_detail_stone_inlay
# Craft range
- clue_id: common_craft_machine
- clue_id: common_craft_turned
- clue_id: common_craft_assembled
# Mark range
- clue_id: common_mark_inscribed
- clue_id: common_mark_patent
- clue_id: common_mark_monogram
# Provenance range
- clue_id: common_provenance_auction_record
- clue_id: common_provenance_certificate
- clue_id: common_provenance_collection
# Medium range
- clue_id: common_medium_watercolor
- clue_id: common_medium_terracotta
- clue_id: common_medium_iron
# Form range
- clue_id: common_form_collapsible
- clue_id: common_form_portable
```

New hidden clue examples (generic authenticity scale):

```yaml
# exclusive_group: authenticity_common
- clue_id: common_leaf_factory # mul 1.0–1.1, low value
- clue_id: common_leaf_workshop # mul 1.3–1.6, moderate value
- clue_id: common_leaf_studio # mul 1.8–2.2, high value
- clue_id: common_leaf_atelier # mul 2.5–3.5, very high value
- clue_id: common_leaf_heritage # mul 1.5–2.0, natural aged authenticity
- clue_id: common_override_assembly_line # override ~10% of anchor base
# Provenance bonuses (no group — stackable)
- clue_id: common_provenance_exhibition
- clue_id: common_provenance_publication
```

### balance_preview.py Rewrite

The tool simulates the full generation flow rather than inventing its own pool logic:

```
load all affixes + combinations from YAML
for each category_id:
    for each combination:
        if combination.category_scope is empty or contains category_id:
            add to category's eligible combinations
    run Monte Carlo:
        for N items:
            draw 1 prefix (always)
            draw optional 2nd affix (prefix or suffix)
            check excluded_affix_groups → reject if conflict
            for each drawn affix, weight-pick combination from eligible set
            resolve clue conflicts via exclusive_group check
            compute value via price pipeline
    report per-category statistics against reference_tables.yaml bands
```

Mirrors `ItemGenerator.gd` flow: affix draw → exclusion check → combination pick → clue assignment → conflict resolution → value computation.

### Rebalance Targets

After structure changes, every category must land within its `reference_tables.yaml` bands. Adjust:

- Anchor `base_value` (±10–20% per tier)
- Clue `effect_amount` on new and existing clues
- Combination `weight` in `affixes.yaml`
- Category-specific clue assignment (move a clue from universal to category-specific if its amount distorts other categories)
- `excluded_affix_groups` to prevent combinations with extreme value overlaps

## Sketch (non-normative)

### Step 1 — Expand exclusive_group + ClueData comment

```
# clue_data.gd:
#   Change: "Hidden clues only; ignored on surface."
#   To:     "Applies to both surface and hidden clues."
#
# clues.yaml:
#   Assign exclusive_group to surface clues that form
#   mutually-exclusive pairs (signed/unsigned, premium/budget,
#   handmade/machine). Existing hidden authenticity groups stay.
```

### Step 2 — Add clue data fields (AffixData + AffixCombinationData)

```
# AffixData:
#   Add: @export var excluded_affix_groups: Array[String] = []
#   Empty array means no exclusion — this affix can pair with any other.
#   scope_mode and category_scope are kept — no deprecation comment.
#
# AffixCombinationData:
#   Add: @export var category_scope: Array[CategoryData] = []
#   Empty array means universal (all categories).
```

### Step 3 — Update tres_lib/entities/affix.py

```
# AffixSpec.build_tres():
#   Add excluded_affix_groups export (same pattern as prefix/suffix fields).
#
# AffixCombinationSpec.build_tres():
#   Add category_scope ext-ref array (same pattern as surface_clues/hidden_clues).
#
# AffixCombinationSpec.validate():
#   Validate category_scope entries against known categories.
```

### Step 4 — Affix draw rules in ItemGenerator.gd

```gdscript
# In draw() — always draw at least one prefix:
#   1. Draw 1 prefix (mandatory).
#   2. Optionally draw 1 more affix (prefix or suffix, not already drawn).
#   3. If the pair shares an excluded_affix_groups entry, re-pick the
#      second affix (up to 3 retries). Fall back to single-affix.
#
# In _draw_affixes(): rewritten to enforce ≥1 prefix, ≤2 total, ≤1 suffix.
#
# In _pick_combination():
#   Add category parameter.
#   Filter combinations by category_scope:
#     if combo.category_scope.is_empty() → eligible
#     elif category in combo.category_scope → eligible
#     else → skip
#
# Conflict resolution (_resolve_conflicts) already checks
# exclusive_group and double-override for surface + hidden combined.
# No change needed for that function.
```

### Step 5 — Add new clues to clues.yaml

```
# Add ~20 new surface clues following common_<aspect>_<detail> convention.
# Add ~10 new hidden clues: generic authenticity scale
# (common_leaf_factory/workshop/studio/atelier/heritage),
# override (common_override_assembly_line), and provenance bonuses.
#
# Assign exclusive_group where applicable.
# Each new clue gets known_text_key, type, attribute, dc,
# effect_op, and effect_amount within standard budgets
# (item.md effect budget table).
```

### Step 6 — Expand oil lamp and porcelain figurine anchors

```
# Add lamp_parlor_03:
#   known_text_key: ANCHOR_LAMP_PARLOR_03
#   base_value: 550, tier: 3
# Rename: lamp_anchor_01 → lamp_hurricane_01 (base: 90)
#         lamp_anchor_02 → lamp_student_02 (base: 310)
#
# Add figurine_cabinet_03:
#   known_text_key: ANCHOR_FIGURINE_CABINET_03
#   base_value: 480, tier: 3
# Rename: figurine_anchor_01 → figurine_bisque_01 (base: 55)
#         figurine_anchor_02 → figurine_glazed_02 (base: 270)
#
# Update known_text_key and localization files.
```

### Step 7 — Restructure affixes.yaml

```
# Add excluded_affix_groups to affixes where applicable:
#   fine → [budget_production]
#   antique → [modern_production]
#   unsigned → [signed_work]
#   modern → [antique_vibe]
#
# Add ~6–8 comb_common_* combinations with no category_scope.
# Add ~12 category-specific combinations with category_scope.
#
# Existing comb_antique_01 etc. remain as-is from Phase 1 for
# backward compat; they can be migrated to the new naming in
# a later phase or left as historical data.
#
# Each affix now bundles a mix of common + category-specific
# combinations via its combination_ids list.
```

### Step 8 — Rewrite balance_preview.py

```
# Remove draw_surface_clues() plain-item fallback.
# Add:
#   build_category_pools() — from affix+combination data,
#     produce per-category eligible combination lists.
#   simulate_affix_draw() — enforce ≥1 prefix, ≤2 total,
#     exclusion check, combination pick with category_scope
#     filter, clue conflict resolution.
#   Monte Carlo per-category (not per-lot) to validate
#     against reference_tables.yaml bands.
#
# Report which categories violate which bands.
```

### Step 9 — Rebalance

```
# Run balance_preview.py against Phase 2 data.
# For each category where any band is violated:
#   1. Adjust anchor base_value (within tier budgets).
#   2. Adjust new clue effect_amounts.
#   3. Adjust combination weights to shift probability mass.
#   4. Assign or re-assign exclusive_group on problematic clues.
#   5. Re-run until all categories land within bands.
```

### Step 10 — Update generation prompts

```
# item.md:
#   Update exclusive_group description: "applies to surface and hidden".
#   Add combination-level category_scope to Combination Schema.
#   Remove scope_mode deprecation language.
#   Update Super-Category Personalities table for new anchor counts.
#
# base.md:
#   Keep scope_mode as valid field with "all" recommended.
#   Add excluded_affix_groups to ID conventions section.
#   Add combination-level category_scope to ID conventions.
#   Update exclusive_group note: "applies to all clue types".
#
# affix.md:
#   Keep scope_mode: all | categories with "all" as recommended standard.
#   Add excluded_affix_groups field description.
#   Update ID conventions for comb_common_* naming.
#   Update example to show excluded_affix_groups usage.
```

### Step 11 — Regenerate and validate

```bash
python dev/tools/yaml_to_tres.py
python dev/tools/validate_yaml.py
python dev/tools/yaml_stats.py
python dev/tools/balance_preview.py
# Verify all category bands pass.
```

## Non-Goals

1. No save migration — anchor and clue rename follow the same pattern as Phase 1, handled by existing stale-ID stripping.
2. No `scope_mode` field deletion — kept with `all` as recommended default; `categories` remains a valid option for test data and tightly-scoped designs.
3. No per-ID exclusion lists — use group-based exclusion (`excluded_affix_groups`, `exclusive_group`) rather than enumerating conflicting clue/affix IDs.
4. No localization population — `known_text_key` entries are defined in YAML but translation source files are not populated in this phase.
5. No tutorial update beyond what Phase 1 already handles.

## Acceptance Criteria

1. `exclusive_group` on `ClueData` applies to surface and hidden clues. At least 2 semantic groups are assigned across the surface clue pool beyond the existing authenticity groups.
2. `AffixData` exposes `excluded_affix_groups` (Array[String], empty by default). At least 3 affixes carry exclusion groups.
3. `AffixCombinationData` exposes `category_scope` (Array[CategoryData], empty = universal).
4. `ItemGenerator` draws ≥1 prefix, ≤2 total affixes per item, respects `excluded_affix_groups`.
5. `ItemGenerator._pick_combination()` filters by combination-level `category_scope`.
6. Oil lamp and porcelain figurine each have 3+ anchors with distinct sub-type `known_text_key`.
7. `affixes.yaml` contains ~6–8 `comb_common_*` combinations and ~12 category-specific combinations with `category_scope`.
8. `balance_preview.py` simulates the full affix→combination→clue flow with exclusion checks and reports per-category statistics against `reference_tables.yaml`.
9. All 12 categories fall within their `reference_tables.yaml` bands after rebalance.
10. `validate_yaml.py` passes. `yaml_to_tres.py` regenerates all `.tres` without error.
11. `dev/tools/prompts/yaml_generation/` files reflect the updated conventions (expanded exclusive_group, excluded_affix_groups, combination category_scope, new affix draw rules). `scope_mode` is kept with `all` as the recommended value, `categories` as a valid special case.
