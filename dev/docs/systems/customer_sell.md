# Customer Sell System

The unified nightly selling loop. Each Hub night, customers arrive with demand tags and a car grid; the player packs matching storage items into a customer's grid and sells via a Conservative or Aggressive strategy. This is the **only** selling path — Quick Sell, merchant negotiation, and special orders are removed.

Related docs: `item_system.md` (clues = tags), `shared/data_model.md` (`Customer`, `ItemEntry`), `shared/autoloads.md` (`MetaManager`, `SaveManager`).

---

## Ownership

- **`Customer`** (`common/gameplay/customer.gd`) — runtime value object: demand tags + grid dims. Owns its own RNG-injectable generation (`generate`, `generate_batch`, `generate_for_night`). RefCounted, save-serialized via `to_dict()` / `from_dict()`. No `.tres`, no registry.
- **`SellMath`** (`common/utils/sell_math.gd`) — pure, stateless, RNG-injectable sell math: fit, dice-pool sizing, sum→multiplier banding, car-total pricing. Unit-testable without autoload state.
- **`MetaManager`** — the **transactional authority**. Generates customers on day advance, commits confirmed sales (mutates `cash` / `storage_items`), records the sale ledger. Delegates all generation and math to the modules above — it does not inline fit/dice/pricing.
- **Customer-sell scene** (`game/meta/customer_sell/`) — reads customers from `SaveManager`, consumes the shared `PackingGrid` (`game/shared/packing/`) and `SellMath`, and calls back into `MetaManager.resolve_customer_sale()`. The scene never mutates cash or storage directly.

---

## Tags = Clues

A clue's id **is** its demand tag. `ItemEntry.fit_tags()` returns the item's revealed surface clue ids (always) plus revealed hidden clue ids (only when verified); the anchor is excluded — it is the base-value identity, not a tag. Customer `demand_tags` are clue ids drawn from the same vocabulary (all surface + hidden clue ids, anchors excluded), served from `ClueRegistry`.

---

## Nightly Generation

Opening shop (`MetaManager.begin_open_shop`) generates the night's customers via `_generate_nightly_customers()`, which delegates to `Customer.generate_for_night(rng, storage_items, count, all_clue_ids)`:

- **Count** — derived from the selling-slot commitment: 1 slot → 2–3, 2 → 4–6, 3 → 7–10 (see `day_slot_economy.md`). The generator still supports `count < 0` rolling a `DEFAULT_NIGHT_MIN..MAX` (3–5) default, but the live path always passes an explicit slot-derived count.
- **Owned pool** — union of `fit_tags()` across current storage.
- **Per-tag 50/50 bias** — each of a customer's 2–4 demand tags is drawn from the owned pool (guaranteed-matchable) with 50% probability, else from the full vocabulary. Deduped per customer. Empty storage → all tags fall back to the full vocabulary.
- **Grid dims** — uniform pick from `Customer.GRID_PRESETS` (`2×2 … 5×4`).

The set is stored on `SaveManager.nightly_customers` and persisted, so re-entering the scene the same day shows the same customers. `SaveManager.customer_sales_today` is reset at generation (it feeds the Phase 11 Day Summary rework).

---

## Fit

`SellMath.item_fit(customer, entry)` = count of the item's `fit_tags()` that appear in `customer.demand_tags`. `matched_items(customer, storage)` filters storage to fit ≥ 1 — items with fit 0 are hidden from that customer's list. `best_item_fit_depth(customer, items)` returns the highest single-item fit in the loaded car, clamped 1–3, used to size the aggressive dice pool.

---

## Pricing & Sell Strategies

Per-item contribution: `item_price × (1.2 if verified else 1.0)` (`SellMath._item_base_contribution`). `car_total(items, multiplier) = Σ contributions × multiplier`, floored at 1.

| Strategy     | Multiplier source                                             |
| ------------ | ------------------------------------------------------------- |
| Conservative | flat `CONSERVATIVE_MULTIPLIER` = **×1.25**, no dice           |
| Aggressive   | dice pool → `dice_multiplier(sum)` over committed `SUM_BANDS` |

**Aggressive pool:** base by best fit depth (`DICE_POOL_BY_DEPTH`: 1→2d, 2→4d, 3→6d) **+1 die per verified item** in the car (`VERIFIED_BONUS_DICE`). The player rolls all d6 (`roll_dice`) and **selects 2**; their sum maps via `SUM_BANDS`:

| Dice sum | Multiplier |
| -------- | ---------- |
| 2–4      | ×0.7       |
| 5–9      | ×1.1       |
| 10–12    | ×1.5       |

This is a **monotonic high=good** mapping (the old non-monotonic band where high sums were penalised was dropped): larger pools are strictly more controllable, so Conservative wins at low fit and Aggressive at fit 2+.

The player sees the resulting price before confirming. Declined items return to storage; the customer stays available until the day advances.

---

## Sale Commit

`MetaManager.resolve_customer_sale(items, sale_price, customer, strategy)`:

1. Erase each sold item from `storage_items` and credit `SELL` category mastery.
2. `cash += sale_price`.
3. Append a record to `customer_sales_today` (`day`, `customer_id/name`, `strategy`, `item_count`, `item_ids`, `sale_price`).
4. Remove the served customer from `nightly_customers` and `save()`.

---

## Edge Cases

| Case                                 | Handling                                                                              |
| ------------------------------------ | ------------------------------------------------------------------------------------- |
| Empty storage at night               | Customers still generate (all-random tags); sell lists may be empty; player can leave |
| Item fits multiple customers         | Selectable for any, but once placed in one car it is unavailable to others that night |
| Declined sale                        | Items return to storage; customer stays until day advance                             |
| Verified item, negative hidden clues | Contribution uses the lower verified value, still ×1.2 and still +1 die               |
| Car grid larger than fittable items  | Partial fill allowed; sells whatever is placed                                        |
