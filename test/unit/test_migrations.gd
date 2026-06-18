# test_migrations.gd
# Phase 2 — migration regression tests for every store with a real transform.
# Constructs historical payloads and verifies the migrated output at the
# dictionary/data level. Full from_dict integration (which resolves registries
# and calls ItemEntry.from_dict) is tested in test_save_round_trip.gd.
extends GutTest

# ══ StorageStore migration (v1 → v2) — dict-level transform tests ═══════
# These tests construct a StorageStore, feed v1-format data through from_dict,
# and check the migration outcome. Entries that survive migration must still
# resolve through ItemEntry.from_dict (which requires anchor/clue registries)
# tests for the sniffing/erasure behaviors therefore only pass when the
# YAML→tres pipeline has been run. The item_id-dropped test is registry-free.

## ctx.infos should mention the dropped entry when an item_id-only (no anchor_id)
## entry is fed through migration.
func test_storage_v1_item_id_dropped_emits_info() -> void:
    var ctx := SaveLoadContext.new()
    var store := StorageStore.new()
    store.from_dict(
        {
            "_version": 1,
            "storage_items": [
                { "item_id": "ghost_item", "anchor_revealed": true, "inspected": false },
            ],
        },
        ctx,
    )
    var found := false
    for msg: String in ctx.infos:
        if msg.contains("dropped"):
            found = true
            break
    assert_true(found, "migration should emit info about dropped item_id-only entry")


func test_storage_v1_migration_survives_all_items_dropped() -> void:
    var ctx := SaveLoadContext.new()
    var store := StorageStore.new()
    store.from_dict(
        {
            "_version": 1,
            "storage_items": [
                { "item_id": "a" },
                { "item_id": "b" },
            ],
        },
        ctx,
    )
    assert_eq(store.storage_items.size(), 0, "dropped entries should result in zero storage items")

# ══ ProgressStore migration (v1 → v2) ════════════════════════════════════
# These tests are registry-independent because the migration only adds a
# tutorial_seen dict with no resource resolution.


func test_progress_v1_missing_tutorial_seen_added() -> void:
    var ctx := SaveLoadContext.new()
    var store := ProgressStore.new()
    var v1_data := {
        "_version": 1,
        "current_day": 10,
        "available_location_ids": [],
    }
    store.from_dict(v1_data, ctx)
    assert_eq(store.tutorial_seen.size(), 0, "tutorial_seen should be initialized as empty if missing")


func test_progress_v1_non_dict_tutorial_seen_replaced() -> void:
    var ctx := SaveLoadContext.new()
    var store := ProgressStore.new()
    var v1_data := {
        "_version": 1,
        "current_day": 10,
        "available_location_ids": [],
        "tutorial_seen": "corrupted_string",
    }
    store.from_dict(v1_data, ctx)
    assert_eq(store.tutorial_seen.size(), 0, "non-dict tutorial_seen should be replaced")


func test_progress_v2_preserves_tutorial_seen() -> void:
    var ctx := SaveLoadContext.new()
    var store := ProgressStore.new()
    var v2_data := {
        "_version": 2,
        "current_day": 10,
        "available_location_ids": [],
        "tutorial_seen": { "hub": true },
    }
    store.from_dict(v2_data, ctx)
    assert_true(store.tutorial_seen.has("hub"), "tutorial_seen hub should be preserved")

# ══ ProgressStore migration (v2 → v3) — onboarding_pending ═══════════════


func test_progress_defaults_onboarding_pending_true() -> void:
    var store := ProgressStore.new()
    assert_true(store.onboarding_pending, "new ProgressStore should have onboarding_pending=true")


func test_progress_v2_missing_onboarding_pending_added_as_false() -> void:
    var ctx := SaveLoadContext.new()
    var store := ProgressStore.new()
    var v2_data := {
        "_version": 2,
        "current_day": 10,
        "available_location_ids": [],
        "tutorial_seen": { },
    }
    store.from_dict(v2_data, ctx)
    assert_false(store.onboarding_pending, "onboarding_pending should be false after v2→v3 migration")


func test_progress_v3_preserves_onboarding_pending_false() -> void:
    var ctx := SaveLoadContext.new()
    var store := ProgressStore.new()
    var v3_data := {
        "_version": 3,
        "current_day": 10,
        "available_location_ids": [],
        "tutorial_seen": { },
        "onboarding_pending": false,
    }
    store.from_dict(v3_data, ctx)
    assert_false(store.onboarding_pending, "onboarding_pending=false should survive round trip")


func test_progress_v3_preserves_onboarding_pending_true() -> void:
    var ctx := SaveLoadContext.new()
    var store := ProgressStore.new()
    var v3_data := {
        "_version": 3,
        "current_day": 10,
        "available_location_ids": [],
        "tutorial_seen": { },
        "onboarding_pending": true,
    }
    store.from_dict(v3_data, ctx)
    assert_true(store.onboarding_pending, "onboarding_pending=true should survive round trip")

# ══ SlotStore migration (v1 → v2) — three-slot to two-slot remap ═══════


func test_slot_v1_morning_maps_to_day() -> void:
    var ctx := SaveLoadContext.new()
    var store := SlotStore.new()
    store.from_dict(
        {
            "_version": 1,
            "current_slot": 1,
        },
        ctx,
    )
    assert_eq(store.current_slot, SlotStore.SLOT_DAY, "Morning (1) should map to Day")


func test_slot_v1_afternoon_maps_to_night() -> void:
    var ctx := SaveLoadContext.new()
    var store := SlotStore.new()
    store.from_dict(
        {
            "_version": 1,
            "current_slot": 2,
        },
        ctx,
    )
    assert_eq(store.current_slot, SlotStore.SLOT_NIGHT, "Afternoon (2) should map to Night")


func test_slot_v1_evening_maps_to_night() -> void:
    var ctx := SaveLoadContext.new()
    var store := SlotStore.new()
    store.from_dict(
        {
            "_version": 1,
            "current_slot": 3,
        },
        ctx,
    )
    assert_eq(store.current_slot, SlotStore.SLOT_NIGHT, "Evening (3) should map to Night")


func test_slot_v1_past_evening_maps_to_day_ending() -> void:
    var ctx := SaveLoadContext.new()
    var store := SlotStore.new()
    store.from_dict(
        {
            "_version": 1,
            "current_slot": 4,
        },
        ctx,
    )
    assert_eq(store.current_slot, SlotStore.SLOT_DAY_ENDING, ">3 should map to day-ending")


func test_slot_v2_preserves_current_slot() -> void:
    var ctx := SaveLoadContext.new()
    var store := SlotStore.new()
    store.from_dict(
        {
            "_version": 2,
            "current_slot": SlotStore.SLOT_NIGHT,
        },
        ctx,
    )
    assert_eq(store.current_slot, SlotStore.SLOT_NIGHT, "v2 data should preserve Night slot")


func test_slot_v1_migration_is_idempotent() -> void:
    # A v1 payload with current_slot=4 would map to 3 (day-ending) on the first
    # pass, and to 2 (Night) on a re-run of the migration. The _version stamp
    # at the end of _apply_migrations prevents the second pass from re-firing.
    var ctx := SaveLoadContext.new()
    var store := SlotStore.new()
    var data := {
        "_version": 1,
        "current_slot": 4,
    }
    store.from_dict(data, ctx)
    assert_eq(store.current_slot, SlotStore.SLOT_DAY_ENDING, "first pass maps 4 to day-ending (3)")
    # Re-feeding the same dict — the stamped _version should bypass migration.
    store.from_dict(data, ctx)
    assert_eq(store.current_slot, SlotStore.SLOT_DAY_ENDING, "re-run must not re-migrate to Night (2)")
