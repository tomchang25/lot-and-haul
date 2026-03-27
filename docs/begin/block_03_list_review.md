# Block 03 — List Review

A static summary screen between Inspection and Auction. No interaction beyond advancing.

---

## Receives

- `GameManager.current_lot` — item list
- `GameManager.inspection_results` — inspection levels per item

---

## Produces

Nothing. Read-only bridge between Block 02 and Block 04.

---

## Requirements

- Display all 4 items in a list
- For each item, show:
    - Item name
    - Inspection status indicator (browsed / examined / uninspected)
    - Valuation range if inspection level > 0, otherwise "?"
- Show the NPC's opening bid price at the bottom (sum of all true values x 0.75)
    - This is informational — the player cannot act on it yet
- Single button: "Enter Auction" — advances to Block 04

---

## Note

- No editing or re-inspection allowed from this screen
- NPC bid price shown here must match exactly what Block 04 uses
- Layout is a simple vertical list — no sorting or filtering needed
