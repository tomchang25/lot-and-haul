# Lot & Haul — Affix YAML Generation Standard

Use this with `base.md` when generating affix data for `data/yaml/affixes.yaml`.

Affixes are drawn after the anchor and before clues during item generation: draw category → anchor → affixes (0–1 prefix + 0–1 suffix) → one weighted combination per affix → that combination's surface and hidden clues. Affixes are the primary index for item naming (Spec B) and the knowledge dictionary (Spec C).

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
    category_scope:
      - <category_id>
    weight: <positive int>
    combination_ids:
      - <combination_id>
      - <combination_id>
```

### Fields

- `affix_id`: unique snake*case ID across all affixes. Prefer `<category_key>*<descriptor>`(e.g.`bag_rustic`, `watch_vintage`).
- `naming_slot`: `prefix` or `suffix`. Controls display-name composition in Spec B. At most one prefix and one suffix can be drawn per item, so only prefix × suffix cross-product conflicts are validated — two prefixes on the same category never combine.
- `display_name`: human-readable label for debug and UI (e.g. `Rustic`, `Vintage`).
- `scope_mode`: `categories` means this affix applies only to `category_scope`; `all` means this affix can appear on any category.
- `category_scope`: list of snake_case category ids this affix applies to when `scope_mode: categories`. Each id must match a category in `category_data.yaml`. Use an empty list only when `scope_mode: all`.
- `weight`: relative draw weight. Higher = more frequent. Must be a positive int.
- `combination_ids`: list of combination ids belonging to this affix. Order sets ext-resolve order but has no functional weight. Every id must be defined in the `affix_combinations:` block.

---

## Combination Schema (`affix_combinations:` block)

```yaml
affix_combinations:
  - combination_id: snake_case string
    affix_id: <affix_id>
    weight: <positive int>
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

The build-time validator checks every prefix × suffix affix pair whose scopes overlap (`scope_mode: all` overlaps everything; `scope_mode: categories` overlaps shared category ids) across all combinations in each affix's cross-product. The merged clue set must satisfy:

1. **No duplicate exclusive_group.** Two hidden clues on the same item must never share an `exclusive_group`.
2. **At most one `effect_op: override`.** Two override clues on the same item are illegal.

Since at most one prefix and one suffix are drawn per item, prefix × prefix and suffix × suffix pairs are not validated — they can never co-occur.

Within a single combination: combinations are mutually exclusive at draw time, so having two clues in the same group inside one combination is fine — the item will only ever receive one of them. The validator still checks for double-override within a single combination as a sanity check, but a combination that carries one hidden override and one hidden mul with no group is valid.

---

## Clue Pools

Combinations draw from the **existing** clue pools in `data/yaml/clues.yaml`. Do not invent new clue ids in the affix YAML — every `surface_clue_id` and `hidden_clue_id` must already be defined.

A combination typically bundles:

- **1–3 surface clues** that thematically fit the affix (material, condition, feature).
- **0–1 hidden clues** that represent the affix's true identity reveal — a genuine-maker `_leaf_` clue, a counterfeit `_override_` clue, or a condition-based negative.

### Thematic Bundling

Affixes should group clues that tell a coherent story:

- A **Rustic** handbag affix bundles worn/faded/tarnished surface clues and a lower-tier leaf or a replica override.
- A **Luxury** handbag affix bundles premium material/hardware surface clues and a high-end leaf — or an override replica as the minority risk.
- A **Vintage** watch affix bundles patina/winding surface clues and a period-correct leaf.
- A **Modern** watch affix bundles quartz/chronograph surface clues and a contemporary leaf.

Each affix should offer at least one positive path and one negative/minority path across its combinations (the "bet" the player makes by Authenticating).

---

## Weighting

### Affix weight

Controls how often the affix appears on items in its category. For the initial playtest:

- Start at 2–3 for standard affixes.
- Use higher weights for common-vibe affixes (e.g. everyday-worn, mass-market).
- Use lower weights for rare-vibe affixes (one-off, extreme values).

Most items should remain **plain** (no affix drawn). Affix weights are calibrated against the _absence_ of any affix, not against each other. If total affix weight for a category is too high relative to the plain-item probability, everything becomes affixed and rarity distributes oddly.

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
<category_key>_<descriptor>            — affix_id (bag_rustic, watch_vintage)
comb_<category_key>_<descriptor>_NN    — combination_id (comb_bag_rustic_01)
```

Short category prefixes are fine (`bag_`, `watch_`, `lamp_`).

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
- `scope_mode: categories` has at least one valid `category_scope` entry; `scope_mode: all` has an empty `category_scope`.
- Every `affix_id` referenced in a combination matches a defined affix.
- Every clue id in `surface_clue_ids` and `hidden_clue_ids` exists in `clues.yaml` with the correct type.
- Every `weight` is a positive int (both affix-level and combination-level).
- No prefix × suffix cross-product carries a duplicate `exclusive_group` or double `override`.
- At least one combination per affix provides a positive discovery path; at least one provides a minority negative path.

---

## Example

```yaml
affix_combinations:
  - combination_id: comb_bag_rustic_01
    affix_id: bag_rustic
    weight: 3
    surface_clue_ids:
      - bag_exterior_faded
      - bag_hardware_tarnished
    hidden_clue_ids:
      - bag_leaf_coach

  - combination_id: comb_bag_rustic_02
    affix_id: bag_rustic
    weight: 1
    surface_clue_ids:
      - bag_exterior_synthetic
      - bag_hardware_tarnished
    hidden_clue_ids:
      - bag_override_replica

affixes:
  - affix_id: bag_rustic
    naming_slot: prefix
    display_name: Rustic
    scope_mode: categories
    category_scope:
      - handbag
    weight: 3
    combination_ids:
      - comb_bag_rustic_01
      - comb_bag_rustic_02
```

This affix is drawn on ~30% of handbag items (weight 3 versus the plain-item baseline). When drawn, the item gets surface clues bundled by the chosen combination — "Faded Tarnished Bag" for comb_01 or "Synthetic Tarnished Bag" for comb_02. The hidden clue reveals "Coach Bag" (2.8× verified multiplier) 60% of the time, or "Reproduction Bag" (collapsed to override base 120) 20% of the time. The remaining 70% of handbags are plain items with no affix and no hidden clues.
