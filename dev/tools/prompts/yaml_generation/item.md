# Lot & Haul — Anchor, Clue & Item YAML Generation Prompt

Use this prompt to generate new entries for `data/yaml/clues.yaml` (which holds **both** the `anchors:` block and the `clues:` block) and `data/yaml/items/*.yaml`.

Anchors, clues, and items live in separate blocks. Anchors are defined once under `anchors:`; surface and hidden clues are defined once under `clues:`; items reference an anchor id plus clue ids and never repeat any anchor or clue data inline.

---

## The Three Resources

| Resource   | Block      | Identity    | Role                                                                                               |
| ---------- | ---------- | ----------- | -------------------------------------------------------------------------------------------------- |
| **Anchor** | `anchors:` | `anchor_id` | The item's physical body: base value, shape, weight, sprite, value tier. Auto-revealed.            |
| **Clue**   | `clues:`   | `clue_id`   | A `surface` or `hidden` price modifier. Surface = discovered on inspection; hidden = Authenticate. |
| **Item**   | `items:`   | `item_id`   | A specific item: one anchor + a list of surface clue ids + a list of hidden clue ids.              |

There is no `anchor` clue `type` any more — anchors are their own resource. Clue `type` is only ever `surface` or `hidden`.

---

## Pricing Model

Understanding how values resolve is required to author correct numbers.

```
appraised_value = (anchor.base_value + Σ revealed_surface_add) × Π revealed_surface_mul

verified_value  = (effective_base   + Σ all_add) × Π all_mul
```

- **all_add / all_mul** are summed/multiplied over **every** clue (surface and hidden combined) — global add-then-mul: add everything to the base first, then apply every multiplier as a product.
- **effective_base** = the revealed hidden **override** amount if one has been revealed, otherwise `anchor.base_value`. An override _replaces_ the base; all other adds and muls still apply on top of it. At most one override per item (first wins).
- The player sees `appraised_value` during the run and in storage until Research completes; `verified_value` replaces it once all hidden clues are revealed.
- **Verified sell bonus** is ×1.05, applied at sale, not baked into clue amounts.
- **Condition multiplier** (0.75× broken → 1.0× at half condition → 1.5× pristine) is applied on top of the resolved value at price time. Author clue amounts at the **condition-neutral** value; never pre-bake condition.
- A **COMMON** item (rarity 0, no hidden clues) is verified immediately on acquisition.

---

## Rarity == Hidden Count

Rarity is the number of hidden clues. It is not a quality tier.

| Rarity    | Value | Hidden clues | Verified by default?     |
| --------- | ----- | ------------ | ------------------------ |
| COMMON    | 0     | 0            | Yes — no research needed |
| UNCOMMON  | 1     | 1            | No                       |
| RARE      | 2     | 2            | No                       |
| EPIC      | 3     | 3            | No                       |
| LEGENDARY | 4     | 4            | No                       |

A LEGENDARY item carries 4 hidden clues; each may be positive or negative.

---

## Anchor Schema (`anchors:` block of `clues.yaml`)

```yaml
anchors:
  - anchor_id: <category_prefix>_<subtype>_NN # e.g. bag_tote_01, watch_diver_01, clock_mantel_01
    known_text_key: ANCHOR_<CAT>_<SUBTYPE>_<TIER> # matches sub-type display name
    category_scope: <category_id> # must match a defined category
    base_value: <number> # > 0; the item's starting visible price (see tier budgets)
    shape_id: <shape_key> # cargo grid footprint; see valid shapes
    sprite: "" # sprite key; "" is allowed, conventionally matches anchor_id
    weight_kg: <float> # >= 0; realistic category weight
    tier: <1–5> # value tier; used by pool-draw tier weight curves
```

Anchors carry **no** `dc`, `attribute`, `effect_op`, `type`, `domain`, `naming`, or `naming_priority` field. They are auto-revealed on first inspect, so they have no discovery roll. `known_text_key` resolves to the sub-type display name used by affix-only display-name composition.

**Each category must define at least two anchor variants at different tiers** (a cheap variant and a premium variant), ideally 3+ with distinct sub-type names (e.g. `bag_tote_01`, `bag_satchel_02`, `bag_clutch_03`). `known_text_key` provides the sub-type noun (`Tote`, `Satchel`, `Clutch`) — qualifiers come from affixes, not clues.

---

## Clue Schema (`clues:` block of `clues.yaml`)

```yaml
clues:
  - clue_id: unique_snake_case_id
    known_text: "..." # shown after reveal; max 3 words
    type: surface | hidden
    attribute: appraisal | perception | investigation | restoration # negotiation is sell-phase only
    dc: <int> # surface 10–18, hidden 20–25
    effect_op: add | mul | override # 'override' is hidden-only
    effect_amount: <number> # non-zero; |amount| <= 100000
    exclusive_group: <string> # HIDDEN-ONLY; at most one clue per group per item
```

Clues carry **no** `domain` field — they are a single global pool, not category-bound. `exclusive_group` is written only on hidden clues; the converter blanks it on surface clues. Clues do **not** carry a `naming` block; item names are composed from affixes plus the anchor body.

**Do not generate condition, damage, wear, or repair clues.** The condition system handles item condition separately. Clues describe material, craftsmanship, marks, provenance, medium, and form.

### Surface clues (2–6 per item, count varies by super-category)

- `effect_op: add` is the default — a flat addition to the running price. **Add is value-positive only — never use add with a negative amount.**
- `effect_op: mul` is used for proportional quality/wear effects (e.g. `0.85` minor defect, `1.3` exceptional finish).
- `effect_amount` must be **non-zero**.
  - Positive `add`: value-adding detail (maker mark, fine material, good feature).
  - **Negative required**: every category pool must include at least one value-reducing surface clue — use `mul < 1.0` (never negative add).
- `dc`: 10–18.
- `known_text`: one word preferred; two or three only when one is unclear.
- Surface clues may be used by affix combinations as readable tells, but they do not contribute display-name slots directly.

### Hidden clues (N per item, N = rarity)

- `effect_op`:
  - `mul > 1.0` — positive discovery (genuine, rare variant, premium maker).
  - `mul < 1.0` — negative discovery (forgery tell, replacement part, damage). See the Negative Effect Tiers table for ranges.
  - `add` — flat bonus only (positive amount). Negative hidden add is forbidden.
  - `override` — **base-replacement**: when revealed, replaces the anchor base entirely (a sleeper reveal uses a large override; a counterfeit collapse uses a small one). **At most one override per item.**
- `effect_amount` must be **non-zero**.
- `dc`: 20–25.
- `exclusive_group`: assign an authenticity group string (e.g. `authenticity_lamp`) to hidden clues that are mutually-exclusive interpretations of the same feature. A genuine-maker (`_leaf_`) clue and its counterfeit (`_override_`) clue for the same category share one group so a single item never carries both. **No item may carry two hidden clues in the same group** — they are alternatives the pool draw chooses between, never combined.
- Hidden clues may reveal identity, authenticity, or condition truth, but they do not rename the item directly. Affixes carry the player-facing qualifier.

---

## Effect Budgets (full tiered scale)

| Resource | effect_op  | Budget                                                                                    |
| -------- | ---------- | ----------------------------------------------------------------------------------------- |
| anchor   | base_value | tier 1: 20–150 · tier 2: 150–400 · tier 3: 400–800 · tier 4: 800–1500 · tier 5: 1500–4000 |
| surface  | add        | positive only: 30–2000 (negative add is forbidden — use mul < 1.0 instead)                |
| surface  | mul        | positive: 1.05–1.5 · negative: 0.6–0.95                                                   |
| hidden   | mul        | positive: 1.1–3.5 · counterfeit: 0.05–0.6                                                 |
| hidden   | override   | sleeper: 5×–20× anchor base · counterfeit collapse: 10%–40% of anchor base                |
| hidden   | add        | positive only: 50–3000 (negative hidden add is forbidden — use mul < 1.0 instead)         |

## Negative Effect Tiers (mul < 1.0)

All value-reduction **must** use `effect_op: mul` with `effect_amount < 1.0`. Use these tiers:

| Tier                | Range     | Category                                                                  | Examples                                                          |
| ------------------- | --------- | ------------------------------------------------------------------------- | ----------------------------------------------------------------- |
| Minor Defect        | 0.80–0.95 | Cosmetic imperfection, light wear, minor blemish                          | Scratched surface, mold seam, faded color, synthetic material     |
| Missing/Compromised | 0.50–0.75 | Missing part, replaced non-original component, significant feature absent | Frayed stitching, replaced band, chipped rim, unmarked base       |
| Severe Damage       | 0.25–0.40 | Major structural damage, extensive degradation                            | Cracked glass, pitted surface, broken mechanism, rusted component |
| Counterfeit/Forgery | override  | Hidden-only base-value replacement                                        | Replica, forgery, cast copy, franken-build                        |

**Positive/negative mix (required per category pool):** at least one negative surface clue `mul < 1.0` **and** at least one negative hidden clue (`mul < 1.0` or a low-value `override`).

**Research EV constraint:** high-rarity items must keep a **positive long-run expected research value** — players must never learn to skip Legendaries. Keep each category's hidden pool net-positive in expectation: more and higher-weighted positive discoveries than negative ones, with counterfeits the minority risk, not the norm.

---

## Super-Category Personalities

Encode these as data conventions (they shape which tiers and spreads a category draws, not the schema):

| Super-category | Anchor spread     | Surface count | Adds / muls            | Hidden volatility |
| -------------- | ----------------- | ------------- | ---------------------- | ----------------- |
| fashion        | wide (tiers 1–4)  | 3–5           | many small adds & muls | high              |
| decorative     | tight (tiers 1–2) | 2–3           | few, mostly flat adds  | low               |
| fine_art       | high (tiers 3–5)  | 4–6           | few large muls         | medium            |
| weapon         | mid (tiers 2–3)   | 2–4           | predictable adds       | very low          |

---

## Valid Shape IDs

```
s1x1  s1x2  s1x3  s1x4
s2x2  s2x3  s2x4
sL11  sL12  sT3
```

Shape follows category convention (e.g. pistol → sL11, clock → s1x3), but exceptions are allowed. Shape is a prompt rule, validated only for existence.

---

## Item Schema (`data/yaml/items/*.yaml`)

```yaml
items:
  - item_id: snake_case_unique_id
    category_id: <category_id>
    rarity: 0 | 1 | 2 | 3 | 4 # must equal the number of hidden_ids
    anchor_id: <category_prefix>_anchor_NN # must reference a defined anchor in this category
    surface_ids:
      - <surface_clue_id>
      - <surface_clue_id>
    hidden_ids: # omit or leave empty for COMMON (rarity 0)
      - <hidden_clue_id> # one per rarity point
```

- **No `item_name`, `base_price`, `auto_verify`, or `clue_ids` fields.** They have been removed. The display name is composed from affixes plus the anchor body; value derives from the price pipeline.
- `rarity` must equal `len(hidden_ids)`. The validator enforces this.
- `anchor_id` is required and must reference a defined anchor whose `category_scope` matches `category_id`.
- `surface_ids` must all be `type: surface`; `hidden_ids` must all be `type: hidden`.
- At most one hidden `override` per item; no two hidden clues may share an `exclusive_group`.
- COMMON items (rarity 0) have no hidden clues and are verified immediately on acquisition.

---

## Display Naming

Item names are affix-only:

1. The anchor `known_text` supplies the body noun.
2. Affixes supply prefix or suffix qualifiers through `data/yaml/affixes.yaml`.
3. Clues and combinations never carry display-name slots. Do not author `naming:` blocks on clues; the validator rejects them.

---

## ID Conventions

```
<category_prefix>_<subtype>_NN         — anchor variants with sub-type names (tote_01, diver_01 …)
common_<aspect>_<detail>               — generic surface clue (material, craft, mark, form, etc.)
<category_id>_<detail>                 — category-specific surface clue (≤1 per category; e.g. handbag_monogram)
<category_id>_leaf_<maker>             — hidden positive identity reveal (genuine maker / sleeper)
<category_id>_override_<identifier>    — hidden override (counterfeit collapse / sleeper base-swap)
```

Short category prefixes for ids are fine (`bag_`, `watch_`, `lamp_`). Generic surface clues use `common_` prefix with no category affiliation.

---

## Valid Attributes

```
appraisal       — recognising value, quality, maker indicators
perception      — spotting physical details, wear, anomalies
investigation   — cross-referencing marks, research, pattern matching
restoration     — condition, material degradation, repair evidence
negotiation     — (reserved for the selling phase, not used in inspection)
```

## Valid Category IDs

```
handbag  wristwatch  oil_lamp  clock  porcelain_figurine
vase  poster  painting  sculpture  pistol  rifle  crossbow
```

---

## Example Output

```yaml
# anchors: + clues: blocks of clues.yaml — two anchor tiers, a negative surface clue,
# and a mutually-exclusive genuine/counterfeit hidden pair sharing one exclusive_group.

anchors:
  - anchor_id: clock_mantel_01
    known_text_key: ANCHOR_CLOCK_MANTEL_01
    category_scope: clock
    base_value: 60
    shape_id: s1x3
    sprite: ""
    weight_kg: 3.5
    tier: 1

  - anchor_id: clock_tall_02
    known_text_key: ANCHOR_CLOCK_TALL_02
    category_scope: clock
    base_value: 500
    shape_id: s1x3
    sprite: ""
    weight_kg: 4.2
    tier: 3

clues:
  - clue_id: common_detail_gilded
    known_text: Gilded
    type: surface
    attribute: perception
    dc: 14
    effect_op: add
    effect_amount: 280

  - clue_id: common_material_canvas
    known_text: Canvas
    type: surface
    attribute: restoration
    dc: 10
    effect_op: mul
    effect_amount: 0.85

  - clue_id: common_mark_signed
    known_text: Signed
    type: surface
    attribute: investigation
    dc: 16
    effect_op: add
    effect_amount: 400

  - clue_id: clock_leaf_boulle
    known_text: Boulle
    type: hidden
    attribute: investigation
    dc: 22
    effect_op: mul
    effect_amount: 2.75
    exclusive_group: authenticity_clock

  - clue_id: clock_override_reproduction
    known_text: Reproduction
    type: hidden
    attribute: investigation
    dc: 22
    effect_op: override
    effect_amount: 120
    exclusive_group: authenticity_clock

  - clue_id: clock_movement_swiss
    known_text: Swiss
    type: hidden
    attribute: investigation
    dc: 21
    effect_op: mul
    effect_amount: 1.4
```

```yaml
# items/*.yaml entries

items:
  - item_id: clock_mantel_common
    category_id: clock
    rarity: 0
    anchor_id: clock_mantel_01
    surface_ids:
      - common_detail_gilded
      - common_material_canvas

  - item_id: clock_signed_uncommon
    category_id: clock
    rarity: 1
    anchor_id: clock_tall_02
    surface_ids:
      - common_detail_gilded
      - common_mark_signed
    hidden_ids:
      - clock_leaf_boulle

  - item_id: clock_repro_uncommon
    category_id: clock
    rarity: 1
    anchor_id: clock_tall_02
    surface_ids:
      - common_detail_gilded
    hidden_ids:
      - clock_override_reproduction

  - item_id: clock_boulle_rare
    category_id: clock
    rarity: 2
    anchor_id: clock_tall_02
    surface_ids:
      - common_detail_gilded
      - common_material_canvas
      - common_mark_signed
    hidden_ids:
      - clock_leaf_boulle
      - clock_movement_swiss
```

Notes on the example:

- `clock_mantel_common` is COMMON (rarity 0, 0 hidden) — verified immediately. Its display name is the anchor sub-type plus any drawn affixes; clues do not rename it.
- `clock_leaf_boulle` and `clock_override_reproduction` both sit in `exclusive_group: authenticity_clock`. They are **alternatives** — `clock_signed_uncommon` draws the genuine `_leaf_`, `clock_repro_uncommon` draws the counterfeit `_override_`. **No single item carries both**, which is exactly what the one-per-group rule enforces.
- `clock_boulle_rare` is RARE (rarity 2). Its two hidden clues are `clock_leaf_boulle` (group `authenticity_clock`) and `clock_movement_swiss` (**no group**) — so they do not collide, and neither is an `override`, so the one-override limit holds.
- `clock_override_reproduction` is the required negative hidden — on `clock_repro_uncommon` it collapses the tier-3 base (500) to 120 (~24%, within the counterfeit budget).
- `clock_mantel_01` (tier 1, base 60) and `clock_tall_02` (tier 3, base 500) are separate anchors with sub-type names; different items reference different variants.
