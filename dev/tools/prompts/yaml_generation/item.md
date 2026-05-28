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
    known_text: "..." # shown to player after reveal; max 3 words
    type: anchor | surface | hidden
    domain: generic | <category_id> # use category_id (e.g. oil_lamp) for category-specific clues
    attribute: appraisal | perception | restoration | negotiation | investigation
    dc: <int> # difficulty class for discovery roll
    effect_op: flat | add | mul
    effect_amount: <number>
    naming: # optional — enables this clue to contribute to the display name
      slot: prefix | body | suffix # part of speech in the composed name
      priority: <int> # higher wins for the same slot; 0 = lowest
```

The `known_text` field serves double duty: it appears as the reveal description when the clue is discovered, and when a `naming` block is present, it contributes to the item's progressive display name.

**Three-word ceiling**: `known_text` must be three words or fewer on every clue (enforced by the YAML validator). **Prefer one word when possible** — especially for clues that carry a `naming` block, since prefix + body + suffix are joined with spaces and the composed name must stay readable. Two or three words are appropriate when a single word would be ambiguous or unnatural (e.g. `"Oil Lamp"` as a body is clearer than `"Lamp"` alone). Never pad to three words for the sake of it.

**Naming composition**: as clues are revealed, the highest-priority naming clue for each slot (`prefix`, `body`, `suffix`) contributes its `known_text`. Ties resolve by array order — the first clue in the slot wins. The three parts are concatenated with spaces. Before verification, this forms the player-visible name. After verification, the authored `item_name` is shown directly.

Under full reveal, the composed name must match `item_name` exactly (enforced by the YAML validator).

**Naming is the norm, not the exception.** Every standard item must have naming blocks on its clues. At full reveal the naming entries must resolve **at least one body slot and at least one prefix or suffix slot** — the validator enforces both. An item with only a body but no prefix or suffix will display as "Unknown {body}" (e.g. "Unknown Bow") until verification, because the runtime prepends "Unknown" when no qualifier has been revealed yet.

Items with no naming entries at all are a deliberate exception (e.g. a generic commodity or placeholder) and must be treated as such — they show "Unknown Item" until verified. This must be the minority case and should be noted in the item's comment in the YAML file.

---

## Rules by Clue Type

### Anchor (exactly 1 per item)

- `effect_op: flat` — sets the perceived base price. This is what the player sees on first reveal.
- `effect_amount`: positive integer. This is the item's visible starting price.
- `known_text`: the item's perceived category at first glance. Prefer **one or two words** — this becomes the body slot baseline and must leave room for prefix/suffix clues to join it. Write as a noun, not a sentence. Example: `"Oil Lamp"`, `"Pouch"`, `"Mantel Clock"`. Three words only when necessary for clarity.
- `dc` and `attribute` are not used (anchor auto-reveals on first inspect). Set `dc: 0` and `attribute: appraisal` as placeholders.
- `domain`: match the item's `category_id`.
- `naming`: convention — the anchor clue carries `slot: body` with a low priority (e.g. `priority: 1`), providing a baseline display name. Surface clues for maker, material, or style use `slot: prefix` or `slot: suffix` with higher priorities. Hidden clues for authentication or origin carry the highest priorities and may override the anchor's body text.

### Surface (0 or more per item, typically 2–5)

- `effect_op: add` — adds to the running price total.
- `effect_amount`: use `0` for lore clues (narrows the estimate spread but adds no value). Use a positive integer for value-adding details.
- `known_text`: a short label for what the player notices — **one word preferred, two or three only when a single word would be unclear**. Write as a noun or adjective, not a sentence. Examples: `"Blown"`, `"Victorian"`, `"Silver Collar"`, `"French Crystal"`. This text appears in the UI when the clue is revealed and contributes to the display name if a `naming` block is present.
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
- `known_text`: a short authentication result — **one or two words preferred**. Write as a terse verdict or specific identity, not a sentence. Examples: `"Forgery"`, `"Hinks & Son"`, `"Boulle"`. When a `naming` block is present this text displaces lower-priority body or suffix text at high priority.
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
- `item_name` is shown to the player only after all hidden clues are revealed (verified state). Before verification, the player sees the progressive affix name assembled from naming clues (see Naming Composition above).

---

## Clue ID Naming Convention

```
{category_id}_{aspect}_{detail}
```

- `{category_id}`: matches the item's domain (e.g. `oil_lamp`, `wristwatch`).
- `{aspect}`: the thing being examined (e.g. `glass_body`, `maker_mark`, `movement`).
- `{detail}`: the specific observation (e.g. `clear_font`, `registry_match`).

Anchor clue ids use the suffix `_anchor_NN` (e.g. `clock_anchor_01`). Hidden identity-reveal clue ids use the suffix `_leaf_{identifier}`.

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
  - clue_id: clock_anchor_01
    known_text: "Clock" # anchor: one word, body slot baseline
    type: anchor
    domain: clock
    attribute: appraisal
    dc: 0
    effect_op: flat
    effect_amount: 80
    naming:
      slot: body
      priority: 1

  - clue_id: clock_wooden_case_joinery
    known_text: "Hand-cut" # surface, no naming — price only
    type: surface
    domain: clock
    attribute: appraisal
    dc: 12
    effect_op: add
    effect_amount: 120

  - clue_id: clock_case_boulle_veneer
    known_text: "Boulle" # surface: one word, prefix slot
    type: surface
    domain: clock
    attribute: investigation
    dc: 16
    effect_op: add
    effect_amount: 800
    naming:
      slot: prefix
      priority: 5

  - clue_id: clock_leaf_boulle
    known_text: "Bracket" # hidden: one word, displaces anchor body at high priority
    type: hidden
    domain: clock
    attribute: investigation
    dc: 20
    effect_op: mul
    effect_amount: 1.85
    naming:
      slot: body
      priority: 10
```

```yaml
# items/*.yaml entry
items:
  - item_id: clock_boulle_marquetry
    item_name: Boulle Bracket Clock
    base_price: 4200
    category_id: clock
    rarity: 3
    clue_ids:
      - clock_anchor_01
      - clock_wooden_case_joinery
      - clock_case_boulle_veneer
      - clock_brass_movement_plate
      - clock_leaf_boulle
```

Notes on the example:

- Under full reveal: `prefix` = "Boulle" (priority 5); `body` = "Bracket" (priority 10, beats anchor's priority 1). Composed: `"Boulle Bracket"` — must match `item_name` exactly (validator enforces this).
- Before the hidden clue is revealed: `prefix` = "Boulle", `body` = "Clock" (anchor). Composed: `"Boulle Clock"` — specific enough to signal identification in progress.
- Before any surface naming clue is revealed: only anchor body → `"Clock"`.
- `clock_wooden_case_joinery` has no `naming` block — contributes price only. One-word `known_text` (`"Hand-cut"`) still satisfies the ceiling.
- Aim for one word per slot where possible: three single-word slots compose to three words total, which is already a tight readable name.
