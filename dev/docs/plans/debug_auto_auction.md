# Debug: Auction Quick-Win Buttons

## Goal

Add two debug-only action buttons to the auction scene that immediately resolve the auction as a player win — one at the opening bid, one at the lot's pre-rolled final price — and jump to the reveal scene, skipping the NPC bidding loop. This removes the wait through the full bidding sequence on every test loop, and the rolled-price path doubles as the behavioral prototype for a future perk-unlocked auto-bid feature.

## Requirements

1. Both buttons exist only behind the debug gate and are created in code per the debug node rules — they never appear or activate in release builds.
2. **Win at opening bid**: one press resolves the auction as a player win at the opening bid price, runs the normal lot-win commit side effect, and navigates to the reveal scene. The opening bid is the floor the auctioneer would accept — this is a pure developer shortcut, not a simulation of a realistic outcome.
3. **Win at rolled price**: one press resolves the auction as a player win at the lot's pre-rolled final price — the value the NPC bidding sequence is already destined to converge to — with the same commit and navigation. This instantly produces the price a fully played-out auction would reach, which is exactly what a future perk-gated auto-bid feature needs, so the resolution behavior must be reusable by that feature without modification.
4. Both buttons resolve through one shared "win now at price X" behavior, parameterized only by price, using the same resolution path as a normal player win (items added to the won-items pool, price accumulated into the run's paid total) so downstream reveal and cargo scenes see consistent state.
5. Pressing either button effectively discloses the rolled price to the developer (immediately or via the paid total). This is acceptable only because the buttons sit behind the debug gate — the existing rule that the rolled price is never exposed outside the debug gate still stands.
6. The buttons are momentary actions, not modes: nothing is persisted, and the manual bidding flow is untouched when no button is pressed.

## Design

The auction already rolls its final price once per lot before the bidding animation starts; the NPC tick sequence is presentation converging on that number. Both buttons therefore skip straight to resolution:

- Opening-bid button → win price = opening bid (the auction's starting display price).
- Rolled-price button → win price = the pre-rolled final price.
- Either press: disable further input, mark the player as winner at that price, run the lot-win commit, navigate to reveal — the same terminal sequence a manual win performs, minus the animation.

The buttons can be pressed at any point before normal resolution; whatever the current display price is, the button's defined price wins (the shortcut is deterministic, not state-dependent). After a press the normal NPC timer and circle animation must not fire again.

The shared resolution behavior is the seed of the future auto-bid perk ("bid for me up to $X"): that feature resolves at min(rolled price, player cap) instead of unconditionally at rolled price, but consumes the same win-at-price entry point. Designing the entry point price-parameterized now means the perk only adds a cap rule and a player-facing trigger later.

## Non-Goals

1. Do not build the player-facing auto-bid perk (UI, cap input, perk unlock) — this plan only requires the resolution behavior be reusable by it.
2. Do not animate or summarize the skipped bidding sequence — the jump is instant.
3. Do not persist any debug state — the buttons are stateless actions.
4. Do not add hotkey bindings in this plan.
5. Do not skip the auction scene entirely (redirect inspection→reveal) — the scene remains the checkpoint where the buttons live.

## Acceptance Criteria

1. With the debug gate off, the auction scene is pixel- and behavior-identical to today: no buttons, full NPC sequence, manual bid/pass flow.
2. Pressing the opening-bid button commits a player win at the opening bid and lands on the reveal scene; reveal and cargo show the lot's items with the paid total increased by exactly the opening bid.
3. Pressing the rolled-price button commits a player win at the lot's pre-rolled final price; the paid total increases by exactly that rolled value.
4. After either press, no further NPC ticks, circle completions, or duplicate commits occur.
5. A release export never creates the buttons and never enters the quick-win code path.
