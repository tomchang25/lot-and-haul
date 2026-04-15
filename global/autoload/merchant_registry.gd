# merchant_registry.gd
# Autoload that loads all MerchantData resources at startup and provides query
# access. Access globally via MerchantRegistry.get_merchant(merchant_id) /
# MerchantRegistry.get_all_merchants().
extends Node

var _merchants: Dictionary = { } # merchant_id → MerchantData


func _ready() -> void:
    _merchants = ResourceDirLoader.load_by_id(
        DataPaths.MERCHANTS_DIR,
        func(r: Resource) -> String:
            return (r as MerchantData).merchant_id if r is MerchantData else ""
    )


# Returns the MerchantData with the given merchant_id, or null if not found.
func get_merchant(merchant_id: String) -> MerchantData:
    return _merchants.get(merchant_id, null)


func get_all_merchants() -> Array[MerchantData]:
    var result: Array[MerchantData] = []
    for m: MerchantData in _merchants.values():
        result.append(m)
    return result


# Returns only the merchants the player has unlocked (perk check).
func get_available_merchants() -> Array[MerchantData]:
    var result: Array[MerchantData] = []
    for m: MerchantData in _merchants.values():
        if m.required_perk_id == "" or KnowledgeManager.has_perk(m.required_perk_id):
            result.append(m)
    return result


func size() -> int:
    return _merchants.size()


# Orchestrator called by SaveManager.advance_days(). Groups all day-advance
# work for merchants: refreshes special orders and resets negotiation budgets.
func advance_day() -> void:
    roll_special_orders()
    _reset_negotiations()


func can_negotiate(merchant: MerchantData) -> bool:
    return merchant.negotiations_used_today < merchant.negotiation_per_day


func increment_negotiation(merchant: MerchantData) -> void:
    merchant.negotiations_used_today += 1


func _reset_negotiations() -> void:
    for m: MerchantData in _merchants.values():
        m.negotiations_used_today = 0


# Refreshes special orders for all merchants.
func roll_special_orders() -> void:
    for m: MerchantData in _merchants.values():
        m.special_orders.clear()
        m.completed_order_ids.clear()
        if m.special_order_pool.is_empty():
            continue
        var pool: Array[ItemData] = m.special_order_pool.duplicate()
        pool.shuffle()
        var count: int = mini(m.special_order_count, pool.size())
        for i in range(count):
            m.special_orders.append(pool[i])
