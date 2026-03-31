# Block Main — Cross-Block Items

Items that span multiple blocks or don't belong to a single block.

---

## Finished Todolist

- [x] `GameManager` reset function: single call clears all run state (inspection_results, lot_result, cargo_items, run_result, re-populates current_lot)
- [x] `GameManager.run_result` field: `{ sell_value, paid_price, net }` written by Block 06, read by Block 07
- [x] Scene routing: all block transitions wired through GameManager methods (Block 02 → 03 → 04 → 05 → 06 → 07 → 02...)

## Itch Demo Todolist

- [ ] `ItemEntry` runtime class (`game/warehouse/item_entry.gd`):
    - `item_data: ItemData`
    - `inspection_level: int` — 0 (veiled) / 1 (untouched) / 2 (browsed) / 3 (examined) / 4 (researched) / 5 (authenticated);
    - `resolved_veiled_type: VeiledType` — null if `inspection_level > 0`
    - Generated at run start; lives until appraisal settles and `item_entries` is cleared
    - Future: may persist into `SaveData` until sold at a shop
- [ ] `VeiledType` designer resource (`data/_definitions/veiled_type.gd`):
    - `type_id: String`
    - `display_label: String`
    - `base_veiled_price: int`
    - `.tres` files under `data/veiled_types/`
- [ ] `ItemData.veiled_types: Array[VeiledType]` — candidate pool per item; one picked uniform-random at run start
- [ ] `GameManager.item_entries: Array[ItemEntry]` replaces `current_lot: Array[ItemData]` + `inspection_results: Dictionary`
    - Generated in `_init_default_lot()` (or its replacement); each entry wraps one `ItemData`
    - `resolved_veiled_type` picked randomly from `item_data.veiled_types` if `is_veiled = true`
    - `lot_result.won_entries: Array[ItemEntry]` replaces `won_items: Array[ItemData]`
    - `cargo_items: Array[ItemEntry]` replaces `cargo_items: Array[ItemData]`
- [ ] `KnowledgeManager` real implementation: per-category knowledge levels, persisted across runs
- [ ] Pawn shop merchant: `MerchantData` resource with buy rate range (0.4–0.6× true value), buys all item types
- [ ] Basic specialist merchant: `MerchantData` with category/super_category filter, higher rate for matched items
    - Match (category + interested): × 1.5–2.0
    - Same super_category, different category: × 0.8
    - Uninteresting to merchant: × 0.8
    - Worst case (different super_category + uninteresting): 1.5 × 0.8 × 0.8 = 0.96 — still above pawn shop floor
- [ ] Persistent run-to-run state: gold balance, knowledge levels, van upgrades (minimal save data)

## Post Demo Todolist

- [ ] Split `GameManager` into `RunData` (single-run state) and `SaveData` (persistent meta-layer)
    - `RunData` extraction takes priority — `SaveData` deferred until meta systems exist
- [ ] Full merchant variant system: aggressive factor, NPC personality affecting bid behaviour
- [ ] Reputation system: tracked per merchant/faction, degrades on scam detection, affects prices and access
- [ ] Scam flow: player can knowingly sell a fake; outcome branches (safe / caught / reputation hit)
- [ ] Own shop: player lists items, sets price, sell frequency scales with price vs. market rate (~0.8–1.5× true value)
- [ ] Expert network: appraisers, restorers, contacts unlockable and callable between runs
- [ ] Museum / collection donations: alternative to selling, builds prestige track
