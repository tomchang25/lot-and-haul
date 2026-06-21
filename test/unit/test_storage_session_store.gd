# test_storage_session_store.gd
# Layer 1 - StorageSessionStore unit tests. Verifies the session lifecycle:
# begin sets active + resume target + selected entry; save/load round-trip
# preserves all fields; clear resets to inactive; missing section defaults
# to inactive; unknown resume target silently clears; validate matches invariants.
extends GutTest

func test_defaults_are_inactive() -> void:
    var store := StorageSessionStore.new()
    assert_false(store.active, "active should default to false")
    assert_eq(store.resume_target, "", "resume_target should default to empty")
    assert_eq(store.selected_entry_id, -1, "selected_entry_id should default to -1")
    assert_false(store.has_session(), "has_session should be false by default")
    assert_false(store.is_active(), "is_active should be false by default")


func test_section_id_is_storage_session() -> void:
    assert_eq(StorageSessionStore.new().section_id(), "storage_session", "section id should be 'storage_session'")


func test_begin_activates_session() -> void:
    var store := StorageSessionStore.new()
    store.begin(42)
    assert_true(store.active, "active should be true after begin")
    assert_eq(store.resume_target, "storage", "resume_target should be 'storage' after begin")
    assert_eq(store.selected_entry_id, 42, "selected_entry_id should match the value passed to begin")
    assert_true(store.has_session(), "has_session should be true after begin")
    assert_true(store.is_active(), "is_active should be true after begin")


func test_begin_with_negative_id() -> void:
    var store := StorageSessionStore.new()
    store.begin(-1)
    assert_true(store.active, "active should be true after begin")
    assert_eq(store.selected_entry_id, -1, "selected_entry_id should store -1 when passed")


func test_set_selected_entry_from_item() -> void:
    var store := StorageSessionStore.new()
    store.begin(0)
    var entry := ItemEntry.new()
    entry.id = 77
    store.set_selected_entry(entry)
    assert_eq(store.selected_entry_id, 77, "selected_entry_id should match the entry id")


func test_set_selected_entry_null_clears() -> void:
    var store := StorageSessionStore.new()
    store.begin(0)
    store.set_selected_entry(null)
    assert_eq(store.selected_entry_id, -1, "selected_entry_id should reset to -1 when entry is null")


func test_clear_resets_all_fields() -> void:
    var store := StorageSessionStore.new()
    store.begin(42)
    store.clear()
    assert_false(store.active, "clear should set active to false")
    assert_eq(store.resume_target, "", "clear should empty resume_target")
    assert_eq(store.selected_entry_id, -1, "clear should reset selected_entry_id to -1")
    assert_false(store.has_session(), "has_session should be false after clear")


func test_has_session_requires_active_and_storage_target() -> void:
    var ctx := SaveLoadContext.new()
    var wrong_target_store := StorageSessionStore.new()
    wrong_target_store.from_dict(
        {
            "_version": 1,
            "active": true,
            "resume_target": "something_else",
            "selected_entry_id": 1,
        },
        ctx,
    )
    assert_false(wrong_target_store.has_session(), "has_session should be false when resume_target is not 'storage'")

    var inactive_store := StorageSessionStore.new()
    inactive_store.from_dict(
        {
            "_version": 1,
            "active": false,
            "resume_target": StorageSessionStore.SCENE_STORAGE,
            "selected_entry_id": 1,
        },
        ctx,
    )
    assert_false(inactive_store.has_session(), "has_session should be false when not active")


func test_to_dict_round_trip() -> void:
    var ctx := SaveLoadContext.new()
    var store := StorageSessionStore.new()
    store.begin(99)
    store.set_selected_entry(null) # clear to -1

    var payload := store.to_dict()
    assert_eq(payload.get("_version", 0), 1, "to_dict should include _version")
    assert_eq(payload.get("active", false), true, "to_dict should serialize active")
    assert_eq(payload.get("resume_target", ""), "storage", "to_dict should serialize resume_target")
    assert_eq(payload.get("selected_entry_id", -1), -1, "to_dict should serialize selected_entry_id")

    var restored := StorageSessionStore.new()
    restored.from_dict(payload, ctx)
    assert_eq(restored.active, true, "from_dict should restore active")
    assert_eq(restored.resume_target, "storage", "from_dict should restore resume_target")
    assert_eq(restored.selected_entry_id, -1, "from_dict should restore selected_entry_id")
    assert_true(restored.has_session(), "from_dict should produce a valid session")


func test_from_dict_defaults_when_section_missing() -> void:
    var ctx := SaveLoadContext.new()
    var store := StorageSessionStore.new()
    store.from_dict({ }, ctx)
    assert_false(store.active, "missing data should default active to false")
    assert_eq(store.resume_target, "", "missing data should default resume_target to empty")
    assert_eq(store.selected_entry_id, -1, "missing data should default selected_entry_id to -1")
    assert_eq(ctx.warnings.size(), 0, "missing section should not emit warnings")


func test_from_dict_silently_clears_unknown_resume_target() -> void:
    var ctx := SaveLoadContext.new()
    var store := StorageSessionStore.new()
    store.from_dict(
        {
            "_version": 1,
            "active": true,
            "resume_target": "bogus_scene",
            "selected_entry_id": 5,
        },
        ctx,
    )
    assert_false(store.active, "store should clear active when resume_target is unknown")
    assert_eq(store.resume_target, "", "store should clear resume_target when unknown")
    assert_eq(store.selected_entry_id, 5, "selected_entry_id should remain intact after target clear")
    assert_false(store.has_session(), "has_session should be false after unknown target recovery")


func test_validate_passes_when_inactive() -> void:
    var store := StorageSessionStore.new()
    assert_true(store.validate(), "inactive store should validate")


func test_validate_passes_when_active_with_valid_state() -> void:
    var store := StorageSessionStore.new()
    store.begin(10)
    assert_true(store.validate(), "active store with valid resume_target and selected_entry_id should validate")


func test_validate_fails_when_active_with_invalid_selected_entry_id() -> void:
    var ctx := SaveLoadContext.new()
    var store := StorageSessionStore.new()
    store.from_dict(
        {
            "_version": 1,
            "active": true,
            "resume_target": StorageSessionStore.SCENE_STORAGE,
            "selected_entry_id": -2,
        },
        ctx,
    )
    assert_false(store.validate(), "active store with selected_entry_id below -1 should fail validation")
