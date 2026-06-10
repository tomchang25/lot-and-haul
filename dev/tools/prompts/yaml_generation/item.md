# Lot & Haul — Clue & Item YAML Generation Prompt

Use this prompt to generate new entries for `data/yaml/clues.yaml` and `data/yaml/items/*.yaml`.

Clue definitions and item definitions are separate files. Clues are defined once in `clues.yaml`. Items reference clue ids — no clue data is repeated inside an item entry.

---

## Pricing Model

Understanding how clues produce value is required to author correct effect amounts.

```
appraised_value = (anchor.effect_amount + Σ revealed_surface_add) × Π revealed_surface_mul

verified_value  = (effective_base + Σ surface_add + Σ hidden_add) × Π surface_mul × Π hidden_mul
```

**effective_base** = revealed override amount if a hidden `flat` clue has been revealed, otherwise the anchor's `effect_amount`.

**Global add-then-mul**: all `add` effects (surface and hidden combined) are summed with the base first, then all `mul` effects (surface and hidden combined) are applied as a product. Appraised math is surface-only and unchanged.

The player sees `appraised_value` during the run and in storage until Research completes. `verified_value` replaces it after all hidden clues are revealed.

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

A COMMON item (0 hidden) is verified immediately on acquisition — the sell bonus applies at no research cost. A LEGENDARY item carries 4 hidden clues; each may be positive or negative.

---

## Clue Schema (`clues.yaml`)

```yaml
clues:
  - clue_id: unique_snake_case_id
    known_text: "..." # shown to player after reveal; max 3 words
    type: anchor | surface | hidden
    domain: generic | <category_id>
    attribute: appraisal | perception | restoration | negotiation | investigation
    dc: <int>
    effect_op: flat | add | mul
    effect_amount: <number>
    naming: # optional — enables naming contribution
      slot: prefix | body | suffix
      priority: <int>

    # ── Anchor-only fields ────────────────────────────────────────────────
    shape_id: <shape_key> # cargo shape; see valid shapes below
    sprite: <sprite_key> # sprite reference (same as clue_id is conventional)
    weight_kg: <float> # item weight in kilograms
    tier: <1–5> # anchor value tier (1=low, 5=high)

    # ── Hidden-only field ─────────────────────────────────────────────────
    exclusive_group: <string> # optional; at most one clue per group per item
```

**Fields only written on the relevant type** — do not add `shape_id`/`sprite`/`weight_kg`/`tier` to surface or hidden clues, and do not add `exclusive_group` to anchor or surface clues.

---

## Rules by Clue Type

### Anchor (exactly 1 per item)

- `effect_op: flat` — sets the anchor base value.
- `effect_amount`: positive integer. This is the item's starting visible price.
- `shape_id`: cargo grid shape. Must be one of the valid shape IDs (see below).
- `sprite`: string key, conventionally matches the clue_id.
- `weight_kg`: positive float. Realistic category weight.
- `tier`: integer 1–5. Tier 1 = cheap common variant, tier 5 = expensive premium variant. Used by pool-draw tier weight curves.
- `dc: 0`, `attribute: appraisal` (anchor auto-reveals on first inspect — these are placeholders).
- `domain`: match the item's `category_id`.
- `naming`: anchor carries `slot: body, priority: 1` (baseline display name).

**Each category must have at least two anchor variants** (different tiers). Items reference a specific anchor — different items in the same category may reference different anchors.

### Surface (2–4 per item, range varies by super-category)

- `effect_op: add` — adds to the running price. `flat` is **forbidden** on surface clues.
- `effect_amount`: **must be non-zero** (the validator rejects zero-effect surface clues).
  - Positive: value-adding details (maker mark, fine material, good condition feature).
  - **Negative allowed and required**: at least some surface clues in each pool should reduce value (wear, cracks, repair marks, reproduction tells). Use a negative integer.
- `dc`: 10–18.
- `known_text`: one word preferred; two or three only when a single word is unclear.
- `naming`: optional. Use for surface clues that identify maker, material, or style.

### Hidden (N per item, N = rarity value)

- `effect_op`: `add`, `mul`, or `flat` (override).
  - `mul > 1.0`: positive discovery (genuine, rare variant, premium maker).
  - `mul < 1.0`: negative discovery (forgery, damage, replacement part).
  - `add`: flat bonus or penalty.
  - `flat`: **base-replacement override** — when revealed, replaces the anchor base entirely. Use for counterfeit collapses (small override value) or sleeper reveals (large override value). At most one override per item.
- `effect_amount`: **must be non-zero** (the validator rejects zero-effect hidden clues).
- `dc`: 20–25.
- `exclusive_group`: assign an authenticity group string (e.g. `"authenticity_lamp"`) to mutually-exclusive hidden clues so at most one may be placed on a single item. Counterfeit and genuine clues for the same category typically share a group.
- `naming`: optional; hidden naming displaces lower-priority slots at high priority when revealed.

---

## Effect Amount Guidelines

| Type    | effect_op | Typical range                                                                             |
| ------- | --------- | ----------------------------------------------------------------------------------------- |
| anchor  | flat      | tier 1: 20–150 / tier 2: 150–400 / tier 3: 400–800 / tier 4: 800–1500 / tier 5: 1500–4000 |
| surface | add       | positive: 30–2000; negative: −500–−20                                                     |
| hidden  | mul       | positive: 1.1–3.5; negative (counterfeit): 0.05–0.6                                       |
| hidden  | flat      | override: positive sleeper 5×–20× anchor; negative counterfeit 10%–40% of anchor          |
| hidden  | add       | ±50 to ±3000                                                                              |

**Positive/negative mix**: each category's clue pool must contain at least one negative surface clue (negative add) and at least one negative hidden clue (mul < 1.0 or a low-value flat override). This is required by the design standard.

---

## Valid Shape IDs

```
s1x1  s1x2  s1x3  s1x4
s2x2  s2x3  s2x4
sL11  sL12  sT3
```

Shape follows category convention (e.g. pistol → sL11, clock → s1x3), but exceptions are allowed. Shape is a generation prompt rule, not enforced by the validator beyond existence check.

---

## Item Schema (`data/yaml/items/*.yaml`)

```yaml
items:
  - item_id: snake_case_unique_id
    category_id: <category_id>
    rarity: 0 | 1 | 2 | 3 | 4 # must equal the number of hidden clues
    clue_ids:
      - clue_id_anchor
      - clue_id_surface_1
      - clue_id_surface_2
      - clue_id_hidden_1 # only present when rarity >= 1
```

- **No `item_name`, `base_price`, or `auto_verify` fields.** These have been removed. The display name is composed entirely from naming clues; value derives from the clue price pipeline.
- `rarity` must equal the number of hidden clues in `clue_ids`. The validator enforces this.
- `clue_ids` must include exactly one anchor clue. The anchor must carry `naming.slot: body`.
- Ordering: anchor first, then all surface clues, then all hidden clues.
- COMMON items (rarity 0) have no hidden clues and are verified immediately upon acquisition.

---

## Structural Naming Requirements (validator-enforced)

At full reveal, the named clue set must resolve:

1. **Exactly one body slot** (mandatory — the anchor carries this at priority 1; a hidden clue may override it at higher priority).
2. **At least one prefix or suffix slot** (mandatory — without a qualifier the name stays "Unknown {body}" until verification).
3. **Non-empty composed name** (no items with all-empty known_text in naming slots).

---

## Clue ID Conventions

```
{category_id}_{aspect}_{detail}     — surface/hidden generic
{category_id}_anchor_NN             — anchor variants (01, 02, 03 …)
{category_id}_leaf_{maker}          — hidden positive identity reveal
{category_id}_override_{identifier} — hidden flat base-replacement (counterfeit/sleeper)
```

---

## Valid Attributes

```
appraisal       — recognising value, quality, maker indicators
perception      — spotting physical details, wear, anomalies
investigation   — cross-referencing marks, research, pattern matching
restoration     — condition, material degradation, repair evidence
negotiation     — (reserved for selling phase, not used in inspection)
```

## Valid Category IDs

```
handbag  wristwatch  oil_lamp  clock  porcelain_figurine
vase  poster  painting  sculpture  pistol  rifle  crossbow
```

---

## Example Output

```yaml
# clues.yaml entries — two anchor variants, a negative surface clue, and an override hidden

clues:
  - clue_id: clock_anchor_01
    known_text: Clock
    type: anchor
    domain: clock
    attribute: appraisal
    dc: 0
    effect_op: flat
    effect_amount: 80
    shape_id: s1x3
    sprite: clock_anchor_01
    weight_kg: 3.5
    tier: 1
    naming:
      slot: body
      priority: 1

  - clue_id: clock_anchor_02
    known_text: Clock
    type: anchor
    domain: clock
    attribute: appraisal
    dc: 0
    effect_op: flat
    effect_amount: 350
    shape_id: s1x3
    sprite: clock_anchor_02
    weight_kg: 4.2
    tier: 3
    naming:
      slot: body
      priority: 1

  - clue_id: clock_case_gilded
    known_text: Gilded
    type: surface
    domain: clock
    attribute: perception
    dc: 14
    effect_op: add
    effect_amount: 280
    naming:
      slot: prefix
      priority: 2

  - clue_id: clock_case_cracked
    known_text: Cracked
    type: surface
    domain: clock
    attribute: perception
    dc: 10
    effect_op: add
    effect_amount: -60
    naming:
      slot: prefix
      priority: 2

  - clue_id: clock_leaf_boulle
    known_text: Bracket
    type: hidden
    domain: clock
    attribute: investigation
    dc: 20
    effect_op: mul
    effect_amount: 1.85
    exclusive_group: authenticity_clock
    naming:
      slot: body
      priority: 10

  - clue_id: clock_override_reproduction
    known_text: Reproduction
    type: hidden
    domain: clock
    attribute: investigation
    dc: 22
    effect_op: flat
    effect_amount: 35
    exclusive_group: authenticity_clock
    naming:
      slot: prefix
      priority: 10
```

```yaml
# items/*.yaml entries

items:
  - item_id: clock_gilded_common
    category_id: clock
    rarity: 0
    clue_ids:
      - clock_anchor_01
      - clock_case_gilded

  - item_id: clock_boulle_rare
    category_id: clock
    rarity: 2
    clue_ids:
      - clock_anchor_02
      - clock_case_gilded
      - clock_movement_signed
      - clock_leaf_boulle
      - clock_override_reproduction
```

Notes on the example:

- `clock_gilded_common` is COMMON (rarity 0, 0 hidden clues) — verified immediately, shows "Gilded Clock".
- `clock_boulle_rare` is RARE (rarity 2, 2 hidden clues). The two hidden clues share `exclusive_group: authenticity_clock` — valid because each item carries at most one per group. A revealed `clock_leaf_boulle` displaces the anchor body with "Bracket" at priority 10; a revealed `clock_override_reproduction` prepends "Reproduction" and collapses the base to 35.
- `clock_case_cracked` is a negative surface clue — reduces appraised value when revealed.
- `clock_anchor_01` (tier 1, $80) and `clock_anchor_02` (tier 3, $350) are separate anchors; different items reference different variants.
