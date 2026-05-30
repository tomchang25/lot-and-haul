# Phase 9 — Final Cleanup: Legacy Selling Removal + Save Migration (Impl Spec)

## Goal

Complete Phase 9 by deleting the legacy merchant / special-order selling stack now that the nightly customer system is live, and migrate existing saves off the removed keys. This makes the customer system the only selling path and removes dead boot, routing, and data.

## Relational Context

- `MetaManager.advance_days` must stop calling `MerchantRegistry.advance_day()`; nightly customer generation is now the only day-advance sell-side hook. `MetaManager.sell_items` and `fulfill_order` are legacy-only and are removed with their callers.
- `SaveManager` is the migration authority: on load it silently drops `merchant_negotiations_used_today`, `merchant_orders`, and `next_order_id`, and stops writing them. The only sell-related persisted state after this PR is `cash`, `storage_items`, `nightly_customers`, and `customer_sales_today`.
- `GameManager` routes hub selling solely through `go_to_customer_sell`; remove `_pending_merchant` and the `merchant_hub` / `merchant_shop` / `fulfillment_panel` routing. The hub Merchant button already points at the customer-sell scene.
- `scene_registry` must drop the `merchant_hub` / `merchant_shop` / `fulfillment_panel` `PackedScene` exports. Leaving `@export` refs to deleted scenes breaks the GameManager autoload `.tscn` load.
- `MerchantRegistry` is an autoload that self-registers with `RegistryCoordinator` in `_ready`. Removing it means deleting the `project.godot` autoload entry and the documented load order in `CLAUDE.md`, not just the script.
- Negotiation is one of the five SPECIAL attributes (`data/tres/attributes/negotiation.tres`), not merchant state — do **not** remove it.
- Wrong shape to avoid: do not let `SellMath` / `Customer` / `customer_sell_scene` take on any merchant reference during cleanup — the new sell path is already self-contained.

## Scope

### Included

- Delete legacy scripts, scenes, and data for merchants and special orders.
- Remove the `MerchantRegistry` autoload and its boot/load-order documentation; remove `MERCHANTS_DIR` and `SPECIAL_ORDERS_DIR`.
- Strip merchant routing from `GameManager` and `scene_registry`; remove `sell_items` / `fulfill_order` and merchant calls from `MetaManager`.
- `SaveManager`: stop serializing merchant/order keys; drop them silently on load.
- Minor robustness: remove the unused `Customer.generate_batch`; normalize `customer_sales_today` `item_ids` to `int` on load.

### Excluded

- `arms_dealer` / `fashion_buyer` conversion (no `.tres` exist).
- The Negotiation attribute.
- Phase 11 Day Summary consumption / timing of `customer_sales_today`.
- Any behavioral change to the customer sell loop.

## Files to Change

| File | Change Size | Purpose |
| --- | --- | --- |
| `global/autoload/registries/merchant_registry.gd` (+ `.uid`) | Large | Delete; drop autoload + boot order |
| `data/definitions/merchant_data.gd`, `special_order_data.gd`, `special_order_slot_pool_entry.gd` | Medium | Delete resource scripts |
| `common/gameplay/special_order.gd`, `order_slot.gd` | Medium | Delete runtime types |
| `game/meta/merchant/**` (merchant_hub, merchant_shop, fulfillment_panel, negotiation_dialog) | Large | Delete scenes + scripts |
| `data/tres/merchants/*`, `data/tres/special_orders/*`, `data/yaml/merchant_data.yaml`, `special_order_data.yaml`, `dev/tools/tres_lib/entities/merchant.py`, `special_order_data.py` | Medium | Delete content + pipeline entities |
| `global/autoload/meta_manager.gd` | Medium | Remove `sell_items`, `fulfill_order`, merchant day/negotiation calls |
| `global/autoload/save_manager.gd` | Medium | Drop merchant/order serialization; migrate on load; int-normalize ledger |
| `global/autoload/game_manager/game_manager.gd` + `scene_registry.gd` | Small | Remove merchant routing + scene exports |
| `project.godot`, `CLAUDE.md` | Small | Remove autoload entry; update load order |

## Implementation Notes

- Project must compile after each deletion: remove references before deleting the file they point to.
- Verify no remaining `MerchantRegistry`, `MerchantData`, `SpecialOrder`, or `OrderSlot` symbol survives outside deleted files (grep both `.gd` and `.tscn`).
- `SaveManager` load already ignores unknown keys for the removed `MarketManager`; mirror that pattern — read nothing into removed state, just don't write the keys back out.

## Edge Cases

| Case | Expected Handling |
| --- | --- |
| Pre-Phase-9 save with merchant/order keys | Keys ignored on load; `cash` and `storage_items` preserved; not re-written on next save |
| Save with `customer_sales_today` from JSON | `item_ids` coerced to `int` on load |
| Save lacking `nightly_customers` | Field resets to empty; customers regenerate on next day advance |

## Acceptance Criteria

1. No selling path or routing exists outside the customer system; the hub Merchant button reaches only the customer-sell scene.
2. The project compiles and launches with the merchant registry, scenes, and data removed.
3. A pre-Phase-9 save loads without error, preserving cash and storage, with legacy merchant/order keys dropped and absent from subsequent saves.
4. The Negotiation attribute remains intact and unaffected.
