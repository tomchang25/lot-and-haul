# shot_pilot.gd
# Generic screenshot harness — captures one PNG per tutorial step for visual
# review. Driven by a manifest (no per-target code). Activates only when
# --tutorial-shot=<script_id|all> is present on the command line. Completely
# inert without the flag, even in release exports.
extends Node

const DEFAULT_SHOT_DIR: String = "user://tutorial_shots"


## Manifest entry shape.
## scene:   scene id passed to SceneRouter (and used as capture filename prefix).
## fixture: name of a static fixture method in game/<scene>/<scene>_fixtures.gd,
##          or "" if no seeding is needed.
## offer:   if true, capture the offer prompt and accept it before stepping.
static func _make_entry(scene: String, fixture: String, offer: bool) -> Dictionary:
    return { "scene": scene, "fixture": fixture, "offer": offer }

## The manifest — add a row here for each capturable scene. When a scene needs
## non-default state, create a <scene>_fixtures.gd next to the scene with a
## static seed_<variant>() method and reference it here. No new autoload needed.
## Use static var (not const) because entries are built by function calls — const
## triggers "not a constant expression" in headless import.
static var manifest: Array[Dictionary] = [
    _make_entry("hub", "", false),
    _make_entry("storage", "seed_storage_state", true),
]

var _shot_dir: String = ""
var _requested_ids: Array[String] = []


func _ready() -> void:
    var args := OS.get_cmdline_args()
    if not _parse_flags(args):
        return
    print("ShotPilot: flags parsed, ids=%s dir=%s" % [_requested_ids, _shot_dir])
    call_deferred("_run")


## Parses --tutorial-shot=<script_id|all> and --shot-dir=<path>.
## Returns false when the capture flag is absent, making the harness inert.
func _parse_flags(args: PackedStringArray) -> bool:
    var shot_flag := ""
    for arg in args:
        if arg.begins_with("--tutorial-shot="):
            shot_flag = arg.trim_prefix("--tutorial-shot=")
        elif arg.begins_with("--shot-dir="):
            _shot_dir = arg.trim_prefix("--shot-dir=")

    if shot_flag.is_empty():
        return false

    if _shot_dir.is_empty():
        _shot_dir = DEFAULT_SHOT_DIR

    if shot_flag == "all":
        _requested_ids = manifest.map(func(e): return e.scene)
    else:
        _requested_ids = [shot_flag]

    return true


## Main loop: init save slot, run each requested script, then exit.
func _run() -> void:
    print("ShotPilot: starting capture for %s" % _requested_ids)
    print("ShotPilot: output dir = %s" % _shot_dir)

    SaveManager.init_slot(1)
    DirAccess.make_dir_recursive_absolute(_shot_dir)

    for script_id in _requested_ids:
        await _capture_script(script_id)

    print("ShotPilot: all captures done")
    get_tree().quit(0)


## Captures all steps for [param script_id] by looking it up in the manifest.
func _capture_script(script_id: String) -> void:
    var entry: Dictionary
    var found := false
    for e in manifest:
        if e.scene == script_id:
            entry = e
            found = true
            break

    if not found:
        ToastManager.show_error("ShotPilot: unknown script id '%s'" % script_id)
        get_tree().quit(1)
        return

    _enter_scene(entry.scene, entry.fixture)
    await _settle()

    # Capture the offer prompt if one is showing (e.g. storage scene).
    if entry.offer and Director.is_offer_showing():
        _snap("%s_offer" % script_id)
        Director.accept_offer()
        await _settle()

    # Select the first storage item so the detail rail is populated.
    if script_id == "storage":
        _select_first_storage_item()
        await _settle()

    # If the script wasn't started by offer accept, force-start now.
    if not Director.is_offer_showing() and script_id != "storage":
        Director.start_script(script_id)
        await _settle()

    var count := Director.step_count()
    for i in count:
        await _settle()
        var idx := Director.step_index()
        if idx != i:
            var anchor_id := Director.step_anchor_id(i)
            print("SKIPPED %s step %d anchor=%s" % [script_id, i, anchor_id])
        _snap("%s_step_%02d" % [script_id, i])
        Director.advance_step()


## Navigates to [param scene_id] and calls the optional fixture.
func _enter_scene(scene_id: String, fixture_name: String) -> void:
    match scene_id:
        "hub":
            SceneRouter.go_to_hub()
        "storage":
            if not fixture_name.is_empty():
                _call_fixture("storage", fixture_name)
            SceneRouter.go_to_storage()
        _:
            ToastManager.show_error("ShotPilot: no route for scene '%s'" % scene_id)
            get_tree().quit(1)


## Loads the fixture script for [param scene_name] and calls the static method
## [param fixture_name].
func _call_fixture(scene_name: String, fixture_name: String) -> void:
    var path := "res://game/meta/%s/%s_fixtures.gd" % [scene_name, scene_name]
    var script := load(path) as GDScript
    if script == null:
        ToastManager.show_error("ShotPilot: fixture script not found at '%s'" % path)
        return
    var callable := Callable(script, fixture_name)
    callable.call()


## Wait for the overlay to settle: scene _ready + register_scene + 2 frames.
func _settle() -> void:
    await get_tree().process_frame
    await get_tree().process_frame
    await get_tree().process_frame


## Captures the current viewport to a PNG file.
func _snap(base_name: String) -> void:
    var img := get_viewport().get_texture().get_image()
    var path := _shot_dir.path_join(base_name + ".png")
    img.save_png(path)
    print("ShotPilot: captured %s" % path)


## Selects the first storage item row so the detail rail is populated.
func _select_first_storage_item() -> void:
    var scene := get_tree().current_scene
    if scene == null:
        return
    var panel := scene.get_node("%ItemListPanel") as ItemListPanel
    if panel == null:
        return
    var items: Array = MetaSystem.storage.storage_items
    if items.is_empty():
        return
    panel.row_pressed.emit(items[0])
