# tutorial_scripts.gd
# Static step arrays for hub and storage tutorials.
# Not autoloaded — imported by Director.
# The single surface for script id resolution, anchor validation, and unit registry.
class_name TutorialScripts

class TutorialOverrideSpec:
    var id: StringName
    var payload: Variant = null
    var release_event: StringName = &""


    static func whole(p_id: StringName, _payload: Variant = null) -> TutorialOverrideSpec:
        var s := TutorialOverrideSpec.new()
        s.id = p_id
        s.payload = _payload
        return s


    static func until(p_id: StringName, event: StringName) -> TutorialOverrideSpec:
        var s := TutorialOverrideSpec.new()
        s.id = p_id
        s.release_event = event
        return s


class TutorialUnit:
    var id: String
    var steps_resolver: Callable
    var trigger: Callable
    var once: bool = true
    var overrides: Array[TutorialOverrideSpec] = []


    func _init(p_id: String, p_resolver: Callable, p_trigger: Callable, p_once: bool = true) -> void:
        id = p_id
        steps_resolver = p_resolver
        trigger = p_trigger
        once = p_once


    func steps() -> Array[TutorialStep]:
        return steps_resolver.call() as Array[TutorialStep]


static func hub_script() -> Array[TutorialStep]:
    return [
        TutorialStep.hint(
            TranslationServer.translate("TUT_HUB_BODY"),
            "slot_label",
        ),
        TutorialStep.popup(
            TranslationServer.translate("TUT_HUB_CHOOSER_BODY"),
        ),
        TutorialStep.hint(
            TranslationServer.translate("TUT_HUB_STORAGE_NAVIGATE_BODY"),
            "storage_btn",
        ).unlock().on_scene("storage"),
    ]

# ══ Onboarding segment scripts ════════════════════════════════════════════════


## Day 1 Day hub intro + chooser: teaches the hub UI and steers the player to
## choose Auction.
static func onboarding_hub_intro_choose_script() -> Array[TutorialStep]:
    return [
        TutorialStep.popup(
            TranslationServer.translate("TUT_ONBOARDING_INTRO_TITLE"),
        ),
        TutorialStep.hint(
            TranslationServer.translate("TUT_HUB_ACTIVITY_CHOOSER_HINT"),
            "activity_btn",
        ).unlock().on_event(TutorialEvents.CHOOSER_OPENED),
        TutorialStep.hint(
            TranslationServer.translate("TUT_HUB_CHOOSE_AUCTION_HINT"),
            "auction_btn",
        ).unlock().on_event(TutorialEvents.ACTIVITY_CHOSEN),
    ]


## Day 1 Night hub chooser: tells the player to choose Storage.
static func onboarding_storage_choose_script() -> Array[TutorialStep]:
    return [
        TutorialStep.popup(
            TranslationServer.translate("TUT_STORAGE_CHOOSE_BODY"),
        ),
        TutorialStep.hint(
            TranslationServer.translate("TUT_HUB_CHOOSER_HINT"),
            "activity_btn",
        ).unlock().on_event(TutorialEvents.CHOOSER_OPENED),
        TutorialStep.hint(
            TranslationServer.translate("TUT_HUB_CHOOSE_STORAGE_HINT"),
            "storage_btn",
        ).unlock().on_event(TutorialEvents.ACTIVITY_CHOSEN),
    ]


## Storage workshop tutorial for onboarding. Inlines storage_script content
## with the final leave_btn step changed to SCENE_ENTERED hub so the
## tutorial completes when the player leaves the storage scene.
static func onboarding_storage_script() -> Array[TutorialStep]:
    return [
        TutorialStep.popup(
            TranslationServer.translate("TUT_WORKSHOP_INTRO_BODY"),
        ),
        TutorialStep.hint(
            TranslationServer.translate("TUT_WORKSHOP_ITEM_BROWSER_HINT"),
            "item_browser",
        ),
        TutorialStep.hint(
            TranslationServer.translate("TUT_WORKSHOP_DETAIL_RAIL_HINT"),
            "detail_rail",
        ),
        TutorialStep.hint(
            TranslationServer.translate("TUT_WORKSHOP_REPAIR_HINT"),
            "repair_btn",
        ).with_fallback(["restore_btn"]),
        TutorialStep.hint(
            TranslationServer.translate("TUT_WORKSHOP_RESEARCH_HINT"),
            "research_btn",
        ),
        TutorialStep.popup(
            TranslationServer.translate("TUT_WORKSHOP_APPRAISED_VS_VERIFIED_BODY"),
        ),
        TutorialStep.hint(
            TranslationServer.translate("TUT_WORKSHOP_AP_HINT"),
            "ap_label",
        ),
        TutorialStep.hint(
            TranslationServer.translate("TUT_WORKSHOP_LEAVE_HINT"),
            "leave_btn",
        ).unlock().on_scene("hub").no_block(),
    ]


## Day summary pass: brief summary of the day, then advance.
static func onboarding_day_pass_script() -> Array[TutorialStep]:
    return [
        TutorialStep.hint(
            TranslationServer.translate("TUT_DAY_PASS_HINT"),
            "continue_btn",
        ).unlock().on_event(TutorialEvents.DAY_SUMMARY_CONTINUED).no_block(),
    ]


## Day 2 Day hub chooser: tells the player to choose Selling.
static func onboarding_shop_choose_script() -> Array[TutorialStep]:
    return [
        TutorialStep.popup(TranslationServer.translate("TUT_SHOP_CHOOSE_BODY")),
        TutorialStep.hint(
            TranslationServer.translate("TUT_HUB_CHOOSER_HINT"),
            "activity_btn",
        ).unlock().on_event(TutorialEvents.CHOOSER_OPENED),
        TutorialStep.hint(
            TranslationServer.translate("TUT_HUB_CHOOSE_SELL_HINT"),
            "sell_btn",
        ).unlock().on_event(TutorialEvents.ACTIVITY_CHOSEN),
    ]


## Nightly customer selling: in-depth walkthrough of the customer flow,
## item packing, deal strategies, dice mechanics, and sale confirmation.
static func onboarding_selling_script() -> Array[TutorialStep]:
    return [
        TutorialStep.popup(
            TranslationServer.translate("TUT_SELLING_INTRO_BODY"),
        ),
        TutorialStep.hint(
            TranslationServer.translate("TUT_SELLING_CUSTOMER_QUEUE_HINT"),
            "customer_queue",
        ),
        TutorialStep.hint(
            TranslationServer.translate("TUT_SELLING_ITEM_LIST_HINT"),
            "item_list",
        ),
        TutorialStep.hint(
            TranslationServer.translate("TUT_SELLING_CAR_PANEL_HINT"),
            "car_panel",
        ).on_event(TutorialEvents.SELL_ITEM_PLACED).no_block(),
        TutorialStep.hint(
            TranslationServer.translate("TUT_SELLING_CONSERVATIVE_HINT"),
            "deal_panel",
        ),
        TutorialStep.hint(
            TranslationServer.translate("TUT_SELLING_AGGRESSIVE_HINT"),
            "deal_panel",
        ).unlock().on_event(TutorialEvents.SELL_AGGRESSIVE_REQUESTED),
        TutorialStep.hint(
            TranslationServer.translate("TUT_SELLING_DICE_HINT"),
            "deal_panel",
        ).on_event(TutorialEvents.DICE_TOGGLED).no_block(),
        TutorialStep.hint(
            TranslationServer.translate("TUT_SELLING_RESULT_HINT"),
            "deal_panel",
        ).on_event(TutorialEvents.SALE_COMPLETED).no_block(),
        TutorialStep.hint(
            TranslationServer.translate("TUT_SELLING_COMPLETE_HINT"),
            "back_btn",
        ),
    ]


## Final onboarding popup shown on the Hub after the player completes
## the selling tutorial. Marks onboarding fully done.
static func onboarding_complete_script() -> Array[TutorialStep]:
    return [
        TutorialStep.popup(
            TranslationServer.translate("TUT_COMPLETE_BODY"),
        ),
    ]

# ══ Run-phase split scripts (replaces onboarding_auction_run) ═══════════════════


## Location-select: pick a location to start the run.
static func onboarding_location_select_script() -> Array[TutorialStep]:
    return [
        TutorialStep.hint(
            TranslationServer.translate("TUT_LOCATION_SELECT_HINT"),
            "cards_container",
        ).unlock().on_event(TutorialEvents.LOCATION_SELECTED),
    ]


## Lot-browse: choose a lot to inspect.
static func onboarding_lot_browse_script() -> Array[TutorialStep]:
    return [
        TutorialStep.hint(
            TranslationServer.translate("TUT_LOT_BROWSE_HINT"),
            "lot_cards",
        ).unlock().on_event(TutorialEvents.LOT_SELECTED),
    ]


## Inspection: select, unveil, inspect, review, and start auction.
static func onboarding_inspection_script() -> Array[TutorialStep]:
    return [
        TutorialStep.hint(TranslationServer.translate("TUT_INSPECTION_ITEM_SELECT_HINT"), "item_browser").unlock().on_event(TutorialEvents.INSPECTION_ITEM_SELECTED),
        TutorialStep.hint(TranslationServer.translate("TUT_INSPECTION_UNVEIL_HINT"), "unveil_btn").unlock().on_event(TutorialEvents.INSPECTION_ITEM_UNVEILED),
        TutorialStep.hint(TranslationServer.translate("TUT_INSPECTION_INSPECT_HINT"), "inspect_btn").unlock().on_event(TutorialEvents.INSPECTION_PERFORMED),
        TutorialStep.hint(TranslationServer.translate("TUT_INSPECTION_REVIEW_HINT"), "review_btn").unlock().on_event(TutorialEvents.INSPECTION_REVIEW_OPENED),
        TutorialStep.hint(TranslationServer.translate("TUT_INSPECTION_START_AUCTION_HINT"), "start_auction_btn").unlock().on_event(TutorialEvents.INSPECTION_AUCTION_STARTED),
    ]


## Auction: bid then wait for resolution.
static func onboarding_auction_script() -> Array[TutorialStep]:
    return [
        TutorialStep.hint(
            TranslationServer.translate("TUT_AUCTION_BID_HINT"),
            "bid_btn",
        ).unlock().on_event(TutorialEvents.BID_PLACED),
        TutorialStep.popup(
            TranslationServer.translate("TUT_AUCTION_WAIT_BODY"),
        ).unlock().on_event(TutorialEvents.AUCTION_RESOLVED).no_block(),
    ]


## Reveal: reveal won items before cargo.
static func onboarding_reveal_script() -> Array[TutorialStep]:
    return [
        TutorialStep.hint(TranslationServer.translate("TUT_REVEAL_HINT"), "reveal_btn").unlock().on_event(TutorialEvents.REVEAL_COMPLETED).no_block(),
        TutorialStep.hint(TranslationServer.translate("TUT_REVEAL_CONTINUE_HINT"), "continue_btn").unlock().on_event(TutorialEvents.REVEAL_CONTINUED).no_block(),
    ]


## Cargo: select item, place in grid, continue.
static func onboarding_cargo_script() -> Array[TutorialStep]:
    return [
        TutorialStep.hint(TranslationServer.translate("TUT_CARGO_SELECT_HINT"), "item_list").unlock().on_event(TutorialEvents.CARGO_ITEM_SELECTED),
        TutorialStep.hint(TranslationServer.translate("TUT_CARGO_PLACE_HINT"), "cargo_grid").unlock().on_event(TutorialEvents.CARGO_ITEM_PLACED),
        TutorialStep.hint(TranslationServer.translate("TUT_CARGO_CONTINUE_HINT"), "continue_btn").unlock().on_event(TutorialEvents.CARGO_CONTINUE_REQUESTED).no_block(),
    ]


## Run-review: inspect the summary and return to hub.
static func onboarding_run_review_script() -> Array[TutorialStep]:
    return [
        TutorialStep.hint(TranslationServer.translate("TUT_RUN_REVIEW_HINT"), "continue_btn").unlock().on_event(TutorialEvents.RUN_REVIEWED).no_block(),
    ]


## Hub intro (day 0 day slot).
static func trigger_onboarding_hub_intro_choose(scene_id: String, ctx: Dictionary) -> bool:
    if not ctx.get("onboarding_pending", false):
        return false
    if int(ctx.get("day", -1)) != 0:
        return false
    if int(ctx.get("slot", -1)) != SlotStore.SLOT_DAY:
        return false
    return scene_id == "hub"


## Location select (day 0 day slot).
static func trigger_onboarding_location_select(scene_id: String, ctx: Dictionary) -> bool:
    if not ctx.get("onboarding_pending", false):
        return false
    if int(ctx.get("day", -1)) != 0:
        return false
    if int(ctx.get("slot", -1)) != SlotStore.SLOT_DAY:
        return false
    return scene_id == "location_select"


## Lot browse (first tutorial run context).
static func trigger_onboarding_lot_browse(scene_id: String, ctx: Dictionary) -> bool:
    if not ctx.get("onboarding_pending", false):
        return false
    if not ctx.get("first_tutorial_run", false):
        return false
    return scene_id == "lot_browse"


## Inspection (first tutorial run context).
static func trigger_onboarding_inspection(scene_id: String, ctx: Dictionary) -> bool:
    if not ctx.get("onboarding_pending", false):
        return false
    if not ctx.get("first_tutorial_run", false):
        return false
    return scene_id == "inspection"


## Auction (first tutorial run context).
static func trigger_onboarding_auction(scene_id: String, ctx: Dictionary) -> bool:
    if not ctx.get("onboarding_pending", false):
        return false
    if not ctx.get("first_tutorial_run", false):
        return false
    return scene_id == "auction"


## Reveal (first tutorial run context).
static func trigger_onboarding_reveal(scene_id: String, ctx: Dictionary) -> bool:
    if not ctx.get("onboarding_pending", false):
        return false
    if not ctx.get("first_tutorial_run", false):
        return false
    return scene_id == "reveal"


## Cargo (first tutorial run context).
static func trigger_onboarding_cargo(scene_id: String, ctx: Dictionary) -> bool:
    if not ctx.get("onboarding_pending", false):
        return false
    if not ctx.get("first_tutorial_run", false):
        return false
    return scene_id == "cargo"


## Run review (first tutorial run context).
static func trigger_onboarding_run_review(scene_id: String, ctx: Dictionary) -> bool:
    if not ctx.get("onboarding_pending", false):
        return false
    if not ctx.get("first_tutorial_run", false):
        return false
    return scene_id == "run_review"


## Storage choose (day 0 night slot).
static func trigger_onboarding_storage_choose(scene_id: String, ctx: Dictionary) -> bool:
    if not ctx.get("onboarding_pending", false):
        return false
    if int(ctx.get("day", -1)) != 0:
        return false
    if int(ctx.get("slot", -1)) != SlotStore.SLOT_NIGHT:
        return false
    return scene_id == "hub"


## Storage workshop (onboarding, items exist).
static func trigger_onboarding_storage(scene_id: String, ctx: Dictionary) -> bool:
    if not ctx.get("onboarding_pending", false):
        return false
    if int(ctx.get("storage_item_count", 0)) <= 0:
        return false
    return scene_id == "storage"


## Day summary pass.
static func trigger_onboarding_day_pass(scene_id: String, ctx: Dictionary) -> bool:
    if not ctx.get("onboarding_pending", false):
        return false
    return scene_id == "day_summary"


## Shop choose (day 1 day slot).
static func trigger_onboarding_shop_choose(scene_id: String, ctx: Dictionary) -> bool:
    if not ctx.get("onboarding_pending", false):
        return false
    if int(ctx.get("day", -1)) != 1:
        return false
    if int(ctx.get("slot", -1)) != SlotStore.SLOT_DAY:
        return false
    return scene_id == "hub"


## Selling (onboarding, items exist).
static func trigger_onboarding_selling(scene_id: String, ctx: Dictionary) -> bool:
    if not ctx.get("onboarding_pending", false):
        return false
    if int(ctx.get("storage_item_count", 0)) <= 0:
        return false
    return scene_id == "customer_sell"

# ══ Unit catalog ══════════════════════════════════════════════════════════════


## Returns all registered tutorial units in evaluation order (first-match-wins).
static func units() -> Array[TutorialUnit]:
    var units_list: Array[TutorialUnit] = []

    var u0 := TutorialUnit.new("onboarding_hub_intro_choose", onboarding_hub_intro_choose_script, trigger_onboarding_hub_intro_choose)
    units_list.append(u0)

    var u1 := TutorialUnit.new("onboarding_location_select", onboarding_location_select_script, trigger_onboarding_location_select)
    units_list.append(u1)

    var u2 := TutorialUnit.new("onboarding_lot_browse", onboarding_lot_browse_script, trigger_onboarding_lot_browse)
    u2.overrides = [TutorialOverrideSpec.whole(GameplayOverride.LOT_PASS_LOCKED)]
    units_list.append(u2)

    var u3 := TutorialUnit.new("onboarding_inspection", onboarding_inspection_script, trigger_onboarding_inspection)
    u3.overrides = [TutorialOverrideSpec.until(GameplayOverride.INSPECTION_REVIEW_GATED, TutorialEvents.INSPECTION_PERFORMED)]
    units_list.append(u3)

    var u4 := TutorialUnit.new("onboarding_auction", onboarding_auction_script, trigger_onboarding_auction)
    u4.overrides = [TutorialOverrideSpec.whole(GameplayOverride.ASSISTED_AUCTION)]
    units_list.append(u4)

    var u5 := TutorialUnit.new("onboarding_reveal", onboarding_reveal_script, trigger_onboarding_reveal)
    units_list.append(u5)

    var u6 := TutorialUnit.new("onboarding_cargo", onboarding_cargo_script, trigger_onboarding_cargo)
    units_list.append(u6)

    var u7 := TutorialUnit.new("onboarding_run_review", onboarding_run_review_script, trigger_onboarding_run_review)
    units_list.append(u7)

    var u8 := TutorialUnit.new("onboarding_storage_choose", onboarding_storage_choose_script, trigger_onboarding_storage_choose)
    units_list.append(u8)

    var u9 := TutorialUnit.new("onboarding_storage", onboarding_storage_script, trigger_onboarding_storage)
    units_list.append(u9)

    var u10 := TutorialUnit.new("onboarding_day_pass", onboarding_day_pass_script, trigger_onboarding_day_pass)
    units_list.append(u10)

    var u11 := TutorialUnit.new("onboarding_shop_choose", onboarding_shop_choose_script, trigger_onboarding_shop_choose)
    units_list.append(u11)

    var u12 := TutorialUnit.new("onboarding_selling", onboarding_selling_script, trigger_onboarding_selling)
    units_list.append(u12)

    return units_list


## Script ids that, once all are seen (via completion or individual skip),
## cause onboarding to be marked complete.
static func required_onboarding_unit_ids() -> Array[String]:
    return [
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


static func resolve_script(script_id: String) -> Array[TutorialStep]:
    match script_id:
        "hub":
            return hub_script()
        "onboarding_hub_intro_choose":
            return onboarding_hub_intro_choose_script()
        "onboarding_location_select":
            return onboarding_location_select_script()
        "onboarding_lot_browse":
            return onboarding_lot_browse_script()
        "onboarding_inspection":
            return onboarding_inspection_script()
        "onboarding_auction":
            return onboarding_auction_script()
        "onboarding_reveal":
            return onboarding_reveal_script()
        "onboarding_cargo":
            return onboarding_cargo_script()
        "onboarding_run_review":
            return onboarding_run_review_script()
        "onboarding_storage_choose":
            return onboarding_storage_choose_script()
        "onboarding_storage":
            return onboarding_storage_script()
        "onboarding_day_pass":
            return onboarding_day_pass_script()
        "onboarding_shop_choose":
            return onboarding_shop_choose_script()
        "onboarding_selling":
            return onboarding_selling_script()
        "onboarding_complete":
            return onboarding_complete_script()
        _:
            ToastManager.show_dev_error("TutorialScripts: unknown script id '%s'" % script_id)
            return []


static func known_script_ids() -> Array[String]:
    return [
        "hub",
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
        "onboarding_complete",
    ]


## Returns anchor ids referenced by [param script_id] that are absent from
## [param anchors] and are expected to be renderable in the current scene.
## Steps whose advance is SCENE_ENTERED or EVENT may target a different scene,
## so their anchors are not flagged here.
static func validate_anchors(script_id: String, anchors: Dictionary) -> Array[String]:
    var missing: Array[String] = []
    var script := resolve_script(script_id)
    if script.is_empty():
        return missing
    for step: TutorialStep in script:
        if step.advance in [TutorialStep.Advance.SCENE_ENTERED, TutorialStep.Advance.EVENT]:
            continue
        if not step.anchor_id.is_empty() and not anchors.has(step.anchor_id):
            missing.append(step.anchor_id)
        for fallback_id: String in step.fallback_anchor_ids:
            if not anchors.has(fallback_id):
                missing.append(fallback_id)
    return missing
