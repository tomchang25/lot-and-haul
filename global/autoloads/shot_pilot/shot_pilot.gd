# shot_pilot.gd
# Tutorial screenshot harness — captures one PNG per tutorial step for visual
# review. Activates only when --tutorial-shot=<script_id|all> is present on
# the command line. Completely inert without the flag, even in release exports.
extends Node

const DEFAULT_SHOT_DIR: String = "user://tutorial_shots"

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
        _requested_ids = ["hub", "storage"]
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


## Captures all steps for [param script_id].
func _capture_script(script_id: String) -> void:
    match script_id:
        "hub":
            SceneRouter.go_to_hub()
        "storage":
            _seed_storage_state()
            SceneRouter.go_to_storage()
        _:
            ToastManager.show_error("ShotPilot: unknown script id '%s'" % script_id)
            get_tree().quit(1)
            return

    await _settle()

    # Capture the offer prompt if one is showing (storage scene).
    if Director.debug_is_offer_showing():
        _snap("%s_offer" % script_id)
        Director.debug_accept_offer()
        await _settle()

    # For storage, select the first item so the detail rail is populated.
    if script_id == "storage":
        _select_first_storage_item()
        await _settle()

    # If the script wasn't started by offer accept, force-start now.
    if not Director.debug_is_offer_showing() and script_id != "storage":
        # Hub script auto-starts in _on_hub_registered, but we restart
        # cleanly for deterministic capture.
        Director.start_script(script_id)
        await _settle()

    var count := Director.debug_step_count()
    for i in count:
        await _settle()
        var idx := Director.debug_step_index()
        if idx != i:
            var anchor_id := Director.debug_step_anchor_id(i)
            print("SKIPPED %s step %d anchor=%s" % [script_id, i, anchor_id])
        _snap("%s_step_%02d" % [script_id, i])
        Director.debug_advance_step()


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


## Seeds the storage store with items so all tutorial anchors resolve.
##
## Creates three ItemEntry instances from registry data, marks the first as
## repair-complete (condition = 0.5) so the restore button is visible, and
## sets up AP via begin_storage_slot().
func _seed_storage_state() -> void:
    var anchors := AnchorRegistry.get_all_anchors()
    if anchors.is_empty():
        ToastManager.show_error("ShotPilot: AnchorRegistry is empty — cannot seed storage")
        return

    var rng := RandomNumberGenerator.new()
    rng.seed = 42

    var count := mini(3, anchors.size())
    var entries: Array[ItemEntry] = []

    for i in count:
        var anchor: AnchorData = anchors[i]
        var surface_clues := _sample_clues(ClueData.ClueType.SURFACE, 2, rng)
        var hidden_clues := _sample_clues(ClueData.ClueType.HIDDEN, 1, rng)
        var entry := ItemEntry.from_generation(anchor, surface_clues, hidden_clues, anchor.category_data, rng)
        entry.unveiled = true
        entry.auto_reveal_all_surface()
        entries.append(entry)

    if not entries.is_empty():
        # First item: repair complete so the restore button is visible.
        entries[0].condition = 0.5

    MetaManager.register_storage_items(entries)
    MetaManager.begin_storage_slot()


## Returns up to [param max_count] clues of the given [param clue_type].
func _sample_clues(clue_type: ClueData.ClueType, max_count: int, rng: RandomNumberGenerator) -> Array[ClueData]:
    var pool: Array[ClueData] = []
    for clue: ClueData in ClueRegistry.get_all_clues():
        if clue.type == clue_type:
            pool.append(clue)
    pool.sort_custom(func(_a, _b): return rng.randf() < 0.5)
    var n := mini(max_count, pool.size())
    var result: Array[ClueData] = []
    for j in n:
        result.append(pool[j])
    return result


## Selects the first storage item row so the detail rail is populated.
func _select_first_storage_item() -> void:
    var scene := get_tree().current_scene
    if scene == null:
        return
    var panel := scene.get_node("%ItemListPanel") as ItemListPanel
    if panel == null:
        return
    var items: Array = MetaManager.storage.storage_items
    if items.is_empty():
        return
    panel.row_pressed.emit(items[0])
