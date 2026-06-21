# test_director.gd
# Director accessor lifecycle, unknown-script fallback, offer acceptance, and
# tutorial-seen tracking. Tests now use synthetic scene ids ("test_hub",
# "test_storage") to avoid ScriptDirector auto-start from tests.
extends GutTest

const HUB_SCRIPT_SIZE := 3
const STORAGE_SCRIPT_SIZE := 8
const UNKNOWN_SCRIPT_ID := "nonexistent_script [DEBUG-PASS]"
const UNKNOWN_OFFER_ID := "nonexistent_offer [DEBUG-PASS]"

var _hub_anchors: Dictionary = { }
var _owned_controls: Array[Control] = []
var _previous_tutorial_skip_all := false


func before_all() -> void:
    _previous_tutorial_skip_all = SettingsStore.tutorial_skip_all
    SettingsStore.tutorial_skip_all = false
    MetaManager.reset()


func before_each() -> void:
    SettingsStore.tutorial_skip_all = false
    MetaManager.reset()
    _hub_anchors = {
        "slot_label": _make_anchor_button(),
        "storage_btn": _make_anchor_button(),
    }
    # Use a synthetic scene id so ScriptDirector does not auto-start tutorials.
    Director.register_scene("test_hub [DIRECTOR-TEST]", _hub_anchors)


func after_each() -> void:
    ScriptDirector.reset_runtime()
    SettingsStore.tutorial_skip_all = false
    for control: Control in _owned_controls:
        if is_instance_valid(control):
            control.free()
    _owned_controls.clear()
    _hub_anchors.clear()


func after_all() -> void:
    SettingsStore.tutorial_skip_all = _previous_tutorial_skip_all


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


func _assert_forced_activity_payload(expected: StringName, message: String) -> void:
    var payload: Variant = GameplayOverride.payload(GameplayOverride.FORCED_ACTIVITY)
    assert_eq(typeof(payload), TYPE_STRING_NAME, "%s payload should be StringName" % message)
    if typeof(payload) != TYPE_STRING_NAME:
        return
    assert_eq(payload, expected, message)

# ══ Accessor lifecycle ═════════════════════════════════════════════════════


func test_accessors_return_active_state_while_playing() -> void:
    Director.start_script("hub")
    assert_eq(Director.step_index(), 0, "step_index starts at 0")
    assert_eq(Director.step_count(), HUB_SCRIPT_SIZE, "step_count matches hub script size")
    assert_eq(Director.step_anchor_id(0), "slot_label", "first step anchor is slot_label")
    assert_false(Director.is_offer_showing(), "is_offer_showing is false during hint playback")


func test_accessors_reset_after_end() -> void:
    Director.start_script("hub")
    # Advance steps 0 (NEXT) and 1 (NEXT). Step 2 is SCENE_ENTERED and will
    # not advance from advance_step(). We register "storage" to complete it.
    Director.advance_step()
    Director.advance_step()
    Director.register_scene("storage", { "storage_btn": _make_anchor_button() })
    assert_eq(Director.step_index(), 0, "step_index resets after end")
    assert_eq(Director.step_count(), 0, "step_count is 0 after end")
    assert_false(Director.is_offer_showing(), "is_offer_showing is false after end")


func test_accessors_survive_scene_registration() -> void:
    Director.start_script("hub")
    # Scene registration no longer clears tutorial state.
    Director.register_scene("test_storage [DIRECTOR-TEST]", { })
    assert_eq(Director.step_index(), 0, "step_index preserved after scene registration")
    assert_eq(Director.step_count(), HUB_SCRIPT_SIZE, "step_count preserved after scene registration")

# ══ Missing anchors — NEXT steps are skipped; SCENE_ENTERED steps wait ════


func test_missing_anchor_skips_next_step_without_crash() -> void:
    var partial_anchors := {
        "slot_label": _make_anchor_button(),
    }
    Director.register_scene("partial_hub [DEBUG-PASS]", partial_anchors)
    Director.start_script("hub")
    # Step 0 (slot_label, NEXT): anchor exists → renders.
    # Advance to step 1 (POPUP, no anchor): renders.
    Director.advance_step()
    # Step 2 (storage_btn, SCENE_ENTERED): anchor missing but advance is
    # SCENE_ENTERED, so it waits rather than skipping.
    Director.advance_step()
    assert_eq(Director.step_index(), 2, "step 2 reached but SCENE_ENTERED waits")
    assert_eq(Director.step_count(), HUB_SCRIPT_SIZE, "tutorial still active")

    # Registering the matching scene completes the step.
    Director.register_scene("storage", { "storage_btn": _make_anchor_button() })
    assert_eq(Director.step_count(), 0, "tutorial ended after scene registration")

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
    Director.register_scene("test_storage [DEBUG-PASS]", anchors)
    Director.start_script("onboarding_storage")
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
    Director.register_scene("partial_hub [DEBUG-PASS]", partial_anchors)
    Director.start_script("hub")
    # Step 0 (slot_label, HINT, NEXT) hidden with no fallback → skip to step 1 (POPUP).
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
    Director.register_scene("test_storage [DEBUG-PASS]", anchors)
    Director.start_script("onboarding_storage")
    # Advance through steps 0-2.
    Director.advance_step()
    Director.advance_step()
    Director.advance_step()
    # Step 3 is NEXT; both primary and fallback condition anchors hidden, so the
    # step is skipped and tutorial advances to step 4 (research_btn).
    assert_eq(Director.step_index(), 4, "next step skipped when all condition anchors are hidden")
    assert_eq(Director.step_count(), STORAGE_SCRIPT_SIZE, "tutorial still active while waiting")

# ══ Offer acceptance ══════════════════════════════════════════════════════


func test_offer_accept_emits_signal() -> void:
    watch_signals(Director)
    # Register storage anchors so that accepting the offer does not produce
    # anchor validation errors.
    Director.register_scene("test_storage [DIRECTOR-TEST]", _storage_anchors())
    Director.show_offer_prompt("onboarding_storage", "Test offer?", "Accept")
    assert_true(Director.is_offer_showing(), "offer is showing after show_offer_prompt")
    Director.accept_offer()
    assert_signal_emitted(Director, "offer_accepted")
    var params = get_signal_parameters(Director, "offer_accepted")
    if params != null and (params as Array).size() > 0:
        assert_eq((params as Array)[0], "onboarding_storage")

# ══ Unknown script id ═════════════════════════════════════════════════════


func test_unknown_script_id_does_not_stick_offer() -> void:
    Director.start_script(UNKNOWN_SCRIPT_ID)
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
    # Advance through NEXT steps (0, 1), then register "storage" to complete
    # the SCENE_ENTERED step (2).
    Director.advance_step()
    Director.advance_step()
    Director.register_scene("storage", { "storage_btn": _make_anchor_button() })
    assert_true(
        MetaManager.progress.tutorial_seen.has("hub"),
        "hub marked seen after completing all steps",
    )


func test_reset_runtime_clears_active_tutorial_without_marking_seen() -> void:
    Director.start_script("hub")
    assert_eq(Director.step_count(), HUB_SCRIPT_SIZE, "tutorial active before reset")

    ScriptDirector.reset_runtime()

    assert_eq(Director.step_count(), 0, "tutorial cleared after runtime reset")
    assert_eq(Director.step_index(), 0, "step index reset after runtime reset")
    assert_false(
        MetaManager.progress.tutorial_seen.has("hub"),
        "runtime reset should not mark tutorial seen",
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
    var missing := TutorialScripts.validate_anchors("onboarding_storage", { "item_browser": _make_anchor_button() })
    assert_true("detail_rail" in missing, "detail_rail reported missing")


func test_validate_anchors_empty_when_all_present() -> void:
    var missing := TutorialScripts.validate_anchors("onboarding_storage", _storage_anchors())
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
    big_btn.size = screen * 0.95
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
    var primary_rect := Director.get_target_rect("target_btn")
    assert_eq(primary_rect.size, Vector2(0, 0), "hidden primary target returns empty rect")
    var fallback_rect := Director.get_target_rect("fallback_target")
    assert_eq(fallback_rect.size, Vector2(200, 100), "visible fallback target rect ok")

# ══ Onboarding resolver and segment tests ══════════════════════════


func test_onboarding_resolver_starts_hub_segment() -> void:
    # after before_each: day 0, slot DAY, onboarding_pending=true.
    # Register the real "hub" id so the onboarding resolver matches.
    Director.register_scene("hub", { "activity_btn": _make_anchor_button(), "auction_btn": _make_anchor_button() })
    assert_true(ScriptDirector.active, "onboarding segment should start for hub scene")
    assert_eq(Director.step_count(), 3, "onboarding_hub_intro_choose has 3 steps")


func test_onboarding_resolver_skips_when_segment_seen() -> void:
    MetaManager.progress.mark_tutorial_seen("onboarding_hub_intro_choose")
    Director.register_scene("hub", { "activity_btn": _make_anchor_button(), "auction_btn": _make_anchor_button() })
    assert_false(ScriptDirector.active, "onboarding should not start when segment already seen")


func test_trigger_onboarding_storage_choose_starts_independent_of_run() -> void:
    # storage_choose no longer requires auction_run seen; its own trigger
    # (night hub, day 0, onboarding_pending) decides independently.
    MetaManager.slot.set_slot(SlotStore.SLOT_NIGHT)
    Director.register_scene("hub", { "activity_btn": _make_anchor_button(), "storage_btn": _make_anchor_button() })
    assert_true(ScriptDirector.active, "storage_choose should start from its own trigger when conditions match")


func test_onboarding_resolver_supports_storage_choose() -> void:
    MetaManager.slot.set_slot(SlotStore.SLOT_NIGHT)
    Director.register_scene("hub", { "activity_btn": _make_anchor_button(), "storage_btn": _make_anchor_button() })
    assert_true(ScriptDirector.active, "onboarding storage_choose should start for night hub")
    assert_eq(Director.step_count(), 3, "onboarding_storage_choose has 3 steps")


func test_onboarding_resolver_does_not_interfere_with_synthetic_scenes() -> void:
    # Registering a synthetic scene id should not trigger onboarding.
    Director.register_scene("synthetic_onboarding_test [DEBUG-PASS]", { })
    assert_false(ScriptDirector.active, "synthetic scene should not start onboarding")


func test_onboarding_scripts_resolve() -> void:
    var ids := [
        "onboarding_hub_intro_choose",
        "onboarding_location_select",
        "onboarding_lot_browse",
        "onboarding_inspection",
        "onboarding_auction",
        "onboarding_reveal",
        "onboarding_cargo",
        "onboarding_run_review",
        "onboarding_storage_choose",
        "onboarding_storage",
        "onboarding_day_pass",
        "onboarding_shop_choose",
        "onboarding_selling",
    ]
    for id: String in ids:
        var steps := TutorialScripts.resolve_script(id)
        assert_false(steps.is_empty(), "onboarding script '%s' should resolve" % id)


func test_onboarding_close_marks_unit_seen_only() -> void:
    ScriptDirector.start_script("onboarding_hub_intro_choose")
    assert_true(ScriptDirector.active, "onboarding script should be active")
    assert_true(MetaManager.is_onboarding_pending(), "onboarding pending before close")
    ScriptDirector.stop_script()
    assert_false(ScriptDirector.active, "script should not be active after close")
    assert_true(MetaManager.is_onboarding_pending(), "onboarding should STILL be pending after single-unit close")
    assert_true(MetaManager.progress.tutorial_seen.has("onboarding_hub_intro_choose"), "closed unit should be marked seen")


func test_skip_all_onboarding_clears_chain() -> void:
    ScriptDirector.start_script("onboarding_hub_intro_choose")
    assert_true(MetaManager.is_onboarding_pending(), "onboarding pending before skip all")
    Director.skip_all_onboarding()
    assert_false(ScriptDirector.active, "script should not be active after skip all")
    assert_false(MetaManager.is_onboarding_pending(), "onboarding should be cleared after skip all")
    assert_eq(
        GameplayOverride.payload(GameplayOverride.FORCED_ACTIVITY) as Variant,
        null,
        "skip all clears forced_activity immediately",
    )
    assert_true(
        MetaManager.progress.tutorial_seen.has("onboarding_hub_intro_choose"),
        "skip all marks hub_intro_choose seen",
    )
    assert_true(
        MetaManager.progress.tutorial_seen.has("onboarding_selling"),
        "skip all marks selling seen",
    )


func test_selling_segment_completes_onboarding() -> void:
    MetaManager.progress.reset_onboarding()
    assert_true(MetaManager.is_onboarding_pending(), "onboarding pending before test")
    # Register all anchors the selling script references.
    var anchors := {
        "customer_queue": _make_anchor_button(),
        "item_list": _make_anchor_button(),
        "car_panel": _make_anchor_button(),
        "deal_panel": _make_anchor_button(),
        "back_btn": _make_anchor_button(),
    }
    Director.register_scene("customer_sell", anchors)
    ScriptDirector.start_script("onboarding_selling")
    # Steps 0-2 are NEXT (popup, customer, item card).
    Director.advance_step() # 0
    Director.advance_step() # 1
    Director.advance_step() # 2
    # Step 3: car grid placement, EVENT (SELL_ITEM_PLACED).
    assert_eq(Director.step_index(), 3, "at car grid step")
    EventBus.tutorial_event.emit(TutorialEvents.SELL_ITEM_PLACED, { })
    # Step 4: conservative, NEXT.
    assert_eq(Director.step_index(), 4, "at conservative step")
    Director.advance_step()
    # Step 5: aggressive, EVENT.
    assert_eq(Director.step_index(), 5, "at aggressive step")
    EventBus.tutorial_event.emit(TutorialEvents.SELL_AGGRESSIVE_REQUESTED, { })
    # Step 6: dice, EVENT (DICE_TOGGLED).
    assert_eq(Director.step_index(), 6, "at dice step")
    EventBus.tutorial_event.emit(TutorialEvents.DICE_TOGGLED, { })
    # Step 7: confirm sale, EVENT (SALE_COMPLETED).
    assert_eq(Director.step_index(), 7, "at confirm step")
    EventBus.tutorial_event.emit(TutorialEvents.SALE_COMPLETED, { })
    # Step 8: back_btn, NEXT.
    assert_eq(Director.step_index(), 8, "at leave step")
    Director.advance_step()
    assert_false(ScriptDirector.active, "script should end after leave step")
    assert_false(MetaManager.is_onboarding_pending(), "onboarding should be complete after selling segment")


func test_auction_resolved_event_constant_exists() -> void:
    assert_eq(typeof(TutorialEvents.AUCTION_RESOLVED), TYPE_STRING_NAME, "AUCTION_RESOLVED should be a StringName")


func test_chooser_opened_event_constant_exists() -> void:
    assert_eq(typeof(TutorialEvents.CHOOSER_OPENED), TYPE_STRING_NAME, "CHOOSER_OPENED should be a StringName")

# ══ New onboarding chain and event tests ═══════════════════════════


func test_onboarding_location_select_starts_auction_segment() -> void:
    # day 0, slot DAY, onboarding pending + prereq seen → triggers auction.
    MetaManager.progress.mark_tutorial_seen("onboarding_hub_intro_choose")
    Director.register_scene("location_select", { "cards_container": _make_anchor_button() })
    assert_true(ScriptDirector.active, "auction_run should start for location_select")


func test_onboarding_day_pass_starts_when_prereqs_met() -> void:
    MetaManager.progress.mark_tutorial_seen("onboarding_storage_choose")
    MetaManager.progress.mark_tutorial_seen("onboarding_storage")
    Director.register_scene("day_summary", { "continue_btn": _make_anchor_button() })
    assert_true(ScriptDirector.active, "day_pass should start for day_summary when prereqs met")


func test_onboarding_selling_skipped_when_storage_empty() -> void:
    MetaManager.progress.reset_onboarding()
    MetaManager.progress.mark_tutorial_seen("onboarding_storage_choose")
    MetaManager.progress.mark_tutorial_seen("onboarding_storage")
    MetaManager.progress.mark_tutorial_seen("onboarding_day_pass")
    MetaManager.progress.mark_tutorial_seen("onboarding_shop_choose")
    Director.register_scene("customer_sell", { "customer_queue": _make_anchor_button() })
    assert_false(ScriptDirector.active, "selling segment should not start with empty storage")


func test_onboarding_day_summary_event_advances() -> void:
    ScriptDirector.start_script("onboarding_day_pass")
    assert_true(ScriptDirector.active, "tutorial active on day summary hint")
    assert_eq(Director.step_index(), 0, "day summary waits at continue hint")
    EventBus.tutorial_event.emit(TutorialEvents.DAY_SUMMARY_CONTINUED, { })
    assert_false(ScriptDirector.active, "tutorial should end after DAY_SUMMARY_CONTINUED")


func test_onboarding_bid_placed_event_advances() -> void:
    ScriptDirector.start_script("onboarding_auction")
    # The auction script has 2 EVENT steps: BID_PLACED then AUCTION_RESOLVED.
    assert_eq(Director.step_index(), 0, "at step 0 (bid) after start")
    assert_true(ScriptDirector.active, "tutorial active at bid step")
    EventBus.tutorial_event.emit(TutorialEvents.BID_PLACED, { })
    assert_true(ScriptDirector.active, "tutorial active after bid")
    assert_eq(Director.step_index(), 1, "at step 1 (auction wait) after bid")
    EventBus.tutorial_event.emit(TutorialEvents.AUCTION_RESOLVED, { })
    assert_false(ScriptDirector.active, "tutorial should end after auction resolved")


func test_onboarding_storage_completes_on_scene_entered_hub() -> void:
    Director.register_scene("storage", _storage_anchors())
    ScriptDirector.start_script("onboarding_storage")
    # Repair and Research steps are NEXT — player clicks Next to advance, no event
    # required. Walk to the last step, then complete it by registering hub.
    var step_count := Director.step_count()
    Director.advance_step()
    Director.advance_step()
    Director.advance_step()
    assert_eq(Director.step_index(), 3, "at repair hint step")
    Director.advance_step()
    assert_eq(Director.step_index(), 4, "at research hint step")
    Director.advance_step()
    while Director.step_index() < step_count - 1:
        Director.advance_step()
    assert_eq(Director.step_index(), step_count - 1, "at last step")
    assert_true(ScriptDirector.active, "tutorial active waiting for hub scene")
    # Registering hub completes the SCENE_ENTERED step.
    Director.register_scene("hub", { "storage_btn": _make_anchor_button(), "activity_btn": _make_anchor_button(), "sell_btn": _make_anchor_button() })
    assert_false(ScriptDirector.active, "tutorial should end after hub scene registered")


func test_new_event_constants_exist() -> void:
    assert_eq(typeof(TutorialEvents.BID_PLACED), TYPE_STRING_NAME, "BID_PLACED should be a StringName")
    assert_eq(typeof(TutorialEvents.DAY_SUMMARY_CONTINUED), TYPE_STRING_NAME, "DAY_SUMMARY_CONTINUED should be a StringName")
    assert_eq(typeof(TutorialEvents.INSPECTION_ITEM_SELECTED), TYPE_STRING_NAME, "INSPECTION_ITEM_SELECTED should be a StringName")
    assert_eq(typeof(TutorialEvents.INSPECTION_ITEM_UNVEILED), TYPE_STRING_NAME, "INSPECTION_ITEM_UNVEILED should be a StringName")
    assert_eq(typeof(TutorialEvents.INSPECTION_REVIEW_OPENED), TYPE_STRING_NAME, "INSPECTION_REVIEW_OPENED should be a StringName")
    assert_eq(typeof(TutorialEvents.INSPECTION_AUCTION_STARTED), TYPE_STRING_NAME, "INSPECTION_AUCTION_STARTED should be a StringName")
    assert_eq(typeof(TutorialEvents.CARGO_ITEM_SELECTED), TYPE_STRING_NAME, "CARGO_ITEM_SELECTED should be a StringName")
    assert_eq(typeof(TutorialEvents.CARGO_ITEM_PLACED), TYPE_STRING_NAME, "CARGO_ITEM_PLACED should be a StringName")
    assert_eq(typeof(TutorialEvents.CARGO_CONTINUE_REQUESTED), TYPE_STRING_NAME, "CARGO_CONTINUE_REQUESTED should be a StringName")
    assert_eq(typeof(TutorialEvents.STORAGE_CONDITION_IMPROVED), TYPE_STRING_NAME, "STORAGE_CONDITION_IMPROVED should be a StringName")
    assert_eq(typeof(TutorialEvents.STORAGE_RESEARCH_PERFORMED), TYPE_STRING_NAME, "STORAGE_RESEARCH_PERFORMED should be a StringName")

# ══ GameplayOverride tests ════════════════════════════════════════════════
# Unit-scoped overrides are activated/deactivated by ScriptDirector as units
# start, stop, or release. Onboarding-scoped overrides are refreshed on every
# scene registration. Runtime reset clears everything.


func test_assisted_auction_activated_on_start() -> void:
    ScriptDirector.start_script("onboarding_auction")
    assert_true(
        GameplayOverride.is_active(GameplayOverride.ASSISTED_AUCTION),
        "assisted_auction active when onboarding_auction is playing",
    )


func test_assisted_auction_deactivated_on_stop() -> void:
    ScriptDirector.start_script("onboarding_auction")
    ScriptDirector.stop_script()
    assert_false(
        GameplayOverride.is_active(GameplayOverride.ASSISTED_AUCTION),
        "assisted_auction inactive after onboarding_auction stops",
    )


func test_assisted_auction_deactivated_on_completion() -> void:
    ScriptDirector.start_script("onboarding_auction")
    assert_true(
        GameplayOverride.is_active(GameplayOverride.ASSISTED_AUCTION),
        "assisted_auction active after start",
    )
    # Drive the 2-step script to completion via its EVENT advances.
    EventBus.tutorial_event.emit(TutorialEvents.BID_PLACED, { })
    EventBus.tutorial_event.emit(TutorialEvents.AUCTION_RESOLVED, { })
    assert_false(
        GameplayOverride.is_active(GameplayOverride.ASSISTED_AUCTION),
        "assisted_auction inactive after tutorial completes naturally",
    )


func test_assisted_auction_not_active_with_wrong_script() -> void:
    ScriptDirector.start_script("onboarding_inspection")
    assert_false(
        GameplayOverride.is_active(GameplayOverride.ASSISTED_AUCTION),
        "assisted_auction inactive when a non-auction script is active",
    )
    ScriptDirector.stop_script()


func test_assisted_auction_not_active_with_no_script() -> void:
    assert_false(
        GameplayOverride.is_active(GameplayOverride.ASSISTED_AUCTION),
        "assisted_auction inactive when no script is active",
    )


func test_lot_pass_locked_activated_on_start() -> void:
    ScriptDirector.start_script("onboarding_lot_browse")
    assert_true(
        GameplayOverride.is_active(GameplayOverride.LOT_PASS_LOCKED),
        "lot_pass_locked active when lot_browse is playing",
    )
    ScriptDirector.stop_script()


func test_lot_pass_locked_deactivated_on_stop() -> void:
    ScriptDirector.start_script("onboarding_lot_browse")
    ScriptDirector.stop_script()
    assert_false(
        GameplayOverride.is_active(GameplayOverride.LOT_PASS_LOCKED),
        "lot_pass_locked inactive after lot_browse stops",
    )


func test_lot_pass_locked_deactivated_on_completion() -> void:
    ScriptDirector.start_script("onboarding_lot_browse")
    assert_true(
        GameplayOverride.is_active(GameplayOverride.LOT_PASS_LOCKED),
        "lot_pass_locked active after start",
    )
    EventBus.tutorial_event.emit(TutorialEvents.LOT_SELECTED, { })
    assert_false(
        GameplayOverride.is_active(GameplayOverride.LOT_PASS_LOCKED),
        "lot_pass_locked inactive after tutorial completes naturally",
    )


func test_inspection_review_gated_active_early_step() -> void:
    ScriptDirector.start_script("onboarding_inspection")
    assert_true(
        GameplayOverride.is_active(GameplayOverride.INSPECTION_REVIEW_GATED),
        "inspection_review_gated active when onboarding_inspection starts",
    )
    ScriptDirector.stop_script()


func test_inspection_review_gated_released_on_event() -> void:
    ScriptDirector.start_script("onboarding_inspection")
    # Emit events for steps 0 (ITEM_SELECTED), 1 (ITEM_UNVEILED), 2 (INSPECTION_PERFORMED).
    EventBus.tutorial_event.emit(TutorialEvents.INSPECTION_ITEM_SELECTED, { })
    EventBus.tutorial_event.emit(TutorialEvents.INSPECTION_ITEM_UNVEILED, { })
    EventBus.tutorial_event.emit(TutorialEvents.INSPECTION_PERFORMED, { })
    # The override declares INSPECTION_PERFORMED as its release event.
    assert_false(
        GameplayOverride.is_active(GameplayOverride.INSPECTION_REVIEW_GATED),
        "inspection_review_gated released after INSPECTION_PERFORMED fires",
    )
    ScriptDirector.stop_script()


func test_inspection_review_gated_inactive_with_no_script() -> void:
    assert_false(
        GameplayOverride.is_active(GameplayOverride.INSPECTION_REVIEW_GATED),
        "inspection_review_gated inactive with no active script",
    )


func test_inspection_review_gated_deactivated_on_completion() -> void:
    ScriptDirector.start_script("onboarding_inspection")
    assert_true(
        GameplayOverride.is_active(GameplayOverride.INSPECTION_REVIEW_GATED),
        "inspection_review_gated active after start",
    )
    # Drive all 5 steps to completion: ITEM_SELECTED -> ITEM_UNVEILED ->
    # INSPECTION_PERFORMED -> REVIEW_OPENED -> AUCTION_STARTED.
    EventBus.tutorial_event.emit(TutorialEvents.INSPECTION_ITEM_SELECTED, { })
    EventBus.tutorial_event.emit(TutorialEvents.INSPECTION_ITEM_UNVEILED, { })
    EventBus.tutorial_event.emit(TutorialEvents.INSPECTION_PERFORMED, { })
    EventBus.tutorial_event.emit(TutorialEvents.INSPECTION_REVIEW_OPENED, { })
    EventBus.tutorial_event.emit(TutorialEvents.INSPECTION_AUCTION_STARTED, { })
    assert_false(
        GameplayOverride.is_active(GameplayOverride.INSPECTION_REVIEW_GATED),
        "inspection_review_gated inactive after tutorial completes naturally",
    )


func test_forced_activity_day0_day() -> void:
    # before_each: day 0, slot DAY, onboarding_pending=true.
    _assert_forced_activity_payload(&"auction", "day 0 day slot targets auction")


func test_forced_activity_day0_night() -> void:
    MetaManager.slot.set_slot(SlotStore.SLOT_NIGHT)
    Director.register_scene("refresh_night_overrides [DEBUG-PASS]", { })
    _assert_forced_activity_payload(&"storage", "day 0 night slot targets storage")


func test_forced_activity_not_pending() -> void:
    MetaManager.progress.mark_onboarding_complete()
    Director.register_scene("refresh_completed_overrides [DEBUG-PASS]", { })
    assert_eq(
        GameplayOverride.payload(GameplayOverride.FORCED_ACTIVITY) as Variant,
        null,
        "forced_activity cleared when onboarding not pending",
    )


func test_forced_tutorial_location_active_when_not_seen() -> void:
    # before_each: day 0, slot DAY, onboarding_pending=true.
    assert_true(
        GameplayOverride.is_active(GameplayOverride.FORCED_TUTORIAL_LOCATION),
        "forced_tutorial_location active when day 0 day slot, not seen",
    )


func test_forced_tutorial_location_inactive_when_seen() -> void:
    MetaManager.progress.mark_tutorial_seen("onboarding_location_select")
    Director.register_scene("refresh_seen_overrides [DEBUG-PASS]", { })
    assert_false(
        GameplayOverride.is_active(GameplayOverride.FORCED_TUTORIAL_LOCATION),
        "forced_tutorial_location inactive when location_select seen",
    )


func test_conservative_sale_locked_when_pending() -> void:
    # before_each: onboarding_pending=true, not seen.
    assert_true(
        GameplayOverride.is_active(GameplayOverride.CONSERVATIVE_SALE_LOCKED),
        "conservative_sale_locked active when onboarding pending",
    )


func test_conservative_sale_locked_not_when_not_pending() -> void:
    MetaManager.progress.mark_onboarding_complete()
    Director.register_scene("refresh_completed_overrides [DEBUG-PASS]", { })
    assert_false(
        GameplayOverride.is_active(GameplayOverride.CONSERVATIVE_SALE_LOCKED),
        "conservative_sale_locked inactive when onboarding not pending",
    )


func test_conservative_sale_locked_not_when_seen() -> void:
    MetaManager.progress.reset_onboarding()
    MetaManager.progress.mark_tutorial_seen("onboarding_selling")
    Director.register_scene("refresh_seen_overrides [DEBUG-PASS]", { })
    assert_false(
        GameplayOverride.is_active(GameplayOverride.CONSERVATIVE_SALE_LOCKED),
        "conservative_sale_locked inactive when selling seen",
    )


func test_runtime_reset_clears_overrides() -> void:
    ScriptDirector.start_script("onboarding_auction")
    assert_true(
        GameplayOverride.is_active(GameplayOverride.ASSISTED_AUCTION),
        "assisted_auction active before reset",
    )
    ScriptDirector.reset_runtime()
    assert_false(
        GameplayOverride.is_active(GameplayOverride.ASSISTED_AUCTION),
        "assisted_auction inactive after runtime reset",
    )
    assert_false(
        GameplayOverride.is_active(GameplayOverride.INSPECTION_REVIEW_GATED),
        "all overrides cleared after runtime reset",
    )


func test_override_changed_signal_on_activate() -> void:
    var state := { "fired": false, "received_id": &"" }
    GameplayOverride.override_changed.connect(
        func(id: StringName, _a: bool, _p: Variant) -> void:
            state.fired = true
            state.received_id = id
    )
    GameplayOverride.activate(GameplayOverride.ASSISTED_AUCTION, null)
    assert_true(state.fired, "override_changed fired on activate")
    assert_eq(state.received_id, GameplayOverride.ASSISTED_AUCTION, "override_changed carries the correct id")
    GameplayOverride.deactivate(GameplayOverride.ASSISTED_AUCTION)


func test_override_changed_signal_on_deactivate() -> void:
    GameplayOverride.activate(GameplayOverride.ASSISTED_AUCTION, null)
    var state := { "fired": false }
    GameplayOverride.override_changed.connect(
        func(_id: StringName, active: bool, _p: Variant) -> void:
            if not active:
                state.fired = true
    )
    GameplayOverride.deactivate(GameplayOverride.ASSISTED_AUCTION)
    assert_true(state.fired, "override_changed fired on deactivate")
