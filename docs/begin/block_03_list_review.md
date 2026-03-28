# Block 03 — List Review

A static popup summary screen between Inspection and Auction. No interaction beyond advancing and returning.

---

## Receives

- `GameManager.current_lot` — item list
- `GameManager.inspection_results` — inspection levels per item

---

## Produces

Nothing. Read-only bridge between Block 02 and Block 04.

---

## Requirements

- Display all items in a list
- For each item, show:
    - Item name
    - Inspection status indicator (browsed / examined / uninspected)
    - Valuation range if inspection level > 0, otherwise "?"
- Show the total estimate price range
- Show the opening bid price at the bottom (sum of all true values x 0.25)
    - This is informational — the player cannot act on it yet
- Two buttons: "Enter Auction" — advances to Block 04, "Back" - Return to Inspect

---

## Note

- No editing or re-inspection allowed from this screen
- Opening bid price shown here must match exactly what Block 04 uses
- Layout is a simple vertical list — no sorting or filtering needed
- Use four spaces instead tab to indent
