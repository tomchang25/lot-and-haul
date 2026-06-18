# TimeSlot Day/Night Rework

## Goal

Collapse the three-slot day (Morning/Afternoon/Evening) into a two-slot Day/Night model where each slot opens a chooser of activities and every activity consumes exactly one slot, with Storage and Selling carrying a larger budget in Day. This removes the special-case "Open Shop force-ends the day" rule, gives the hub a single clean activity entry point, and produces the simpler two-state surface that onboarding (Plan C) needs to teach.

## Requirements

1. Two slots per day: Day then Night. Day-ending is signaled by advancing past Night, reusing the hub's existing "past the last slot → end the day on re-entry" trigger so the day-orchestration shape is unchanged.
2. Each slot exposes one activity entry point that opens a chooser popup listing the activities valid for that slot. The chooser can be cancelled without consuming the slot, because a mis-click must never burn a day's activity.
3. Day chooser offers Auction, Storage, Selling. Night chooser offers Storage, Selling — Auction is Day-only because a run consumes the working portion of the day and returns the player to the Night slot.
4. Every activity advances the slot by exactly one step (Day→Night, Night→day-ending). No activity special-cases end-of-day; all three activities share one advancement rule, which is what removes the current "Selling ends the day" exception.
5. Storage AP budget scales by slot: Day grants the enlarged pool (the existing deep-storage multiplier applied to the base AP max), Night grants the base AP max. The Storage scene and actions are identical in both; only the AP pool differs, because Day represents the working portion with more time to work.
6. Selling customer volume scales by slot (Day larger, Night smaller), replacing the current "selling slots committed" scaling that assumed a three-slot day. Starting balance: Day ≈ 7–10 customers, Night ≈ 2–3, tunable.
7. Existing saves migrate to the two-slot model: an in-progress save maps to its closest two-slot equivalent (Morning→Day; Afternoon or Evening→Night; past-Evening→day-ending). Migration code is additive and permanent, never deleted.
8. The day-summary and run-settlement flows behave unchanged from the player's view; only the slot counting that feeds them changes.

## Design

### Slot model

| Slot         | Value | Meaning                                                                  |
| ------------ | ----- | ------------------------------------------------------------------------ |
| Day          | 1     | Working portion: full Storage AP, full Selling volume, Auction available |
| Night        | 2     | Wind-down portion: base Storage AP, small Selling volume, no Auction     |
| (past Night) | >= 3  | Day ending — hub auto-ends the day on entry, as today                    |

### Activity advancement

| Current slot | Activity | Resulting slot |
| ------------ | -------- | -------------- |
| Day          | Auction  | Night          |
| Day          | Storage  | Night          |
| Day          | Selling  | Night          |
| Night        | Storage  | day-ending     |
| Night        | Selling  | day-ending     |

A day therefore holds at most one Day activity plus one Night activity. An Auction day is Auction + (Storage or Selling) in the Night slot.

Auction run settlement already returns the player to a post-run slot; that target becomes Night (it was Evening). The player then picks a Night activity as usual.

### Budgets

- Storage AP: Day = base AP max × deep-storage multiplier (25 with current constants); Night = base AP max (10).
- Selling volume: Day = 7–10 customers; Night = 2–3. This replaces the 1/2/3-slot committed-selling scaling.

### Chooser popup

The chooser opens from the single hub activity button. It registers its option buttons as tutorial anchors on open and unregisters them on close (cancel or confirm), so a tutorial can point at a chooser option that only exists while the popup is open. Cancel closes the popup without invoking any begin-activity path; confirm invokes the matching begin-activity path and navigates.

### Save compatibility

The legacy committed-selling-slots field becomes vestigial under the two-slot model. It is preserved for save compatibility (read on load, not actively used) and not removed, per the no-delete-migration rule. The slot store's version ladder gains a new migration step that remaps old slot values to the two-slot equivalents.

## Non-Goals

1. No new activities beyond Auction, Storage, Selling.
2. No rebalance of AP action costs, customer pricing, or daily living cost — only the pool sizes and customer counts the slot model implies.
3. No change to the run scene flow (location select → lot browse → inspection → auction → reveal → cargo → run review).
4. No onboarding/tutorial wiring — that is Plan C on top of Plan B. This plan delivers the chooser and its anchor hooks but no tutorial content.

## Acceptance Criteria

1. A new day offers Day then Night; choosing any activity advances exactly one slot; the day ends only after a Night activity.
2. Cancelling the chooser at either slot consumes nothing and the player remains on the hub at the same slot.
3. Day Storage grants the enlarged AP pool; Night Storage grants the base pool; the same workshop actions are available in both.
4. Day Selling spawns the larger customer set; Night Selling the smaller; both advance to the next slot or day-ending as above.
5. Auction is selectable only from the Day chooser and is absent from the Night chooser.
6. A save created under the old three-slot model loads and maps to the correct two-slot state without warnings or data loss; the day summary after migration is economically consistent.
7. The hub, day summary, and run settlement produce consistent results across a full two-slot day (Day activity + Night activity → end day).
