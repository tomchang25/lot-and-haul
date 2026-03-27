# Block 02 — Inspection

The player interacts with items in the warehouse scene using limited stamina.

---

## Receives

- `GameManager.current_lot` — the 4 items placed in the scene

---

## Produces

- `GameManager.inspection_results` — Dictionary mapping each item to its inspection level (0, 1, or 2)

---

## Requirements

### Stamina
- Fixed pool of 8 points per run
- Displayed as a counter in the HUD
- When stamina reaches 0, inspection ends automatically and advances to List Review

### Actions
- Two actions available (warehouse restriction — no touch action):
    - Browse: costs 1 stamina, sets inspection level to 1
    - Examine: costs 3 stamina, sets inspection level to 2
- Clicking an item opens an action menu showing available actions
- Actions that cannot be afforded (not enough stamina) are greyed out and unselectable
- Applying a lower-level action to an already higher-level item has no effect

### Valuation Range (ClueEvaluator)
- Inspection level 0: display "?"
- Inspection level 1 (browse): range = [true_value x 0.4, true_value x 2.0]
- Inspection level 2 (examine): range = [true_value x 0.8, true_value x 1.3]
- Knowledge level is fixed at 0 — do not read from KnowledgeManager

### Scene
- 4 items placed statically in the warehouse testbed scene
- Each item is clickable
- A small label or indicator on each item shows its current inspection status

---

## Note

- `KnowledgeManager` autoload must exist but only returns level 0 — do not implement upgrade logic
- Stamina depletion is the only way to exit this stage; there is no manual "done" button
- Valuation range is calculated at display time, not stored
