# storage_session_store.gd
# Storage session runtime store: in-flight state for the storage scene -
# whether a Storage activity is active, the resume target for boot routing,
# and the selected item id for scene restore.
# Owns the fields and their save payload. Fields are read-public via getters.
# Mutation goes through the owning Manager only.
class_name StorageSessionStore
extends SessionStore

const SCENE_STORAGE: String = "storage"

var _active: bool = false
var _resume_target: String = ""
var _selected_entry_id: int = -1

## True when a resumeable Storage session is in flight.
## Read-only externally.
var active: bool:
    get:
        return _active

## Resume scene target. "storage" while active, "" otherwise.
## Read-only externally.
var resume_target: String:
    get:
        return _resume_target

## Saved selected item entry id. -1 when none, or when storage is empty.
## Read-only externally.
var selected_entry_id: int:
    get:
        return _selected_entry_id


## Returns whether the storage session is active.
func is_active() -> bool:
    return _active


## Returns the boot-routing scene target.
func get_resume_target() -> String:
    return _resume_target


## Returns whether [param target] is a supported Storage resume target.
func is_valid_resume_target(target: String) -> bool:
    return target == SCENE_STORAGE


## Section id for the storage_session save payload.
func section_id() -> String:
    return "storage_session"


## Serializes storage-session state to a save payload.
func to_dict() -> Dictionary:
    return {
        "_version": _store_version(),
        "active": _active,
        "resume_target": _resume_target,
        "selected_entry_id": _selected_entry_id,
    }


## Restores storage-session state. Pre-feature saves (no storage_session
## section) load with no migration warning — the defensive reads default to
## inactive. When active but the resume_target is unknown, the session is
## silently cleared so boot routing falls through to hub.
func from_dict(data: Dictionary, _ctx: SaveLoadContext) -> void:
    var version: int = int(data.get("_version", 1))
    data = _apply_migrations(data, version, _ctx)
    _active = bool(data.get("active", false))
    _resume_target = str(data.get("resume_target", ""))
    _selected_entry_id = int(data.get("selected_entry_id", -1))
    if _active and _resume_target != SCENE_STORAGE:
        _active = false
        _resume_target = ""


## Validates session invariants. Inactive sessions are always valid.
func validate() -> bool:
    if not _active:
        return true
    return _resume_target == SCENE_STORAGE and _selected_entry_id >= -1

# ══ Mutators - called only from MetaSystem wrappers ══════════════════════════


## Begins a new Storage session with [param selected_id] as the initially
## selected entry id. Does not save.
func begin(selected_id: int) -> void:
    _active = true
    _resume_target = SCENE_STORAGE
    _selected_entry_id = selected_id


## Updates the selected entry id from an ItemEntry reference. Does not save.
func set_selected_entry(entry: ItemEntry) -> void:
    _selected_entry_id = entry.id if entry != null else -1


## Clears the active session. Does not save.
func clear() -> void:
    _active = false
    _resume_target = ""
    _selected_entry_id = -1


func _store_version() -> int:
    return 1
