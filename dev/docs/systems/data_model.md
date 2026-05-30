# Data Model

The two layers that hold all game data: **designer resources** (static, authored, loaded from `.tres`) and **runtime types** (per-run/per-night state, save-serialized). This doc is concept-only — flow, lifecycle, and relationships. Field lists, signatures, and tuning constants live in the code docstrings of each file (paths below). If a field matters, it's documented where it's declared.

> Single source of truth: this doc had previously mirrored every exported field. That duplication went stale (e.g. it claimed Phase 11 customer-sales fields were still "coming" after they shipped). The fields now live only in code.

---

## Designer resources (`data/definitions/*.gd` → `data/tres/`)

Authored in YAML, converted to `.tres` by the pipeline (see `autoloads.md`), loaded by the matching registry at boot. The chain of ownership:

`SuperCategoryData` ← `CategoryData` ← `ItemData` → `Array[ClueData]`

- **SuperCategoryData / CategoryData** — physical classification. A category carries
  weight and cargo `shape_id`; a super-category groups categories. `CategoryRegistry`
  and `SuperCategoryRegistry` own lookup and the super→member reverse index, so no code
  ever scans `ItemRegistry` to answer a category question.
- **ItemData** — one authorable item. Identity and value are expressed entirely as an
  ordered `Array[ClueData]` (one anchor, then surface, then hidden). `item_name` and
  `base_price` are deprecated holdovers; true value resolves through the clue stack. See
  `../item_system.md`.
- **ClueData** — the atomic unit of identity and value. Type (anchor/surface/hidden),
  a discovery attribute + DC, a price effect (`flat`/`add`/`mul`), and optional naming
  slot. Pricing applies clues as `(anchor_flat + Σ add) × Π mul`; hidden clues join once
  the item is verified.
- **AttributeData** — the five SPECIAL-style attributes that bonus clue-discovery rolls.
- **PerkData** — unlocks sourced from attribute thresholds (reach value N on an attribute).
- **LotData** — static lot config: draw tables (rarity / super-category / category /
  explicit item weights), NPC bidding ranges, price-estimation bounds, inspection AP
  quota. All randomness is *ranges* here; rolled values live on `LotEntry`. The
  clue-based NPC estimate is driven by `npc_clue_sight_chance`.
- **CarData** — cargo grid, weight cap, stamina (inspection AP) pool, fuel cost, trailer
  slots and their damage risk, shop price. See `../meta/vehicle.md`.
- **LocationData** — entry fee, travel days, and the lot pool sampled per visit. See
  `../lot_auction_run.md`.

### Deprecated designer resources

`MerchantData`, `SpecialOrderData`, and `SpecialOrderSlotPoolEntry` belonged to the old merchant / negotiation / special-order channels, superseded by the unified nightly customer system (`../customer_sell.md`). They still load for save round-tripping but are scheduled for deletion; do not author new content against them. Their archived design docs are archived under `../../archived/` (the merchant, merchant_shop, and special_orders files).

---

## Runtime types (`common/gameplay/*.gd`, sell math in `common/utils/`)

All `RefCounted` value objects — save-serialized where persisted, free of autoload state where possible.

- **RunRecord** — state for one warehouse run. Created in `location_select`, lives on
  `RunManager.run_record` (null between runs), cleared in `run_review`. Accumulates won
  items across lots, tracks cargo/trailer selection, travel costs, stamina, and the
  sampled browse-lot list for the visit.
- **LotEntry** — runtime context for one lot, created from `LotData`. All random values
  (aggressive factor, price variance, item draws, NPC estimate) are rolled **once** at
  creation and cached — never re-rolled. Item draw: roll item count, then per item either
  draw by explicit `item_weights` or roll rarity → (super-category → member category, or
  category weights) → a random matching item, retrying a bounded number of times. Each
  item independently starts pre-unveiled by `veiled_chance`. The NPC estimate sums each
  item's clue-based estimate, where the NPC notices each surface clue with probability
  `npc_clue_sight_chance`.
- **ItemEntry** — runtime state for one owned item: veil state (the sole authority is
  `anchor_revealed`), revealed clue ids, verified status, condition, and the inspection
  bias offset. All prices/names/inspection level are computed from the clue stack — see
  `../item_system.md` for the full pricing/naming/condition model. Serialization self-heals:
  on load it migrates legacy keys and drops clue ids no longer present in the item's
  current clue set, so pipeline regenerations don't corrupt saves.
- **ResearchSlot** — now a stateless holder for the static storage condition math
  (`apply_repair`, `apply_restore`, caps, zone/rarity factors, the Restoration coefficient)
  invoked by `MetaManager`'s immediate storage AP actions. Its old day-ticker lifecycle
  was retired with the slot economy; the math was kept. Hidden-clue reveal is no longer
  here — it is deterministic per-clue progress on `ItemEntry` (see `day_slot_economy.md`).
- **Customer** — one nightly buyer: a car grid plus demand tags (clue ids it
  wants). Generation is RNG-injectable and biases each tag roughly half the time toward
  tags actually present in current storage (so nights are matchable) and otherwise toward
  the full vocabulary. The per-night count is driven by the selling-slot commitment.
- **DaySummary** — value object returned by `MetaManager`'s day-end sequence and read by
  `DaySummaryScene`. Captures run costs (folded from pending-run economics), living cost,
  and the night's customer sales (snapshotted before nightly generation clears them);
  `net_change` is computed from these.

### Sell math (`common/utils/sell_math.gd`)

Pure, stateless, RNG-injectable. Computes item-fit against a customer's tags, the conservative multiplier vs. the aggressive dice-pool result, verified-item bonuses, and the final car total. See `../customer_sell.md` for how the sell loop uses it.

### Deprecated runtime types

`SpecialOrder` and `OrderSlot` are the runtime side of the old special-order channel — still compile and round-trip through save but superseded by the customer system and scheduled for removal. `PriceConfig` and `ItemViewContext` were already removed.
