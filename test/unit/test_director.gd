# test_director.gd
# Director accessor lifecycle, unknown-script fallback, offer acceptance, and
# tutorial-seen tracking.
extends GutTest

const HUB_SCRIPT_SIZE := 3
const STORAGE_SCRIPT_SIZE := 9
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
    _owned_controls.append(button)
    return button

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
    Director.register_scene("hub_partial", partial_anchors)
    Director.start_script("hub")
    # Step 0: slot_label (exists) → shown.
    # Advance to step 1 (POPUP, no anchor), then step 2 (storage_btn MISSING).
    Director.advance_step()
    Director.advance_step()
    # Step 2's missing storage_btn triggers auto-skip → tutorial ends.
    assert_eq(Director.step_count(), 0, "tutorial ended after missing anchor auto-skip")
    assert_eq(Director.step_index(), 0, "step_index reset after missing anchor")

# ══ Offer acceptance ══════════════════════════════════════════════════════


func test_offer_accept_emits_signal() -> void:
    watch_signals(Director)
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
    # accept_offer checks _get_script and falls back with dev error.
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
