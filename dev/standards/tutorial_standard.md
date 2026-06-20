# Tutorial Standard

This document defines the architecture and authoring rules for tutorial scripts, tutorial flow, tutorial anchors, and gameplay tutorial events.

Applies to:

- Tutorial infrastructure under `global/autoloads/director/`
- Tutorial script catalog entries in `TutorialScripts`
- Scene tutorial anchor registration via `Director.register_scene()` / `register_anchor()` / `unregister_anchor()`
- Gameplay tutorial milestone events emitted through `EventBus.tutorial_event`

Does not apply to:

- Non-tutorial UI hints, inline status labels, or scene-local feedback
- Global notifications, which belong to `ToastManager`
- Story scripting, branching narrative, or quest logic

---

# 1. Ownership Boundary

Tutorial infrastructure has three layers: presentation, flow, and gameplay overrides.

`Director` is the presentation layer. It owns overlay nodes, dimming, highlight holes, panel placement, offer prompts, Help button display, and anchor lookup. It must not own script order, current step index, wait conditions, tutorial completion, tutorial-seen persistence, or gameplay override state.

`ScriptDirector` is the flow layer. It owns the active tutorial id, active step list, current step index, wait-condition evaluation, cross-scene continuation, runtime reset, tutorial-seen marking, and the lifecycle of `GameplayOverride` (activating/deactivating unit-scoped overrides and refreshing onboarding-scoped overrides).

`GameplayOverride` is a runtime-only autoload that stores named gameplay overrides. The flow layer pushes overrides (which modifiers are active for the current tutorial unit or onboarding phase). Gameplay scenes read the override store and react to its change signal. The override store is cleared on save-slot reset.

Rules:

- Do not add step-order state to `Director`.
- Do not make gameplay scenes call `ScriptDirector` to advance tutorial steps, or to query tutorial flow state (active script id, step index, seen status).
- Do not make gameplay scenes call `Director` for gameplay-affecting overrides (assisted auction, locked sale, forced activity, and so on). Those live in `GameplayOverride` and are pushed by `ScriptDirector`, not pulled by scenes.
- Do not make gameplay systems reference tutorial copy, tutorial ids, or tutorial step indexes.
- Use `Director.start_script()` only as a compatibility facade or UI entry point; new orchestration logic belongs in `ScriptDirector`.
- If a caller needs a tutorial step to advance because a gameplay action happened, emit a tutorial event instead of calling tutorial flow directly.

---

# 2. Step Advance Kinds

Every `TutorialStep` has one advance kind.

| Kind            | Owner              | Completes when                                      |
| --------------- | ------------------ | --------------------------------------------------- |
| `NEXT`          | Player UI          | The player clicks the step's Next control.          |
| `SCENE_ENTERED` | Scene registration | A matching scene calls `Director.register_scene()`. |
| `EVENT`         | Gameplay event     | A matching semantic tutorial event is emitted.      |

Rules:

- `NEXT` steps must only advance from `Director.advance_requested` / `Director.advance_step()`.
- `SCENE_ENTERED` steps must set `advance_scene_id` when only one target scene is valid. Empty `advance_scene_id` means any scene registration may advance the step, so use it rarely.
- `EVENT` steps must set `advance_event_id` to a `TutorialEvents` constant.
- Do not use `NEXT` as a fake event when the player should perform a real gameplay action.
- Do not use `EVENT` for ordinary button navigation when scene entry is the real milestone.

Examples:

```gdscript
TutorialStep.hint(
        "Choose a location.",
        "cards_container",
).unlock().on_event(TutorialEvents.LOCATION_SELECTED)
```

```gdscript
TutorialStep.hint(
        "Go to Storage.",
        "storage_btn",
).unlock().on_scene("storage")
```

---

# 3. Script Catalog

Tutorial content lives in `TutorialScripts`. The catalog is the single surface for tutorial ids, step arrays, anchor ids, and advance conditions.

Rules:

- Add one static function per tutorial script, named `<script_id>_script()`.
- Add the script id to `resolve_script()`.
- Add the script id to `known_script_ids()`.
- Keep tutorial copy and step order out of `Director`, scenes, managers, and gameplay services.
- Code-authored catalog entries are acceptable. Do not add a resource or external data format unless a plan explicitly calls for it.
- Existing tutorial ids are save-relevant because `ProgressStore.tutorial_seen` stores ids. Rename tutorial ids only with an explicit migration plan.

Minimal new script checklist:

1. Add `<id>_script()` to `TutorialScripts`.
2. Add `<id>` to `resolve_script()`.
3. Add `<id>` to `known_script_ids()`.
4. Ensure every hint anchor id is registered by the relevant scene or transient popup.
5. Ensure every `EVENT` step has a corresponding `EventBus.tutorial_event.emit(...)` call.
6. Add or update unit tests for the trigger and advance behavior.

---

# 4. Scene Anchors

Scenes expose tutorial targets by registering anchors.

Persistent scene anchors use `Director.register_scene(scene_id, anchors)` in the scene root `_ready()` after the nodes exist and after early error guards have returned.

Transient anchors use `Director.register_anchor(id, anchor)` when opened and `Director.unregister_anchor(id)` when closed. Use this for popups, option choosers, or any UI that does not exist for the scene's full lifetime.

Rules:

- Anchor ids are semantic UI ids, not node paths.
- Anchor ids must be stable enough for tutorial scripts to reference.
- Register plain `Control` nodes for simple rectangular targets.
- Use `TutorialTarget` when the highlight rect needs a custom region or preferred placement side.
- Do not leave transient anchors registered after the UI closes.
- Do not treat a closed transient anchor as hidden-but-valid. It must be unregistered.

Example:

```gdscript
Director.register_scene("cargo", {
    "item_list": _item_list_vbox,
    "cargo_grid": _cargo_grid,
    "continue_btn": _continue_btn,
})
```

Transient example:

```gdscript
func _show_chooser() -> void:
    _chooser.show()
    Director.register_anchor("auction_btn", _auction_btn)


func _close_chooser() -> void:
    _chooser.hide()
    Director.unregister_anchor("auction_btn")
```

---

# 5. Tutorial Events

Gameplay systems emit semantic tutorial milestones through `EventBus.tutorial_event`.

Rules:

- Event ids live in `TutorialEvents` as `StringName` constants.
- Emit tutorial events after the gameplay action has successfully committed.
- Do not emit events before guards, confirmation dialogs, or failed transaction paths complete.
- Do not include tutorial script ids or step ids in gameplay event payloads.
- Payload is reserved for future filtering. Current flow should advance by event id only unless a plan explicitly adds payload filtering.
- Reuse existing semantic events when they describe the milestone. Add new constants only when the gameplay concept is genuinely new.

Example:

```gdscript
RunManager.commit_cargo(cargo, trailer, proceeds)
EventBus.tutorial_event.emit(TutorialEvents.CARGO_LOADED, {})
SceneRouter.go_to_run_review()
```

---

# 6. Triggering Tutorials

Automatic tutorial triggers belong in `ScriptDirector`, not in scenes.

Rules:

- Scene code should register anchors and emit gameplay tutorial events, not decide whether a tutorial should start.
- `ScriptDirector._decide_tutorial_for_scene(scene_id)` owns scene-entry tutorial offers and auto-starts.
- Tutorial-seen checks use `MetaManager.progress.tutorial_seen`.
- Tutorial completion or user close/skip marks the tutorial seen through `MetaManager.mark_tutorial_seen()`.
- Runtime reset must not mark tutorials seen.

Use explicit trigger conditions. Do not start a tutorial every time a scene registers unless it is guarded by a seen flag or a stronger progression condition.

---

# 7. Runtime Reset

Tutorial flow state is runtime-only. Save-slot reset/load creates fresh persistent state, but it does not automatically recreate autoload runtime state.

Rules:

- `SaveManager.reset_providers()` emits `EventBus.save_runtime_reset` after persistent providers reset.
- `ScriptDirector` subscribes to `save_runtime_reset` and calls `reset_runtime()`.
- Runtime reset clears active script id, step index, rendered overlay, offers, Help button state, anchors, and current scene id.
- Runtime reset must not call `MetaManager.mark_tutorial_seen()`.
- Do not have `SaveManager` look up tutorial nodes by root path or call tutorial methods directly. Save lifecycle notification is event-based.

---

# 8. Tests

Unit tests that intentionally trigger missing-anchor dev errors must include `[DEBUG-PASS]` in the scene id or error text path so error filters treat the push_error as expected.

Rules:

- Test `NEXT`, `SCENE_ENTERED`, and `EVENT` advance separately.
- Tests for missing-anchor skip behavior should expect dev errors and mark them with `[DEBUG-PASS]`.
- Tests for new-save behavior should verify runtime reset clears active flow without marking tutorials seen.
- Use synthetic scene ids in tests when the test should not trigger `ScriptDirector` auto-start rules.
- Use real scene ids in tests when validating `SCENE_ENTERED` advance.

---

# 9. Anti-Patterns

Do not write these shapes:

```gdscript
# Wrong: gameplay knows tutorial flow.
ScriptDirector.advance_to_step(4)
```

```gdscript
# Wrong: SaveManager reaches into tutorial singleton by path.
get_node_or_null("/root/ScriptDirector").reset_runtime()
```

```gdscript
# Wrong: tutorial copy in gameplay scene.
Director.show_popup("Now bid on the auction")
```

```gdscript
# Wrong: closed popup leaves stale anchor behind.
_chooser.hide()
# missing Director.unregister_anchor(...)
```

```gdscript
# Wrong: gameplay scene queries tutorial flow layer for state.
if Director.is_auction_assisted():
    _pass_button.disabled = true
```

```gdscript
# Wrong: gameplay scene connects to tutorial completion signal.
Director.script_completed.connect(_unlock_something)
```

Correct shapes:

```gdscript
EventBus.tutorial_event.emit(TutorialEvents.AUCTION_WON, {})
```

```gdscript
EventBus.save_runtime_reset.emit()
```

```gdscript
Director.register_anchor("storage_btn", _storage_btn)
Director.unregister_anchor("storage_btn")
```

```gdscript
# Correct: gameplay scene reads the override store.
if GameplayOverride.is_active(GameplayOverride.ASSISTED_AUCTION):
    _pass_button.disabled = true
```
