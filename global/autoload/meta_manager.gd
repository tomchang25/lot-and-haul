extends Node

# ══ Storage registration ══════════════════════════════════════════════════════

func register_storage_item(entry: ItemEntry) -> void:
    entry.id = SaveManager.next_entry_id
    SaveManager.next_entry_id += 1
    SaveManager.storage_items.append(entry)


func register_storage_items(entries: Array[ItemEntry]) -> void:
    for entry: ItemEntry in entries:
        register_storage_item(entry)
    SaveManager.save()

# ══ Location sampling ════════════════════════════════════════════════════════


func roll_available_locations() -> void:
    var all := LocationRegistry.get_all_locations()
    all.shuffle()
    SaveManager.available_locations = all.slice(0, mini(Economy.LOCATION_SAMPLE_SIZE, all.size()))

# ══ Day advancement ═══════════════════════════════════════════════════════════


func advance_days(days: int) -> DaySummary:
    var summary := DaySummary.new()
    if days <= 0:
        summary.start_day = SaveManager.current_day
        summary.end_day = SaveManager.current_day
        summary.days_elapsed = 0
        return summary

    summary.start_day = SaveManager.current_day
    summary.days_elapsed = days
    summary.living_cost = days * Economy.DAILY_BASE_COST

    SaveManager.current_day += days
    SaveManager.cash -= summary.living_cost

    summary.completed_actions = _tick_research_slots(days)
    summary.end_day = SaveManager.current_day

    MarketManager.advance_market(days)
    MerchantRegistry.advance_day()
    SaveManager.available_locations.clear()

    SaveManager.save()
    return summary


func _tick_research_slots(days: int) -> Array[Dictionary]:
    var completions: Array[Dictionary] = []

    for i: int in range(SaveManager.research_slots.size()):
        var d: Dictionary = SaveManager.research_slots[i]
        var slot := ResearchSlot.from_dict(d)
        if slot.is_empty() or slot.completed:
            continue
        var entry: ItemEntry = _find_storage_entry(slot.item_id)
        if entry == null:
            continue

        var completed_during_tick: bool = false
        for day: int in range(days):
            if slot.completed:
                break
            match slot.action:
                ResearchSlot.SlotAction.STUDY:
                    entry.advance_scrutiny()
                    slot.completed = entry.is_study_complete()
                    if entry.intuition_level < entry.max_intuition_level:
                        var intuition_chance: float = 0.05 / (entry.intuition_level + 1)
                        if randf() < intuition_chance:
                            entry.intuition_level += 1
                ResearchSlot.SlotAction.REPAIR:
                    entry.apply_repair()
                    slot.completed = entry.is_repair_complete()
                ResearchSlot.SlotAction.UNLOCK:
                    entry.add_unlock_effort()
                    if entry.is_unlock_ready():
                        entry.advance_layer()
                        slot.completed = true
                ResearchSlot.SlotAction.RESTORE:
                    entry.apply_restore()
                    slot.completed = entry.is_restore_complete()
                _:
                    push_warning("MetaManager: unknown SlotAction %d" % slot.action)
                    break
            if slot.completed and not completed_during_tick:
                completed_during_tick = true

        SaveManager.research_slots[i] = slot.to_dict()

        if completed_during_tick:
            completions.append(
                {
                    "name": entry.display_name,
                    "effect": _slot_effect_label(slot.action),
                    "action": ResearchSlot.action_to_string(slot.action),
                },
            )

    return completions


func _find_storage_entry(item_id: int) -> ItemEntry:
    for entry: ItemEntry in SaveManager.storage_items:
        if entry.id == item_id:
            return entry
    return null


func _slot_effect_label(action: ResearchSlot.SlotAction) -> String:
    match action:
        ResearchSlot.SlotAction.STUDY:
            return "Fully inspected"
        ResearchSlot.SlotAction.REPAIR:
            return "Repair complete"
        ResearchSlot.SlotAction.UNLOCK:
            return "Layer unlocked"
        ResearchSlot.SlotAction.RESTORE:
            return "Fully restored"
        _:
            push_warning("MetaManager: unknown SlotAction %d" % action)
            return "Done"

# ══ Trade operations ══════════════════════════════════════════════════════════


func sell_items(items: Array[ItemEntry], price: int, merchant: MerchantData) -> void:
    for entry: ItemEntry in items:
        SaveManager.storage_items.erase(entry)
        ResearchSlot.clear_for_item(SaveManager.research_slots, entry.id)
        KnowledgeManager.add_category_points(
            entry.item_data.category_data,
            entry.item_data.rarity,
            KnowledgeManager.KnowledgeAction.SELL,
        )
    SaveManager.cash += price
    MerchantRegistry.increment_negotiation(merchant)
    SaveManager.save()


func fulfill_order(order: SpecialOrder, assignments: Dictionary) -> int:
    var merchant: MerchantData = order.merchant
    var total_payout: int = 0
    var consumed: Array[ItemEntry] = []

    for slot_idx: Variant in assignments:
        var assigned: Array = assignments[slot_idx]
        var slot: OrderSlot = order.slots[int(slot_idx)]
        for entry: ItemEntry in assigned:
            total_payout += order.compute_item_price(entry)
            consumed.append(entry)
            slot.filled_count += 1

    for entry: ItemEntry in consumed:
        SaveManager.storage_items.erase(entry)
        ResearchSlot.clear_for_item(SaveManager.research_slots, entry.id)
        KnowledgeManager.add_category_points(
            entry.item_data.category_data,
            entry.item_data.rarity,
            KnowledgeManager.KnowledgeAction.SELL,
        )

    if order.is_complete():
        total_payout += order.completion_bonus
        merchant.completed_order_ids.append(order.id)
        merchant.active_orders.erase(order)

    SaveManager.cash += total_payout
    SaveManager.save()
    return total_payout


func buy_car(car: CarData) -> bool:
    if car == null:
        return false
    if SaveManager.owned_cars.has(car):
        return false
    if SaveManager.cash < car.price:
        return false
    SaveManager.cash -= car.price
    SaveManager.owned_cars.append(car)
    SaveManager.save()
    return true


func set_active_car(car: CarData) -> void:
    if car == SaveManager.active_car:
        return
    SaveManager.active_car = car
    SaveManager.save()

# ══ Research slot assignment ═════════════════════════════════════════════════


func assign_research_slot(entry: ItemEntry, action: ResearchSlot.SlotAction) -> bool:
    if entry == null:
        return false

    var new_slot := ResearchSlot.create(action, entry.id)
    var existing_idx: int = ResearchSlot.find_index(SaveManager.research_slots, entry.id)
    if existing_idx >= 0:
        SaveManager.research_slots[existing_idx] = new_slot.to_dict()
        SaveManager.save()
        return true

    var empty_idx: int = _find_empty_slot_index()
    if empty_idx >= 0:
        SaveManager.research_slots[empty_idx] = new_slot.to_dict()
        SaveManager.save()
        return true

    if SaveManager.research_slots.size() < SaveManager.max_research_slots:
        SaveManager.research_slots.append(new_slot.to_dict())
        SaveManager.save()
        return true

    return false


func remove_research_slot(entry: ItemEntry) -> void:
    if entry == null:
        return
    var idx: int = ResearchSlot.find_index(SaveManager.research_slots, entry.id)
    if idx < 0:
        return
    SaveManager.research_slots[idx] = ResearchSlot.new().to_dict()
    SaveManager.save()


func _find_empty_slot_index() -> int:
    for i: int in range(SaveManager.research_slots.size()):
        var d: Dictionary = SaveManager.research_slots[i]
        if int(d.get("item_id", -1)) == -1:
            return i
    return -1

# ══ Run resolution ════════════════════════════════════════════════════════════


func resolve_run(record: RunRecord) -> DaySummary:
    SaveManager.cash += record.onsite_proceeds - record.paid_price - record.entry_fee - record.fuel_cost

    register_storage_items(record.cargo_items)

    var summary := advance_days(record.location_data.travel_days)

    summary.onsite_proceeds = record.onsite_proceeds
    summary.paid_price = record.paid_price
    summary.entry_fee = record.entry_fee
    summary.fuel_cost = record.fuel_cost
    summary.cargo_count = record.cargo_items.size()

    RunManager.clear_run_state()

    return summary
