# Customer Sell System

The unified nightly selling loop. Each Hub night, customers arrive with demand tags and a car grid; the player packs matching storage items into a customer's grid and sells via a Conservative or Aggressive strategy. This is the **only** selling path — Quick Sell, merchant negotiation, and special orders are removed.

Related docs: `item_system.md` (clues = tags), `shared/autoloads.md` (`MetaManager`).

---

## Tags = Clues

A clue's id **is** its demand tag. An item's fit tags are its revealed surface clue ids (always) plus revealed hidden clue ids (only when verified); the anchor is excluded — it is the base-value identity, not a tag. Customer demand tags are clue ids drawn from the same vocabulary (all surface + hidden clue ids, anchors excluded).

---

## Nightly Generation

Opening shop triggers `MetaManager` to generate the slot's customers. Customer count is derived from the current Day/Night slot (see `day_slot_economy.md`). Each customer's 2–4 demand tags use a **50/50 bias**: drawn from the owned-storage tag pool (guaranteed-matchable) half the time, from the full clue vocabulary otherwise. Empty storage falls back to all-random tags. Grid dimensions are drawn from a preset list. The generated set is persisted, so re-entering the scene the same day shows the same customers.

---

## Sell Strategies

Two strategies, both operating on `item_price × (1.2 if verified else 1.0)` per item, summed over the car:

| Strategy     | Multiplier source                                           |
| ------------ | ----------------------------------------------------------- |
| Conservative | flat ×1.25, no dice                                         |
| Aggressive   | dice pool → multiplier banding (monotonic: high sum = good) |

**Aggressive dice pool:** base size by best-item fit depth (fit 1 → 2d, 2 → 4d, 3 → 6d) plus +1 die per verified item in the car. Player rolls all d6 and selects 2; the sum maps to a multiplier (2–4 → ×0.7, 5–9 → ×1.1, 10–12 → ×1.5). Larger pools are strictly more controllable, so Conservative wins at low fit and Aggressive at fit 2+.

The player sees the resulting price before confirming. `SellMath` owns all formulas and constants; `MetaManager.resolve_customer_sale` owns the transaction (removes sold items from storage, credits cash, records the sale, saves).

---

## Edge Cases

| Case                                 | Handling                                                                              |
| ------------------------------------ | ------------------------------------------------------------------------------------- |
| Empty storage at night               | Customers still generate (all-random tags); sell lists may be empty; player can leave |
| Item fits multiple customers         | Selectable for any, but once placed in one car it is unavailable to others that night |
| Declined sale                        | Items return to storage; customer stays until day advance                             |
| Verified item, negative hidden clues | Contribution uses the lower verified value, still ×1.2 and still +1 die               |
| Car grid larger than fittable items  | Partial fill allowed; sells whatever is placed                                        |
