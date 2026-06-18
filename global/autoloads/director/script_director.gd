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
    _mark_seen(_active_script_id)
    Director.hide_tutorial_overlay()
    _clear_state()


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
    if step.kind == TutorialStep.Kind.HINT and not step.anchor_id.is_empty():
        var target := Director.resolve_target(step)
        if not target.is_empty():
            Director.render_step(step)
        else:
            Director.hide_tutorial_overlay()
    elif step.kind == TutorialStep.Kind.POPUP:
        Director.render_step(step)
    else:
        Director.hide_tutorial_overlay()


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


func _show_current_step() -> void:
    if not _is_active:
        return

    # Do not skip SCENE_ENTERED steps — they wait for a future scene.
    # Do not skip EVENT steps — they wait for a gameplay event.
    # Only skip NEXT steps whose anchors are unresolvable (old static-tutorial
    # behavior).
    _skip_non_renderable_next_steps()

    if _active_step_index >= _active_script.size():
        _end_tutorial()
        return

    var step: TutorialStep = _active_script[_active_step_index]
    if step.advance in [TutorialStep.Advance.SCENE_ENTERED, TutorialStep.Advance.EVENT]:
        # Cannot render yet — scene or event will trigger completion.
        if step.kind != TutorialStep.Kind.POPUP and not step.anchor_id.is_empty() and Director.resolve_target(step).is_empty():
            Director.hide_tutorial_overlay()
            return
    Director.render_step(step)


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
    Director.hide_tutorial_overlay()
    _clear_state()
    Director.notify_script_completed(completed_id)


func _mark_seen(script_id: String) -> void:
    if script_id.is_empty():
        return
    MetaManager.mark_tutorial_seen(script_id)


func _clear_state() -> void:
    _active_script = []
    _active_step_index = 0
    _active_script_id = ""
    _is_active = false
    active = false

# ══ Scene registration decision (for non-active state) ════════════════════════


func _decide_tutorial_for_scene(scene_id: String) -> void:
    match scene_id:
        "hub":
            _on_hub_registered()
        "storage":
            _on_storage_registered()
        _:
            pass


func _on_hub_registered() -> void:
    if MetaManager.progress.tutorial_seen.has("hub"):
        return
    start_script("hub")


func _on_storage_registered() -> void:
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
