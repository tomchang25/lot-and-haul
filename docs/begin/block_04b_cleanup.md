# Block 04b — Cleanup

After winning the auction, the player gets one last look at the lot before loading the van.

This block sits between Auction (Block 04) and Cargo Loading (Block 05).
It reuses the inspection UI but operates on a separate stamina budget.

---

## Receives

- `GameManager.lot_result.won_items` — the items the player just won
- `GameManager.inspection_results` — existing inspection state carried forward from Block 02

---

## Produces

- `GameManager.inspection_results` — updated in-place (levels can increase; cannot decrease)

---

## Requirements

### Stamina
- Separate pool of 8 points, independent from Block 02 stamina
- Displayed in HUD the same way as Block 02: `current / max`
- When stamina reaches 0, cleanup ends automatically and advances to Block 05

### Actions
- Same two actions as Block 02 (warehouse context — no touch):
  - **Browse**: costs 1 stamina, sets inspection level to 1 (no-op if already ≥ 1)
  - **Examine**: costs 3 stamina from 0, or 2 stamina from level 1, sets level to 2
- Inspection levels can only increase — applying an action that would not raise the level is disabled

### Scene
- Reuses the same item display layout as Block 02
- Items that were already at level 2 in Block 02 show all buttons disabled (nothing left to reveal)
- A "Done" button is always visible and skips the remaining stamina

### Transition
- When stamina reaches 0 or player presses "Done": advance to Block 05 (Cargo Loading)

---

## Note

- This phase exists to let players make better cargo decisions after they know they won
- It is not a second full inspection — the stamina budget is intentionally tight
- Do not reset inspection_results; carry forward whatever Block 02 produced

---

## MVP Todolist

- [ ] This entire block is Itch Demo scope — do not implement in MVP

## Itch Demo Todolist

- [ ] Implement Cleanup scene reusing Block 02 inspection UI
- [ ] Separate stamina tracker instance (does not share state with Block 02)
- [ ] "Done" button to skip remaining stamina and advance early
- [ ] Items at max level (2) show all action buttons disabled

## Post Demo Todolist

- [ ] Touch action available in cleanup if unlocked (costs 2 stamina, intermediate level)
- [ ] Cleanup stamina upgradeable via vehicle/tool unlocks
