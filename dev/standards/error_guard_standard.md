# Error Guard Standard

`assert()` is stripped in release exports, turning guards into silent null-pointer crashes. Every precondition check must use an explicit `if` guard that survives in all build configurations.

---

# 1. Why Not `assert()`

In a Godot release export, `assert(condition, message)` compiles to nothing. The following code:

```gdscript
assert(RunManager.lot != null, "lot is null")
_run_auction_logic(RunManager.lot)
```

…becomes a bare null-dereference crash with no context. The player sees a frozen screen or a sudden exit — no log, no error toast, no safe fallback.

The replacement is an explicit `if` guard:

```gdscript
if RunManager.lot == null:
    ToastManager.show_dev_error("AuctionScene: RunManager.lot is null")
    handle_failure()
    return
```

---

# 2. Three Guard Categories

| Category             | Who sees it | Toast channel                                 | Fallback                          |
| -------------------- | ----------- | --------------------------------------------- | --------------------------------- |
| **Runtime guard**    | Player      | `ToastManager.show_error()` (always)          | Navigate to safe scene            |
| **Programmer error** | Developer   | `ToastManager.show_dev_error()` (debug-gated) | `return` / `return safe sentinel` |
| **Recovery warning** | Player      | `ToastManager.show_warning()` (always)        | Continue with the recovered state |

Both error channels write to the error log via `push_error` internally, so every error — runtime or programmer — leaves a trail in release exports that a player can report. Call sites never call `push_error` or `push_warning` themselves (see §3).

## 2a. Runtime Guard

A condition that can fail due to scene-flow bugs, state desync, or edge-case navigation. The player might encounter this and needs a visible recovery path.

```gdscript
## In _ready() of a scene that depends on RunManager.lot:
func _ready() -> void:
    if RunManager.lot == null:
        ToastManager.show_error("Inspection scene failed to load. Returning to hub.")
        SceneRouter.go_to_hub.call_deferred()
        return
    # ... normal setup ...
```

Key points:

- **`ToastManager.show_error()`** always — the player-facing message. This is the only call needed; it writes to the error log via `push_error` internally, so do **not** add a separate `push_error()`.
- **Context in the message** — the log's reported location points at ToastManager, not the guard, so the message must carry the system/operation itself (`"Inspection scene failed to load…"`, not `"failed to load"`).
- **Navigate to a safe scene** (hub, start page) — not just `return` into a broken state.

## 2b. Programmer Error

A condition that signals a bug in the codebase itself — including violated preconditions (bad arguments, broken invariants). Should never fire in a correct build. The message is internal-facing and only surfaced to the screen when `Debug.enabled` is true.

The canonical pattern is a single call to `ToastManager.show_dev_error()`:

```gdscript
func register_provider(provider: Object) -> void:
    if not provider.has_method("to_dict"):
        ToastManager.show_dev_error("register_provider: %s missing to_dict()" % provider)
        return
    # ... register ...
```

The helper:

- **Always writes `push_error()`** with a `[DEV] ` prefix — so it reaches the log file even in release, and player-reported logs distinguish codebase bugs (`[DEV]`) from runtime/data errors at a glance.
- **Shows a red error toast only when `Debug.enabled`** — devs see it immediately during playtesting; players never see the internal detail.
- **Dedupes toasts fire-once per session** — a guard sitting in a per-frame or loop path produces at most one toast per unique message string, while every occurrence still reaches the error log.

For consistency, the message in the call is the same internal detail that would have appeared in `push_error` — no separate player-facing wrapper. Add contextual hints (function name, received value) directly in the argument.

- **Abort, don't navigate** — `return` for `void` functions; when the function has a return type callers depend on, return a safe sentinel (`false`, `[]`, `RunResult.new()`, etc.) so the caller's error-handling path triggers:

```gdscript
## Deducts [param amount] from cash. Guards against negative input.
func spend(amount: int) -> bool:
    if amount < 0:
        ToastManager.show_dev_error("spend() expects non-negative amount, got %d" % amount)
        return false
    # ... spend logic ...
```

**Fire-once for high-frequency paths**: use the same helper — `show_dev_error` includes built-in fire-once dedupe. No manual member flag needed:

```gdscript
func _process(_delta: float) -> void:
    if RunManager.lot == null:
        ToastManager.show_dev_error("CargoScene: RunManager.lot is null in _process")
        return
```

## 2c. Recovery Warning

The operation recovered, but with data loss or degradation the player must know about — e.g. the newest save file was corrupt and an older one was loaded, or entries were dropped during migration. Not a guard failure: execution continues with the recovered state, no navigation, no abort.

```gdscript
ToastManager.show_warning(
    "Loaded save_%d.json (newest file was corrupt). Skipped: %s" % [loaded_counter, ", ".join(skipped)],
)
```

**Save/load path exception — use the push model, not direct toasts.** Code running inside a store's `from_dict()` / `_apply_migrations()` must not call ToastManager directly; it appends to the `SaveLoadContext` threaded through the load, and SaveManager drains it once at the end:

- `ctx.warn(msg)` — player-facing data-loss summary → routed to `show_warning()` (always visible).
- `ctx.info(msg)` — debug-only migration/resolution detail → routed to `show_info()` (plus `push_warning` console parity).

This keeps load-time diagnostics batched and ordered instead of toasting mid-load from a dozen call sites.

---

# 3. ToastManager Channels

| Method                | Visibility | Color               | Logs                           | Use case                                                                 |
| --------------------- | ---------- | ------------------- | ------------------------------ | ------------------------------------------------------------------------ |
| `show_error(msg)`     | Always     | Red                 | `push_error`                   | Runtime guards (player-facing)                                           |
| `show_warning(msg)`   | Always     | Yellow              | —                              | Recovery warnings (corruption fallback, data loss)                       |
| `show_info(msg)`      | Debug only | Near-white          | —                              | Migration details, internal diagnostics                                  |
| `show_dev_error(msg)` | Debug only | Red (same as error) | `push_error` (`[DEV] ` prefix) | Programmer-error guards (one-call: log + gated toast + fire-once dedupe) |

Rule of thumb: use `show_dev_error` for programmer invariants and violated internal preconditions; use `show_error` for runtime failures the player can hit and recover from, such as a scene reached without required state. Programmer-error guards use `show_dev_error` — never gate a raw `show_error` call manually. Use `show_error` directly only for runtime guards (always visible, player-facing).

Never use `show_info` for error guards — it is reserved for migration/load diagnostics, and inside the save/load path it is reached via `ctx.info()`, never called directly.

## 3a. No Bare `push_error` / `push_warning` (lint-enforced)

All error logging flows through `show_error` / `show_dev_error` — both call `push_error` internally. A bare `push_error` at a call site is a violation: it either duplicates the toast channel's log or silently skips the toast the category requires. ToastManager itself is the single exempt file.

Similarly, warnings must use `ToastManager.show_warning()`. A bare `push_warning` at a call site is a violation, with exempt files:
- `toast_manager.gd` — the single home of the underlying `push_warning`.
- `save_load_context.gd` — uses `push_warning` for console parity in `ctx.info()`.

**Boot-phase exception.** `EventBus`, `SettingsStore`, and `Debug` load before the ToastManager autoload and cannot call it. A bare `push_error` / `push_warning` there must declare the exception with a `# push-error: boot` marker, trailing the call or on the comment line directly above:

```gdscript
push_error("SettingsStore: settings file corrupt, using defaults") # push-error: boot
```

The marker is only legitimate in code that can run before ToastManager exists — a reviewer can grep `push-error: boot` and judge each claim.

---

# 4. Summary

| When you need a guard…                         | Use this pattern                                                    |
| ---------------------------------------------- | ------------------------------------------------------------------- |
| Scene can't function (null state)              | `show_error(always)` + navigate away                                |
| Internal invariant / precondition broken (bug) | `ToastManager.show_dev_error(msg)` + `return` / safe sentinel       |
| …in a per-frame or loop path                   | same — `show_dev_error` handles fire-once dedupe automatically      |
| Recovered with data loss (player must know)    | `show_warning(always)` — via `ctx.warn()` inside the save/load path |
| Error before ToastManager loads (boot phase)   | bare `push_error` + `# push-error: boot` marker                     |
