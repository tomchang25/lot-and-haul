# Phase 7.5 — Inspection Refinement

## Goal

Refine inspection semantics and clue reveal mechanics to establish a consistent naming vocabulary (Veiled / Unveiled / Verified), replace the variable-cost unveil action with a fixed 1 AP cost, and introduce chain reveal so a single 2 AP spend can discover multiple clues in sequence. Addresses three gaps left by Phase 7: inconsistent naming, flat single-clue inspection, and no lot-level control over initial item visibility.

## Relational Context

- `ItemEntry.verified` is currently a stored `bool` written by `MetaManager`. It must become a computed property derived from hidden clue coverage. `MetaManager` must stop writing `entry.verified = true` — it should only call `reveal_all_hidden()`.
- `InspectionScene` currently writes to `ItemEntry` directly (`unveil()`, `reveal_anchor()`, `attempt_surface_clue()`). This stays. Do not route inspection writes through `RunManager`.
- `InspectionScene` owns chain reveal loop logic. `ItemEntry.attempt_surface_clue()` stays single-clue. The loop that retries on success lives in the scene, not in `ItemEntry`.
- AP spending stays in `InspectionScene` (`RunManager.run_record.actions_remaining -= cost`). `RunManager` is not being expanded.
- Lot unveil probability is applied once at lot generation in `LotEntry` (when `item_entries` is populated). After that, `ItemEntry.inspected` is the sole authority on veil state. `LotData.veiled_chance` is the source field — it already exists as a deprecated field and needs to be reactivated.
- Hidden clues are attempted in the same chain as surface clues. Clue attempt order follows the designer-controlled sequence in `ItemData`'s clue array — not sorted by DC (remove current lowest-DC selection logic from `_attempt_clue_reveal`). Hidden clues must always appear after all surface clues in that array — enforced at the YAML pipeline level. This means the chain naturally exhausts surface clues before reaching hidden ones; no skip logic is needed in `InspectionScene`.

## Scope

### Included

- Naming constants for Veiled / Unveiled / Verified display states.
- Fixed 1 AP unveil action (replaces variable shape-based SEARCH cost).
- Chain reveal: 2 AP per attempt, sequential clues until failure or exhaustion.
- Dedicated clue result display area in InspectionScene, separate from value column.
- Hidden clues accessible during inspection via the same chain mechanic.
- `verified` changed from stored field to computed property.
- Storage Research rename (Authenticate → Research) in MetaManager and UI.
- Lot unveil probability reactivated in LotData / LotEntry.

### Excluded

- Storage AP redesign or per-clue Research granularity.
- Dynamic naming templates (Phase 8).
- Attribute system, DC formula, or success rate calculation changes.
- Player-selectable clue ordering.

## Files to Change

| File | Change Size | Purpose |
| --- | --- | --- |
| `common/gameplay/item_entry.gd` | Medium | Convert `verified` to computed property; expose hidden clues for inspection. |
| `game/run/inspection/inspection_scene.gd` | Large | Fixed AP costs, chain reveal loop, dedicated result area, hidden clue access. |
| `data/definitions/lot_data.gd` | Small | Reactivate `veiled_chance` field (remove deprecated marker). |
| `common/gameplay/lot_entry.gd` | Small | Apply `veiled_chance` roll per item at lot generation. |
| `global/autoload/meta_manager.gd` | Small | Remove `entry.verified = true` write; rename AUTHENTICATE → RESEARCH. |

## Implementation Notes

**`item_entry.gd`**

- Replace `var verified: bool` with a computed getter: true when every clue in `_hidden_clues()` has its `clue_id` in `revealed_clue_ids`. If the item has no hidden clues, `verified` is true by default.
- Add or expose a method that returns all inspection-eligible clues in designer order (surface + hidden, in array order from `ItemData`). `InspectionScene` uses this to build the chain sequence instead of filtering surface-only and sorting by DC.

**`inspection_scene.gd`**

- Unveil action: remove `_search_duration_by_entry` and all shape-size calculation. Fixed cost is 1 AP.
- Chain reveal: spend 2 AP upfront. Call `attempt_surface_clue()` (or equivalent) on the first unrevealed eligible clue. If it returns true, immediately attempt the next — loop until failure or no clues remain. Display each result sequentially in the dedicated result area.
- Dedicated result area: add a new Label or container node for clue flip results. Clue text and success/failure go here. `%ValueValueLabel` continues to show item price estimate only.
- Hidden clue eligibility: include hidden clues in the chain sequence. Their DCs are higher; the existing `attempt_surface_clue` logic (DC roll + attribute bonus) applies unchanged.

**`lot_entry.gd`**

- When populating `item_entries`, roll `randf() > lot_data.veiled_chance` per item. Items that pass start with `inspected = true` and `anchor_revealed = true` (pre-unveiled).

**YAML pipeline (`dev/tools/validate_yaml.py`)**

- Add a validation rule: for any item, all clues with `type: hidden` must appear after all clues with `type: surface`. Fail loudly on violation so authoring errors are caught before `.tres` generation.

**`meta_manager.gd`**

- In `_tick_research_slots`: remove `entry.verified = true`. Keep `entry.reveal_all_hidden()`. Verified state follows automatically.
- Rename enum value `SlotAction.AUTHENTICATE` → `SlotAction.RESEARCH` and update all references.

## Edge Cases

| Case | Expected Handling |
| --- | --- |
| Item has no hidden clues | `verified` returns true immediately after anchor is revealed. |
| All surface clues already revealed | Chain attempt finds only hidden clues (if any); correct. |
| `veiled_chance = 0.0` | All items in lot start pre-unveiled. |
| `veiled_chance = 1.0` | All items start veiled (current default behavior). |
| Player unveils an item that has no surface or hidden clues | Unveil succeeds (1 AP), anchor reveals. Chain attempt finds nothing; no AP spent. |

## Acceptance Criteria

1. A veiled item displays "Unknown [Category Name]". An unveiled item displays "Unknown [Anchor Display Name]". A verified item displays the true item name.
2. Unveiling costs exactly 1 AP regardless of item shape or size.
3. A single 2 AP chain attempt can reveal multiple clues if successive checks pass.
4. Clue results (text and success/failure) appear in a display area visually separate from the item price estimate.
5. Hidden clues are included in the chain sequence and can be discovered during inspection.
6. An item whose all hidden clues are revealed is `verified` regardless of how or where discovery happened. No storage action required if hidden clues are revealed during inspection.
7. Storage Research behaves identically to the old Authenticate (reveals all hidden clues on completion). Only the name changes.
8. Lots with a non-zero `veiled_chance` produce a mix of veiled and pre-unveiled items. Each item rolls independently.
