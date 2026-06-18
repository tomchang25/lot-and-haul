# director.gd
# Tutorial presentation layer — owns the dim overlay, step playback, and Help
# button. Knows nothing about game state or when tutorials should trigger
# callers (ScriptDirector, ShotPilot, Help button) drive it via public commands.
# Inserted after SceneRouter, before ScriptDirector in autoload order.
extends Node

const OVERLAY_LAYER := 120
const DIM_COLOR := Color(0.0, 0.0, 0.0, 0.55)
const PANEL_BG := Color(0.15, 0.15, 0.18, 1.0)
const PANEL_BORDER := Color(0.3, 0.3, 0.35, 1.0)
const TEXT_COLOR := Color(0.88, 0.88, 0.92, 1.0)

## Emitted when a scene registers its anchors. ScriptDirector connects to this
## to decide whether to auto-start a tutorial, show an offer, or show Help.
signal scene_registered(scene_id: String)

## Emitted when the user accepts the offer prompt. Payload is the script_id that
## was passed to [method show_offer_prompt].
signal offer_accepted(script_id: String)

## Emitted when the user skips the offer prompt. Director already marks the
## script as seen and shows the Help button before emitting.
signal offer_skipped(script_id: String)

## Emitted when a tutorial script finishes (all steps exhausted or SCENE_ENTERED
## advance triggered).
signal script_completed(script_id: String)

# ── Overlay nodes (code-built) ─────────────────────────────────────────────────
var _canvas: CanvasLayer
var _dim_top: ColorRect
var _dim_bottom: ColorRect
var _dim_left: ColorRect
var _dim_right: ColorRect
var _dim_full: ColorRect
var _hint_panel: PanelContainer
var _hint_label: Label
var _hint_next: Button
var _hint_close: Button
var _popup_panel: PanelContainer
var _popup_label: Label
var _popup_image: TextureRect
var _popup_next: Button
var _popup_close: Button
var _help_btn: Button

# ── Playback state ─────────────────────────────────────────────────────────────
var _is_tutorial_active := false
var _current_script: Array[TutorialStep] = []
var _current_step_index := 0
var _current_script_id := ""
var _current_scene_id := ""
var _anchors: Dictionary = { }
var _is_offer_showing := false
var _offer_script_id := ""
var _help_script_id := ""

## Cached target geometry used to skip redundant per-frame layout recalculations.
## Reset at each step transition in _show_step and whenever the rect changes
## during _process. Stores { rect: Rect2, preferred: int }.
var _last_target_info: Dictionary = { }


func _ready() -> void:
    _build_overlay()
    SceneRouter.scene_changed.connect(_on_scene_changed)
    set_process(false)
    _position_help_btn.call_deferred()


## Consume ESC/ui_settings while the tutorial cover or offer prompt is visible
## to prevent SettingsStore from pausing the tree (which would deadlock both
## overlays since the dim cover blocks the settings panel).
func _unhandled_input(event: InputEvent) -> void:
    if (_is_tutorial_active or _is_offer_showing) and event.is_action_pressed("ui_settings"):
        get_viewport().set_input_as_handled()


## Entry point for scenes. Registers [param anchors] for the current scene
## identified by [param scene_id]. Emits [signal scene_registered] so the
## orchestration layer can decide what to do.
func register_scene(scene_id: String, anchors: Dictionary) -> void:
    _current_scene_id = scene_id
    _anchors = anchors.duplicate()
    _hide_overlay()
    _help_btn.visible = false
    _help_script_id = ""
    _offer_script_id = ""
    _last_target_info = { }
    scene_registered.emit(scene_id)


## Registers a single [param anchor] node under [param id] without resetting the
## scene's full anchor map or overlay state. Intended for dynamic elements like
## chooser popup options that appear and disappear during the scene's lifetime.
func register_anchor(id: String, anchor: Variant) -> void:
    _anchors[id] = anchor


## Removes the anchor registered under [param id]. Does not reset overlay state.
func unregister_anchor(id: String) -> void:
    _anchors.erase(id)


## Starts playback of the tutorial script identified by [param script_id].
## Safe to call at any time — the script's steps are all explain-only.
func start_script(script_id: String) -> void:
    var script: Array[TutorialStep] = TutorialScripts.resolve_script(script_id)
    if script.is_empty():
        ToastManager.show_dev_error("Director.start_script: unknown script '%s'" % script_id)
        _hide_overlay()
        _clear_playback_state()
        return

    var missing_anchors := TutorialScripts.validate_anchors(script_id, _anchors)
    if not missing_anchors.is_empty():
        ToastManager.show_dev_error(
            "Director: script '%s' references unregistered anchors in scene '%s': %s"
            % [script_id, _current_scene_id, ", ".join(missing_anchors)],
        )

    _current_script = script
    _current_script_id = script_id
    _current_step_index = 0
    _is_tutorial_active = true
    _is_offer_showing = false
    _help_btn.visible = false
    _last_target_info = { }
    _show_step()


## Shows a centered offer prompt with the given text. When the user accepts,
## [signal offer_accepted] is emitted with [param script_id]; when declined,
## Director marks the script as seen, shows the Help button, and emits
## [signal offer_skipped].
func show_offer_prompt(script_id: String, offer_text: String, accept_text: String) -> void:
    _offer_script_id = script_id
    _is_offer_showing = true

    _dim_full.color = DIM_COLOR
    _dim_full.visible = true
    _dim_full.mouse_filter = Control.MOUSE_FILTER_STOP
    _dim_full.position = Vector2.ZERO
    _dim_full.size = _get_screen_size()

    _popup_image.visible = false
    _popup_label.text = offer_text
    _popup_next.text = accept_text
    _popup_panel.visible = true
    _popup_close.text = "Skip"
    _popup_close.visible = true

    # Disconnect old slot signatures to avoid duplicates, then connect.
    _offer_safe_disconnect(_popup_close.pressed, _on_offer_skip_pressed)
    _offer_safe_disconnect(_popup_next.pressed, _on_offer_start_pressed)
    _popup_close.pressed.connect(_on_offer_skip_pressed)
    _popup_next.pressed.connect(_on_offer_start_pressed)


## Makes the Help button visible for the given [param script_id]. Pressing the
## button replays the tutorial via [method start_script]. The button persists
## across tutorial completions until a new scene registers.
func show_help_button(script_id: String) -> void:
    _help_script_id = script_id
    _help_btn.visible = true
    _position_help_btn.call_deferred()


## Hides the Help button and clears its associated script.
func hide_help_button() -> void:
    _help_script_id = ""
    _help_btn.visible = false

# ══ Step display ═══════════════════════════════════════════════════════════════


func _is_node_renderable(node: Node) -> bool:
    if not is_instance_valid(node):
        return false
    if not node.is_visible_in_tree():
        return false
    return true


func _is_rect_positive(rect: Rect2) -> bool:
    return rect.size.x > 0.0 and rect.size.y > 0.0


## Resolves a TutorialStep's target to a { rect, preferred } dictionary.
## Accepts both plain Control references and TutorialTarget nodes registered
## as anchors. Returns an empty dictionary when nothing resolves.
func _resolve_target(step: TutorialStep) -> Dictionary:
    var raw = _anchors.get(step.anchor_id)
    if raw == null:
        return _try_fallback_targets(step)

    if raw is TutorialTarget:
        if not _is_node_renderable(raw):
            return _try_fallback_targets(step)
        var rect: Rect2 = raw.get_tutorial_rect()
        if not _is_rect_positive(rect):
            return _try_fallback_targets(step)
        return { "rect": rect, "preferred": raw.preferred_side }

    if raw is Control:
        if not _is_node_renderable(raw):
            return _try_fallback_targets(step)
        var rect: Rect2 = raw.get_global_rect()
        if not _is_rect_positive(rect):
            return _try_fallback_targets(step)
        return { "rect": rect, "preferred": TutorialTarget.PreferredSide.AUTO }

    return _try_fallback_targets(step)


func _try_fallback_targets(step: TutorialStep) -> Dictionary:
    if not step.fallback_when_anchor_unrenderable:
        return { }
    for fallback_id: String in step.fallback_anchor_ids:
        var raw = _anchors.get(fallback_id)
        if raw == null:
            continue
        if raw is TutorialTarget:
            if not _is_node_renderable(raw):
                continue
            var rect: Rect2 = raw.get_tutorial_rect()
            if not _is_rect_positive(rect):
                continue
            return { "rect": rect, "preferred": raw.preferred_side }
        if raw is Control:
            if not _is_node_renderable(raw):
                continue
            var rect: Rect2 = raw.get_global_rect()
            if not _is_rect_positive(rect):
                continue
            return { "rect": rect, "preferred": TutorialTarget.PreferredSide.AUTO }
    return { }


func _advance_to_renderable_step() -> void:
    while _current_step_index < _current_script.size():
        var step: TutorialStep = _current_script[_current_step_index]
        if step.kind == TutorialStep.Kind.POPUP:
            return
        if not _resolve_target(step).is_empty():
            return
        ToastManager.show_dev_error(
            "Director: Skipping step %d: all targets non-renderable in scene '%s'"
            % [_current_step_index, _current_scene_id],
        )
        _current_step_index += 1


func _show_step() -> void:
    if _current_step_index >= _current_script.size():
        _end_tutorial()
        return

    _last_target_info = { }

    _advance_to_renderable_step()

    if _current_step_index >= _current_script.size():
        _end_tutorial()
        return

    var step: TutorialStep = _current_script[_current_step_index]
    _hide_step_ui()
    _help_btn.visible = false
    set_process(false)

    match step.kind:
        TutorialStep.Kind.HINT:
            _show_hint(step)
        TutorialStep.Kind.POPUP:
            _show_popup(step)


func _show_hint(step: TutorialStep) -> void:
    var target := _resolve_target(step)
    if target.is_empty():
        ToastManager.show_dev_error(
            "Director._show_hint: step %d target unresolved despite advance guard"
            % _current_step_index,
        )
        _current_step_index += 1
        _show_step()
        return

    var t_rect: Rect2 = target.get("rect", Rect2())
    var preferred: int = target.get("preferred", TutorialTarget.PreferredSide.AUTO)
    _update_dim_hole(t_rect)

    if step.unlock_anchor:
        _dim_full.visible = false
    else:
        _dim_full.color = Color.TRANSPARENT
        _dim_full.mouse_filter = Control.MOUSE_FILTER_STOP
        _dim_full.position = t_rect.position
        _dim_full.size = t_rect.size
        _dim_full.visible = true

    _hint_label.text = step.text
    _hint_panel.visible = true
    _position_near_anchor(_hint_panel, t_rect, preferred)

    set_process(true)


func _show_popup(step: TutorialStep) -> void:
    _dim_full.color = DIM_COLOR
    _dim_full.visible = true
    _dim_full.mouse_filter = Control.MOUSE_FILTER_STOP
    _dim_full.position = Vector2.ZERO
    _dim_full.size = _get_screen_size()

    if step.image != null:
        _popup_image.texture = step.image
        _popup_image.visible = true
    else:
        _popup_image.visible = false

    _popup_label.text = step.text
    _popup_panel.visible = true


func _hide_step_ui() -> void:
    _hint_panel.visible = false
    _popup_panel.visible = false
    _dim_full.visible = false
    _dim_top.visible = false
    _dim_bottom.visible = false
    _dim_left.visible = false
    _dim_right.visible = false


func _hide_overlay() -> void:
    _hide_step_ui()
    _is_tutorial_active = false
    _is_offer_showing = false
    set_process(false)
    _clear_playback_state()

# ══ Public commands (used by UI buttons, ScriptDirector, and ShotPilot) ══════


## Returns the current step index during playback.
func step_index() -> int:
    return _current_step_index


## Returns the total number of steps in the active script.
func step_count() -> int:
    return _current_script.size()


## Returns the anchor_id for the step at [param idx], or "" if out of range.
func step_anchor_id(idx: int) -> String:
    if idx < 0 or idx >= _current_script.size():
        return ""
    return _current_script[idx].anchor_id


## Returns true when the offer prompt is currently visible.
func is_offer_showing() -> bool:
    return _is_offer_showing


## Returns the hint panel node, or null if not yet built.
func get_hint_panel() -> PanelContainer:
    return _hint_panel


## Returns the anchor registered under [param id] (Control or TutorialTarget),
## or null. Preserved for backward compatibility with harness code.
func get_anchor(id: String) -> Variant:
    return _anchors.get(id) if _anchors.has(id) else null


## Returns the resolved global rect for the target registered under [param id].
## Handles both plain Control references and TutorialTarget nodes. Returns an
## empty Rect2 when the id is unknown.
func get_target_rect(id: String) -> Rect2:
    var raw = _anchors.get(id)
    if raw == null:
        return Rect2()
    if raw is TutorialTarget:
        if not _is_node_renderable(raw):
            return Rect2()
        return raw.get_tutorial_rect()
    if raw is Control:
        if not _is_node_renderable(raw):
            return Rect2()
        return raw.get_global_rect()
    return Rect2()


## Advances one step (as if the user clicked Next). Called by both the Next
## button handlers and the ShotPilot harness. No-op when no tutorial is active.
func advance_step() -> void:
    if not _is_tutorial_active:
        return
    _current_step_index += 1
    _show_step()


## Accepts the current offer prompt (simulates clicking "Yes"). Called by both
## the offer "Yes" button handler and the ShotPilot harness. No-op when no
## offer is showing. Emits [signal offer_accepted] — the orchestration layer
## decides what to do next (typically [method start_script]).
func accept_offer() -> void:
    if not _is_offer_showing:
        return
    _offer_safe_disconnect(_popup_close.pressed, _on_offer_skip_pressed)
    _offer_safe_disconnect(_popup_next.pressed, _on_offer_start_pressed)
    _popup_close.text = "×"
    var script_id := _offer_script_id
    _is_offer_showing = false
    if TutorialScripts.resolve_script(script_id).is_empty():
        ToastManager.show_dev_error("Director.accept_offer: script '%s' no longer resolves" % script_id)
        _hide_overlay()
        _clear_playback_state()
        _help_btn.visible = false
        return
    offer_accepted.emit(script_id)

# ══ Navigation buttons ═════════════════════════════════════════════════════════


func _on_hint_next_pressed() -> void:
    advance_step()


func _on_hint_close_pressed() -> void:
    if not _is_tutorial_active:
        return
    _mark_seen(_current_script_id)
    _hide_overlay()
    if not _help_script_id.is_empty():
        _help_btn.visible = true


func _on_popup_next_pressed() -> void:
    advance_step()


func _on_popup_close_pressed() -> void:
    if not _is_tutorial_active:
        return
    _mark_seen(_current_script_id)
    _hide_overlay()
    if not _help_script_id.is_empty():
        _help_btn.visible = true


func _on_offer_start_pressed() -> void:
    accept_offer()


func _on_offer_skip_pressed() -> void:
    _offer_safe_disconnect(_popup_close.pressed, _on_offer_skip_pressed)
    _offer_safe_disconnect(_popup_next.pressed, _on_offer_start_pressed)
    _popup_close.text = "×"
    var skipped_id := _offer_script_id
    _mark_seen(skipped_id)
    _hide_overlay()
    show_help_button(skipped_id)
    offer_skipped.emit(skipped_id)


func _on_help_pressed() -> void:
    start_script(_help_script_id)


func _offer_safe_disconnect(signal_obj: Signal, callable: Callable) -> void:
    if signal_obj.is_connected(callable):
        signal_obj.disconnect(callable)

# ══ Scene change watcher ═══════════════════════════════════════════════════════


func _clear_playback_state() -> void:
    _current_script = []
    _current_step_index = 0
    _current_script_id = ""
    _last_target_info = { }


func _on_scene_changed() -> void:
    if _is_tutorial_active and _current_step_index < _current_script.size():
        var step: TutorialStep = _current_script[_current_step_index]
        if step.advance == TutorialStep.Advance.SCENE_ENTERED:
            var completed_id := _current_script_id
            _mark_seen(completed_id)
            _hide_overlay()
            script_completed.emit(completed_id)

# ══ Script management ══════════════════════════════════════════════════════════


func _end_tutorial() -> void:
    var completed_id := _current_script_id
    _mark_seen(completed_id)
    _hide_overlay()
    _clear_playback_state()
    if not _help_script_id.is_empty():
        _help_btn.visible = true
    script_completed.emit(completed_id)


func _mark_seen(script_id: String) -> void:
    if script_id.is_empty():
        return
    MetaManager.mark_tutorial_seen(script_id)

# ══ Dim / hole layout ══════════════════════════════════════════════════════════


func _update_dim_hole(hole: Rect2) -> void:
    var screen: Vector2 = _get_screen_size()

    var hole_top: float = maxf(hole.position.y, 0.0)
    var hole_bottom: float = hole.position.y + hole.size.y
    var hole_left: float = maxf(hole.position.x, 0.0)
    var hole_right: float = hole.position.x + hole.size.x

    _dim_top.position = Vector2(0, 0)
    _dim_top.size = Vector2(screen.x, hole_top)

    _dim_bottom.position = Vector2(0, hole_bottom)
    _dim_bottom.size = Vector2(screen.x, maxf(screen.y - hole_bottom, 0))

    _dim_left.position = Vector2(0, hole_top)
    _dim_left.size = Vector2(hole_left, hole.size.y)

    _dim_right.position = Vector2(hole_right, hole_top)
    _dim_right.size = Vector2(maxf(screen.x - hole_right, 0), hole.size.y)

    for dim in [_dim_top, _dim_bottom, _dim_left, _dim_right]:
        dim.visible = true
        dim.mouse_filter = Control.MOUSE_FILTER_STOP


## Tries to place [param panel] on the given [param side] of [param target_rect]
## within screen bounds. Returns the position if it fits, or null if clipping
## occurs.
func _try_place_on_side(
        panel: Control,
        target_rect: Rect2,
        side: TutorialTarget.PreferredSide,
        screen: Vector2,
        margin: float,
) -> Variant:
    var pw := panel.custom_minimum_size.x if panel.custom_minimum_size.x > 0 else 280.0
    var ph := panel.size.y if panel.size.y > 0 else 100.0

    match side:
        TutorialTarget.PreferredSide.RIGHT:
            var px := target_rect.end.x + margin
            if px + pw <= screen.x - margin:
                return Vector2(px, clampf(target_rect.position.y, margin, screen.y - ph - margin))
        TutorialTarget.PreferredSide.LEFT:
            var px := target_rect.position.x - pw - margin
            if px >= margin:
                return Vector2(px, clampf(target_rect.position.y, margin, screen.y - ph - margin))
        TutorialTarget.PreferredSide.TOP:
            var py := target_rect.position.y - ph - margin
            if py >= margin:
                return Vector2(clampf(target_rect.position.x, margin, screen.x - pw - margin), py)
        TutorialTarget.PreferredSide.BOTTOM:
            var py := target_rect.end.y + margin
            if py + ph <= screen.y - margin:
                return Vector2(clampf(target_rect.position.x, margin, screen.x - pw - margin), py)
        _:
            return null
    return null


## Positions [param panel] near [param target_rect], trying [param preferred_side]
## first when set, then falling through RIGHT → LEFT → BOTTOM → centered.
## Full-viewport targets (>=90% screen in both axes) are always centered.
func _position_near_anchor(
        panel: Control,
        target_rect: Rect2,
        preferred_side: int = TutorialTarget.PreferredSide.AUTO,
) -> void:
    var screen: Vector2 = _get_screen_size()
    var margin: float = 16.0
    panel.custom_minimum_size.x = 280.0
    var pw: float

    # Full-viewport fallback: when the target covers most of the viewport, use
    # a centered popup-style placement rather than edge-relative positioning.
    if target_rect.size.x >= screen.x * 0.9 and target_rect.size.y >= screen.y * 0.9:
        pw = panel.custom_minimum_size.x
        panel.position = Vector2(
            clampi(int((screen.x - pw) / 2), 0, int(screen.x - pw)),
            clampi(int(screen.y * 0.3), 0, int(screen.y - panel.size.y - margin if panel.size.y > 0 else screen.y - 200)),
        )
        return

    # Try preferred side first when explicitly set.
    if preferred_side != TutorialTarget.PreferredSide.AUTO:
        var pos := _try_place_on_side(panel, target_rect, preferred_side, screen, margin)
        if pos != null:
            panel.position = pos as Vector2
            return

    # Default fallback order: RIGHT → LEFT → BOTTOM → TOP → centered.
    var fallback_order: Array[int] = [
        TutorialTarget.PreferredSide.RIGHT,
        TutorialTarget.PreferredSide.LEFT,
        TutorialTarget.PreferredSide.BOTTOM,
        TutorialTarget.PreferredSide.TOP,
    ]
    for side: int in fallback_order:
        var pos := _try_place_on_side(panel, target_rect, side, screen, margin)
        if pos != null:
            panel.position = pos as Vector2
            return

    # Last resort: centered with margin.
    pw = panel.custom_minimum_size.x
    panel.position = Vector2(
        clampf((screen.x - pw) / 2, margin, screen.x - pw - margin),
        clampf(screen.y * 0.3, margin, screen.y - panel.size.y - margin if panel.size.y > 0 else screen.y - 200),
    )

# ══ Per-frame hole update ══════════════════════════════════════════════════════


func _process(_delta: float) -> void:
    if not _is_tutorial_active:
        set_process(false)
        return
    if _current_step_index >= _current_script.size():
        set_process(false)
        return

    var step: TutorialStep = _current_script[_current_step_index]
    if step.kind != TutorialStep.Kind.HINT:
        set_process(false)
        return

    var target := _resolve_target(step)
    if target.is_empty():
        return

    var t_rect: Rect2 = target.get("rect", Rect2())
    var preferred: int = target.get("preferred", TutorialTarget.PreferredSide.AUTO)

    # Skip redundant layout when the target rect has not changed since the last
    # per-frame update. _last_target_info is reset at each step transition in
    # _show_step, so stale data from a previous step never carries forward.
    var cached_rect: Rect2 = _last_target_info.get("rect", Rect2())
    if t_rect == cached_rect:
        return
    _last_target_info = { "rect": t_rect, "preferred": preferred }

    _update_dim_hole(t_rect)

    if not step.unlock_anchor:
        _dim_full.position = t_rect.position
        _dim_full.size = t_rect.size

    _position_near_anchor(_hint_panel, t_rect, preferred)

# ══ Helpers ════════════════════════════════════════════════════════════════════


func _get_screen_size() -> Vector2:
    return get_viewport().get_visible_rect().size


func _position_help_btn() -> void:
    var screen: Vector2 = _get_screen_size()
    _help_btn.position = Vector2(8, screen.y - 44)


func _make_dim_rect(parent: CanvasLayer) -> ColorRect:
    var cr := ColorRect.new()
    cr.color = DIM_COLOR
    cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
    cr.visible = false
    parent.add_child(cr)
    return cr

# ══ Overlay construction ═══════════════════════════════════════════════════════


func _build_overlay() -> void:
    _canvas = CanvasLayer.new()
    _canvas.layer = OVERLAY_LAYER
    add_child(_canvas)

    _dim_top = _make_dim_rect(_canvas)
    _dim_bottom = _make_dim_rect(_canvas)
    _dim_left = _make_dim_rect(_canvas)
    _dim_right = _make_dim_rect(_canvas)

    _dim_full = ColorRect.new()
    _dim_full.color = DIM_COLOR
    _dim_full.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _dim_full.visible = false
    _canvas.add_child(_dim_full)

    # Hint panel
    _hint_panel = PanelContainer.new()
    _hint_panel.visible = false
    _hint_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    _canvas.add_child(_hint_panel)

    var hint_margin := MarginContainer.new()
    hint_margin.add_theme_constant_override("margin_left", 16)
    hint_margin.add_theme_constant_override("margin_right", 16)
    hint_margin.add_theme_constant_override("margin_top", 12)
    hint_margin.add_theme_constant_override("margin_bottom", 12)
    _hint_panel.add_child(hint_margin)

    var hint_vbox := VBoxContainer.new()
    hint_vbox.add_theme_constant_override("separation", 12)
    hint_margin.add_child(hint_vbox)

    _hint_label = Label.new()
    _hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _hint_label.add_theme_color_override("font_color", TEXT_COLOR)
    _hint_label.add_theme_font_size_override("font_size", 13)
    _hint_label.custom_minimum_size = Vector2(260, 0)
    hint_vbox.add_child(_hint_label)

    var hint_btn_hbox := HBoxContainer.new()
    hint_btn_hbox.alignment = BoxContainer.ALIGNMENT_END
    hint_btn_hbox.add_theme_constant_override("separation", 8)
    hint_vbox.add_child(hint_btn_hbox)

    _hint_close = Button.new()
    _hint_close.text = "×"
    _hint_close.flat = true
    _hint_close.pressed.connect(_on_hint_close_pressed)
    hint_btn_hbox.add_child(_hint_close)

    _hint_next = Button.new()
    _hint_next.text = "Next"
    _hint_next.pressed.connect(_on_hint_next_pressed)
    hint_btn_hbox.add_child(_hint_next)

    # Popup panel
    _popup_panel = PanelContainer.new()
    _popup_panel.visible = false
    _popup_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    _popup_panel.set_anchors_preset(Control.PRESET_CENTER)
    _popup_panel.custom_minimum_size = Vector2(420, 0)
    _canvas.add_child(_popup_panel)

    var popup_margin := MarginContainer.new()
    popup_margin.add_theme_constant_override("margin_left", 24)
    popup_margin.add_theme_constant_override("margin_right", 24)
    popup_margin.add_theme_constant_override("margin_top", 20)
    popup_margin.add_theme_constant_override("margin_bottom", 20)
    _popup_panel.add_child(popup_margin)

    var popup_vbox := VBoxContainer.new()
    popup_vbox.add_theme_constant_override("separation", 16)
    popup_margin.add_child(popup_vbox)

    _popup_image = TextureRect.new()
    _popup_image.visible = false
    _popup_image.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
    _popup_image.custom_minimum_size = Vector2(0, 80)
    popup_vbox.add_child(_popup_image)

    _popup_label = Label.new()
    _popup_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _popup_label.add_theme_color_override("font_color", TEXT_COLOR)
    _popup_label.add_theme_font_size_override("font_size", 14)
    popup_vbox.add_child(_popup_label)

    var popup_btn_hbox := HBoxContainer.new()
    popup_btn_hbox.alignment = BoxContainer.ALIGNMENT_END
    popup_btn_hbox.add_theme_constant_override("separation", 8)
    popup_vbox.add_child(popup_btn_hbox)

    _popup_close = Button.new()
    _popup_close.text = "×"
    _popup_close.flat = true
    _popup_close.pressed.connect(_on_popup_close_pressed)
    popup_btn_hbox.add_child(_popup_close)

    _popup_next = Button.new()
    _popup_next.text = "Next"
    _popup_next.pressed.connect(_on_popup_next_pressed)
    popup_btn_hbox.add_child(_popup_next)

    # Help button (bottom-left corner)
    _help_btn = Button.new()
    _help_btn.text = "?"
    _help_btn.visible = false
    _help_btn.mouse_filter = Control.MOUSE_FILTER_STOP
    _help_btn.pressed.connect(_on_help_pressed)
    _help_btn.custom_minimum_size = Vector2(36, 36)
    _help_btn.position = Vector2(8, 0)
    _canvas.add_child(_help_btn)

    # Style panels
    for panel in [_hint_panel, _popup_panel]:
        var sb := StyleBoxFlat.new()
        sb.bg_color = PANEL_BG
        sb.border_color = PANEL_BORDER
        sb.set_border_width_all(1)
        sb.set_corner_radius_all(6)
        sb.content_margin_left = 0
        sb.content_margin_right = 0
        sb.content_margin_top = 0
        sb.content_margin_bottom = 0
        panel.add_theme_stylebox_override("panel", sb)
