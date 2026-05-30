# Phase 10 — Value Policy Cleanup

## Goal

Simplify the item pricing pipeline so that appraised value × condition multiplier is the sole per-item price resolution. The current pipeline carries market factor and knowledge bonus layers that no longer serve a design purpose — Phase 9's customer fit and sell strategy mechanics replace their role. Removing them reduces code surface, eliminates dead toggles, and establishes a clean contract for Phase 9 to build on.

## Requirements

1. Replace the multi-toggle pricing pipeline with a single resolved price property (`item_price`) that computes `(appraised or verified value) × condition_multiplier`. No other factors participate.
2. Remove the market factor system — the autoload that tracks per-category daily price factors, the drift/resample logic, and all references from data definitions and UI.
3. Remove the knowledge bonus from the pricing path (the per-super-category rank multiplier).
4. Simplify or remove the config object that toggles pricing factors — with market and knowledge gone, the remaining axis is condition only, which may not need a dedicated config class.
5. Remove old selling-channel price helpers that will not survive into Phase 9 — merchant offer calculation, special order price calculation, and their callers in the merchant shop, negotiation dialog, and fulfillment panel.
6. Preserve condition as an independent system — it is not a clue and remains coupled to Repair/Restore research. The non-linear condition multiplier bucketing is unchanged.
7. Preserve all existing display logic for estimated value ranges, condition text, and display state — only the underlying price resolution changes.

## Non-Goals

1. Do not build the Phase 9 customer/shop selling system or any transaction-level pricing (car total, sell multiplier).
2. Do not redesign the item display UI or value range presentation.
3. Do not remove or restructure the merchant/special-order scene files themselves — only decouple them from the pricing pipeline. Full scene deprecation belongs to Phase 9.
4. Do not change condition bucketing thresholds or Repair/Restore research mechanics.
5. Do not touch auction NPC estimate logic — it has its own independent valuation path.

## Acceptance Criteria

1. Every place that previously resolved an item's transaction price now goes through the single `item_price` property, which equals `(appraised or verified value) × condition_multiplier`.
2. No code references the market factor autoload, category price factors, or knowledge rank bonus.
3. Old selling-channel price helpers (merchant offer, special order price) are removed or stubbed out, and their UI callers no longer invoke them.
4. Condition multiplier continues to function identically — items at low condition still show reduced prices, and Repair/Restore still improves condition as before.
5. Estimated value range display still narrows with inspection progress and collapses to exact value when all surface clues are revealed.
6. The project loads, runs, and passes any existing automated checks without regression.
