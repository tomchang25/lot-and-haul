# tutorial_scripts.gd
# Static step arrays for hub and storage tutorials.
# Not autoloaded — imported by Director.
class_name TutorialScripts

static func hub_script() -> Array[TutorialStep]:
    return [
        TutorialStep.new(
            TutorialStep.Kind.HINT,
            "This shows the current day and your available time slots. \
You have three slots per day: Morning, Afternoon, and Evening. \
Each slot can be used for one activity.",
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
            "Let's visit the Workshop to see what items you've collected. \
Click the Storage button to continue.",
            "storage_btn",
            TutorialStep.Advance.SCENE_ENTERED,
            true,
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
