# Hub & Home

Meta block group in `game/meta/` — hub navigation, the slot tray that allocates a day, storage, and entry points to the sell / vehicle / knowledge sub-systems. The day's slot/AP structure is owned by `../day_slot_economy.md` (the calendar day, storage AP, auction AP, customer scaling, living cost); the selling surface is the unified nightly customer system (`../customer_sell.md`); the legacy merchant channel is removed from the hub and its old design docs are archived (`../../archived/merchant.md`, `merchant_shop.md`, `special_orders.md`). This doc covers the hub surface around them.

## Goal

Be the calm between runs: the place where the player converts won cargo into cash, spends cash on progression, and allocates the day's three slots. Success is a hub that frames every major meta system (knowledge, storage, selling, vehicles) without itself becoming a minigame.

## Reads

- `SaveManager.cash` — displayed in hub header (Balance)
- `SaveManager.storage_items` — hub header (item count) and storage scene source of truth
- `KnowledgeManager.get_mastery_rank()` — hub header (Mastery Rank)
- `SaveManager.current_slot` — which of the day's three slots the tray presents next; `> 3` triggers day-end
- `GameManager.consume_pending_day_summary()` — `DaySummaryScene` input

## Writes

- Slot transitions go through `MetaManager` (one entry point per activity); the hub never writes `current_day`, living cost, or customers itself — see `../day_slot_economy.md`.
- `SaveManager.storage_items` — mutated by Storage AP actions (Repair / Restore / Research)

Routing: Auction (slot 1 only) → `GameManager.go_to_location_select()`. Storage → `GameManager.go_to_storage()`. Open Shop → customer-sell scene. Knowledge → `GameManager.go_to_knowledge_hub()`. Vehicle → `GameManager.go_to_vehicle_hub()`. When the day ends (Open Shop chosen, or all slots spent) the hub takes the `DaySummary` from `MetaManager` to `GameManager.go_to_day_summary(summary)`.

## Feature Intro

### Data Definitions

No resources owned by this block directly — Hub is a navigation surface over other systems' data. Its runtime hook is the slot tray: it allocates each of the day's three slots to an activity through `MetaManager` and, when the day ends, routes the returned summary to the Day Summary scene. The slot/AP rules behind the tray live in `../day_slot_economy.md`.

### Hub Scene

`game/meta/hub/hub_scene.gd` + `.tscn` — central navigation after each run and across the day's slots.

Header displays Mastery Rank, Balance, and Storage item count (refreshed by `_refresh_display()` on `_ready()`).

The **slot tray** presents the three slots (Morning / Afternoon / Evening) with filled/empty indicators and offers an activity chooser for the next open slot:

- **Auction** (slot 1 only; greyed otherwise) → consumes slots 1+2 → `GameManager.go_to_location_select()`
- **Storage** → begins a fresh storage AP slot → `GameManager.go_to_storage()`
- **Open Shop** → generates slot-scaled nightly customers and ends the day → customer-sell scene
- **Next Run / Sell** route as Auction / Open Shop above (the unified nightly customer system replaces the old Merchant button — see `../customer_sell.md`)
- **Vehicle** → `GameManager.go_to_vehicle_hub()` (see `vehicle.md`)
- **Knowledge** → `GameManager.go_to_knowledge_hub()` (Mastery / Attributes / Perks — see `knowledge.md`)

When the day ends — Open Shop chosen, or all three slots spent (`current_slot > 3`) — the hub asks `MetaManager` to close the day and routes the `DaySummary` to `DaySummaryScene`. Returning via `GameManager.go_to_hub()` re-runs `_ready()` → `_refresh_display()`.

### Vehicle Hub Entry

`game/meta/vehicle/vehicle_hub.gd` + `.tscn` — navigation menu to Garage (car select) and Car Shop. Back returns to Hub. Full spec in `vehicle.md`.

### Knowledge Hub Entry

`game/meta/knowledge/knowledge_hub.gd` + `.tscn` — navigation menu to three standalone sub-scenes: Mastery, Attributes, Perks. Back returns to Hub. Full spec in `knowledge.md`.

### Day Summary Scene

`game/meta/day_summary/day_summary_scene.gd` + `.tscn` — standalone scene displaying day-end results. Reached when the hub closes the day. Reads a pending `DaySummary` from `GameManager.consume_pending_day_summary()`; if none is pending, returns to hub with a warning.

`DaySummary` (the value object, in `common/gameplay/day_summary.gd` — see `../shared/data_model.md`) carries the day range, run-specific costs (folded from the pending-run economics stashed after an auction), living cost, and the night's customer sales, with a computed net change. `has_run_data()` gates the income group in the scene. It does not currently carry slot-count or storage-action fields.

### Storage

`game/meta/storage/storage_scene.gd` + `.tscn` — player works stored items by spending the slot's storage AP. Storage is both the viewer and the verb surface — there is no separate Research scene, and there is no slot to assign: each button applies its effect immediately and charges AP. The three actions are **Repair** (condition → 0.5 cap), **Restore** (0.5 → 1.0), and **Research** (deterministic per-clue hidden reveal). AP pool size, costs, the deterministic-research rule, and condition guards are owned by `../day_slot_economy.md`; this scene is the surface that renders the AP bar and drives those `MetaManager` actions.

- Item list uses `ItemListPanel`; clicking a row opens the action surface for the selected item.
- Each action button executes immediately on press (no day-tick) and disables when its guard fails — insufficient AP, condition already past a cap, or no unrevealed hidden clue remaining.
- After any action the scene re-renders the AP bar, the detail panel, and each button's enabled state.

### Sell Surface

Selling is owned by the unified nightly customer system, documented in `../customer_sell.md`. Hub only owns the **Sell** button that routes into the customer-sell scene; customers are generated on day advance by `MetaManager`. The legacy merchant stack is removed from the hub; its design docs are archived under `../../archived/`.

### Garage Sell _(deferred — system unclear)_

Another auction-type scene modelled on the existing `game/run/auction/` structure. No hard blockers — deferred to avoid scope creep on the selling flow. Lives in hub for now because it's unclear whether this is a merchant surface or a separate selling channel.

### Own Shop _(deferred — system unclear)_

Player lists items at a set price, resolved during the day-end sequence. Lives in hub for now because the player-listing surface may not belong to any single merchant. (Largely subsumed by the customer-sell system; retained as an open design idea only.)

### Bank / Bankruptcy _(deferred)_

Daily interest applied during the day-end sequence before living cost. Defines bankruptcy state and game-over condition. Optional loan UI in hub.

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
