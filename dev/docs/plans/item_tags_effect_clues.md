# Item Tags and Effect Clues Rework

## Goal

Replace the price-modifier clue system and affix combination tables with a compact information economy: three fixed tags per anchor (period, element, type) become the shared demand language between buying and selling, and a global pool of at most 20 effect-based clues turns clue knowledge into packing and selling decisions instead of inert price deltas. This collapses a content surface players experience as noise (~170 clues, ~80 affix combinations) into a vocabulary small enough to actually learn, delivering the progression fantasy the affix dictionary plan tried to buy with far more machinery.

## Requirements

1. Every anchor carries three fixed authored tags — period (5-step ordered axis), element (material family), type (object family) — visible as soon as the anchor is known, because tags are identity rather than secrets; the information asymmetry lives entirely in the hidden clue.
2. Customer demand is expressed only in tag vocabulary. Customers stop demanding raw clue ids or anchors, because raw clue demands are unreadable and unpredictable on the buy side, while tag demands let the player forecast tonight's sales while still standing at the auction.
3. The clue pool shrinks to at most 20 clues globally. A clue is an id plus an effect — display names are dropped and the UI presents the effect text directly, because the flavor-name layer was the main source of "meaningless string" noise.
4. Every item carries exactly one affix, one surface clue, and one hidden clue. The surface clue is drawn at random from the surface pool with no affix correlation (deliberate: surface must not leak hidden information — the affix alone carries the inference signal); the hidden clue is drawn from the affix's weighted hidden pool, so the affix stays the player's inference frame for the authenticate bet.
5. Affix combination tables are removed. An affix reduces to a display name plus a weighted hidden pool of 3–4 clues; total affix count stays around 6–10 so the full affix-to-hidden-pool table is memorizable by a veteran without external notes.
6. Two or three hidden clues are identity overrides (jackpot or counterfeit) implemented as a compound value transform — minimum floor, multiplier, additive shift, resolved in that fixed order — absorbing the former replace-override draft; this preserves the open-the-box thrill the brand reveals used to provide.
7. Progression feedback ships in the same rework as a lightweight auto-collected notes surface: clue effect entries unlock on first encounter, affix entries list their hidden pool as locked rows until observed, and probability display is gated by category mastery rank — superseding the affix dictionary plan.
8. Old saves must load: owned legacy items convert into the new model (tags derived from their anchor, clue slots remapped or redrawn deterministically) following the existing per-store migration pattern.

## Design

### Tags

Three axes, fixed per anchor and authored directly in anchor data. The anchor keeps its existing base value, shape, weight, and tier; tags are additional identity fields.

- Period — ordered: Ancient → Medieval → Renaissance → Industrial → Modern. The ordering is load-bearing: adjacency effects shift demand eligibility along this axis.
- Element — closed vocabulary, proposed six values: metal, wood, glass, ceramic, textile, paper. Adding a value requires content-review justification, because every new value dilutes demand-match density.
- Type — object family, closed vocabulary, proposed six values: furniture, accessory, art, instrument, decor, document. Authored per anchor rather than derived from category, so two anchors in the same category may carry different types.

Tags become visible the moment the anchor is known (unveil / first inspect). Veterans who memorize anchor→tag mappings can forecast sale fit from the lot preview — that memorization is intended progression, not a leak.

Customer demand: each customer persona draws its demand as tag predicates (for example "period: Industrial", "element: metal"). At sale, each matched demand predicate multiplies the item's sale price by ×1.25 (starting value for the balance pass, not a commitment). Customers accept non-matching items at unmodified price, preserving the current "fill the car anyway" flexibility.

### Effect clues

At most 20 clues globally. Each clue is: id, slot (surface or hidden), effect. Proposed effect archetypes with starting numbers:

| Archetype | Slot bias | Example effect |
| --- | --- | --- |
| Tag range | surface | Period adjacency +1: item also satisfies demands for neighboring periods |
| Cargo bonus | surface | +250 sale price for every other item loaded in the same customer car |
| Element synergy | surface | Sale price ×(1 + 0.1×N), N = co-loaded items sharing this item's element |
| Sale restriction | hidden | Cannot be sold while condition < 0.75 (feeds the repair loop) |
| Cargo penalty | hidden | −250 per co-loaded item; a sale may resolve negative |
| Identity jackpot | hidden | "Maker original": compound transform, e.g. floor 100, ×3.0, +0 |
| Identity counterfeit | hidden | Compound transform, e.g. floor 100, ×0.2, −100 |

The surface pool skews toward logistics and synergy effects that are readable before sale; the hidden pool holds risk and identity effects. Negative effects are first-class content, because a hidden clue that can hurt is what makes the authenticate decision a real bet.

### Affixes as inference frames

6–10 affixes, single affix per item, item name = affix + anchor ("Suspicious Pocket Watch"). Each affix's hidden pool is a themed 3–4 clue set answering one player question. Examples:

- Suspicious (authenticity question) → identity counterfeit (weight 2), identity jackpot (weight 1), sale restriction (weight 1).
- Restored (alteration question) → sale restriction (weight 2), cargo bonus (weight 1), identity counterfeit (weight 1).

Authoring rule: if an affix's pool starts answering two unrelated questions, split the affix instead of growing the pool.

The veteran read is: affix + tags + condition + current bid → estimated hidden distribution → authenticate, gamble, or skip. This is the "reverse the full picture from partial information" loop, achieved with an at-most 10×4 table instead of combination matrices.

### Price pipeline

- Appraised value = anchor base × condition multiplier.
- Verified value = appraised value with the hidden identity transform applied, if the hidden clue is one (floor → multiplier → shift, in that order).
- Sale price = item value × sell-mode multiplier (conservative / aggressive dice, unchanged) × tag-match multipliers, then car-context effects (cargo bonus, penalty, element synergy) applied per loaded car.
- The cross-flow invariant "all item prices resolve through the single item price pipeline" is preserved for item-level value. Car-context effects are a sale-time layer owned by the sell math, because they depend on co-loaded items and cannot be a property of one item. The sell flow must itemize these contributions on screen before the player confirms, or effect clues degrade back into opaque number changes.

### Hub research and reveal

With one hidden clue per item, hub research becomes a single progress track per item: the hidden clue carries a research requirement, the relevant attribute contributes progress per spend, and completion reveals the hidden clue and marks the item verified. This absorbs the former research reveal redesign draft. Inspection is unchanged: run-phase rolls reveal the surface clue slot.

### Notes and mastery

Auto-collected, zero-input glossary replacing the affix dictionary plan:

- A clue effect entry unlocks the first time that clue is revealed anywhere.
- An affix entry appears when the affix is first seen; its hidden pool renders as locked rows until each member has been observed at least once.
- Probability display on affix pools gates by category mastery rank: none → qualitative ("likely / possible / unlikely") → rounded percent → exact weighted percent.
- Higher mastery may additionally pre-reveal the surface clue on inspection without a roll (absorbs the mastery–clue integration draft; thresholds tuned later).

### Content migration

Clue and affix content is rewritten from scratch — the current sets are not convertible. Anchors gain three tag fields; customer personas' demand pools are rewritten in tag vocabulary; the balance preview tooling is reworked around tag and effect distributions. The item YAML restructure chore is absorbed here.

## Non-Goals

1. No multi-affix generation; one affix per item is the contract.
2. No location-based probability overlays or location-biased hidden draws.
3. No weighted or calendar-driven customer tag pools — stays in the Customer System Evolution draft.
4. No final economy numbers — multipliers in this plan are starting inputs for the balance preview, not commitments.
5. No posterior assistant that computes the best action for a live item; notes inform judgment, they do not replace it.
6. No weekly order rework in this plan — its clue-requirement design is invalidated (items now carry two clues total) and must move to tag + effect requirements in its own plan pass.

## Acceptance Criteria

1. Every generated item carries exactly one affix, one surface clue, one hidden clue, and three tags; tags are visible once the anchor is known.
2. The global clue pool contains at most 20 clues; no clue has a display name; every player-facing clue row shows effect text.
3. Customer demand is expressed and matched purely in tags; no customer references a clue id or anchor.
4. Affix combination data is gone from content and generation; hidden draws come only from the item's affix pool, surface draws show no correlation with the affix.
5. Authenticate can still produce jackpot and counterfeit swings via identity transforms, resolved floor → multiplier → shift.
6. Sale-time effects (adjacency, cargo bonus/penalty, element synergy, restriction) resolve visibly in the customer sell flow with itemized contributions the player can read before confirming.
7. Notes entries unlock from play, persist across save/load, and probability text upgrades with category mastery rank.
8. Old saves load without loss: legacy owned items appear with valid tags and clue slots via the per-store migration pattern.
