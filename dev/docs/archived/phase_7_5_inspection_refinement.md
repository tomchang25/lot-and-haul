## Goal

Refine inspection semantics, item display naming, and clue reveal mechanics to create clearer player-facing language, a more exciting inspection flow (chain reveals), and lot-level variety in item visibility. This addresses three gaps left by Phase 7: naming stages lack a unified vocabulary, single-clue-per-AP inspection feels flat, and lots have no influence over initial item visibility.

## Requirements

1. **Naming vocabulary** — Establish a project-wide glossary for item knowledge states. "Veiled" = anchor unrevealed, displays "Unknown [Category Name]". "Unveiled" = anchor revealed, displays "Unknown [Anchor Display Name]". "Verified" = all hidden clues revealed, displays true item name. All code, UI text, and documentation use these terms consistently.

2. **Unveil action** — Unveiling an item (revealing its anchor clue) costs a fixed 1 AP. This replaces the current variable-cost search action. Lots may contain a mix of pre-unveiled and veiled items; the ratio is controlled by a per-lot probability field that each item rolls against independently.

3. **Chain reveal** — Attempting to reveal clues (surface or hidden) costs a fixed 2 AP per attempt. On success, the system immediately attempts the next unrevealed clue in sequence. The chain continues until a check fails or no unrevealed clues remain. Clue attempt order is designer-controlled (data-driven, not player-chosen). The displayed success rate reflects only the first clue in the chain; subsequent clues may have different DCs.

4. **Clue result display** — Reveal check outcomes (success/fail, clue text, modifier) display in a dedicated result area, not inside the value column. This separates discovery feedback from price display and supports chain reveal animation (sequential clue flip).

5. **Hidden clue inspection access** — Hidden clues can be attempted during inspection alongside surface clues, using the same chain reveal mechanic and AP cost. Their DCs are typically higher, making in-run discovery unlikely but possible. Unrevealed hidden clues do not auto-reveal on hub return (only surface clues do).

6. **Verified as derived state** — The verified flag becomes a computed property: true when all hidden clues on the item are revealed. No manual flag-setting. If all hidden clues happen to be revealed during inspection, the item is immediately verified without requiring a storage action.

7. **Research action** — Storage Authenticate is renamed to Research. Research reveals all hidden clues on completion, same as the current Authenticate model. Research occupies the same slot and UI position as the current Authenticate action. Per-clue granularity is deferred to the storage AP redesign.

## Non-Goals

1. Do not redesign the storage slot system or hub phase flow structure (separate decision note covers this).
2. Do not implement dynamic naming templates (Phase 8 scope).
3. Do not change the attribute system, DC formula, or success rate calculation.
4. Do not add player-selectable clue ordering during inspection.

## Acceptance Criteria

1. A veiled item displays "Unknown [Category Name]". An unveiled item displays "Unknown [Anchor Display Name]". A verified item displays the true item name. No other naming patterns exist.
2. Unveiling costs 1 AP. Chain reveal costs 2 AP and processes clues sequentially until failure or exhaustion.
3. A single 2 AP spend can reveal multiple clues in one action if successive checks pass.
4. Lots define an unveil probability. Each item in the lot independently rolls against it to determine starting veil state.
5. Reveal results appear in a dedicated display area separate from the value column.
6. An item with all hidden clues revealed is verified regardless of how or where those clues were discovered.
7. Storage Research reveals all hidden clues on completion (unchanged from current Authenticate behavior, renamed only). Per-clue granularity deferred to storage AP redesign.
