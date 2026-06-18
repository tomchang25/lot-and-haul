# Hub & Home

Meta block group in `game/meta/` — hub navigation, the slot tray that allocates a day, storage, and entry points to the sell / vehicle / knowledge sub-systems. The day's slot/AP structure is owned by `../day_slot_economy.md`; selling is the unified nightly customer system (`../customer_sell.md`).

## Goal

Be the calm between runs: the place where the player converts won cargo into cash, spends cash on progression, and allocates the day's Day/Night activity slots. Success is a hub that frames every major meta system (knowledge, storage, selling, vehicles) without itself becoming a minigame.

## Hub Navigation Flow

The slot tray presents two slots, Day and Night. The Activity button opens a cancellable chooser for the activities valid in the current slot:

- **Auction** (Day only) — consumes the Day slot, transitions to location select, and returns to hub for Night after run settlement.
- **Storage** — begins a fresh storage AP slot, with the larger Day budget or base Night budget.
- **Open Shop** — generates Day/Night-scaled customers and advances one slot.
- **Vehicle** — routes to Vehicle Hub (Garage car select + Car Shop).
- **Knowledge** — routes to Knowledge Hub (Mastery / Attributes / Perks).

When a Night activity advances past Night, the hub asks `MetaManager` to close the day and routes the returned `DaySummary` to `DaySummaryScene`. Returning to hub re-runs `_ready()` and refreshes the display.

All slot transitions go through `MetaManager` (one method per activity); the hub never writes `current_day`, living cost, or customer state itself. Full slot/AP rules are in `../day_slot_economy.md`.

## Open Questions

### Prestige shape is undecided

Before building the museum/donation path: what does prestige unlock or affect (access tiers, price modifiers, cosmetics, pure achievement)? Is it per-super-category or global? These two answers determine the save state shape and whether the donation UI belongs in storage or is its own scene.
