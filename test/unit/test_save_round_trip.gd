# test_save_round_trip.gd
# Phase 2 — save round-trip tests using committed save_v2 fixture data.
# Loads the fixture through the real parse path, asserts representative
# fields, then serializes and restores to prove shape stability.
extends GutTest

const SAVE_V2_PATH := "res://test/test_data/save_v2/save_81.json"


func test_fixture_exists() -> void:
    assert_true(FileAccess.file_exists(SAVE_V2_PATH), "save_v2 fixture file should exist")


func test_fixture_schema_version() -> void:
    var data := _load_fixture()
    assert_not_null(data, "fixture should parse")
    assert_eq(data.get("schema_version", -1), 2, "schema_version should be 2")


func test_fixture_has_sections() -> void:
    var data := _load_fixture()
    var sections: Dictionary = data.get("sections", { })
    assert_true(sections.size() > 0, "sections should not be empty")


func test_fixture_expected_section_keys() -> void:
    var data := _load_fixture()
    var sections: Dictionary = data.get("sections", { })
    var expected_keys := [
        "economy",
        "progress",
        "storage",
        "garage",
        "customers",
        "slot",
        "knowledge",
    ]
    for key: String in expected_keys:
        assert_true(sections.has(key), "sections should contain '%s'" % key)


func test_economy_cash_value() -> void:
    var data := _load_fixture()
    var economy: Dictionary = data.get("sections", { }).get("economy", { })
    var cash: int = economy.get("cash", -1)
    assert_eq(cash, 258350, "economy.cash should be 258350")


func test_progress_current_day() -> void:
    var data := _load_fixture()
    var progress: Dictionary = data.get("sections", { }).get("progress", { })
    var day: int = progress.get("current_day", -1)
    assert_eq(day, 283, "progress.current_day should be 283")


func test_storage_has_items() -> void:
    var data := _load_fixture()
    var storage: Dictionary = data.get("sections", { }).get("storage", { })
    var items: Array = storage.get("storage_items", [])
    assert_true(items.size() > 0, "storage should have items")


func test_garage_has_active_car() -> void:
    var data := _load_fixture()
    var garage: Dictionary = data.get("sections", { }).get("garage", { })
    var active_car: String = garage.get("active_car_id", "")
    assert_eq(active_car, "semi_rig", "garage.active_car_id should be semi_rig")


func test_json_round_trip_stability() -> void:
    var original := _load_fixture()
    assert_not_null(original, "fixture should parse")

    var re_encoded := JSON.stringify(original)
    var parsed: Variant = JSON.parse_string(re_encoded)
    assert_not_null(parsed, "re-encoded JSON should parse")
    assert_true(parsed is Dictionary, "re-parsed value should be a Dictionary")

    var parsed_dict: Dictionary = parsed as Dictionary
    assert_eq(
        parsed_dict.get("schema_version", -1),
        original.get("schema_version", -1),
        "schema_version should survive round trip",
    )

    var orig_sections: Dictionary = original.get("sections", { })
    var new_sections: Dictionary = parsed_dict.get("sections", { })
    assert_eq(
        new_sections.keys().size(),
        orig_sections.keys().size(),
        "section key count should survive round trip",
    )


func test_section_content_survives_round_trip() -> void:
    var original := _load_fixture()
    var re_encoded := JSON.stringify(original)
    var parsed: Variant = JSON.parse_string(re_encoded)

    var orig_economy: Dictionary = original.get("sections", { }).get("economy", { })
    var new_economy: Dictionary = (parsed as Dictionary).get("sections", { }).get("economy", { })
    assert_eq(
        new_economy.get("cash", -1),
        orig_economy.get("cash", -1),
        "economy.cash should survive round trip",
    )

    var orig_progress: Dictionary = original.get("sections", { }).get("progress", { })
    var new_progress: Dictionary = (parsed as Dictionary).get("sections", { }).get("progress", { })
    assert_eq(
        new_progress.get("current_day", -1),
        orig_progress.get("current_day", -1),
        "progress.current_day should survive round trip",
    )


func _load_fixture() -> Variant:
    if not FileAccess.file_exists(SAVE_V2_PATH):
        return null
    var file := FileAccess.open(SAVE_V2_PATH, FileAccess.READ)
    if file == null:
        return null
    var text := file.get_as_text()
    file.close()
    return JSON.parse_string(text)
