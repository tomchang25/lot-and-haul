# car_registry.gd
# Autoload that loads all CarData resources at startup and provides query
# access. Access globally via CarRegistry.get_car_by_id(car_id) /
# CarRegistry.get_all_cars().
extends ResourceRegistry


func _dir_path() -> String:
    return DataPaths.CARS_DIR


func _id_of(r: Resource) -> String:
    return (r as CarData).car_id if r is CarData else ""


# Idempotent migration: guarantees a fresh save gets the starter van, and
# repairs saves whose active_car no longer resolves (e.g. the car was
# removed from the data pipeline). Safe to re-run.
func migrate() -> void:
    if SaveManager.owned_cars.is_empty():
        var van: CarData = get_car_by_id("van_basic")
        if van != null:
            SaveManager.owned_cars.append(van)
    if SaveManager.active_car == null and not SaveManager.owned_cars.is_empty():
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
        if car == null:
            push_error("CarRegistry: SaveManager.owned_cars contains a null entry")
            ok = false
    return ok


# Returns the CarData with the given car_id, or null if not found.
func get_car_by_id(car_id: String) -> CarData:
    return get_by_id(car_id) as CarData


func get_all_cars() -> Array[CarData]:
    var result: Array[CarData] = []
    for car: CarData in get_all():
        result.append(car)
    return result
