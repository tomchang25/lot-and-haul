# test_error_filters_consistency.gd
# Asserts that the GDScript constants in TestbedChecks match the canonical
# dev/ci/error_filters.json file. If this test fails, update both sides to
# match (typically the JSON first, then update the const arrays).
extends GutTest

var _json_data: Dictionary = { }


func before_all() -> void:
    _json_data = TestbedChecks.load_error_filters_from_json()
    if _json_data.is_empty():
        push_warning("error_filters.json not available — skipping consistency assertions")


func test_error_patterns_match_json() -> void:
    if _json_data.is_empty():
        return
    var json_errors: Array = _json_data.get("error_patterns", [])
    var gdscript_errors: Array[String] = TestbedChecks.ERROR_PATTERNS.duplicate()
    gdscript_errors.sort()
    json_errors.sort()
    assert_eq_deep(gdscript_errors, json_errors)


func test_benign_patterns_match_json() -> void:
    if _json_data.is_empty():
        return
    var json_benign: Array = _json_data.get("benign_patterns", [])
    var gdscript_benign: Array[String] = TestbedChecks.BENIGN_PATTERNS.duplicate()
    gdscript_benign.sort()
    json_benign.sort()
    assert_eq_deep(gdscript_benign, json_benign)


func test_error_filters_json_has_required_keys() -> void:
    if _json_data.is_empty():
        return
    assert_has(_json_data, "error_patterns", "error_filters.json must have error_patterns key")
    assert_has(_json_data, "benign_patterns", "error_filters.json must have benign_patterns key")


func test_error_filters_json_keys_are_arrays() -> void:
    if _json_data.is_empty():
        return
    assert_true(typeof(_json_data["error_patterns"]) == TYPE_ARRAY, "error_patterns must be an array")
    assert_true(typeof(_json_data["benign_patterns"]) == TYPE_ARRAY, "benign_patterns must be an array")
