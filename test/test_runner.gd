# test_runner.gd
# Automated test runner invoked by GameManager when --test-unit is present.
# Creates GUT node, runs all tests in res://test/unit/, and exits.
extends Node

var _gut: GutMain = null
var _tracker: GutErrorTracker = null


func _ready() -> void:
    await get_tree().process_frame
    await get_tree().process_frame
    _run_all()


func _run_all() -> void:
    _tracker = _FilteredErrorTracker.new()
    _gut = GutMain.new()
    _gut.error_tracker = _tracker
    GutErrorTracker.register_logger(_tracker)
    add_child(_gut)
    _gut.include_subdirectories = true
    _gut.ignore_pause_before_teardown = true
    _gut.log_level = GutMain.LOG_LEVEL_FAIL_ONLY
    _gut.add_directory("res://test/unit")
    _gut.end_run.connect(_on_run_finished)
    _gut.run_tests()


func _on_run_finished() -> void:
    if _tracker != null:
        GutErrorTracker.deregister_logger(_tracker)
    if _gut == null:
        get_tree().quit(1)
        return
    var tc = _gut.get_test_collector()
    var totals := _summarize(tc, _gut.get_logger())
    var failed: bool = totals.failing_tests > 0 or totals.errors > 0
    print(
        "TestRunner: %d scripts, %d tests, %d passed, %d failed, %d errors" % [
            totals.scripts,
            totals.tests,
            totals.passing_tests,
            totals.failing_tests,
            totals.errors,
        ],
    )
    get_tree().quit(1 if failed else 0)

# ── Filtered error tracker ──────────────────────────────────────────────


class _FilteredErrorTracker extends GutErrorTracker:
    ## Exempts errors whose text matches a benign pattern from
    ## TestbedChecks.BENIGN_PATTERNS, while keeping the default
    ## treat-everything-as-failure for all other errors.

    func _is_error_failable(error: GutTrackedError) -> bool:
        if error.handled:
            return false
        for pattern: String in TestbedChecks.BENIGN_PATTERNS:
            if error.contains_text(pattern):
                return false
        return super._is_error_failable(error)


static func _summarize(tc, logger) -> Dictionary:
    var out := {
        passing = 0,
        failing = 0,
        pending = 0,
        risky = 0,
        passing_tests = 0,
        failing_tests = 0,
        scripts = 0,
        tests = 0,
        errors = 0,
        warnings = 0,
        orphans = 0,
    }
    if tc == null:
        return out
    out.scripts = tc.get_ran_script_count()
    for s in tc.get_scripts():
        out.passing += s.get_pass_count()
        out.pending += s.get_pending_count()
        out.failing += s.get_fail_count()
        out.tests += s.get_ran_test_count()
        out.passing_tests += s.get_passing_test_count()
        out.failing_tests += s.get_failing_test_count()
        out.risky += s.get_risky_count()
    if logger != null:
        out.errors = logger.get_errors().size()
        out.warnings = logger.get_warnings().size()
    return out
