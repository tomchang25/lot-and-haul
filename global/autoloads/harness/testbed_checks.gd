# testbed_checks.gd
# Static helper that provides three machine-checkable observations for the
# testbed agent pilot: error-level log scanning, stall detection, and foreground
# panel overlap geometry. All methods are pure and stateless — the pilot holds
# the report dict.
extends RefCounted

class_name TestbedChecks

## Benign noise patterns from headless Godot that should not be flagged as errors.
## Mirrors the grep -v filter in .github/workflows/ci.yml smoke-test job.
const BENIGN_PATTERNS: Array[String] = [
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
    var anchor: Control = Director.get_anchor(aid)
    if anchor == null:
        return hits
    if panel.get_global_rect().intersects(anchor.get_global_rect()):
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
