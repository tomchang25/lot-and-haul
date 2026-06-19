# script_director.gd
# Tutorial flow layer — owns which tutorial is active, the current step,
# wait conditions, cross-scene continuity, and seen marking.
# The presentation layer (Director) knows nothing about step order or
# wait conditions; it only renders the current step on demand.
extends Node

## True during any scripted sequence (tutorial or future scripted run).
var active: bool = false

## Current scripted-run phase, empty when inactive.
var phase: StringName = &""

# ── Flow state ────────────────────────────────────────────────────────────────

var _active_script_id: String = ""
var _active_script: Array[TutorialStep] = []
var _active_step_index: int = 0
var _is_active: bool = false
var _current_scene_id: String = ""
var _layout_retry_serial: int = 0


func _ready() -> void:
    Director.scene_registered.connect(_on_scene_registered)
    Director.offer_accepted.connect(_on_offer_accepted)
    Director.offer_skipped.connect(_on_offer_skipped)
    Director.advance_requested.connect(_on_advance_requested)
    Director.tutorial_closed.connect(_on_tutorial_closed)
    EventBus.save_runtime_reset.connect(reset_runtime)
    EventBus.tutorial_event.connect(_on_tutorial_event)

# ══ Public API (called by Director compatibility wrappers) ════════════════════


func start_script(script_id: String) -> void:
    _layout_retry_serial += 1
    var script: Array[TutorialStep] = TutorialScripts.resolve_script(script_id)
    if script.is_empty():
        ToastManager.show_dev_error("ScriptDirector.start_script: unknown script '%s'" % script_id)
        Director.hide_tutorial_overlay()
        _clear_state()
        return

    if _current_scene_id.is_empty():
        _current_scene_id = Director.current_scene_id

    var missing_anchors := TutorialScripts.validate_anchors(script_id, Director.get_anchors())
    if not missing_anchors.is_empty():
        ToastManager.show_dev_error(
            "ScriptDirector: script '%s' references unregistered anchors in scene '%s': %s"
            % [script_id, _current_scene_id, ", ".join(missing_anchors)],
        )

    _active_script = script
    _active_script_id = script_id
    _active_step_index = 0
    _is_active = true
    active = true
    _show_current_step()


func stop_script() -> void:
    if not _is_active:
        return
    var script_id := _active_script_id
    _mark_seen(script_id)
    _complete_onboarding_if_all_milestones_seen(script_id)
    Director.hide_tutorial_overlay()
    _clear_state()


## Marks every onboarding unit as seen, clears the pending flag, and stops
## any currently active script. Only callable from debug menu or explicit
## user action — never from the per-step X button.
func skip_all_onboarding() -> void:
    if _is_active:
        stop_script()
    for unit: TutorialScripts.TutorialUnit in TutorialScripts.units():
        if unit.id.begins_with("onboarding_"):
            MetaManager.mark_tutorial_seen(unit.id)
    MetaManager.skip_onboarding()


## Clears runtime-only tutorial flow state without marking anything seen.
## Save-slot reset/load creates new persistent ProgressStore state, so active
## tutorial flow from the prior slot must be discarded separately.
func reset_runtime() -> void:
    Director.reset_tutorial_presentation()
    _current_scene_id = ""
    phase = &""
    _clear_state()


func step_index() -> int:
    return _active_step_index


func step_count() -> int:
    return _active_script.size()


func step_anchor_id(idx: int) -> String:
    if idx < 0 or idx >= _active_script.size():
        return ""
    return _active_script[idx].anchor_id

# ══ Director signal handlers ══════════════════════════════════════════════════


func _on_scene_registered(scene_id: String) -> void:
    _current_scene_id = scene_id

    if not _is_active:
        _decide_tutorial_for_scene(scene_id)
        return

    # Cross-scene continuation: check if current step waits on this scene.
    var step: TutorialStep = _current_step()
    if step == null:
        return

    if step.advance == TutorialStep.Advance.SCENE_ENTERED:
        if step.advance_scene_id.is_empty() or step.advance_scene_id == scene_id:
            _advance_step()
        return

    # Re-evaluate anchor availability for the new scene and re-render if possible.
    # Scene registration must not skip NEXT steps; only explicit advancement does that.
    _show_current_step(true, false)


func _on_offer_accepted(script_id: String) -> void:
    start_script(script_id)


func _on_offer_skipped(_script_id: String) -> void:
    pass


func _on_advance_requested() -> void:
    if not _is_active:
        return
    var step: TutorialStep = _current_step()
    if step == null:
        return
    if step.advance == TutorialStep.Advance.NEXT:
        _advance_step()


func _on_tutorial_closed() -> void:
    stop_script()

# ══ Event bus handler ═════════════════════════════════════════════════════════


func _on_tutorial_event(event_id: StringName, _payload: Dictionary) -> void:
    if not _is_active:
        return
    var step: TutorialStep = _current_step()
    if step == null:
        return
    if step.advance == TutorialStep.Advance.EVENT and step.advance_event_id == event_id:
        _advance_step()

# ══ Internal ═══════════════════════════════════════════════════════════════════


func _current_step() -> TutorialStep:
    if not _is_active or _active_step_index >= _active_script.size():
        return null
    return _active_script[_active_step_index]


func _advance_step() -> void:
    _active_step_index += 1
    _show_current_step()


func _show_current_step(allow_layout_retry: bool = true, allow_next_skip: bool = true) -> void:
    if not _is_active:
        return

    # Do not skip SCENE_ENTERED steps — they wait for a future scene.
    # Do not skip EVENT steps — they wait for a gameplay event.
    # Only skip NEXT steps whose anchors are unresolvable (old static-tutorial
    # behavior).
    if allow_next_skip:
        _skip_non_renderable_next_steps()

    if _active_step_index >= _active_script.size():
        _end_tutorial()
        return

    var step: TutorialStep = _active_script[_active_step_index]
    if step.kind != TutorialStep.Kind.POPUP and not step.anchor_id.is_empty() and Director.resolve_target(step).is_empty():
        Director.hide_tutorial_overlay()
        if step.advance in [TutorialStep.Advance.SCENE_ENTERED, TutorialStep.Advance.EVENT] and allow_layout_retry:
            _request_layout_retry(_active_script_id, _active_step_index)
        return
    Director.render_step(step)


func _request_layout_retry(script_id: String, step_idx: int) -> void:
    _layout_retry_serial += 1
    _retry_current_step_after_layout.call_deferred(script_id, step_idx, _layout_retry_serial)


func _retry_current_step_after_layout(script_id: String, step_idx: int, serial: int) -> void:
    await get_tree().process_frame
    if serial != _layout_retry_serial:
        return
    if not _is_active or _active_script_id != script_id or _active_step_index != step_idx:
        return
    _show_current_step(false, false)


## Skips NEXT steps whose anchors cannot be resolved in the current scene.
## This preserves the old static-tutorial auto-skip behavior for steps that
## should never have been reached without their anchor being present.
func _skip_non_renderable_next_steps() -> void:
    while _active_step_index < _active_script.size():
        var step: TutorialStep = _active_script[_active_step_index]
        if step.advance != TutorialStep.Advance.NEXT:
            return
        if step.kind == TutorialStep.Kind.POPUP:
            return
        if not step.anchor_id.is_empty():
            if not Director.resolve_target(step).is_empty():
                return
        else:
            return
        ToastManager.show_dev_error(
            "ScriptDirector: Skipping step %d: all targets non-renderable in scene '%s'"
            % [_active_step_index, _current_scene_id],
        )
        _active_step_index += 1


func _end_tutorial() -> void:
    var completed_id := _active_script_id
    _mark_seen(completed_id)
    _complete_onboarding_if_all_milestones_seen(completed_id)
    Director.hide_tutorial_overlay()
    _clear_state()
    Director.notify_script_completed(completed_id)


func _mark_seen(script_id: String) -> void:
    if script_id.is_empty():
        return
    MetaManager.mark_tutorial_seen(script_id)


func _clear_state() -> void:
    _layout_retry_serial += 1
    _active_script = []
    _active_step_index = 0
    _active_script_id = ""
    _is_active = false
    active = false

# ══ Scene registration decision (for non-active state) ════════════════════════


func _decide_tutorial_for_scene(scene_id: String) -> void:
    var ctx := _build_trigger_context()
    for unit: TutorialScripts.TutorialUnit in TutorialScripts.units():
        if not _should_consider_unit(unit):
            continue
        if not unit.trigger.call(scene_id, ctx):
            continue
        start_script(unit.id)
        return

    # When onboarding is still pending, do not fall through to legacy offers.
    if MetaManager.is_onboarding_pending():
        return
    match scene_id:
        "hub":
            _on_hub_registered()
        "storage":
            _on_storage_registered()
        _:
            pass


func _build_trigger_context() -> Dictionary:
    return {
        "day": MetaManager.progress.current_day,
        "slot": MetaManager.slot.current_slot,
        "onboarding_pending": MetaManager.is_onboarding_pending(),
        "is_run_active": RunManager.is_run_active(),
        "first_tutorial_run": _is_first_tutorial_run_context(),
        "storage_item_count": MetaManager.storage.storage_items.size(),
    }


func _is_first_tutorial_run_context() -> bool:
    return MetaManager.is_onboarding_pending() and MetaManager.progress.current_day == 0


func _should_consider_unit(unit: TutorialScripts.TutorialUnit) -> bool:
    if not unit.once:
        return true
    return not _is_unit_seen(unit.id)


## Legacy compatibility: if the old monolithic `onboarding_auction_run` is in the
## seen set, treat every new run-phase milestone as seen so existing saves do
## not re-trigger the split run tutorial.
func _is_unit_seen(unit_id: String) -> bool:
    if MetaManager.progress.tutorial_seen.has(unit_id):
        return true
    if unit_id in _run_milestone_unit_ids() and MetaManager.progress.tutorial_seen.has("onboarding_auction_run"):
        return true
    return false


func _run_milestone_unit_ids() -> Array[String]:
    return TutorialScripts.run_milestone_unit_ids()


## Checks whether onboarding should complete. Two paths:
## 1. The script that just ended is `onboarding_selling` — always complete.
## 2. Every required onboarding milestone is seen — complete.
func _complete_onboarding_if_all_milestones_seen(script_id: String) -> void:
    if not MetaManager.is_onboarding_pending():
        return
    if script_id == "onboarding_selling":
        MetaManager.complete_onboarding()
        return
    for unit_id: String in TutorialScripts.required_onboarding_unit_ids():
        if not _is_unit_seen(unit_id):
            return
    MetaManager.complete_onboarding()


func _on_hub_registered() -> void:
    # Show completion popup once after onboarding is fully finished.
    if not MetaManager.is_onboarding_pending() and _has_seen_onboarding_segment():
        if not MetaManager.progress.tutorial_seen.has("onboarding_complete"):
            start_script("onboarding_complete")
        return

    if _has_seen_onboarding_segment():
        return
    if MetaManager.progress.tutorial_seen.has("hub"):
        return
    start_script("hub")


func _on_storage_registered() -> void:
    if _has_seen_onboarding_segment():
        return
    if MetaManager.progress.tutorial_seen.has("storage"):
        Director.show_help_button("storage")
        return
    if MetaManager.storage.storage_items.is_empty():
        return
    Director.show_offer_prompt(
        "storage",
        "Welcome to the Workshop!\n\nWould you like a quick tour of the features?",
        "Yes, show me around!",
    )


func _has_seen_onboarding_segment() -> bool:
    for script_id: String in MetaManager.progress.tutorial_seen.keys():
        if script_id.begins_with("onboarding_"):
            return true
    return false
