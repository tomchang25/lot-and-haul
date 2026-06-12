# test_run_manager.gd
# Layer 1 — run-loop manager unit tests.
# Constructs all designer resources from scratch (no disk dependency).
# Uses seeded RNG for deterministic outcomes.
extends GutTest

# ══ Helpers ═══════════════════════════════════════════════════════════════════

func _make_clue(id: String, type: int, attr: String, dc: int, op: String, amount: float) -> ClueData:
    var c := ClueData.new()
    c.clue_id = id
    c.type = type
    c.attribute = attr
    c.dc = dc
    c.effect_op = op
    c.effect_amount = amount
    return c


func _make_anchor(id: String, base: float, cat: CategoryData) -> AnchorData:
    var a := AnchorData.new()
    a.anchor_id = id
    a.base_value = base
    a.category_data = cat
    return a


func _make_category(id: String) -> CategoryData:
    var c := CategoryData.new()
    c.category_id = id
    return c


func _make_car() -> CarData:
    var c := CarData.new()
    c.car_id = "test_car"
    c.grid_columns = 4
    c.grid_rows = 3
    c.max_weight = 500.0
    c.stamina_cap = 30
    c.fuel_cost_per_day = 10
    c.trailer_damage_chance = 0.0
    return c


func _make_location() -> LocationData:
    var l := LocationData.new()
    l.location_id = "test_loc"
    l.display_name = "Test Location"
    l.entry_fee = 50
    l.travel_days = 2
    return l


func _seed_rng(seed_val: int) -> RandomNumberGenerator:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_val
    return rng

# ══ AP Lifecycle ═══════════════════════════════════════════════════════════


func test_ap_lifecycle_create_and_spend() -> void:
    var rng := _seed_rng(42)
    var car := _make_car()
    var loc := _make_location()

    RunManager.create_run_store(loc, car)
    assert_not_null(RunManager.run, "run store should exist after create")
    assert_eq(RunManager.run.inspection_ap_cap, 10, "default AP cap")

    var cat := _make_category("test_cat")
    var anchor := _make_anchor("test_anchor", 100.0, cat)
    var clue := _make_clue("test_surface", ClueData.ClueType.SURFACE, "appraisal", 10, "add", 50.0)

    # Manually construct a LotEntry to avoid registry dependency.
    var lot_data := LotData.new()
    lot_data.lot_id = "test_lot"
    lot_data.aggressive_factor_min = 0.4
    lot_data.aggressive_factor_max = 0.4
    lot_data.price_variance_min = 1.0
    lot_data.price_variance_max = 1.0
    lot_data.npc_clue_sight_chance = 0.0

    var item := ItemEntry.from_generation(anchor, [clue], [], cat, rng)
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
    var cat := _make_category("test_cat")
    var anchor := _make_anchor("test_anchor", 100.0, cat)
    var easy := _make_clue("easy", ClueData.ClueType.SURFACE, "appraisal", 5, "add", 10.0)
    var hard := _make_clue("hard", ClueData.ClueType.SURFACE, "appraisal", 19, "add", 20.0)
    var rng := _seed_rng(2)
    var entry := ItemEntry.from_generation(anchor, [easy, hard], [], cat, rng)

    entry.unveil()
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
    var car := _make_car()
    var loc := _make_location()
    RunManager.create_run_store(loc, car)

    var cat := _make_category("test_cat")
    var anchor := _make_anchor("test_anchor", 100.0, cat)

    var entry := ItemEntry.from_generation(anchor, [], [], cat)
    entry.unveil()

    RunManager.commit_cargo([entry], [], 50)
    assert_eq(RunManager.run.cargo_items.size(), 1, "cargo should have 1 item")
    assert_eq(RunManager.run.onsite_proceeds, 50, "onsite proceeds should be 50")

    RunManager.clear_run_state()


func test_commit_lot_win() -> void:
    var car := _make_car()
    var loc := _make_location()
    RunManager.create_run_store(loc, car)

    var cat := _make_category("test_cat")
    var lot_data := LotData.new()
    lot_data.lot_id = "test_lot"
    lot_data.npc_clue_sight_chance = 0.0

    var rng := _seed_rng(7)
    var lot_entry := LotEntry.create(lot_data, rng)
    RunManager.set_lot(lot_entry)

    var items := lot_entry.item_entries
    RunManager.commit_lot_win(items, 500)
    assert_eq(RunManager.run.paid_price, 500, "paid_price should be 500")

    RunManager.clear_run_state()

# ══ Trailer Damage ════════════════════════════════════════════════════════


func test_trailer_damage_triggered() -> void:
    var car := _make_car()
    car.trailer_damage_chance = 1.0
    car.trailer_damage_ratio_min = 0.1
    car.trailer_damage_ratio_max = 0.3

    var loc := _make_location()
    RunManager.create_run_store(loc, car)

    var cat := _make_category("test_cat")
    var anchor := _make_anchor("test_anchor", 100.0, cat)
    var entry := ItemEntry.from_generation(anchor, [], [], cat)

    RunManager.commit_cargo([], [entry], 0)

    var cracked := RunManager.apply_trailer_damage()
    assert_eq(cracked, 1, "trailer damage should crack 1 item")
    assert_lt(entry.condition, 1.0, "cracked item condition should decrease")

    RunManager.clear_run_state()


func test_trailer_no_damage_when_chance_zero() -> void:
    var car := _make_car()
    car.trailer_damage_chance = 0.0

    var loc := _make_location()
    RunManager.create_run_store(loc, car)

    var cat := _make_category("test_cat")
    var anchor := _make_anchor("test_anchor", 100.0, cat)
    var entry := ItemEntry.from_generation(anchor, [], [], cat)

    RunManager.commit_cargo([], [entry], 0)

    var cracked := RunManager.apply_trailer_damage()
    assert_eq(cracked, 0, "no damage when chance is 0")

    RunManager.clear_run_state()

# ══ Full Run Traversal ════════════════════════════════════════════════════


func test_full_run_scratch_to_run_result() -> void:
    var rng := _seed_rng(1)
    var car := _make_car()
    var loc := _make_location()

    # Create the run
    RunManager.create_run_store(loc, car)
    assert_not_null(RunManager.run, "run should exist")

    # Construct a lot entry with known items
    var cat := _make_category("test_cat")
    var anchor := _make_anchor("a1", 200.0, cat)
    var surface := _make_clue("s1", ClueData.ClueType.SURFACE, "appraisal", 5, "add", 100.0)

    var item := ItemEntry.from_generation(anchor, [surface], [], cat, rng)
    item.unveil()
    item.revealed_clue_ids.append("s1")

    var lot_data := LotData.new()
    lot_data.lot_id = "test_lot"
    lot_data.npc_clue_sight_chance = 1.0

    var lot_entry := LotEntry.new()
    lot_entry.lot_data = lot_data
    lot_entry.aggressive_factor = 0.5
    lot_entry.price_variance = 1.0
    lot_entry.item_entries = [item]
    lot_entry.npc_estimate = int(200.0 + 100.0)

    # Set the lot
    RunManager.set_lot(lot_entry)
    assert_not_null(RunManager.lot, "lot store should exist")

    # Win the auction
    RunManager.commit_lot_win([item], 250)
    assert_eq(RunManager.run.paid_price, 250, "should have paid 250")

    # Fill cargo
    RunManager.commit_cargo([item], [], 30)
    assert_eq(RunManager.run.cargo_items.size(), 1, "cargo should contain item")
    assert_eq(RunManager.run.onsite_proceeds, 30, "onsite proceeds should be 30")

    # Build run result
    var result: RunResult = RunManager.take_run_result()
    assert_eq(result.cargo_items.size(), 1, "result cargo should have 1 item")
    assert_eq(result.onsite_proceeds, 30, "result onsite_proceeds")
    assert_eq(result.paid_price, 250, "result paid_price")
    assert_eq(result.entry_fee, loc.entry_fee, "result entry_fee")
    assert_eq(result.fuel_cost, car.fuel_cost_per_day * loc.travel_days, "result fuel_cost")

    # Cargo item should have auto-revealed surface clues after take_run_result
    assert_eq(result.cargo_items[0].revealed_clue_ids.size(), 1, "surface clue should be revealed")

    RunManager.clear_run_state()
