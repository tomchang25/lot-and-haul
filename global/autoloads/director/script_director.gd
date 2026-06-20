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
var _active_unit_overrides: Array[StringName] = []


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
    _activate_unit_overrides(script_id)
    _show_current_step()


func stop_script() -> void:
    if not _is_active:
        return
    var script_id := _active_script_id
    _deactivate_unit_overrides()
    _mark_seen(script_id)
    _complete_onboarding_if_all_milestones_seen(script_id)
    _refresh_onboarding_overrides()
    Director.hide_tutorial_overlay()
    _clear_state()


## Cleans up an active tutorial without marking anything seen or modifying
## onboarding-pending state. Used when the player bypasses tutorials via the
## settings toggle or "Skip All" button, so toggling off later can re-trigger.
func dismiss_script() -> void:
    if not _is_active:
        return
    _deactivate_unit_overrides()
    Director.hide_tutorial_overlay()
    _clear_state()


## Public wrapper so Director can trigger an override refresh.
func refresh_overrides() -> void:
    _refresh_onboarding_overrides()


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
    _refresh_onboarding_overrides()


## Clears runtime-only tutorial flow state without marking anything seen.
## Save-slot reset/load creates new persistent ProgressStore state, so active
## tutorial flow from the prior slot must be discarded separately.
func reset_runtime() -> void:
    _deactivate_unit_overrides()
    GameplayOverride.clear_all()
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
    _refresh_onboarding_overrides()

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
    # Release any unit overrides that declared this event as their release point.
    var unit := _find_unit(_active_script_id)
    if unit != null:
        for spec in unit.overrides:
            if spec.release_event == event_id and GameplayOverride.is_active(spec.id):
                GameplayOverride.deactivate(spec.id)
                _active_unit_overrides.erase(spec.id)
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
    _deactivate_unit_overrides()
    _mark_seen(completed_id)
    _complete_onboarding_if_all_milestones_seen(completed_id)
    _refresh_onboarding_overrides()
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

# ══ Override helpers ═══════════════════════════════════════════════════════════


func _activate_unit_overrides(script_id: String) -> void:
    var unit := _find_unit(script_id)
    if unit == null:
        return
    for spec in unit.overrides:
        GameplayOverride.activate(spec.id, spec.payload)
        _active_unit_overrides.append(spec.id)


func _deactivate_unit_overrides() -> void:
    for id in _active_unit_overrides:
        GameplayOverride.deactivate(id)
    _active_unit_overrides.clear()


func _find_unit(script_id: String) -> TutorialScripts.TutorialUnit:
    for unit: TutorialScripts.TutorialUnit in TutorialScripts.units():
        if unit.id == script_id:
            return unit
    return null


## Recomputes onboarding-scoped overrides (forced activity, forced tutorial
## location, conservative sale lock) and pushes changes to the override store.
## Called on every scene registration and on onboarding completion.
func _refresh_onboarding_overrides() -> void:
    if not MetaManager.is_onboarding_pending():
        _clear_onboarding_overrides()
        return
    if SettingsStore.tutorial_skip_all:
        _clear_onboarding_overrides()
        return
    var ctx := _build_trigger_context()
    _set_onboarding_override(
        GameplayOverride.FORCED_TUTORIAL_LOCATION,
        _onboarding_forced_tutorial_location(ctx),
    )
    _set_onboarding_override(
        GameplayOverride.FORCED_ACTIVITY,
        _onboarding_forced_activity(ctx),
    )
    _set_onboarding_override(
        GameplayOverride.CONSERVATIVE_SALE_LOCKED,
        _onboarding_conservative_sale_locked(ctx),
    )


func _set_onboarding_override(id: StringName, payload: Variant) -> void:
    if payload == null:
        if GameplayOverride.is_active(id):
            GameplayOverride.deactivate(id)
        return
    if not GameplayOverride.is_active(id) or GameplayOverride.payload(id) != payload:
        GameplayOverride.activate(id, payload)


func _onboarding_forced_tutorial_location(ctx: Dictionary) -> Variant:
    if _is_unit_seen("onboarding_location_select"):
        return null
    if int(ctx.get("day", -1)) == 0 and int(ctx.get("slot", -1)) == SlotStore.SLOT_DAY:
        return true
    return null


func _onboarding_forced_activity(ctx: Dictionary) -> Variant:
    var day := int(ctx.get("day", -1))
    var slot := int(ctx.get("slot", -1))
    if day == 0 and slot == SlotStore.SLOT_DAY:
        if _is_unit_seen("onboarding_hub_intro_choose"):
            return null
        return &"auction"
    if day == 0 and slot == SlotStore.SLOT_NIGHT:
        if _is_unit_seen("onboarding_storage_choose"):
            return null
        return &"storage"
    if day == 1 and slot == SlotStore.SLOT_DAY:
        var storage_count := int(ctx.get("storage_item_count", 0))
        if storage_count > 0 and not _is_unit_seen("onboarding_shop_choose"):
            return &"selling"
    return null


func _onboarding_conservative_sale_locked(ctx: Dictionary) -> Variant:
    if _is_unit_seen("onboarding_selling"):
        return null
    return ctx.get("onboarding_pending", false)


func _clear_onboarding_overrides() -> void:
    for id in [
        GameplayOverride.FORCED_TUTORIAL_LOCATION,
        GameplayOverride.FORCED_ACTIVITY,
        GameplayOverride.CONSERVATIVE_SALE_LOCKED,
    ]:
        if GameplayOverride.is_active(id):
            GameplayOverride.deactivate(id)

# ══ Scene registration decision (for non-active state) ════════════════════════


func _decide_tutorial_for_scene(scene_id: String) -> void:
    if SettingsStore.tutorial_skip_all:
        return
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


func _is_unit_seen(unit_id: String) -> bool:
    return MetaManager.progress.tutorial_seen.has(unit_id)


## Checks whether onboarding should complete. Two paths:
## 1. The script that just ended is `onboarding_selling` — always complete.
## 2. Every required onboarding milestone is seen — complete.
func _complete_onboarding_if_all_milestones_seen(script_id: String) -> void:
    if not MetaManager.is_onboarding_pending():
        return
    if script_id == "onboarding_selling":
        MetaManager.complete_onboarding()
        _clear_onboarding_overrides()
        return
    for unit_id: String in TutorialScripts.required_onboarding_unit_ids():
        if not _is_unit_seen(unit_id):
            return
    MetaManager.complete_onboarding()
    _clear_onboarding_overrides()


func _on_hub_registered() -> void:
    if SettingsStore.tutorial_skip_all:
        return
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
    if SettingsStore.tutorial_skip_all:
        return
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
