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

## Currently active save slot (1-3). 0 means no slot is loaded (fresh start).
var _active_slot: int = 0


func _ready() -> void:
    pass


## Returns the currently active slot number (1-3), or 0 if none is loaded.
func get_active_slot() -> int:
    return _active_slot


## Registers a save provider. Call before boot_load() runs (i.e. in _ready() of the
## owning autoload). The provider must implement to_dict() -> Dictionary,
## from_dict(Dictionary), and validate() -> bool.
func register_provider(provider: Object) -> void:
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
func flush() -> void:
    if _dirty:
        save()


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
            push_warning("SaveManager: could not delete slot %d counter %d (error %d)" % [slot, counter, err])
    var manifest_path := _slot_manifest_path(slot)
    if FileAccess.file_exists(manifest_path):
        var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(manifest_path))
        if err != OK:
            push_warning("SaveManager: could not delete manifest for slot %d (error %d)" % [slot, err])


## Wipes all slots and the last-active pointer.
func wipe_all() -> void:
    for s: int in range(1, SLOT_COUNT + 1):
        wipe_slot(s)
    var last_active_path := _last_active_path()
    if FileAccess.file_exists(last_active_path):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(last_active_path))


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
func save() -> void:
    if _active_slot <= 0:
        ToastManager.show_dev_error("save() called with no active slot")
        return

    _dirty = false
    _elapsed = 0.0
    _ensure_slot_dir(_active_slot)
    var new_counter := _next_counter_for_slot(_active_slot)

    var sections_out: Dictionary = { }
    for provider: Object in _providers:
        sections_out.merge(provider.to_dict())

    var data := {
        "schema_version": SCHEMA_VERSION,
        "sections": sections_out,
    }

    var path := _slot_counter_path(_active_slot, new_counter)
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        ToastManager.show_error("SaveManager: failed to open %s for writing (error %d)" % [path, FileAccess.get_open_error()])
        return
    file.store_string(JSON.stringify(data))
    file.close()

    var summary := _build_summary(sections_out)
    _write_manifest(_active_slot, new_counter, summary)
    _write_last_active(_active_slot)
    _cleanup_old_saves_in_slot(_active_slot)

# ══ Load ══════════════════════════════════════════════════════════════════════


## Loads from the newest valid counter-based save file in the active slot.
func _load_active_slot() -> void:
    if _active_slot <= 0:
        ToastManager.show_dev_error("_load_active_slot() called with no active slot")
        return

    var candidates := _build_candidate_list_for_slot(_active_slot)
    if candidates.is_empty():
        return

    var highest_counter: int = candidates[0]
    var loaded_counter := -1
    var failed_files: Array[String] = []
    var sections_data: Dictionary = { }

    for counter: int in candidates:
        var path := _slot_counter_path(_active_slot, counter)
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
            func(c: int) -> String: return _slot_counter_path(_active_slot, c)
        )
        ToastManager.show_warning(
            "Loaded save_%d.json (newest file was corrupt). Skipped: %s" % [
                loaded_counter,
                ", ".join(skipped),
            ],
        )

    var summary := _build_summary(sections_data)
    _write_manifest(_active_slot, loaded_counter, summary)

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
    var path := _slot_manifest_path(slot)
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        ToastManager.show_error("SaveManager: failed to write manifest for slot %d (error %d)" % [slot, FileAccess.get_open_error()])
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
    var manifest_counter := _read_manifest_counter(slot)
    var scanned := _scan_save_counters_in_slot(slot)
    if scanned.is_empty():
        return [] as Array[int]
    var ordered: Array[int] = []
    if manifest_counter > 0 and manifest_counter in scanned:
        ordered.append(manifest_counter)
    for c: int in scanned:
        if c not in ordered:
            ordered.append(c)
    return ordered


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
    var counters := _scan_save_counters_in_slot(slot)
    while counters.size() > MAX_SAVES:
        var oldest: int = counters.pop_back()
        var err := DirAccess.remove_absolute(
            ProjectSettings.globalize_path(_slot_counter_path(slot, oldest)),
        )
        if err != OK:
            push_warning("SaveManager: could not delete slot %d save_%d (error %d)" % [slot, oldest, err])
