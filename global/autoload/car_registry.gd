# car_registry.gd
# Autoload that loads all CarData resources at startup and provides query
# access. Access globally via CarRegistry.get_car(car_id) /
# CarRegistry.get_all_cars(). Mirrors the ItemRegistry pattern.
extends Node

var _cars: Array[CarData] = []


func _ready() -> void:
    _load_all_cars()


func _load_all_cars() -> void:
    var dir := DirAccess.open(DataPaths.CARS_DIR)
    if dir == null:
        push_error("CarRegistry: could not open " + DataPaths.CARS_DIR)
        return

    dir.list_dir_begin()
    var file_name := dir.get_next()
    while file_name != "":
        if not dir.current_is_dir() and file_name.ends_with(".tres"):
            var path := DataPaths.CARS_DIR + "/" + file_name
            var resource := load(path)
            if resource is CarData:
                _cars.append(resource as CarData)
        file_name = dir.get_next()
    dir.list_dir_end()


# Returns the CarData with the given car_id, or null if not found.
func get_car(car_id: String) -> CarData:
    for car: CarData in _cars:
        if car.car_id == car_id:
            return car
    return null


func get_all_cars() -> Array[CarData]:
    return _cars
