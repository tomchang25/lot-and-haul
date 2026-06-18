# testbed_checks.gd
# Static helper that provides three machine-checkable observations for the
# testbed agent pilot: error-level log scanning, stall detection, and foreground
# panel overlap geometry. All methods are pure and stateless — the pilot holds
# the report dict.
extends RefCounted

class_name TestbedChecks

## Canonical error and benign patterns, kept in sync with dev/ci/error_filters.json.
## Test test/unit/test_error_filters_consistency.gd asserts the two stay in sync.
## Benign noise patterns from headless Godot that should not be flagged as errors.
## Mirrors the grep -v filter in .github/workflows/ci.yml smoke-test job.
const BENIGN_PATTERNS: Array[String] = [
    "[DEBUG-PASS]",
    "AudioServer",
    "DisplayServer",
    "PulseAudio",
    "ALSA",
    "D3D12",
    "WASAPI",
    "CoreAudio",
]

## Error-level patterns to scan for in the Godot log (matches ci.yml filter).
const ERROR_PATTERNS: Array[String] = [
    "SCRIPT ERROR",
    "ERROR:",
    "push_error",
    "FATAL",
]


## Loads error filters from dev/ci/error_filters.json and returns them as a
## Dictionary with "error_patterns" and "benign_patterns" arrays. Returns null
## when the file is missing or unparseable. Consumers that want one source of
## truth can call this instead of referencing the const arrays directly.
static func load_error_filters_from_json() -> Dictionary:
    var path := "res://dev/ci/error_filters.json"
    if not FileAccess.file_exists(path):
        push_warning("TestbedChecks: error_filters.json not found at %s" % path)
        return { }
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_warning("TestbedChecks: could not open %s" % path)
        return { }
    var raw := file.get_as_text()
    file.close()
    var parsed := JSON.parse_string(raw)
    if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
        push_warning("TestbedChecks: error_filters.json is not a valid JSON object")
        return { }
    return parsed as Dictionary


## Scans [param log_path] for error-level lines, excluding benign engine noise.
## Returns an Array of matching line strings (empty = clean).
static func scan_log(log_path: String) -> Array[String]:
    var hits: Array[String] = []
    if not FileAccess.file_exists(log_path):
        return hits
    var file := FileAccess.open(log_path, FileAccess.READ)
    if file == null:
        return hits
    while not file.eof_reached():
        var line := file.get_line()
        if not _is_error_line(line):
            continue
        if _is_benign(line):
            continue
        hits.append(line)
    file.close()
    return hits


## Returns overlap records for the current Director step. Each record is a
## Dictionary with "step" (int) and "covers" (String anchor_id).
## The foreground hint panel must not intersect the anchor it points at.
static func overlaps_for_current_step() -> Array[Dictionary]:
    var hits: Array[Dictionary] = []
    var panel: Control = Director.get_hint_panel()
    if panel == null or not panel.visible:
        return hits
    var step_idx := Director.step_index()
    var aid := Director.step_anchor_id(step_idx)
    if aid.is_empty():
        return hits
    var target_rect: Rect2 = Director.get_target_rect(aid)
    if target_rect.size.x <= 0 or target_rect.size.y <= 0:
        return hits
    if panel.get_global_rect().intersects(target_rect):
        hits.append({ "step": step_idx, "covers": aid })
    return hits


static func _is_error_line(line: String) -> bool:
    for pattern: String in ERROR_PATTERNS:
        if line.contains(pattern):
            return true
    return false


static func _is_benign(line: String) -> bool:
    for pattern: String in BENIGN_PATTERNS:
        if line.contains(pattern):
            return true
    return false
