# tutorial_scripts.gd
# Static step arrays for hub and storage tutorials.
# Not autoloaded — imported by Director.
# The single surface for script id resolution and anchor validation.
class_name TutorialScripts

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


static func storage_script() -> Array[TutorialStep]:
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
Better condition means higher sale prices.",
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
dramatically change the item's value — for better or worse.",
            "research_btn",
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


## Covers the full auction-run scene chain: location select → lot browse →
## inspection → auction → cargo → run review.
static func onboarding_auction_run_script() -> Array[TutorialStep]:
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
        TutorialStep.new(
            TutorialStep.Kind.HINT,
            "Inspect items to learn about their condition and value. \
Spend Action Points (AP) to reveal clue details.",
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
            "Bid on the lot or pass. The auction is real — win or lose, \
the run continues.",
            "bid_btn",
            TutorialStep.Advance.EVENT,
            true,
            null,
            ["pass_btn"],
            true,
            TutorialEvents.AUCTION_RESOLVED,
        ),
        TutorialStep.new(
            TutorialStep.Kind.HINT,
            "Load items into your cargo to bring them home. Items left \
behind are sold on-site.",
            "cargo_grid",
            TutorialStep.Advance.EVENT,
            true,
            null,
            [],
            false,
            TutorialEvents.CARGO_LOADED,
        ),
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


## Storage workshop tutorial for onboarding. Reuses the existing storage
## tutorial steps but auto-starts instead of going through the offer prompt.
static func onboarding_storage_script() -> Array[TutorialStep]:
    return storage_script()


## Day summary pass: brief summary of the day, then advance.
static func onboarding_day_pass_script() -> Array[TutorialStep]:
    return [
        TutorialStep.new(
            TutorialStep.Kind.POPUP,
            "Day 1 is complete! Here's a summary of your earnings and \
expenses. Today's net profit is shown below.",
        ),
        TutorialStep.new(
            TutorialStep.Kind.HINT,
            "Click Continue to move to Day 2.",
            "continue_btn",
            TutorialStep.Advance.NEXT,
            true,
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


## Nightly customer selling: brief intro, then wait for a completed sale.
static func onboarding_selling_script() -> Array[TutorialStep]:
    return [
        TutorialStep.new(
            TutorialStep.Kind.POPUP,
            "Welcome to your shop! Select a customer, pack their car with \
matching items, and make a deal.",
        ),
        TutorialStep.new(
            TutorialStep.Kind.POPUP,
            "Complete a sale to finish the onboarding and continue \
playing freely.",
        ),
        TutorialStep.new(
            TutorialStep.Kind.HINT,
            "Serve a customer to complete the sale.",
            "customer_queue",
            TutorialStep.Advance.EVENT,
            true,
            null,
            [],
            false,
            TutorialEvents.SALE_COMPLETED,
        ),
    ]


static func resolve_script(script_id: String) -> Array[TutorialStep]:
    match script_id:
        "hub":
            return hub_script()
        "storage":
            return storage_script()
        "onboarding_hub_intro_choose":
            return onboarding_hub_intro_choose_script()
        "onboarding_auction_run":
            return onboarding_auction_run_script()
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
        _:
            ToastManager.show_dev_error("TutorialScripts: unknown script id '%s'" % script_id)
            return []


static func known_script_ids() -> Array[String]:
    return [
        "hub",
        "storage",
        "onboarding_hub_intro_choose",
        "onboarding_auction_run",
        "onboarding_storage_choose",
        "onboarding_storage",
        "onboarding_day_pass",
        "onboarding_shop_choose",
        "onboarding_selling",
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
