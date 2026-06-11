# save_manager.gd
# Persistence coordinator: file IO, schema handling, and registered provider dispatch.
# Holds no gameplay state. Systems that own gameplay state register themselves via
# register_provider() before GameManager calls load(). Each provider implements the
# StoreBase save interface: to_dict(), from_dict(), validate(). Per-store versioned
# migrations run inside each store's from_dict() via _apply_migrations().
#
# Providers may also implement reset() to support the new-game flow; SaveManager
# calls reset() on any provider that defines it when starting a fresh game.
#
# On-disk format: counter-based files user://saves/save_N.json, never overwritten.
# A manifest (user://saves/manifest.json) tracks the latest backup counter as a
# fast-path for load. If the manifest is absent or corrupt, SaveManager scans
# filenames. Up to MAX_SAVES (10) files are retained; older files are best-effort
# deleted.
#
# Save payload per file is unchanged:
#   { "schema_version": int, "sections": { <id>: <payload> } }
# schema_version is always SCHEMA_VERSION (2) on new saves; never checked on load.
extends Node

const SCHEMA_VERSION := 2
const MAX_SAVES := 10
const _SAVE_DIR := "user://saves"
const _MANIFEST_PATH := "user://saves/manifest.json"
const _LEGACY_PATH := "user://save.json"
const _MANIFEST_VERSION := 1

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


func _ready() -> void:
    pass # Providers are registered by owning systems before GameManager runs.


## Registers a save provider. Call before load() runs (i.e. in _ready() of the
## owning autoload). The provider must implement to_dict() -> Dictionary,
## from_dict(Dictionary), and validate() -> bool.
func register_provider(provider: Object) -> void:
    assert(provider.has_method("to_dict"), "register_provider: %s missing to_dict()" % provider)
    assert(provider.has_method("from_dict"), "register_provider: %s missing from_dict()" % provider)
    assert(provider.has_method("validate"), "register_provider: %s missing validate()" % provider)
    _providers.append(provider)


## Accumulates delta when dirty and flushes once the throttle interval elapses.
## Zero cost when clean.
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
## Only resets _elapsed on the clean→dirty transition — subsequent calls while
## already dirty are no-ops on the timer (true throttle: fires at most once per
## THROTTLE_SEC after the first mutation in a burst).
func mark_dirty() -> void:
    if not _dirty:
        _dirty = true
        _elapsed = 0.0


## Iterates registered providers and calls reset() on any that implement it.
## Used by the new-game flow to restore every persistent store to its default
## state. Providers that do not define reset() are left untouched.
func reset_providers() -> void:
    for provider: Object in _providers:
        if provider.has_method("reset"):
            provider.reset()


## Deletes all counter-based save files and the manifest from disk. Used by the
## new-game flow before resetting providers and writing a fresh save.
func wipe_all() -> void:
    for counter: int in _scan_save_counters():
        var err := DirAccess.remove_absolute(
            ProjectSettings.globalize_path(_counter_path(counter)),
        )
        if err != OK:
            push_warning("SaveManager: could not delete %s (error %d)" % [_counter_path(counter), err])
    if FileAccess.file_exists(_MANIFEST_PATH):
        var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(_MANIFEST_PATH))
        if err != OK:
            push_warning("SaveManager: could not delete manifest (error %d)" % err)


## Catches OS quit (Alt-F4 / window close) and flushes any pending deferred
## state before the engine shuts down.
func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        flush()


## Calls validate() on every registered provider, accumulates failures, and
## returns true only if every provider passed.
func run_validation() -> bool:
    var ok := true
    for provider: Object in _providers:
        if not provider.validate():
            ok = false
    return ok


## Returns true when at least one counter-based save file exists, or the legacy
## save.json exists. Use this instead of checking file paths directly.
func has_save() -> bool:
    if FileAccess.file_exists(_LEGACY_PATH):
        return true
    return not _scan_save_counters().is_empty()

# ══ Save ══════════════════════════════════════════════════════════════════════


## Writes a new counter-based save file, updates the manifest, and best-effort
## cleans up files beyond MAX_SAVES. Never modifies or deletes any existing
## save file during the write — a crash during write leaves the manifest
## pointing to the previous good file.
## Clears dirty state on entry so a concurrent deferred flush is suppressed
## after a transaction save.
func save() -> void:
    _dirty = false
    _elapsed = 0.0
    _ensure_save_dir()
    var new_counter := _next_counter()

    var sections_out: Dictionary = { }
    for provider: Object in _providers:
        sections_out.merge(provider.to_dict())

    var data := {
        "schema_version": SCHEMA_VERSION,
        "sections": sections_out,
    }

    var path := _counter_path(new_counter)
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        push_error("SaveManager: failed to open %s for writing (error %d)" % [path, FileAccess.get_open_error()])
        return
    file.store_string(JSON.stringify(data))
    file.close()

    _write_manifest(new_counter)
    _cleanup_old_saves()

# ══ Load ══════════════════════════════════════════════════════════════════════


## Loads from the newest valid counter-based save file. Falls back through
## candidates newest-first. If no counter-based file exists but the legacy
## user://save.json does, migrates it first. Toasts a warning on fallback or
## total failure. Toasts migration info when Debug.enabled.
func load() -> void:
    # One-time legacy migration.
    if _should_migrate_legacy():
        _migrate_legacy()

    var candidates := _build_candidate_list()
    if candidates.is_empty():
        return # Fresh game — no save file exists.

    var highest_counter: int = candidates[0]
    var loaded_counter := -1
    var failed_files: Array[String] = []

    for counter: int in candidates:
        var path := _counter_path(counter)
        var result := _try_load_file(path)
        if result == null:
            failed_files.append(path)
            continue
        # Valid file found — dispatch to providers.
        var sections_data: Dictionary = result["sections"].duplicate(true)
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
        # No file survived validation.
        ToastManager.show_warning(
            "Save data could not be read. Starting fresh.\n(%s)" % ", ".join(failed_files),
        )
        return

    # Warn if we fell back past the most recent file.
    if loaded_counter != highest_counter:
        var skipped := range(loaded_counter + 1, highest_counter + 1).map(
            func(c: int) -> String: return _counter_path(c)
        )
        ToastManager.show_warning(
            "Loaded save_%d.json (newest file was corrupt). Skipped: %s" % [
                loaded_counter,
                ", ".join(skipped),
            ],
        )

    # Correct manifest drift — point to the file actually loaded.
    _write_manifest(loaded_counter)

# ══ Private helpers ═══════════════════════════════════════════════════════════


## Creates user://saves/ if it does not yet exist. Call before any file write.
func _ensure_save_dir() -> void:
    if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_SAVE_DIR)):
        DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_SAVE_DIR))


## Returns the save path for [param counter].
func _counter_path(counter: int) -> String:
    return "%s/save_%d.json" % [_SAVE_DIR, counter]


## Reads the manifest and returns the stored current_backup counter, or -1 on
## failure. Accepts the legacy "current_slot" field name as a fallback so
## manifests written by the previous build remain readable without migration.
func _read_manifest_counter() -> int:
    if not FileAccess.file_exists(_MANIFEST_PATH):
        return -1
    var file := FileAccess.open(_MANIFEST_PATH, FileAccess.READ)
    if file == null:
        return -1
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    file.close()
    if parsed == null or not parsed is Dictionary:
        return -1
    var counter: Variant = parsed.get("current_backup", -1)
    if counter is int and counter >= 1:
        return counter
    # Fallback to the legacy field name.
    var legacy: Variant = parsed.get("current_slot", -1)
    if legacy is int and legacy >= 1:
        return legacy
    return -1


## Writes the manifest with [param counter] as current_backup.
func _write_manifest(counter: int) -> void:
    var file := FileAccess.open(_MANIFEST_PATH, FileAccess.WRITE)
    if file == null:
        push_error("SaveManager: failed to write manifest (error %d)" % FileAccess.get_open_error())
        return
    file.store_string(JSON.stringify({ "current_backup": counter, "version": _MANIFEST_VERSION }))
    file.close()


## Scans user://saves/ for save_N.json files and returns their counters sorted
## descending. Returns an empty array when none exist.
func _scan_save_counters() -> Array[int]:
    var dir := DirAccess.open(_SAVE_DIR)
    if dir == null:
        return [] as Array[int]
    var counters: Array[int] = []
    dir.list_dir_begin()
    var fname := dir.get_next()
    while fname != "":
        if fname.begins_with("save_") and fname.ends_with(".json"):
            var stem := fname.trim_prefix("save_").trim_suffix(".json")
            if stem.is_valid_int():
                counters.append(stem.to_int())
        fname = dir.get_next()
    dir.list_dir_end()
    counters.sort()
    counters.reverse()
    return counters


## Determines the counter to use for the next save.
## Reads manifest first; falls back to filename scan.
func _next_counter() -> int:
    var counter := _read_manifest_counter()
    if counter > 0:
        return counter + 1
    var existing := _scan_save_counters()
    if existing.is_empty():
        return 1
    return existing[0] + 1


## Builds the ordered candidate list for load (newest-first).
## Starts with the manifest's counter if valid, then includes all scanned files.
func _build_candidate_list() -> Array[int]:
    var manifest_counter := _read_manifest_counter()
    var scanned := _scan_save_counters()
    if scanned.is_empty():
        return [] as Array[int]
    # Ensure manifest counter is first, then remaining by descending counter.
    var ordered: Array[int] = []
    if manifest_counter > 0 and manifest_counter in scanned:
        ordered.append(manifest_counter)
    for c: int in scanned:
        if c not in ordered:
            ordered.append(c)
    return ordered


## Tries to parse and structurally validate [param path].
## Returns the parsed Dictionary on success, null on any failure.
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


## Deletes the oldest save files when total count exceeds MAX_SAVES.
## Best-effort — deletion failures are non-fatal.
func _cleanup_old_saves() -> void:
    var counters := _scan_save_counters()
    while counters.size() > MAX_SAVES:
        var oldest: int = counters.pop_back()
        var err := DirAccess.remove_absolute(
            ProjectSettings.globalize_path(_counter_path(oldest)),
        )
        if err != OK:
            push_warning("SaveManager: could not delete %s (error %d)" % [_counter_path(oldest), err])


## Returns true when legacy migration should run: no save_*.json exists but
## user://save.json does.
func _should_migrate_legacy() -> bool:
    var scanned := _scan_save_counters()
    return scanned.is_empty() and FileAccess.file_exists(_LEGACY_PATH)


## Reads user://save.json, writes it as save_1.json via the normal write path,
## updates the manifest, then best-effort deletes save.json.
func _migrate_legacy() -> void:
    _ensure_save_dir()
    var file := FileAccess.open(_LEGACY_PATH, FileAccess.READ)
    if file == null:
        push_error("SaveManager: could not open legacy save for migration")
        return
    var text := file.get_as_text()
    file.close()

    var target := _counter_path(1)
    var out := FileAccess.open(target, FileAccess.WRITE)
    if out == null:
        push_error("SaveManager: could not write legacy migration to %s" % target)
        return
    out.store_string(text)
    out.close()

    _write_manifest(1)

    # Best-effort delete the old file.
    var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(_LEGACY_PATH))
    if err != OK:
        push_warning("SaveManager: could not delete legacy save.json (error %d)" % err)
