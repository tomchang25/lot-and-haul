# Tutorial Override Inversion

## Goal

Remove the gameplay-scene → tutorial-flow coupling that the Director query API introduced, so gameplay scenes no longer query the tutorial flow layer for assisted-auction, locked-sale, forced-activity, forced-location, or per-step gating state. A runtime gameplay-override store sits between them: the tutorial flow layer pushes named overrides when a tutorial unit starts, advances, or stops; gameplay scenes read the override store the same way they read any other gameplay state. This closes the ownership hole the tutorial standard describes but the query API reopened — gameplay scenes never reference tutorial flow state, tutorial unit ids, step indexes, or tutorial completion signals.

## Requirements

1. Gameplay scenes must not call the tutorial flow layer (`Director` / `ScriptDirector`) for gameplay decisions. The assisted-auction flag, conservative-sale lock, lot-pass lock, forced activity, forced location pool, and inspection-review gate are gameplay concerns read from a gameplay-owned runtime store, not from the tutorial. Why: the tutorial standard forbids gameplay systems from referencing tutorial flow state; the query API violated this by making scenes call tutorial methods whose answers depended on the active tutorial unit id and step index.
2. A runtime-only gameplay-override store holds the active override set. It is not persisted and clears on save-slot reset/load. Why: overrides are session-scoped; persisting them would reintroduce the run-snapshot tutorial-baking problem the prior refactor removed.
3. Each tutorial unit declares the gameplay overrides it needs active while it plays. An override may be released mid-unit when a specific tutorial event fires, so a gate can lift partway through a unit. On unit start the declared overrides activate; on release-event or unit stop they deactivate. Why: both whole-unit overrides (assisted auction) and part-unit gates (inspection review until the inspect action) must be expressible without scenes inspecting step indexes.
4. Onboarding-spanning overrides (forced activity, forced location, conservative-sale lock) that are not bound to a single unit's lifetime are recomputed by the flow layer on every scene registration and on onboarding completion, then pushed to the override store. Why: these derive from day/slot/onboarding state, not from an active unit, so their lifecycle is tied to the onboarding phase, not a unit.
5. The tutorial presentation layer (`Director`) and the gameplay-override store are separate concerns. `Director` owns anchors, overlay, and step rendering; the override store owns active gameplay overrides. `Director` must not read or write the override store. Why: keeping presentation, flow, and gameplay-override state in three distinct owners preserves the existing ownership boundary and prevents presentation from depending on gameplay logic.
6. Scenes must read the override store only after they have registered their scene anchors, so the flow layer has had the chance to start the matching tutorial and activate its overrides before the scene reads them. Scenes whose gameplay setup currently runs before anchor registration must reorder so registration comes first. Why: tutorial start is triggered synchronously by scene registration; reading overrides before registration would always see them inactive — the latent timing defect in the current query API.
7. No gameplay scene connects to the tutorial completion signal to undo a gameplay override. Overrides clear through the override store (the flow layer deactivates them on unit stop), and the scene reacts to the store's change signal if it needs to update visuals immediately. Why: the existing completion-signal connection is the most direct flow-into-scene leak and must be removed by the inversion.
8. The existing tutorial anchor registration and tutorial-event emission bindings stay. Scenes still register anchors and emit semantic tutorial events. Why: those couplings are intrinsic — the presentation layer needs screen geometry only the scene has, and gameplay milestones originate in the scene — and are explicitly sanctioned by the tutorial standard.

## Design

### Three owners, one shared vocabulary

The flow layer (`ScriptDirector`) owns _which_ overrides are active and pushes them. A new runtime-only gameplay-override store owns the _active set_ and broadcasts changes. Gameplay scenes own _how_ an override affects them and read the store. The only thing all three share is a vocabulary of override ids — a small constants class, comparable to how tutorial events are a shared vocabulary today.

### Override vocabulary

| Override                 | Meaning when active                                 | Source                                                                   |
| ------------------------ | --------------------------------------------------- | ------------------------------------------------------------------------ |
| assisted auction         | no NPC bidding, pass disabled                       | onboarding auction unit (whole-unit)                                     |
| lot pass locked          | pass/skip disabled in lot browse                    | onboarding lot-browse unit (whole-unit)                                  |
| conservative sale locked | conservative sell path locked                       | onboarding phase, until selling milestone seen                           |
| forced activity          | chooser offers only one activity (payload names it) | onboarding phase, day/slot-derived                                       |
| forced tutorial location | location pool restricted to the tutorial location   | onboarding phase, day-0 day-slot                                         |
| inspection review gated  | review button disabled                              | onboarding inspection unit, released when the inspect-action event fires |

### Override lifecycle

Two lifecycles, both pushed by the flow layer:

- **Unit-scoped**: declared on a tutorial unit. Activated when the unit starts. Deactivated when the unit stops (completes, is skipped, or runtime resets). An override may carry a _release event_: it deactivates the moment that tutorial event fires, even while the unit keeps playing — this models the inspection-review gate without any scene knowing the step index.
- **Onboarding-scoped**: not tied to a unit. The flow layer recomputes these on every scene registration and on onboarding completion, from the same trigger context it already builds (day, slot, onboarding pending, seen milestones). They activate when the context says they should and deactivate when it no longer does or onboarding completes.

### Timing fix

Scene registration triggers tutorial start synchronously (the registration signal is handled inline). Therefore a scene that reads an override before it registers its anchors will always see the override inactive — even when the tutorial is about to start for that scene. The current query API has this latent defect on the auction and inspection scenes (the assisted and review-gate checks run before registration, so they read inactive and effectively no-op). The inversion requires scenes to register anchors first, then run gameplay setup that depends on overrides. This both removes the coupling and makes the gates actually effective.

### What stays

Anchor registration, transient anchor registration/unregistration, and tutorial-event emission remain scene responsibilities and remain unchanged. The presentation/flow split is untouched. The override store is additive: a new owner between flow and gameplay, not a replacement for either.

## Sketch (non-normative)

### New runtime store

A new autoload, inserted after `ScriptDirector`, runtime-only, cleared on save reset:

```gdscript
# gameplay_override.gd
# Runtime-only store of active gameplay overrides. Not persisted.
# The tutorial flow layer pushes overrides; gameplay scenes read them.
# Cleared on save_runtime_reset so a slot switch cannot leak overrides.
extends Node

signal override_changed(id: StringName, active: bool, payload: Variant)

var _active: Dictionary = {}  # StringName -> payload

func _ready() -> void:
    EventBus.save_runtime_reset.connect(clear_all)

func is_active(id: StringName) -> bool:
    return _active.has(id)

func payload(id: StringName) -> Variant:
    return _active.get(id, null)

func activate(id: StringName, payload: Variant = null) -> void:
    _active[id] = payload
    override_changed.emit(id, true, payload)

func deactivate(id: StringName) -> void:
    var had := _active.has(id)
    _active.erase(id)
    if had:
        override_changed.emit(id, false, null)

func clear_all() -> void:
    var ids := _active.keys()
    _active.clear()
    for id in ids:
        override_changed.emit(id, false, null)
```

### Shared vocabulary

A constants class, the only symbol all three owners share:

```gdscript
# gameplay_override.gd
class_name GameplayOverride

const ASSISTED_AUCTION := &"assisted_auction"
const LOT_PASS_LOCKED := &"lot_pass_locked"
const CONSERVATIVE_SALE_LOCKED := &"conservative_sale_locked"
const FORCED_ACTIVITY := &"forced_activity"          # payload: StringName
const FORCED_TUTORIAL_LOCATION := &"forced_tutorial_location"
const INSPECTION_REVIEW_GATED := &"inspection_review_gated"
```

### Unit declares overrides

The unit record gains an optional override list. An override entry carries an optional release event:

```gdscript
class TutorialUnit:
    var id: String
    var steps_resolver: Callable
    var trigger: Callable
    var once: bool = true
    var overrides: Array[TutorialOverrideSpec] = []

class TutorialOverrideSpec:
    var id: StringName
    var payload: Variant = null
    var release_event: StringName = &""  # empty = active for whole unit

    static func whole(id: StringName, payload: Variant = null) -> TutorialOverrideSpec:
        var s := TutorialOverrideSpec.new()
        s.id = id
        s.payload = payload
        return s

    static func until(id: StringName, event: StringName) -> TutorialOverrideSpec:
        var s := TutorialOverrideSpec.new()
        s.id = id
        s.release_event = event
        return s
```

Catalog entries attach overrides where needed; units that need none leave the list empty:

```gdscript
static func units() -> Array[TutorialUnit]:
    var u := []
    # ...build each unit...
    var auction := TutorialUnit.new("onboarding_auction", onboarding_auction_script, trigger_onboarding_auction)
    auction.overrides = [TutorialOverrideSpec.whole(GameplayOverride.ASSISTED_AUCTION)]
    u.append(auction)

    var lot := TutorialUnit.new("onboarding_lot_browse", onboarding_lot_browse_script, trigger_onboarding_lot_browse)
    lot.overrides = [TutorialOverrideSpec.whole(GameplayOverride.LOT_PASS_LOCKED)]
    u.append(lot)

    var insp := TutorialUnit.new("onboarding_inspection", onboarding_inspection_script, trigger_onboarding_inspection)
    insp.overrides = [TutorialOverrideSpec.until(GameplayOverride.INSPECTION_REVIEW_GATED, TutorialEvents.INSPECTION_PERFORMED)]
    u.append(insp)
    # ...rest unchanged...
    return u
```

### Flow layer pushes overrides

On start, activate the unit's overrides. On event, release any override whose release event matches. On stop/reset, deactivate the unit's overrides. Onboarding-scoped overrides are recomputed on each scene registration:

```gdscript
# script_director.gd
var _active_unit_overrides: Array[StringName] = []

func start_script(script_id: String) -> void:
    # ...existing resolve + validate + state set...
    var unit := _find_unit(script_id)
    if unit != null:
        for spec in unit.overrides:
            GameplayOverride.activate(spec.id, spec.payload)
            _active_unit_overrides.append(spec.id)
    _show_current_step()

func _on_tutorial_event(event_id: StringName, _payload: Dictionary) -> void:
    # ...existing step-advance logic...
    var unit := _find_unit(_active_script_id)
    if unit != null:
        for spec in unit.overrides:
            if spec.release_event == event_id and GameplayOverride.is_active(spec.id):
                GameplayOverride.deactivate(spec.id)
                _active_unit_overrides.erase(spec.id)

func stop_script() -> void:
    # ...existing mark-seen + complete-check...
    _deactivate_unit_overrides()
    Director.hide_tutorial_overlay()
    _clear_state()

func reset_runtime() -> void:
    GameplayOverride.clear_all()
    # ...existing reset...

func _deactivate_unit_overrides() -> void:
    for id in _active_unit_overrides:
        GameplayOverride.deactivate(id)
    _active_unit_overrides.clear()
```

Onboarding-scoped overrides recomputed on scene registration (the flow layer already builds the trigger context here):

```gdscript
func _on_scene_registered(scene_id: String) -> void:
    _current_scene_id = scene_id
    _refresh_onboarding_overrides()
    # ...existing active-continuation / decide logic...

func _refresh_onboarding_overrides() -> void:
    var ctx := _build_trigger_context()
    _set_onboarding_override(GameplayOverride.FORCED_TUTORIAL_LOCATION, _onboarding_forces_tutorial_location(ctx))
    _set_onboarding_override(GameplayOverride.FORCED_ACTIVITY, _onboarding_forced_activity(ctx))
    _set_onboarding_override(GameplayOverride.CONSERVATIVE_SALE_LOCKED, _onboarding_locks_conservative_sale(ctx))

func _set_onboarding_override(id: StringName, payload: Variant) -> void:
    # payload null means "should be inactive"
    if payload != null and not GameplayOverride.is_active(id):
        GameplayOverride.activate(id, payload)
    elif payload == null and GameplayOverride.is_active(id):
        GameplayOverride.deactivate(id)

func _onboarding_forces_tutorial_location(ctx: Dictionary) -> Variant:
    if not ctx.get("onboarding_pending", false):
        return null
    if _is_unit_seen("onboarding_location_select"):
        return null
    if int(ctx.get("day", -1)) == 0 and int(ctx.get("slot", -1)) == SlotStore.SLOT_DAY:
        return true
    return null

func _onboarding_forced_activity(ctx: Dictionary) -> Variant:
    # Same day/slot derivation as the old _derive_activity_chooser_target,
    # but pushed as an override payload (StringName) instead of pulled.
    if not ctx.get("onboarding_pending", false):
        return null
    # day 0 day -> auction, day 0 night -> storage, day 1 day -> selling
    # ...return the StringName or null...

func _onboarding_locks_conservative_sale(ctx: Dictionary) -> Variant:
    if not ctx.get("onboarding_pending", false):
        return null
    if _is_unit_seen("onboarding_selling"):
        return null
    return true
```

### Director facade — query methods removed

The six gameplay-facing query methods on `Director` and their `ScriptDirector` implementations are deleted. `Director` keeps only presentation plus the start/advance/skip facade. The standard's anti-pattern list already forbids gameplay calling tutorial flow; this pass makes it true:

```gdscript
# Removed from Director.gd:
#   use_tutorial_location, is_auction_assisted, activity_chooser_target,
#   is_conservative_sale_locked, should_disable_pass_in_lot_browse,
#   should_disable_inspection_review
# Removed from ScriptDirector.gd:
#   the matching implementations + _derive_activity_chooser_target
```

### Scene rewrites — register first, then read overrides

Auction: register before setup so the assisted override is active by the time the scene reads it. This also fixes the latent defect where the assisted check ran before the tutorial started:

```gdscript
# auction_scene.gd _ready
func _ready() -> void:
    # ...node setup, _init_auction()...
    Director.register_scene("auction", { "bid_btn": _bid_button, "price_label": _price_label })
    var assisted := GameplayOverride.is_active(GameplayOverride.ASSISTED_AUCTION)
    if assisted:
        _pass_button.disabled = true
    else:
        _start_npc_timer()

func _on_npc_tick() -> void:
    if GameplayOverride.is_active(GameplayOverride.ASSISTED_AUCTION):
        return
    # ...existing NPC bid logic...

func _resolve() -> void:
    if GameplayOverride.is_active(GameplayOverride.ASSISTED_AUCTION) and _last_bidder != "player":
        # ...guard...
        return
    # ...existing resolve...
```

Lot browse: register before the first refresh that reads the override; gate each pass attempt on the override:

```gdscript
# lot_browse_scene.gd _ready
func _ready() -> void:
    # ...build cards...
    Director.register_scene("lot_browse", { "lot_cards": _lot_card_container, "cargo_btn": _cargo_button, "skip_btn": _skip_button })
    _refresh_view()

func _refresh_view() -> void:
    var lock_pass := GameplayOverride.is_active(GameplayOverride.LOT_PASS_LOCKED)
    _skip_button.disabled = lock_pass
    # ...rest...

func _on_pass_pressed() -> void:
    if GameplayOverride.is_active(GameplayOverride.LOT_PASS_LOCKED):
        return
    # ...existing...

func _on_skip_pressed() -> void:
    if GameplayOverride.is_active(GameplayOverride.LOT_PASS_LOCKED):
        return
    # ...existing...
```

Inspection: register before the review-button initial state; the gate lifts automatically when the inspect event fires (the flow layer releases the override). The post-action manual re-enable is no longer needed:

```gdscript
# inspection_scene.gd _ready
func _ready() -> void:
    # ...setup...
    Director.register_scene("inspection", { "item_browser": _item_browser, "review_btn": _review_button, "unveil_btn": _action_unveil_button, "inspect_btn": _action_inspect_button })
    _review_button.disabled = GameplayOverride.is_active(GameplayOverride.INSPECTION_REVIEW_GATED)
    GameplayOverride.override_changed.connect(_on_override_changed)

func _on_override_changed(id: StringName, active: bool, _payload: Variant) -> void:
    if id == GameplayOverride.INSPECTION_REVIEW_GATED:
        _review_button.disabled = active

func _do_clue_chain(entry: ItemEntry) -> void:
    # ...existing clue logic...
    _complete_action()
    EventBus.tutorial_event.emit(TutorialEvents.INSPECTION_PERFORMED, {})
    # No manual re-enable here — the override release (driven by the event
    # above, handled in ScriptDirector) clears the gate; _on_override_changed
    # updates the button visual.
```

Customer sell: the conservative lock is read from the override store; the completion-signal connection is replaced by reacting to the override store. The gameplay gate is checked at the action, the visual lock follows the override:

```gdscript
# customer_sell_scene.gd _ready
func _ready() -> void:
    # ...setup...
    Director.register_scene("customer_sell", { ... })
    _apply_conservative_lock_visual()
    GameplayOverride.override_changed.connect(_on_override_changed)

func _apply_conservative_lock_visual() -> void:
    _deal_panel.set_conservative_sale_locked(GameplayOverride.is_active(GameplayOverride.CONSERVATIVE_SALE_LOCKED))

func _on_override_changed(id: StringName, active: bool, _payload: Variant) -> void:
    if id == GameplayOverride.CONSERVATIVE_SALE_LOCKED:
        _deal_panel.set_conservative_sale_locked(active)

func _on_conservative_requested(price: int) -> void:
    if GameplayOverride.is_active(GameplayOverride.CONSERVATIVE_SALE_LOCKED):
        return  # gameplay gate at the action
    # ...existing receipt flow...

# _on_selling_tutorial_completed and the Director.script_completed connection are deleted.
```

Hub chooser: the forced-activity payload is read from the override store when the chooser opens:

```gdscript
# hub_scene.gd _show_chooser
func _show_chooser() -> void:
    # ...show buttons...
    _auction_btn.disabled = false
    _storage_btn.disabled = false
    _sell_btn.disabled = false
    var forced := GameplayOverride.payload(GameplayOverride.FORCED_ACTIVITY) as StringName
    if forced == &"auction":
        _storage_btn.disabled = true
        _sell_btn.disabled = true
    elif forced == &"storage":
        _auction_btn.disabled = true
        _sell_btn.disabled = true
    elif forced == &"selling":
        _auction_btn.disabled = true
        _storage_btn.disabled = true
    # ...rest unchanged...
```

Location select: register before populating cards, then read the override. The `cards_container` anchor is already registered, so the location-select hint renders correctly once cards populate (the per-frame rect tracking repositions it; an initial empty-container rect triggers a deferred layout retry that resolves the same frame populate runs):

```gdscript
# location_select_scene.gd _ready
func _ready() -> void:
    _back_button.pressed.connect(_on_back_pressed)
    Director.register_scene("location_select", { "cards_container": _cards_container, "back_btn": _back_button })
    _populate_cards()

func _populate_cards() -> void:
    var locations: Array[LocationData] = []
    if GameplayOverride.is_active(GameplayOverride.FORCED_TUTORIAL_LOCATION):
        var tutorial_loc := LocationRegistry.get_tutorial_location()
        # ...guard + use tutorial_loc...
        locations = [tutorial_loc]
    else:
        # ...normal pool...
```

### Autoload order

The new store registers after `ScriptDirector` (so the flow layer exists before it is read) and before `GameManager`. It subscribes to `save_runtime_reset` like `ScriptDirector` does.

### Standard update

The tutorial standard's ownership section gains a third owner line: gameplay overrides live in a runtime store the flow layer pushes and gameplay scenes read; scenes must not query the tutorial flow layer for gameplay state. The anti-pattern examples join the removed query methods to the existing list.

### Tests

- Existing query-method tests in the director test suite are rewritten to assert against the override store: starting the relevant unit activates the right override; stopping or skipping deactivates it; the inspection-review override deactivates when the inspect event fires mid-unit.
- New tests: onboarding-scoped overrides activate/deactivate as the trigger context changes across scene registrations; `save_runtime_reset` clears the store and emits deactivation for each previously-active override.
- New tests: auction setup reads the assisted override as active after registration (the timing-fix), and as inactive after the unit is skipped before the scene loads.
- A grep-backed check asserts no reference to the tutorial flow layer remains in the gameplay scene files for gameplay decisions.

## Non-Goals

1. A push-only model where scenes never query the store and only react to its change signal. The sketch keeps read-at-decision-point queries because the scenes already have setup/decision methods; the signal is used only where a visual must update mid-scene (conservative-sale lock, inspection-review gate). A full push model is a later refinement, not this pass.
2. Persisting overrides or baking them into run snapshots. They are runtime-only, matching the prior refactor's removal of the persisted assisted-auction field.
3. Renaming or splitting the existing tutorial units, triggers, or step arrays. The unit catalog and trigger model from the prior refactor are unchanged; this pass only adds override declarations to existing units.
4. Moving the override vocabulary into a fully gameplay-generic system with non-tutorial writers. The constants class is named for gameplay overrides, but today the only writer is the tutorial flow layer. Generalizing to other writers (debug cheats, challenge modes) is a future concern; the store already supports it without further changes.
5. Changing anchor registration, transient anchor handling, or tutorial-event emission. Those scene bindings are intrinsic and stay as the standard sanctions.

## Acceptance Criteria

1. No gameplay scene file under the gameplay scene trees references the tutorial flow layer for a gameplay decision. A search for the removed query method names in those files returns nothing.
2. Starting the onboarding auction unit activates the assisted-auction override; the auction scene, having registered its anchors before setup, starts with NPC bidding suppressed and the pass button disabled. Skipping the unit before the scene loads leaves the override inactive, so the auction runs with NPC bidding and pass enabled.
3. The conservative-sale lock is active from onboarding start until the selling milestone is seen; completing or skipping that milestone deactivates it, and the customer-sell scene updates its deal panel without any connection to a tutorial completion signal.
4. The inspection-review gate is active while the onboarding inspection unit plays and lifts the moment the inspect-action tutorial event fires, without the inspection scene reading any step index.
5. The forced-activity and forced-tutorial-location overrides are active during the onboarding phases that previously drove them, and deactivate when onboarding completes or the relevant milestone is seen.
6. A save-slot reset clears the override store and emits a deactivation for every previously-active override, so a slot switch cannot leave a gameplay override stuck on.
7. The tutorial presentation layer (anchor registry, overlay, step rendering) is unchanged in its public surface and continues to render steps correctly after the scene reordering.
8. The unit catalog, trigger functions, step arrays, and tutorial-event constants are unchanged; only override declarations are added to existing units.
