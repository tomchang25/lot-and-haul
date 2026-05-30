# Lot Auction Run

Everything from choosing a location to settling a run. Covers location selection, lot browsing, AP-grid inspection, list review, auction, reveal/loss state, cargo packing, and run review.

## Goal

Deliver one complete location visit as a tight loop: pick a location, sample lots, inspect under an AP budget, decide whether to bid, reveal the result, pack the haul, and settle costs. The through-line is a single run record that carries location costs, sampled lots, active lot state, auction wins, cargo choices, and final settlement.

## Scene Flow

```
hub
  └── location_select
       └── location_entry
            └── lot_browse
                 ├── [enter active lot]
                 │    └── inspection grid
                 │         └── list review overlay
                 │              ├── [back while AP remains] -> inspection grid
                 │              ├── [pass lot] -> lot_browse
                 │              └── auction
                 │                   └── reveal / auction lost
                 │                        └── lot_browse
                 └── [all lots done / skip remaining]
                      └── cargo
                           └── run_review
                                └── day_summary
                                     └── hub
```

A finished run returns the player to the Hub for the Evening slot, stashing its economics as pending; the Day Summary scene (`GameManager.go_to_day_summary`) fires when the day ends from the hub (Open Shop or all slots spent). See `day_slot_economy.md`.

## Key Flows

### Location Selection

The location screen shows the saved daily location sample. If no sample exists, the meta layer rolls one from the location registry. The sample persists on the save until day advancement clears it.

Cards show display name, description, entry fee, travel days, lot count, and estimated run cost. Estimated run cost is entry fee plus active-car fuel cost for the location's travel days. Picking a card creates the active run record with the selected location and current active car, then plays the placeholder arrival transition.

### Lot Browse

On first entry, the run samples lots from the selected location by shuffling the location's lot pool and taking the configured lot count. That sampled list and browse index persist across scene transitions, so returning from reveal resumes at the next lot.

All sampled lot cards are visible, but only the current card exposes Enter and Pass. Enter creates a runtime lot, advances the browse index immediately, and enters inspection. Pass advances the index without creating a lot. Once all lots are consumed, or the player confirms skipping the remaining lots, the flow goes to cargo.

### Inspection And List Review

Current inspection is an AP grid, not the older stamina action model. The active lot's item shapes are placed on an 8x8 hidden grid using category shapes. The AP budget is a two-tier pool — a per-lot cap plus a visit-wide reserve that refills the cap (deficit only) at each lot boundary — owned by the run record; the old per-lot `action_quota` no longer drives it. See `day_slot_economy.md` for the full pool model. Car stamina still exists on the run record, but the current inspection UI does not spend it.

Identity is clue-based, not layer-based. Clicking a veiled object spends the unveil AP cost and calls `ItemEntry.unveil()`, which reveals the item's **anchor** clue (its base-value identity) and grants reveal knowledge. There is no layer ladder.

Clicking an already-unveiled item that still has discoverable clues (`has_inspection_clues()`) spends the clue-chain AP cost and runs a chain of discovery rolls over its unrevealed surface (and high-DC hidden) clues. Each roll calls `attempt_clue(clue, attribute_bonus)`, where `success_chance = clamp((21 + attribute_bonus − dc) × 5, 5, 95)` and `attribute_bonus` comes from the player's attribute value for that clue's `attribute`. The chain reveals clues until the first failed roll. Revealed surface clues raise `inspection_level` (the revealed-surface ratio), which tightens the estimated price range.

The list review overlay can be opened manually or appears automatically when AP reaches zero. It shows found items, condition/estimate columns, the lot total estimate, and the auction opening bid. Back to inspection is enabled only while AP remains. Passing returns to lot browse; entering auction routes to the auction scene.

Price estimates are hidden for veiled items. Revealed, unverified items show an estimated range derived from the revealed clue stack (`anchor_flat + Σ surface_add` then `× Π surface_mul`, widened by a spread that shrinks to zero at full inspection) and keep a "+" uncertainty suffix at the lot level while any item is still veiled. Verification (hidden clues) and true value remain hub/storage concepts, not run-phase information.

### Auction

The runtime lot caches an NPC estimate when it is created (`LotEntry.roll_npc_estimate()`). The estimate is clue-based: it sums each item's `ItemEntry.roll_npc_estimate(lot_data.npc_clue_sight_chance)`, where the NPC notices each surface clue with that per-clue probability and computes `(anchor_flat + Σ noticed_add) × Π noticed_mul`. Opening bid and the hidden rolled price both derive from that cached estimate, with lot aggression (`aggressive_lerp`), price variance, floor, and ceiling tuning applied before the auction scene opens.

The auction is a simulation, not a negotiation. NPC ticks raise the displayed price toward the rolled threshold while a closing circle controls resolution timing. The player can bid or pass. If the circle resolves after the threshold is reached and the player was the last bidder, the current lot's items are added to accumulated run wins and the current price is added to the accumulated paid total. If an NPC was last bidder, or the player passes, accumulated wins and paid total are left untouched.

The rolled price is hidden from normal play UI. The current debug overlay exposes it only in debug builds.

### Reveal

Reveal uses only the latest lot result. If the last auction was lost or passed, the screen shows an Auction Lost state and continues back to lot browse.

For won lots, the screen lists the latest won items. Pressing Reveal unveils any still-veiled items (reveals their anchor clue). It does not auto-reveal surface clues, run discovery rolls, or resolve true item identity — surface clues auto-reveal only on hub return, and hidden clues only via Storage Authenticate. Continue returns to lot browse for the next sampled lot.

### Cargo

Cargo starts with all accumulated won items in temporary storage. The player moves items into the active car's cargo grid, rotating shapes with Q/E. Cargo placement enforces shape bounds, collisions, and the active car's weight limit.

Cars may also expose extra single-item slots. These are tracked as trailer items, separate from the cargo grid, and currently bypass cargo grid space and weight checks. Items left in temporary storage are sold on-site at a flat price per item when the player confirms settlement.

### Run Review

Run review applies trailer damage before showing the item list. Trailer damage uses the active car's chance and damage ratio, reducing condition on affected trailer items.

The finance panel shows cash cost, sold-on-site proceeds, immediate cash flow, estimated cargo value, and estimated profit. Cash cost is auction paid total plus entry fee plus fuel cost. Immediate cash flow is on-site proceeds minus that cost.

Continuing resolves the run through `MetaManager.resolve_run()`: cash is mutated by on-site proceeds minus paid price, entry fee, and fuel cost; normal cargo items have all surface clues auto-revealed (`ItemEntry.auto_reveal_all_surface()` — no layer ladder) and enter storage; the run's economics are stashed as pending (folded into the day summary at day-end) and the player returns to the Hub for the Evening slot (the auction consumed the morning + afternoon). Items flagged `auto_verify` also reveal their hidden clues on storage entry. There is no market advancement (`MarketManager` was removed). Living cost and the day summary are applied later by the day-end sequence, not here — see `day_slot_economy.md`. Run state is cleared after settlement.

Current caveat: run review displays cargo plus trailer items and applies trailer damage, but settlement registration currently only stores normal cargo items (see Open Questions).

## Design Notes

- **Paid total and won items accumulate across lots.** Lost or passed auctions deliberately do not mutate those totals, so earlier wins survive later losses.
- **The lot browse index advances before inspection.** Returning from reveal should always show the next sampled lot, not the same lot again.
- **AP is a two-tier pool, capped per lot.** Within a lot AP is pure consume and never exceeds the cap; the visit-wide reserve refills the cap (deficit only) at lot boundaries. Vehicle stamina is present in run state but is not consumed by current inspection actions. Reconnect or remove it before tuning cars around inspection endurance. Full model in `day_slot_economy.md`.
- **Aggressive lerp is the primary location risk dial.** Entry fee and travel days are secondary. Price variance is useful for texture, but too much variance creates noise more than readable risk.
- **Extra slots bypass weight today.** Treat them as a deliberate trailer escape valve only after settlement behavior is fixed.
- **On-site proceeds currently mean left-behind won items.** Commodity fields exist in authored location YAML, but there is no active commodity runtime path in the lot/auction/cargo code reviewed here.

## Open Questions

- **Trailer-item settlement.** Run review displays and damages trailer (extra-slot) items, but settlement only registers normal cargo. Should trailer items enter storage, be discarded, or be treated as a separate risk channel? Extra slots bypass weight until this is decided.
- **AP vs. vehicle stamina.** Vehicle stamina exists in run state but no inspection action consumes it. Reconnect it as an inspection-endurance dial, or remove it before cars promise stamina-based tuning?
- **Commodity runtime path.** Authored location YAML carries commodity fields, but no runtime path consumes them; on-site proceeds today just mean left-behind won items. Wire commodities into the run loop, or drop the fields?
