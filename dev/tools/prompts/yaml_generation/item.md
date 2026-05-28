# Lot & Haul — Clue & Item YAML Generation Prompt

Use this prompt to generate new entries for `data/yaml/clues.yaml` and `data/yaml/items/*.yaml`.

Clue definitions and item definitions are separate files. Clues are defined once in `clues.yaml`. Items reference clue ids — no clue data is repeated inside an item entry.

---

## Pricing Model

Understanding how clues produce value is required to author correct effect amounts.

```
appraised_value = (anchor.effect_amount + Σ revealed_surface_add) × Π revealed_surface_mul
verified_value  = (appraised_value + Σ revealed_hidden_add) × Π revealed_hidden_mul
```

**Add before multiply.** All `add` effects are summed first, then all `mul` effects are applied as a product. Order within the YAML does not affect the result.

The player sees `appraised_value` during the run and in storage until Research completes. `verified_value` replaces it after authentication.

---

## Clue Schema (`clues.yaml`)

```yaml
clues:
  - clue_id: unique_snake_case_id # globally unique across all clues
    known_text: "..." # shown to player after reveal
    type: anchor | surface | hidden
    domain: generic | <category_id> # use category_id (e.g. oil_lamp) for category-specific clues
    attribute: appraisal | perception | restoration | negotiation | investigation
    dc: <int> # difficulty class for discovery roll
    effect_op: flat | add | mul
    effect_amount: <number>
```

---

## Rules by Clue Type

### Anchor (exactly 1 per item)

- `effect_op: flat` — sets the perceived base price. This is what the player sees on first reveal.
- `effect_amount`: positive integer. This is the item's visible starting price.
- `known_text`: the item's perceived identity at first glance. Write it as a noun phrase, not a sentence. Example: `"Brass Oil Lamp"`, `"Fabric Pouch"`.
- `dc` and `attribute` are not used (anchor auto-reveals on first inspect). Set `dc: 0` and `attribute: appraisal` as placeholders.
- `domain`: match the item's `category_id`.

### Surface (0 or more per item, typically 2–5)

- `effect_op: add` — adds to the running price total.
- `effect_amount`: use `0` for lore clues (narrows the estimate spread but adds no value). Use a positive integer for value-adding details.
- `known_text`: a specific first-person observation. Write as a complete sentence describing what the player notices. Example: `"The clear glass font is blown rather than molded."`.
- `dc`: 10–18. Use 10–12 for obvious details, 14–16 for trained-eye observations, 18 for expert-level reads.
- `attribute`: choose based on what skill the check represents.
  - `appraisal` — recognising value, quality, or maker indicators.
  - `perception` — spotting physical details, wear, or anomalies.
  - `investigation` — cross-referencing marks, research, or pattern matching.
  - `restoration` — condition, material degradation, repair evidence.

### Hidden (0 or more per item, typically 0–2)

- Accessible during inspection via the chain reveal mechanic, but DC should be set high enough that in-run discovery is unlikely. Fully revealed by Storage Research on completion.
- `effect_op`: any of `add`, `mul`. `mul` is most common for hidden clues.
  - Use `mul` > 1.0 for a positive discovery (e.g., confirmed authentic: `x1.5`).
  - Use `mul` < 1.0 for a negative discovery (e.g., confirmed forgery: `x0.3`).
  - Use `add` for a flat bonus (e.g., hidden component adds independent value).
- `known_text`: a significant reveal. Write as a sentence that would change the player's assessment. Example: `"Hallmarked Duplex Oil Lamp by Hinks & Son."`.
- `dc`: 20–25. High enough to make inspection discovery rare but not impossible.
- `attribute`: choose the attribute that fits the nature of the hidden information.
- Hidden clues make Research a risk/reward decision — the verified value may be higher or lower than the appraised value.

---

## Effect Amount Guidelines

| Type    | effect_op | Reasonable range                       |
| ------- | --------- | -------------------------------------- |
| anchor  | flat      | 10–1000 (reflects item tier)           |
| surface | add       | 0–2000 (proportional to anchor)        |
| surface | mul       | avoid for now (ordering semantics TBD) |
| hidden  | mul       | 0.1–3.0                                |
| hidden  | add       | 0–5000                                 |

Surface add amounts should sum to a total that, combined with the anchor, produces a final appraised value meaningfully below `base_price`. The gap between max appraised and `base_price` represents the value of authenticating.

---

## Item Schema (`data/yaml/items/*.yaml`)

```yaml
items:
  - item_id: snake_case_unique_id
    item_name: "Display Name Shown After Research"
    base_price: <positive int> # true verified price, shown only after Research
    category_id: <category_id> # must exist in category_data.yaml
    rarity: 0 | 1 | 2 | 3 | 4 # 0=Common, 1=Uncommon, 2=Rare, 3=Epic, 4=Legendary
    clue_ids:
      - clue_id_anchor
      - clue_id_surface_1
      - clue_id_surface_2
      - clue_id_hidden_1
```

- `base_price` must be greater than the maximum possible appraised value (anchor + all surface adds). This preserves the authentication value gap.
- `clue_ids` must include exactly one anchor clue. All referenced ids must exist in `clues.yaml`.
- `clue_ids` ordering: anchor first, then all surface clues, then all hidden clues. Hidden clues must never appear before a surface clue — this is enforced by the YAML validator.
- `item_name` is shown to the player only after all hidden clues are revealed (verified state). Before that, the anchor clue's `known_text` is the player-visible name.

---

## Clue ID Naming Convention

```
{category_id}_{aspect}_{detail}
```

- `{category_id}`: matches the item's domain (e.g. `oil_lamp`, `wristwatch`).
- `{aspect}`: the thing being examined (e.g. `glass_body`, `maker_mark`, `movement`).
- `{detail}`: the specific observation (e.g. `clear_font`, `registry_match`).

Anchor clue ids use the suffix `_veil_NN`. Hidden identity-reveal clue ids use the suffix `_leaf_{identifier}`.

All clue ids must be registered in `clues.yaml` before being referenced by items.

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
# clues.yaml entries
clues:
  - clue_id: clock_veil_01
    known_text: "Wooden Mantel Clock"
    type: anchor
    domain: clock
    attribute: appraisal
    dc: 0
    effect_op: flat
    effect_amount: 80

  - clue_id: clock_wooden_case_joinery
    known_text: "The case joints are hand-cut rather than machine-routed."
    type: surface
    domain: clock
    attribute: appraisal
    dc: 12
    effect_op: add
    effect_amount: 120

  - clue_id: clock_leaf_boulle
    known_text: "Verified Boulle-style marquetry case, mid-18th century."
    type: hidden
    domain: clock
    attribute: investigation
    dc: 20
    effect_op: mul
    effect_amount: 1.85
```

```yaml
# items/*.yaml entry
items:
  - item_id: clock_boulle_marquetry
    item_name: Boulle Marquetry Bracket Clock
    base_price: 4200
    category_id: clock
    rarity: 3
    clue_ids:
      - clock_veil_01
      - clock_wooden_case_joinery
      - clock_brass_movement_plate
      - clock_leaf_boulle
```
