# Lot & Haul — Affix YAML Generation Standard

Use this with `base.md` when generating affix data for `data/yaml/affixes.yaml`.

Affixes are drawn after the anchor and before clues during item generation: draw category → anchor → affixes (≥1 prefix, ≤2 total, ≤1 suffix) → one weighted combination per affix → that combination's surface and hidden clues. Affixes are the primary index for item naming (Spec B) and the knowledge dictionary (Spec C).

---

## Output Root

The YAML must begin with both keys:

```yaml
affix_combinations:

affixes:
```

Combinations always list first — the pipeline builds their UIDs before affixes reference them.

---

## Affix Schema (`affixes:` block)

```yaml
affixes:
  - affix_id: snake_case string
    naming_slot: prefix | suffix
    display_name: string
    scope_mode: all | categories
    excluded_affix_groups:
      - <group_name>
    category_scope:
      - <category_id>
    weight: <positive int>
    combination_ids:
      - <combination_id>
      - <combination_id>
```

### Fields

- `affix_id`: unique snake_case ID across all affixes. After Phase 1 merge, most affixes use unprefixed IDs like `antique`, `fine`, `service` with `scope_mode: all`. Category-prefixed IDs (e.g. `bag_rustic`) are still valid for special cases but are no longer the default.
- `naming_slot`: `prefix` or `suffix`. Controls display-name composition in Spec B. At most 3 affixes can be drawn per item (LEGENDARY), with max 2 prefixes and max 2 suffixes. Only prefix × suffix and prefix × prefix cross-product conflicts are validated — the validator checks all active combinations.
- `display_name_key`: localization key for the human-readable label (e.g. `AFFIX_ANTIQUE`).
- `scope_mode`: controls draw eligibility. **`all`** (preferred) — this affix can appear on any category. `categories` — this affix applies only to the listed `category_scope` entries (use for test data or category-restricted designs).
- `category_scope`: list of snake_case category ids this affix applies to when `scope_mode: categories`. Each id must match a category in `category_data.yaml`. Omit or leave empty when `scope_mode: all`.
- `excluded_affix_groups`: optional list of group names. When set, this affix cannot coexist on the same item with any other affix sharing a group in this list. Used to prevent conflicting affix pairs (e.g. two material affixes on one item). Omit when no exclusion is needed.
- `weight`: relative draw weight. Higher = more frequent. Must be a positive int.
- `combination_ids`: list of combination ids belonging to this affix. Order sets ext-resolve order but has no functional weight. Every id must be defined in the `affix_combinations:` block.

---

## Combination Schema (`affix_combinations:` block)

```yaml
affix_combinations:
  - combination_id: snake_case string
    affix_id: <affix_id>
    weight: <positive int>
    category_scope:
      - <category_id>
    surface_clue_ids:
      - <surface clue_id>
      - <surface clue_id>
    hidden_clue_ids:
      - <hidden clue_id>
```

### Fields

- `combination_id`: unique snake*case ID across all combinations. Prefer `comb*<category*key>*<affix_descriptor>\_NN`(e.g.`comb_bag_rustic_01`).
- `affix_id`: the parent affix. Must match an `affix_id` in the `affixes:` block.
- `weight`: relative draw weight among this affix's combinations. Must be a positive int.
- `surface_clue_ids`: list of surface clue ids contributed by this combination. Every id must reference an existing `clue_id` in `clues.yaml` with `type: surface`.
- `hidden_clue_ids`: list of hidden clue ids contributed by this combination. Every id must reference an existing `clue_id` in `clues.yaml` with `type: hidden`.

---

## Conflict Rules (validator-enforced)

The build-time validator checks all affix pair cross-products whose scopes overlap (`scope_mode: all` overlaps everything; `scope_mode: categories` overlaps shared category ids) across all combinations in each affix's cross-product. Since up to 3 affixes (LEGENDARY) can be drawn per item, all pair combinations are validated. The merged clue set must satisfy:

1. **No duplicate exclusive_group.** Two clues on the same item must never share an `exclusive_group`.
2. **At most one `effect_op: override`.** Two override clues on the same item are illegal.

Within a single combination: combinations are mutually exclusive at draw time, so having two clues in the same group inside one combination is fine — the item will only ever receive one of them. The validator still checks for double-override within a single combination as a sanity check, but a combination that carries one hidden override and one hidden mul with no group is valid.

---

## Clue Pools

Combinations draw from the **existing** clue pools in `data/yaml/clues.yaml`. Do not invent new clue ids in the affix YAML — every `surface_clue_id` and `hidden_clue_id` must already be defined.

A combination typically bundles:

- **1–3 surface clues** that thematically fit the affix (material, condition, feature).
- **0–1 hidden clues** that represent the affix's true identity reveal — a genuine-maker `_leaf_` clue, a counterfeit `_override_` clue, or a condition-based negative.

#### Negative Effect Tiers

All value-reducing `mul` clues must use one of these tiers — never use negative `add`:

| Tier                | Range     | Use Case                                       |
| ------------------- | --------- | ---------------------------------------------- |
| Minor Defect        | 0.80–0.95 | Cosmetic imperfection, light wear              |
| Missing/Compromised | 0.50–0.75 | Missing/non-original part, significant flaw    |
| Severe Damage       | 0.25–0.40 | Major structural damage, extensive degradation |
| Counterfeit/Forgery | override  | Hidden-only base-value replacement             |

## Thematic Bundling

Affixes should group clues that tell a coherent story:

- A **Rustic** handbag affix bundles worn/faded/tarnished surface clues (Minor Defect tier) and a lower-tier leaf or a replica override.
- A **Luxury** handbag affix bundles premium material/hardware surface clues and a high-end leaf — or an override replica as the minority risk.
- A **Vintage** watch affix bundles patina/winding surface clues (Minor Defect tier) and a period-correct leaf.
- A **Modern** watch affix bundles quartz/chronograph surface clues and a contemporary leaf.

Each affix should offer at least one positive path and one negative/minority path across its combinations (the "bet" the player makes by Authenticating). Negative paths should use `mul < 1.0` at the appropriate tier for the flaw theme.

---

## Weighting

### Affix weight

Controls how often the affix appears on items in its category. For the initial playtest:

- Start at 2–3 for standard affixes.
- Use higher weights for common-vibe affixes (e.g. everyday-worn, mass-market).
- Use lower weights for rare-vibe affixes (one-off, extreme values).

Most items should remain **plain** (no affix drawn). Affix weights are calibrated against the _absence_ of any affix, not against each other. If total affix weight for a category is too high relative to the plain-item probability, everything becomes affixed and rarity distributes oddly. Rarity now drives affix count (COMMON=1, RARE=2, LEGENDARY=3); affix weights continue to calibrate relative draw frequency among eligible affixes within each slot.

### Combination weight

Controls which combination an affix lands on once drawn. For the initial playtest:

- The genuine/positive path should be the majority (weight 2–3).
- The counterfeit/negative path should be the minority (weight 1).

The example "bag_luxury" affix has three combinations: two genuine at weight 2 each, one replica at weight 1. The player has a 4/5 chance of a real luxury item and 1/5 chance of a high-grade fake — a bet worth taking.

---

## Structural Naming Requirements (Spec B)

Each affix must provide its `naming_slot` and `display_name` so that Spec B (naming composition) can qualify the item's display name. A `prefix` affix with `display_name: Rustic` becomes "Rustic Bag" when the anchor is "Bag". A `suffix` affix joins the game-terminology slot.

The naming system is deferred — this field is authored now so it round-trips through `.tres` and is ready when Spec B lands.

---

## ID Conventions

```
<unprefixed_descriptor>                — affix_id (antique, fine, service, modern)
comb_<descriptor>_NN                   — combination_id (comb_antique_01)
comb_<category>_<descriptor>_NN        — combination_id for category-specific affixes (comb_bag_rustic_01)
```

After Phase 1 merge, most affix IDs are unprefixed and use `scope_mode: all`. Category-prefixed IDs (`bag_rustic`, `watch_vintage`) are still valid for special/restricted cases.

---

## Valid Category IDs

```
handbag  wristwatch  oil_lamp  clock  porcelain_figurine
vase  poster  painting  sculpture  pistol  rifle  crossbow
```

---

## Validation Checklist

- `affix_combinations:` and `affixes:` blocks are present, combinations listed first.
- Every `affix_id` is unique and snake_case.
- Every `combination_id` is unique and snake_case.
- Every affix has `naming_slot` (`prefix` or `suffix`), `display_name`, `scope_mode`, `category_scope`, `weight`, and at least one `combination_id`.
- Every combination has `affix_id`, `weight`, and references at least one clue across `surface_clue_ids` and `hidden_clue_ids`.
- `scope_mode: all` is the standard (no `category_scope` needed). `scope_mode: categories` is valid with at least one `category_scope` entry.
- `excluded_affix_groups` entries must reference defined group names; affixes with overlapping `excluded_affix_groups` must never co-occur in validation.
- Every `affix_id` referenced in a combination matches a defined affix.
- Every clue id in `surface_clue_ids` and `hidden_clue_ids` exists in `clues.yaml` with the correct type.
- Every `weight` is a positive int (both affix-level and combination-level).
- No prefix × suffix cross-product carries a duplicate `exclusive_group` or double `override`.
- `category_scope` on a combination, if present, must contain valid category IDs; the combination's scope is the intersection of its own `category_scope` and its parent affix's scope.
- At least one combination per affix provides a positive discovery path; at least one provides a minority negative path.

---

## Example

```yaml
affix_combinations:
  - combination_id: comb_antique_01
    affix_id: antique
    weight: 3
    surface_clue_ids:
      - common_material_leather
    hidden_clue_ids:
      - bag_leaf_coach

  - combination_id: comb_antique_02
    affix_id: antique
    weight: 1
    surface_clue_ids:
      - common_material_synthetic
    hidden_clue_ids:
      - common_override_reproduce

affixes:
  - affix_id: antique
    naming_slot: prefix
    display_name_key: AFFIX_ANTIQUE
    scope_mode: all
    weight: 3
    combination_ids:
      - comb_antique_01
      - comb_antique_02
```

This affix is drawn at weight 3 versus the plain-item baseline. With `scope_mode: all`, it is eligible for every category. When drawn, the chosen combination supplies the surface clues — "Leather Bag" for comb_01 (a genuine path) or "Synthetic Bag" for comb_02 (a counterfeit risk). The hidden clue in the genuine path reveals a maker leaf with a high mul multiplier; the counterfeit path collapses to the override base. Categories with their own category-specific affixes still draw them because each affix's draw is independent.
