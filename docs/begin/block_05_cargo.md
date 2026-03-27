# Block 05 — Cargo Loading

The player selects which items to bring home from the won lot.

---

## Receives

- `GameManager.lot_result.won_items` — items available to load

---

## Produces

- `GameManager.cargo_items` — the subset of items the player chose to bring

---

## Requirements

### Limits
- Maximum 6 items
- Maximum total weight 20 kg

### UI — Checklist HUD
- Display all won items in a 5-column-wide list (one row per item)
- Each row shows:
    - Toggle button (switch style, on/off)
    - Item name
    - Item weight
- Header row shows current counts: slots used / 6, weight used / 20 kg
- Footer shows a confirm button: "Load Up"

### Toggle Behaviour
- Toggling an item on adds it to the selection
- Toggling an item off removes it
- If adding an item would exceed either limit, the toggle is disabled and unclickable
- Already-selected items can always be toggled off regardless of limits

### Confirming
- "Load Up" is always clickable (player may confirm with zero items selected)
- On confirm, write selected items to `GameManager.cargo_items`
- Advance to Block 06

### Unselected Items
- Silently ignored — no selling, no shipping, no penalty in this slice

---

## Note

- There is no drag-and-drop in this slice
- Weight and slot counts must update live as the player toggles items
- Do not show valuation ranges or true values on this screen — the player only knows what they inspected
