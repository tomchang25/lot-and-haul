# director.gd
# Tutorial presentation layer — owns the dim overlay, step rendering, offer
# prompt, Help button, and anchor registry. Knows nothing about step order or
# wait conditions. The flow layer (ScriptDirector) owns all tutorial state.
# Inserted after SceneRouter, before ScriptDirector in autoload order.
extends Node

const OVERLAY_LAYER := 120
const DIM_COLOR := Color(0.0, 0.0, 0.0, 0.55)
const PANEL_BG := Color(0.15, 0.15, 0.18, 1.0)
const PANEL_BORDER := Color(0.3, 0.3, 0.35, 1.0)
const TEXT_COLOR := Color(0.88, 0.88, 0.92, 1.0)

## Emitted when a scene registers its anchors. ScriptDirector connects to this
## to decide whether to start a tutorial, show an offer, or show Help.
signal scene_registered(scene_id: String)

## Emitted when the player clicks Next on a hint or popup step.
signal advance_requested

## Emitted when the player closes the tutorial with the close (x) button.
signal tutorial_closed

## Emitted when the user accepts the offer prompt. Payload is the script_id that
## was passed to [method show_offer_prompt].
signal offer_accepted(script_id: String)

## Emitted when the user skips the offer prompt.
signal offer_skipped(script_id: String)

## Emitted when a tutorial script finishes (all steps exhausted or ended).
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

# ── Presentation state ─────────────────────────────────────────────────────────
var _anchors: Dictionary = { }
var _is_offer_showing := false
var _offer_script_id := ""
var _help_script_id := ""
var _current_scene_id := ""

## The step currently being rendered — used by _process for per-frame
## anchor tracking. Set by render_step(), cleared by hide_tutorial_overlay().
var _rendered_step: TutorialStep = null

## Cached target geometry used to skip redundant per-frame layout recalculations.
## Reset at each step transition in render_step and whenever the rect changes
## during _process.
var _last_target_info: Dictionary = { }


func _ready() -> void:
    _build_overlay()
    SceneRouter.scene_changed.connect(_on_scene_changed)
    set_process(false)
    _position_help_btn.call_deferred()

## The scene id most recently registered.
var current_scene_id: String:
    get:
        return _current_scene_id


## Whether the offer prompt is currently visible.
func is_offer_showing() -> bool:
    return _is_offer_showing


## Whether a tutorial step is currently being rendered.
func is_tutorial_active() -> bool:
    return _rendered_step != null


## Returns the full anchors dictionary for the current scene.
func get_anchors() -> Dictionary:
    return _anchors.duplicate()


## Consume ESC/ui_settings while the tutorial cover or offer prompt is visible
## to prevent SettingsStore from pausing the tree (which would deadlock both
## overlays since the dim cover blocks the settings panel).
func _unhandled_input(event: InputEvent) -> void:
    if (_rendered_step != null or _is_offer_showing) and event.is_action_pressed("ui_settings"):
        get_viewport().set_input_as_handled()

# ══ Anchor management ══════════════════════════════════════════════════════════


## Entry point for scenes. Registers [param anchors] for the current scene
## identified by [param scene_id]. Emits [signal scene_registered] so the
## flow layer can decide what to do.
func register_scene(scene_id: String, anchors: Dictionary) -> void:
    _current_scene_id = scene_id
    _anchors = anchors.duplicate()
    _last_target_info = { }
    # Do not clear overlay or flow state here — ScriptDirector handles that.
    scene_registered.emit(scene_id)


## Registers a single [param anchor] node under [param id] without resetting the
## scene's full anchor map. Intended for dynamic elements like chooser popup
## options that appear and disappear during the scene's lifetime.
func register_anchor(id: String, anchor: Variant) -> void:
    _anchors[id] = anchor


## Removes the anchor registered under [param id].
func unregister_anchor(id: String) -> void:
    _anchors.erase(id)

# ══ Public commands — delegate flow to ScriptDirector ═════════════════════════


## Starts playback of the tutorial script identified by [param script_id].
## Delegates to the flow layer.
func start_script(script_id: String) -> void:
    ScriptDirector.start_script(script_id)


## Advances one step (as if the user clicked Next). Delegates to the flow layer
## by emitting [signal advance_requested].
func advance_step() -> void:
    advance_requested.emit()


## Marks every onboarding unit as seen and clears the onboarding-pending flag
## immediately. Only callable from debug menu or explicit user action — never
## from the per-step X button. Delegates to the flow layer.
func skip_all_onboarding() -> void:
    ScriptDirector.skip_all_onboarding()

# ══ Tutorial-driven state queries — delegated to ScriptDirector ═════════════


## Returns true when the location-select scene should show only the tutorial
## location. Evaluated before the location_select unit is active, so it uses
## trigger context directly.
func use_tutorial_location() -> bool:
    return ScriptDirector.use_tutorial_location()


## Returns true while the onboarding_auction unit is active. Auction scene
## uses this to disable NPC bidding and the pass button.
func is_auction_assisted() -> bool:
    return ScriptDirector.is_auction_assisted()


## Returns the activity that the onboarding flow wants the player to choose
## ("auction", "storage", "selling"), or an empty StringName when no target
## is active. Hub scene uses this to gate the chooser buttons.
func activity_chooser_target() -> StringName:
    return ScriptDirector.activity_chooser_target()


## Returns true while onboarding is pending and the selling tutorial has not
## yet been seen. Customer_sell scene uses this to lock conservative sale.
func is_conservative_sale_locked() -> bool:
    return ScriptDirector.is_conservative_sale_locked()


## Returns true while the onboarding_lot_browse unit is active. Lot_browse
## scene uses this to disable the pass/skip buttons.
func should_disable_pass_in_lot_browse() -> bool:
    return ScriptDirector.should_disable_pass_in_lot_browse()


## Returns true while the onboarding_inspection unit is active and the player
## has not yet performed an inspection. Inspection scene uses this to disable
## the review button.
func should_disable_inspection_review() -> bool:
    return ScriptDirector.should_disable_inspection_review()

# ══ Public accessors — delegated to ScriptDirector ════════════════════════════


## Returns the current step index during playback.
func step_index() -> int:
    return ScriptDirector.step_index()


## Returns the total number of steps in the active script.
func step_count() -> int:
    return ScriptDirector.step_count()


## Returns the anchor_id for the step at [param idx], or "" if out of range.
func step_anchor_id(idx: int) -> String:
    return ScriptDirector.step_anchor_id(idx)


## Returns the anchor registered under [param id] (Control or TutorialTarget),
## or null.
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


## Returns the hint panel node, or null if not yet built.
func get_hint_panel() -> PanelContainer:
    return _hint_panel

# ══ Offer prompt ═══════════════════════════════════════════════════════════════


## Shows a centered offer prompt with the given text. When the user accepts,
## [signal offer_accepted] is emitted with [param script_id]; when declined,
## [signal offer_skipped] is emitted.
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

    _offer_safe_disconnect(_popup_close.pressed, _on_offer_skip_pressed)
    _offer_safe_disconnect(_popup_next.pressed, _on_offer_start_pressed)
    _popup_close.pressed.connect(_on_offer_skip_pressed)
    _popup_next.pressed.connect(_on_offer_start_pressed)


## Hides the offer prompt without emitting signals.
func hide_offer_prompt() -> void:
    _is_offer_showing = false
    _dim_full.visible = false
    _popup_panel.visible = false
    _offer_safe_disconnect(_popup_close.pressed, _on_offer_skip_pressed)
    _offer_safe_disconnect(_popup_next.pressed, _on_offer_start_pressed)


## Accepts the current offer prompt. Emits [signal offer_accepted] only after
## confirming the referenced script still resolves. Unknown scripts are silently
## dismissed with a dev error (preserving the old Director.accept_offer contract).
func accept_offer() -> void:
    if not _is_offer_showing:
        return
    _offer_safe_disconnect(_popup_close.pressed, _on_offer_skip_pressed)
    _offer_safe_disconnect(_popup_next.pressed, _on_offer_start_pressed)
    _popup_close.text = "x"
    var script_id := _offer_script_id
    if TutorialScripts.resolve_script(script_id).is_empty():
        ToastManager.show_dev_error("Director.accept_offer: script '%s' no longer resolves" % script_id)
        _hide_offer_state()
        return
    _hide_offer_state()
    offer_accepted.emit(script_id)

# ══ Help button ════════════════════════════════════════════════════════════════


## Makes the Help button visible for the given [param script_id]. Pressing the
## button replays the tutorial via the flow layer.
func show_help_button(script_id: String) -> void:
    _help_script_id = script_id
    _help_btn.visible = true
    _position_help_btn.call_deferred()


## Hides the Help button and clears its associated script.
func hide_help_button() -> void:
    _help_script_id = ""
    _help_btn.visible = false

# ══ Step rendering (called by ScriptDirector) ═════════════════════════════════


## Renders the given [param step] on the overlay. Called by the flow layer
## after evaluating advance conditions. The Director owns no flow state:
## it only renders what it is told.
func render_step(step: TutorialStep) -> void:
    _rendered_step = step
    _hide_step_ui()
    _help_btn.visible = false
    _last_target_info = { }
    set_process(false)

    match step.kind:
        TutorialStep.Kind.HINT:
            _show_hint(step)
        TutorialStep.Kind.POPUP:
            _show_popup(step)


## Hides the tutorial overlay but does not clear flow state. Called by the
## flow layer when a tutorial ends or pauses across scene transitions.
func hide_tutorial_overlay() -> void:
    _hide_step_ui()
    set_process(false)
    _rendered_step = null


## Clears all non-persistent tutorial presentation state. Called when save-slot
## state is reset or switched so stale overlays, offers, Help buttons, and
## anchors cannot suppress the next scene's tutorial trigger.
func reset_tutorial_presentation() -> void:
    hide_tutorial_overlay()
    hide_offer_prompt()
    hide_help_button()
    _anchors.clear()
    _current_scene_id = ""
    _offer_script_id = ""
    _last_target_info = { }


## Called by ScriptDirector after a tutorial completes. Emits the
## [signal script_completed] signal for backward compatibility.
func notify_script_completed(script_id: String) -> void:
    script_completed.emit(script_id)

# ══ Target resolution (shared with ScriptDirector) ════════════════════════════


## Resolves a TutorialStep's target to a { rect, preferred } dictionary.
## Accepts both plain Control references and TutorialTarget nodes registered
## as anchors. Returns an empty dictionary when nothing resolves.
func resolve_target(step: TutorialStep) -> Dictionary:
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


func _is_node_renderable(node: Node) -> bool:
    if not is_instance_valid(node):
        return false
    if not node.is_visible_in_tree():
        return false
    return true


func _is_rect_positive(rect: Rect2) -> bool:
    return rect.size.x > 0.0 and rect.size.y > 0.0

# ══ Step display ═══════════════════════════════════════════════════════════════


func _show_hint(step: TutorialStep) -> void:
    var target := resolve_target(step)
    if target.is_empty():
        ToastManager.show_dev_error(
            "Director._show_hint: step target unresolved — flow layer should have skipped",
        )
        return

    var t_rect: Rect2 = target.get("rect", Rect2())
    var preferred: int = target.get("preferred", TutorialTarget.PreferredSide.AUTO)
    if step.blocks_input:
        _update_dim_hole(t_rect)
    else:
        _dim_top.visible = false
        _dim_bottom.visible = false
        _dim_left.visible = false
        _dim_right.visible = false

    if step.unlock_anchor or not step.blocks_input:
        _dim_full.visible = false
    else:
        _dim_full.color = Color.TRANSPARENT
        _dim_full.mouse_filter = Control.MOUSE_FILTER_STOP
        _dim_full.position = t_rect.position
        _dim_full.size = t_rect.size
        _dim_full.visible = true

    _hint_label.text = step.text
    _hint_panel.visible = true
    _hint_next.visible = step.advance == TutorialStep.Advance.NEXT
    _position_near_anchor(_hint_panel, t_rect, preferred)

    set_process(true)


func _show_popup(step: TutorialStep) -> void:
    if step.blocks_input:
        _dim_full.color = DIM_COLOR
        _dim_full.visible = true
        _dim_full.mouse_filter = Control.MOUSE_FILTER_STOP
        _dim_full.position = Vector2.ZERO
        _dim_full.size = _get_screen_size()
    else:
        _dim_full.visible = false
        _dim_full.mouse_filter = Control.MOUSE_FILTER_IGNORE

    if step.image != null:
        _popup_image.texture = step.image
        _popup_image.visible = true
    else:
        _popup_image.visible = false

    _popup_label.text = step.text
    _popup_panel.visible = true
    _popup_next.visible = step.advance == TutorialStep.Advance.NEXT


func _hide_step_ui() -> void:
    _hint_panel.visible = false
    _popup_panel.visible = false
    _dim_full.visible = false
    _dim_top.visible = false
    _dim_bottom.visible = false
    _dim_left.visible = false
    _dim_right.visible = false


func _hide_offer_state() -> void:
    _is_offer_showing = false
    _dim_full.visible = false
    _popup_panel.visible = false

# ══ Navigation buttons ═════════════════════════════════════════════════════════


# Next — emit advance_requested for the flow layer to handle.
func _on_hint_next_pressed() -> void:
    advance_requested.emit()


func _on_hint_close_pressed() -> void:
    if _rendered_step == null:
        return
    tutorial_closed.emit()


func _on_popup_next_pressed() -> void:
    advance_requested.emit()


func _on_popup_close_pressed() -> void:
    if _rendered_step == null:
        return
    tutorial_closed.emit()


func _on_help_pressed() -> void:
    if not _help_script_id.is_empty():
        ScriptDirector.start_script(_help_script_id)

# ══ Offer button handlers ══════════════════════════════════════════════════════


func _on_offer_start_pressed() -> void:
    accept_offer()


func _on_offer_skip_pressed() -> void:
    _offer_safe_disconnect(_popup_close.pressed, _on_offer_skip_pressed)
    _offer_safe_disconnect(_popup_next.pressed, _on_offer_start_pressed)
    _popup_close.text = "x"
    var skipped_id := _offer_script_id
    _hide_offer_state()
    offer_skipped.emit(skipped_id)


func _offer_safe_disconnect(signal_obj: Signal, callable: Callable) -> void:
    if signal_obj.is_connected(callable):
        signal_obj.disconnect(callable)

# ══ Scene change watcher ═══════════════════════════════════════════════════════


func _on_scene_changed() -> void:
    # Presentation only — inform the flow layer. No state clearing here.
    pass

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

# ══ Per-frame hole update ══════════════════════════════════════════════════════


func _process(_delta: float) -> void:
    if _rendered_step == null:
        set_process(false)
        return
    if _rendered_step.kind != TutorialStep.Kind.HINT:
        set_process(false)
        return

    var target := resolve_target(_rendered_step)
    if target.is_empty():
        return

    var t_rect: Rect2 = target.get("rect", Rect2())
    var preferred: int = target.get("preferred", TutorialTarget.PreferredSide.AUTO)

    var cached_rect: Rect2 = _last_target_info.get("rect", Rect2())
    if t_rect == cached_rect:
        return
    _last_target_info = { "rect": t_rect, "preferred": preferred }

    if _rendered_step.blocks_input:
        _update_dim_hole(t_rect)
    else:
        _dim_top.visible = false
        _dim_bottom.visible = false
        _dim_left.visible = false
        _dim_right.visible = false

    if _rendered_step.blocks_input and not _rendered_step.unlock_anchor:
        _dim_full.position = t_rect.position
        _dim_full.size = t_rect.size

    _position_near_anchor(_hint_panel, t_rect, preferred)

# ══ Panel placement ════════════════════════════════════════════════════════════


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


func _position_near_anchor(
        panel: Control,
        target_rect: Rect2,
        preferred_side: int = TutorialTarget.PreferredSide.AUTO,
) -> void:
    var screen: Vector2 = _get_screen_size()
    var margin: float = 16.0
    panel.custom_minimum_size.x = 280.0
    var pw: float

    if target_rect.size.x >= screen.x * 0.9 and target_rect.size.y >= screen.y * 0.9:
        pw = panel.custom_minimum_size.x
        panel.position = Vector2(
            clampi(int((screen.x - pw) / 2), 0, int(screen.x - pw)),
            clampi(int(screen.y * 0.3), 0, int(screen.y - panel.size.y - margin if panel.size.y > 0 else screen.y - 200)),
        )
        return

    if preferred_side != TutorialTarget.PreferredSide.AUTO:
        var pos := _try_place_on_side(panel, target_rect, preferred_side, screen, margin)
        if pos != null:
            panel.position = pos as Vector2
            return

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

    pw = panel.custom_minimum_size.x
    panel.position = Vector2(
        clampf((screen.x - pw) / 2, margin, screen.x - pw - margin),
        clampf(screen.y * 0.3, margin, screen.y - panel.size.y - margin if panel.size.y > 0 else screen.y - 200),
    )

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
    _hint_close.text = "x"
    _hint_close.flat = true
    _hint_close.pressed.connect(_on_hint_close_pressed)
    hint_btn_hbox.add_child(_hint_close)

    _hint_next = Button.new()
    _hint_next.text = "Next"
    _hint_next.pressed.connect(_on_hint_next_pressed)
    hint_btn_hbox.add_child(_hint_next)

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
    _popup_close.text = "x"
    _popup_close.flat = true
    _popup_close.pressed.connect(_on_popup_close_pressed)
    popup_btn_hbox.add_child(_popup_close)

    _popup_next = Button.new()
    _popup_next.text = "Next"
    _popup_next.pressed.connect(_on_popup_next_pressed)
    popup_btn_hbox.add_child(_popup_next)

    _help_btn = Button.new()
    _help_btn.text = "?"
    _help_btn.visible = false
    _help_btn.mouse_filter = Control.MOUSE_FILTER_STOP
    _help_btn.pressed.connect(_on_help_pressed)
    _help_btn.custom_minimum_size = Vector2(36, 36)
    _help_btn.position = Vector2(8, 0)
    _canvas.add_child(_help_btn)

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
