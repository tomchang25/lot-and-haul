# test_shop_session_store.gd
# Layer 1 - ShopSessionStore unit tests. Verifies the boot-routing pointer,
# the active-customer id, and the placement list survive a save/load
# round-trip; defaults are empty when the section is absent; clear() resets
# all fields.
extends GutTest

func test_defaults_are_empty() -> void:
    var store := ShopSessionStore.new()
    assert_eq(store.active_customer_session_id, "", "active_customer_session_id should default to empty")
    assert_eq(store.placement.size(), 0, "placement should default to empty")
    assert_eq(store.pending_scene, "", "pending_scene should default to empty")
    assert_false(store.has_session(), "has_session should be false by default")


func test_section_id_is_shop_session() -> void:
    assert_eq(ShopSessionStore.new().section_id(), "shop_session", "section id should be 'shop_session'")


func test_set_active_customer_and_placement() -> void:
    var store := ShopSessionStore.new()
    store.set_active_customer("c1")
    store.set_placement(
        [
            {
                "item_id": 7,
                "cell": { "x": 1, "y": 2 },
                "rotation": 3,
            },
        ],
    )
    store.set_pending_scene(ShopSessionStore.SCENE_CUSTOMER_SELL)

    assert_eq(store.active_customer_session_id, "c1", "active_customer_session_id should be set")
    assert_eq(store.placement.size(), 1, "placement should hold one entry")
    assert_eq(store.pending_scene, "customer_sell", "pending_scene should be customer_sell")
    assert_true(store.has_session(), "has_session should be true when pending_scene is set")


func test_set_placement_deduplicates_array() -> void:
    # The setter deep-duplicates the input, so mutating the caller's array
    # afterwards must not mutate the store's internal list.
    var store := ShopSessionStore.new()
    var input: Array = [{ "item_id": 1, "cell": { "x": 0, "y": 0 }, "rotation": 0 }]
    store.set_placement(input)
    input.append({ "item_id": 2, "cell": { "x": 1, "y": 1 }, "rotation": 0 })
    assert_eq(store.placement.size(), 1, "store's placement should not see the appended entry")


func test_clear_resets_all_fields() -> void:
    var store := ShopSessionStore.new()
    store.set_active_customer("c1")
    store.set_placement([{ "item_id": 1, "cell": { "x": 0, "y": 0 }, "rotation": 0 }])
    store.set_pending_scene("customer_sell")
    store.clear()
    assert_eq(store.active_customer_session_id, "", "clear should empty active_customer_session_id")
    assert_eq(store.placement.size(), 0, "clear should empty placement")
    assert_eq(store.pending_scene, "", "clear should empty pending_scene")


func test_to_dict_round_trip() -> void:
    var ctx := SaveLoadContext.new()
    var store := ShopSessionStore.new()
    store.set_active_customer("c42")
    store.set_placement(
        [
            { "item_id": 11, "cell": { "x": 0, "y": 1 }, "rotation": 2 },
            { "item_id": 12, "cell": { "x": 3, "y": 4 }, "rotation": 0 },
        ],
    )
    store.set_pending_scene(ShopSessionStore.SCENE_CUSTOMER_SELL)

    var payload := store.to_dict()
    assert_eq(payload.get("active_customer_session_id", ""), "c42", "to_dict should serialize active_customer_session_id")
    assert_eq(payload.get("pending_scene", ""), "customer_sell", "to_dict should serialize pending_scene")
    assert_eq(payload.get("placement", []).size(), 2, "to_dict should serialize two placement entries")

    var restored := ShopSessionStore.new()
    restored.from_dict(payload, ctx)
    assert_eq(restored.active_customer_session_id, "c42", "from_dict should restore active_customer_session_id")
    assert_eq(restored.pending_scene, "customer_sell", "from_dict should restore pending_scene")
    assert_eq(restored.placement.size(), 2, "from_dict should restore both placement entries")
    var first := restored.placement[0] as Dictionary
    assert_eq(int(first.get("item_id", -1)), 11, "first entry item_id should round-trip")
    assert_eq(int(first.get("cell", { }).get("x", -1)), 0, "first entry cell x should round-trip")
    assert_eq(int(first.get("cell", { }).get("y", -1)), 1, "first entry cell y should round-trip")
    assert_eq(int(first.get("rotation", -1)), 2, "first entry rotation should round-trip")


func test_from_dict_defaults_when_section_missing() -> void:
    # Pre-feature save: no shop_session section, no pending_scene field. The
    # defensive reads in from_dict should default to empty without warnings.
    var ctx := SaveLoadContext.new()
    var store := ShopSessionStore.new()
    store.from_dict({ }, ctx)
    assert_eq(store.active_customer_session_id, "", "missing data should default active_customer_session_id to empty")
    assert_eq(store.placement.size(), 0, "missing data should default placement to empty")
    assert_eq(store.pending_scene, "", "missing data should default pending_scene to empty")
    assert_eq(ctx.warnings.size(), 0, "missing section should not emit warnings")


func test_from_dict_drops_malformed_placement_entries() -> void:
    var ctx := SaveLoadContext.new()
    var store := ShopSessionStore.new()
    store.from_dict(
        {
            "placement": [
                { "item_id": 1, "cell": { "x": 0, "y": 0 }, "rotation": 0 },
                "not_a_dict",
                null,
                { "item_id": 2, "cell": { "x": 1, "y": 1 }, "rotation": 0 },
            ],
        },
        ctx,
    )
    assert_eq(store.placement.size(), 2, "only dict-typed placement entries should survive restore")


func test_cell_for_item_returns_saved_cell() -> void:
    var store := ShopSessionStore.new()
    store.set_placement(
        [
            { "item_id": 5, "cell": { "x": 2, "y": 3 }, "rotation": 1 },
        ],
    )
    var cell := store.cell_for_item(5)
    assert_eq(cell.x, 2, "cell x should match the saved value")
    assert_eq(cell.y, 3, "cell y should match the saved value")


func test_cell_for_item_returns_sentinel_when_absent() -> void:
    var store := ShopSessionStore.new()
    var cell := store.cell_for_item(99)
    assert_eq(cell, Vector2i(-1, -1), "missing item should return Vector2i(-1, -1)")


func test_rotation_for_item_returns_saved_value() -> void:
    var store := ShopSessionStore.new()
    store.set_placement(
        [
            { "item_id": 5, "cell": { "x": 0, "y": 0 }, "rotation": 3 },
        ],
    )
    assert_eq(store.rotation_for_item(5), 3, "rotation should match the saved value")


func test_rotation_for_item_defaults_to_zero() -> void:
    var store := ShopSessionStore.new()
    assert_eq(store.rotation_for_item(99), 0, "missing item should default rotation to 0")
