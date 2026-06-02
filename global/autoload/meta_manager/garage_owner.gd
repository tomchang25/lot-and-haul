# garage_owner.gd
# Garage domain owner: active car and owned car roster. Owns the fields and
# their save payload. Held by MetaManager; not a global singleton.
class_name GarageOwner
extends RefCounted

var active_car: CarData = null
var owned_cars: Array[CarData] = []


## Section id for the garage save payload.
func section_id() -> String:
    return "garage"


## Serializes garage state to a save payload.
func to_dict() -> Dictionary:
    var owned_car_ids: Array[String] = []
    for car: CarData in owned_cars:
        owned_car_ids.append(car.car_id)
    return {
        "active_car_id": active_car.car_id if active_car != null else "",
        "owned_car_ids": owned_car_ids,
    }


## Restores garage state. Unresolved car ids are dropped with a warning.
func from_dict(data: Dictionary) -> void:
    if data.has("active_car_id") and data["active_car_id"] is String:
        var id: String = data["active_car_id"]
        if id.is_empty():
            active_car = null
        else:
            var car := CarRegistry.get_car_by_id(id)
            if car == null:
                push_warning("GarageOwner: active_car_id '%s' not found — dropped" % id)
            active_car = car
    if data.has("owned_car_ids") and data["owned_car_ids"] is Array:
        owned_cars = []
        for id_variant: Variant in data["owned_car_ids"]:
            if not id_variant is String:
                continue
            var car := CarRegistry.get_car_by_id(id_variant as String)
            if car == null:
                push_warning("GarageOwner: owned_car_id '%s' not found — dropped" % id_variant)
                continue
            owned_cars.append(car)
