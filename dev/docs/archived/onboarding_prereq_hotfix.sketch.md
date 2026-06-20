# Onboarding Prerequisite Hotfix

## Goal

Patch the tutorial and save infrastructure gaps that block the first-game onboarding from being implemented safely. This hotfix does not ship onboarding content; it makes the existing event-driven tutorial machinery reliable enough for onboarding segments, resume behavior, chooser guidance, and real auction outcomes.

## Requirements

1. New games must have an explicit onboarding-pending state, while existing saves must migrate as onboarding already completed so returning players are not surprised by a tutorial on load.
2. Onboarding flow selection must be derived from real economy state and the current scene, because resume should reattach to the right segment without storing fragile tutorial step indexes.
3. Tutorial flow must support segmented onboarding scripts that start only when onboarding is pending and the current scene/slot/day matches the intended segment.
4. Auction onboarding must not softlock when the player loses, because the onboarding uses real auctions and does not force an outcome.
5. Activity chooser guidance must only advance when the intended activity is chosen, or must prevent unintended choices while onboarding is steering the player.
6. Every scene that onboarding needs to teach, wait in, or reattach from must expose a scene id and stable tutorial anchors.
7. Existing hub and storage tutorials must keep their current behavior for non-onboarding players.

## Design

The hotfix should keep onboarding state persistent but tutorial step state runtime-only. Persistence answers only "is onboarding pending?" and "has onboarding been completed or skipped?"; the active segment is recalculated from the real day, slot, activity, run state, and scene. This keeps quit/resume aligned with the actual economy instead of creating a second onboarding timeline.

Auction progress should wait on a neutral auction-resolution milestone instead of a win-only milestone. Winning can still have its own event for future tutorials, but onboarding needs a semantic milestone that fires after the auction result is committed regardless of winner.

Chooser guidance should prefer simple gating for the hotfix: while onboarding is active, non-target activity options are disabled or hidden, so the existing activity-chosen event cannot accidentally advance the wrong segment. If gating proves awkward, the equivalent behavior can be achieved by adding activity identity to the event and filtering it in the flow layer.

## Sketch (non-normative)

Implementation names and file references here are illustrative. Verify them against the codebase before editing; when code disagrees with this sketch, the code wins.

1. Add onboarding persistence to `ProgressStore`.

```gdscript
var _onboarding_pending: bool = true

var onboarding_pending: bool:
    get: return _onboarding_pending

func mark_onboarding_complete() -> void:
    _onboarding_pending = false
```

Migration shape:

```gdscript
func _store_version() -> int:
    return 3

func _apply_migrations(data: Dictionary, from_version: int, ctx: SaveLoadContext) -> Dictionary:
    if from_version < 2:
        data["tutorial_seen"] = data.get("tutorial_seen", { }) if data.get("tutorial_seen", { }) is Dictionary else { }
    if from_version < 3:
        data["onboarding_pending"] = false
    data["_version"] = _store_version()
    return data
```

New `ProgressStore.new()` defaults to pending. Loaded saves older than the onboarding version migrate to not pending. `MetaManager` exposes `is_onboarding_pending()`, `complete_onboarding()`, and `skip_onboarding()` wrappers so scenes do not mutate the store directly.

2. Add a segment resolver to `ScriptDirector`.

Suggested shape:

```gdscript
func _decide_tutorial_for_scene(scene_id: String) -> void:
    if MetaManager.is_onboarding_pending():
        _decide_onboarding_for_scene(scene_id)
        return
    match scene_id:
        "hub": _on_hub_registered()
        "storage": _on_storage_registered()
```

The onboarding resolver should inspect current day, current slot, and scene id. Suggested segment ids:

| Segment                     | Trigger shape                                     | End milestone                                   |
| --------------------------- | ------------------------------------------------- | ----------------------------------------------- |
| `onboarding_hub_intro`      | Day 0 or Day 1 start, hub scene, day slot         | chooser opened or Next into chooser instruction |
| `onboarding_auction_choose` | hub chooser open during first day slot            | intended activity chosen                        |
| `onboarding_auction_run`    | run scenes while first auction activity is active | run reviewed                                    |
| `onboarding_storage_choose` | hub scene after auction slot, night slot          | intended activity chosen                        |
| `onboarding_storage`        | storage scene while onboarding pending            | storage tutorial segment completes              |
| `onboarding_day_pass`       | day summary scene after first day ends            | player advances to next hub                     |
| `onboarding_shop_choose`    | second day hub, day slot                          | intended activity chosen                        |
| `onboarding_selling`        | customer sell scene                               | sale completed                                  |

Do not persist the segment id unless implementation proves it is required. Prefer deriving it from real state each time a scene registers.

3. Add onboarding scripts to `TutorialScripts`.

Suggested functions:

```gdscript
static func onboarding_auction_run_script() -> Array[TutorialStep]:
    return [
        TutorialStep.new(TutorialStep.Kind.HINT, "Choose a lot to inspect.", "lot_cards", TutorialStep.Advance.EVENT, true, null, [], false, TutorialEvents.LOT_SELECTED),
        TutorialStep.new(TutorialStep.Kind.HINT, "Spend inspection AP to learn about an item.", "inspect_btn", TutorialStep.Advance.EVENT, true, null, [], false, TutorialEvents.INSPECTION_PERFORMED),
        TutorialStep.new(TutorialStep.Kind.HINT, "Bid or pass for real. The result is yours.", "bid_btn", TutorialStep.Advance.EVENT, true, null, ["pass_btn"], true, TutorialEvents.AUCTION_RESOLVED),
        TutorialStep.new(TutorialStep.Kind.HINT, "Load anything you want to bring home.", "cargo_grid", TutorialStep.Advance.EVENT, true, null, [], false, TutorialEvents.CARGO_LOADED),
        TutorialStep.new(TutorialStep.Kind.HINT, "Review the run and return to the hub.", "continue_btn", TutorialStep.Advance.EVENT, true, null, [], false, TutorialEvents.RUN_REVIEWED),
    ]
```

Storage can either reuse `storage_script()` with a wrapper segment or add `onboarding_storage_script()` that copies the storage steps with onboarding-specific intro/outro text. Keep non-onboarding storage Help behavior unchanged.

4. Replace the win-only onboarding wait with an auction-resolution event.

Add a neutral event constant such as:

```gdscript
const AUCTION_RESOLVED: StringName = &"auction_resolved"
```

Emit it after auction resolution commits and before leaving the auction result path. If the win path should still emit `AUCTION_WON`, emit both on win:

```gdscript
if player_won:
    EventBus.tutorial_event.emit(TutorialEvents.AUCTION_WON, { })
EventBus.tutorial_event.emit(TutorialEvents.AUCTION_RESOLVED, { "won": player_won })
```

Payload should remain optional for current flow. The important hotfix behavior is that both win and loss advance the onboarding run segment.

5. Gate the activity chooser during onboarding.

Suggested minimum API:

```gdscript
func onboarding_target_activity() -> StringName:
    if not progress.onboarding_pending:
        return &""
    if progress.current_day == 0 and slot.current_slot == SlotStore.SLOT_DAY:
        return &"auction"
    if progress.current_day == 0 and slot.current_slot == SlotStore.SLOT_NIGHT:
        return &"storage"
    if progress.current_day == 1 and slot.current_slot == SlotStore.SLOT_DAY:
        return &"selling"
    return &""
```

In the hub chooser, disable or hide non-target options when this returns a target. Keep the cancel button behavior deliberate: either disable cancel during onboarding steps that require a choice, or cancel should not advance the segment and should leave the same chooser guidance active when reopened.

6. Register missing onboarding scenes and anchors.

Add `Director.register_scene()` calls for scenes onboarding needs to reattach from or point at. Likely minimum:

```gdscript
Director.register_scene("day_summary", { "continue_btn": _continue_btn })
Director.register_scene("customer_sell", {
    "customer_queue": _customer_queue,
    "item_list": _item_list,
    "car_panel": _car_panel,
    "deal_panel": _deal_panel,
    "back_btn": _back_button,
})
```

Consider registering `reveal` and `location_entry` only if onboarding copy appears there or resume needs those scenes to trigger a segment before they auto-advance. Auto-advance scenes may be better left as pass-throughs unless a concrete onboarding step targets them.

7. Complete onboarding on sale completion or explicit skip.

`ScriptDirector._on_tutorial_event()` can mark onboarding complete when the active onboarding selling segment receives `SALE_COMPLETED`, or the segment completion handler can map `onboarding_selling` completion to `MetaManager.complete_onboarding()`. The close/skip path should call `skip_onboarding()` only for onboarding scripts, not for ordinary hub/storage tutorial close.

8. Add focused tests.

Suggested coverage:

- New `ProgressStore` defaults onboarding pending.
- Migrated pre-onboarding progress payloads become not pending.
- Onboarding resolver starts a segment only when pending.
- Runtime reset clears active tutorial but does not change onboarding pending.
- Auction win and loss both emit the neutral auction-resolution milestone.
- Activity chooser cannot advance onboarding through a non-target activity.
- Completing or skipping onboarding clears the pending flag.

## Non-Goals

1. Do not write the full final onboarding copy beyond placeholder instructional text needed to wire segments.
2. Do not add branching tutorial scripts or persistent tutorial step indexes.
3. Do not force an auction win, alter economy rewards, or create a fake onboarding economy.
4. Do not redesign the normal hub/storage tutorial offer and Help flows.

## Acceptance Criteria

1. Brand-new games enter onboarding-pending state, while older saves load without entering onboarding.
2. Onboarding can start the correct segment from the current scene and real economy state after a runtime reset or save/load.
3. Winning or losing the first auction both allow the run onboarding to continue to run review without tutorial softlock.
4. During onboarding, the hub activity chooser cannot accidentally advance the flow through the wrong activity.
5. Day summary and customer selling can be targeted or used for onboarding reattachment through registered tutorial scene anchors.
6. Completing or skipping onboarding clears the first-time flag and leaves the player in the normal economy.
7. Existing non-onboarding hub and storage tutorials still play or offer exactly as before.
