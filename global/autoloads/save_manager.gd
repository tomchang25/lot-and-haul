# save_manager.gd
# Persistence coordinator: file IO, schema handling, and registered provider dispatch.
# Holds no gameplay state. Systems that own gameplay state register themselves via
# register_provider() before GameManager calls boot_load(). Each provider implements the
# StoreBase save interface: to_dict(), from_dict(), validate(). Per-store versioned
# migrations run inside each store's from_dict() via _apply_migrations().
#
# Providers may also implement reset() to support the new-game flow; SaveManager
# calls reset() on any provider that defines it when starting a fresh game.
#
# Save slots: three independent player-facing save slots (1-3), each with its own
# counter-based backup rotation and manifest at:
#   user://save_slots/slot_N/save_C.json
#   user://save_slots/slot_N/manifest.json
# A top-level pointer tracks the last-active slot:
#   user://save_slots/last_active
extends Node

const SCHEMA_VERSION := 2
const MAX_SAVES := 10
const SLOT_COUNT := 3
const _SLOT_BASE_DIR := "user://save_slots"
const _MANIFEST_VERSION := 2

## Path for the disposable testbed slot. Non-numeric so it is never picked up
## by boot_load() or the numbered-slot listing. Wiped at every testbed launch.
const TEST_SLOT_DIR := "user://save_slots/slot_test"

## Deferred-save throttle interval in seconds. The first mark_dirty() starts
## the clock; a flush fires once _elapsed >= THROTTLE_SEC. Tunable.
const THROTTLE_SEC: float = 5.0

## Registered providers, in registration order. Each must implement to_dict(),
## from_dict(), and validate(). to_dict() returns a flat multi-key dict (all
## section keys merged into sections_out); from_dict() receives the full sections
## dict and reads only its own keys.
var _providers: Array = []

## True when at least one store has been mutated since the last disk write.
var _dirty: bool = false

## Seconds since _dirty was first set on the current cycle.
var _elapsed: float = 0.0

## Currently active save slot (1-3). 0 means no slot is loaded (fresh start)
## OR the test slot is active (disambiguated by _active_slot_dir being non-empty).
var _active_slot: int = 0

## When non-empty, overrides the active slot directory for all save/load operations.
## Set by use_test_slot(). Normal numbered-slot helpers (boot_load, get_slot_summaries,
## has_any_save) never touch this path because they only iterate slots 1..SLOT_COUNT.
var _active_slot_dir: String = ""


func _ready() -> void:
    pass


## Returns the currently active slot number (1-3), or 0 if none is loaded.
func get_active_slot() -> int:
    return _active_slot


## Registers a save provider. Call before boot_load() runs (i.e. in _ready() of the
## owning autoload). The provider must implement to_dict() -> Dictionary,
## from_dict(Dictionary), and validate() -> bool.
func register_provider(provider: Object) -> void:
    if provider in _providers:
        ToastManager.show_info("register_provider: %s already registered" % provider)
        return

    if not provider.has_method("to_dict"):
        ToastManager.show_dev_error("register_provider: %s missing to_dict()" % provider)
        return

    if not provider.has_method("from_dict"):
        ToastManager.show_dev_error("register_provider: %s missing from_dict()" % provider)
        return

    if not provider.has_method("validate"):
        ToastManager.show_dev_error("register_provider: %s missing validate()" % provider)
        return

    _providers.append(provider)


func _process(delta: float) -> void:
    if not _dirty:
        return
    _elapsed += delta
    if _elapsed >= THROTTLE_SEC:
        flush()


## Flushes pending deferred state to disk if dirty. Idempotent when clean.
## Returns true when the flush completed or was already clean; false when
## the underlying save failed.
func flush() -> bool:
    if _dirty:
        return save()
    return true


## Marks the save state as dirty and starts the throttle clock.
func mark_dirty() -> void:
    if not _dirty:
        _dirty = true
        _elapsed = 0.0


## Calls reset() on every registered provider that implements it.
## Used to restore all persistent stores to their default state.
func reset_providers() -> void:
    for provider: Object in _providers:
        if provider.has_method("reset"):
            provider.reset()
    EventBus.save_runtime_reset.emit()


## Returns true when at least one save slot holds data.
func has_any_save() -> bool:
    for s: int in range(1, SLOT_COUNT + 1):
        if has_slot_data(s):
            return true
    return false


## Returns true when [param slot] has at least one save file.
func has_slot_data(slot: int) -> bool:
    return not _scan_save_counters_in_slot(slot).is_empty()


## Returns an Array of SLOT_COUNT elements (index 0 = slot 1).
## Each element is null (empty slot) or a Dictionary with "day", "cash",
## and "last_played" keys. Falls back to parsing the newest save file
## when the manifest has no summary block (pre-summary format).
func get_slot_summaries() -> Array:
    var result: Array = []
    result.resize(SLOT_COUNT)
    for s: int in range(1, SLOT_COUNT + 1):
        result[s - 1] = _read_slot_summary(s)
    return result


## Returns the slot number (1-3) that has the newest save file, or 0 if none.
func _find_newest_slot() -> int:
    var newest_slot: int = 0
    var newest_counter: int = -1
    for s: int in range(1, SLOT_COUNT + 1):
        var counters := _scan_save_counters_in_slot(s)
        if counters.is_empty():
            continue
        if counters[0] > newest_counter:
            newest_counter = counters[0]
            newest_slot = s
    return newest_slot


## Reads the summary for [param slot] from its manifest, falling back to
## parsing the latest save file. Returns null when the slot is empty.
func _read_slot_summary(slot: int) -> Variant:
    var counters := _scan_save_counters_in_slot(slot)
    if counters.is_empty():
        return null

    # Try manifest summary first.
    var manifest_data := _read_manifest_full(slot)
    if manifest_data != null and manifest_data.has("summary"):
        return manifest_data["summary"].duplicate()

    # Fallback: parse the newest save file directly.
    var path := _slot_counter_path(slot, counters[0])
    var parsed := _try_load_file(path)
    if parsed == null:
        return null
    var sections: Dictionary = parsed.get("sections", { })
    return {
        "day": sections.get("progress", { }).get("current_day", 0),
        "cash": sections.get("economy", { }).get("cash", 0),
        "last_played": "",
    }


## Boot entry point: loads the last-active slot. Falls back to the newest slot
## if the pointer is stale. Fresh start (no data anywhere) leaves _active_slot at 0.
func boot_load() -> void:
    var last_active := _read_last_active()
    if last_active > 0 and has_slot_data(last_active):
        _active_slot = last_active
        _load_active_slot()
        return

    # Fallback: find the slot with the newest save.
    var newest := _find_newest_slot()
    if newest > 0:
        _active_slot = newest
        _write_last_active(newest)
        _load_active_slot()
        return

    # Fresh start — no save data exists.
    _active_slot = 0


## Switches the active slot: flushes pending state, resets all providers to
## defaults, then loads [param slot]'s save data and sets the last-active pointer.
## Used by Load Game in the slot picker.
func switch_to_slot(slot: int) -> void:
    if slot < 1 or slot > SLOT_COUNT:
        ToastManager.show_dev_error("switch_to_slot: invalid slot %d" % slot)
        return

    flush()
    reset_providers()
    _active_slot_dir = "" # exit test slot mode if active
    _active_slot = slot
    _load_active_slot()
    _write_last_active(slot)


## Initializes a slot for a new game: wipes any existing save files in the slot,
## resets all providers to defaults, saves a fresh state, and sets the last-active
## pointer. Used by New Game in the slot picker.
func init_slot(slot: int) -> void:
    if slot < 1 or slot > SLOT_COUNT:
        ToastManager.show_dev_error("init_slot: invalid slot %d" % slot)
        return

    _active_slot_dir = "" # exit test slot mode if active
    wipe_slot(slot)
    reset_providers()
    _active_slot = slot
    save()


## Deletes all save files and manifest for a single [param slot].
func wipe_slot(slot: int) -> void:
    for counter: int in _scan_save_counters_in_slot(slot):
        var err := DirAccess.remove_absolute(
            ProjectSettings.globalize_path(_slot_counter_path(slot, counter)),
        )
        if err != OK:
            ToastManager.show_warning("SaveManager: could not delete slot %d counter %d (error %d)" % [slot, counter, err])
    var manifest_path := _slot_manifest_path(slot)
    if FileAccess.file_exists(manifest_path):
        var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(manifest_path))
        if err != OK:
            ToastManager.show_warning("SaveManager: could not delete manifest for slot %d (error %d)" % [slot, err])


## Wipes all slots and the last-active pointer.
func wipe_all() -> void:
    for s: int in range(1, SLOT_COUNT + 1):
        wipe_slot(s)
    var last_active_path := _last_active_path()
    if FileAccess.file_exists(last_active_path):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(last_active_path))


## Activates the disposable test slot: wipes its directory, redirects all
## subsequent save/load operations to TEST_SLOT_DIR, and resets all providers
## to their default state so fixtures can seed on top of a clean baseline.
## The test slot is never written to the last-active pointer, so a normal boot
## or crash cannot land in test data.
## Debug-only — call only from testbed entry points.
func use_test_slot() -> void:
    _wipe_dir(TEST_SLOT_DIR)
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_SLOT_DIR))
    _active_slot = 0
    _active_slot_dir = TEST_SLOT_DIR
    reset_providers()


## Deletes every file (non-recursively) inside [param dir_path].
## Safe to call when the directory does not exist.
func _wipe_dir(dir_path: String) -> void:
    var abs_path := ProjectSettings.globalize_path(dir_path)
    if not DirAccess.dir_exists_absolute(abs_path):
        return
    var d := DirAccess.open(dir_path)
    if d == null:
        return
    d.list_dir_begin()
    var fname := d.get_next()
    while fname != "":
        if not d.current_is_dir():
            DirAccess.remove_absolute(abs_path.path_join(fname))
        fname = d.get_next()
    d.list_dir_end()


## Catches OS quit and flushes deferred state.
func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        flush()


## Calls validate() on every registered provider.
func run_validation() -> bool:
    var ok := true
    for provider: Object in _providers:
        if not provider.validate():
            ok = false
    return ok

# ══ Save ══════════════════════════════════════════════════════════════════════


## Writes a new counter-based save file to the active slot, updates the manifest
## with a summary block, writes the last-active pointer, and cleans up old files.
## When the test slot is active (_active_slot_dir non-empty), writes to that dir
## and skips the last-active pointer so normal boot never lands in test data.
## Returns true when the save completed successfully; false on failure.
func save() -> bool:
    var is_test_slot := not _active_slot_dir.is_empty()
    if _active_slot <= 0 and not is_test_slot:
        ToastManager.show_dev_error("save() called with no active slot")
        return false

    _dirty = false
    _elapsed = 0.0
    var dir := _active_slot_dir if is_test_slot else _slot_dir(_active_slot)
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
    var new_counter := _next_counter_in_dir(dir)

    var sections_out: Dictionary = { }
    for provider: Object in _providers:
        sections_out.merge(provider.to_dict())

    var data := {
        "schema_version": SCHEMA_VERSION,
        "sections": sections_out,
    }

    var path := dir.path_join("save_%d.json" % new_counter)
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        ToastManager.show_error("SaveManager: failed to open %s for writing (error %d)" % [path, FileAccess.get_open_error()])
        return false
    file.store_string(JSON.stringify(data))
    file.close()

    var summary := _build_summary(sections_out)
    _write_manifest_to_dir(dir, new_counter, summary)
    if not is_test_slot:
        _write_last_active(_active_slot)
    _cleanup_old_saves_in_dir(dir)
    return true

# ══ Load ══════════════════════════════════════════════════════════════════════


## Loads from the newest valid counter-based save file in the active slot.
func _load_active_slot() -> void:
    var is_test_slot := not _active_slot_dir.is_empty()
    if _active_slot <= 0 and not is_test_slot:
        ToastManager.show_dev_error("_load_active_slot() called with no active slot")
        return

    var dir := _active_slot_dir if is_test_slot else _slot_dir(_active_slot)
    var candidates := _build_candidate_list_in_dir(dir)
    if candidates.is_empty():
        return

    var highest_counter: int = candidates[0]
    var loaded_counter := -1
    var failed_files: Array[String] = []
    var sections_data: Dictionary = { }

    for counter: int in candidates:
        var path := dir.path_join("save_%d.json" % counter)
        var result := _try_load_file(path)
        if result == null:
            failed_files.append(path)
            continue
        sections_data = result["sections"].duplicate(true)
        var ctx := SaveLoadContext.new()
        for provider: Object in _providers:
            provider.from_dict(sections_data, ctx)
        for w: String in ctx.warnings:
            ToastManager.show_warning(w)
        for i: String in ctx.infos:
            ToastManager.show_info(i)
        loaded_counter = counter
        break

    if loaded_counter == -1:
        ToastManager.show_warning(
            "Save data could not be read. Starting fresh.\n(%s)" % ", ".join(failed_files),
        )
        return

    if loaded_counter != highest_counter:
        var skipped := range(loaded_counter + 1, highest_counter + 1).map(
            func(c: int) -> String: return dir.path_join("save_%d.json" % c)
        )
        ToastManager.show_warning(
            "Loaded save_%d.json (newest file was corrupt). Skipped: %s" % [
                loaded_counter,
                ", ".join(skipped),
            ],
        )

    var summary := _build_summary(sections_data)
    _write_manifest_to_dir(dir, loaded_counter, summary)

# ══ Private helpers ═══════════════════════════════════════════════════════════


func _slot_dir(slot: int) -> String:
    return "%s/slot_%d" % [_SLOT_BASE_DIR, slot]


func _slot_manifest_path(slot: int) -> String:
    return "%s/manifest.json" % _slot_dir(slot)


func _slot_counter_path(slot: int, counter: int) -> String:
    return "%s/save_%d.json" % [_slot_dir(slot), counter]


func _last_active_path() -> String:
    return "%s/last_active" % [_SLOT_BASE_DIR]


func _ensure_slot_base_dir() -> void:
    if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_SLOT_BASE_DIR)):
        DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_SLOT_BASE_DIR))


func _ensure_slot_dir(slot: int) -> void:
    var dir := _slot_dir(slot)
    if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir)):
        DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))


## Reads the full manifest for a slot. Returns null on failure.
func _read_manifest_full(slot: int) -> Variant:
    var path := _slot_manifest_path(slot)
    if not FileAccess.file_exists(path):
        return null
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return null
    var text := file.get_as_text()
    file.close()
    var parsed: Variant = JSON.parse_string(text)
    if parsed == null or not parsed is Dictionary:
        return null
    return parsed


## Reads the current_backup counter from a slot manifest. Returns -1 on failure.
func _read_manifest_counter(slot: int) -> int:
    var data := _read_manifest_full(slot)
    if data == null:
        return -1
    var counter: Variant = data.get("current_backup", -1)
    if counter is int and counter >= 1:
        return counter
    return -1


## Writes the manifest for [param slot] with [param counter] and [param summary].
func _write_manifest(slot: int, counter: int, summary: Dictionary = { }) -> void:
    _write_manifest_to_dir(_slot_dir(slot), counter, summary)


## Writes the manifest to an arbitrary [param dir] (used for both numbered slots
## and the test slot path).
func _write_manifest_to_dir(dir: String, counter: int, summary: Dictionary = { }) -> void:
    var path := dir.path_join("manifest.json")
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        ToastManager.show_error("SaveManager: failed to write manifest at %s (error %d)" % [path, FileAccess.get_open_error()])
        return
    var data: Dictionary = {
        "current_backup": counter,
        "version": _MANIFEST_VERSION,
    }
    if not summary.is_empty():
        data["summary"] = summary
    file.store_string(JSON.stringify(data))
    file.close()


## Reads the last-active slot pointer. Returns the slot number (1-3) or 0 when
## missing or invalid.
func _read_last_active() -> int:
    var path := _last_active_path()
    if not FileAccess.file_exists(path):
        return 0
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return 0
    var text := file.get_as_text()
    file.close()
    var parsed: Variant = JSON.parse_string(text)
    if parsed == null or not parsed is Dictionary:
        return 0
    var slot: Variant = parsed.get("last_active", 0)
    if slot is int and slot >= 1 and slot <= SLOT_COUNT:
        return slot
    return 0


## Writes the last-active slot pointer.
func _write_last_active(slot: int) -> void:
    _ensure_slot_base_dir()
    var file := FileAccess.open(_last_active_path(), FileAccess.WRITE)
    if file == null:
        ToastManager.show_error("SaveManager: failed to write last_active (error %d)" % FileAccess.get_open_error())
        return
    file.store_string(JSON.stringify({ "last_active": slot }))
    file.close()


## Builds a summary dict from provider section data for the manifest.
func _build_summary(sections: Dictionary) -> Dictionary:
    return {
        "day": sections.get("progress", { }).get("current_day", 0),
        "cash": sections.get("economy", { }).get("cash", 0),
        "last_played": Time.get_datetime_string_from_system(),
    }


## Scans [param dir] for save_N.json files and returns counters sorted descending.
func _scan_save_counters_in_dir(dir: String) -> Array[int]:
    var d := DirAccess.open(dir)
    if d == null:
        return [] as Array[int]
    var counters: Array[int] = []
    d.list_dir_begin()
    var fname := d.get_next()
    while fname != "":
        if fname.begins_with("save_") and fname.ends_with(".json"):
            var stem := fname.trim_prefix("save_").trim_suffix(".json")
            if stem.is_valid_int():
                counters.append(stem.to_int())
        fname = d.get_next()
    d.list_dir_end()
    counters.sort()
    counters.reverse()
    return counters


## Scans [param slot] for save_N.json files and returns counters sorted descending.
func _scan_save_counters_in_slot(slot: int) -> Array[int]:
    return _scan_save_counters_in_dir(_slot_dir(slot))


## Determines the next counter for a new save in [param slot].
func _next_counter_for_slot(slot: int) -> int:
    var counter := _read_manifest_counter(slot)
    if counter > 0:
        return counter + 1
    var existing := _scan_save_counters_in_slot(slot)
    if existing.is_empty():
        return 1
    return existing[0] + 1


## Builds the ordered candidate list for slot loading (newest-first) in a slot.
func _build_candidate_list_for_slot(slot: int) -> Array[int]:
    return _build_candidate_list_in_dir(_slot_dir(slot))


## Builds the ordered candidate list for loading from an arbitrary [param dir].
## Manifest pointer is tried first; remaining counters appended in descending order.
func _build_candidate_list_in_dir(dir: String) -> Array[int]:
    var manifest_counter := _read_manifest_counter_in_dir(dir)
    var scanned := _scan_save_counters_in_dir(dir)
    if scanned.is_empty():
        return [] as Array[int]
    var ordered: Array[int] = []
    if manifest_counter > 0 and manifest_counter in scanned:
        ordered.append(manifest_counter)
    for c: int in scanned:
        if c not in ordered:
            ordered.append(c)
    return ordered


## Reads the current_backup counter from the manifest in [param dir]. Returns -1 on failure.
func _read_manifest_counter_in_dir(dir: String) -> int:
    var path := dir.path_join("manifest.json")
    if not FileAccess.file_exists(path):
        return -1
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return -1
    var text := file.get_as_text()
    file.close()
    var parsed: Variant = JSON.parse_string(text)
    if parsed == null or not parsed is Dictionary:
        return -1
    var counter: Variant = parsed.get("current_backup", -1)
    if counter is int and counter >= 1:
        return counter
    return -1


## Determines the next counter for a new save in [param dir].
func _next_counter_in_dir(dir: String) -> int:
    var counter := _read_manifest_counter_in_dir(dir)
    if counter > 0:
        return counter + 1
    var existing := _scan_save_counters_in_dir(dir)
    if existing.is_empty():
        return 1
    return existing[0] + 1


## Deletes the oldest save files in [param dir] when total count exceeds MAX_SAVES.
func _cleanup_old_saves_in_dir(dir: String) -> void:
    var counters := _scan_save_counters_in_dir(dir)
    var abs_path := ProjectSettings.globalize_path(dir)
    while counters.size() > MAX_SAVES:
        var oldest: int = counters.pop_back()
        var err := DirAccess.remove_absolute(abs_path.path_join("save_%d.json" % oldest))
        if err != OK:
            ToastManager.show_warning("SaveManager: could not delete %s/save_%d.json (error %d)" % [dir, oldest, err])


## Tries to parse and structurally validate [param path].
func _try_load_file(path: String) -> Variant:
    if not FileAccess.file_exists(path):
        return null
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return null
    var text := file.get_as_text()
    file.close()
    var parsed: Variant = JSON.parse_string(text)
    if parsed == null or not parsed is Dictionary:
        return null
    if not (parsed.has("sections") and parsed["sections"] is Dictionary):
        return null
    return parsed


## Deletes the oldest save files in a slot when total count exceeds MAX_SAVES.
func _cleanup_old_saves_in_slot(slot: int) -> void:
    _cleanup_old_saves_in_dir(_slot_dir(slot))
