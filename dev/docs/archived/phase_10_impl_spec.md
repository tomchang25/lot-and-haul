# Phase 10 — Value Policy Cleanup — Implementation Spec

## Goal

Simplify the item pricing pipeline so that `item_price = (appraised or verified value) × condition_multiplier` is the sole per-item price resolution. Remove the market factor system and knowledge bonus, which are replaced by Phase 9's customer fit and sell strategy.

## Relational Context

- `ItemEntry` is the single owner of per-item price resolution. After this PR, `item_price` is a simple property on ItemEntry — no external system contributes to item-level pricing.
- `MarketManager` is an autoload that currently writes state consumed by ItemEntry, SaveManager, CategoryRegistry, SuperCategoryRegistry, and market_board UI. Removing it requires severing all six consumers.
- SaveManager serializes MarketManager state (`super_cat_means`, `category_factors_today`). The save schema must drop these keys and the load path must tolerate their absence in old saves (migration).
- CategoryRegistry and SuperCategoryRegistry run validation and migration against MarketManager dictionaries. These checks must be removed, not replaced.
- `ItemViewContext` carries `merchant` and `order` references used by deprecated selling stages. Removing the MERCHANT_SHOP and FULFILLMENT_PANEL stages here means all code that constructs or pattern-matches on them must be cleaned in the same pass.
- `PriceConfig` is consumed only by `compute_price`. If `compute_price` is replaced by the `item_price` property, PriceConfig and the ItemRegistry preset cache have no remaining callers.
- Do not touch `roll_npc_estimate` or `LotEntry.roll_npc_estimate` / `get_player_estimate` — auction NPC valuation is an independent path that does not use the pricing pipeline.

## Scope

### Included

- Replace `compute_price(config)` / `market_price` / `market_factor_delta` with a single `item_price` property on ItemEntry.
- Remove PriceConfig class and ItemRegistry preset cache.
- Remove MarketManager autoload (script, project autoload entry, CLAUDE.md autoload list).
- Remove market-related fields from SuperCategoryData (`market_mean_min`, `market_mean_max`, `market_stddev`, `market_drift_per_week`).
- Remove MarketManager save/load in SaveManager (with old-save tolerance).
- Remove MarketManager validation/migration in CategoryRegistry and SuperCategoryRegistry.
- Remove market_board scene, its scene_registry entry, and the `go_to_market_board` route.
- Remove deprecated selling helpers: `merchant_offer_value`, `special_order_value`, `merchant_offer_text`, `special_order_text` on ItemEntry.
- Remove deprecated ItemViewContext stages (MERCHANT_SHOP, FULFILLMENT_PANEL) and their factory methods.
- Remove COLUMN_MERCHANT_OFFER, COLUMN_SPECIAL_ORDER, COLUMN_MARKET_FACTOR from ItemEntry and item_row.
- Remove knowledge bonus code path from ItemEntry (the `KnowledgeManager.get_super_category_rank` call).

### Excluded

- Phase 9 customer/shop system, car total, sell multiplier.
- Merchant shop scene, fulfillment panel scene, negotiation dialog scene — file deletion belongs to Phase 9.
- Auction NPC estimate logic.
- Condition bucketing or Repair/Restore mechanics.
- UI redesign of estimated value display.

## Files to Change

| File | Change Size | Purpose |
| --- | --- | --- |
| `common/gameplay/item_entry.gd` | Large | Replace compute_price/market_price/market_factor_delta with item_price; remove knowledge bonus, deprecated selling helpers, market factor text/sort, deprecated column constants and stage branches |
| `common/gameplay/price_config.gd` | Delete | No remaining consumers |
| `common/gameplay/item_view_context.gd` | Medium | Remove MERCHANT_SHOP/FULFILLMENT_PANEL stages, merchant/order fields, their factories |
| `common/gameplay/special_order.gd` | Small | Remove `compute_item_price` and its `pricing_config` field |
| `global/autoload/market_manager.gd` | Delete | Entire system removed |
| `global/autoload/registries/item_registry.gd` | Small | Remove PriceConfig preset cache and `_build_price_config_presets` |
| `global/autoload/registries/category_registry.gd` | Small | Remove MarketManager migration and validation blocks |
| `global/autoload/registries/super_category_registry.gd` | Small | Remove MarketManager validation block |
| `global/autoload/save_manager.gd` | Small | Remove MarketManager save/load; tolerate missing keys on old saves |
| `global/autoload/meta_manager.gd` | Small | Remove `MarketManager.advance_market(days)` call |
| `data/definitions/merchant_data.gd` | Small | Remove `offer_for` and `market_price` reference |
| `data/definitions/super_category_data.gd` | Small | Remove four market-related exported fields |
| `game/meta/merchant/market_board/market_board.gd` | Delete | Entire scene removed |
| `game/meta/merchant/merchant_hub.gd` | Small | Remove market board button/navigation |
| `game/shared/item_display/item_row.gd` | Small | Remove MARKET_FACTOR column enum entry, header, width, label, refresh line |
| `game/meta/merchant/merchant_shop/merchant_shop_scene.gd` | Small | Remove MARKET_FACTOR from column list |
| `global/autoload/game_manager/game_manager.gd` | Small | Remove `go_to_market_board` |
| `global/autoload/game_manager/scene_registry.gd` | Small | Remove `market_board` PackedScene export |
| `project.godot` | Small | Remove MarketManager autoload entry |
| `CLAUDE.md` | Small | Remove MarketManager from autoload list |

## Implementation Notes

**ItemEntry.item_price** replaces all of `compute_price`, `market_price`, and `market_factor_delta`. The property body is:

```
var value = appraised_with_hidden() if verified else _raw_appraised_value()
return maxi(1, int(value * get_condition_multiplier()))
```

`estimated_value_min` and `estimated_value_max` already inline their own condition multiplier — they do not call `compute_price`. They are unchanged.

**estimated_value_text** currently does not include condition in the verified branch (`"$%d" % int(appraised_with_hidden())`). Decide whether verified display text should include condition. The estimated_value_min/max getters do include condition for verified items, so the text helper is inconsistent — align it with item_price.

**SaveManager migration**: when loading an old save that contains `super_cat_means` or `category_factors_today`, silently ignore those keys. No migration action needed — the data is simply unused.

**market_board scene file and .tscn**: delete the scene file in addition to the script. Check for a `.tscn` reference in scene_registry's export.

## Edge Cases

| Case | Expected Handling |
| --- | --- |
| Old save file contains MarketManager keys | Load succeeds; keys are silently ignored |
| Item with condition 0.0 | item_price returns at least 1 (maxi clamp) |
| Veiled item | item_price is not meaningful; display helpers already gate on anchor_revealed |
| Item with no hidden clues (auto-verified) | item_price uses appraised_with_hidden, which equals _raw_appraised_value when hidden lists are empty |

## Acceptance Criteria

1. All item price resolution goes through a single `item_price` property that equals `(appraised or verified value) × condition_multiplier`.
2. No code references MarketManager, market factor, knowledge rank bonus, or PriceConfig.
3. Deprecated selling helpers (merchant offer, special order price) and their column/stage entries are removed from ItemEntry and ItemViewContext.
4. Old saves load without error regardless of whether they contain market data.
5. Condition multiplier functions identically — low-condition items show reduced prices, Repair/Restore still works.
6. Estimated value range display narrows with inspection and collapses on full reveal.
7. Project loads and runs without errors or warnings related to removed systems.
