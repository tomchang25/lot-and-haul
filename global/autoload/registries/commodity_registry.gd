# commodity_registry.gd
# Autoload that loads all CommodityData resources at startup and provides query
# access. Access globally via CommodityRegistry.get_commodity_by_id(id).
extends Node

var _commodities_by_id: Dictionary = { } # commodity_id -> CommodityData


func _ready() -> void:
    _commodities_by_id = ResourceDirLoader.load_by_id(
        DataPaths.COMMODITIES_DIR,
        func(r: Resource) -> String:
            return (r as CommodityData).commodity_id if r is CommodityData else ""
    )
    RegistryCoordinator.register(self)


func validate() -> bool:
    if size() == 0:
        push_error("CommodityRegistry: registry is empty")
        return false

    var ok := true
    for commodity: CommodityData in _commodities_by_id.values():
        if commodity.category_data == null:
            push_error(
                "CommodityRegistry: commodity '%s' has no category_data"
                % commodity.commodity_id,
            )
            ok = false
    return ok


func get_commodity_by_id(commodity_id: String) -> CommodityData:
    return _commodities_by_id.get(commodity_id, null)


func get_all_commodities() -> Array[CommodityData]:
    var result: Array[CommodityData] = []
    for commodity: CommodityData in _commodities_by_id.values():
        result.append(commodity)
    return result


func size() -> int:
    return _commodities_by_id.size()
