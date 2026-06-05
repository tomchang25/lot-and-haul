# garage_store.gd
# Garage runtime store: active car and owned car roster. Serializable state
# slice held by MetaManager. Owns the fields, their save payload, and the
# operations that mutate them.
class_name GarageStore
extends RefCounted

var active_car: CarData = null
var owned_cars: Array[CarData] = []


## Returns true if [param car] is already in the owned roster.
func owns_car(car: CarData) -> bool:
    return owned_cars.has(car)


## Appends [param car] to the owned roster. No-op if already owned.
func add_car(car: CarData) -> void:
    if not owned_cars.has(car):
        owned_cars.append(car)


## Sets [param car] as the active car. No-op if already active.
func set_active(car: CarData) -> void:
    active_car = car


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
                push_warning("GarageStore: active_car_id '%s' not found — dropped" % id)
            active_car = car
    if data.has("owned_car_ids") and data["owned_car_ids"] is Array:
        owned_cars = []
        for id_variant: Variant in data["owned_car_ids"]:
            if not id_variant is String:
                continue
            var car := CarRegistry.get_car_by_id(id_variant as String)
            if car == null:
                push_warning("GarageStore: owned_car_id '%s' not found — dropped" % id_variant)
                continue
            owned_cars.append(car)


## Idempotent migration: guarantees a fresh save gets the starter van.
## Mirrors the logic previously in CarRegistry.migrate(). CarRegistry is loaded
## before SaveManager/MetaManager, so it is available here.
func migrate() -> void:
    if owned_cars.is_empty():
        var van: CarData = CarRegistry.get_car_by_id("van_basic")
        if van != null:
            owned_cars.append(van)
    if active_car == null and not owned_cars.is_empty():
        active_car = owned_cars[0]


## Validates invariants within this section. Returns true when all pass.
func validate() -> bool:
    return true
