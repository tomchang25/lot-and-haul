# Lot & Haul — Roadmap

High-level milestones and deferred systems. Not an implementation spec — this is a decision log and dependency map.

---

## Value Hierarchy

Every price resolves through the shared pricing pipeline. A config object toggles which factors participate; there is no per-type formula living outside the pipeline.

Items carry three clue tiers: one **anchor clue** (flat base value, auto-revealed on first inspect), zero or more **surface clues** (price modifiers, discoverable during inspection, auto-revealed on hub return), and zero or more **hidden clues** (only revealed by Authenticate or passive conditions, can be positive or negative).

| Name              | Basis                                           | Range | Role                                       |
| ----------------- | ----------------------------------------------- | ----- | ------------------------------------------ |
| `appraised_value` | anchor × revealed surface modifiers             | yes   | base for all display and selling           |
| `verified_value`  | anchor × all surface × all hidden modifiers     | no    | replaces appraised for authenticated items |
| `market_price`    | appraised/verified × condition × market factor  | no    | car total input                            |
| `car_total`       | sum of item market_prices (verified items ×1.2) | no    | customer transaction base                  |
| `sell_price`      | car_total × sell multiplier                     | no    | final transaction price                    |

Naming convention: `_value` = appraisal-side, `_price` / `_total` = transaction-side.

Verified items use `verified_value` in place of `appraised_value` as pipeline input, and receive ×1.2 on their individual contribution to car total. Verified value may be higher or lower than appraised — hidden clues can be negative.

Sell multiplier: conservative = flat ×1.2; aggressive = dice result (×1.0 / ×1.5 / ×0.8 depending on roll). See Phase 9 spec.

Range convergence: appraised value shows as a range when not all surface clues are revealed. Spread = `max_spread × (1.0 - reveal_ratio)`. At ratio 1.0 the range collapses to the exact appraised value.

---

## Core Loop Design Principles

1. **Clue-driven perceived value ≠ Verified item value** — The player's perceived price is the sum of revealed clue modifiers on top of a category base. The true item identity and base price are hidden until verification.

2. **Inspection is fast, probabilistic information** — Player spends AP pre-auction to attempt clue discovery. Each attempt is a dice roll against the clue's difficulty, modified by the player's attributes. Success reveals the clue and its price modifier; failure spends the AP with no result.

3. **Storage is slow, high-return** — The core Storage payoff is Authenticate: marks an item verified, reveals hidden clues (positive or negative), and unlocks selling bonuses (×1.2 price, +1 die, hidden tag matching).

4. **Clues are price modifiers** — Each clue directly changes the item's perceived value: flat bonuses, multipliers, or conditional modifiers that interact with other revealed clues. Clues are both information and economy.

5. **True price only revealed by verification** — Before verification, the player sees category base + revealed clue modifiers. After verification, the true item name and base price are shown. The gap between clue-derived value and verified base price is the profit incentive.

6. **Unified selling through customers** — All selling goes through the nightly customer system: tag matching, car grid packing, and conservative/aggressive sell. No Quick Sell, no merchant negotiation, no special orders. Verification provides selling bonuses, not channel access.

7. **Data semantics are owned by YAML** — Item definitions, clue pools, and naming rules are authored in YAML; the pipeline generates engine resources. Runtime code is agnostic to content.

8. **Clue discovery is probabilistic** — Revealing a clue requires an attribute check (dice roll + attribute bonus vs. difficulty). This replaces the old deterministic skill/rank gate system with a more game-like feel that rewards investment without guaranteeing outcomes.

---

## Completed Phases

Phases 0–6 cover the foundational work. Detailed specs omitted — see git history and code.

| Phase | Title                                    | Status                                                                                                    |
| ----- | ---------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| 0–2   | Runtime veil cleanup, AP grid inspection | ✅ Complete                                                                                               |
| 3     | Item base price + abstract identity data | ✅ Complete                                                                                               |
| 4     | Clues + AP inspection (layer-based)      | ⚠️ Superseded — clue data structures exist but the layer-based advancement model is replaced by Phase 7   |
| 5     | Hub final layer resolution               | ⚠️ Superseded — auto-advance logic exists but will be removed when identity layers are deleted in Phase 7 |
| 6     | Storage Authenticate                     | ✅ Complete — verified flag, rarity-based duration, slot action all operational                           |
| 7     | Clue Independence + Attribute System     | ✅ Complete — identity layers/skills removed, clue-based pricing, SPECIAL attributes, dice inspection     |
| 7.5   | Inspection Refinement                    | ✅ Complete — veiled/unveiled/verified vocabulary, chain reveal, lot unveil probability                   |
| 8     | Dynamic Naming Rules                     | ✅ Complete — ClueData naming_slot/priority, display_name composition, validator rules                    |
| 8b    | YAML Content Regeneration                | ✅ Complete — all 128 clues rewritten to 1-word known_text, naming entries assigned, names reconciled     |

---

## Core Loop Redesign — Phase Plan

**Phases 7, 7.5, 8, and 8b are complete.** Phase 10 (Value Policy Cleanup) is next. Phase 9 (Merchant System Redesign) follows after Phase 10.

### Phase 7 — Clue Independence + Attribute System ✅

**Status: Complete** (PR #107 merged)

**Goal:** Replace identity layers and the skill system with independent clue resources and attribute-based discovery.

**What shipped:**

- Items = category + anchor clue + surface clues + hidden clues. Identity layers, layer advancement, SkillData, SkillLevelData all removed.
- ClueData with `type` (anchor | surface | hidden), `domain`, `attribute`, `dc`, `effect_op`, `effect_amount`.
- 5 SPECIAL-style attributes (Appraisal, Perception, Restoration, Negotiation, Investigation) replace skill system. Perks gate on attribute thresholds.
- Inspection: 1 AP = dice roll vs DC. Success rate = `clamp((21 + bonus - DC) × 5, 5, 95)`. Anchor auto-reveals; surface clues auto-reveal on hub return.
- Authenticate reveals hidden clues (can be positive or negative).
- Add-then-mul pricing: `(anchor_flat + sum surface_add) × product surface_mul`.
- Unified tag vocabulary — clue table is the single source of truth, validated by pipeline.
- `ItemData.base_price` deprecated — true value now derived entirely from clues.

**Deferred to later:**

- Mastery ↔ clue integration effects (see Draft Features)
- Attribute upgrade cost scaling (see item_system.md draft)

_Full spec: `dev/docs/archived/phase_7_clue_independence.md` `dev/docs/systems/item_system.md`_

---

### Phase 7.5 — Inspection Refinement ✅

**Status: Complete** (commit `e59d58e`)

**Goal:** Refine inspection semantics, item display naming vocabulary, and clue reveal mechanics left unresolved after Phase 7.

**What shipped:**

- `DisplayState` enum (VEILED / UNVEILED / VERIFIED) and unified naming vocabulary across all code, UI, and docs. Veiled = anchor unrevealed ("Unknown [Category]"); unveiled = anchor revealed (anchor known_text); verified = all hidden clues revealed (true item name).
- Unveil action costs a fixed 1 AP. Chain reveal costs 2 AP per attempt; on success, immediately attempts the next unrevealed clue in sequence until a check fails or clues are exhausted.
- Lot unveil probability field — each item in a lot rolls independently to determine starting veil state.
- Clue results display in a dedicated section, separate from the value column.
- `verified` is now a computed property (true when all hidden clues are in `revealed_clue_ids`); items with no hidden clues are verified by default.
- Storage Authenticate renamed to Research.

_Full spec: `dev/docs/archived/phase_7_5_inspection_refinement.md`_

---

### Phase 8 — Dynamic Naming Rules ✅

**Status: Complete** (commits `3c4c423`, `e59d58e`)

**Goal:** Replace the binary display name with a priority-based affix composition system that assembles the item's visible name progressively as clues are revealed.

**What shipped:**

- `naming_slot` (prefix / body / suffix) and `naming_priority` fields on `ClueData`.
- `display_name` computed property on `ItemEntry`: assembles from highest-priority revealed clue per slot; falls back to "Unknown Item" when no naming clues are revealed; verified items bypass composition and show `item_data.item_name` directly.
- Three-word `known_text` ceiling enforced by `validate_yaml.py`.
- Full-reveal composition validation: composed name must equal `item_name` — mismatch is a pipeline error.
- YAML pipeline (`tres_lib/entities/clue.py`, `yaml_to_tres.py`) updated for naming fields.
- Generation prompts (`base.md`, `item.md`) document naming entry schema, slot/priority conventions, and 1-word preferred / 3-word max rule.

**Phase 8b — YAML Content Regeneration** (commit `19c6caf`): bulk content pass on all existing clues and items.

- All 128 clue `known_text` values rewritten to 1-word labels.
- Naming entries (`slot`, `priority`) assigned to every clue (anchors → body prio 1, surfaces → prefix prio 2, hidden → prefix prio 5).
- Item names reconciled to 2-word prefix+body format matching full-reveal composition.
- Validator reports zero naming-match and known_text-length errors.

_Full spec: `dev/docs/archived/phase_8_dynamic_naming_rules_impl_spec.md`_

**Dependencies:** Phase 7

---

### Phase 9 — Merchant System Redesign

**Goal:** Replace all existing selling channels with a unified customer-based system. Nightly customers arrive with demand tags and car grids; the player fills cars and chooses a sell strategy.

**Design decisions:**

- 3–5 customers per night. Each has demand tags (clue ids, uniform random) and a car grid (random from hardcoded size list).
- Item list per customer filters to fit ≥ 1 only. Fit = set intersection of customer demand tags and item's revealed clue ids. Tag = clue.
- **Conservative sell:** flat ×1.2 on entire car total. No dice.
- **Aggressive sell:** dice pool from best single-item fit in the car (fit 1→2d, fit 2→4d, fit 3→6d). Each verified item adds +1 die. Player rolls all, selects 2. Sum: 2–5 = ×1.0, 6–10 = ×1.5, 11–12 = ×0.8.
- Verified items: ×1.2 price bonus on individual car contribution, +1 die, hidden clue tags count toward fit.
- Player sees result before confirming sale. Declined items return to storage.
- **Deprecations:** pawn_shop, antique_dealer, special order system, Quick Sell, merchant negotiation dialog — all removed.

**Scope:** Customer data model, demand tag generation, car grid packing UI, fit calculation, sell flow (conservative + aggressive), dice UI, verified bonuses, deprecation of all old selling systems. Excludes customer personality, progression-weighted generation, selling-related perks.

**Dependencies:** Phase 7, Phase 10

_Full spec: `dev/docs/plan/merchant_system_redesign.md`_

---

### Phase 10 — Value Policy Cleanup

**Goal:** Centralise verified / unverified item value resolution; eliminate price rules scattered across scenes.

**Design decisions:**

- Unverified display value: anchor + revealed clue modifiers.
- Verified display value: anchor × all surface × all hidden modifiers.
- All selling flows use `market_price` (appraised/verified × condition × market factor) as the item's contribution to car total.
- Verified items receive ×1.2 on their car contribution.

**Scope:** Centralised value helper, migration of existing callers. Excludes full UI redesign.

**Dependencies:** Phase 7

---

### Phase 11 — Day Summary Rework

**Goal:** Resolve the psychological harm caused by the Net figure showing the player as perpetually losing money.

**Design decisions:**

- Net can be kept or removed depending on cash-flow feel once customer selling is live.
- Non-auction days may skip summary entirely and return directly to hub.

**Scope:** Day Summary UI adjustments. Excludes weekly system, Weekly Report, fixed-deduction game over.

**Dependencies:** Phase 9

---

### Superseded Phases

The following phases from the previous roadmap are fully superseded by the merchant system redesign (Phase 9):

| Old Phase | Old Title                             | Reason                                                                       |
| --------- | ------------------------------------- | ---------------------------------------------------------------------------- |
| 9 (old)   | Special Order Verified Integration    | Special orders deprecated; verified bonus integrated into customer sell flow |
| 11 (old)  | Player Shop                           | All selling unified through customer system                                  |
| 12 (old)  | Garage Auction + Merchant Deprecation | Merchant deprecation handled in Phase 9; garage auction concept replaced     |

---

### Phase Dependency Graph

```
Phase 7  — Clue Independence + Attributes  ✅
  └─ Phase 7.5 — Inspection Refinement      ✅
Phase 8  — Dynamic Naming Rules             ✅
  └─ Phase 8b — YAML Content Regeneration   ✅
Phase 10 — Value Policy Cleanup             ← next
  └─ Phase 9  — Merchant System Redesign (depends on 7, 10)
       └─ Phase 11 — Day Summary Rework
```

Phases 7, 7.5, 8, and 8b are complete. Phase 10 is unblocked and is next. Phase 9 depends on both 7 and 10.

---

## Other Current Work

These are independent of the core loop redesign phases and can proceed in parallel.

- **Customer content** — demand tag pools, car grid size list, and customer generation tuning. `pawn_shop` and `antique_dealer` merchant content is deprecated; `arms_dealer` and `fashion_buyer` are evaluated separately for potential conversion to customer archetypes or removal.
- **Director system** — skeleton to get all three demo runs flowing end-to-end with placeholder content. See `dev/docs/plan/demo_summary.md`.
- **Dialog system** — linear first, Uncle branching second.
- **Bank / Bankruptcy** — daily interest, game-over condition, optional loans.

---

## Pending Features

**Content & calibration (post-Phase 7+):** Attribute costs, customer generation weighting, and perk balance don't stabilise until earlier systems impose real constraints on a run.

**Attribute growth design:** How do attributes increase? Starting model: spend cash to increase by 1. More complex models (per-run rewards, daily training slots, mastery-gated upgrades) are explored after the base system is stable.

**Market system evolution:**

- **Mean-reversion drift** — replace pure random walk with drift that pulls super-category means back toward 1.0; the current walk can leave a category depressed or inflated forever.

**Customer system evolution (post-Phase 9):**

- **Weighted tag pools** — demand tags influenced by in-game calendar, events, or player progression instead of uniform random.
- **Regular customers** — fixed-profile customers that visit periodically, giving the player predictable selling targets.
- **Customer quality tiers** — budget buyers vs. collectors with different multiplier tables or car grid sizes.
- **Selling-related perks** — perks that modify selling mechanics (reroll a die, preview customer demands before a run, etc.).

**Acquisition cost tracking on ItemEntry:** ItemEntry has no record of what the player paid. Proposed: at lot purchase resolution, distribute total paid price across won items proportional to each item's perceived value at that moment. Stored as a permanent field set once at acquisition, never modified.

---

## Draft Features

- **Reputation + Scam Flow** — faction reputation, scam detection branches. Builds on customer system.
- **Expert Network (Appraisers)** — design question unresolved.
- **Museum / Prestige** — prestige design decisions needed first.
- **Auction Modifier: All-Base-Layer Run** — requires auction modifier system design.
- **Training Courses** — training resource, hub Training button. Deferred.
- **Category Mastery ↔ Clue Integration** — Mastery as "experience-based intuition": at certain category mastery ranks, inspection shows unrevealed clue count, or auto-reveals the easiest surface clue for that category. Mastery does not affect DC or success rate (that's attributes). Exact thresholds and effects TBD. See Phase 7 spec for draft details.
