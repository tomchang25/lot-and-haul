# Run-Phase Persistence (Mid-Run Save & Resume)

## Goal

Quitting the game mid-run currently discards the entire run silently — the visited location, sampled lots, generated items, inspection progress, and the scene the player was in are never saved, while cash spent during the run has already been deducted and persisted. Add run-phase persistence so the game can be closed at any point during a run and resumed at the scene the player was in, with the whole run behaving as one atomic economic transaction.

## Requirements

1. The full run snapshot persists across app restarts: visited location, run economics (escrowed spend, on-site proceeds), stamina, AP reserve, won/cargo/trailer item sets, browse progress (sampled lot list and index), the active lot (rolled factors, generated items with their reveal and condition state, remaining AP), and the resume scene.
2. Resume returns the player to the scene recorded at the last phase transition, never auto-advanced into the next phase — if inspection was completed and the player quit on the way into the auction, resume lands back in the completed inspection scene, because being dropped directly into a scene the player never saw is disorienting.
3. The auction is atomic: no in-auction state (bid history, NPC bidding state, current price) is ever persisted. Quitting during a live auction resumes at that lot's pre-auction state with inspection results intact. This avoids serializing a live encounter state machine and removes reload-to-reroll abuse of auction outcomes.
4. Run economics become transactional: money spent during a run (entry fee, fuel, winning bids) is booked against the run as escrow instead of being deducted from the persistent wallet immediately. The wallet is debited (and proceeds credited) only at run settlement on hub return. The player must not be able to tell the difference: every cash display and every affordability check during the run uses effective cash = wallet − run escrow.
5. Saves fire at phase transitions (run start, entering a lot, auction settled, cargo committed) plus one final write on graceful app quit via the existing close-time flush — not on every mutation, because each save writes a new rotation file and a high save rate would push hub saves out of the retention window. Only a hard crash rolls progress back to the last transition.
6. Serialization follows the established store-owned versioning pattern: entry-level runtime types serialize and parse only the current shape; schema version and migrations are owned by the run section's store version ladder, consistent with how the storage and customer payloads already work.
7. If the run payload cannot be restored on load (corrupt payload, or referenced lot/item/clue definitions no longer exist after a data update), the run is discarded with a visible warning toast and the player boots to the hub. Because of the escrow model, the wallet was never debited, so a discarded run costs the player nothing — the won goods and their escrowed cost vanish together as one unit.
8. A save with no active run behaves exactly as today: run section absent, boot lands at the hub. Pre-feature saves carry no run section and load with no migration and no warnings.

## Design

### Resume scene model

The run phase is a linear scene flow: location entry → lot browse → (inspection → auction → reveal)* → cargo → run review → hub settlement. The persisted resume target is always a phase-stable scene:

| Player quit during              | Resume target                                                                                      |
| ------------------------------- | -------------------------------------------------------------------------------------------------- |
| location entry / lot browse     | same scene, browse index restored                                                                   |
| inspection (mid-lot)            | inspection, with revealed clues and remaining AP as of the last save                                |
| transition inspection → auction | inspection (completed state) — never auto-advance, see Requirements                                 |
| auction (live)                  | inspection (completed state) — auction is atomic                                                    |
| reveal (auction settled)        | reveal — the win is already committed; replaying the auction would change nothing                   |
| cargo                           | cargo, with won items restored; grid placement is re-done by the player (placement is view state)   |
| run review                      | run review                                                                                          |

The recorded resume scene is part of the run payload and is written at each phase-transition save.

### Escrow economics

Worked example: wallet $5,000. Run start books entry fee $200 + fuel $100 → escrow $300; wallet on disk still $5,000; UI shows $4,700. Player wins a lot for $1,200 → escrow $1,500; UI shows $3,500. Sells an abandoned item on-site for $150 → run proceeds $150; UI shows $3,650. Settlement at hub return: wallet = 5,000 − 1,500 + 150 = $3,650 — exactly what the UI showed all along. If the save is lost or unrestorable at any point before settlement, the wallet on disk is still $5,000: the entire run rolls back as one unit.

Bid affordability during the auction checks effective cash, so escrow can never drive the wallet below zero at settlement.

### Identity across item collections

A single item instance can appear in several run collections at once (the active lot's item list overlaps the won set after a win; cargo and trailer sets are subsets of the won set). Restoration must preserve this: each item is materialized once and the same instance is shared by every collection that references it — otherwise a clue revealed on one copy would not appear on the other. The payload therefore stores each item once and lets collections reference it by a per-run stable key, never as duplicated item dicts.

### Lot reference resolution

A lot is persisted as its stable identifier plus its rolled runtime values; the static definition is re-resolved from designer data on load. The sampled browse list is likewise persisted as identifiers. If any identifier in the run payload no longer resolves, the whole run is treated as unrestorable — partial reconstruction is never attempted, because a half-resolved run risks inconsistent totals between the item sets and the escrow ledger, and the escrow rollback makes whole-run discard lossless anyway.

## Non-Goals

1. No mid-auction state restoration — atomic by design.
2. No anti-save-scum measures beyond auction atomicity; reloading an older rotation file can still replay a run.
3. No obfuscation of the save payload — veiled items and hidden clues remain readable in the JSON, as they already are for storage items.
4. No change to the hub-side save cadence, file rotation, or retention policy.
5. Cargo grid placement is not persisted — only membership of the cargo and trailer sets.

## Acceptance Criteria

1. Quit gracefully at any run scene, relaunch: the game resumes at the recorded scene per the resume table, with items, revealed clues, AP, stamina, browse progress, and escrow intact.
2. Quit during a live auction, relaunch: the player is back at that lot's completed-inspection state; no bid state survives; bidding restarts fresh.
3. Displayed cash during a run is indistinguishable from pre-change behavior at every step, and hub settlement produces the same final wallet as today's immediate-deduction flow.
4. Force-kill mid-inspection, relaunch: the game resumes at the last phase-transition save with escrow restored; the on-disk wallet was never debited at any point.
5. Loading a save whose run payload references removed content: visible warning toast, hub boot, wallet unchanged, no crash, hub state untouched.
6. Loading a pre-feature save (no run section) behaves identically to today, with no migration warnings.
