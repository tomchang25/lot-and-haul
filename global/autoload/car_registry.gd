# car_registry.gd
# Autoload that loads all CarData resources at startup and provides query
# access. Access globally via CarRegistry.get_car(car_id) /
# CarRegistry.get_all_cars().
extends Node

var _cars: Dictionary = { } # car_id → CarData


func _ready() -> void:
    _cars = ResourceDirLoader.load_by_id(
        DataPaths.CARS_DIR,
        func(r: Resource) -> String:
            return (r as CarData).car_id if r is CarData else ""
    )


# Returns the CarData with the given car_id, or null if not found.
func get_car(car_id: String) -> CarData:
    return _cars.get(car_id, null)


func get_all_cars() -> Array[CarData]:
    var result: Array[CarData] = []
    for car: CarData in _cars.values():
        result.append(car)
    return result
