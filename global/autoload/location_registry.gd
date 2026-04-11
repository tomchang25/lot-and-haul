# location_registry.gd
# Autoload that loads all LocationData resources at startup and provides query
# access. Access globally via LocationRegistry.get_location(location_id) /
# LocationRegistry.get_all_locations(). Mirrors the ItemRegistry pattern.
extends Node

var _locations: Array[LocationData] = []


func _ready() -> void:
    _load_all_locations()


func _load_all_locations() -> void:
    var dir := DirAccess.open(DataPaths.LOCATIONS_DIR)
    if dir == null:
        push_error("LocationRegistry: could not open " + DataPaths.LOCATIONS_DIR)
        return

    dir.list_dir_begin()
    var file_name := dir.get_next()
    while file_name != "":
        if not dir.current_is_dir() and file_name.ends_with(".tres"):
            var path := DataPaths.LOCATIONS_DIR + "/" + file_name
            var resource := load(path)
            if resource is LocationData:
                _locations.append(resource as LocationData)
        file_name = dir.get_next()
    dir.list_dir_end()


# Returns the LocationData with the given location_id, or null if not found.
func get_location(location_id: String) -> LocationData:
    for location: LocationData in _locations:
        if location.location_id == location_id:
            return location
    return null


func get_all_locations() -> Array[LocationData]:
    return _locations
