# location_registry.gd
# Autoload that loads all LocationData resources at startup and provides query
# access. Access globally via LocationRegistry.get_location_by_id(location_id) /
# LocationRegistry.get_all_locations().
extends ResourceRegistry

func _dir_path() -> String:
    return DataPaths.LOCATIONS_DIR


func _id_of(r: Resource) -> String:
    return (r as LocationData).location_id if r is LocationData else ""


# Returns the LocationData with the given location_id, or null if not found.
func get_location_by_id(location_id: String) -> LocationData:
    return get_by_id(location_id) as LocationData


func get_all_locations(include_tutorial: bool = false, include_test: bool = false) -> Array[LocationData]:
    var result: Array[LocationData] = []
    for loc: LocationData in get_all():
        if loc.is_tutorial and not include_tutorial:
            continue
        if loc.is_test and not include_test:
            continue
        result.append(loc)
    return result


## Returns the first tutorial-only location, or null if none exist.
func get_tutorial_location() -> LocationData:
    for loc: LocationData in get_all():
        if loc.is_tutorial:
            return loc
    return null
