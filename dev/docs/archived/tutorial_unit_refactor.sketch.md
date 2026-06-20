# Tutorial Unit Refactor

## Goal

Convert the onboarding tutorial from a single chain where skipping any segment kills all following segments, into independent scene/milestone units that trigger on game state and skip individually. Move the tutorial/intent leakage out of `MetaManager`/`RunStore` and gameplay scenes, so gameplay code only queries the `Director` for tutorial-driven state (assisted auction, gated activity chooser, locked conservative sale, disabled pass). Remove the `disable_npc_bids` field from `RunStore` so run snapshots never bake in tutorial-only behavior.

## Requirements

1. Each tutorial is a unit identified by a stable `id`, with a step array, a `trigger` condition (a callable that takes the current scene id and a game-state snapshot), and an optional `once` flag. The flow layer iterates known units and starts the first whose trigger fires and that is not already seen.
2. Closing a single unit (X button on a hint or popup step) only marks that unit as seen; it does not call `skip_onboarding()`, and it does not affect other units' trigger conditions. The chain behavior must fall out of trigger conditions, not out of a hard-coded prerequisite lookup.
3. An explicit `skip_all_onboarding()` API exists on `Director` and is reachable from a debug menu only — never from the per-step X button. The debug action marks every `onboarding_*` unit as seen and clears `onboarding_pending`.
4. The `onboarding_pending` flag remains a saved field in `ProgressStore`. It is one input to a unit's trigger condition, not the only condition. Skipping one unit does not clear it; completing or skipping every required onboarding milestone, or invoking `skip_all_onboarding()`, clears it.
5. Gameplay scenes do not read `is_onboarding_pending()`, `onboarding_target_activity()`, or any `_is_onboarding_auction_run()` helper. They query `Director` for tutorial-driven state at the moment of decision (`_ready`, `_refresh_view`, action handler, chooser open).
6. The run-phase onboarding is split into scene/milestone units instead of one `onboarding_auction_run` unit. Skipping inspection marks only the inspection unit seen; auction, reveal, cargo, and run-review units still trigger when their scene/milestone condition matches.
7. `RunStore._disable_npc_bids` and `RunManager.is_disable_npc_bids()` are removed. `auction_scene` queries `Director.is_auction_assisted()` at every relevant decision point (start, NPC tick, resolve) so a skip that lands before or after the auction starts correctly toggles NPC bidding. Run snapshots no longer carry this field — a migration drops it on read.
8. Tutorial script ids are save-relevant. New milestone ids are additive, and legacy `onboarding_auction_run` seen state is migrated or interpreted as “all run-phase milestone units already seen” so existing saves do not re-enter the old run tutorial.

## Design

### Unit shape

A unit is the next layer of the catalog: a `TutorialUnit` record wraps a step array with metadata.

```text
TutorialUnit:
  id: String
  steps: Array[TutorialStep]    (resolves via existing TutorialScripts table)
  trigger: Callable             (scene_id: String, ctx: Dictionary) -> bool
  once: bool = true             (mark seen on completion; false = always replayable)
```

The catalog `TutorialScripts` exposes two parallel surfaces: `resolve_script(id) -> Array[TutorialStep]` (existing) and `resolve_unit(id) -> TutorialUnit` (new). Step data still lives in the existing `*_script()` functions; the unit table only adds trigger and `once`. Existing tests that call `resolve_script(id)` keep working.

### Trigger model

A trigger is a `static func` on `TutorialScripts`, signature `(scene_id: String, ctx: Dictionary) -> bool`. The `ctx` snapshot is built once per `register_scene` call by `ScriptDirector` and contains the fields the unit tests need (`day`, `slot`, `onboarding_pending`, `is_run_active`, `storage_item_count`). All known units are iterated in stable registration order, first-match-wins. A unit that has been seen is skipped (when `once` is true).

Chain behavior falls out of trigger conditions:

- `onboarding_hub_intro_choose` fires on `scene == "hub" && day == 0 && slot == SLOT_DAY && onboarding_pending`.
- `onboarding_location_select` fires on `scene == "location_select" && day == 0 && slot == SLOT_DAY && onboarding_pending` and owns the location-pick hint.
- `onboarding_lot_browse` fires on `scene == "lot_browse" && onboarding_pending && first tutorial run context` and owns lot selection / pass-lock teaching.
- `onboarding_inspection` fires on `scene == "inspection" && onboarding_pending && first tutorial run context` and owns item select, unveil, inspect, and review hints.
- `onboarding_auction` fires on `scene == "auction" && onboarding_pending && first tutorial run context` and owns bid / wait-for-resolution hints and the assisted-auction query.
- `onboarding_reveal` fires on `scene == "reveal" && onboarding_pending && first tutorial run context` and owns reveal/continue hints.
- `onboarding_cargo` fires on `scene == "cargo" && onboarding_pending && first tutorial run context` and owns item select, place, and continue hints.
- `onboarding_run_review` fires on `scene == "run_review" && onboarding_pending && first tutorial run context` and owns return-to-hub review.
- `onboarding_storage_choose` fires on `scene == "hub" && day == 0 && slot == SLOT_NIGHT && onboarding_pending` — independent of whether the player saw the run segment.
- `onboarding_storage` fires on `scene == "storage" && onboarding_pending && storage_item_count > 0`.
- `onboarding_day_pass` fires on `scene == "day_summary" && onboarding_pending`.
- `onboarding_shop_choose` fires on `scene == "hub" && day == 1 && slot == SLOT_DAY && onboarding_pending`.
- `onboarding_selling` fires on `scene == "customer_sell" && onboarding_pending && storage_item_count > 0`.

A skip of any single unit leaves every other unit's trigger condition unchanged. The chain stops feeling like a chain, and a mid-run skip cannot suppress later run-phase hints because those hints live in separate milestone units.

### Director query API (Phase 2)

Each gameplay call site that today reads `is_onboarding_pending()` becomes a `Director` query. Most queries reflect the current active unit (runtime only, never persisted). `use_tutorial_location()` is the exception: it evaluates the same game-state/trigger context directly because location cards are populated before the location-select tutorial unit is active.

| API | Replaces | Call site |
| --- | --- | --- |
| `Director.use_tutorial_location()` | `is_onboarding_pending()` in `location_select_scene._populate_cards` | scene `_ready` |
| `Director.is_auction_assisted()` | `RunManager.is_disable_npc_bids()` in `auction_scene` | auction start and per-tick |
| `Director.activity_chooser_target()` | `MetaManager.onboarding_target_activity()` in `hub_scene._show_chooser` | chooser open |
| `Director.is_conservative_sale_locked()` | `is_onboarding_pending() && !tutorial_seen "onboarding_selling"` in `customer_sell_scene._ready` | scene `_ready` |
| `Director.should_disable_pass_in_lot_browse()` | `_is_onboarding_auction_run()` in `lot_browse_scene` | every `_refresh_view` |
| `Director.should_disable_inspection_review()` | `_is_onboarding_auction_run()` in `inspection_scene._ready` and the post-inspect unlock | scene `_ready` and inspect action |
| `Director.skip_all_onboarding()` | (no caller yet) | debug menu only |

The facade methods on `Director` are thin forwarders to `ScriptDirector`; the decision logic lives in `ScriptDirector` because flow state lives there. The same `_active_script_id` field that drives step rendering drives active-unit queries, so closing a script (`stop_script`) automatically clears gated gameplay state. State/trigger queries that happen before a unit is active must use the trigger context directly instead of relying on `_active_script_id`.

### `disable_npc_bids` removal (Phase 3)

`RunStore` has one and only one purpose for the field: the assisted-auction tutorial mechanic. After Phase 2, no caller writes it. Phase 3 deletes:

- `RunStore._disable_npc_bids` backing field
- `RunStore.disable_npc_bids` getter
- `RunStore.initialize` `p_disable_npc_bids` parameter
- `RunStore._encode_fields` `disable_npc_bids` entry
- `RunStore._restore_fields` `disable_npc_bids` read
- `RunStore._apply_migrations` version 1→2 migration block (it only added this field)
- `RunManager.create_run_store` `assisted` parameter
- `RunManager.is_disable_npc_bids()` method

The schema version is bumped from 2 to 3, with a 2→3 migration that erases `disable_npc_bids` and updates `_version`. Old saves load fine: the field is silently dropped.

`auction_scene` reads `Director.is_auction_assisted()` at the three decision points (`_ready` for timer/pass setup, `_on_npc_tick` for bid decision, `_resolve` for the win/loss guard). `is_auction_assisted()` is true only while the `onboarding_auction` unit is active. Because `Director` state is runtime only, a skip that lands before `_ready` correctly turns NPC bidding on; a skip that lands mid-auction stops future assisted checks from returning true.

## Sketch (non-normative)

### Phase 1 — Unit refactor + chain fix

`TutorialUnit` is a new value type in `tutorial_scripts.gd` (kept light, no extra file unless it earns one):

```gdscript
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
```

`TutorialScripts` gains trigger functions and a unit table. Run-phase tutorial content is split into scene/milestone scripts; the old `onboarding_auction_run_script()` is either deleted or kept as a compatibility wrapper that is no longer registered as an active unit:

```gdscript
static func trigger_onboarding_location_select(scene_id: String, ctx: Dictionary) -> bool:
    if not ctx.get("onboarding_pending", false):
        return false
    if int(ctx.get("day", -1)) != 0:
        return false
    if int(ctx.get("slot", -1)) != SlotStore.SLOT_DAY:
        return false
    return scene_id == "location_select"

static func trigger_onboarding_auction(scene_id: String, ctx: Dictionary) -> bool:
    if not ctx.get("onboarding_pending", false):
        return false
    if not ctx.get("first_tutorial_run", false):
        return false
    return scene_id == "auction"

static func trigger_onboarding_storage_choose(scene_id: String, ctx: Dictionary) -> bool:
    if not ctx.get("onboarding_pending", false):
        return false
    if int(ctx.get("day", -1)) != 0:
        return false
    if int(ctx.get("slot", -1)) != SlotStore.SLOT_NIGHT:
        return false
    return scene_id == "hub"

# ...one per onboarding unit and run milestone, plus the existing hub/storage offer rules

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
        # Existing non-onboarding units (hub, storage) keep their offer-prompt behavior
        # via separate code paths in ScriptDirector until Phase 4 sweeps them.
    ]
```

Suggested run-phase script split:

```gdscript
static func onboarding_location_select_script() -> Array[TutorialStep]:
    return [
        TutorialStep.new(... TutorialEvents.LOCATION_SELECTED),
    ]

static func onboarding_lot_browse_script() -> Array[TutorialStep]:
    return [
        TutorialStep.new(... TutorialEvents.LOT_SELECTED),
    ]

static func onboarding_inspection_script() -> Array[TutorialStep]:
    return [
        TutorialStep.new(... TutorialEvents.INSPECTION_ITEM_SELECTED),
        TutorialStep.new(... TutorialEvents.INSPECTION_ITEM_UNVEILED),
        TutorialStep.new(... TutorialEvents.INSPECTION_PERFORMED),
        TutorialStep.new(... TutorialEvents.INSPECTION_REVIEW_OPENED),
        TutorialStep.new(... TutorialEvents.INSPECTION_AUCTION_STARTED),
    ]

static func onboarding_auction_script() -> Array[TutorialStep]:
    return [
        TutorialStep.new(... TutorialEvents.BID_PLACED),
        TutorialStep.new(... TutorialEvents.AUCTION_RESOLVED),
    ]

static func onboarding_reveal_script() -> Array[TutorialStep]:
    return [
        TutorialStep.new(... TutorialEvents.REVEAL_COMPLETED),
        TutorialStep.new(... TutorialEvents.REVEAL_CONTINUED),
    ]

static func onboarding_cargo_script() -> Array[TutorialStep]:
    return [
        TutorialStep.new(... TutorialEvents.CARGO_OPENED),
        TutorialStep.new(... TutorialEvents.CARGO_ITEM_SELECTED),
        TutorialStep.new(... TutorialEvents.CARGO_ITEM_PLACED),
        TutorialStep.new(... TutorialEvents.CARGO_CONTINUE_REQUESTED),
    ]

static func onboarding_run_review_script() -> Array[TutorialStep]:
    return [
        TutorialStep.new(... TutorialEvents.RUN_REVIEWED),
    ]
```

`ScriptDirector` becomes unit-driven:

```gdscript
func _decide_tutorial_for_scene(scene_id: String) -> void:
    var ctx := _build_trigger_context()
    for unit: TutorialUnit in TutorialScripts.units():
        if not _should_consider_unit(unit):
            continue
        if not unit.trigger.call(scene_id, ctx):
            continue
        start_script(unit.id)
        return

    # Existing non-onboarding offer prompts (hub, storage) keep their match
    # branches here.
    match scene_id:
        "hub": _on_hub_registered()
        "storage": _on_storage_registered()

func _build_trigger_context() -> Dictionary:
    return {
        "day": MetaManager.progress.current_day,
        "slot": MetaManager.slot.current_slot,
        "onboarding_pending": MetaManager.is_onboarding_pending(),
        "is_run_active": RunManager.is_run_active(),
        "first_tutorial_run": _is_first_tutorial_run_context(),
        "storage_item_count": MetaManager.storage.storage_items.size(),
    }

func _should_consider_unit(unit: TutorialUnit) -> bool:
    if not unit.once:
        return true
    return not _is_unit_seen(unit.id)
```

Legacy seen compatibility:

```gdscript
func _is_unit_seen(unit_id: String) -> bool:
    if MetaManager.progress.tutorial_seen.has(unit_id):
        return true
    if unit_id in _run_milestone_unit_ids() and MetaManager.progress.tutorial_seen.has("onboarding_auction_run"):
        return true
    return false
```

This keeps existing saves that already saw the old full-run tutorial from re-triggering every new milestone. A later save migration may materialize the new milestone keys, but Phase 1 can treat the old id as a virtual umbrella seen flag.

`stop_script()` shrinks:

```gdscript
func stop_script() -> void:
    if not _is_active:
        return
    var script_id := _active_script_id
    _mark_seen(script_id)
    _complete_onboarding_if_all_milestones_seen()
    Director.hide_tutorial_overlay()
    _clear_state()

func skip_all_onboarding() -> void:
    for unit: TutorialUnit in TutorialScripts.units():
        if unit.id.begins_with("onboarding_"):
            MetaManager.mark_tutorial_seen(unit.id)
    MetaManager.skip_onboarding()
    SaveManager.save()
```

`_end_tutorial()` should call the same `_complete_onboarding_if_all_milestones_seen()` after marking the completed unit seen. The helper treats both naturally completed and individually skipped milestones as seen:

```gdscript
func _complete_onboarding_if_all_milestones_seen() -> void:
    if not MetaManager.is_onboarding_pending():
        return
    for unit_id: String in TutorialScripts.required_onboarding_unit_ids():
        if not _is_unit_seen(unit_id):
            return
    MetaManager.complete_onboarding()
```

`required_onboarding_unit_ids()` includes every onboarding milestone except `onboarding_complete`; `onboarding_complete` is a post-completion popup, not a requirement for completion.

`_onboarding_prerequisite`, `_check_chain_prerequisite`, `_derive_onboarding_segment` are deleted. `_decide_onboarding_for_scene` is folded into `_decide_tutorial_for_scene`.

`onboarding_complete` (the "you finished onboarding!" popup) is kept as a one-step unit with a trigger that fires when all required onboarding milestone units are seen, `onboarding_pending == false`, and `onboarding_complete` is not seen. This prevents it from firing after an arbitrary single unit skip.

### Phase 2 — Director query API + scene cleanup

`Director` facade gains forwarders. `ScriptDirector` owns the decision:

```gdscript
# Director.gd
func use_tutorial_location() -> bool:
    return ScriptDirector.use_tutorial_location()

func is_auction_assisted() -> bool:
    return ScriptDirector.is_auction_assisted()

func activity_chooser_target() -> StringName:
    return ScriptDirector.activity_chooser_target()

func is_conservative_sale_locked() -> bool:
    return ScriptDirector.is_conservative_sale_locked()

func should_disable_pass_in_lot_browse() -> bool:
    return ScriptDirector.should_disable_pass_in_lot_browse()

func should_disable_inspection_review() -> bool:
    return ScriptDirector.should_disable_inspection_review()
```

`ScriptDirector` decides active-unit queries by checking whether the current active unit is the relevant lesson. `use_tutorial_location()` evaluates the trigger context directly because it is called before the location-select unit is active:

```gdscript
# Inside ScriptDirector.gd
func use_tutorial_location() -> bool:
    if _is_unit_seen("onboarding_location_select"):
        return false
    return TutorialScripts.trigger_onboarding_location_select("location_select", _build_trigger_context())

func is_auction_assisted() -> bool:
    if not _is_active:
        return false
    return _active_script_id == "onboarding_auction"

func should_disable_pass_in_lot_browse() -> bool:
    if not _is_active or _active_script_id != "onboarding_lot_browse":
        return false
    return true

func should_disable_inspection_review() -> bool:
    if not _is_active or _active_script_id != "onboarding_inspection":
        return false
    var step := _current_step()
    if step == null:
        return false
    return _active_step_index < 3  # until inspect_btn / INSPECTION_PERFORMED is done
```

Scene rewrites (illustrative; the implementer verifies each call site against the codebase):

```gdscript
# game/meta/location_select/location_select_scene.gd
func _populate_cards() -> void:
    if Director.use_tutorial_location():
        var tutorial_loc := LocationRegistry.get_tutorial_location()
        # ...
    else:
        # normal pool

func _on_card_pressed(card: LocationCard) -> void:
    var location := card.get_location_data()
    RunManager.create_run_store(location, MetaManager.garage.active_car)
    RunManager.set_resume_target(RunStore.RESUME_LOCATION_ENTRY)
    MetaManager.begin_auction()
    EventBus.tutorial_event.emit(TutorialEvents.LOCATION_SELECTED, { })
    SceneRouter.go_to_location_entry()
```

```gdscript
# game/meta/hub/hub_scene.gd — inside _show_chooser
var target := Director.activity_chooser_target()
if target == "auction":
    _storage_btn.disabled = true
    _sell_btn.disabled = true
elif target == "storage":
    # ...
```

```gdscript
# game/meta/customer_sell/customer_sell_scene.gd
func _ready() -> void:
    # ...
    if Director.is_conservative_sale_locked():
        _deal_panel.set_conservative_sale_locked(true)
        Director.script_completed.connect(_on_selling_tutorial_completed)
```

```gdscript
# game/run/inspection/inspection_scene.gd
func _ready() -> void:
    # ...
    _review_button.disabled = Director.should_disable_inspection_review()
    # ...

func _on_inspect_clues_pressed() -> void:
    # ...after INSPECTION_PERFORMED is emitted
    if not Director.should_disable_inspection_review():
        _review_button.disabled = false
```

```gdscript
# game/run/lot_browse/lot_browse_scene.gd
func _refresh_view() -> void:
    var lock_pass := Director.should_disable_pass_in_lot_browse()
    _skip_button.disabled = lock_pass
    # ...
```

`MetaManager.is_onboarding_pending()` and `MetaManager.onboarding_target_activity()` lose their gameplay callers; the methods stay (they remain the source of truth for the saved flag), but their docstring is updated to forbid gameplay call sites. Lint: the standard for tutorials already forbids this; Phase 2 also adds a "do not call from scenes" note to the manager docstring.

### Phase 3 — `disable_npc_bids` removal + `RunStore` migration

`RunStore` changes:

```gdscript
# common/gameplay/store/run_store.gd
func initialize(
        p_location: LocationData,
        p_car: CarData,
        p_ap_cap: int,
        p_refill: int,
        p_entry_fee: int,
        p_fuel_cost: int,
) -> void:
    # assisted-auction state is no longer baked into a run; Director owns it.
    # ...

func _store_version() -> int:
    return 3

func _apply_migrations(data: Dictionary, from_version: int, _ctx: SaveLoadContext) -> Dictionary:
    if from_version < 3:
        data.erase("disable_npc_bids")
    data["_version"] = _store_version()
    return data
```

`RunManager`:

```gdscript
# global/autoloads/managers/run_manager.gd
func create_run_store(location: LocationData, car: CarData) -> void:
    # ...
    r.initialize(location, car, ap_cap, refill, entry_fee, fuel_cost)
    run = r

# is_disable_npc_bids() removed.
```

`auction_scene` rewires all three call sites:

```gdscript
# game/run/auction/auction_scene.gd
func _ready() -> void:
    # ...
    var assist := Director.is_auction_assisted()
    if assist:
        _pass_button.disabled = true
    else:
        _start_npc_timer()

func _on_npc_tick() -> void:
    if Director.is_auction_assisted():
        return  # no NPC bids while the tutorial is teaching
    # ...existing NPC bid logic

func _resolve() -> void:
    if Director.is_auction_assisted() and _last_bidder != "player":
        ToastManager.show_dev_error("assisted auction tried to resolve without player bid")
        _start_circle(0.0)
        return
    # ...existing resolve logic
```

Test updates:

- `test_director.gd::test_onboarding_chain_blocks_later_segment` is deleted; replaced by a trigger-condition test that asserts each unit's trigger accepts/rejects the right scene + state combinations.
- `test_director.gd::test_onboarding_close_skips_onboarding` is rewritten: closing a unit only marks that unit seen; `onboarding_pending` is not cleared. Add a separate test that `Director.skip_all_onboarding()` clears the chain.
- New tests for Phase 1: skipping `onboarding_inspection` marks only that unit seen, and `onboarding_auction`, `onboarding_cargo`, and `onboarding_run_review` can still trigger when their scene/milestone condition matches.
- New tests for Phase 1: a legacy seen flag for `onboarding_auction_run` suppresses every new run-phase milestone unit, so old saves do not replay the split tutorial.
- New tests for Phase 2: each `Director` query returns the expected value with the relevant active unit (`onboarding_lot_browse`, `onboarding_inspection`, `onboarding_auction`). After `stop_script()`, every active-unit query returns false.
- New tests for Phase 3: after `stop_script()` mid-run, `auction_scene`'s NPC tick path sees `is_auction_assisted() == false`. The `RunStore` migration test asserts v2 save payloads load and `disable_npc_bids` is silently dropped.

## Non-Goals

1. Branching or conditional tutorial scripts (no per-choice replays, no replay from a menu inside the run segment). Help button on the hub/storage still replays the legacy `hub`/`storage` tutorial as today.
2. Persisting tutorial step indexes across save/load. The current runtime-only model stays.
3. Localizing tutorial copy.
4. Removing the legacy `hub` / `storage` scripts or the offer-prompt flow. Phase 1 leaves them alone; they coexist with unit-driven onboarding until a future pass sweeps them.
5. Renaming `onboarding_pending` or moving it out of `ProgressStore`.
6. Re-using the trigger condition mechanism for non-tutorial gameplay logic (e.g. story scripting, NPC chatter). Triggers are a tutorial concept; the only consumer is `ScriptDirector`.

## Acceptance Criteria

1. Pressing X on any step of `onboarding_inspection` marks only `onboarding_inspection` as seen. `onboarding_auction`, `onboarding_reveal`, `onboarding_cargo`, `onboarding_run_review`, and `onboarding_storage_choose` still fire when their conditions match.
2. Pressing X on `onboarding_hub_intro_choose` does not prevent `onboarding_location_select` from starting when the player enters `location_select`.
3. `Director.skip_all_onboarding()` is the only API that clears `onboarding_pending` mid-run. The per-step X never calls it. The debug menu shows it.
4. After every required onboarding milestone unit is seen (completed or individually skipped), `MetaManager.is_onboarding_pending()` is false and `onboarding_complete` can trigger once.
5. No gameplay scene (`game/meta/...` or `game/run/...`) reads `MetaManager.is_onboarding_pending()` or `MetaManager.onboarding_target_activity()`. Grep is empty.
6. After skipping `onboarding_inspection` before the auction scene loads, `onboarding_auction` still triggers. After skipping `onboarding_auction` before or during the auction scene, `auction_scene` shows NPC bidding (the `_pass_button` is enabled, the NPC timer runs, and `_on_npc_tick` may place NPC bids).
7. After `RunStore._apply_migrations` reads a version 2 save payload, the resulting run has no `disable_npc_bids` field accessible from gameplay code. The migrated run behaves like a normal run (NPCs bid).
8. `test_director.gd` no longer contains a `test_onboarding_chain_blocks_later_segment` test. New trigger-condition tests cover the same scenarios through the new API.
9. Phase 1 ships with no `RunStore` change. Phase 2 ships with no `RunStore` change. Phase 3 ships the `RunStore` migration. Each phase's diff is independently mergeable.
