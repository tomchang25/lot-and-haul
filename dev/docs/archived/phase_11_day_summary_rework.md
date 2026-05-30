# Phase 11 — Day Summary Rework

## Goal

Surface nightly customer sales revenue in the day summary so the net change reflects actual cash flow (sales minus costs) instead of showing a perpetual loss, and skip the summary entirely on uneventful non-auction days.

## Relational Context

- `MetaManager.advance_days()` calls `_generate_nightly_customers()` which clears `SaveManager.customer_sales_today` — the sales data must be captured into `DaySummary` BEFORE this clear happens, not after.
- `MetaManager.resolve_run()` calls `advance_days()` internally — run-triggered advancement inherits whatever data capture pattern `advance_days()` uses.
- `GameManager._pending_day_summary` is the single hand-off point for the summary scene. `RunReviewScene._resolve_run_and_navigate()` currently discards the DaySummary returned by `resolve_run()` and goes directly to hub — post-run must now route through `go_to_day_summary()`.
- `DaySummary` is a `RefCounted` value object — it must own its customer sales data as native fields (not references to SaveManager arrays that may be cleared).
- Customer sales data schema (`day`, `customer_id`, `customer_name`, `strategy`, `item_count`, `item_ids`, `sale_price`) is already stable in `SaveManager.customer_sales_today`. Do not change this schema; only aggregate it into DaySummary.

## Scope

### Included

- Add `customer_sales_total`, `customer_sales_detail`, and `has_customer_sales()` to `DaySummary`
- Capture `SaveManager.customer_sales_today` into `DaySummary` fields before `_generate_nightly_customers()` clears it
- Update `net_change` computed property to include `customer_sales_total`
- Add CustomerSalesGroup UI section to `DaySummaryScene` showing count, total revenue, and strategy breakdown
- Reroute `RunReviewScene._resolve_run_and_navigate()` to show day summary after a run
- Skip the summary (go directly to hub) when there is no run data and no customer sales

### Excluded

- Weekly report or weekly summary system
- Game-over / fixed-deduction mechanics
- Time-slot day structure (Phase 12)
- Modifications to the customer sale data schema or `SaveManager.customer_sales_today`
- Item-level detail in the summary (item names/ids per sale)

## Files to Change

| File | Change Size | Purpose |
| --- | --- | --- |
| `common/gameplay/day_summary.gd` | Small | Add customer sales fields and computed total |
| `global/autoload/meta_manager.gd` | Small | Capture customer_sales_today into DaySummary before clear in advance_days |
| `game/meta/day_summary/day_summary_scene.gd` | Medium | Render customer sales section; add skip-to-hub logic when uneventful |
| `game/meta/day_summary/day_summary_scene.tscn` | Small | Add CustomerSalesGroup nodes to the layout |
| `game/run/run_review/run_review_scene.gd` | Small | Route through day summary instead of direct-to-hub |

## Implementation Notes

### DaySummary (`common/gameplay/day_summary.gd`)
- Add fields: `var customer_sales_total: int = 0` and `var customer_sales_detail: Array[Dictionary] = []`
- Add `func has_customer_sales() -> bool` returning `not customer_sales_detail.is_empty()`
- Update `net_change` getter to: `onsite_proceeds + customer_sales_total - paid_price - entry_fee - fuel_cost - living_cost`

### MetaManager (`global/autoload/meta_manager.gd`)
- In `advance_days()`, BEFORE the `_generate_nightly_customers()` call on line 49, capture sales data:
  ```gdscript
  for sale in SaveManager.customer_sales_today:
      summary.customer_sales_total += sale.sale_price
      summary.customer_sales_detail.append(sale.duplicate())
  ```
  (Use `duplicate()` so the summary owns independent copies, not references to the array about to be cleared.)
- Apply the same pattern inside `resolve_run()` if needed — but since it calls `advance_days()`, it inherits the capture automatically.

### DaySummaryScene (`game/meta/day_summary/`)
- Add node references for CustomerSalesGroup, `_customer_header`, `_customer_total_label`, `_customer_strategy_group`, `_conservative_label`, `_aggressive_label` (or a single line).
- In `_render()`: after the trip group and before the daily group, add a customer sales section visible only when `summary.has_customer_sales()`:
  ```
  Conservative: N items, $X total
  Aggressive: N items, $X total
  Total Customer Sales: $X
  ```
- In `_ready()`, after checking for null summary: if the summary has no run data AND no customer sales, skip directly to hub instead of rendering:
  ```gdscript
  if not summary.has_run_data() and not summary.has_customer_sales():
      GameManager.go_to_hub()
      return
  ```

### TSCN (`day_summary_scene.tscn`)
- Add a `CustomerSalesGroup` VBoxContainer after the TripGroup and before the DailyGroup, containing:
  - A gray header "Customer Sales"
  - Strategy breakdown labels (Conservative / Aggressive)

### RunReviewScene (`game/run/run_review/run_review_scene.gd`)
- Change `_resolve_run_and_navigate()` from:
  ```gdscript
  MetaManager.resolve_run(RunManager.run_record)
  GameManager.go_to_hub()
  ```
  To:
  ```gdscript
  var summary := MetaManager.resolve_run(RunManager.run_record)
  GameManager.go_to_day_summary(summary)
  ```

## Edge Cases

| Case | Expected Handling |
| --- | --- |
| Day pass on a day with no customer sales | Summary is skipped; player goes directly to hub |
| Day pass after selling items (has customer_sales_today) | Summary shows customer sales section; net includes sales revenue |
| Run with no customer sales (player didn't sell post-run) | Summary shows run data + living cost; customer sales section hidden |
| Run after selling items (sold in hub before next run) | Summary shows both run data and customer sales |
| Zero customer_sales_total but non-empty detail (if sale_price = 0) | Section still shows (0 items, $0) — edge case, but should still be visible |
| advance_days(0) | Returns early with empty summary, never reaches _generate_nightly_customers — customer_sales_today survives for the next real tick |

## Acceptance Criteria

1. Day summary shows a "Customer Sales" section with total revenue, item count, and strategy breakdown when `customer_sales_today` is non-empty.
2. Net change reflects customer sales revenue plus run income minus costs — no longer shows a loss on days with profitable selling.
3. Post-run flow routes through the day summary scene before returning to hub.
4. Pure day-pass with zero customer sales skips the summary and goes directly to hub.
5. `customer_sales_today` data is fully captured before the array is cleared in `_generate_nightly_customers()` — no data loss.
