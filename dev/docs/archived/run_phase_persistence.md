# Run-Phase Persistence (Mid-Run Save & Resume)

## Goal

Quitting the game mid-run currently discards the active run silently: the visited location, sampled lots, generated items, inspection progress, cargo choices, and run scene are all session-only. The hub-side auction slot has already advanced and saved before the run starts, so a mid-run quit can consume the day activity while dropping the run contents. Add run-phase persistence so the game can be closed at any point during a run and resumed at the scene the player was in, with the whole run behaving as one atomic economic transaction.

## Current Codebase Context

`RunStore` and `LotStore` are currently owned only by `RunManager` for the lifetime of an in-memory run. Their docstrings explicitly say they carry no save payload, and `RunManager` is not registered as a `SaveManager` provider. Saves therefore contain only the existing meta/knowledge sections; a save with an active run has no run section to restore.

Cash settlement is already mostly deferred: entry fee, fuel cost, winning bids, and on-site proceeds accumulate on the run record, then `MetaManager.resolve_run()` applies the final cash delta, registers cargo, stashes pending run economics for the day summary, sets the hub slot to Night, saves once, and clears run state. The missing piece is persistence for that deferred ledger and for the run content that ledger describes.

The current persisted side effect before a run exists is `MetaManager.begin_auction()`: selecting a location advances the day slot and saves, then `RunManager.create_run_store()` builds the in-memory run. Until run persistence exists, quitting after this point loses the run while preserving the spent activity slot. The new run payload must make that saved slot transition and the active run restore together as one coherent state.

## Requirements

1. The full run snapshot persists across app restarts: visited location, run economics (committed spend, on-site proceeds), saved hub slot context, stamina, AP reserve, won/cargo/trailer item sets, browse progress (sampled lot list and index), the active lot (rolled factors, generated items with their reveal and condition state, remaining AP), and the resume scene.
2. Resume returns the player to the scene recorded at the last phase transition, never auto-advanced into the next phase — if inspection was completed and the player quit on the way into the auction, resume lands back in the completed inspection scene, because being dropped directly into a scene the player never saw is disorienting.
3. The auction is atomic: no in-auction state (bid history, NPC bidding state, current price) is ever persisted. Quitting during a live auction resumes at that lot's pre-auction state with inspection results intact. This avoids serializing a live encounter state machine and removes reload-to-reroll abuse of auction outcomes.
4. Run economics stay transactional: money committed during a run (entry fee, fuel, winning bids) remains booked on the run ledger instead of being deducted from the persistent wallet until `MetaManager.resolve_run()` settles on hub return. The player must not be able to tell the difference: every cash display and every affordability check during the run uses effective cash = wallet - run committed spend. The current auction budget label already displays this model; bidding still needs to enforce it.
5. Saves fire at phase transitions (run start, entering a lot, auction settled, cargo committed) plus one final write on graceful app quit via the existing close-time flush. Scene transitions already call `SaveManager.flush()`, but run mutations do not currently mark dirty or serialize because `RunManager` is not a provider. Do not save on every inspection mutation, because each save writes a new rotation file and a high save rate would push hub saves out of the retention window. Only a hard crash rolls progress back to the last transition.
6. Serialization follows the established store-owned versioning pattern: the run section owns `_version` and migrations for run payload shape; entry-level runtime types serialize and parse only their current shape. This must be consistent with the existing storage, shop session, and customer payloads. Per-store migrations run inside `from_dict()`; the top-level `schema_version` is a legacy stamp and must not drive run loading.
7. If the run payload cannot be restored on load (corrupt payload, or referenced location, lot, item, clue, car, category, or affix definitions no longer exist after a data update), the run is discarded with a visible warning toast and the player boots to the hub in a coherent no-active-run state. Because the wallet was never debited, a discarded run costs the player no cash; the won goods, committed spend, and saved run scene vanish together as one unit.
8. A save with no active run behaves exactly as today: run section absent, boot lands at the hub. Pre-feature saves carry no run section and load with no migration and no warnings.

## Design

### Resume scene model

The run phase is a linear scene flow: location entry → lot browse → (inspection → auction → reveal)\* → cargo → run review → hub settlement. The persisted resume target is always a phase-stable scene:

| Player quit during              | Resume target                                                                                     |
| ------------------------------- | ------------------------------------------------------------------------------------------------- |
| location entry / lot browse     | same scene, browse index restored                                                                 |
| inspection (mid-lot)            | inspection, with revealed clues and remaining AP as of the last save                              |
| transition inspection → auction | inspection (completed state) — never auto-advance, see Requirements                               |
| auction (live)                  | inspection (completed state) — auction is atomic                                                  |
| reveal (auction settled)        | reveal — the win is already committed; replaying the auction would change nothing                 |
| cargo                           | cargo, with won items restored; grid placement is re-done by the player (placement is view state) |
| run review                      | run review                                                                                        |

The recorded resume scene is part of the run payload and is written at each phase-transition save.

### Escrow economics

Worked example: wallet $5,000. Run start books entry fee $200 + fuel $100, so committed spend is $300; wallet on disk still $5,000; UI shows $4,700. Player wins a lot for $1,200, so committed spend is $1,500; UI shows $3,500. Sells an abandoned item on-site for $150, so run proceeds are $150; UI shows $3,650. Settlement at hub return: wallet = 5,000 - 1,500 + 150 = $3,650, exactly what the UI showed all along. If the run payload is lost or unrestorable at any point before settlement, the wallet on disk is still $5,000: the entire run rolls back as one unit.

Bid affordability during the auction must check effective cash, so committed spend can never drive the wallet below zero at settlement. This is not true yet: the auction scene currently refreshes a budget label from wallet minus committed run costs, but the bid button path does not enforce that budget.

The current `begin_auction()` slot advancement happens before `RunManager.create_run_store()`. The run-persistence implementation should either create/save the run before the slot transition is committed or save both in one transaction immediately after run creation. The player should never be left in a state where the auction slot is consumed but no active run can resume.

### Identity across item collections

A single item instance can appear in several run collections at once (the active lot's item list overlaps the won set after a win; cargo and trailer sets are subsets of the won set). Restoration must preserve this: each item is materialized once and the same instance is shared by every collection that references it — otherwise a clue revealed on one copy would not appear on the other. The payload therefore stores each item once and lets collections reference it by a per-run stable key, never as duplicated item dicts.

### Lot reference resolution

A lot is persisted as its stable identifier plus its rolled runtime values; the static definition is re-resolved from designer data on load. The sampled browse list is likewise persisted as identifiers. If any identifier in the run payload no longer resolves, the whole run is treated as unrestorable — partial reconstruction is never attempted, because a half-resolved run risks inconsistent totals between the item sets and the committed-spend ledger, and the wallet rollback makes whole-run discard lossless anyway.

### Save-provider shape

Run persistence needs a new run save provider surface. The smallest viable shape is for `RunManager` to register with `SaveManager` and own a single optional run section. When no run is active, the run section is absent so pre-feature and between-run saves behave like today. When a run is active, the section contains the run store, optional active lot store, and resume target. `RunStore` and `LotStore` can then gain store-owned serialization without becoming hub/meta state.

The run section should not duplicate item dicts across active-lot, won, cargo, and trailer collections. Store each generated `ItemEntry` once under a per-run key, then store collection membership by key. This preserves object identity after load and keeps reveal/condition changes shared across every collection reference.

Resume routing belongs with the existing boot-routing logic. Today, loading a save can route to customer sell when `ShopSessionStore.pending_scene` requests it; otherwise the start page routes to hub. A restored active run needs an equivalent route from the loaded run section to the recorded run scene, with invalid or unrestorable runs falling back to hub after warning.

## Non-Goals

1. No mid-auction state restoration — atomic by design.
2. No anti-save-scum measures beyond auction atomicity; reloading an older rotation file can still replay a run.
3. No obfuscation of the save payload — veiled items and hidden clues remain readable in the JSON, as they already are for storage items.
4. No change to the hub-side save cadence, file rotation, or retention policy.
5. Cargo grid placement is not persisted — only membership of the cargo and trailer sets after cargo is committed. In-progress drag, rotation, and grid coordinates remain view state.

## Acceptance Criteria

1. Quit gracefully at any run scene, relaunch: the game resumes at the recorded scene per the resume table, with items, revealed clues, AP, stamina, browse progress, and committed run economics intact.
2. Quit during a live auction, relaunch: the player is back at that lot's completed-inspection state; no bid state survives; bidding restarts fresh.
3. Displayed cash during a run is indistinguishable from the current deferred-settlement behavior at every step, and hub settlement produces the same final wallet as today's successful completed-run flow.
4. Bidding cannot exceed effective cash. A bid that would make committed spend greater than wallet is blocked before it mutates auction state.
5. Force-kill mid-inspection, relaunch: the game resumes at the last phase-transition save with committed spend restored; the on-disk wallet was never debited at any point.
6. Quit after selecting a location but before settlement, relaunch: the auction/day slot is not consumed without a restorable run. Either the run resumes or the player returns to the exact coherent pre-run hub state chosen by the implementation.
7. Loading a save whose run payload references removed content: visible warning toast, hub boot, wallet unchanged, no crash, hub state untouched.
8. Loading a pre-feature save (no run section) behaves identically to today, with no migration warnings.
