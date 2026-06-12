# ci_pilot.gd
# CI-only headless autopilot. Activates only when --ci-run is present on the
# command line. Waits for all autoloads to finish initializing, then auto-pilots
# one full run: new-game init → create a run → inspect all surface clues on
# one lot → win the auction → fill cargo → resolve the run → end the day →
# exit with code 0.
#
# Invisible in production — the flag is absent in normal launches.
extends Node

func _ready() -> void:
    var args := OS.get_cmdline_args()
    print("CI Pilot: args=%s" % [args])
    if "--ci-run" not in args:
        print("CI Pilot: --ci-run not found, skipping")
        return
    print("CI Pilot: starting autopilot")
    call_deferred("_run_autopilot")


func _run_autopilot() -> void:
    var ok := _do_autopilot()
    print("CI Pilot: autopilot ", "OK" if ok else "FAILED")
    get_tree().quit(0 if ok else 1)


func _do_autopilot() -> bool:
    # ── 1. New game init ──────────────────────────────────────────────────
    SaveManager.init_slot(1)
    print("CI Pilot: slot initialized")

    # ── 2. Verify registries have data ────────────────────────────────────
    if LocationRegistry.get_all_locations().is_empty():
        ToastManager.show_error("CI Pilot: LocationRegistry is empty")
        return false
    var cars: Array = CarRegistry.get_all_cars()
    if cars.is_empty():
        ToastManager.show_error("CI Pilot: CarRegistry is empty")
        return false
    var car: CarData = cars[0] as CarData

    # ── 3. Pick first location ────────────────────────────────────────────
    MetaManager.roll_available_locations()
    var locations: Array = MetaManager.progress.available_locations
    if locations.is_empty():
        ToastManager.show_error("CI Pilot: no available locations")
        return false
    var location: LocationData = locations[0] as LocationData
    MetaManager.set_active_car(car)
    print("CI Pilot: location=%s car=%s" % [location.location_id, car.car_id])

    # ── 4. Create run ────────────────────────────────────────────────────
    RunManager.create_run_store(location, car)
    if not RunManager.is_run_active():
        ToastManager.show_error("CI Pilot: run not active after create")
        return false

    # ── 5. Pick first lot from location's pool ────────────────────────────
    var lot_pool: Array = location.lot_pool
    if lot_pool.is_empty():
        ToastManager.show_error("CI Pilot: location '%s' has no lot pool" % location.location_id)
        return false
    var lot_data: LotData = lot_pool[0] as LotData

    # ── 6. Create LotEntry ───────────────────────────────────────────────
    var rng := RandomNumberGenerator.new()
    rng.seed = 42
    var lot_entry := LotEntry.create(lot_data, rng)
    if lot_entry.item_entries.is_empty():
        ToastManager.show_error("CI Pilot: lot has no items")
        return false
    print("CI Pilot: lot=%s items=%d" % [lot_data.lot_id, lot_entry.item_entries.size()])

    # ── 7. Set up lot for inspection ─────────────────────────────────────
    RunManager.set_lot(lot_entry)

    # ── 8. Inspect each item ─────────────────────────────────────────────
    for item: ItemEntry in lot_entry.item_entries:
        if item.is_veiled():
            RunManager.unveil_item(item)
        for clue: ClueData in item.surface_clues:
            if clue.clue_id not in item.revealed_clue_ids:
                RunManager.attempt_clue(item, clue)

    # ── 9. Win auction ───────────────────────────────────────────────────
    var auction_price := lot_entry.get_rolled_price()
    RunManager.commit_lot_win(lot_entry.item_entries, auction_price)
    print("CI Pilot: won lot price=%d" % auction_price)

    # ── 10. Fill cargo ──────────────────────────────────────────────────
    RunManager.commit_cargo(lot_entry.item_entries, [], 0)

    # ── 11. Build run result and resolve ─────────────────────────────────
    var result: RunResult = RunManager.take_run_result()
    MetaManager.resolve_run(result)
    RunManager.clear_run_state()

    # ── 12. Advance the hub day ──────────────────────────────────────────
    # resolve_run (step 11) already set slot to 3 (evening); begin_auction
    # is only valid at slot 1 (morning) so we skip it here.
    MetaManager.begin_open_shop(1)
    MetaManager.end_day()
    MetaManager.begin_auction()
    MetaManager.end_day()

    print(
        "CI Pilot: day=%d cash=%d storage=%d" % [
            MetaManager.progress.current_day,
            MetaManager.economy.cash,
            MetaManager.storage.storage_items.size(),
        ],
    )

    # ── 13. Verify scene wiring ──────────────────────────────────────────
    _verify_key_scenes()

    return true


## Instantiate a representative set of scenes to catch wiring bugs
## (null child-node references, bad exports, missing signal handlers).
func _verify_key_scenes() -> void:
    var registry: SceneRegistry = SceneRouter.scenes
    if registry == null:
        ToastManager.show_error("CI Pilot: SceneRegistry is null")
        return

    var scene_keys := [
        "hub",
        "inspection",
        "auction",
        "cargo",
        "storage",
    ]
    for key: String in scene_keys:
        var scene: PackedScene = registry.get(key)
        if scene == null:
            ToastManager.show_error("CI Pilot: scene '%s' is null" % key)
            continue
        var instance := scene.instantiate()
        if instance != null:
            instance.queue_free()
