# Hub & Home

Meta block group in `game/meta/` — hub navigation, day-pass system, storage, and entry points to the sell / vehicle / knowledge sub-systems. The selling surface is the unified nightly customer system (`../customer_sell.md`); the legacy merchant channel is removed from the hub and its old design docs are archived (`../../archived/merchant.md`, `merchant_shop.md`, `special_orders.md`). This doc covers the hub surface around them.

## Goal

Be the calm between runs: the place where the player converts won cargo into cash, spends cash on progression, and ticks the day forward. Success is a hub that frames every major meta system (knowledge, storage, selling, vehicles) without itself becoming a minigame.

## Reads

- `SaveManager.cash` — displayed in hub header (Balance)
- `SaveManager.storage_items` — hub header (item count) and storage scene source of truth
- `KnowledgeManager.get_mastery_rank()` — hub header (Mastery Rank)
- `GameManager.consume_pending_day_summary()` — `DaySummaryScene` input
- `SaveManager.research_slots` — Storage research-slot state (per-action availability gating)

## Writes

- `SaveManager.current_day` / `cash` / `research_slots` — via `MetaManager.advance_days()` on Day Pass
- `SaveManager.storage_items` — mutated by Storage actions (assign/remove research slot)

On Day Pass: `GameManager.go_to_day_summary(summary)`. On Knowledge: `GameManager.go_to_knowledge_hub()`. On Next Run: `GameManager.go_to_location_select()`. On Sell: routes into the customer-sell scene (see `../customer_sell.md`). On Storage: `GameManager.go_to_storage()`.

## Feature Intro

### Data Definitions

No resources owned by this block directly — Hub is a navigation surface over other
systems' data. The only runtime hook is the Day Pass: it advances one day through
`MetaManager` and routes the returned summary to the Day Summary scene.

### Hub Scene

`game/meta/hub/hub_scene.gd` + `.tscn` — central navigation after each run and between day passes.

Header displays Mastery Rank, Balance, and Storage item count (refreshed by `_refresh_display()` on `_ready()`).

Buttons:

- **Next Run** → `GameManager.go_to_location_select()`
- **Storage** → `GameManager.go_to_storage()`
- **Sell** → customer-sell scene (the unified nightly customer system; replaces the old Merchant button — see `../customer_sell.md`)
- **Vehicle** → `GameManager.go_to_vehicle_hub()` (see `vehicle.md`)
- **Knowledge** → `GameManager.go_to_knowledge_hub()` (Mastery / Attributes / Perks — see `knowledge.md`)
- **Day Pass** → `ConfirmationDialog` (`DayPassConfirm`) → on confirm, `_do_day_pass()` → `DaySummaryScene`

Returning from `DaySummaryScene` via `GameManager.go_to_hub()` re-runs hub `_ready()`, which calls `_refresh_display()` to update the header.

### Vehicle Hub Entry

`game/meta/vehicle/vehicle_hub.gd` + `.tscn` — navigation menu to Garage (car select) and Car Shop. Back returns to Hub. Full spec in `vehicle.md`.

### Knowledge Hub Entry

`game/meta/knowledge/knowledge_hub.gd` + `.tscn` — navigation menu to three standalone sub-scenes: Mastery, Attributes, Perks. Back returns to Hub. Full spec in `knowledge.md`.

### Day Summary Scene

`game/meta/day_summary/day_summary_scene.gd` + `.tscn` — standalone scene displaying day-advancement results. Used by both the hub Day Pass and the run-review continue flow. Reads a pending `DaySummary` from `GameManager.consume_pending_day_summary()`; if none is pending, returns to hub with a warning.

`DaySummary` (the value object, in `common/gameplay/day_summary.gd` — see `../shared/data_model.md`) carries the day range, run-specific costs, living cost, completed research actions, and the night's customer sales, with a computed net change. `has_run_data()` gates the income group in the scene.

### Storage

`game/meta/storage/storage_scene.gd` + `.tscn` — player manages stored items and assigns them to research slots. Storage is both the viewer and the verb surface — there is no separate Research scene. The slot actions are the `ResearchSlot.SlotAction` set: **Repair** (condition → 0.5), **Restore** (0.5 → 1.0), and **Research** (reveals all hidden clues after `Economy.RESEARCH_DAYS[rarity]` day-ticks, marking the item verified). The old Study / Unlock actions are gone.

- Item list uses `ItemListPanel` with storage columns including `RESEARCH_STATUS`, which reflects the current slot action or completion state; empty when the item is not assigned.
- Clicking a row opens an `ActionPopup` with the available slot actions plus Remove / Cancel. If `max_research_slots` is exhausted the popup shows `"No research slots available"` and hides the action buttons.
- Actions disable with a tooltip when not applicable (e.g. Repair when condition is already ≥ 0.5, Restore when already at full condition, Research when the item is already verified).
- Choosing a new action writes a fresh `ResearchSlot` to `SaveManager.research_slots`; switching action on an in-slot item replaces the slot and resets `completed` but leaves the item's `condition` and reveal state untouched.
- Hub Storage button text is appended with `"(N done)"` when completed research slots exist (counted via `_completed_research_count()` in `hub_scene.gd`).

### Sell Surface

Selling is owned by the unified nightly customer system, documented in `../customer_sell.md`. Hub only owns the **Sell** button that routes into the customer-sell scene; customers are generated on day advance by `MetaManager`. The legacy merchant stack is removed from the hub; its design docs are archived under `../../archived/`.

### Garage Sell _(deferred — system unclear)_

Another auction-type scene modelled on the existing `game/run/auction/` structure. No hard blockers — deferred to avoid scope creep on the selling flow. Lives in hub for now because it's unclear whether this is a merchant surface or a separate selling channel.

### Own Shop _(deferred — system unclear)_

Player lists items at a set price. Sale resolution ticks inside `MetaManager.advance_days()` alongside action ticking. Lives in hub for now because the player-listing surface may not belong to any single merchant. (Largely subsumed by the customer-sell system; retained as an open design idea only.)

### Bank / Bankruptcy _(deferred)_

Daily interest applied inside `MetaManager.advance_days()` after sale-side mutation and before living cost. Defines bankruptcy state and game-over condition. Optional loan UI in hub.

### Museum / Prestige _(deferred)_

Donation UI in storage scene, new `SaveManager` field for prestige state. See Notes for the design question that blocks this.

### Auction Modifier: All-Base-Layer Run _(deferred)_

Forces every item to display `layer_index = 0` regardless of player knowledge for an entire run. Requires a general auction modifier system design first.

## Notes

### Prestige shape is undecided

Before building the museum donation path, decide: what does prestige unlock or affect (access tiers, price modifiers, cosmetics, pure achievement)? Is it per-super-category or global? These two answers determine both the `SaveManager` shape and whether the donation UI belongs in storage or is its own scene.

### Car system lives in `vehicle.md`

Hub is where vehicle selection and the car shop _surface_ (via the Vehicle button → Vehicle Hub), but the system doc is `vehicle.md`. This doc only references it.

### Selling lives in `../customer_sell.md`

Hub only routes into the customer-sell scene via the **Sell** button. The unified nightly customer system owns all selling logic. The legacy merchant design docs are archived under `../../archived/`.


