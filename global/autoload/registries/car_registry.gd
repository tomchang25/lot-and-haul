# car_registry.gd
# Autoload that loads all CarData resources at startup and provides query
# access. Access globally via CarRegistry.get_car_by_id(car_id) /
# CarRegistry.get_all_cars().
extends Node

var _cars: Dictionary = { } # car_id → CarData


func _ready() -> void:
    _cars = ResourceDirLoader.load_by_id(
        DataPaths.CARS_DIR,
        func(r: Resource) -> String:
            return (r as CarData).car_id if r is CarData else ""
    )
    RegistryCoordinator.register(self)


# Idempotent migration: guarantees a fresh save gets the starter van, and
# repairs saves whose active_car no longer resolves. Safe to re-run.
func migrate() -> void:
    if SaveManager.owned_cars.is_empty():
        var starter: CarData = get_car_by_id("van_basic")
        if starter != null:
            SaveManager.owned_cars.append(starter)
    if SaveManager.active_car == null or not SaveManager.owned_cars.has(SaveManager.active_car):
        SaveManager.active_car = SaveManager.owned_cars[0]


func validate() -> bool:
    var ok := true
    if size() == 0:
        push_error("CarRegistry: registry is empty")
        ok = false
    if SaveManager.active_car == null:
        push_error("CarRegistry: SaveManager.active_car is null")
        ok = false
    for car: CarData in SaveManager.owned_cars:
        if get_car_by_id(car.car_id) == null:
            push_error(
                "CarRegistry: SaveManager.owned_cars entry '%s' not found"
                % car.car_id,
            )
            ok = false
    return ok


# Returns the CarData with the given car_id, or null if not found.
func get_car_by_id(car_id: String) -> CarData:
    return _cars.get(car_id, null)


func get_all_cars() -> Array[CarData]:
    var result: Array[CarData] = []
    for car: CarData in _cars.values():
        result.append(car)
    return result


func size() -> int:
    return _cars.size()
