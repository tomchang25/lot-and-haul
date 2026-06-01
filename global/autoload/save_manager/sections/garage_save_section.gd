# garage_save_section.gd
# Save section: garage state — the active car and the set of owned cars.
# Cars are persisted by id and re-resolved through CarRegistry on load.
# Registered with SaveManager as the "garage" section.
class_name GarageSaveSection
extends RefCounted


## Unique key for this section in the JSON save file.
func section_id() -> String:
    return "garage"


func to_dict() -> Dictionary:
    var owned_car_ids: Array[String] = []
    for car: CarData in SaveManager.owned_cars:
        owned_car_ids.append(car.car_id)
    return {
        "active_car_id": SaveManager.active_car.car_id if SaveManager.active_car != null else "",
        "owned_car_ids": owned_car_ids,
    }


func from_dict(data: Dictionary) -> void:
    if data.has("active_car_id") and data["active_car_id"] is String:
        SaveManager.active_car = CarRegistry.get_car_by_id(data["active_car_id"])
    if data.has("owned_car_ids") and data["owned_car_ids"] is Array:
        SaveManager.owned_cars = []
        for id: Variant in data["owned_car_ids"]:
            if not id is String:
                continue
            var car: CarData = CarRegistry.get_car_by_id(id)
            if car != null:
                SaveManager.owned_cars.append(car)
