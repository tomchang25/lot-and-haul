# garage_store.gd
# Garage runtime store: active car and owned car roster. Serializable state
# slice held by MetaManager. Owns the fields, their save payload, and the
# operations that mutate them.
#
# Fields are read-public via getters. Mutation goes through the owning Manager only.
class_name GarageStore
extends StoreBase

var _active_car: CarData = null
var _owned_cars: Array[CarData] = []

## Currently active car. Read-only externally.
var active_car: CarData:
    get:
        return _active_car

## Shallow duplicate of the owned-car roster (CarData refs shared). Read-only externally.
## Returns a duplicate for iteration stability; refs inside are shared.
var owned_cars: Array[CarData]:
    get:
        return _owned_cars.duplicate()


## Returns true if [param car] is already in the owned roster.
func owns_car(car: CarData) -> bool:
    return _owned_cars.has(car)


## Appends [param car] to the owned roster. No-op if already owned.
func add_car(car: CarData) -> void:
    if not _owned_cars.has(car):
        _owned_cars.append(car)


## Sets [param car] as the active car. No-op if already active.
func set_active(car: CarData) -> void:
    _active_car = car


## Section id for the garage save payload.
func section_id() -> String:
    return "garage"


## Serializes garage state to a save payload.
func to_dict() -> Dictionary:
    var owned_car_ids: Array[String] = []
    for car: CarData in _owned_cars:
        owned_car_ids.append(car.car_id)
    return {
        "_version": _store_version(),
        "active_car_id": _active_car.car_id if _active_car != null else "",
        "owned_car_ids": owned_car_ids,
    }


## Restores garage state. Unresolved car ids are dropped with a warning.
func from_dict(data: Dictionary, _ctx: SaveLoadContext) -> void:
    var version: int = int(data.get("_version", 1))
    data = _apply_migrations(data, version, _ctx)
    if data.has("active_car_id") and data["active_car_id"] is String:
        var id: String = data["active_car_id"]
        if id.is_empty():
            _active_car = null
        else:
            var car: CarData = CarRegistry.get_car_by_id(id)
            if car == null:
                push_warning("GarageStore: active_car_id '%s' not found — dropped" % id)
            _active_car = car
    if data.has("owned_car_ids") and data["owned_car_ids"] is Array:
        _owned_cars = []
        for id_variant: Variant in data["owned_car_ids"]:
            if not id_variant is String:
                continue
            var car: CarData = CarRegistry.get_car_by_id(id_variant as String)
            if car == null:
                push_warning("GarageStore: owned_car_id '%s' not found — dropped" % id_variant)
                continue
            _owned_cars.append(car)
