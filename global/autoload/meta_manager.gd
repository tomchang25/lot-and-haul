extends Node

# ══ Storage registration ══════════════════════════════════════════════════════

func register_storage_item(entry: ItemEntry) -> void:
    entry.id = SaveManager.next_entry_id
    SaveManager.next_entry_id += 1
    SaveManager.storage_items.append(entry)
    if entry.item_data != null and entry.item_data.auto_verify:
        entry.reveal_all_hidden()


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

    SaveManager.available_locations.clear()

    _generate_nightly_customers()

    SaveManager.save()
    return summary

# ══ Nightly customers ═════════════════════════════════════════════════════════


## Generates the nightly customer set for the current day.
## Delegates to Customer.generate_for_night, stores in SaveManager, and resets
## the per-night sales ledger that the Day Summary rework (Phase 11) reads.
func _generate_nightly_customers() -> void:
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    SaveManager.nightly_customers = Customer.generate_for_night(
        rng,
        SaveManager.storage_items,
    )
    SaveManager.customer_sales_today.clear()


## Commits a customer sale: removes items from storage, adds cash, records the
## sale for the daily summary, drops the served customer, and saves.
##
## MetaManager is the transactional authority — the sell scene only computes the
## price and calls this; it does not mutate cash, storage, or the customer list.
##
## [param items] — ItemEntry instances being sold.
## [param sale_price] — total price computed by SellMath.
## [param customer] — the served customer; removed from the nightly set. May be
##   null (caller manages removal) for backward compatibility.
## [param strategy] — "conservative" / "aggressive", recorded for the summary.
func resolve_customer_sale(
        items: Array,
        sale_price: int,
        customer: Customer = null,
        strategy: String = "",
) -> void:
    var sold_ids: Array[int] = []
    for entry: ItemEntry in items:
        sold_ids.append(entry.id)
        SaveManager.storage_items.erase(entry)
        ResearchSlot.clear_for_item(SaveManager.research_slots, entry.id)
        KnowledgeManager.add_category_points(
            entry.item_data.category_data,
            entry.item_data.rarity,
            KnowledgeManager.KnowledgeAction.SELL,
        )
    SaveManager.cash += sale_price

    SaveManager.customer_sales_today.append({
        "day": SaveManager.current_day,
        "customer_id": customer.customer_id if customer != null else "",
        "customer_name": customer.display_name if customer != null else "",
        "strategy": strategy,
        "item_count": items.size(),
        "item_ids": sold_ids,
        "sale_price": sale_price,
    })

    if customer != null:
        SaveManager.nightly_customers.erase(customer)

    SaveManager.save()


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
                ResearchSlot.SlotAction.REPAIR:
                    ResearchSlot.apply_repair(entry)
                    slot.completed = ResearchSlot.is_repair_complete(entry)
                ResearchSlot.SlotAction.RESTORE:
                    ResearchSlot.apply_restore(entry)
                    slot.completed = ResearchSlot.is_restore_complete(entry)
                ResearchSlot.SlotAction.RESEARCH:
                    slot.research_days_spent += 1
                    var duration: int = Economy.RESEARCH_DAYS.get(
                        entry.item_data.rarity,
                        3,
                    )
                    if slot.research_days_spent >= duration:
                        entry.reveal_all_hidden()
                        slot.completed = true
                _:
                    push_warning("MetaManager: unknown SlotAction %d" % slot.action)
                    break
            if slot.completed and not completed_during_tick:
                completed_during_tick = true

        # RESEARCH auto-clears on completion — verified is computed from
        # hidden clue coverage; the slot has no further use once verified.
        # All other actions keep the completed slot until the player removes it.
        if slot.action == ResearchSlot.SlotAction.RESEARCH and slot.completed:
            SaveManager.research_slots[i] = ResearchSlot.new().to_dict()
        else:
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
        ResearchSlot.SlotAction.REPAIR:
            return "Repair complete"
        ResearchSlot.SlotAction.RESTORE:
            return "Fully restored"
        ResearchSlot.SlotAction.RESEARCH:
            return "Verified"
        _:
            push_warning("MetaManager: unknown SlotAction %d" % action)
            return "Done"

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

    # Phase 7: Auto-reveal all surface clues on hub return.
    for entry: ItemEntry in record.cargo_items:
        entry.auto_reveal_all_surface()

    register_storage_items(record.cargo_items)

    var summary := advance_days(record.location_data.travel_days)

    summary.onsite_proceeds = record.onsite_proceeds
    summary.paid_price = record.paid_price
    summary.entry_fee = record.entry_fee
    summary.fuel_cost = record.fuel_cost
    summary.cargo_count = record.cargo_items.size()

    RunManager.clear_run_state()

    return summary
