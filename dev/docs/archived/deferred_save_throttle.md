# Deferred Save Throttle

Introduce a two-tier save strategy — **Transaction Save** (immediate disk write at irreversible commit points) and **Deferred Save** (dirty-flag + throttled flush for frequent low-stakes mutations) — to reduce redundant file IO without risking data loss.

## Context

SaveManager currently writes a new `save_N.json` on every mutation (14 call sites). A player doing 5 repairs in a row generates 5 JSON files in rapid succession. The existing invariant ("save once per transaction") is correct in spirit but treats every mutation as equally critical. In practice, some mutations are irreversible transitions (run resolution, customer sale, day end) while others are recoverable micro-actions (repair, restore, research, car toggle).

## Design

### New SaveManager state

- `_dirty: bool` — at least one store has been mutated since the last disk write.
- `_elapsed: float` — seconds since dirty flag was set.
- `THROTTLE_SEC: float` — deferred flush interval (2.0 seconds, tunable).

### New SaveManager API

- `mark_dirty()` — sets `_dirty = true` and starts the throttle clock. Only resets `_elapsed` on the clean→dirty transition (i.e. when `_dirty` was false); subsequent calls while already dirty are no-ops on the timer. This makes it a true throttle — the flush fires at most `THROTTLE_SEC` after the *first* mutation, regardless of how many follow. Called by managers after deferred mutations.
- `flush()` — if `_dirty`, calls `save()`. Idempotent when clean.
- `save()` — existing method, now also clears `_dirty` and `_elapsed` on entry, before the write. This is the **Transaction Save** path — it persists all state including any pending deferred changes, so no deferred flush fires redundantly after a transaction save.

### Throttle in `_process`

SaveManager gains a `_process(delta)` that does nothing when `_dirty == false`. When dirty, it accumulates `_elapsed += delta` and calls `flush()` once `_elapsed >= THROTTLE_SEC`. Zero cost when clean.

### Scene-transition flush

SceneRouter gains a private `_navigate(scene: PackedScene)` helper. Every `go_to_*` method calls `_navigate` instead of `get_tree().change_scene_to_packed()` directly. `_navigate` calls `SaveManager.flush()` before the scene change, catching any pending deferred state. `go_to_day_summary` stores the payload then calls `_navigate`.

### Quit-safety flush

SaveManager adds `_notification(NOTIFICATION_WM_CLOSE_REQUEST)` that calls `flush()`. Godot fires this before engine shutdown on Alt-F4 / window close.

### Call-site classification

Transaction Save — `SaveManager.save()` (irreversible transitions):

- `resolve_run` — run completion, cargo registered, economics applied
- `end_day` — day advanced, costs deducted, slot reset
- `resolve_customer_sale` — items permanently sold, cash earned
- `begin_auction` — commits morning + afternoon slots to run
- `begin_open_shop` — customers generated, slot consumed
- `buy_car` — cash spent, car acquired
- `upgrade_attribute` — cross-domain cash + knowledge, infrequent

Deferred Save — `SaveManager.mark_dirty()` (recoverable micro-actions):

- `repair_item` — incremental AP action, repeatable
- `restore_item` — incremental AP action, repeatable
- `research_item` — incremental AP action, repeatable
- `set_active_car` — trivial toggle, flushed on scene exit
- `unlock_perk` — small state change during mastery interaction
- `begin_storage_slot` — slot increment, flushed on next scene transition
- `register_storage_items` — only called standalone; `resolve_run` already transaction-saves after registering entries directly via `storage.register_entries()`

### Race condition: non-issue

GDScript is single-threaded; `save()` is synchronous (FileAccess open → write → close). No interleaving is possible. A transaction save while `_dirty == true` is safe because `save()` clears the dirty flag before writing, preventing a redundant deferred flush.

## Implementation steps

1. Add `_dirty`, `_elapsed`, `THROTTLE_SEC` to SaveManager. Add `mark_dirty()` and `flush()`. Modify `save()` to clear dirty state on entry. Add `_process` throttle. Add `_notification` quit hook.
2. Extract `_navigate(scene)` in SceneRouter with `SaveManager.flush()` call. Update all `go_to_*` methods.
3. Reclassify call sites: change the 7 deferred methods in MetaManager and KnowledgeManager from `SaveManager.save()` to `SaveManager.mark_dirty()`. Leave the 7 transaction methods unchanged.
4. Update `dev/docs/systems/autoloads.md` invariant wording to reflect the two-tier model.

## Acceptance criteria

- Spamming repair/restore/research produces at most one save file per throttle interval, not one per click.
- Every transaction-save call site still writes to disk immediately.
- Quitting mid-storage (with pending deferred changes) produces a valid save file.
- Scene transitions flush deferred state before the new scene loads.
- No behavioral change from the player's perspective — state is never lost.
