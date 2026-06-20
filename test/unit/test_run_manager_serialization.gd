# test_run_manager_serialization.gd
# Unit tests for active run snapshot serialization standardization.
extends GutTest

var _ctx: SaveLoadContext

# ══ Helpers ═══════════════════════════════════════════════════════════════════


func _car() -> CarData:
    var c := CarRegistry.get_car_by_id("test_car")
    assert_not_null(c, "test_car should exist in CarRegistry")
    return c


func _location() -> LocationData:
    var l := LocationRegistry.get_location_by_id("test_location")
    assert_not_null(l, "test_location should exist in LocationRegistry")
    return l


func _category() -> CategoryData:
    var cat := CategoryRegistry.get_category_by_id("test_category")
    assert_not_null(cat, "test_category should exist in CategoryRegistry")
    return cat


func _item(rng: RandomNumberGenerator) -> ItemEntry:
    var cat := _category()
    var entry := ItemGenerator.draw(cat, { }, rng)
    assert_not_null(entry, "item should be generated")
    assert_not_null(entry.anchor, "item should have an anchor")
    return entry


## Returns a committed test lot from the location browse pool so restore can
## resolve lot_id through RunStore.browse_lots like production does.
func _browse_lot(location: LocationData) -> LotData:
    assert_gt(location.lot_pool.size(), 0, "test_location should have lot_pool data")
    return location.lot_pool[0]


## Builds a complete run+lot snapshot dict via the normal save path. Caller
## should have set up RunManager state before calling.
func _capture_snapshot() -> Dictionary:
    return RunManager.to_dict().get("run_snapshot", { })

# ══ Round-trip ═══════════════════════════════════════════════════════════════


func test_run_snapshot_round_trip() -> void:
    _ctx = SaveLoadContext.new()
    var rng := RandomNumberGenerator.new()
    rng.seed = 42
    var car := _car()
    var loc := _location()

    RunManager.create_run_store(loc, car)
    var item := _item(rng)
    item.unveil()

    var ld := _browse_lot(loc)
    var lot_entry := LotEntry.new()
    lot_entry.lot_data = ld
    lot_entry.aggressive_factor = ld.aggressive_factor_min
    lot_entry.price_variance = ld.price_variance_min
    lot_entry.item_entries = [item]
    lot_entry.npc_estimate = 200

    RunManager.init_browse_lots([ld])
    RunManager.set_lot(lot_entry)
    RunManager.commit_lot_win([item], 250)
    RunManager.commit_cargo([item], [], 30)
    RunManager.set_resume_target(RunStore.RESUME_INSPECTION)

    var snapshot := _capture_snapshot()
    assert_false(snapshot.is_empty(), "snapshot should be non-empty")
    assert_eq(snapshot.get("_version", 0), RunSnapshotContext.VERSION, "snapshot version should match")
    assert_eq(snapshot.get("resume_target", ""), RunStore.RESUME_INSPECTION, "resume target should match")
    assert_true(snapshot.has("entries"), "snapshot should have entries key")
    assert_true(snapshot.has("stores"), "snapshot should have stores key")
    assert_true(snapshot["stores"].has("run"), "stores should have run key")
    assert_true(snapshot["stores"].has("lot"), "stores should have lot key")

    # Preserve reference data for comparison after restore.
    var orig_loc_id := loc.location_id
    var orig_car_id := car.car_id
    var orig_paid := RunManager.run.paid_price
    var orig_onsite := RunManager.run.onsite_proceeds
    var orig_won_count := RunManager.run.won_items.size()
    var orig_cargo_count := RunManager.run.cargo_items.size()

    RunManager.clear_run_state()
    assert_null(RunManager.run, "run should be null after clear")
    assert_null(RunManager.lot, "lot should be null after clear")

    _ctx = SaveLoadContext.new()
    RunManager.from_dict({ "run_snapshot": snapshot }, _ctx)

    assert_not_null(RunManager.run, "run should be restored")
    assert_not_null(RunManager.lot, "lot should be restored")
    assert_eq(RunManager.run.resume_target, RunStore.RESUME_INSPECTION, "resume target restored")
    assert_eq(RunManager.run.location_data.location_id, orig_loc_id, "location id restored")
    assert_eq(RunManager.run.car_data.car_id, orig_car_id, "car id restored")
    assert_eq(RunManager.run.paid_price, orig_paid, "paid price restored")
    assert_eq(RunManager.run.onsite_proceeds, orig_onsite, "onsite proceeds restored")
    assert_eq(RunManager.run.won_items.size(), orig_won_count, "won items count restored")
    assert_eq(RunManager.run.cargo_items.size(), orig_cargo_count, "cargo items count restored")
    assert_eq(RunManager.lot.won_price, 250, "lot won price restored")

    # Item data fidelity.
    assert_eq(RunManager.run.cargo_items[0].anchor.anchor_id, item.anchor.anchor_id, "cargo item anchor restored")
    assert_true(RunManager.run.won_items[0].unveiled, "won item unveiled state restored")

    RunManager.clear_run_state()

# ══ Shared ItemEntry Identity ════════════════════════════════════════════════


func test_run_snapshot_shared_item_identity() -> void:
    _ctx = SaveLoadContext.new()
    var rng := RandomNumberGenerator.new()
    rng.seed = 7
    var car := _car()
    var loc := _location()

    RunManager.create_run_store(loc, car)
    var item := _item(rng)
    item.unveil()

    var ld := _browse_lot(loc)
    var lot_entry := LotEntry.new()
    lot_entry.lot_data = ld
    lot_entry.aggressive_factor = ld.aggressive_factor_min
    lot_entry.price_variance = ld.price_variance_min
    lot_entry.item_entries = [item]
    lot_entry.npc_estimate = 150

    RunManager.init_browse_lots([ld])
    RunManager.set_lot(lot_entry)
    # Commit the SAME item ref to both win and cargo so the snapshot context
    # assigns the same table key and identity survives restore.
    RunManager.commit_lot_win([item], 300)
    RunManager.commit_cargo([item], [], 0)
    RunManager.set_resume_target(RunStore.RESUME_CARGO)

    var snapshot := _capture_snapshot()
    var orig_ref := RunManager.run.cargo_items[0]

    RunManager.clear_run_state()
    _ctx = SaveLoadContext.new()
    RunManager.from_dict({ "run_snapshot": snapshot }, _ctx)

    assert_not_null(RunManager.run, "run should be restored")
    assert_eq(RunManager.run.cargo_items.size(), 1, "cargo items count")
    assert_eq(RunManager.run.won_items.size(), 1, "won items count")

    # The same ItemEntry ref that was in both cargo and won_items before save
    # should be the SAME restored object (shared identity from same table key).
    var ref_kind := typeof(RunManager.run.cargo_items[0])
    assert_eq(ref_kind, typeof(orig_ref), "ref type should match")
    assert_eq(
        RunManager.run.cargo_items[0],
        RunManager.run.won_items[0],
        "cargo item and won item should be same object after restore",
    )

    RunManager.clear_run_state()

# ══ Atomic discard — bad lot reference ═══════════════════════════════════════


func test_run_snapshot_atomic_discard_on_bad_lot_ref() -> void:
    _ctx = SaveLoadContext.new()
    var rng := RandomNumberGenerator.new()
    rng.seed = 13
    var car := _car()
    var loc := _location()

    RunManager.create_run_store(loc, car)
    var item := _item(rng)
    item.unveil()

    var ld := _browse_lot(loc)
    var lot_entry := LotEntry.new()
    lot_entry.lot_data = ld
    lot_entry.aggressive_factor = ld.aggressive_factor_min
    lot_entry.item_entries = [item]
    lot_entry.npc_estimate = 100

    RunManager.init_browse_lots([ld])
    RunManager.set_lot(lot_entry)
    RunManager.set_resume_target(RunStore.RESUME_INSPECTION)

    var snapshot := _capture_snapshot()
    # Corrupt lot_id so it won't match any browse lot.
    snapshot["stores"]["lot"]["lot_id"] = "nonexistent_lot"

    RunManager.clear_run_state()
    _ctx = SaveLoadContext.new()
    RunManager.from_dict({ "run_snapshot": snapshot }, _ctx)

    assert_null(RunManager.run, "run should be null after bad lot restore")
    assert_null(RunManager.lot, "lot should be null after bad lot restore")
    assert_true(_ctx.warnings.size() > 0, "should have warning after bad lot")

    RunManager.clear_run_state()

# ══ Atomic discard — invalid resume target ═══════════════════════════════════


func test_run_snapshot_atomic_discard_on_invalid_resume_target() -> void:
    _ctx = SaveLoadContext.new()
    var rng := RandomNumberGenerator.new()
    rng.seed = 21
    var car := _car()
    var loc := _location()

    RunManager.create_run_store(loc, car)
    RunManager.set_resume_target(RunStore.RESUME_INSPECTION)

    var snapshot := _capture_snapshot()
    # Corrupt resume_target to an invalid value.
    snapshot["resume_target"] = "bad_target"

    RunManager.clear_run_state()
    _ctx = SaveLoadContext.new()
    RunManager.from_dict({ "run_snapshot": snapshot }, _ctx)

    assert_null(RunManager.run, "run should be null after invalid resume target")
    assert_null(RunManager.lot, "lot should be null after invalid resume target")
    assert_true(_ctx.warnings.size() > 0, "should have warning after invalid resume target")

    RunManager.clear_run_state()

# ══ v1 legacy migration ══════════════════════════════════════════════════════


func test_run_snapshot_migration_v1_legacy_shape() -> void:
    _ctx = SaveLoadContext.new()
    var rng := RandomNumberGenerator.new()
    rng.seed = 55
    var car := _car()
    var loc := _location()

    RunManager.create_run_store(loc, car)
    var item := _item(rng)
    item.unveil()

    var ld := _browse_lot(loc)
    var lot_entry := LotEntry.new()
    lot_entry.lot_data = ld
    lot_entry.aggressive_factor = ld.aggressive_factor_min
    lot_entry.item_entries = [item]
    lot_entry.npc_estimate = 180

    RunManager.init_browse_lots([ld])
    RunManager.set_lot(lot_entry)
    RunManager.commit_lot_win([item], 400)
    RunManager.set_resume_target(RunStore.RESUME_REVEAL)

    # Get the v2 snapshot, then manually flatten to v1 shape.
    var v2 := _capture_snapshot()
    var v1 := { }
    for key in v2["stores"]["run"].keys():
        v1[key] = v2["stores"]["run"][key]
    v1["items"] = v2["entries"]["items"]
    v1["lot"] = v2["stores"]["lot"]
    v1["resume_target"] = v2["resume_target"]
    # In v1, resume_target was embedded in the flat run snapshot root.
    assert_true(v1.has("resume_target"), "v1 should have resume_target at root")
    v1["_version"] = 1 # v1 aggregate root version was the RunStore's internal version

    # Sanity-check that the v1 shape lacks stores/entries keys.
    assert_false(v1.has("stores"), "v1 should not have stores key")
    assert_false(v1.has("entries"), "v1 should not have entries key")

    # Now feed v1 through from_dict — it should trigger migrate_v1_to_v2.
    RunManager.clear_run_state()
    _ctx = SaveLoadContext.new()
    RunManager.from_dict({ "run_snapshot": v1 }, _ctx)

    assert_not_null(RunManager.run, "run should be restored from v1 shape")
    assert_not_null(RunManager.lot, "lot should be restored from v1 shape")
    assert_eq(RunManager.run.resume_target, RunStore.RESUME_REVEAL, "resume target from v1 migration")
    assert_eq(RunManager.run.won_items.size(), 1, "won items from v1 migration")
    assert_eq(RunManager.run.paid_price, 400, "paid price from v1 migration")
    assert_eq(RunManager.lot.won_price, 400, "lot won price from v1 migration")

    RunManager.clear_run_state()
