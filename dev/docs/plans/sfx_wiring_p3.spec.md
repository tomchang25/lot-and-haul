# SFX Pipeline: Phase 3 — Wiring

## Goal

Wire the generated sound set into the game: a global click binder that connects every button to a shared click event on scene change (with per-button opt-out), explicit `AudioManager.play_event()` calls at each semantic interaction point (bid confirm, auction won/lost, reveal, sale, cash credited, error), and rate-limited reveal playback so the hub-return batch auto-reveal doesn't machine-gun.

## Relational Context

- **Button wiring is zero-per-scene.** The click binder is a single autoload that connects to `SceneRouter.scene_changed` (a new signal), walks the new scene's tree once, and wires every `Button` to `AudioManager.play_event(click_event)`. Scenes need no per-scene `_ready()` click wiring. This is the opposite of the existing pattern where every scene manually connects its buttons in `_ready()` — the binder replaces that per-scene boilerplate for click audio only.
- **Semantic sounds are explicit calls at interaction points.** Each call site loads its event resource (via `preload` or `load`) and calls `AudioManager.play_event(event_resource)`. This follows the existing `# TODO: play confirm sound via AudioManager` pattern already present at `auction_scene.gd:185` — the spec completes those TODOs.
- **`SceneRouter._navigate()`** (`global/autoloads/scene_router/scene_router.gd:107-109`) calls `SaveManager.flush()` then `get_tree().change_scene_to_packed(scene)`. The new `scene_changed` signal is emitted after `change_scene_to_packed` returns — by then the new scene is the current scene and `get_tree().current_scene` is valid.
- **`AudioManager.play_event()`** (`global/autoloads/audio_manager/audio_manager.gd:145`) is the single entry point for all event playback. It dispatches by type — for `UiAudioEvent`, it applies rate-limiting via `_is_rate_limited()` before calling `play_ui()`. Semantic call sites pass `Vector2.ZERO` for `world_pos` (all sounds in scope are non-positional UI sounds).
- **Button opt-out via meta field.** A button with `set_meta("sfx_click_ignore", true)` is skipped by the binder. This prevents double-triggering: buttons that fire their own semantic sound (e.g. bid confirm button) set the meta to avoid playing both click and bid_confirm.
- **The generated audio event `.tres` files** live at `data/tres/audio_events/<sound_id>.tres`. Wiring code loads them by path: `preload("res://data/tres/audio_events/click.tres")`. These are generated artifacts (`.gitignored`) — the preload path is stable because the filename matches the `sound_id` in the YAML.
- **Reveal sounds use a shared limiter key** (`"reveal"`) defined in the generated `.tres` metadata. The hub-return batch auto-reveal (`reveal_scene.gd:_on_reveal_pressed()`) loops over all won items and calls `RunManager.auto_reveal_all_surface(entry)` which may fire multiple clue reveals. Each reveal that plays a sound goes through `AudioManager.play_event()` which consults the limiter — so the batch reveal naturally plays only ~4 overlapping sounds instead of a burst of 20.

## Plan Friction

- Settled: No friction found between Plan and codebase. All touched files exist, all interaction points identified, and the audio system is fully implemented but unconnected.

## Design Gaps

- Settled: **Where to add `scene_changed` signal.** In `SceneRouter` (`global/autoloads/scene_router/scene_router.gd`): add `signal scene_changed` at the top, emit it in `_navigate()` after `change_scene_to_packed()`. The scene tree is fully loaded at that point (Godot's `change_scene_to_packed` is synchronous), so `get_tree().current_scene` is valid for the binder's tree walk.
- Settled: **Click binder placement.** A new file `global/autoloads/audio_manager/click_binder.gd` — kept near `audio_manager.gd` since it depends on it. Registered as autoload `ClickBinder` in `project.godot` after `AudioManager` (load order must ensure `AudioManager` is ready before the binder tries to play sounds).
- Settled: **One variant vs. all variants.** The binder loads the click event once and reuses it — `AudioEvent.pick_stream()` handles random variant selection with `avoid_repeat` internally. No per-click variant logic needed.
- Settled: **Reveal sound call site.** In `reveal_scene.gd:_on_reveal_pressed()`, play the `reveal_good` sound for each item. The rate limiter on the event resource caps the actual playback. For `_do_unveil()` and `_do_clue_chain()` in `inspection_scene.gd`: on success (unveil or clue succeeded), play `reveal_good`; on failure (clue failed), play `reveal_bad`.
- Settled: **Blocked/error sound call sites.** Not every `push_warning` or `ToastManager.show_error` gets a sound — only user-facing blocked actions: insufficient AP (inspection scene), can't bid (bid button disabled), can't sell with empty car. These are gated at the interaction point where the user action is rejected, not at the error display.
- Settled: **Cash credited sound call sites.** Play when `run_review_scene.gd:_resolve_run_and_navigate()` calls `MetaManager.resolve_current_run()` (cash credited via run economics) and when `customer_sell_scene.gd:_on_sell_confirmed()` calls `MetaManager.resolve_customer_sale()` (customer sale cash). The `cash_credited` event has its own limiter key so rapid-fire calls don't overlap.
- Settled: **button_hover, generic confirm, cancel_dismiss exist as assets but are unwired in v1.** Phase 2 produced them but Phase 3 wiring scope is limited to the original 9 interaction sounds. These three are available for future binding passes.
- Settled: **Hover sounds are explicitly excluded from the ClickBinder.** The binder wires `pressed` only. Adding `mouse_entered`/`mouse_exited` would require per-button cooldown logic (to avoid machine-gunning on list navigation) and a separate opt-out meta — not worth the complexity for placeholder tier. If hover feedback is needed later, it gets its own binder pass.
- Settled: **Generic `confirm` sound is not wired by the ClickBinder.** The binder plays the shared `click` event for all buttons. Using `confirm` for OK/action buttons would require per-button classification (e.g. a new meta `sfx_sound_override = &"confirm"`) — out of scope for v1. Only `bid_confirm` (auction-specific) is wired at its semantic call site.
- Settled: **`cancel_dismiss` has no call site in v1.** No back/navigate-away or "No"/"Cancel" button is wired in the current scene set. The sound exists for future use when those call sites are added.

## Scope

### Included

- `scene_changed` signal on `SceneRouter`, emitted after each scene transition.
- `ClickBinder` autoload: connects to `SceneRouter.scene_changed`, walks the scene tree, connects `pressed` on every `Button` without `sfx_click_ignore` meta, plays the shared click event.
- Semantic sound call sites:
  - `auction_scene.gd:_on_bid_pressed()` — play `bid_confirm`
  - `auction_scene.gd:_resolve()` player-won path — play `auction_won`
  - `reveal_scene.gd:_show_auction_lost_state()` — play `auction_lost`
  - `reveal_scene.gd:_on_reveal_pressed()` — play `reveal_good` per item (rate-limited by event)
  - `inspection_scene.gd:_do_unveil()` — play `reveal_good`
  - `inspection_scene.gd:_do_clue_chain()` — play `reveal_good` on success, `reveal_bad` on failure
  - `customer_sell_scene.gd:_on_sell_confirmed()` — play `sale_completed` then `cash_credited`
  - `run_review_scene.gd:_resolve_run_and_navigate()` — play `cash_credited`
  - `day_summary_scene.gd:_render()` — play `cash_credited` when net change is positive
  - Blocked-action points (insufficient AP, disabled bid, empty sell car) — play `blocked_error`
- Opt-out meta on buttons that already have semantic sounds (bid button, reveal button).
- Autoload registration for `ClickBinder` in `project.godot`.

### Excluded

- No music playback wiring (music is out of scope for this pipeline).
- No positional/2D audio.
- No changes to the audio system itself — only consuming its existing API.
- No new UI elements for sound volume/control — the bus layout handles that.
- No sound for the `start_page` scene (menu buttons are low-priority and can be added later).
- `button_hover` is not wired — the ClickBinder only connects `pressed`, not `mouse_entered`/`mouse_exited`.
- `cancel_dismiss` is not wired — no back/cancel call site exists in the current scene set.
- Generic `confirm` is not wired — the ClickBinder plays the shared `click` event for all buttons; `confirm` is reserved for future per-button override use.

## Files to Change

| File | Change Size | Purpose |
| --- | --- | --- |
| `global/autoloads/scene_router/scene_router.gd` | Small | Add `signal scene_changed`, emit after `change_scene_to_packed()` |
| `global/autoloads/audio_manager/click_binder.gd` | Medium | New autoload: walks scene tree, binds button clicks to shared click event |
| `project.godot` | Small | Register `ClickBinder` autoload after `AudioManager` |
| `game/run/auction/auction_scene.gd` | Medium | Add `bid_confirm` sound on bid, `auction_won` on resolve win; mark bid button `sfx_click_ignore` |
| `game/run/reveal/reveal_scene.gd` | Medium | Add `reveal_good` on batch reveal, `auction_lost` on lost state; mark reveal/continue buttons |
| `game/run/inspection/inspection_scene.gd` | Medium | Add `reveal_good` on unveil, `reveal_good`/`reveal_bad` on clue chain success/failure |
| `game/run/run_review/run_review_scene.gd` | Small | Add `cash_credited` on run resolution |
| `game/meta/customer_sell/customer_sell_scene.gd` | Small | Add `sale_completed` then `cash_credited` on sale confirm |
| `game/meta/day_summary/day_summary_scene.gd` | Small | Add `cash_credited` on positive net |
| `game/run/cargo/cargo_scene.gd` | Small | Add `blocked_error` on weight-limit violation |
| `game/run/inspection/inspection_scene.gd` | Small | Add `blocked_error` on insufficient AP |

## Implementation Notes

### ClickBinder autoload

```gdscript
# click_binder.gd
# Autoload: walks the active scene on every transition and binds button clicks
# to a shared UiAudioEvent. Buttons with meta sfx_click_ignore = true are skipped.
extends Node

const CLICK_EVENT: UiAudioEvent = preload("res://data/tres/audio_events/click.tres")


func _ready() -> void:
    SceneRouter.scene_changed.connect(_on_scene_changed)


func _on_scene_changed() -> void:
    var scene := get_tree().current_scene
    if scene == null:
        return
    _walk(scene)


func _walk(node: Node) -> void:
    if node is Button:
        var btn: Button = node as Button
        if not btn.has_meta("sfx_click_ignore") or not btn.get_meta("sfx_click_ignore"):
            if not btn.pressed.is_connected(_on_click):
                btn.pressed.connect(_on_click)
    for child: Node in node.get_children():
        _walk(child)


func _on_click() -> void:
    AudioManager.play_event(CLICK_EVENT)
```

Key constraints:
- Must be idempotent — if `_on_scene_changed` fires twice, it must not double-connect. The `is_connected` guard handles this.
- Must not connect buttons that already have `sfx_click_ignore` meta (set per semantic call site).
- The `CLICK_EVENT` is a constant `preload` — the `.tres` must exist at compile time. Since generated `.tres` files are in `.gitignore`, this preload will fail on a fresh clone. This is consistent with the existing project convention (all generated `.tres` under `data/tres/` are gitignored and must be generated before running). The build automation draft item covers this bootstrap gap.

### SceneRouter signal

Add to `scene_router.gd`:
- Line ~5: `signal scene_changed`
- End of `_navigate()`, after `change_scene_to_packed()`: `scene_changed.emit()`

### Semantic sound call sites

Each call site follows this pattern:
```gdscript
const SOUND := preload("res://data/tres/audio_events/<name>.tres")
# ...
AudioManager.play_event(SOUND)
```

For sounds with rate-limiting (reveal), the limiter is built into the event resource — the call site just calls `play_event` naturally.

**auction_scene.gd** (`game/run/auction/auction_scene.gd`):
- Add `const BID_CONFIRM := preload("res://data/tres/audio_events/bid_confirm.tres")` and `const AUCTION_WON := preload("res://data/tres/audio_events/auction_won.tres")` at top.
- `_on_bid_pressed()` at line 185: replace `# TODO: play confirm sound via AudioManager` with `AudioManager.play_event(BID_CONFIRM)`.
- `_resolve()` at line 306 (the `if _last_bidder == "player"` branch): add `AudioManager.play_event(AUCTION_WON)`.
- Set `_bid_button.set_meta("sfx_click_ignore", true)` in `_ready()` — the bid button plays `bid_confirm`, not the generic click.

**reveal_scene.gd** (`game/run/reveal/reveal_scene.gd`):
- Add `const REVEAL_GOOD := preload("res://data/tres/audio_events/reveal_good.tres")` and `const AUCTION_LOST := preload("res://data/tres/audio_events/auction_lost.tres")`.
- `_on_reveal_pressed()`: after the loop that reveals items, play `REVEAL_GOOD` once (the rate limiter inside the event resource handles the cap — but the loop fires `auto_reveal_all_surface` which reveals all clues silently; the single play here is the UI feedback for the batch complete). Actually, re-reading the plan: "Reveal sounds set a rate-limit key in their playback metadata; the audio singleton's existing per-key limiter then caps the hub-return batch auto-reveal to a few overlapping plays." This means each individual reveal should fire a sound, but the limiter caps it. So play `REVEAL_GOOD` inside the loop per item, or once with a slightly longer sound. Given the limiter, playing once per item is fine — only ~4 will actually play.
  - Implementation: inside the `for entry: ItemEntry in _won_items` loop, after `RunManager.auto_reveal_all_surface(entry)`, call `AudioManager.play_event(REVEAL_GOOD)`.
- `_show_auction_lost_state()`: add `AudioManager.play_event(AUCTION_LOST)`.
- Set `_reveal_btn` and `_continue_btn` with `sfx_click_ignore = true` — they already have a semantic reveal/lost sound playing at the action point.

**inspection_scene.gd** (`game/run/inspection/inspection_scene.gd`):
- Add `const REVEAL_GOOD := preload(...)` and `const REVEAL_BAD := preload(...)`.
- `_do_unveil(entry)`: add `AudioManager.play_event(REVEAL_GOOD)` after the item is unveiled.
- `_do_clue_chain(entry)`: inside the loop where `succeeded` is determined, play `REVEAL_GOOD` on success, `REVEAL_BAD` on failure.
- Blocked AP: at the early-return points (`if UNVEIL_COST > RunManager.lot.actions_remaining` and `if CLUE_CHAIN_COST > RunManager.lot.actions_remaining`), play `BLOCKED_ERROR` before returning.

**customer_sell_scene.gd** (`game/meta/customer_sell/customer_sell_scene.gd`):
- Add `const SALE_COMPLETED := preload(...)` and `const CASH_CREDITED := preload(...)`.
- `_on_sell_confirmed()`: after `MetaManager.resolve_customer_sale()` resolves (line ~404 area), play `SALE_COMPLETED`, then `CASH_CREDITED` after a short delay or immediately (the cash credited sound is short and positive). Using `call_deferred` for the second is fine but not required — two `play_event` calls in sequence will both play, the second overlapping the first's tail.

**run_review_scene.gd** (`game/run/run_review/run_review_scene.gd`):
- Add `const CASH_CREDITED := preload(...)`.
- `_resolve_run_and_navigate()`: after `MetaManager.resolve_current_run()`, play `CASH_CREDITED`.

**day_summary_scene.gd** (`game/meta/day_summary/day_summary_scene.gd`):
- Add `const CASH_CREDITED := preload(...)`.
- `_render(summary)`: after populating the net/balance labels, if `summary.net_change > 0`, play `CASH_CREDITED`.

**Blocked/error feedback points:**
- `cargo_scene.gd` (`game/run/cargo/cargo_scene.gd:449-451`): the weight limit exceeded error is shown via a label, but the user action (trying to place an over-weight item) is silently rejected. Add `BLOCKED_ERROR` play when `_grid.can_place()` returns false.
- `inspection_scene.gd` AP-check: the early returns at lines 223 and 229 already exist as silent returns. Add `BLOCKED_ERROR` before returning.

## Edge Cases

| Case | Expected Handling |
| --- | --- |
| Scene changes rapidly (double-navigate) | `ClickBinder._on_scene_changed` uses `is_connected` guard to prevent double-wiring. The scene tree from the first navigate is already gone when the second signal fires — no stale references |
| Button dynamically added after scene load (ephemeral node) | The per-frame/eventual walk doesn't cover it. Ephemeral buttons that need clicks must be handled explicitly (rare — the inspection grid's cell buttons are the main case; they are created in `_ready()` before the binder walks, but after the `ready` signal, so they ARE covered by the binder's first post-navigate walk). For truly-late-added buttons, the scene must wire them manually or the binder must also listen to `node_added` — not in scope for v1 |
| Preloaded `.tres` file missing (fresh clone) | Godot will error at parse time: "Cannot preload resource ...". This is the same failure mode as any other missing generated `.tres` in the project. The build automation bootstrap (separate draft item) addresses this |
| Button with `sfx_click_ignore` also connected to a semantic sound | No double-play — the binder skips it, and the semantic handler fires only its own sound |
| `reveal_good` played N times in a loop but rate-limited | The `UiAudioEvent` has `limiter_key = "reveal"`, `max_per_window = 4`, `window_sec = 0.3`. In a batch of 10 items, only ~4 will get through; the rest are silently dropped by `AudioManager._is_rate_limited()` |
| `change_scene_to_packed` returns ERR (scene load failure) | `_navigate()` does not check the return value currently. If it fails, `current_scene` is null and the binder's `_on_scene_changed` early-returns. No crash |

## Acceptance Criteria

1. Every button in every game scene plays the shared click sound when pressed, without any per-scene click wiring code.
2. A button with `set_meta("sfx_click_ignore", true)` does NOT play the click sound (verified on bid button, reveal button).
3. Placing a bid plays the bid_confirm sound, not the generic click.
4. Winning an auction plays the auction_won sound.
5. Losing an auction (reveal scene with no won items) plays the auction_lost sound.
6. Unveiling an item in inspection plays the reveal_good sound.
7. Succeeding on a clue chain roll plays reveal_good; failing plays reveal_bad.
8. Confirming a customer sale plays sale_completed then cash_credited.
9. Completing a run (run review continue) plays cash_credited.
10. Day summary with positive net change plays cash_credited.
11. Trying to inspect with insufficient AP plays blocked_error.
12. Batch auto-reveal in the reveal scene plays at most ~4 overlapping reveal sounds regardless of item count (verified by listening — the burst is audibly capped).
13. The ClickBinder autoload is registered in `project.godot` and does not error on boot (assuming generated `.tres` files exist).
