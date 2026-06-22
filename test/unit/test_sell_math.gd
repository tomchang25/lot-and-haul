# test_sell_math.gd
# Phase 9 — SellMath regression tests: item matching, fit depth, dice pool,
# pricing, and customer-aware valued-negative pricing.
extends GutTest

var _anchor_100: AnchorData
var _clue_add_50: ClueData
var _clue_mul_15: ClueData
var _clue_mul_08: ClueData
var _clue_mul_07: ClueData
var _clue_hidden_mul_12: ClueData
var _item: ItemEntry
var _item_valued: ItemEntry
var _item_no_valued: ItemEntry
var _item_multi: ItemEntry
var _item_verified: ItemEntry
var _customer: CustomerEntry
var _customer_no_valued: CustomerEntry


func before_each() -> void:
    _anchor_100 = AnchorData.new()
    _anchor_100.anchor_id = "test_anchor"
    _anchor_100.base_value = 100

    _clue_add_50 = _make_surface("add_50", "add", 50.0)
    _clue_mul_15 = _make_surface("mul_99", "mul", 1.5)
    _clue_mul_08 = _make_surface("mul_08", "mul", 0.8)
    _clue_mul_07 = _make_surface("mul_07", "mul", 0.7)
    _clue_hidden_mul_12 = _make_hidden("hidden_mul_12", "mul", 1.2)

    # Normal item with a valued-negative clue (mul_08) and other clues.
    _item_valued = _make_item(
        _anchor_100,
        [_clue_add_50, _clue_mul_08],
    )
    _item_valued.revealed_clue_ids = ["add_50", "mul_08"]
    _item_valued.condition = 0.5

    # Item with no valued-negative clue, using non-overlapping tags.
    _item_no_valued = _make_item(
        _anchor_100,
        [_make_surface("no_match_add", "add", 10.0), _clue_mul_15],
    )
    _item_no_valued.revealed_clue_ids = ["no_match_add", "mul_99"]
    _item_no_valued.condition = 0.5

    # Item with multiple negative surface clues — some valued, some not.
    _item_multi = _make_item(
        _anchor_100,
        [_clue_add_50, _clue_mul_08, _clue_mul_07],
    )
    _item_multi.revealed_clue_ids = ["add_50", "mul_08", "mul_07"]
    _item_multi.condition = 0.5

    # Verified item with a hidden clue (non-valued negative surface too).
    _item_verified = _make_item(
        _anchor_100,
        [_clue_add_50, _clue_mul_08],
        [_clue_hidden_mul_12],
    )
    _item_verified.revealed_clue_ids = ["add_50", "mul_08", "hidden_mul_12"]
    _item_verified.condition = 0.5

    # Customer that values mul_08.
    _customer = CustomerEntry.new()
    _customer.valued_negative_tags = ["mul_08"]
    _customer.demand_tags = ["add_50", "mul_08"]

    # Customer with no valued negative tags.
    _customer_no_valued = CustomerEntry.new()
    _customer_no_valued.valued_negative_tags = []
    _customer_no_valued.demand_tags = ["add_50", "mul_99"]

    _item = _item_valued


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
    return item

# ══ Matched items ═══════════════════════════════════════════════════════════


func test_matched_items_finds_intersecting_demand() -> void:
    var results := SellMath.matched_items(_customer, [_item_valued, _item_no_valued])
    assert_has(results, _item_valued, "item with matching demand tag is included")
    assert_does_not_have(results, _item_no_valued, "item without matching demand tag is excluded")


func test_matched_items_empty_when_no_demand() -> void:
    var empty_customer := CustomerEntry.new()
    var results := SellMath.matched_items(empty_customer, [_item_valued])
    assert_eq(results.size(), 0, "empty demand tags → no matches")


func test_matched_items_empty_when_no_storage() -> void:
    var results := SellMath.matched_items(_customer, [])
    assert_eq(results.size(), 0, "empty storage → no matches")

# ══ Item fit ════════════════════════════════════════════════════════════════


func test_item_fit_counts_matching_tags() -> void:
    var fit := SellMath.item_fit(_customer, _item_valued)
    assert_eq(fit, 2, "item matches 2 of customer's demand tags")


func test_item_fit_zero_when_no_overlap() -> void:
    var fit := SellMath.item_fit(_customer, _item_no_valued)
    assert_eq(fit, 0, "no overlap → fit 0")


# ══ Base contribution (non-customer) ══════════════════════════════════════
func test_item_contribution_uses_global_price() -> void:
    # item_valued: anchor 100 + add 50 = 150, * mul 0.8 = 120
    # 0 hidden clues → verified by default → × 1.05 verified bonus = 126
    var contrib := SellMath.item_contribution(_item_valued)
    assert_eq(contrib, 126, "standard contribution uses global appraised price with verified bonus")

# ══ Customer-aware pricing ════════════════════════════════════════════════


func test_item_contribution_with_customer_converts_valued_negative() -> void:
    # item_valued: anchor 100 + add 50 = 150, skip mul_08, add valued bonus
    # valued_negative_bonus = 50
    # (100 + 50 + 50) * 1.0 = 200, × 1.05 verified bonus = 210
    var contrib := SellMath.item_contribution(_item_valued, _customer)
    assert_eq(contrib, 210, "valued negative mul penalty replaced with fixed bonus")


func test_item_contribution_with_customer_ignores_hidden_negative() -> void:
    # Item has hidden mul 1.2 AND surface mul_08. Valued tags include only "mul_08".
    # mul_08 is surface and valued → bonus + skip mul
    # hidden_mul_12 is hidden → not eligible for valued check → applies normally as mul
    # (100 + 50 + 50) * 1.2 = 240, × 1.05 verified bonus = 252
    var contrib := SellMath.item_contribution(_item_verified, _customer)
    assert_eq(contrib, 252, "hidden mul applies normally alongside valued surface bonus")


func test_item_contribution_with_customer_leaves_non_valued_negative() -> void:
    # item_multi: anchor 100 + add 50 = 150, mul_08 is valued → bonus 50, mul_07 stays 0.7
    # (100 + 50 + 50) * 0.7 = 140, × 1.05 verified bonus = 147
    var contrib := SellMath.item_contribution(_item_multi, _customer)
    assert_eq(contrib, 147, "non-valued negative mul still applies")


func test_item_contribution_with_customer_falls_back_to_global_when_no_valued_tags() -> void:
    # customer_no_valued has empty valued_negative_tags
    # item_valued: (100 + 50) * 0.8 = 120, × 1.05 verified bonus = 126
    var contrib := SellMath.item_contribution(_item_valued, _customer_no_valued)
    assert_eq(contrib, 126, "empty customer valued tags → global price with verified bonus")


func test_item_contribution_no_customer_falls_back() -> void:
    var contrib := SellMath.item_contribution(_item_valued, null)
    assert_eq(contrib, 126, "null customer → global price with verified bonus")

# ══ Conservative total ════════════════════════════════════════════════════


func test_conservative_total_with_customer_uses_valued_pricing() -> void:
    # item_valued: customer price 210, conservative × 1.25 = 262.5 → 262
    var total := SellMath.conservative_total([_item_valued], _customer)
    assert_eq(total, 262, "conservative total with customer-valued pricing")


func test_conservative_total_standard_no_customer() -> void:
    # item_valued: global price 126, conservative × 1.25 = 157.5 → 157
    var total := SellMath.conservative_total([_item_valued])
    assert_eq(total, 157, "standard conservative total unchanged")

# ══ Min value floor ═══════════════════════════════════════════════════════


func test_item_contribution_floors_at_min_value() -> void:
    var low_val := _make_item(_make_anchor(1))
    low_val.revealed_clue_ids = []
    low_val.condition = 0.5
    var contrib := SellMath.item_contribution(low_val)
    assert_eq(contrib, Economy.MIN_ITEM_VALUE, "item contribution floors at MIN_ITEM_VALUE")


func test_item_contribution_with_customer_floors_at_min_value() -> void:
    var low_val := _make_item(_make_anchor(1))
    low_val.revealed_clue_ids = []
    low_val.condition = 0.5
    var contrib := SellMath.item_contribution(low_val, _customer)
    assert_eq(contrib, Economy.MIN_ITEM_VALUE, "customer contribution floors at MIN_ITEM_VALUE")

# ══ Verified bonus ════════════════════════════════════════════════════════


func test_item_contribution_verified_bonus_applied() -> void:
    var contrib := SellMath.item_contribution(_item_verified)
    # verified item: (100 + 50) * 0.8 * 1.2 (hidden mul) = 144, then × 1.05 verified bonus = 151.2 → 151
    assert_eq(contrib, 151, "verified item gets ×1.05 bonus")


func test_item_contribution_with_customer_verified_bonus_applied() -> void:
    # customer-aware: (100 + 50 + 50) * 1.2 (hidden mul) = 240, then × 1.05 = 252
    var contrib := SellMath.item_contribution(_item_verified, _customer)
    assert_eq(contrib, 252, "customer pricing + verified bonus")


func _make_anchor(base_value: int = 100) -> AnchorData:
    var a := AnchorData.new()
    a.anchor_id = "test_anchor"
    a.base_value = base_value
    return a
