# merchant_registry.gd
# Autoload that loads all MerchantData resources at startup and provides query
# access. Access globally via MerchantRegistry.get_merchant(merchant_id) /
# MerchantRegistry.get_all_merchants().
extends Node

var _merchants: Dictionary = { } # merchant_id → MerchantData
var _next_order_id: int = 0


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

        var order := _generate_order(m, day)
        if order != null:
            m.active_orders.append(order)
            m.last_order_roll_day = day


func _generate_order(m: MerchantData, day: int) -> SpecialOrder:
    var template: SpecialOrderData = m.special_orders.pick_random()
    if template.allowed_categories.is_empty():
        return null

    var order := SpecialOrder.new()
    order.id = "%s_%d" % [m.merchant_id, _next_order_id]
    _next_order_id += 1
    order.special_order_id = template.special_order_id
    order.merchant_id = m.merchant_id
    order.buff = randf_range(template.buff_min, template.buff_max)
    order.completion_bonus = template.completion_bonus
    order.deadline_day = day + template.deadline_days
    order.uses_condition_pricing = template.uses_condition_pricing
    order.allow_partial_delivery = template.allow_partial_delivery

    var slot_count: int = randi_range(template.slot_count_min, template.slot_count_max)
    for i in range(slot_count):
        var slot := OrderSlot.new()
        slot.category = template.allowed_categories.pick_random()
        slot.required_count = randi_range(template.required_count_min, template.required_count_max)
        if randf() < template.rarity_gate_chance:
            slot.min_rarity = ItemData.Rarity.UNCOMMON
        else:
            slot.min_rarity = -1
        if randf() < template.condition_gate_chance:
            slot.min_condition = 0.6
        else:
            slot.min_condition = 0.0
        order.slots.append(slot)

    return order
