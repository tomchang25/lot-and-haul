# test_run_manager.gd
# Layer 1 — run-loop manager unit tests.
# All test resources loaded from committed YAML test data via normal registries.
extends GutTest

# ══ Helpers ═══════════════════════════════════════════════════════════════════

func _car() -> CarData:
    var c := CarRegistry.get_car_by_id("test_car")
    assert_not_null(c, "test_car should exist in CarRegistry (run YAML→tres pipeline)")
    return c


func _location() -> LocationData:
    var l := LocationRegistry.get_location_by_id("test_location")
    assert_not_null(l, "test_location should exist in LocationRegistry (run YAML→tres pipeline)")
    return l

# ══ AP Lifecycle ═══════════════════════════════════════════════════════════


func test_ap_lifecycle_create_and_spend() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 42
    var car := _car()
    var loc := _location()

    RunManager.create_run_store(loc, car)
    assert_not_null(RunManager.run, "run store should exist after create")
    assert_eq(RunManager.run.inspection_ap_cap, 10, "default AP cap")

    var cat := CategoryRegistry.get_category_by_id("test_category")
    assert_not_null(cat, "test category should exist in registry")

    var item := ItemGenerator.draw(cat, { }, rng)
    assert_not_null(item, "item should be generated")
    assert_not_null(item.anchor, "item should have an anchor")

    var lot_data := LotData.new()
    lot_data.lot_id = "test_lot"
    lot_data.aggressive_factor_min = 0.4
    lot_data.aggressive_factor_max = 0.4
    lot_data.price_variance_min = 1.0
    lot_data.price_variance_max = 1.0
    lot_data.npc_clue_sight_chance = 0.0

    var entry := LotEntry.new()
    entry.lot_data = lot_data
    entry.aggressive_factor = 0.4
    entry.price_variance = 1.0
    entry.item_entries.append(item)
    entry.npc_estimate = 100

    assert_eq(entry.item_entries.size(), 1, "lot should have 1 item")

    RunManager.set_lot(entry)
    assert_not_null(RunManager.lot, "lot store should exist after set_lot")

    var initial_ap := RunManager.lot.actions_remaining
    assert_gt(initial_ap, 0, "should have initial AP")

    RunManager.spend_ap(3)
    assert_eq(RunManager.lot.actions_remaining, initial_ap - 3, "AP should decrease by 3")

    RunManager.spend_ap(initial_ap - 3 + 1)
    assert_eq(RunManager.lot.actions_remaining, 0, "AP should not go below 0")

    RunManager.clear_run_state()
    assert_null(RunManager.run, "run should be null after clear")
    assert_null(RunManager.lot, "lot should be null after clear")

# ══ Clue Attempt ══════════════════════════════════════════════════════════


func test_clue_hit_and_miss() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 2

    var easy := ClueRegistry.get_clue_by_id("test_surface_easy")
    var hard := ClueRegistry.get_clue_by_id("test_surface_hard")
    assert_not_null(easy, "test_surface_easy should exist in ClueRegistry")
    assert_not_null(hard, "test_surface_hard should exist in ClueRegistry")

    var entry := ItemEntry.new()
    entry.surface_clues = [easy, hard]
    entry.unveil()
    assert_true(entry.unveiled, "item should be unveiled")

    entry.revealed_clue_ids.clear()
    assert_true(entry.attempt_clue(easy, 1, rng), "easy clue should succeed with attribute bonus")
    assert_eq(entry.revealed_clue_ids.size(), 1, "one clue should be revealed")

    var revealed_before := entry.revealed_clue_ids.duplicate()

    assert_false(entry.attempt_clue(hard, 0, rng), "hard clue should miss with zero bonus")
    assert_eq(
        entry.revealed_clue_ids,
        revealed_before,
        "revealed set should stay stable after miss",
    )

    assert_true(entry.attempt_clue(hard, 19, rng), "hard clue should hit with max bonus")
    assert_eq(entry.revealed_clue_ids.size(), 2, "both clues should be revealed")

# ══ Cargo Commit ═══════════════════════════════════════════════════════════


func test_cargo_commit() -> void:
    var car := _car()
    var loc := _location()
    RunManager.create_run_store(loc, car)

    var cat := CategoryRegistry.get_category_by_id("test_category")
    assert_not_null(cat, "test category should exist in registry")

    var rng := RandomNumberGenerator.new()
    rng.seed = 42
    var entry := ItemGenerator.draw(cat, { }, rng)
    assert_not_null(entry, "item should be generated")
    entry.unveil()

    RunManager.commit_cargo([entry], [], 50)
    assert_eq(RunManager.run.cargo_items.size(), 1, "cargo should have 1 item")
    assert_eq(RunManager.run.onsite_proceeds, 50, "onsite proceeds should be 50")

    RunManager.clear_run_state()


func test_commit_lot_win() -> void:
    var car := _car()
    var loc := _location()
    RunManager.create_run_store(loc, car)

    var lot_data := LotData.new()
    lot_data.lot_id = "test_lot"
    lot_data.npc_clue_sight_chance = 0.0
    lot_data.item_count_min = 0
    lot_data.item_count_max = 0

    var rng := RandomNumberGenerator.new()
    rng.seed = 7
    var lot_entry := LotEntry.create(lot_data, rng)
    RunManager.set_lot(lot_entry)

    var items := lot_entry.item_entries
    RunManager.commit_lot_win(items, 500)
    assert_eq(RunManager.run.paid_price, 500, "paid_price should be 500")

    RunManager.clear_run_state()

# ══ Trailer Damage ════════════════════════════════════════════════════════


func test_trailer_damage_triggered() -> void:
    var car := _car().duplicate()
    car.trailer_damage_chance = 1.0
    car.trailer_damage_ratio_min = 0.1
    car.trailer_damage_ratio_max = 0.3

    var loc := _location()
    RunManager.create_run_store(loc, car)

    var cat := CategoryRegistry.get_category_by_id("test_category")
    assert_not_null(cat, "test category should exist in registry")

    var rng := RandomNumberGenerator.new()
    rng.seed = 42
    var entry := ItemGenerator.draw(cat, { }, rng)

    RunManager.commit_cargo([], [entry], 0)

    var cracked := RunManager.apply_trailer_damage()
    assert_eq(cracked, 1, "trailer damage should crack 1 item")
    assert_lt(entry.condition, 1.0, "cracked item condition should decrease")

    RunManager.clear_run_state()


func test_trailer_no_damage_when_chance_zero() -> void:
    var car := _car().duplicate()
    car.trailer_damage_chance = 0.0

    var loc := _location()
    RunManager.create_run_store(loc, car)

    var cat := CategoryRegistry.get_category_by_id("test_category")
    assert_not_null(cat, "test category should exist in registry")

    var rng := RandomNumberGenerator.new()
    rng.seed = 42
    var entry := ItemGenerator.draw(cat, { }, rng)

    RunManager.commit_cargo([], [entry], 0)

    var cracked := RunManager.apply_trailer_damage()
    assert_eq(cracked, 0, "no damage when chance is 0")

    RunManager.clear_run_state()

# ══ Full Run Traversal ════════════════════════════════════════════════════


func test_full_run_scratch_to_run_result() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 1
    var car := _car()
    var loc := _location()

    RunManager.create_run_store(loc, car)
    assert_not_null(RunManager.run, "run should exist")

    var cat := CategoryRegistry.get_category_by_id("test_category")
    assert_not_null(cat, "test category should exist in registry")

    var item := ItemGenerator.draw(cat, { }, rng)
    assert_not_null(item, "item should be generated")
    assert_not_null(item.anchor, "item should have an anchor")
    item.unveil()

    for c: ClueData in item.surface_clues:
        item.attempt_clue(c, 20, rng)
        break

    var lot_data := LotData.new()
    lot_data.lot_id = "test_lot"
    lot_data.npc_clue_sight_chance = 1.0

    var lot_entry := LotEntry.new()
    lot_entry.lot_data = lot_data
    lot_entry.aggressive_factor = 0.5
    lot_entry.price_variance = 1.0
    lot_entry.item_entries = [item]
    lot_entry.npc_estimate = int(item.anchor.base_value + 100.0)

    RunManager.set_lot(lot_entry)
    assert_not_null(RunManager.lot, "lot store should exist")

    RunManager.commit_lot_win([item], 250)
    assert_eq(RunManager.run.paid_price, 250, "should have paid 250")

    RunManager.commit_cargo([item], [], 30)
    assert_eq(RunManager.run.cargo_items.size(), 1, "cargo should contain item")
    assert_eq(RunManager.run.onsite_proceeds, 30, "onsite proceeds should be 30")

    var result: RunResult = RunManager.take_run_result()
    assert_eq(result.cargo_items.size(), 1, "result cargo should have 1 item")
    assert_eq(result.onsite_proceeds, 30, "result onsite_proceeds")
    assert_eq(result.paid_price, 250, "result paid_price")
    assert_eq(result.entry_fee, loc.entry_fee, "result entry_fee")
    assert_eq(result.fuel_cost, car.fuel_cost_per_day * loc.travel_days, "result fuel_cost")

    assert_gt(result.cargo_items[0].revealed_clue_ids.size(), 0, "surface clues should be revealed")

    RunManager.clear_run_state()
