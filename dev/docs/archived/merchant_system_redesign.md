# Phase 9 — Merchant System Redesign

## Goal

Replace all existing selling channels (pawn shop negotiation, antique dealer, special orders) with a unified customer-based system. Each night, customers arrive with specific demands and a car grid; the player fills the car with matching items and chooses a sell strategy.

## Context

The old merchant system has multiple overlapping channels (Quick Sell, Merchant Negotiation, Special Orders, planned Player Shop and Garage Auction) that each solve a narrow problem but create a fragmented selling experience. This redesign collapses all selling into one system that combines tag matching, spatial puzzle, and risk/reward dice — three proven mechanics that reinforce each other.

### Deprecations

The following systems are fully deprecated and removed by this phase:

- **pawn_shop** merchant and its negotiation dialog.
- **antique_dealer** merchant (including `antique_dealer_premium` / `antique_dealer_bulk` special orders).
- **Special Order** system (order slots, fulfillment panel, order generation).
- **Quick Sell** channel — no instant-sell fallback. Items that don't match any customer stay in storage.
- **Merchant Negotiation** dialog and `shopkeeper_offer` pipeline step.
- **Player Shop** (Phase 11 old) and **Garage Auction** (Phase 12 old) — never implemented, now superseded.

---

## Nightly Customer Flow

### Overview

Each night during the Hub phase, 3–5 customers arrive. Each customer has:

- **Demand tags** — a set of clue ids (e.g. `["90s", "guitar", "western"]`). Drawn uniform random from the unified tag vocabulary.
- **Car grid** — a 2D grid with specific dimensions, random-picked from a hardcoded size list.

The player views all customers simultaneously and decides which items from storage to assign to which customer's car.

### Selling Steps

1. Player sees all customers, their demand tags, and car grid dimensions.
2. For each customer, the item list shows only items with **fit ≥ 1** (at least one revealed clue id matches a demand tag).
3. Player drags items into the customer's car grid (spatial packing puzzle).
4. After loading, player chooses: **Conservative** or **Aggressive** sell.
5. Result is shown. Player confirms or declines the sale.
6. If confirmed, items are removed from storage, cash is added. If declined, items return to storage.

---

## Fit Calculation

Fit is computed per item, per customer:

```
fit = | customer_demand_tags ∩ item_revealed_clue_ids |
```

- Only **revealed** clue ids count. Surface clues are known (auto-revealed on hub return). Hidden clue ids count only if the item has been authenticated (verified).
- Fit 0 items do not appear in the customer's sellable item list.
- The **best single-item fit** across all items in the car determines the dice pool for aggressive sell.

### Tag Source

Customer demand tags and clue ids share the same namespace — the unified tag vocabulary defined in `tags.yaml` (or equivalent). A clue's id IS its tag.

---

## Sell Modes

### Conservative — No Dice

Flat **×1.2** multiplier on the entire car total. No randomness, instant confirmation.

### Aggressive — Dice

Dice pool size is determined by the **best fit among all items in the car**:

| Best item fit | Dice pool |
|---------------|-----------|
| fit 1 | 2 dice |
| fit 2 | 4 dice |
| fit 3+ | 6 dice |

Each verified (authenticated) item in the car adds **+1 die** to the pool. Multiple verified items stack.

All dice are d6. Player rolls the full pool, then **selects 2 dice**. The sum of the selected pair determines the multiplier:

| Sum of 2 | Multiplier | Meaning |
|-----------|------------|---------|
| 2–5 | ×1.0 | Neutral — no bonus |
| 6–10 | ×1.5 | Good deal |
| 11–12 | ×0.8 | Overplayed — customer pushes back |

The multiplier applies to the **entire car total**.

### Dice Pool Dynamics

The "select 2 from N" mechanic means more dice = more control, not higher numbers:

- **fit 1, no verified (2 dice):** No choice, stuck with whatever rolls. ~64% chance of ×1.5, ~28% chance of ×1.0, ~8% chance of ×0.8.
- **fit 2 (4 dice, select 2):** C(4,2) = 6 combinations. High chance of dodging ×0.8 and landing ×1.5.
- **fit 3 (6 dice, select 2):** C(6,2) = 15 combinations. Near-guaranteed ×1.5 unless extreme rolls.
- **Verified bonus dice** improve control further, with diminishing returns at high fit (the biggest improvement is fit 1: 2→3 dice).

---

## Pricing

### Car Total

Each item's contribution to the car total:

```
item_contribution = market_price(item)
                  = appraised_value × condition_multiplier × market_factor
```

If the item is **verified (authenticated)**, its contribution receives an additional **×1.2** bonus:

```
item_contribution = market_price(item) × 1.2    (verified only)
```

### Final Sale Price

```
car_total  = sum of all item contributions
sell_price = car_total × sell_multiplier
```

Where `sell_multiplier` is ×1.2 (conservative) or the dice result (aggressive).

### Verified Item Benefits Summary

Authenticated items receive three distinct benefits in the merchant system:

1. **Hidden clue tags count toward fit** — may increase the item's fit count if hidden clues match customer demands.
2. **×1.2 price bonus** on the item's individual contribution to car total.
3. **+1 die** added to the aggressive dice pool (stacks per verified item).

Even if hidden clues are negative (lowering verified_value below appraised_value), benefits 2 and 3 still apply. The ×1.2 bonus is applied to the item's market_price (which already incorporates the lower verified_value), so it partially compensates. Example: an item appraised at $5000 authenticates to $1500 (negative hidden clue). Its car contribution is $1500 × condition × market × 1.2 — lower than the unverified $5000 base, but the ×1.2 and +1 die soften the blow. Authentication is a gamble on price, not a pure loss on selling mechanics.

---

## Customer Generation

### Current Model (Minimal Viable)

- **Demand tags:** 2–4 tags per customer, drawn uniform random from the tag vocabulary. No weighting, no player-progression influence.
- **Car grid size:** Random pick from a hardcoded list of dimensions (e.g. `[3×4, 4×4, 4×6, 5×6]`). Exact list tuned during implementation.
- **Customer count:** 3–5 per night, uniform random.

### Future Considerations (Deferred)

- Weighted tag pools based on in-game calendar or events.
- "Regular customers" with fixed demand profiles that visit periodically.
- Customer quality tiers (budget buyer vs. collector) with different multiplier tables.
- Progression-influenced generation (higher mastery attracts better customers).

---

## Interaction with Phase 7 Systems

### Clue System

- Surface clues auto-reveal on hub return → player knows all surface tags before selling.
- Hidden clues are unknown until authenticated → authentication can reveal additional demand-matching tags.
- Clue id = tag → fit calculation is a simple set intersection.

### Attributes and Perks

- Attributes affect Run-phase inspection (clue discovery). Better attributes → more clues revealed pre-auction → better purchasing decisions for customer matching.
- Perks may modify selling mechanics (e.g. reroll one die, see customer demands before the run). Specific selling-related perks deferred to implementation.

### Mastery

- Mastery does not directly affect selling mechanics.
- Future hook (draft): high category mastery might attract customers with demands in that category, or provide a small bonus to fit calculation for that category's items.

---

## UI Outline (Conceptual)

1. **Customer overview** — All customers shown simultaneously. Each card displays: demand tags (as chips), car grid (empty), and a tag-match indicator.
2. **Item assignment** — Player selects a customer, sees the filtered item list (fit ≥ 1 only), drags items into the car grid. Grid enforces spatial constraints (items have shapes from category data).
3. **Sell decision** — After loading, two buttons: Conservative (shows ×1.2 and exact price) and Aggressive (shows dice pool size and probability breakdown).
4. **Dice roll** — Aggressive: all dice roll visually. Player taps/clicks 2 dice to select. Sum and multiplier shown. Confirm/decline buttons.
5. **Result** — Items removed from storage, cash added, customer leaves.

---

## Scope

Includes: customer data model, demand tag generation, car grid UI and packing logic, fit calculation, conservative/aggressive sell flow, dice roll UI and selection, verified item bonuses, deprecation of old merchant/order systems, removal of pawn_shop/antique_dealer/special_order code and data.

Excludes: customer personality/dialog, customer progression weighting, regular customer system, selling-related perks, merchant content migration for non-deprecated merchants (arms_dealer, fashion_buyer — evaluated separately).

## Dependencies

- **Phase 7** — clue data model, tag=clue, attribute system, verified flag.
- **Phase 10** — value policy cleanup (centralised value resolution used by car total calculation).

## Acceptance Criteria

- 3–5 customers appear each night with demand tags and car grids.
- Item list per customer filters to fit ≥ 1 only. Fit = set intersection of demand tags and revealed clue ids.
- Player can spatially pack items into customer car grids.
- Conservative sell: flat ×1.2 on car total. No dice.
- Aggressive sell: dice pool from best-fit item (fit 1→2, fit 2→4, fit 3→6). Verified items add +1 die each. Player selects 2 dice, sum determines multiplier (2–5: ×1.0, 6–10: ×1.5, 11–12: ×0.8).
- Verified items contribute ×1.2 bonus to individual car total share.
- Player sees result and confirms/declines before sale is final.
- pawn_shop, antique_dealer, special order, Quick Sell, merchant negotiation — all removed.
- No item can be sold outside the customer system.
