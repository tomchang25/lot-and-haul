# LotStore Extraction

## Goal

Extract per-lot state from RunStore into a new session-scoped LotStore with its own lifecycle (created on lot entry, destroyed after reveal). RunStore retains per-run cumulative state. This separates two distinct lifetimes currently conflated in one container, reducing cognitive load and preventing stale-state bugs.

## Relational Context

- **RunManager** owns both `run: RunStore` (per-run) and `lot: LotStore` (per-lot, nullable). Both are public read-only properties. External code never mutates either Store directly — all mutation goes through RunManager methods.
- **RunManager → RunStore** is read-write: RunManager calls `draw_ap_from_reserve()` during lot creation and `accumulate_lot_result()` after auction.
- **RunManager → LotStore** is read-write: RunManager creates/nulls LotStore and delegates `deduct_ap()`.
- **LotStore does not reference RunStore.** The AP reserve draw is computed by RunManager and passed as a construction argument. LotStore has no upward dependency.
- **Scenes read lot state via `RunManager.lot.*`** (replacing `RunManager.run.lot_entry`, `RunManager.run.lot_items`, `RunManager.run.actions_remaining`, `RunManager.run.last_lot_won_items`). Scenes read run-level state via `RunManager.run.*` (unchanged for `inspection_ap_cap`, `browse_lots`, `browse_index`, `won_items`, etc.).
- **Scene mutation calls on RunManager are unchanged in signature**: `spend_ap()`, `commit_lot_win()`, `set_lot()`. Internal delegation changes but callers do not.
- **LotStore lifecycle**: created inside `RunManager.set_lot()`, consumed and nulled via `RunManager.clear_lot()` called by reveal_scene after reading results. The previous lot's LotStore is replaced when `set_lot()` is called for the next lot — no explicit clear between reveal and next browse.
- **`_last_lot_won_items` elimination**: LotStore holds `won_items` and `won_price` as lot-result fields, written by `record_win()`. reveal_scene reads `RunManager.lot.won_items`. The transitional `_last_lot_won_items` field on RunStore is removed — LotStore's lifetime naturally covers the reveal window.
- **StoreBase**: LotStore extends StoreBase (session-scoped, no save payload — same as RunStore).

## Scope

### Included

- New `LotStore` class (`common/gameplay/store/lot_store.gd`)
- RunStore field and method removal (per-lot state)
- RunStore new method `draw_ap_from_reserve()` for AP handoff
- RunStore new method `accumulate_lot_result()` for post-auction cumulation
- RunManager restructure: `var lot: LotStore`, updated factory/delegation
- Scene access path migration (`RunManager.run.lot_*` → `RunManager.lot.*`)

### Excluded

- Browse state (`_browse_lots`, `_browse_index`) stays in RunStore — it is per-run, not per-lot.
- `_inspection_ap_cap` and `_refill_metric` stay in RunStore — they are run-level AP pool parameters.
- No new signals or EventBus events.
- No changes to LotEntry, ItemEntry, or LotData.

## Files to Change

| File | Change Size | Purpose |
| --- | --- | --- |
| `common/gameplay/store/lot_store.gd` | Medium | New file: per-lot state container |
| `common/gameplay/store/run_store.gd` | Medium | Remove per-lot fields/methods, add `draw_ap_from_reserve()` and `accumulate_lot_result()` |
| `global/autoloads/managers/run_manager.gd` | Medium | Add `var lot`, restructure `set_lot()` / `commit_lot_win()` / `spend_ap()`, add `clear_lot()` |
| `game/run/inspection/inspection_scene.gd` | Small | `RunManager.run.lot_items` → `RunManager.lot.lot_items`, same for `actions_remaining`, `lot_entry` |
| `game/run/inspection/action_popup/lot_action_bar.gd` | Small | `RunManager.run.actions_remaining` → `RunManager.lot.actions_remaining` |
| `game/run/auction/auction_scene.gd` | Small | `RunManager.run.lot_entry` / `lot_items` → `RunManager.lot.*` |
| `game/run/reveal/reveal_scene.gd` | Small | `RunManager.run.last_lot_won_items` → `RunManager.lot.won_items` |
| `game/run/lot_browse/lot_browse_scene.gd` | Small | No access path changes (browse state stays in RunStore), but `RunManager.set_lot()` call is unchanged |

## Implementation Notes

**LotStore construction** — `LotStore.new()` takes `lot_entry: LotEntry` and `initial_ap: int`. No reference to RunStore or RunManager. The `initialize()` pattern matches RunStore: a separate method called immediately after `new()`, or a static factory — either is fine, but stay consistent with RunStore's pattern.

**AP handoff in `RunManager.set_lot()`** — the deficit-refill logic currently in `RunStore.set_lot()` moves to RunManager. Sequence: (1) compute deficit from `run.inspection_ap_cap - (lot.actions_remaining if lot else run.inspection_ap_cap)`, (2) call `run.draw_ap_from_reserve(deficit) -> int` which returns the actual take, (3) pass `initial_ap` to LotStore constructor. On the first lot of a run (no prior LotStore), deficit is 0 and initial AP equals the cap.

**First-lot edge case** — when `lot` is null (first lot of the run), there is no prior AP to measure deficit from. Initial AP for the first lot should equal `run.inspection_ap_cap` (full cap, no reserve draw needed). `draw_ap_from_reserve(0)` returns 0.

**`accumulate_lot_result()`** — called by `RunManager.commit_lot_win()` after writing to LotStore. Reads `lot.won_items` and `lot.won_price`, appends to `run._won_items` and adds to `run._paid_price`. This keeps cumulative tracking in RunStore.

**`_last_lot_won_items` removal** — reveal_scene currently reads `RunManager.run.last_lot_won_items`. After extraction, it reads `RunManager.lot.won_items` (the LotStore persists through reveal). The `_last_lot_won_items` field and its clear-on-set_lot logic are deleted entirely.

**Auction loss** — `commit_lot_win()` is not called on loss. LotStore's `won_items` stays empty. reveal_scene already handles the empty case (`_show_auction_lost_state`). LotStore survives through reveal regardless of win/loss.

## Edge Cases

| Case | Expected Handling |
| --- | --- |
| First lot of run (no prior LotStore) | Initial AP = full cap, no reserve draw |
| Auction loss | LotStore.won_items is empty; reveal shows loss state; LotStore still replaced on next `set_lot()` |
| `RunManager.lot` accessed between runs | Returns null; same guard pattern as `RunManager.run` |
| `clear_run_state()` called while lot is active | Nulls both `run` and `lot` |

## Acceptance Criteria

1. Per-lot state (`lot_entry`, `actions_remaining`, lot won items) lives in LotStore with a per-lot lifecycle, not in RunStore.
2. RunStore holds only per-run cumulative and configuration state.
3. All scenes read lot state through `RunManager.lot.*` and run state through `RunManager.run.*`.
4. AP deficit-refill at lot boundaries works identically to current behavior.
5. Reveal scene displays won items (or loss state) correctly, reading from LotStore.
6. Cumulative `won_items` and `paid_price` on RunStore accumulate correctly across multiple lots.
7. No regressions in the inspection → auction → reveal → lot_browse loop.
