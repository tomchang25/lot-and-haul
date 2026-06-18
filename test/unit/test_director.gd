# test_director.gd
# Director accessor lifecycle, unknown-script fallback, offer acceptance, and
# tutorial-seen tracking.
extends GutTest

const HUB_SCRIPT_SIZE := 3
const STORAGE_SCRIPT_SIZE := 8
const UNKNOWN_SCRIPT_ID := "nonexistent_script [DEBUG-PASS]"
const UNKNOWN_OFFER_ID := "nonexistent_offer [DEBUG-PASS]"

var _hub_anchors: Dictionary = { }
var _owned_controls: Array[Control] = []


func before_all() -> void:
    MetaManager.reset()


func before_each() -> void:
    MetaManager.reset()
    _hub_anchors = {
        "slot_label": _make_anchor_button(),
        "storage_btn": _make_anchor_button(),
    }
    Director.register_scene("hub", _hub_anchors)


func after_each() -> void:
    for control: Control in _owned_controls:
        if is_instance_valid(control):
            control.free()
    _owned_controls.clear()
    _hub_anchors.clear()


func _make_anchor_button() -> Button:
    var button := Button.new()
    button.size = Vector2(100, 40)
    add_child(button)
    _owned_controls.append(button)
    return button


func _storage_anchors() -> Dictionary:
    return {
        "item_browser": _make_anchor_button(),
        "detail_rail": _make_anchor_button(),
        "repair_btn": _make_anchor_button(),
        "restore_btn": _make_anchor_button(),
        "research_btn": _make_anchor_button(),
        "ap_label": _make_anchor_button(),
        "leave_btn": _make_anchor_button(),
    }

# ══ Accessor lifecycle ═════════════════════════════════════════════════════


func test_accessors_return_active_state_while_playing() -> void:
    Director.start_script("hub")
    assert_eq(Director.step_index(), 0, "step_index starts at 0")
    assert_eq(Director.step_count(), HUB_SCRIPT_SIZE, "step_count matches hub script size")
    assert_true(Director.step_anchor_id(0) == "slot_label", "first step anchor is slot_label")
    assert_false(Director.is_offer_showing(), "is_offer_showing is false during hint playback")


func test_accessors_reset_after_end() -> void:
    Director.start_script("hub")
    # Advance through all steps to trigger _end_tutorial via public API.
    for i in HUB_SCRIPT_SIZE:
        Director.advance_step()
    assert_eq(Director.step_index(), 0, "step_index resets after end")
    assert_eq(Director.step_count(), 0, "step_count is 0 after end")
    assert_false(Director.is_offer_showing(), "is_offer_showing is false after end")


func test_accessors_reset_after_scene_registration() -> void:
    Director.start_script("hub")
    Director.register_scene("storage", { })
    assert_eq(Director.step_index(), 0, "step_index resets to 0 after new scene registration")
    assert_eq(Director.step_count(), 0, "step_count is 0 after new scene registration")

# ══ Missing anchors auto-skip ══════════════════════════════════════════════


func test_missing_anchor_skips_step_without_crash() -> void:
    var partial_anchors := {
        "slot_label": _make_anchor_button(),
    }
    Director.register_scene("hub_partial [DEBUG-PASS]", partial_anchors)
    Director.start_script("hub")
    # Step 0: slot_label (exists) → shown.
    # Advance to step 1 (POPUP, no anchor), then step 2 (storage_btn MISSING).
    Director.advance_step()
    Director.advance_step()
    # Step 2's missing storage_btn triggers auto-skip → tutorial ends.
    assert_eq(Director.step_count(), 0, "tutorial ended after missing anchor auto-skip")
    assert_eq(Director.step_index(), 0, "step_index reset after missing anchor")

# ══ Anchor fallback resolution ════════════════════════════════════════════


func test_anchor_fallback_resolves_when_primary_hidden() -> void:
    var anchors := {
        "item_browser": _make_anchor_button(),
        "detail_rail": _make_anchor_button(),
        "repair_btn": _make_anchor_button(),
        "restore_btn": _make_anchor_button(),
        "research_btn": _make_anchor_button(),
        "ap_label": _make_anchor_button(),
        "leave_btn": _make_anchor_button(),
    }
    anchors["repair_btn"].hide()
    Director.register_scene("storage", anchors)
    Director.start_script("storage")
    # Advance through steps 0 (POPUP), 1 (item_browser), 2 (detail_rail).
    Director.advance_step()
    Director.advance_step()
    Director.advance_step()
    # Step 3 (merged repair/restore, fallback enabled) resolves via restore_btn.
    assert_eq(Director.step_index(), 3, "step index 3 after advance to merged repair step")
    assert_eq(Director.step_count(), STORAGE_SCRIPT_SIZE, "tutorial still active after fallback resolution")


func test_anchor_fallback_disabled_skips_when_primary_hidden() -> void:
    var partial_anchors := {
        "slot_label": _make_anchor_button(),
        "storage_btn": _make_anchor_button(),
    }
    partial_anchors["slot_label"].hide()
    Director.register_scene("hub_hidden [DEBUG-PASS]", partial_anchors)
    Director.start_script("hub")
    # Step 0 (slot_label, HINT) hidden with no fallback → skip to step 1 (POPUP).
    assert_eq(Director.step_index(), 1, "step index 1 after hidden primary with no fallback")


func test_anchor_fallback_all_hidden_skips() -> void:
    var anchors := {
        "item_browser": _make_anchor_button(),
        "detail_rail": _make_anchor_button(),
        "repair_btn": _make_anchor_button(),
        "restore_btn": _make_anchor_button(),
        "research_btn": _make_anchor_button(),
        "ap_label": _make_anchor_button(),
        "leave_btn": _make_anchor_button(),
    }
    anchors["repair_btn"].hide()
    anchors["restore_btn"].hide()
    Director.register_scene("storage [DEBUG-PASS]", anchors)
    Director.start_script("storage")
    # Advance through steps 0-2.
    Director.advance_step()
    Director.advance_step()
    Director.advance_step()
    # Step 3: primary hidden, fallback hidden, both non-renderable → skip.
    # Step 4 (research_btn) should render next.
    assert_eq(Director.step_index(), 4, "step index 4 after all-anchor skip of step 3")
    assert_eq(Director.step_count(), STORAGE_SCRIPT_SIZE, "tutorial still active after skip")

# ══ Offer acceptance ══════════════════════════════════════════════════════


func test_offer_accept_emits_signal() -> void:
    watch_signals(Director)
    # Register storage anchors so that accepting the offer (which triggers
    # start_script("storage") via ScriptDirector) doesn't produce anchor
    # validation errors that would fail the test.
    Director.register_scene("storage", _storage_anchors())
    Director.show_offer_prompt("storage", "Test offer?", "Accept")
    assert_true(Director.is_offer_showing(), "offer is showing after show_offer_prompt")
    Director.accept_offer()
    assert_signal_emitted(Director, "offer_accepted")
    var params = get_signal_parameters(Director, "offer_accepted")
    if params != null and (params as Array).size() > 0:
        assert_eq((params as Array)[0], "storage")

# ══ Unknown script id ═════════════════════════════════════════════════════


func test_unknown_script_id_does_not_stick_offer() -> void:
    Director.start_script(UNKNOWN_SCRIPT_ID)
    # start_script with unknown script calls _hide_overlay() → _clear_playback_state()
    assert_eq(Director.step_count(), 0, "step_count is 0 after unknown script")
    assert_eq(Director.step_index(), 0, "step_index is 0 after unknown script")
    assert_false(Director.is_offer_showing(), "no offer popup stuck after unknown script")


func test_unknown_script_accept_offer_resets_state() -> void:
    Director.show_offer_prompt(UNKNOWN_OFFER_ID, "Bad offer?", "Accept")
    # Offer is showing, but the script doesn't exist.
    Director.accept_offer()
    # accept_offer checks resolve_script and falls back with dev error.
    assert_false(Director.is_offer_showing(), "offer dismissed after unresolving accept")
    assert_eq(Director.step_count(), 0, "state cleared after unresolving offer accept")
    assert_eq(Director.step_index(), 0, "step index reset after unresolving offer accept")

# ══ Tutorial-seen tracking ═══════════════════════════════════════════════


func test_completing_tutorial_marks_seen() -> void:
    assert_false(
        MetaManager.progress.tutorial_seen.has("hub"),
        "hub not seen before tutorial completes",
    )
    Director.start_script("hub")
    # Advance through all steps to trigger _end_tutorial.
    for i in HUB_SCRIPT_SIZE:
        Director.advance_step()
    assert_true(
        MetaManager.progress.tutorial_seen.has("hub"),
        "hub marked seen after completing all steps",
    )

# ══ Script registry ═══════════════════════════════════════════════════════════


func test_known_script_ids_resolve() -> void:
    for id: String in TutorialScripts.known_script_ids():
        assert_false(
            TutorialScripts.resolve_script(id).is_empty(),
            "script '%s' resolves to steps" % id,
        )


func test_unknown_script_id_returns_empty() -> void:
    assert_true(
        TutorialScripts.resolve_script("nonexistent_registry_test [DEBUG-PASS]").is_empty(),
        "unknown id returns empty",
    )


func test_validate_anchors_finds_missing() -> void:
    var missing := TutorialScripts.validate_anchors("hub", { "slot_label": _make_anchor_button() })
    assert_true("storage_btn" in missing, "storage_btn reported missing")


func test_validate_anchors_empty_when_all_present() -> void:
    var full_anchors := {
        "slot_label": _make_anchor_button(),
        "storage_btn": _make_anchor_button(),
    }
    var missing := TutorialScripts.validate_anchors("hub", full_anchors)
    assert_true(missing.is_empty(), "no missing anchors when all present")


func _make_tutorial_target(id: String, use_custom: bool = false, custom: Rect2 = Rect2()) -> TutorialTarget:
    var t := TutorialTarget.new()
    t.target_id = id
    t.use_custom_rect = use_custom
    t.custom_rect = custom
    t.size = Vector2(200, 100)
    add_child(t)
    _owned_controls.append(t)
    return t

# ══ TutorialTarget resolution ════════════════════════════════════════


func test_target_with_custom_rect_uses_smaller_rect() -> void:
    var target := _make_tutorial_target("custom_target", true, Rect2(10, 10, 50, 30))
    Director.register_scene("target_test [DEBUG-PASS]", { "custom_target": target })
    var rect := Director.get_target_rect("custom_target")
    assert_eq(rect.size, Vector2(50, 30), "custom rect size used")
    assert_eq(rect.position, target.global_position + Vector2(10, 10), "custom rect position offset from target origin")


func test_target_without_custom_rect_uses_global_rect() -> void:
    var target := _make_tutorial_target("plain_target")
    Director.register_scene("target_test [DEBUG-PASS]", { "plain_target": target })
    var rect := Director.get_target_rect("plain_target")
    assert_eq(rect.size, Vector2(200, 100), "full global rect size used when custom_rect is off")


func test_plain_control_anchor_still_works_via_get_target_rect() -> void:
    var btn := _make_anchor_button()
    Director.register_scene("compat_test [DEBUG-PASS]", { "my_btn": btn })
    var rect := Director.get_target_rect("my_btn")
    assert_eq(rect.size, Vector2(100, 40), "plain Control rect returned by get_target_rect")


func test_get_target_rect_unknown_id_returns_empty() -> void:
    var rect := Director.get_target_rect("does_not_exist")
    assert_eq(rect.size, Vector2(0, 0), "unknown id returns empty Rect2")


func test_mixed_registration_control_and_target_resolves() -> void:
    var btn := _make_anchor_button()
    var target := _make_tutorial_target("targ", true, Rect2(0, 0, 60, 60))
    Director.register_scene("mixed [DEBUG-PASS]", { "btn": btn, "targ": target })

    assert_eq(Director.get_target_rect("btn").size, Vector2(100, 40), "Control rect ok")
    assert_eq(Director.get_target_rect("targ").size, Vector2(60, 60), "TutorialTarget rect ok")

# ══ Preferred-side placement fallback ════════════════════════════════


func test_preferred_side_is_stored_on_target() -> void:
    var target := _make_tutorial_target("pref")
    target.preferred_side = TutorialTarget.PreferredSide.TOP
    assert_eq(target.preferred_side, TutorialTarget.PreferredSide.TOP, "preferred_side stores TOP")


func test_auto_preferred_side_default() -> void:
    var target := _make_tutorial_target("auto")
    assert_eq(target.preferred_side, TutorialTarget.PreferredSide.AUTO, "default preferred_side is AUTO")

# ══ Full-viewport centered fallback ══════════════════════════════════


func test_full_viewport_target_uses_centered_fallback() -> void:
    var screen := Director.get_viewport().get_visible_rect().size
    var big_btn := Button.new()
    big_btn.size = screen * 0.95 # large enough to trigger ≥90% fallback
    add_child(big_btn)
    _owned_controls.append(big_btn)

    Director.register_scene("big [DEBUG-PASS]", { "big": big_btn })
    var rect := Director.get_target_rect("big")
    assert_true(rect.size.x >= screen.x * 0.9, "target rect is >= 90% screen width")
    assert_true(rect.size.y >= screen.y * 0.9, "target rect is >= 90% screen height")

# ══ Target fallback across types ═════════════════════════════════════


func test_tutorial_target_fallback_resolves_when_primary_hidden() -> void:
    var primary := _make_tutorial_target("target_btn")
    primary.visible = false
    var fallback := _make_tutorial_target("fallback_target")
    Director.register_scene(
        "tgt_fallback [DEBUG-PASS]",
        {
            "target_btn": primary,
            "fallback_target": fallback,
        },
    )
    # The primary TutorialTarget is hidden; get_target_rect should return empty.
    var primary_rect := Director.get_target_rect("target_btn")
    assert_eq(primary_rect.size, Vector2(0, 0), "hidden primary target returns empty rect")
    # The fallback TutorialTarget renders normally.
    var fallback_rect := Director.get_target_rect("fallback_target")
    assert_eq(fallback_rect.size, Vector2(200, 100), "visible fallback target rect ok")
