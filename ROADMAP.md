# Lot & Haul — Roadmap

High-level milestones and deferred systems. Not an implementation spec — this is a decision log and dependency map.

---

## Value Hierarchy

Items carry three clue tiers: one **anchor clue** (flat base value, auto-revealed on first inspect), zero or more **surface clues** (price modifiers, discoverable during inspection, auto-revealed on hub return), and zero or more **hidden clues** (only revealed by Authenticate or passive conditions, can be positive or negative).

Clue math: add/subtract first, then multiply. `(anchor_flat + Σ surface_add) × Π surface_mul`. Verified items additionally apply hidden modifiers in the same add-then-mul order.

| Name              | Basis                                            | Range | Role                             |
| ----------------- | ------------------------------------------------ | ----- | -------------------------------- |
| `appraised_value` | anchor + revealed clue modifiers (add-then-mul)  | yes   | base for all display and selling |
| `verified_value`  | appraised + hidden clue modifiers (add-then-mul) | no    | replaces appraised when verified |
| `item_price`      | (appraised or verified) × condition_multiplier   | no    | resolved per-item price          |

Condition is an independent system (0.0–1.0, non-linear bucketing into ×0.25–×4.0) tied to Repair/Restore research. It multiplies into item_price but is not a clue.

Market factor and knowledge bonus are removed — customer fit + sell strategy replaces their design role.

Verified items use `verified_value` in place of `appraised_value` as item_price input, and receive ×1.2 on their individual car contribution. Verified value may be higher or lower than appraised — hidden clues can be negative.

Transaction-level pricing (car total, sell multiplier, verified bonus) is owned by the customer/shop system — see Phase 9 (complete).

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
| ----- | ---------------------------------------- | --------------------------------------------------------------------------------------------------------- | -------------------------------- |
| 0–2   | Runtime veil cleanup, AP grid inspection | ✅ Complete                                                                                               |
| 3     | Item base price + abstract identity data | ✅ Complete                                                                                               |
| 4     | Clues + AP inspection (layer-based)      | ⚠️ Superseded — clue data structures exist but the layer-based advancement model is replaced by Phase 7   |
| 5     | Hub final layer resolution               | ⚠️ Superseded — auto-advance logic exists but will be removed when identity layers are deleted in Phase 7 |
| 6     | Storage Authenticate                     | ✅ Complete — verified flag, rarity-based duration, slot action all operational                           |
| 7     | Clue Independence + Attribute System     | ✅ Complete — identity layers/skills removed, clue-based pricing, SPECIAL attributes, dice inspection     |
| 7.5   | Inspection Refinement                    | ✅ Complete — veiled/unveiled/verified vocabulary, chain reveal, lot unveil probability                   |
| 8     | Dynamic Naming Rules                     | ✅ Complete — ClueData naming_slot/priority, display_name composition, validator rules                    |
| 8b    | YAML Content Regeneration                | ✅ Complete — all 128 clues rewritten to 1-word known_text, naming entries assigned, names reconciled     |
| 9     | Merchant System Redesign                 | ✅ Complete — Customer data model, car grid packing UI, fit/sell flow, dice UI, legacy selling removed    |
| 10    | Value Policy Cleanup                     | ✅ Complete — MarketManager, PriceConfig, compute_price removed; item_price simplified to (appraised      | verified) × condition_multiplier |
| 11    | Day Summary Rework                       | ✅ Complete — customer_sales_today captured into DaySummary before clear, net change includes sales revenue, customer sales section in summary scene, post-run routes through summary |

---

## Core Loop Redesign — Phase Plan

**Phases 7–11 are complete.** Phase 12 (Time-Slot + Storage AP) is next.

### Phase 7 — Clue Independence + Attribute System ✅

**Status: Complete** (PR #107 merged)

Clue-based pricing (add-then-mul), 5 SPECIAL attributes, dice-roll inspection, deprecated `ItemData.base_price`. Full spec: `dev/docs/archived/phase_7_clue_independence.md`

---

### Phase 7.5 — Inspection Refinement ✅

**Status: Complete** (commit `e59d58e`)

`DisplayState` (VEILED/UNVEILED/VERIFIED), chain reveal, lot unveil probability, `verified` as computed property. Full spec: `dev/docs/archived/phase_7_5_inspection_refinement.md`

---

### Phase 8 — Dynamic Naming Rules ✅

**Status: Complete** (commits `3c4c423`, `e59d58e`)

Priority-based `display_name` composition from naming clues, 3-word `known_text` ceiling, full-reveal validation. Phase 8b (commit `19c6caf`): regenerated all 128 clues to 1-word labels with naming entries. Full spec: `dev/docs/archived/phase_8_dynamic_naming_rules_impl_spec.md`

**Dependencies:** Phase 7

---

### Phase 9 — Merchant System Redesign ✅

**Status: Complete** (commit `236f636`, PR #108 cleanup `9b4dfe9`)

`Customer` runtime type with `generate_for_night()`, `SellMath` pure helpers (conservative ×1.25 / aggressive dice bands), customer sell scene with car grid packing and dice UI, `SaveManager.customer_sales_today` ledger, legacy selling code removed. Full spec: `dev/docs/archived/phase_9_merchant_system_impl_spec.md`

**Dependencies:** Phase 7, Phase 10

---

### Phase 10 — Value Policy Cleanup ✅

**Status: Complete** (commit `41a5945`)

`item_price` simplified to `(appraised|verified) × condition_multiplier`. `MarketManager`, `PriceConfig`, `ItemViewContext` removed. Condition stays as independent ×0.25–×4.0 system.

**Dependencies:** Phase 7

---

### Phase 11 — Day Summary Rework ✅

**Status: Complete**

`DaySummary` value object now carries `customer_sales_total`, `customer_sales_detail`, and `has_customer_sales()`. `MetaManager.advance_days()` captures `SaveManager.customer_sales_today` into the summary before `_generate_nightly_customers()` clears the ledger. Net change includes customer sales revenue. Summary scene renders a customer sales section (count, total, strategy breakdown). Post-run flow routes through the day summary scene.

**Dependencies:** Phase 9 ✅

---
### Phase 12 — Time-Slot Day Structure + Storage AP Economy

**Goal:** Replace the passive day-counter hub with a three-slot day model (morning / afternoon / evening) so each day is an explicit resource-allocation decision, and convert storage actions from day-timers to an AP economy.

**Activities (one per slot):**

- **Auction** — available only from morning, consumes morning + afternoon (two slots); player returns in the evening with one slot left. One auction per day.
- **Storage maintenance** — spend AP for Repair (condition → 0.5), Restore (condition → 1.0), and Research (reveal one hidden clue per attempt). Each action costs AP from a daily pool instead of ticking calendar days. This replaces the current `ResearchSlot` day-tick model (`REPAIR`/`RESTORE`/`RESEARCH` in `MetaManager._tick_research_slots`).
- **Open shop** — ends the day immediately; customer count scales with consecutive slots dedicated (more slots → more customers, with a full-day bonus).

**Wiring already present:** `Customer.generate_for_night(rng, storage_items, count, …)` takes an explicit `count` (negative = roll the default 3–5). The time-slot economy passes a slot-derived count here instead of the default roll.

**Core tension:** auction eats two slots, leaving one for light storage or a small evening shop; skipping auction frees all three for heavy maintenance, a full shop day, or a mix.

**Open questions (carried from the draft):**

- Shared vs. separate AP pool for inspection and storage maintenance.
- Daily AP pool sizing — flat, attribute-derived, or upgradeable (starting assumption: flat).
- Customer-count curves per slot config (starting assumptions: 1 slot → 2–3, 2 slots → 5–7, 3 slots → 8–12; needs playtest).

**Dependencies:** Phase 9 ✅. Should land before/with Phase 11 so the summary reflects the slot model. Storage AP changes touch the same `ResearchSlot` plumbing.

_Reference: `dev/docs/draft/time_slot_economy.md`._

---

### Phase Dependency Graph

```
Phase 7  — Clue Independence + Attributes  ✅
  └─ Phase 7.5 — Inspection Refinement      ✅
Phase 8  — Dynamic Naming Rules             ✅
  └─ Phase 8b — YAML Content Regeneration   ✅
Phase 10 — Value Policy Cleanup             ✅
Phase 9  — Merchant System Redesign (depends on 7, 10)  ✅
  └─ Phase 11 — Day Summary Rework (depends on 9)       ✅
  └─ Phase 12 — Time-Slot + Storage AP (depends on 9)   ← next


Phases 7–11 are complete. Phase 12 (Time-Slot + Storage AP) is next.

---

## Other Current Work

These are independent of the core loop redesign phases and can proceed in parallel.

- **Customer content** — demand tag pools, car grid size list, and customer generation tuning. Legacy merchants (`pawn_shop`, `antique_dealer`, `arms_dealer`, `fashion_buyer`) are removed — customer archetypes or tag-biased generation replace their content role.
- **Director system** — skeleton to get all three demo runs flowing end-to-end with placeholder content. See `dev/docs/plans/demo_summary.md`.
- **Dialog system** — linear first, Uncle branching second.
- **Bank / Bankruptcy** — daily interest, game-over condition, optional loans.

---

## Pending Features

**Content & calibration (post-Phase 7+):** Attribute costs, customer generation weighting, and perk balance don't stabilise until earlier systems impose real constraints on a run.

**Attribute growth design:** How do attributes increase? Starting model: spend cash to increase by 1. More complex models (per-run rewards, daily training slots, mastery-gated upgrades) are explored after the base system is stable.

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
