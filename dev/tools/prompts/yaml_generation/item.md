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
- **Condition multiplier** (0.25× broken → 1.0× at half condition → 4.0× mint) is applied on top of the resolved value at price time. Author clue amounts at the **condition-neutral** value; never pre-bake condition.
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
  - anchor_id: <category_prefix>_veil_NN # e.g. lamp_veil_01, clock_veil_02
    known_text: "..." # the bare category noun shown as the body name; max 3 words
    naming_priority: 1 # anchor always occupies the body slot at this priority
    category_scope: <category_id> # must match a defined category
    base_value: <number> # > 0; the item's starting visible price (see tier budgets)
    shape_id: <shape_key> # cargo grid footprint; see valid shapes
    sprite: "" # sprite key; "" is allowed, conventionally matches anchor_id
    weight_kg: <float> # >= 0; realistic category weight
    tier: <1–5> # value tier; used by pool-draw tier weight curves
```

Anchors carry **no** `dc`, `attribute`, `effect_op`, `type`, `domain`, or `naming` block — only `naming_priority`. They are auto-revealed on first inspect, so they have no discovery roll.

**Each category must define at least two anchor variants at different tiers** (a cheap variant and a premium variant). Different items in the same category reference different anchors. `known_text` is the plain noun (`Lamp`, `Clock`, `Pistol`) — the qualifiers come from clues.

---

## Clue Schema (`clues:` block of `clues.yaml`)

```yaml
clues:
  - clue_id: unique_snake_case_id
    known_text: "..." # shown after reveal; max 3 words
    type: surface | hidden
    domain: generic | <category_id>
    attribute: appraisal | perception | investigation | restoration # negotiation is sell-phase only
    dc: <int> # surface 10–18, hidden 20–25
    effect_op: add | mul | override # 'override' is hidden-only
    effect_amount: <number> # non-zero; |amount| <= 100000
    naming: # optional — enables a naming contribution
      slot: prefix | body | suffix
      priority: <int> # >= 0
    exclusive_group: <string> # HIDDEN-ONLY; at most one clue per group per item
```

`exclusive_group` is written only on hidden clues; the converter blanks it on surface clues.

### Surface clues (2–6 per item, count varies by super-category)

- `effect_op: add` is the default — a flat addition to the running price. `effect_op: mul` is allowed for proportional quality/wear effects (e.g. `0.85` heavy wear, `1.3` exceptional finish).
- `effect_amount` must be **non-zero**.
  - Positive `add`: value-adding detail (maker mark, fine material, good feature).
  - **Negative required**: every category pool must include at least one value-reducing surface clue — a negative `add` (`-500`…`-20`) or a `mul < 1.0`.
- `dc`: 10–18.
- `known_text`: one word preferred; two or three only when one is unclear.
- `naming`: optional — use for surface clues that identify maker, material, or style (prefix/suffix).

### Hidden clues (N per item, N = rarity)

- `effect_op`:
  - `mul > 1.0` — positive discovery (genuine, rare variant, premium maker).
  - `mul < 1.0` — negative discovery (forgery tell, replacement part, damage).
  - `add` — flat bonus or penalty.
  - `override` — **base-replacement**: when revealed, replaces the anchor base entirely (a sleeper reveal uses a large override; a counterfeit collapse uses a small one). **At most one override per item.**
- `effect_amount` must be **non-zero**.
- `dc`: 20–25.
- `exclusive_group`: assign an authenticity group string (e.g. `authenticity_lamp`) to hidden clues that are mutually-exclusive interpretations of the same feature. A genuine-maker (`_leaf_`) clue and its counterfeit (`_override_`) clue for the same category share one group so a single item never carries both. **No item may carry two hidden clues in the same group** — they are alternatives the pool draw chooses between, never combined.
- `naming`: optional — a revealed identity (`_leaf_`) clue typically takes the body slot at high priority to replace the generic noun; an override may prepend a prefix such as `Reproduction`.

---

## Effect Budgets (full tiered scale)

| Resource | effect_op  | Budget                                                                                    |
| -------- | ---------- | ----------------------------------------------------------------------------------------- |
| anchor   | base_value | tier 1: 20–150 · tier 2: 150–400 · tier 3: 400–800 · tier 4: 800–1500 · tier 5: 1500–4000 |
| surface  | add        | positive: 30–2000 · negative: −500…−20                                                    |
| surface  | mul        | positive: 1.05–1.5 · negative: 0.6–0.95                                                   |
| hidden   | mul        | positive: 1.1–3.5 · counterfeit: 0.05–0.6                                                 |
| hidden   | override   | sleeper: 5×–20× anchor base · counterfeit collapse: 10%–40% of anchor base                |
| hidden   | add        | ±50 to ±3000                                                                              |

**Positive/negative mix (required per category pool):** at least one negative surface clue (negative `add` or `mul < 1.0`) **and** at least one negative hidden clue (`mul < 1.0` or a low-value `override`).

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
    anchor_id: <category_prefix>_veil_NN # must reference a defined anchor in this category
    surface_ids:
      - <surface_clue_id>
      - <surface_clue_id>
    hidden_ids: # omit or leave empty for COMMON (rarity 0)
      - <hidden_clue_id> # one per rarity point
```

- **No `item_name`, `base_price`, `auto_verify`, or `clue_ids` fields.** They have been removed. The display name is composed entirely from naming slots (anchor body + clue qualifiers); value derives from the price pipeline.
- `rarity` must equal `len(hidden_ids)`. The validator enforces this.
- `anchor_id` is required and must reference a defined anchor whose `category_scope` matches `category_id`.
- `surface_ids` must all be `type: surface`; `hidden_ids` must all be `type: hidden`.
- At most one hidden `override` per item; no two hidden clues may share an `exclusive_group`.
- COMMON items (rarity 0) have no hidden clues and are verified immediately on acquisition.

---

## Structural Naming Requirements (validator-enforced)

At full reveal, the named clue set must resolve:

1. **A body slot** — the anchor always provides it at `naming_priority` (a revealed hidden clue may displace it at higher priority).
2. **At least one prefix or suffix qualifier** — supplied by a surface or hidden clue with `naming.slot: prefix` or `suffix`. Without one, the item stays "Unknown {body}".
3. **Non-empty composed name** — no item whose every naming slot is empty.

---

## ID Conventions

```
<category_prefix>_veil_NN              — anchor variants (01, 02, 03 …)
<category_id>_<aspect>_<detail>        — surface clue
<category_id>_leaf_<maker>             — hidden positive identity reveal (genuine maker / sleeper)
<category_id>_override_<identifier>    — hidden override (counterfeit collapse / sleeper base-swap)
```

Short category prefixes for ids are fine (`bag_`, `watch_`, `lamp_`).

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
  - anchor_id: clock_veil_01
    known_text: Clock
    naming_priority: 1
    category_scope: clock
    base_value: 60
    shape_id: s1x3
    sprite: ""
    weight_kg: 3.5
    tier: 1

  - anchor_id: clock_veil_02
    known_text: Clock
    naming_priority: 1
    category_scope: clock
    base_value: 500
    shape_id: s1x3
    sprite: ""
    weight_kg: 4.2
    tier: 3

clues:
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
    attribute: restoration
    dc: 10
    effect_op: add
    effect_amount: -60
    naming:
      slot: prefix
      priority: 2

  - clue_id: clock_movement_signed
    known_text: Signed
    type: surface
    domain: clock
    attribute: investigation
    dc: 16
    effect_op: add
    effect_amount: 400
    naming:
      slot: suffix
      priority: 2

  - clue_id: clock_leaf_boulle
    known_text: Boulle
    type: hidden
    domain: clock
    attribute: investigation
    dc: 22
    effect_op: mul
    effect_amount: 2.75
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
    effect_op: override
    effect_amount: 120
    exclusive_group: authenticity_clock
    naming:
      slot: prefix
      priority: 10

  - clue_id: clock_movement_swiss
    known_text: Swiss
    type: hidden
    domain: clock
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
    anchor_id: clock_veil_01
    surface_ids:
      - clock_case_gilded
      - clock_case_cracked

  - item_id: clock_signed_uncommon
    category_id: clock
    rarity: 1
    anchor_id: clock_veil_02
    surface_ids:
      - clock_case_gilded
      - clock_movement_signed
    hidden_ids:
      - clock_leaf_boulle

  - item_id: clock_repro_uncommon
    category_id: clock
    rarity: 1
    anchor_id: clock_veil_02
    surface_ids:
      - clock_case_gilded
    hidden_ids:
      - clock_override_reproduction

  - item_id: clock_boulle_rare
    category_id: clock
    rarity: 2
    anchor_id: clock_veil_02
    surface_ids:
      - clock_case_gilded
      - clock_case_cracked
      - clock_movement_signed
    hidden_ids:
      - clock_leaf_boulle
      - clock_movement_swiss
```

Notes on the example:

- `clock_mantel_common` is COMMON (rarity 0, 0 hidden) — verified immediately, shows "Gilded Clock".
- `clock_leaf_boulle` and `clock_override_reproduction` both sit in `exclusive_group: authenticity_clock`. They are **alternatives** — `clock_signed_uncommon` draws the genuine `_leaf_`, `clock_repro_uncommon` draws the counterfeit `_override_`. **No single item carries both**, which is exactly what the one-per-group rule enforces.
- `clock_boulle_rare` is RARE (rarity 2). Its two hidden clues are `clock_leaf_boulle` (group `authenticity_clock`) and `clock_movement_swiss` (**no group**) — so they do not collide, and neither is an `override`, so the one-override limit holds.
- `clock_case_cracked` is the required negative surface clue; `clock_override_reproduction` is the required negative hidden — on `clock_repro_uncommon` it collapses the tier-3 base (500) to 120 (~24%, within the counterfeit budget).
- `clock_veil_01` (tier 1, base 60) and `clock_veil_02` (tier 3, base 500) are separate anchors; different items reference different variants.
