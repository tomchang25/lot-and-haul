# Phase 9 — Merchant System Redesign (Pre-Plan)

## Goal

Replace all existing selling channels with a single nightly customer system, so selling becomes one coherent loop — tag matching, spatial packing, and risk/reward dice — instead of several overlapping channels. This closes the fragmented-selling gap and makes inspection and authentication investment pay off directly at sell time.

## Requirements

1. Nightly customers — generate 3–5 customers per Hub night, each with a set of demand tags and a car grid sized from a fixed dimension list. Reuse the existing item-footprint and grid-packing concepts.
2. Match-biased generation — for each demand tag, roughly half the time draw from clues present on current storage items (guaranteeing fit) and half the time draw uniformly from the tag vocabulary, so sellable inventory is reliably available without removing randomness.
3. Fit filtering — show a customer only items whose revealed clue ids intersect its demand tags (fit ≥ 1). Clue id is the tag; verified items add hidden-clue tags to fit.
4. Two sell strategies — Conservative (flat multiplier, no dice) and Aggressive (dice pool sized from the best single-item fit in the car, plus one die per verified item, player selects two dice, sum maps to a multiplier). Rebalance the dice bands and conservative multiplier so neither strategy strictly dominates across fit levels.
5. Pricing — each item's car contribution is its value (appraised, or verified when authenticated) times its condition multiplier, with an additional bonus for verified items; final sale price is the car total times the chosen strategy multiplier. No market factor or knowledge bonus.
6. Confirm or decline — the player sees the sale result before finalizing; declined items return to storage.
7. Deprecation — remove the pawn shop, antique dealer, special orders, Quick Sell, and merchant negotiation, along with their data and dialogs.

## Non-Goals

1. No customer personality, dialog, or progression-weighted generation.
2. No regular/recurring customers or customer quality tiers.
3. No selling-related perks.
4. No migration of non-deprecated merchants — evaluated separately.
5. No Day Summary rework — that is Phase 11.

## Acceptance Criteria

1. Each night, 3–5 customers appear with demand tags and car grids, and roughly half of each customer's tags are guaranteed to match current storage.
2. Per-customer item lists filter to fit ≥ 1, computed as the intersection of demand tags and revealed clue ids.
3. The player can spatially pack matching items into a customer's car using the existing shape and grid behavior.
4. Both Conservative and Aggressive sells function, and neither is the obviously correct choice in all situations.
5. Verified items contribute their value bonus, add a die to the aggressive pool, and have their hidden tags counted toward fit.
6. The player can confirm or decline each sale; declined items remain in storage.
7. No selling path exists outside the customer system; all deprecated channels and their data are removed.
