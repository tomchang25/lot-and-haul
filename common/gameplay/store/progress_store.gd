# progress_store.gd
# Progress runtime store: calendar day, sampled available locations, and
# tutorial-seen flags.
# Serializable state slice held by MetaManager. Owns the fields, their save
# payload, and the operations that mutate them.
#
# Fields are read-public via getters. Mutation goes through the owning Manager only.
class_name ProgressStore
extends StoreBase

var _current_day: int = 0
var _available_locations: Array[LocationData] = []
var _tutorial_seen: Dictionary = { }
var _onboarding_pending: bool = true

## Calendar day counter. Starts at 0, incremented by end_day(). Read-only externally.
var current_day: int:
    get:
        return _current_day

## Shallow duplicate of the available-locations list (LocationData refs shared).
## Read-only externally. Returns a duplicate for iteration stability.
var available_locations: Array[LocationData]:
    get:
        return _available_locations.duplicate()

## Tutorial-seen flags, scene_id -> bool. Read-only externally.
var tutorial_seen: Dictionary:
    get:
        return _tutorial_seen.duplicate()

## Onboarding pending flag. Read-only externally. Starts true for new games
## existing saves from before the onboarding feature are migrated to false.
var onboarding_pending: bool:
    get:
        return _onboarding_pending


## Marks onboarding as done (completed or skipped). Does not save.
func mark_onboarding_complete() -> void:
    _onboarding_pending = false


## Resets onboarding to pending. Test-helper — not used in production.
func reset_onboarding() -> void:
    _onboarding_pending = true


## Increments current_day by one. Does not save.
func advance_day() -> void:
    _current_day += 1


## Replaces available_locations with [param locations]. Does not save.
func set_locations(locations: Array[LocationData]) -> void:
    _available_locations = locations


## Clears available_locations. Does not save.
func clear_locations() -> void:
    _available_locations.clear()


## Marks a scene tutorial as seen. Does not save.
func mark_tutorial_seen(scene_id: String) -> void:
    _tutorial_seen[scene_id] = true


## Section id for the progress save payload.
func section_id() -> String:
    return "progress"


## Returns current schema version. Version 2 adds tutorial_seen flags.
## Version 3 adds onboarding_pending flag.
func _store_version() -> int:
    return 3


## Serializes progress state to a save payload.
func to_dict() -> Dictionary:
    var available_location_ids: Array[String] = []
    for loc: LocationData in _available_locations:
        available_location_ids.append(loc.location_id)
    return {
        "_version": _store_version(),
        "current_day": _current_day,
        "available_location_ids": available_location_ids,
        "tutorial_seen": _tutorial_seen.duplicate(),
        "onboarding_pending": _onboarding_pending,
    }


## Restores progress state. Unresolved location ids are dropped with a warning.
func from_dict(data: Dictionary, ctx: SaveLoadContext) -> void:
    var version: int = int(data.get("_version", 1))
    data = _apply_migrations(data, version, ctx)
    _current_day = int(data.get("current_day", _current_day))
    if data.has("available_location_ids") and data["available_location_ids"] is Array:
        _available_locations = []
        for id_variant: Variant in data["available_location_ids"]:
            if not id_variant is String:
                continue
            var loc: LocationData = LocationRegistry.get_location_by_id(id_variant as String)
            if loc == null:
                ctx.warn(
                    "ProgressStore: available_location_id '%s' not found — dropped" % id_variant,
                )
                continue
            _available_locations.append(loc)
    _tutorial_seen = data.get("tutorial_seen", { })
    if not _tutorial_seen is Dictionary:
        _tutorial_seen = { }
    _onboarding_pending = bool(data.get("onboarding_pending", true))


## Migrates saved payloads from older schema versions.
## Version 2: adds default tutorial_seen dict.
## Version 3: adds onboarding_pending flag (default false for existing saves).
func _apply_migrations(data: Dictionary, from_version: int, _ctx: SaveLoadContext) -> Dictionary:
    if from_version < 2:
        if not data.has("tutorial_seen") or not data["tutorial_seen"] is Dictionary:
            data["tutorial_seen"] = { }
    if from_version < 3:
        if not data.has("onboarding_pending"):
            data["onboarding_pending"] = false
    data["_version"] = _store_version()
    return data
