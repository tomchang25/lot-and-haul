# car_registry.gd
# Autoload that loads all CarData resources at startup and provides query
# access. Access globally via CarRegistry.get_car_by_id(car_id) /
# CarRegistry.get_all_cars().
extends ResourceRegistry

func _dir_path() -> String:
    return DataPaths.CARS_DIR


func _id_of(r: Resource) -> String:
    return (r as CarData).car_id if r is CarData else ""


# Returns the CarData with the given car_id, or null if not found.
func get_car_by_id(car_id: String) -> CarData:
    return get_by_id(car_id) as CarData


func get_all_cars() -> Array[CarData]:
    var result: Array[CarData] = []
    for car: CarData in get_all():
        result.append(car)
    return result
