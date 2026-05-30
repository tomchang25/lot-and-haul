# Phase 9 — Merchant System Redesign (Implementation Spec)

## Goal

Replace all existing selling channels with one nightly customer system: each night 3–5 runtime customers arrive with demand tags and a car grid; the player packs matching storage items into a customer's grid and sells via a Conservative or Aggressive strategy. This unifies tag matching, spatial packing, and risk/reward dice into a single coherent selling loop.

## Relational Context

- `MetaManager` is the **transactional authority**, not the computation owner. It mutates `cash`/`storage_items` and commits a confirmed sale, but delegates customer generation and all sell math to the `common/gameplay` customer module. Keep it a thin orchestrator — do not inline fit/dice/pricing logic into it.
- Customers and their car grids are **runtime value objects, not designer resources**, and live in `common/gameplay` mirroring `SpecialOrder`/`OrderSlot` (which they replace): RefCounted, save-serialized via `to_dict()`/`from_dict()`, no `.tres`, no registry — `MerchantRegistry` is being removed.
- Customer generation and sell math (fit intersection, dice-pool sizing, sum→multiplier banding, car-total pricing) are **pure and RNG-injectable**, owned by the customer module — following the `LotEntry`-generates-`ItemEntry` precedent — so they are unit-testable without autoload state.
- The sell scene reads customers from `MetaManager`/`SaveManager` and calls back to resolve a sale; the scene never mutates cash or storage directly.
- Item value resolves solely through `ItemEntry.item_price` (`(appraised|verified) × condition_multiplier`, from Phase 10). The verified ×1.2 and the sell multiplier are applied on top by the sell system. Do **not** reintroduce `market_factor`/`MarketManager` — the redesign doc's old `market_price()` formula is stale and must not be carried over.
- Grid placement is extracted from `cargo_scene.gd` into a shared component. The shared module owns placement/rotation/occupancy only; **weight, trailer slots, and run-summary stay in `cargo_scene.gd`** and are not part of the shared module.
- Removing `MerchantRegistry` changes the autoload boot order — drop it from `registry_coordinator` registration and the documented load order.
- `SaveManager` must migrate (silently drop) `merchant_negotiations_used_today`, `merchant_orders`, and `next_order_id` from existing saves. `cash` and `storage_items` are unchanged.
- Customer set is regenerated on day advance and persisted, so re-entering the sell scene the same day shows the same customers.

## Scope

### Included

- Runtime customer type, 50/50 match-biased tag generation, hardcoded grid-size list.
- Shared packing module extracted from cargo; new hub-side customer-sell scene that consumes it.
- Fit calculation, Conservative + Aggressive sell flow, dice roll/selection UI, verified bonuses.
- Full removal of the old selling stack and its save/data/routing references.

### Excluded

- Customer personality/dialog, progression-weighted or regular customers, quality tiers.
- Selling-related perks; `arms_dealer`/`fashion_buyer` (no `.tres` exist — out of scope).
- Day Summary rework (Phase 11).

## Files to Change

| File | Change Size | Purpose |
| --- | --- | --- |
| shared packing module (new) | Medium | Grid placement/rotation/occupancy core, used by cargo and customer sell |
| `common/gameplay/customer.gd` (new) | Medium | Customer runtime value object (demand tags + grid dims) + RNG-injectable generation; `to_dict()`/`from_dict()`; replaces `SpecialOrder`/`OrderSlot` |
| pure sell-math helper (new, `common/gameplay` or `common/utils`) | Small | Fit intersection, dice-pool sizing, sum→multiplier banding, car-total pricing — pure, unit-testable |
| customer-sell scene `.gd` + `.tscn` (new) | Large | Customer overview, packing, sell decision, dice UI, result |
| `game/run/cargo/cargo_scene.gd` | Medium | Consume shared packing module; keep weight/trailer/summary |
| `global/autoload/meta_manager.gd` | Medium | Thin orchestrator: generate customers on day advance, commit confirmed sales (cash/storage); delegate generation + sell math to the customer module; remove `fulfill_order`, retune `sell_items` (drop merchant arg), drop `MerchantRegistry.advance_day` |
| `global/autoload/save_manager.gd` | Medium | Remove merchant/order serialization; migrate old saves |
| `global/autoload/game_manager/game_manager.gd` | Small | Route to customer-sell scene; remove merchant_hub/shop/fulfillment + `_pending_merchant` |
| `global/autoload/game_manager/scene_registry.gd` | Small | Swap merchant scene refs for customer-sell scene |
| `game/meta/hub/hub_scene.gd` | Small | Point Merchant button at customer-sell scene |
| `global/autoload/registry_coordinator.gd` | Small | Drop `MerchantRegistry` from boot |
| `global/constants/data_paths.gd` | Small | Remove `MERCHANTS_DIR`, `SPECIAL_ORDERS_DIR` |
| old selling stack (delete) | Large | Remove `merchant_registry.gd`, `merchant_data.gd`, `special_order*.gd`, `order_slot.gd`, merchant_hub/merchant_shop/fulfillment_panel/negotiation_dialog scenes, and `pawn_shop`/`antique_dealer`/special-order `.tres` |
| `CLAUDE.md` autoload list | Small | Update load order |

## Implementation Notes

All generation and sell math below lives in the `common/gameplay` customer module as pure, RNG-injectable functions; `MetaManager` only calls them and commits results.

**Customer generation (per night).** Build the owned-tag pool = union of revealed clue ids across current storage (surface always; hidden only if verified). For each of 2–4 demand-tag slots, roll 50/50: heads → draw uniformly from the owned pool (guaranteed-matchable); tails → draw uniformly from the full tag vocabulary. Dedupe within a customer. If storage is empty, all tags fall back to the full vocabulary. Customer count 3–5 uniform; grid dims from a hardcoded list (e.g. `[3×4, 4×4, 4×6, 5×6]`, tunable).

**Fit.** `fit = |demand_tags ∩ revealed_clue_ids|`. Items with fit 0 are hidden from that customer's list. Aggressive dice pool uses the single best-fit item in the loaded car (kept as designed).

**Pricing.** `item_contribution = ItemEntry.item_price × (1.2 if verified else 1.0)`; `car_total = Σ contributions`; `sell_price = car_total × sell_multiplier`.

**Sell strategies (starting constants, playtest-tunable).**
- Conservative: flat **×1.25**, no dice.
- Aggressive: pool = best-fit base (`1→2, 2→4, ≥3→6`) **+1 die per verified item in the car**; roll all d6, player **selects any 2**; sum → multiplier: **2–4 → ×0.7, 5–9 → ×1.1, 10–12 → ×1.5**.
- Design change to flag: the old non-monotonic band (high sum penalised) is replaced with a monotonic high=good mapping so larger pools are strictly more controllable and Conservative is no longer dominated (Conservative wins at low fit, Aggressive at fit 2+). Confirm this flavor change is acceptable.

## Edge Cases

| Case | Expected Handling |
| --- | --- |
| Empty storage at night | Customers still generate (all-random tags); sell lists may be empty; player can leave |
| Item fits multiple customers | Selectable for any, but once placed in one car it is unavailable to others that night |
| Declined sale | Items return to storage; customer stays available until day advances |
| Verified item, negative hidden clues | Contribution uses lower verified_value, still ×1.2 and still +1 die |
| Old save with merchant/order keys | Keys dropped silently on load; cash and storage preserved |
| Car grid larger than fittable items | Partial fill allowed; sells whatever is placed |

## Acceptance Criteria

1. Each night 3–5 customers appear with demand tags and a car grid; roughly half of each customer's tags are guaranteed to match current storage.
2. Per-customer item lists show only fit ≥ 1 items, fit = intersection of demand tags and revealed clue ids.
3. The player can spatially pack items into a customer's car using shared grid behavior (with rotation).
4. Conservative (flat ×1.25) and Aggressive (dice) both function, and neither is the correct choice at every fit level.
5. Aggressive pool = best-fit base + 1 per verified item; player selects 2 dice; sum maps to the committed bands.
6. Verified items contribute their ×1.2 value bonus, add a die, and count hidden tags toward fit.
7. The player sees the result and confirms or declines before the sale is final.
8. No selling path exists outside the customer system; pawn shop, antique dealer, special orders, Quick Sell, and merchant negotiation — code, data, save state, and routing — are removed.
