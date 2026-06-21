# testbed_pilot.gd
# Agent-driven headless entry point for testbeds. Activates only when
# --testbed=<id> is present on the command line. Takes the same wipe-seed-enter
# sequence as the manual launcher, then drives the flow, captures per-step
# screenshots, and reports three mechanical checks (error-level log lines,
# stalls, and foreground panel overlaps).
#
# Invocation (xvfb required for real frame capture):
#   xvfb-run -a -s "-screen 0 1280x720x24" \
#     Godot --path "$LH" --rendering-driver opengl3 --display-driver x11 \
#     --testbed=storage --testbed-shot-dir=/tmp/shots
#
# Completely inert without the --testbed= flag, even in release exports.
extends Node

## Default seconds to wait for a tutorial step to advance before flagging a stall.
const DEFAULT_STALL_TIMEOUT_SEC: float = 5.0

## Default screenshot output directory.
const DEFAULT_SHOT_DIR: String = "user://testbed_shots"

var _id: String = ""
var _shot_dir: String = ""
var _stall_timeout: float = DEFAULT_STALL_TIMEOUT_SEC


func _ready() -> void:
    var args := OS.get_cmdline_args()
    if not _parse_flags(args):
        return
    print("TestbedPilot: id=%s shot_dir=%s stall_timeout=%.1f" % [_id, _shot_dir, _stall_timeout])
    call_deferred("_run")


## Parses --testbed=<id>, --testbed-shot-dir=<path>, and
## --testbed-stall-timeout=<seconds>.
## Returns false when --testbed= is absent (harness stays inert).
func _parse_flags(args: PackedStringArray) -> bool:
    for arg: String in args:
        if arg.begins_with("--testbed="):
            _id = arg.trim_prefix("--testbed=")
        elif arg.begins_with("--testbed-shot-dir="):
            _shot_dir = arg.trim_prefix("--testbed-shot-dir=")
        elif arg.begins_with("--testbed-stall-timeout="):
            var val := arg.trim_prefix("--testbed-stall-timeout=")
            var parsed := val.to_float()
            if parsed > 0.0:
                _stall_timeout = parsed
    if _id.is_empty():
        return false
    if _shot_dir.is_empty():
        _shot_dir = DEFAULT_SHOT_DIR
    return true


## Main entry: resolve the registry entry, launch the testbed, drive the flow,
## collect the three checks, write the report, and exit.
func _run() -> void:
    print("TestbedPilot: starting testbed '%s'" % _id)

    var entry := TestbedRegistry.get_entry(_id)
    if entry.is_empty():
        ToastManager.show_error("TestbedPilot: unknown testbed id '%s'" % _id)
        get_tree().quit(1)
        return

    DirAccess.make_dir_recursive_absolute(_shot_dir)

    TestbedRegistry.launch(entry)
    await _settle()

    var report: Dictionary = { "id": _id, "errors": [], "stalls": [], "overlaps": [] }

    var tutorial_id: String = entry.get("tutorial", "")
    if not tutorial_id.is_empty():
        Director.start_script(tutorial_id)
        await _settle()

        var step_count := Director.step_count()
        for i: int in step_count:
            _snap("%s_step_%02d" % [_id, i])
            report["overlaps"] += TestbedChecks.overlaps_for_current_step()

            var advanced := await _advance_with_timeout()
            if not advanced:
                report["stalls"].append(i)
                print("TestbedPilot: stall at step %d" % i)
                break # cannot continue a stalled flow

    # Scan the Godot project log for error-level lines.
    var log_path := OS.get_user_data_dir().path_join("logs/godot.log")
    report["errors"] = TestbedChecks.scan_log(log_path)

    _write_report(report)

    var clean := _is_clean(report)
    print("TestbedPilot: %s" % ("OK" if clean else "FAILED"))
    get_tree().quit(0 if clean else 1)


## Advances the current tutorial step and waits for Director.step_index() to
## increment (or the scene to change) within STALL_TIMEOUT_SEC. One retry is
## attempted before declaring a stall so a slow single frame does not become
## a false positive.
## Returns true when the step advanced, false on timeout (stall).
func _advance_with_timeout() -> bool:
    var before := Director.step_index()
    Director.advance_step()
    if await _poll_step_change(before):
        return true
    # One retry before declaring a stall.
    if await _poll_step_change(before):
        return true
    return false


## Polls step_index changes for up to STALL_TIMEOUT_SEC. Returns true when the
## step advances or the scene changes.
func _poll_step_change(before: int) -> bool:
    var elapsed := 0.0
    while elapsed < _stall_timeout:
        await get_tree().process_frame
        elapsed += get_process_delta_time()
        if Director.step_index() != before:
            return true
        if Director.step_index() == 0 and before > 0:
            return true
    return false


## Waits several process frames for the scene and overlay to settle.
func _settle() -> void:
    for i: int in 4:
        await get_tree().process_frame


## Captures the current viewport to a PNG at [param base_name].png.
func _snap(base_name: String) -> void:
    var img := get_viewport().get_texture().get_image()
    var path := _shot_dir.path_join(base_name + ".png")
    img.save_png(path)
    print("TestbedPilot: captured %s" % path)


## Writes the report JSON to the shot directory.
func _write_report(report: Dictionary) -> void:
    var path := _shot_dir.path_join("%s_report.json" % _id)
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        ToastManager.show_warning("TestbedPilot: could not write report to %s" % path)
        return
    file.store_string(JSON.stringify(report, "\t"))
    file.close()
    print("TestbedPilot: report written to %s" % path)


## Returns true when the report has no errors, stalls, or overlaps.
func _is_clean(report: Dictionary) -> bool:
    return (
        (report["errors"] as Array).is_empty()
        and (report["stalls"] as Array).is_empty()
        and (report["overlaps"] as Array).is_empty()
    )
