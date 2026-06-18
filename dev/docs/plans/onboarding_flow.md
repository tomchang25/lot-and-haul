# Onboarding Flow

## Goal

Ship a first-game onboarding that walks a new player through one full day cycle — intro and the Day/Night chooser, an Auction run, Storage, then a second day's Selling — using the real slot economy (Plan A) and the event-driven tutorial machinery (Plan B). This replaces the current "land on the hub with no guidance" new-game experience and realizes the "tutorial covers whole gameplay" goal.

## Requirements

1. A new game enters onboarding mode via a first-time flag on the progress save section (today no such flag exists and new games drop straight onto the hub). Onboarding gates the player to the intended path without a parallel fake economy, because maintaining a second onboarding economy would diverge from the real one and rot.
2. Onboarding rides the real slot economy from Plan A: Day 1 Day slot = Auction → Day 1 Night slot = Storage → day end → Day 2 Day slot = Selling. The player performs the real activities; the tutorial points and waits, it does not simulate.
3. The onboarding is segmented by scene, aligned to the flow layer from Plan B: hub intro + chooser teaching, auction-choose, the auction run (location select → lot browse → inspection → auction → reveal → cargo → run review), storage-choose, storage, a day-summary pass, shop-choose, selling. Each segment owns its own anchors; no single giant script spans all scenes.
4. Interactive segments advance on gameplay events (Plan B's event set): the auction-run segment waits on lot selected, inspection performed, auction won, cargo loaded, and run reviewed, rather than on Next. The player must actually do the action to proceed, because watching is not learning.
5. Chooser teaching points at the single hub activity button, then at the chooser option for the intended activity (Auction, then Storage, then Selling in turn). The chooser option is targeted via Plan B's transient-anchor lifecycle, since the option only exists while the chooser popup is open.
6. Storage onboarding reuses the existing storage tutorial, lightly adjusted to note the AP pool is the current slot's budget, since the workshop mechanics are unchanged by Plan A.
7. Onboarding completion clears the first-time flag and frees the player into the normal hub; a player who has completed (or explicitly skipped) onboarding never re-enters it on later days.
8. Onboarding must not break if the player quits mid-onboarding: resuming lands the player at their real slot and scene state (per existing run-persistence and save behavior) and the onboarding flow reattaches at the segment for that scene, because onboarding rides the real economy rather than holding separate onboarding state.

## Design

### First-time flag

Added to the progress save section's payload. Migration defaults existing saves to "onboarding already done" (a returning player never sees onboarding) and defaults brand-new saves to "onboarding pending." The flag is a single boolean; it carries no step index, because step position is derived from the player's real slot/scene on resume.

### Segments and end conditions

| Segment        | Scene             | Ends when                                  |
| -------------- | ----------------- | ------------------------------------------ |
| hub_intro      | hub (Day 1 Day)   | player opens the chooser                   |
| auction_choose | hub chooser       | player chooses Auction (`activity_chosen`) |
| auction_run    | run scenes        | `run_reviewed`                             |
| storage_choose | hub (Day 1 Night) | player chooses Storage                     |
| storage        | storage scene     | storage tutorial completes (Next)          |
| day_pass       | day summary       | player advances to the Day 2 hub           |
| shop_choose    | hub (Day 2 Day)   | player chooses Selling                     |
| selling        | selling scene     | `sale_completed`                           |

### Day flow

Day 1 Day slot is consumed by Auction → Night. Night Storage consumes Night → day ends → day summary → Day 2. Day 2 Selling consumes the Day 2 Day slot → Night → onboarding ends at `sale_completed` and the player is free; the leftover Day 2 Night slot is theirs to use normally.

### Deep Storage

Deep Storage is not a separate onboarding path. Under Plan A, Day Storage simply is the enlarged-AP Storage; the storage segment mentions the larger AP budget in passing and otherwise reuses the existing storage tutorial.

### Auction outcome adaptation

The auction-run segment is not scripted to a win. The player bids for real: a win flows through cargo and run review; a loss flows to run review with empty cargo. The segment's event waits (`auction_won`, `cargo_loaded`, `run_reviewed`) advance through whichever path occurs, so onboarding never softlocks on an outcome it did not script.

### Economy realism

Onboarding uses the same begin-activity paths as normal play. The only special-casing is the first-time flag gating which segments are active, plus the flow layer pointing the player at the correct chooser option. No onboarding-specific economy mutations exist.

## Non-Goals

1. No onboarding for Knowledge, Vehicle, or Deep-Storage-as-a-distinct-path — those are discovered in free play after onboarding.
2. No scripted NPC dialogue or story; onboarding is instructional hints and popups only.
3. No replay-onboarding-from-menu in this plan — a Help replay of individual tutorials already exists and remains separate.
4. No forced auction win/loss; the onboarding adapts to the real outcome.

## Acceptance Criteria

1. A brand-new game enters onboarding and is guided Hub → Auction run → Storage → day end → Selling, performing each activity for real on the real economy.
2. Each interactive segment advances only when the player performs the real gameplay action (selects a lot, inspects, wins or loses the auction, loads cargo, completes a sale).
3. The onboarding points at the chooser option for the intended activity via the transient chooser anchor, and the chooser can be interacted with normally.
4. A returning player (existing save, or onboarding already done) lands on the hub with no onboarding and full freedom.
5. Quitting mid-onboarding and resuming reattaches the onboarding at the segment matching the player's real slot/scene, with no duplicate or skipped segments.
6. Onboarding completion or skip sets the first-time flag and the player continues in the normal economy with whatever slot state they reached.
