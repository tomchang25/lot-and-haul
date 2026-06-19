# tutorial_scripts.gd
# Static step arrays for hub and storage tutorials.
# Not autoloaded — imported by Director.
# The single surface for script id resolution, anchor validation, and unit registry.
class_name TutorialScripts

class TutorialUnit:
    var id: String
    var steps_resolver: Callable
    var trigger: Callable
    var once: bool = true


    func _init(p_id: String, p_resolver: Callable, p_trigger: Callable, p_once: bool = true) -> void:
        id = p_id
        steps_resolver = p_resolver
        trigger = p_trigger
        once = p_once


    func steps() -> Array[TutorialStep]:
        return steps_resolver.call() as Array[TutorialStep]


static func hub_script() -> Array[TutorialStep]:
    return [
        TutorialStep.new(
            TutorialStep.Kind.HINT,
            "This shows the current day and your available time slots. \
You have two slots per day: Day and Night. \
Each slot can be used for one activity. Click the Activity button to choose.",
            "slot_label",
            TutorialStep.Advance.NEXT,
            false,
        ),
        TutorialStep.new(
            TutorialStep.Kind.POPUP,
            "From here you can start an Auction run, manage items in Storage, \
open your Shop to sell to nightly customers, upgrade your Vehicle, \
or study Knowledge to improve your attributes.",
        ),
        TutorialStep.new(
            TutorialStep.Kind.HINT,
            "Let's visit the Workshop to see what you've collected. \
Click the Storage button to continue.",
            "storage_btn",
            TutorialStep.Advance.SCENE_ENTERED,
            true,
            null,
            [],
            false,
            &"",
            "storage",
        ),
    ]

# ══ Onboarding segment scripts ════════════════════════════════════════════════


## Day 1 Day hub intro + chooser: teaches the hub UI and steers the player to
## choose Auction.
static func onboarding_hub_intro_choose_script() -> Array[TutorialStep]:
    return [
        TutorialStep.new(
            TutorialStep.Kind.POPUP,
            "Welcome to Lot & Haul!\n\nThis is your Hub. Each day has two time \
slots: Day and Night. You can use each slot for one activity. \
Let's start your first day with an Auction Run.",
        ),
        TutorialStep.new(
            TutorialStep.Kind.HINT,
            "Click the Activity button to open the activity chooser.",
            "activity_btn",
            TutorialStep.Advance.EVENT,
            true,
            null,
            [],
            false,
            TutorialEvents.CHOOSER_OPENED,
        ),
        TutorialStep.new(
            TutorialStep.Kind.HINT,
            "Choose Auction to begin your first run.",
            "auction_btn",
            TutorialStep.Advance.EVENT,
            true,
            null,
            [],
            false,
            TutorialEvents.ACTIVITY_CHOSEN,
        ),
    ]


## Day 1 Night hub chooser: tells the player to choose Storage.
static func onboarding_storage_choose_script() -> Array[TutorialStep]:
    return [
        TutorialStep.new(
            TutorialStep.Kind.POPUP,
            "Good run! Now let's visit Storage.\n\nYou can manage items, \
repair them, and research hidden details.",
        ),
        TutorialStep.new(
            TutorialStep.Kind.HINT,
            "Click the Activity button to open the chooser.",
            "activity_btn",
            TutorialStep.Advance.EVENT,
            true,
            null,
            [],
            false,
            TutorialEvents.CHOOSER_OPENED,
        ),
        TutorialStep.new(
            TutorialStep.Kind.HINT,
            "Choose Storage to manage your items.",
            "storage_btn",
            TutorialStep.Advance.EVENT,
            true,
            null,
            [],
            false,
            TutorialEvents.ACTIVITY_CHOSEN,
        ),
    ]


## Storage workshop tutorial for onboarding. Inlines storage_script content
## with the final leave_btn step changed to SCENE_ENTERED hub so the
## tutorial completes when the player leaves the storage scene.
static func onboarding_storage_script() -> Array[TutorialStep]:
    return [
        TutorialStep.new(
            TutorialStep.Kind.POPUP,
            "Welcome to the Workshop! This is where you prepare items for sale. \
You can Repair, Restore, and Research items using Action Points (AP).",
        ),
        TutorialStep.new(
            TutorialStep.Kind.HINT,
            "This table lists every item in storage. Columns show the item name, \
condition (damage level), estimated value, and rarity. Click any row \
to inspect it in detail.",
            "item_browser",
        ),
        TutorialStep.new(
            TutorialStep.Kind.HINT,
            "Select an item to see its details here: name, category, rarity, \
condition, estimated value, and price convergence. The closer convergence \
is to 100%, the more accurate the estimate.",
            "detail_rail",
        ),
        TutorialStep.new(
            TutorialStep.Kind.HINT,
            "Repair improves condition up to 50%, and Restore pushes it from 50% \
to 100%. Only one button appears based on the current state. \
Better condition means higher sale prices. Improve this item's condition, \
then continue.",
            "repair_btn",
            TutorialStep.Advance.NEXT,
            false,
            null,
            ["restore_btn"],
            true,
        ),
        TutorialStep.new(
            TutorialStep.Kind.HINT,
            "Research reveals hidden details about an item. Each discovery can \
dramatically change the item's value — for better or worse. \
Try researching this item, then continue.",
            "research_btn",
            TutorialStep.Advance.NEXT,
            false,
        ),
        TutorialStep.new(
            TutorialStep.Kind.POPUP,
            "Appraised vs. Verified Value: The items you collect have surface clues \
that give an estimated value range. Research uncovers hidden clues, \
revealing the true verified value which may be far higher — or lower — \
than the estimate.",
            "",
            TutorialStep.Advance.NEXT,
            false,
        ),
        TutorialStep.new(
            TutorialStep.Kind.HINT,
            "AP (Action Points) fuel all workshop actions. Each Repair, Restore, \
or Research action costs AP. Your AP pool refills each time you visit \
the Workshop in a new slot.",
            "ap_label",
        ),
        TutorialStep.new(
            TutorialStep.Kind.HINT,
            "When you're done, click here to return to the Hub and continue \
your day. You can always come back to the Workshop later.",
            "leave_btn",
            TutorialStep.Advance.SCENE_ENTERED,
            true,
            null,
            [],
            false,
            &"",
            "hub",
            false,
        ),
    ]


## Day summary pass: brief summary of the day, then advance.
static func onboarding_day_pass_script() -> Array[TutorialStep]:
    return [
        TutorialStep.new(
            TutorialStep.Kind.HINT,
            "Day 1 is complete! Review your net profit, then click Continue to move to Day 2.",
            "continue_btn",
            TutorialStep.Advance.EVENT,
            true,
            null,
            [],
            false,
            TutorialEvents.DAY_SUMMARY_CONTINUED,
            "",
            false,
        ),
    ]


## Day 2 Day hub chooser: tells the player to choose Selling.
static func onboarding_shop_choose_script() -> Array[TutorialStep]:
    return [
        TutorialStep.new(
            TutorialStep.Kind.POPUP,
            "Welcome to Day 2! Let's try selling to nightly customers.",
        ),
        TutorialStep.new(
            TutorialStep.Kind.HINT,
            "Click the Activity button to open the chooser.",
            "activity_btn",
            TutorialStep.Advance.EVENT,
            true,
            null,
            [],
            false,
            TutorialEvents.CHOOSER_OPENED,
        ),
        TutorialStep.new(
            TutorialStep.Kind.HINT,
            "Choose Selling to open your shop.",
            "sell_btn",
            TutorialStep.Advance.EVENT,
            true,
            null,
            [],
            false,
            TutorialEvents.ACTIVITY_CHOSEN,
        ),
    ]


## Nightly customer selling: in-depth walkthrough of the customer flow,
## item packing, deal strategies, dice mechanics, and sale confirmation.
static func onboarding_selling_script() -> Array[TutorialStep]:
    return [
        TutorialStep.new(
            TutorialStep.Kind.POPUP,
            "Welcome to your shop! Let's walk through serving your first customer \
step by step.",
        ),
        TutorialStep.new(
            TutorialStep.Kind.HINT,
            "This is your customer queue. Each tab shows a customer and their \
demand tags — the kinds of items they're looking for. Click a tab \
to select a customer.",
            "customer_queue",
            TutorialStep.Advance.NEXT,
            false,
        ),
        TutorialStep.new(
            TutorialStep.Kind.HINT,
            "These are your item cards. The top number is the price, the badge \
shows rarity, and the coloured bar indicates condition. Tags at the \
bottom show which categories this item matches.",
            "item_list",
            TutorialStep.Advance.NEXT,
            false,
        ),
        TutorialStep.new(
            TutorialStep.Kind.HINT,
            "Pick up an item from the list and drop it into the car grid on \
the right. Items must fit the customer's car shape and match their \
demand tags to count toward the sale.",
            "car_panel",
            TutorialStep.Advance.EVENT,
            false,
            null,
            [],
            false,
            TutorialEvents.SELL_ITEM_PLACED,
            "",
            false,
        ),
        TutorialStep.new(
            TutorialStep.Kind.HINT,
            "Conservative selling gives a safe ×1.2 multiplier on the total \
item value. It guarantees the sale — no risk, no dice. Handy when \
you want a sure deal.",
            "deal_panel",
            TutorialStep.Advance.NEXT,
            false,
        ),
        TutorialStep.new(
            TutorialStep.Kind.HINT,
            "Aggressive selling rolls dice to multiply the total item value. \
The better your item fit (depth) and the more verified items you have, \
the more dice you roll. Try it — press the Aggressive button.",
            "deal_panel",
            TutorialStep.Advance.EVENT,
            true,
            null,
            [],
            false,
            TutorialEvents.SELL_AGGRESSIVE_REQUESTED,
        ),
        TutorialStep.new(
            TutorialStep.Kind.HINT,
            "The dice show your luck: each die can add to or subtract from \
the multiplier.",
            "deal_panel",
            TutorialStep.Advance.EVENT,
            false,
            null,
            [],
            false,
            TutorialEvents.DICE_TOGGLED,
            "",
            false,
        ),
        TutorialStep.new(
            TutorialStep.Kind.HINT,
            "Green faces are good, red faces are bad. The result sets your final price. \
            Press Confirm when ready. Review the receipt, then confirm to complete the sale.",
            "deal_panel",
            TutorialStep.Advance.EVENT,
            false,
            null,
            [],
            false,
            TutorialEvents.SALE_COMPLETED,
            "",
            false,
        ),
        TutorialStep.new(
            TutorialStep.Kind.HINT,
            "Great! You can serve more customers or click Back to return \
to the Hub and finish the day.",
            "back_btn",
            TutorialStep.Advance.NEXT,
            false,
        ),
    ]


## Final onboarding popup shown on the Hub after the player completes
## the selling tutorial. Marks onboarding fully done.
static func onboarding_complete_script() -> Array[TutorialStep]:
    return [
        TutorialStep.new(
            TutorialStep.Kind.POPUP,
            "Congratulations! You've completed the Lot & Haul tutorial.\n\n\
You know how to run auctions, manage storage, and sell to customers. \
The rest is up to you — good luck out there!",
        ),
    ]

# ══ Run-phase split scripts (replaces onboarding_auction_run) ═══════════════════


## Location-select: pick a location to start the run.
static func onboarding_location_select_script() -> Array[TutorialStep]:
    return [
        TutorialStep.new(
            TutorialStep.Kind.HINT,
            "Pick a location to visit. Each location has different lots \
and travel costs.",
            "cards_container",
            TutorialStep.Advance.EVENT,
            true,
            null,
            [],
            false,
            TutorialEvents.LOCATION_SELECTED,
        ),
    ]


## Lot-browse: choose a lot to inspect.
static func onboarding_lot_browse_script() -> Array[TutorialStep]:
    return [
        TutorialStep.new(
            TutorialStep.Kind.HINT,
            "Browse the available lots and choose one to inspect.",
            "lot_cards",
            TutorialStep.Advance.EVENT,
            true,
            null,
            [],
            false,
            TutorialEvents.LOT_SELECTED,
        ),
    ]


## Inspection: select, unveil, inspect, review, and start auction.
static func onboarding_inspection_script() -> Array[TutorialStep]:
    return [
        TutorialStep.new(
            TutorialStep.Kind.HINT,
            "Select the item card to inspect it.",
            "item_browser",
            TutorialStep.Advance.EVENT,
            true,
            null,
            [],
            false,
            TutorialEvents.INSPECTION_ITEM_SELECTED,
        ),
        TutorialStep.new(
            TutorialStep.Kind.HINT,
            "Unveil the item to reveal its identity.",
            "unveil_btn",
            TutorialStep.Advance.EVENT,
            true,
            null,
            [],
            false,
            TutorialEvents.INSPECTION_ITEM_UNVEILED,
        ),
        TutorialStep.new(
            TutorialStep.Kind.HINT,
            "Inspect the unveiled item to reveal clue details.",
            "inspect_btn",
            TutorialStep.Advance.EVENT,
            true,
            null,
            [],
            false,
            TutorialEvents.INSPECTION_PERFORMED,
        ),
        TutorialStep.new(
            TutorialStep.Kind.HINT,
            "Review the lot before starting the auction.",
            "review_btn",
            TutorialStep.Advance.EVENT,
            true,
            null,
            [],
            false,
            TutorialEvents.INSPECTION_REVIEW_OPENED,
        ),
        TutorialStep.new(
            TutorialStep.Kind.HINT,
            "Start the auction when you're ready.",
            "start_auction_btn",
            TutorialStep.Advance.EVENT,
            true,
            null,
            [],
            false,
            TutorialEvents.INSPECTION_AUCTION_STARTED,
        ),
    ]


## Auction: bid then wait for resolution.
static func onboarding_auction_script() -> Array[TutorialStep]:
    return [
        TutorialStep.new(
            TutorialStep.Kind.HINT,
            "Click Bid to place your first bid. No rivals will bid in \
this tutorial auction.",
            "bid_btn",
            TutorialStep.Advance.EVENT,
            true,
            null,
            [],
            false,
            TutorialEvents.BID_PLACED,
        ),
        TutorialStep.new(
            TutorialStep.Kind.POPUP,
            "With no rival bids, wait for the auction to close.",
            "",
            TutorialStep.Advance.EVENT,
            true,
            null,
            [],
            false,
            TutorialEvents.AUCTION_RESOLVED,
            "",
            false,
        ),
    ]


## Reveal: reveal won items before cargo.
static func onboarding_reveal_script() -> Array[TutorialStep]:
    return [
        TutorialStep.new(
            TutorialStep.Kind.HINT,
            "Reveal what you won before loading cargo.",
            "reveal_btn",
            TutorialStep.Advance.EVENT,
            true,
            null,
            [],
            false,
            TutorialEvents.REVEAL_COMPLETED,
            "",
            false,
        ),
        TutorialStep.new(
            TutorialStep.Kind.HINT,
            "Continue back to the lot list, then head to cargo loading.",
            "continue_btn",
            TutorialStep.Advance.EVENT,
            true,
            null,
            [],
            false,
            TutorialEvents.REVEAL_CONTINUED,
            "",
            false,
        ),
    ]


## Cargo: select item, place in grid, continue.
static func onboarding_cargo_script() -> Array[TutorialStep]:
    return [
        TutorialStep.new(
            TutorialStep.Kind.HINT,
            "Select the item you want to load.",
            "item_list",
            TutorialStep.Advance.EVENT,
            true,
            null,
            [],
            false,
            TutorialEvents.CARGO_ITEM_SELECTED,
        ),
        TutorialStep.new(
            TutorialStep.Kind.HINT,
            "Place the item into your cargo grid.",
            "cargo_grid",
            TutorialStep.Advance.EVENT,
            true,
            null,
            [],
            false,
            TutorialEvents.CARGO_ITEM_PLACED,
        ),
        TutorialStep.new(
            TutorialStep.Kind.HINT,
            "Click Continue when your cargo is ready.",
            "continue_btn",
            TutorialStep.Advance.EVENT,
            true,
            null,
            [],
            false,
            TutorialEvents.CARGO_CONTINUE_REQUESTED,
            "",
            false,
        ),
    ]


## Run-review: inspect the summary and return to hub.
static func onboarding_run_review_script() -> Array[TutorialStep]:
    return [
        TutorialStep.new(
            TutorialStep.Kind.HINT,
            "Review your run results and continue to the Hub.",
            "continue_btn",
            TutorialStep.Advance.EVENT,
            true,
            null,
            [],
            false,
            TutorialEvents.RUN_REVIEWED,
            "",
            false,
        ),
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
    return [
        TutorialUnit.new("onboarding_hub_intro_choose", onboarding_hub_intro_choose_script, trigger_onboarding_hub_intro_choose),
        TutorialUnit.new("onboarding_location_select", onboarding_location_select_script, trigger_onboarding_location_select),
        TutorialUnit.new("onboarding_lot_browse", onboarding_lot_browse_script, trigger_onboarding_lot_browse),
        TutorialUnit.new("onboarding_inspection", onboarding_inspection_script, trigger_onboarding_inspection),
        TutorialUnit.new("onboarding_auction", onboarding_auction_script, trigger_onboarding_auction),
        TutorialUnit.new("onboarding_reveal", onboarding_reveal_script, trigger_onboarding_reveal),
        TutorialUnit.new("onboarding_cargo", onboarding_cargo_script, trigger_onboarding_cargo),
        TutorialUnit.new("onboarding_run_review", onboarding_run_review_script, trigger_onboarding_run_review),
        TutorialUnit.new("onboarding_storage_choose", onboarding_storage_choose_script, trigger_onboarding_storage_choose),
        TutorialUnit.new("onboarding_storage", onboarding_storage_script, trigger_onboarding_storage),
        TutorialUnit.new("onboarding_day_pass", onboarding_day_pass_script, trigger_onboarding_day_pass),
        TutorialUnit.new("onboarding_shop_choose", onboarding_shop_choose_script, trigger_onboarding_shop_choose),
        TutorialUnit.new("onboarding_selling", onboarding_selling_script, trigger_onboarding_selling),
    ]


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
