# Customer Sell Resume

## Goal

Force-quit (Ctrl+W, OS kill, power loss) during a nightly shop session must resume the player at the same customer with the same items in the car grid, instead of losing the shop to either a fresh customer generation on re-entry or a forced slot advance. The Back button finalizes the shop and rolls the day to the day summary; the hub does not surface any "resume open shop" affordance for now.

## Requirements

1. Force-quit during a shop session and relaunch resumes the player directly into the customer_sell scene with the same nightly customers, the same selected customer, and the same items placed in that customer's car grid at the same cells and rotations.
2. The Back button on the customer_sell scene is treated as closing shop for the night: it clears the nightly customers, clears the in-flight session, advances the day, and routes the player into the day summary. The linear flow is shop → back → day summary, with no path back to the hub while a shop is in flight.
3. Quit-during-shop loss window is the existing 5s save throttle. A hard kill inside that window rolls the in-flight placement state back to the last successful save, matching the run-phase persistence contract. No new save rotation policy.
4. Mid-interaction UI state is not persisted. On resume the player starts a clean interaction for the same item or deal: no held item mid-drag, no receipt dialog open, no dice roll animating. The customer and grid are restored, not the click sequence.
5. The in-flight scene state serializes as the selected customer's id plus a placement array of `{item_id, cell, rotation}` triples. Item identity uses `ItemEntry.id`, which is already stable across save and load.
6. The boot path from the start page's Load Game respects a "scene pointer" field on the save. When set to `"customer_sell"`, the player is routed into the customer_sell scene with the saved session restored. When unset, the player lands in the hub, matching today. New Game never sets the pointer, so it always lands in the hub.
7. Close-shop-via-Back and the end-of-day path both clear the scene pointer, so a quit anywhere in the day-summary flow and reload does not reopen the shop.
8. Pre-feature saves (no shop session section, no scene pointer) load with no migration warning and route to the hub, identical to today. The defensive `data.get(key, default)` reads on both new fields are the migration.

## Design

Three things land together: a per-session shop state slice on the save, a one-field scene pointer on the save, and a Back button that finalizes the shop. The session state is small — one customer id plus a list of up-to-N placement triples, where N is bounded by the customer's car grid capacity. The customer's grid dimensions stay on `CustomerEntry` and do not need to be repeated.

Item identity uses the existing `ItemEntry.id` (assigned by `StorageStore.register_entry`, stable across save). The PackingGrid's `placement: Dictionary[Vector2i → ItemEntry]` and `item_rotations: Dictionary[ItemEntry → int]` round-trip cleanly: serialize as `item_id → {cell, rotation}` dicts, restore by looking up the live entry in `storage.storage_items` and rebuilding the grid's dicts in place. `Vector2i` is not JSON-serializable directly, so the cell becomes `{x, y}`.

The scene pointer is a single `String` field on the new shop session store. `"customer_sell"` while a shop is in flight, `""` otherwise. Set when a shop session opens from the hub, cleared on Back and on end-of-day. This mirrors the run-phase persistence plan's "resume scene" idea but is one field on one store, not a multi-value routing table.

Back button is the same physical control as today but its handler now does a single close-shop-and-end-day transaction (clear session, clear customers, advance day, save) before navigating to the day summary, not a flat `go_to_hub()`. The hub's `current_slot > SLOT_NIGHT` auto-end-day check is unaffected — close-shop is the one and only entry into the day summary from the shop scene.

Resume loss window: the 5s `mark_dirty()` throttle on every placement change and customer switch. A hard crash inside that window rolls the in-flight state back to the last successful `save()`. This matches the run-phase contract and avoids synchronous save on every cell click.

## Sketch (non-normative)

Names and shapes below are implementation hints only; the codebase wins any disagreement.

### New store: ShopSessionStore

Place at `common/gameplay/store/shop_session_store.gd`, registered as a sibling of `CustomersStore` in `MetaManager`. It owns the in-flight shop session for the current night plus the scene pointer:

```gdscript
class_name ShopSessionStore
extends StoreBase

# Customer id of the active customer. Empty when no shop in flight.
var _active_customer_id: String = ""

# [{"item_id": int, "cell": {"x": int, "y": int}, "rotation": int}, ...]
# Empty when no shop in flight or the active customer has no placements.
var _placement: Array = []

# "customer_sell" while a shop is in flight, "" otherwise. Read by the boot
# router to decide whether to land in the shop scene after Load Game.
var _pending_scene: String = ""

func section_id() -> String:
    return "shop_session"

func to_dict() -> Dictionary:
    return {
        "_version": _store_version(),
        "active_customer_id": _active_customer_id,
        "placement": _placement.duplicate(true),
        "pending_scene": _pending_scene,
    }

func from_dict(data: Dictionary, _ctx: SaveLoadContext) -> void:
    var version: int = int(data.get("_version", 1))
    data = _apply_migrations(data, version, _ctx)
    _active_customer_id = str(data.get("active_customer_id", ""))
    _pending_scene = str(data.get("pending_scene", ""))
    _placement = []
    if data.has("placement") and data["placement"] is Array:
        for p: Variant in data["placement"]:
            if p is Dictionary:
                _placement.append(p.duplicate())

# Read-only accessors for scene / tests.
var active_customer_id: String:
    get: return _active_customer_id

var placement: Array:
    get: return _placement.duplicate(true)

var pending_scene: String:
    get: return _pending_scene

# Mutators — called only from MetaManager wrappers.
func set_active_customer(customer_id: String) -> void:
    _active_customer_id = customer_id

func set_placement(placement: Array) -> void:
    _placement = placement.duplicate(true)

func set_pending_scene(value: String) -> void:
    _pending_scene = value

func clear() -> void:
    _active_customer_id = ""
    _placement = []
    _pending_scene = ""

func _store_version() -> int:
    return 1
```

A `clear_customers()` helper on `CustomersStore` is needed by the close-shop path (existing `set_customers([])` works but a named helper is clearer):

```gdscript
# customers_store.gd
func clear_customers() -> void:
    _nightly_customers.clear()
```

### MetaManager wiring

Register the store in `_ready()` next to the other MetaManager stores, and add a section read in `to_dict`/`from_dict` like the existing `customers` section. Add thin wrapper methods that scenes call instead of touching the stores directly:

```gdscript
# Called by customer_sell_scene on enter / customer switch.
func open_shop_session(customer: CustomerEntry) -> void:
    shop_session.set_active_customer(customer.customer_id)
    shop_session.set_placement([])
    shop_session.set_pending_scene("customer_sell")
    SaveManager.save()

# Called on every customer switch and every PackingGrid change.
func update_shop_session(customer: CustomerEntry, placement: Array) -> void:
    shop_session.set_active_customer(
        customer.customer_id if customer != null else ""
    )
    shop_session.set_placement(placement)
    SaveManager.mark_dirty()

# Called on Back from customer_sell_scene. Returns the DaySummary for
# go_to_day_summary. Atomic — one save.
func close_shop_and_end_day() -> DaySummary:
    shop_session.clear()
    customers.clear_customers()
    customers.clear_sales()
    SaveManager.save() # single commit for the close step
    return end_day()
```

`end_day()` is unchanged and already handles day advance, daily cost, sales capture, slot reset, and storage AP reset.

### customer_sell_scene restoration

In `_ready()`, after the default `set_selected(0)` / `_select_customer(0)` setup, check for a saved active customer id. If it points to a valid customer in the live `nightly_customers` list, switch to that customer and reapply the saved placement; otherwise the default selection stands (the first customer, which is the most common case after a successful sale auto-advance).

```gdscript
func _ready() -> void:
    # ... existing wiring ...
    _customers = MetaManager.customers.nightly_customers.duplicate()
    if _customers.is_empty():
        _show_empty_state("No customers tonight.")
        return
    _customer_queue.setup(_customers)
    _select_customer(0)

    var saved_id: String = MetaManager.shop_session.active_customer_id
    if saved_id != "":
        var idx := _find_customer_index(saved_id)
        if idx >= 0:
            _customer_queue.set_selected(idx)
            _select_customer(idx)
            _apply_saved_placement(MetaManager.shop_session.placement)

# Replays the saved (item_id, cell, rotation) tuples onto the live PackingGrid.
func _apply_saved_placement(placement: Array) -> void:
    var grid := _car_panel.get_grid()
    var by_id: Dictionary = { }
    for item in MetaManager.storage.storage_items:
        var entry := item as ItemEntry
        if entry != null:
            by_id[entry.id] = entry
    for p: Dictionary in placement:
        var entry: ItemEntry = by_id.get(int(p.get("item_id", -1)))
        if entry == null:
            continue
        var cell_dict: Dictionary = p.get("cell", { })
        var cell := Vector2i(
            int(cell_dict.get("x", 0)),
            int(cell_dict.get("y", 0)),
        )
        var rot: int = int(p.get("rotation", 0))
        if grid.can_place(entry, cell):
            grid.place(entry, cell)
            grid.item_rotations[entry] = rot
    _refresh_car_display()
```

Hook the placement snapshot into the scene's existing `_on_car_placement_changed` (the signal goes PackingGrid → CustomerCarPanel → scene), and the active-customer update into the existing `_on_customer_selected`:

```gdscript
func _on_customer_selected(index: int) -> void:
    _select_customer(index)
    MetaManager.update_shop_session(
        _get_selected_customer(),
        _serialize_placement(),
    )

func _on_car_placement_changed() -> void:
    _refresh_car_display()
    MetaManager.update_shop_session(
        _get_selected_customer(),
        _serialize_placement(),
    )

func _serialize_placement() -> Array:
    var grid := _car_panel.get_grid()
    var snapshot: Array = []
    for cell: Vector2i in grid.placement.keys():
        var entry := grid.placement[cell] as ItemEntry
        if entry == null:
            continue
        snapshot.append({
            "item_id": entry.id,
            "cell": {"x": cell.x, "y": cell.y},
            "rotation": int(grid.item_rotations.get(entry, 0)),
        })
    return snapshot
```

A placement that fails the `can_place` check (grid size changed, item removed mid-restore) is silently dropped. The car display simply shows fewer items. This is consistent with the run-phase persistence plan's "partial restoration is acceptable for run state" — the alternative is warning the player mid-resume, which is jarring.

### Back-button close-shop

Replace the current `_on_back_pressed` body with a single transaction plus a day-summary call. The day summary is produced by `MetaManager.close_shop_and_end_day()` and is the same kind of summary the hub uses at `current_slot > SLOT_NIGHT`.

```gdscript
func _on_back_pressed() -> void:
    var summary := MetaManager.close_shop_and_end_day()
    SceneRouter.go_to_day_summary(summary)
```

When all customers are served, the existing `_show_empty_state("All customers served! End of night.")` path can call the same close-shop transaction (the player has to leave the scene somehow). The cleanest version adds a "Close shop" button on the empty state that calls `_on_back_pressed()`; the existing "End of night" copy already implies the action.

### Boot routing

The start page's Load Game path already calls `SaveManager.switch_to_slot(slot)` then `SceneRouter.go_to_hub()`. Add a check on the saved `pending_scene` after `switch_to_slot` returns:

```gdscript
func _execute_load_game(slot: int) -> void:
    SaveManager.switch_to_slot(slot)
    if MetaManager.shop_session.pending_scene == "customer_sell":
        SceneRouter.go_to_customer_sell()
    else:
        SceneRouter.go_to_hub()
```

Same read on `_execute_new_game` — a fresh game has no pending scene, so it lands in the hub as today. The `GameManager._boot_normal` path is unchanged; the start page remains the boot scene and remains the routing decision point.

### Test seams

Add a unit test for `ShopSessionStore`: round-trip the placement list (cells with rotation 0..3), default-empty restore when the section is absent, and a `clear()` reset. Add a scene-level test that drives `_ready()` with a pre-seeded `ShopSessionStore` (one active customer id, two placement entries) and asserts the right customer and grid placements are restored. Update `test_save_round_trip.gd`'s `test_fixture_expected_section_keys` if it wants to assert presence of the new section (today it asserts presence of expected keys, not exclusivity, so the existing fixture remains valid without an update — only do this if you want a forward assertion that the fixture will fail loudly if the section is dropped).

## Non-Goals

1. Pause-and-resume from the hub with an open shop in flight. Hub-side resume is deferred to a separate discussion; close-shop-via-Back makes the in-flight session non-resumable from the hub's perspective by design.
2. Persisting mid-interaction UI state (held item, receipt dialog, dice roll animation). The resume starts at the same customer and the same grid, not in the middle of a click sequence.
3. Synchronous save on every grid cell edit. The 5s throttle is the contract; hard-kill inside that window rolls back to the last successful save, matching the run-phase persistence plan.
4. Changing the per-night customer generation algorithm or volume. This only adds persistence to the session that is already in flight.
5. A "saved placement is no longer valid" warning UI. Failed placements are silently dropped; the player sees a car with fewer items on resume.

## Acceptance Criteria

1. Force-quit (Ctrl+W) with one item placed in the active customer's car grid, relaunch, click Load Game: the player is taken directly into the customer_sell scene with the same nightly customers, the same selected customer, and the same item in the same cell at the same rotation.
2. Force-quit with two customers served (one served, one remaining) and two items placed for the remaining customer, relaunch, click Load Game: the customer_sell scene shows the served customer already removed, the remaining customer auto-selected, and the two items in the saved cells and rotations.
3. Hard kill the game within 5 seconds of placing the most recent item, relaunch, click Load Game: the in-flight session rolls back to the placement state from the last successful save, matching the run-phase loss contract.
4. From the customer_sell scene with no items placed, click Back: the player is taken to the day summary, the save shows `pending_scene == ""`, `nightly_customers` is empty, and the next Load Game lands in the hub.
5. With an in-flight shop session, mid-drag an item into the air (held above the car but not yet placed), quit, relaunch, click Load Game: the held item is not carried over; the player sees the same grid state but no item in hand and the placement is unchanged from the last successful save.
6. Open the receipt dialog with a confirmed price, quit, relaunch, click Load Game: the dialog is not present; the price and strategy are not pre-loaded. The player must re-press Conservative or Aggressive.
7. Old saves (no `shop_session` section, no `pending_scene` field) load with no migration warning and land in the hub on Load Game, identical to today.
8. New Game (no save in slot) never routes to customer_sell, identical to today.
9. Serve all customers and use the empty-state close path: the day summary is shown, the save shows `pending_scene == ""` and an empty `nightly_customers`, and the next Load Game lands in the hub.
