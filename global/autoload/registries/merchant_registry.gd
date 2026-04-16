# merchant_registry.gd
# Autoload that loads all MerchantData resources at startup and provides query
# access. Access globally via MerchantRegistry.get_merchant(merchant_id) /
# MerchantRegistry.get_all_merchants().
extends Node

var _merchants: Dictionary = { } # merchant_id → MerchantData
var next_order_id: int = 0


func _ready() -> void:
    _merchants = ResourceDirLoader.load_by_id(
        DataPaths.MERCHANTS_DIR,
        func(r: Resource) -> String:
            return (r as MerchantData).merchant_id if r is MerchantData else ""
    )
    RegistryCoordinator.register(self)


func migrate() -> void:
    for m: MerchantData in _merchants.values():
        m.active_orders = m.active_orders.filter(
            func(order: SpecialOrder) -> bool:
                for slot in order.slots:
                    if slot.category == null:
                        push_warning("MerchantRegistry.migrate: dropping order '%s' (slot has unresolved category)" % order.id)
                        return false
                return true
        )


func validate() -> bool:
    var ok := true
    if size() == 0:
        push_error("MerchantRegistry: registry is empty")
        ok = false
    for merchant: MerchantData in get_all_merchants():
        for order: SpecialOrder in merchant.active_orders:
            for i in range(order.slots.size()):
                var slot: OrderSlot = order.slots[i]
                if slot.category == null:
                    push_error(
                        "MerchantRegistry: merchant '%s' order '%s' slot %d category_id not found in CategoryRegistry"
                        % [merchant.merchant_id, order.id, i],
                    )
                    ok = false
    return ok


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
# work for merchants: rolls/expires special orders and resets negotiation budgets.
func advance_day() -> void:
    _advance_orders()
    _reset_negotiations()


func can_negotiate(merchant: MerchantData) -> bool:
    return merchant.negotiations_used_today < merchant.negotiation_per_day


func increment_negotiation(merchant: MerchantData) -> void:
    merchant.negotiations_used_today += 1


func get_active_orders(merchant: MerchantData) -> Array[SpecialOrder]:
    return merchant.active_orders


func has_active_orders(merchant: MerchantData) -> bool:
    return not merchant.active_orders.is_empty()


func _reset_negotiations() -> void:
    for m: MerchantData in _merchants.values():
        m.negotiations_used_today = 0


func _advance_orders() -> void:
    var day: int = SaveManager.current_day
    for m: MerchantData in _merchants.values():
        # 1. Clear expired orders (no payout)
        var kept: Array[SpecialOrder] = []
        for order: SpecialOrder in m.active_orders:
            if not order.is_expired(day):
                kept.append(order)
        m.active_orders = kept

        # 2. Roll new order if eligible
        if m.order_roll_cadence <= 0:
            continue
        if m.special_orders.is_empty():
            continue
        if m.last_order_roll_day >= 0 and (day - m.last_order_roll_day) < m.order_roll_cadence:
            continue
        if m.active_orders.size() >= m.max_active_orders:
            continue

        var order := _generate_order(m)
        if order != null:
            m.active_orders.append(order)
            m.last_order_roll_day = day


func _generate_order(m: MerchantData) -> SpecialOrder:
    var template: SpecialOrderData = m.special_orders.pick_random()
    if template.slot_pool.is_empty():
        return null

    var id_string: String = "%s_%d" % [m.merchant_id, next_order_id]
    next_order_id += 1
    return SpecialOrder.create(template, m.merchant_id, id_string)
