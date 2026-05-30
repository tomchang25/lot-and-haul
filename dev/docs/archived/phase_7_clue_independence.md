# Phase 7 — Clue Independence + Attribute System

## Goal

Replace identity layers and the skill system with independent clue resources and attribute-based dice checks. Items become a category plus a set of clues; perceived value emerges from which clues the player has revealed.

## Context

The existing identity-layer / skill system has three problems: skills are homogeneous (all follow the same level-gate pattern with no meaningful difference), the layer-chain model adds complexity without proportional gameplay depth, and deterministic gates don't produce interesting decisions for a casual-tone game. This phase replaces all of it with a simpler model: clues carry price modifiers, attributes affect discovery rolls, and dice produce the uncertainty.

## Design Principles

- **Tag = Clue** — A clue's id is its tag. Customer demands (Phase 9) are sets of clue ids. Fit = set intersection. No sub-tag layer.
- **Clue dual classification** — Every clue carries two orthogonal string fields: `type` (reveal mechanic: anchor | surface | hidden) and `domain` (content scope: generic | specific category_id). No separate table needed.
- **Unified tag vocabulary** — All clue ids share a single namespace validated by the YAML pipeline. `validate_yaml.py` enforces that all item `clue_ids` reference entries in the clue table — the clue table itself is the single source of truth (no separate `tags.yaml` needed).

---

## Three Clue Types

Every item carries a set of clues drawn from three types. Each clue is a standalone designer resource with its own id, display text, price effect, and discovery rules.

### Clue Data Model

Each clue has two classification fields:

```
clue:
  id: "vintage_tube_amp"
  type: "surface"            # anchor | surface | hidden — controls reveal mechanic
  domain: "audio_equipment"  # generic | <category_id> — controls content scope
  attribute: appraisal
  dc: 12
  price_effect: "×1.4"
```

`type` determines when and how the clue is revealed. `domain` determines which items the clue can appear on — `generic` clues can be assigned to any category, category-specific clues only to items in that category. Both are strings; no separate lookup table.

### Anchor Clue

One per item. Represents the item's base identity — what it fundamentally is.

- Auto-revealed on first inspect (no roll, no AP cost beyond the initial inspect action).
- Price effect is always a flat value (e.g. `+3000`). This is the item's price anchor.
- Before the anchor is revealed, the item's value shows as "???". The player knows the category but has no price signal.
- The anchor reveal is the first dramatic moment: "this thing is worth roughly $3000."

### Surface Clues

Zero or more per item. Represent observable details the player can discover during the Run phase.

- Each has a DC (difficulty class) and an associated attribute.
- Revealed during Inspection by spending AP (see Inspection Mechanism below).
- All unrevealed surface clues auto-reveal when the item enters Storage (hub return). This ensures the player always has full surface information for selling decisions — no clue stays locked just because they ran out of AP.
- Price effects: flat bonuses (`+500`), multipliers (`×1.5`), or conditional modifiers (`×2 if clue X is also revealed, ×0.5 otherwise`).
- Surface clues are the main source of appraised value beyond the anchor.

### Hidden Clues

Zero or more per item. Represent details that require deep analysis — not discoverable by casual inspection.

- Invisible during Inspection. The player doesn't know they exist until they're revealed.
- Revealed by Storage Authenticate (time-based research action, already implemented) or by meeting a passive condition (e.g. a specific attribute above a threshold — auto-revealed without spending a research slot).
- Can be positive (`×1.5 authentic signature`) or negative (`×0.3 confirmed forgery`). This makes Authenticate a risk/reward decision, not a guaranteed value increase.
- Hidden clues are the source of the gap between appraised value and verified value.

---

## Pricing Model

### Pricing Flow

```
Anchor unrevealed         → "???" (category known, no price)
Anchor revealed           → anchor_value (rough base)
Anchor + some Surface     → appraised_value = anchor × known_surface_modifiers
                            ± spread based on (revealed_surface / total_surface)
Anchor + all Surface      → appraised_value = anchor × all_surface_modifiers
                            (exact appraised value, no spread)
Authenticated             → verified_value = anchor × all_surface × all_hidden
                            (true final value, may be higher or lower than appraised)
```

### Value Hierarchy

Pricing pipeline layers that stack on top of the base appraised/verified value:

| Name              | Basis                                                          | Range                           | Role                                       |
| ----------------- | -------------------------------------------------------------- | ------------------------------- | ------------------------------------------ |
| `appraised_value` | anchor × known surface modifiers                               | yes (from surface reveal ratio) | base for all display and selling           |
| `verified_value`  | anchor × all surface × all hidden                              | no                              | replaces appraised for authenticated items |
| `market_price`    | appraised/verified × condition × market factor                 | no                              | car total input                            |
| `car_total`       | sum of item market_prices (verified items ×1.2)                | no                              | customer transaction base                  |
| `sell_price`      | car_total × sell multiplier (conservative ×1.2 or dice result) | no                              | final transaction price                    |

Verified items use `verified_value` in place of `appraised_value` as the pipeline input, and receive an additional ×1.2 bonus on their individual contribution to the car total. See `merchant_system_redesign.md` for the full selling mechanism.

### Spread Calculation

When not all surface clues are revealed, the appraised value shows as a range:

```
reveal_ratio = revealed_surface_count / total_surface_count   (0.0–1.0)
spread       = max_spread × (1.0 - reveal_ratio)
```

- `reveal_ratio` = revealed surface clue count / total surface clue count (0.0–1.0).
- Spread narrows linearly as ratio approaches 1.0. At ratio 1.0, spread is zero.
- Anchor-only (ratio 0.0) has the widest spread.
- `max_spread` is a tuning constant (starting point: 0.5). Calibrate against real item data during implementation.

---

## Inspection Mechanism

### Core Loop

1. Player selects an item in the inspection grid and chooses Inspect.
2. If the anchor clue is unrevealed, it auto-reveals (no roll). Show the anchor value. Done for this AP.
3. If surface clues remain, the system targets the unrevealed surface clue with the lowest DC (player can manually override to pick a different clue).
4. Display: **"Inspect — N% success"** (single number, single button).
5. Player confirms. 1 AP spent. Roll happens.
6. Success → clue text and price modifier revealed. Appraised value updates visually.
7. Failure → "You didn't find anything useful." AP consumed, clue stays hidden.
8. If no unrevealed surface clues remain, Inspect action is disabled (nothing left to find during inspection).

### Success Rate

```
success% = clamp((21 + attribute_bonus - DC) × 5, 5, 95)
```

- Floor 5% — there's always a chance, even against hard clues.
- Ceiling 95% — there's always a small risk, even against easy clues.
- Each +1 attribute bonus shifts success rate by 5 percentage points.
- A clue with DC 10 and attribute bonus +3: `(21 + 3 - 10) × 5 = 70%`.

### Retry

Failed clues can be reattempted on subsequent AP spends. The DC doesn't change. The player's decision is: "is it worth spending another AP to retry this 40% clue, or should I move to a different item?"

### Hub Auto-Reveal

When the player returns to hub and items enter storage, all unrevealed surface clues auto-reveal (no roll, no cost). This guarantees the player has full surface-level information for selling decisions. Only hidden clues remain unknown.

---

## Attribute System

### Replaces Skills — SPECIAL Model

The existing Skill pillar (SkillData, SkillLevelData, purchasable levels 0–5 with mastery/super-category gates) is removed entirely. In its place: a Fallout 4 SPECIAL-style attribute system — a fixed set of named numeric stats that provide bonuses to clue discovery rolls.

### Designer Surface

Each attribute is a named stat with a current value (starting at 1). Clue definitions reference an attribute and a DC:

```
clue:
  attribute: appraisal
  dc: 12
```

The player's `appraisal` attribute value is added to their roll when attempting this clue. The attribute set is fixed at design time (exact list TBD during implementation; starting candidates: Appraisal, Perception, Restoration, Negotiation, etc.).

### Perks

Perks are sourced from attribute thresholds. When an attribute reaches a specific value, it unlocks one or more perks. Perks are binary abilities that modify gameplay rules (e.g. `xray_inspect` reveals hidden clue count, a negotiation perk adds a reroll). The perk tree is designed per-attribute.

This replaces the old content-granted perk model. Perk data is authored in YAML alongside attribute definitions.

### Attribute Growth

Starting model: spend cash to increase an attribute by 1. No prerequisites. Cost may scale with current level (e.g. linear or quadratic). More complex models (per-run rewards, daily training, mastery-gated upgrades) are explored after the base system is stable.

### Mastery — Retained as Progression Signal

Mastery (category points → category rank → super-category rank → mastery rank) is retained as a level-equivalent progression indicator. It does **not** affect clue DC or discovery success rate (that is the attribute system's role).

Mastery's role in the clue system is informational — "experience-based intuition" vs. the attribute system's "technical ability":

- At certain category mastery ranks, Inspection UI shows meta-info: "this item has N unrevealed surface clues remaining."
- At higher ranks, the easiest surface clue for that category may auto-reveal during inspection (no roll, no AP).
- Exact thresholds and effects are **draft** — to be finalized after the attribute system is stable.

The four-layer derivation model (category → super-category → mastery) is preserved for now. Simplification is possible but deferred.

---

## Authenticate Redesign

Storage Authenticate already works (Phase 6 complete). The mechanical change in Phase 7:

- Authenticate reveals all **hidden clues** on the item (instead of revealing `ItemData.base_price` directly).
- Hidden clues can be positive or negative, so authenticating is a gamble — the verified value might be higher or lower than the appraised value.
- Authenticated items receive selling bonuses in the merchant system: ×1.2 price bonus on their car contribution and +1 die to the dice pool. Hidden clue tags also count toward customer fit.
- The `verified` flag marks the item as fully known. Duration by rarity is unchanged.

### Player Decision

"I appraised this at $5000 from surface clues. Do I sell now, or spend 5 days authenticating? It might turn out to be $8000 (authentic signature), or $1500 (confirmed forgery)."

This replaces the old model where authentication was always a net positive (guaranteed to reveal the true higher base_price).

---

## Removals

Code and data removed as part of this phase:

- IdentityLayer, LayerUnlockAction — deleted from data definitions.
- ItemEntry: `layer_index`, `advance_layer()`, `advance_to_final_layer()`, `inspection_level`, layer-based display name logic.
- KnowledgeManager: `get_level()`, `try_upgrade_skill()`, `peek_upgrade()`, `can_advance()`, skill registry.
- MetaManager: auto-final-layer logic in `resolve_run()` (replaced by surface clue auto-reveal).
- SkillData, SkillLevelData — deleted from data definitions.
- YAML identity layer authoring — replaced by clue list authoring.

---

## Scope

Includes: data definitions (ClueData restructure with type/domain fields, AttributeData, PerkData migration, ItemData migration), KnowledgeManager restructure, ItemEntry restructure, pricing pipeline (clue modifier step, spread formula), inspection scene adaptation, YAML schema migration, hub auto-reveal logic, unified tag vocabulary file, attribute growth (simple cash model).

Excludes: naming rules (Phase 8), merchant system / selling channels (Phase 9), pool-based generation (deferred draft in item_system.md), mastery integration details (draft, finalized post-attribute-stabilization).

## Acceptance Criteria

- Items are defined as category + anchor clue + surface clues + hidden clues in YAML. No identity layers. Each clue has `type` and `domain` string fields.
- Inspection spends 1 AP to attempt 1 surface clue with a single displayed success rate. Anchor auto-reveals on first inspect.
- Appraised value = anchor × revealed surface modifiers. Spread = `max_spread × (1.0 - reveal_ratio)`.
- Hub return auto-reveals all surface clues.
- Authenticate reveals hidden clues. Verified value may be higher or lower than appraised.
- SPECIAL-style attributes replace skills. Attribute bonus affects inspection success rate. Perks unlock at attribute thresholds.
- Mastery retained as progression signal. Does not affect DC or success rate.
- Unified tag vocabulary enforced by `validate_yaml.py` — all item `clue_ids` validated against the clue table (no separate tags file).
- All existing YAML item definitions successfully converted to the new format.
- All old layer/skill code paths removed. No regression in existing storage flows.
