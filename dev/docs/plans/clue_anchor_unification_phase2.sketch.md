# Clue & Anchor Unification — Phase 2

## Goal

Restore the clue pool after Phase 1's condition-clue removal, then restructure the affix/combination system so category specificity lives at the combination layer rather than the affix layer. Deprecate `scope_mode` entirely. Expand all categories to 3+ sub-type anchors. Rebuild `balance_preview.py` for affix-aware pool statistics. Rebalance the full dataset.

This sketch builds on Phase 1's output: domain is already removed, all clues are generic-named, affix scope is uniform, and anchors for most categories already carry sub-type names.

## Requirements

1. Add new generic surface and hidden clues to fill the pool emptied by Phase 1's condition-clue removal, maintaining or exceeding the original pool depth.
2. Deprecate `scope_mode` field from `AffixData`. All affixes are universal; category gating moves to the combination level.
3. Design ~6–8 common combinations that span all categories, plus a small set of category-specific combinations for truly category-bound clues (brand authenticity, form-specific traits).
4. Expand oil lamp and porcelain figurine to 3+ sub-type anchors each, matching Phase 1's naming pattern.
5. Rewrite `balance_preview.py` to derive per-category clue pools by parsing `affixes.yaml` combinations and their category associations.
6. Run a full rebalance pass against `reference_tables.yaml`, adjusting clue effect amounts, combination weights, and anchor base values so every category falls within its target bands.
7. Update generation prompts to reflect the new combination-level structure and `scope_mode` deprecation.
8. Update `data/definitions/affix_data.gd` and `affix_combination_data.gd` to remove `scope_mode` and add combination-level `category_scope` field.

## Design

### Common Combinations

Six to eight combinations form the universal pool. Every category can draw from these. Each combination bundles a small set of surface and hidden clues that create a coherent affix story.

| Combination | Surface clues (example) | Hidden clues (example) | Story |
|-------------|------------------------|------------------------|-------|
| `comb_fine_material` | common_material_premium, common_detail_gold | fine_leaf_maker_tier3 | High-end materials and finish |
| `comb_budget_material` | common_material_budget, common_material_synthetic | fine_override_counterfeit | Cheap production, possible fake |
| `comb_signed_work` | common_mark_signed, common_provenance_label | fine_leaf_maker_tier1 | Signed, documented, genuine |
| `comb_unsigned_work` | common_mark_unsigned, common_craft_machine | unsigned_override_reproduction | No attribution, suspect |
| `comb_ornate_detail` | common_detail_brass, common_craft_handmade, common_craft_engraved | decorated_leaf_artisan | Elaborate craftsmanship |
| `comb_plain_form` | common_form_standard, common_detail_basic | decorated_override_assembly | Unadorned, possibly kit-built |
| `comb_numbered_edition` | common_mark_edition, common_provenance_tagged | provenance_leaf_limited | Numbered, documented run |
| `comb_aged_character` | common_finish_patina, common_material_aged | antique_leaf_heritage | Natural age, not damage |

### Category-Specific Combinations

Each category keeps 1–2 combinations for clues that only make sense on that item type. These carry `category_scope: [handbag]` or equivalent at the combination level.

| Category | Combination | Clues |
|----------|-------------|-------|
| handbag | `comb_handbag_branded` | handbag_monogram, handbag_blind_stamp + bag_leaf_hermes etc. |
| wristwatch | `comb_watch_movement` | watch_chronograph, watch_jewelled + watch_leaf_roleex etc. |
| oil_lamp | `comb_lamp_glasswork` | lamp_blown_glass + lamp_leaf_moser etc. |
| clock | `comb_clock_casework` | clock_dovetail_joinery + clock_leaf_graham etc. |
| porcelain_figurine | `comb_figurine_pastoral` | figurine_shepherdess_form + figurine_leaf_meissen etc. |
| vase | `comb_vase_cameo` | vase_cameo_body + vase_leaf_tiffany etc. |
| poster | `comb_poster_print` | poster_lithograph + poster_leaf_lautrec etc. |
| painting | `comb_painting_medium` | painting_craquelure + painting_leaf_monet etc. |
| sculpture | `comb_sculpture_technique` | sculpture_lost_wax + sculpture_leaf_rodin etc. |
| pistol | `comb_pistol_lockwork` | pistol_lock_maker + pistol_leaf_boutet etc. |
| rifle | `comb_rifle_marksman` | rifle_precision_sight + rifle_leaf_purdey etc. |
| crossbow | `comb_crossbow_prod` | crossbow_steel_prod + crossbow_leaf_balestrier etc. |

### scope_mode Deprecation

- `AffixData.scope_mode` field kept for backward compat but ignored at runtime. New affixes omit or set to empty.
- `AffixData.category_scope` removed from the affix resource.
- `AffixCombinationData` gains `category_scope: Array[CategoryData]`. Empty or absent means universal (all categories). Populated means only those categories can draw the combination.
- `ItemGenerator._draw_affixes()` becomes category-unaware: every affix is always eligible. Category filtering moves to `_pick_combination()`.
- `ItemGenerator._affix_matches_category()` is deprecated and replaced with `_combination_matches_category()`.

### Anchor Expansion

Oil lamp and porcelain figurine each gain a third anchor variant:

| Category | New anchor | known_text | base_value | tier |
|----------|-----------|------------|------------|------|
| oil_lamp | `lamp_hurricane_01` | Hurricane | 80 → 90 | 1 |
|  | `lamp_student_02` | Student | 320 → 310 | 2 |
|  | `lamp_parlor_03` (new) | Parlor | 550 | 3 |
| porcelain_figurine | `figurine_bisque_01` | Bisque | 50 → 55 | 1 |
|  | `figurine_glazed_02` | Glazed | 280 → 270 | 2 |
|  | `figurine_cabinet_03` (new) | Cabinet | 480 | 3 |

### New Clue Additions

Phase 1 removes ~28 surface and ~12 hidden clues. Phase 2 adds replacements. The goal is not to match count-for-count but to ensure each aspect has enough variety for meaningful combination diversity.

Target additions: ~20 new surface clues, ~10 new hidden clues, distributed across aspects.

New surface clue examples:

```yaml
# Material range
- clue_id: common_material_canvas
- clue_id: common_material_fine_wood
- clue_id: common_material_lacquer
# Detail range
- clue_id: common_detail_engraved
- clue_id: common_detail_enamel
- clue_id: common_detail_marble
# Craft range
- clue_id: common_craft_machine
- clue_id: common_craft_assemble
- clue_id: common_craft_turned
# Mark range
- clue_id: common_mark_inscribed
- clue_id: common_mark_date_code
- clue_id: common_mark_patent
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
- clue_id: common_form_folding
- clue_id: common_form_portable
```

New hidden clue examples:

```yaml
# Generic authenticity scales (exclusive_group: authenticity)
- clue_id: common_leaf_factory  # mul 1.0–1.1, low value
- clue_id: common_leaf_workshop # mul 1.3–1.6, moderate value
- clue_id: common_leaf_studio   # mul 1.8–2.2, high value
- clue_id: common_leaf_atelier  # mul 2.5–3.5, very high value
- clue_id: common_override_assembly_line  # override ~10% of anchor base
# Generic provenance bonuses
- clue_id: common_provenance_exhibition
- clue_id: common_provenance_publication
```

### balance_preview.py Rewrite (Option B — Affix-Aware)

The tool parses `affixes.yaml` to build per-category clue pools:

```
parse all affixes + combinations from YAML
for each category_id:
    eligible_combos = []
    for each combination:
        if combination.category_scope is empty:
            eligible_combos.append(combination)  # universal
        elif category_id in combination.category_scope:
            eligible_combos.append(combination)  # category-specific
    extract all surface_clue_ids from eligible_combos → surface pool
    extract all hidden_clue_ids from eligible_combos → hidden pool
    Monte Carlo sample N items per category using these pools
```

This replaces the `draw_surface_clues()` plain-item fallback entirely. The tool mirrors the runtime `ItemGenerator` flow (affix → combination → clues) rather than inventing its own pool logic.

### Rebalance Targets

After the structure changes, every category must re-land within its `reference_tables.yaml` bands. Adjust:

- Anchor `base_value` (tune by ±10–20% per tier)
- Clue `effect_amount` on new and existing clues
- Combination `weight` in `affixes.yaml`
- Category-specific clue assignment (move a clue from universal to category-specific if its amount is too impactful in other categories)

## Sketch (non-normative)

### Step 1 — Add new clues to `clues.yaml`

```
# Add ~20 new surface clues following the common_<aspect>_<detail>
# convention. Distribute across all aspects to avoid gaps.
# Add ~10 new hidden clues: a generic authenticity scale
# (common_leaf_factory/workshop/studio/atelier), a generic
# override (common_override_assembly_line), and provenance
# bonuses. Every hidden clue carries exclusive_group: authenticity.
#
# Each new clue gets a known_text_key, type, attribute, dc,
# effect_op, and effect_amount within the standard budgets
# (item.md effect budget table).
```

### Step 2 — Expand oil lamp and porcelain figurine anchors

```
# Add lamp_parlor_03 to oil_lamp:
#   known_text_key: ANCHOR_LAMP_PARLOR_03
#   base_value: 550, tier: 3, shape_id: s1x2, weight_kg: 2.2
#
# Add figurine_cabinet_03 to porcelain_figurine:
#   known_text_key: ANCHOR_FIGURINE_CABINET_03
#   base_value: 480, tier: 3, shape_id: s1x1, weight_kg: 0.9
#
# Rename existing oil lamp anchors:
#   lamp_anchor_01 → lamp_hurricane_01
#   lamp_anchor_02 → lamp_student_02
# Rename existing figurine anchors:
#   figurine_anchor_01 → figurine_bisque_01
#   figurine_anchor_02 → figurine_glazed_02
#
# Update known_text_key for renamed anchors to match sub-type.
```

### Step 3 — `data/definitions/affix_data.gd` and `affix_combination_data.gd`

```
# AffixData:
#   Comment scope_mode and category_scope as deprecated for Phase 2 removal.
#   No field deletion yet — backward compat with existing .tres.
#
# AffixCombinationData:
#   Add: @export var category_scope: Array[CategoryData] = []
#   Empty array means universal (all categories can draw this combination).
#   Non-empty restricts the combination to listed categories.
```

### Step 4 — `affixes.yaml`: combination-level category_scope

```
# For each combination entry, add category_scope:
#   - Common combinations: omit or set to [] (universal).
#   - Category-specific combinations: set to [<category_id>].
#
# Example universal combination:
#   - combination_id: comb_fine_material
#     affix_id: fine
#     weight: 3
#     surface_clue_ids: [common_material_premium, common_detail_gold]
#     hidden_clue_ids: [common_leaf_atelier]
#     # no category_scope → universal
#
# Example category-specific combination:
#   - combination_id: comb_handbag_branded
#     affix_id: fine
#     weight: 2
#     category_scope: [handbag]          # new field
#     surface_clue_ids: [handbag_monogram, handbag_blind_stamp]
#     hidden_clue_ids: [bag_leaf_hermes]
#
# Keep all 18 affixes from Phase 1. Each affix now bundles a mix
# of universal and category-specific combinations. This is the
# "combination-level specificity" model.
```

### Step 5 — `ItemGenerator.gd`: combination-level category filter

```gdscript
# In _draw_affixes(): remove the _affix_matches_category() call.
# Every affix in the registry is always eligible.
#
# In _pick_combination(): replace uniform pick with
# category-filtered pick:
#
# static func _pick_combination(
#         affix: AffixData,
#         category: CategoryData,
#         rng: RandomNumberGenerator,
# ) -> AffixCombinationData:
#     var eligible: Array[AffixCombinationData] = []
#     for c in affix.combinations:
#         if _combination_matches_category(c, category):
#             eligible.append(c)
#     # ... weighted pick from eligible
#
# static func _combination_matches_category(
#         combo: AffixCombinationData,
#         category: CategoryData,
# ) -> bool:
#     if combo.category_scope.is_empty():
#         return true
#     return category in combo.category_scope
```

### Step 6 — `balance_preview.py`: full rewrite

```
# Parse all affix data from YAML (or from generated .tres).
# For each category:
#   Collect all combinations where category_scope is empty
#     or contains this category.
#   Build surface_clue_pool and hidden_clue_pool from those
#     combinations' clue_ids.
#   Run Monte Carlo generation using affix draw → combination
#     pick → clue assignment, mirroring ItemGenerator flow.
#   Report per-category statistics against reference_tables.yaml.
#
# Remove old domain-based draw_surface_clues().
# Remove ClueData.domain field.
# New functions: parse_affix_data(), build_category_pools(),
# simulate_affix_draw().
```

### Step 7 — Rebalance

```
# Run balance_preview.py against Phase 2 data.
# For each category where any band is violated:
#   1. Adjust anchor base_value (within tier budgets in item.md).
#   2. Adjust new clue effect_amounts.
#   3. Adjust combination weights to shift probability mass.
#   4. Re-run until all categories land within bands.
#
# Update reference_tables.yaml bands if the Phase 2 design
# intentionally shifts target ranges (approve with user).
```

### Step 8 — Update prompts

```
# item.md:
#   Remove scope_mode from affix schema example.
#   Add combination-level category_scope to Combination Schema.
#   Update "Affix scope mechanism" section to describe the
#     combination-level filter as the active constraint.
#   Update Super-Category Personalities table for new anchor counts.
#
# base.md:
#   Update "scope_mode" references to note deprecation.
#   Add combination-level category_scope to ID conventions section.
```

### Step 9 — Regenerate and validate

```bash
python dev/tools/yaml_to_tres.py
python dev/tools/validate_yaml.py
python dev/tools/yaml_stats.py
python dev/tools/balance_preview.py
# Verify all category bands pass.
```

## Non-Goals

1. No save migration — anchor and clue rename follow the same pattern as Phase 1, handled by existing stale-ID stripping.
2. No `scope_mode` field deletion — commented as deprecated, left on `AffixData` for now.
3. No localization population — `known_text_key` entries are defined in YAML but translation source files are not populated in this phase.
4. No tutorial update beyond what Phase 1 already handles — tutorial data is small and self-contained.

## Acceptance Criteria

1. Oil lamp and porcelain figurine each have 3+ anchors with distinct sub-type `known_text_key`.
2. `affixes.yaml` contains ~6–8 common combinations with empty or absent `category_scope` and ~12 category-specific combinations with populated `category_scope`.
3. `AffixCombinationData` resource exposes `category_scope` (exported, empty by default).
4. `ItemGenerator._pick_combination()` filters by `category_scope`; `_affix_matches_category()` is bypassed.
5. `balance_preview.py` derives per-category clue pools from affix/combination data and reports category statistics against `reference_tables.yaml`.
6. All 12 categories fall within their `reference_tables.yaml` bands after rebalance.
7. `validate_yaml.py` passes on the full dataset.
8. `yaml_to_tres.py` regenerates all `.tres` files without error.
9. Game launches. A run generates items where every displayed item name is `{affix_display} {anchor_display}` with no category-prefix artifacts.
