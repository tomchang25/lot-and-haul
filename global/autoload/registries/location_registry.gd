# location_registry.gd
# Autoload that loads all LocationData resources at startup and provides query
# access. Access globally via LocationRegistry.get_location(location_id) /
# LocationRegistry.get_all_locations().
extends Node

var _locations: Dictionary = { } # location_id → LocationData


func _ready() -> void:
    _locations = ResourceDirLoader.load_by_id(
        DataPaths.LOCATIONS_DIR,
        func(r: Resource) -> String:
            return (r as LocationData).location_id if r is LocationData else ""
    )
    RegistryCoordinator.register(self)


func validate() -> bool:
    var ok := true
    if size() == 0:
        push_error("LocationRegistry: registry is empty")
        ok = false
    for location_id: String in SaveManager.available_location_ids:
        if get_location(location_id) == null:
            push_error(
                "LocationRegistry: SaveManager.available_location_ids '%s' not found"
                % location_id,
            )
            ok = false
    return ok


# Returns the LocationData with the given location_id, or null if not found.
func get_location(location_id: String) -> LocationData:
    return _locations.get(location_id, null)


func get_all_locations() -> Array[LocationData]:
    var result: Array[LocationData] = []
    for loc: LocationData in _locations.values():
        result.append(loc)
    return result


func size() -> int:
    return _locations.size()
