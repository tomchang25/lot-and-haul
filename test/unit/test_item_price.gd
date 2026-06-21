# test_item_price.gd
# Phase 2 — price pipeline regression tests: condition multiplier bands,
# verified-vs-appraised divergence, and hidden-clue override-base resolution.
extends GutTest

func _make_anchor(base_value: int = 100) -> AnchorData:
    var a := AnchorData.new()
    a.anchor_id = "test_anchor"
    a.base_value = base_value
    return a


func _make_surface(clue_id: String, op: String, amount: float, dc: int = 5) -> ClueData:
    var c := ClueData.new()
    c.clue_id = clue_id
    c.type = ClueData.ClueType.SURFACE
    c.dc = dc
    c.effect_op = op
    c.effect_amount = amount
    return c


func _make_hidden(clue_id: String, op: String, amount: float, dc: int = 10) -> ClueData:
    var c := ClueData.new()
    c.clue_id = clue_id
    c.type = ClueData.ClueType.HIDDEN
    c.dc = dc
    c.effect_op = op
    c.effect_amount = amount
    return c


func _make_item(anchor: AnchorData, surface: Array[ClueData] = [], hidden: Array[ClueData] = []) -> ItemEntry:
    var item := ItemEntry.new()
    item.anchor = anchor
    item.surface_clues = surface
    item.hidden_clues = hidden
    item.unveiled = true
    item.condition = 0.5
    return item

# ── Condition multiplier bands ─────────────────────────────────────────────


func test_condition_band_destroyed() -> void:
    var item := _make_item(_make_anchor(100))
    item.condition = 0.0
    assert_eq(item.get_condition_multiplier(), 0.25, "0.0 condition → 0.25x")


func test_condition_band_low() -> void:
    var item := _make_item(_make_anchor(100))
    item.condition = 0.25
    var m := item.get_condition_multiplier()
    assert_between(m, 0.25, 0.5, "0.25 condition maps to [0.25, 0.5]")


func test_condition_band_mid() -> void:
    var item := _make_item(_make_anchor(100))
    item.condition = 0.5
    var m := item.get_condition_multiplier()
    assert_between(m, 0.5, 1.0, "0.5 condition maps to [0.5, 1.0]")


func test_condition_band_good() -> void:
    var item := _make_item(_make_anchor(100))
    item.condition = 0.75
    var m := item.get_condition_multiplier()
    assert_between(m, 1.0, 2.0, "0.75 condition maps to [1.0, 2.0]")


func test_condition_band_pristine() -> void:
    var item := _make_item(_make_anchor(100))
    item.condition = 1.0
    var m := item.get_condition_multiplier()
    assert_between(m, 2.0, 4.0, "1.0 condition maps to [2.0, 4.0]")


func test_condition_continuous_within_band() -> void:
    var item := _make_item(_make_anchor(100))
    item.condition = 0.6
    var m := item.get_condition_multiplier()
    assert_gt(m, 0.5, "0.6 condition > 0.5 multiplier")
    assert_lt(m, 2.0, "0.6 condition < 2.0 multiplier")

# ── Appraised value (surface clues only) ──────────────────────────────────


func test_appraised_anchor_only() -> void:
    var item := _make_item(_make_anchor(100))
    assert_eq(item.item_price, 100, "no clues → anchor base_value")


func test_appraised_surface_add() -> void:
    var item := _make_item(_make_anchor(100), [_make_surface("add_50", "add", 50)])
    item.revealed_clue_ids.append("add_50")
    assert_eq(item.item_price, 150, "anchor 100 + surface add 50")


func test_appraised_surface_mul() -> void:
    var item := _make_item(_make_anchor(100), [_make_surface("mul_1.5", "mul", 1.5)])
    item.revealed_clue_ids.append("mul_1.5")
    assert_eq(item.item_price, 150, "anchor 100 * surface mul 1.5")


func test_appraised_surface_add_then_mul() -> void:
    var item := _make_item(
        _make_anchor(100),
        [
            _make_surface("add_50", "add", 50),
            _make_surface("mul_1.5", "mul", 1.5),
        ],
    )
    item.revealed_clue_ids.append("add_50")
    item.revealed_clue_ids.append("mul_1.5")
    assert_eq(item.item_price, 225, "(100 + 50) * 1.5 = 225")


func test_appraised_unrevealed_surface_skipped() -> void:
    var item := _make_item(
        _make_anchor(100),
        [_make_surface("add_50", "add", 50)],
    )
    assert_eq(item.item_price, 100, "unrevealed surface not counted")

# ── Verified value (hidden clues included) ────────────────────────────────


func test_verified_includes_hidden_add() -> void:
    var item := _make_item(
        _make_anchor(100),
        [],
        [_make_hidden("hidden_add_200", "add", 200)],
    )
    item.revealed_clue_ids.append("hidden_add_200")
    assert_true(item.verified, "all hidden revealed → verified")
    assert_eq(item.item_price, 300, "anchor 100 + hidden add 200")


func test_verified_hidden_mul() -> void:
    var item := _make_item(
        _make_anchor(100),
        [_make_surface("add_50", "add", 50)],
        [_make_hidden("hidden_mul_2", "mul", 2.0)],
    )
    item.revealed_clue_ids.append("add_50")
    item.revealed_clue_ids.append("hidden_mul_2")
    assert_true(item.verified, "all hidden revealed → verified")
    assert_eq(item.item_price, 300, "(100 + 50) * 2.0 = 300")


func test_no_hidden_implies_verified() -> void:
    var item := _make_item(_make_anchor(100))
    assert_true(item.verified, "no hidden clues → verified by default")


func test_unverified_if_hidden_unrevealed() -> void:
    var item := _make_item(
        _make_anchor(100),
        [],
        [_make_hidden("hidden_gem", "mul", 2.0)],
    )
    assert_false(item.verified, "unrevealed hidden → not verified")

# ── Hidden override base ──────────────────────────────────────────────────


func test_hidden_override_replaces_base() -> void:
    var item := _make_item(
        _make_anchor(100),
        [],
        [_make_hidden("override_500", "override", 500)],
    )
    item.revealed_clue_ids.append("override_500")
    assert_true(item.verified, "hidden override revealed → verified")
    assert_eq(item.item_price, 500, "override replaces anchor base 100 with 500")


func test_hidden_override_with_surface_add() -> void:
    var item := _make_item(
        _make_anchor(100),
        [_make_surface("add_50", "add", 50)],
        [_make_hidden("override_500", "override", 500)],
    )
    item.revealed_clue_ids.append("add_50")
    item.revealed_clue_ids.append("override_500")
    assert_eq(item.item_price, 550, "override base 500 + surface add 50")


func test_override_hidden_unrevealed_uses_anchor() -> void:
    var item := _make_item(
        _make_anchor(100),
        [_make_surface("add_50", "add", 50)],
        [_make_hidden("override_500", "override", 500)],
    )
    item.revealed_clue_ids.append("add_50")
    assert_false(item.verified, "override unrevealed → not verified")
    assert_eq(item.item_price, 150, "unrevealed override: anchor 100 + add 50")

# ── item_price applies condition multiplier ───────────────────────────────


func test_item_price_applies_condition() -> void:
    var item := _make_item(_make_anchor(100))
    item.condition = 0.5
    var cond := item.get_condition_multiplier()
    assert_eq(item.item_price, int(100.0 * cond), "item_price = base * condition_multiplier")

# ── Minimum value floor ──────────────────────────────────────────────────


func test_price_floor_enforced_appraised() -> void:
    var item := _make_item(
        _make_anchor(30),
        [_make_surface("huge_neg", "add", -9999)],
    )
    item.revealed_clue_ids.append("huge_neg")
    item.condition = 0.0
    assert_eq(item.item_price, Economy.MIN_ITEM_VALUE, "appraised negative value floors at MIN_ITEM_VALUE")


func test_price_floor_enforced_verified() -> void:
    var item := _make_item(
        _make_anchor(30),
        [],
        [_make_hidden("low_override", "override", 5)],
    )
    item.revealed_clue_ids.append("low_override")
    item.condition = 0.0
    assert_eq(item.item_price, Economy.MIN_ITEM_VALUE, "verified low value floors at MIN_ITEM_VALUE")


func test_price_floor_enforced_range() -> void:
    var item := _make_item(
        _make_anchor(30),
        [_make_surface("huge_neg", "add", -9999)],
    )
    item.revealed_clue_ids.append("huge_neg")
    item.condition = 0.0
    var view := item.resolve_price()
    assert_true(view.min_value >= Economy.MIN_ITEM_VALUE, "range min_value floors at MIN_ITEM_VALUE")
    assert_true(view.point_value >= Economy.MIN_ITEM_VALUE, "point_value floors at MIN_ITEM_VALUE")


func test_npc_estimate_floor_enforced() -> void:
    var item := _make_item(
        _make_anchor(30),
        [_make_surface("huge_neg", "add", -9999)],
    )
    item.revealed_clue_ids.append("huge_neg")
    var estimate := item.roll_npc_estimate(1.0)
    assert_true(estimate >= Economy.MIN_ITEM_VALUE, "NPC estimate floors at MIN_ITEM_VALUE")


func test_item_price_with_condition_and_clues() -> void:
    var item := _make_item(
        _make_anchor(100),
        [_make_surface("add_50", "add", 50)],
    )
    item.revealed_clue_ids.append("add_50")
    item.condition = 0.75
    var cond := item.get_condition_multiplier()
    assert_eq(item.item_price, int(150.0 * cond), "item_price = (anchor + surface) * condition")
