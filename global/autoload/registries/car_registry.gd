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
    RegistryCoordinator.register(self)


# Idempotent migration: guarantees a fresh save gets the starter van, and
# repairs saves whose `active_car_id` no longer resolves (e.g. the car was
# removed from the data pipeline). Safe to re-run.
func migrate() -> void:
    if SaveManager.owned_car_ids.is_empty():
        SaveManager.owned_car_ids.append("van_basic")
    if SaveManager.active_car_id.is_empty() or get_car(SaveManager.active_car_id) == null:
        SaveManager.active_car_id = SaveManager.owned_car_ids[0]


func validate() -> bool:
    var ok := true
    if size() == 0:
        push_error("CarRegistry: registry is empty")
        ok = false
    if get_car(SaveManager.active_car_id) == null:
        push_error(
            "CarRegistry: SaveManager.active_car_id '%s' not found"
            % SaveManager.active_car_id,
        )
        ok = false
    for car_id: String in SaveManager.owned_car_ids:
        if get_car(car_id) == null:
            push_error(
                "CarRegistry: SaveManager.owned_car_ids '%s' not found"
                % car_id,
            )
            ok = false
    return ok


# Returns the CarData with the given car_id, or null if not found.
func get_car(car_id: String) -> CarData:
    return _cars.get(car_id, null)


func get_all_cars() -> Array[CarData]:
    var result: Array[CarData] = []
    for car: CarData in _cars.values():
        result.append(car)
    return result


func size() -> int:
    return _cars.size()
