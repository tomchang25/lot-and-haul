# Debug: Cargo Quick-Pack Buttons

## Goal

Add two debug-only action buttons to the cargo scene: one auto-packs all won items into the grid legally in a single press, and one commits every won item as carried — ignoring grid and capacity entirely — and jumps straight to run review. This removes manual grid-dragging from every test loop, and the legal auto-pack doubles as the behavioral prototype for a future perk-unlocked auto-place feature.

## Requirements

1. Both buttons exist only behind the debug gate and are created in code per the debug node rules — they never appear or activate in release builds.
2. **Auto-pack**: one press places every currently unplaced won item into the cargo grid using legal placement — respecting each item's shape cells, grid bounds, occupied cells, and the car's weight limit. Items that fit nowhere are skipped, and once the grid or weight budget is exhausted, remaining items spill into empty trailer slots in order; anything still left stays unloaded in the item list. No navigation happens — the player reviews the result, may adjust manually, and continues through the normal confirm flow. Legality matters because this behavior is the seed of a future perk-unlocked player-facing auto-place feature and must produce only states the player could reach by hand.
3. **Stuff all & go**: one press commits every won item as carried regardless of grid capacity, shapes, or weight, then navigates to run review with no confirm popup. All items are committed as main cargo (none as trailer) so the trailer damage roll adds no randomness to test runs, no items are left behind, and on-site sell proceeds are zero.
4. The legal auto-pack placement behavior must be reusable by the future perk-gated auto-place feature without modification — the debug button is just a trigger in front of it.
5. Stuff-all deliberately produces states unreachable by manual play (over-capacity, over-weight loads). This is invisible to the current run-review display; if a future system reads capacity or weight to determine penalties, stuff-all must either cap to fit or surface the overflow clearly. (Accepting this gap because no such system exists yet.)
6. The buttons are momentary actions, not modes: nothing is persisted, each press acts on the current scene state, and the manual packing flow is untouched when no button is pressed.

## Design

**Auto-pack** is a first-fit pass over the unplaced items in item-list order. For each item, scan grid positions left-to-right, top-to-bottom and place at the first position where the item's shape fits and the weight limit holds; no rotation search and no optimization, because developer speed (and later, a fair player convenience) is the goal, not space efficiency. Items already placed in the grid or trailer are left where they are — the button only fills, never rearranges — so pressing it after partial manual packing completes the load, and pressing it again when nothing is unplaced does nothing. The future perk version is the same pass triggered by a player-facing control instead of the debug gate.

**Stuff all & go** bypasses placement entirely: it hands the full won-items list to the same cargo commit side effect the confirm popup normally triggers, with an empty trailer assignment and zero on-site proceeds, then navigates to run review. The grid state on screen at press time is irrelevant — the commit is built from the won-items list, not from placements.

## Non-Goals

1. Do not build the player-facing auto-place perk (UI, unlock, balancing) — this plan only requires the placement behavior be reusable by it.
2. Do not add a smart packing algorithm (rotation heuristics, optimal fit, weight balancing) — first-fit is sufficient for both the debug use and the future convenience feature.
3. Do not persist any debug state or cargo assignment outside the normal commit.
4. Do not add hotkey bindings in this plan.
5. Do not skip the cargo scene entirely (redirect reveal→run-review) — the scene remains the checkpoint where the buttons live.

## Acceptance Criteria

1. With the debug gate off, the cargo scene is behavior-identical to today: no buttons, full interactive grid, confirm popup.
2. Pressing auto-pack on a fresh scene fills the grid first-fit with legal placements only (no overlap, no out-of-bounds, weight limit respected), spills overflow into trailer slots, and leaves the remainder unloaded; the scene stays interactive and the summary reflects the new state.
3. Pressing auto-pack after partial manual packing places only the unplaced items and moves nothing already placed; pressing it with nothing unplaced changes nothing.
4. Pressing stuff-all commits every won item as main cargo with zero on-site proceeds and an empty trailer, and lands on run review — even when items far exceed grid or weight capacity.
5. The two buttons are independent of each other and of the auction quick-win buttons.
6. A release export never creates the buttons and never enters either code path.
