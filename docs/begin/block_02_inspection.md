# Block 02 — Inspection

The player interacts with items in the warehouse scene using limited stamina.

---

## Receives

- `GameManager.current_lot` — the 4 items placed in the scene

---

## Produces

- `GameManager.inspection_results` — Dictionary mapping each item to:
  - `level` (int): 0, 1, or 2
  - `clues_revealed` (int): number of clues unlocked (derived from level and store seperatly)
    - level 0 → 0 clues
    - level 1 → 2 clues
    - level 2 → all clues (clues.size())

---

## Requirements

### Stamina
- Fixed pool of 8 points per run
- Displayed in HUD as: `current / max` (e.g. `8 / 8`)
- When stamina reaches 0, inspection ends automatically
- Exit transition: "Start Auction" button frame pulses/glows, no scene cut delay

### Actions
- Two actions available (warehouse restriction — no touch):
  - **Browse**: costs 1 stamina, sets inspection level to 1
  - **Examine**: costs 3 stamina, sets inspection level to 2
- Clicking an item opens an action popup below the item containing three buttons:
  - Browse
  - Examine
  - Cancel
- Affordability:
  - Actions the player cannot afford are greyed out and unclickable
  - Browse is greyed out (disabled appearance) once the item is already at level 1 or higher
  - Examine can still be selected on a level 1 item (upgrade path, costs rest 2 stamina)
  - Applying an action that would not raise the level has no effect and should not be selectable
- Popup dismissal:
  - ESC key
  - Cancel button
  - Left-clicking anywhere outside the popup (including on another item — closes current popup and opens the new one)

### Item Display (per item in scene)
- Sprite representing the item
- Estimated price range label:
  - Level 0: `?`
  - Level 1: range calculated from true_value (see ClueEvaluator)
  - Level 2: narrower range calculated from true_value (see ClueEvaluator)
- Inspection level indicator: shows current level (0 / 1 / 2)
- On level change: small tween animation on the level indicator (e.g. scale pop or color flash)

### Valuation Range (ClueEvaluator)
- Calculated at display time, not stored
- Level 0: `?`
- Level 1 (browse): `[true_value × 0.4, true_value × 2.0]`
- Level 2 (examine): `[true_value × 0.8, true_value × 1.3]`
- Knowledge level fixed at 0 — KnowledgeManager autoload must exist but always returns 0

### Scene
- 4 items placed statically in the scene
- No testbed required — integrate directly into warehouse scene

---

## Out of Scope
- KnowledgeManager upgrade logic
- Manual "done" / "end inspection" button
- Item highlight on action menu open
- Touch action
