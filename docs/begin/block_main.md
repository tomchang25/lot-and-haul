# Block Main — Cross-Block Items

Items that span multiple blocks or don't belong to a single block.

---

## MVP Todolist

- [ ] `GameManager` reset function: single call clears all run state (inspection_results, lot_result, cargo_items, run_result, re-populates current_lot)
- [ ] `GameManager.run_result` field: add `{ sell_value, paid_price, net }` written by Block 06, read by Block 07
- [ ] Scene routing: wire all block transitions through a central scene switcher or GameManager method (Block 02 → 03 → 04 → 05 → 06 → 07 → 02...)

## Itch Demo Todolist

- [ ] `ItemRunContext` resource class: per-run generated context for each item, separate from static `ItemData`
  - `is_veiled: bool`
  - Stored in `GameManager.item_contexts: Dictionary` (ItemData → ItemRunContext)
  - Generated at run start alongside `current_lot`
- [ ] `KnowledgeManager` real implementation: per-category knowledge levels, persisted across runs
- [ ] Pawn shop merchant: `MerchantData` resource with buy rate range (0.4–0.6× true value), buys all item types
- [ ] Basic specialist merchant: `MerchantData` with category/super_category filter, higher rate for matched items
  - Match (category + interested): × 1.5–2.0
  - Same super_category, different category: × 0.8
  - Uninteresting to merchant: × 0.8
  - Worst case (different super_category + uninteresting): 1.5 × 0.8 × 0.8 = 0.96 — still above pawn shop floor
- [ ] Persistent run-to-run state: gold balance, knowledge levels, van upgrades (minimal save data)

## Post Demo Todolist

- [ ] Full merchant variant system: aggressive factor, NPC personality affecting bid behaviour
- [ ] Reputation system: tracked per merchant/faction, degrades on scam detection, affects prices and access
- [ ] Scam flow: player can knowingly sell a fake; outcome branches (safe / caught / reputation hit)
- [ ] Own shop: player lists items, sets price, sell frequency scales with price vs. market rate (~0.8–1.5× true value)
- [ ] Expert network: appraisers, restorers, contacts unlockable and callable between runs
- [ ] Museum / collection donations: alternative to selling, builds prestige track
