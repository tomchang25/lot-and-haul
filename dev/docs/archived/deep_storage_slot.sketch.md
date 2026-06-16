# Deep Storage Slot

## Goal

Add a one-click deep storage option that gives the player a larger storage AP budget while preserving the evening shop. This reduces repetitive Storage → Hub → Storage navigation without changing the selling loop into an all-day lockout.

## Requirements

1. The player must be able to choose a storage-focused day shape that enters Storage once and grants a larger AP pool, because repeated storage sessions are operational friction rather than an interesting decision.
2. Deep Storage must preserve the evening shop, because selling remains the daily closeout pressure and should not be accidentally skipped by a storage-heavy day.
3. Deep Storage should grant `x2.5` the normal storage AP budget as the first tuning target, because it is stronger than two normal slots but still compact enough to test as a distinct commitment.
4. The storage scene should behave like normal storage after entry; the difference is the starting AP budget, not a separate research/repair ruleset.

## Design

Deep Storage is a slot-economy UX and tuning change, not a new storage system. The player commits to storage work once, receives an enlarged AP budget, spends it inside the familiar storage scene, then returns to the hub with the evening shop still available.

The intended day shape is `Deep Storage + Shop`. It should replace the feeling of selecting Storage twice in one day, while keeping the final selling action available as the daily endpoint.

## Sketch (non-normative)

Implementation can start by adding a separate hub action such as `Deep Storage` or `Storage Day`. That action seeds storage AP to `round(Economy.STORAGE_AP_MAX * 2.5)` and advances the slot state to Evening rather than consuming the whole day.

The normal storage scene should not need a special mode at first. It can read the seeded AP value and display/spend it through the existing repair, restore, and research buttons.

If the hub needs clearer copy, label normal storage as a short workshop session and Deep Storage as an extended workshop session that still leaves time to open shop tonight.

## Non-Goals

1. Rebalancing all storage AP costs in the first pass.
2. Adding new research, repair, or restore actions.
3. Reworking the full timeslot system beyond this one storage-focused day shape.

## Acceptance Criteria

1. The player can enter one storage session with an enlarged AP budget equivalent to the deep storage multiplier.
2. Returning from that storage session still leaves the player able to open shop that night.
3. Storage actions consume the enlarged AP pool through the normal storage UI and rules.
4. The flow removes the need to enter Storage twice for a storage-heavy day.
