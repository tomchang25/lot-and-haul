extends Node

# Pending run economics are stashed on SaveManager.pending_run (persisted) by
# resolve_run() and folded into the DaySummary by end_day().

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

# ══ Location sampling ═════════════════════════════════════════════════════════


func roll_available_locations() -> void:
    var all := LocationRegistry.get_all_locations()
    all.shuffle()
    SaveManager.available_locations = all.slice(0, mini(Economy.LOCATION_SAMPLE_SIZE, all.size()))

# ══ Slot economy — hub actions ════════════════════════════════════════════════


## Begins a Storage slot: increments current_slot (consuming it) and refreshes
## storage_ap to a full pool. Call before navigating to the storage scene.
func begin_storage_slot() -> void:
    SaveManager.current_slot += 1
    SaveManager.storage_ap = Economy.STORAGE_AP_MAX
    SaveManager.save()


## Begins an Auction slot: consumes morning + afternoon (slots 1 + 2) by
## advancing current_slot to 3, returning the player to the evening slot.
## Call before navigating to location select.
func begin_auction() -> void:
    assert(SaveManager.current_slot == 1, "Auction can only begin in slot 1 (Morning)")
    SaveManager.current_slot = 3
    SaveManager.save()


## Begins an Open Shop session: generates nightly customers scaled to the slots
## committed, clears the nightly sales ledger, and marks current_slot > 3 so
## the hub ends the day on re-entry after customer_sell completes.
##
## [param selling_slots] — 1 (evening only), 2 (afternoon + evening), or
##   3 (full day). Pass 4 - current_slot at the moment Open Shop is chosen.
func begin_open_shop(selling_slots: int) -> void:
    SaveManager.selling_slots_today = selling_slots
    SaveManager.current_slot = 4 # hub sees > 3 → triggers end_day
    SaveManager.customer_sales_today.clear()
    _generate_nightly_customers(selling_slots)
    SaveManager.save()


## Closes out the current calendar day: advances current_day, deducts living
## cost, captures customer sales, folds pending run economics, resets slot
## state, saves, and returns a DaySummary for the day summary scene.
##
## The hub calls this automatically when current_slot > 3.
func end_day() -> DaySummary:
    var summary := DaySummary.new()
    summary.start_day = SaveManager.current_day
    summary.days_elapsed = 1
    summary.living_cost = Economy.DAILY_BASE_COST

    SaveManager.current_day += 1
    SaveManager.cash -= Economy.DAILY_BASE_COST
    summary.end_day = SaveManager.current_day

    # Capture customer sales recorded during Open Shop.
    for sale in SaveManager.customer_sales_today:
        summary.customer_sales_total += sale.sale_price
        summary.customer_sales_detail.append(sale.duplicate())

    # Fold pending run economics (set by resolve_run after the auction).
    if not SaveManager.pending_run.is_empty():
        var pr: Dictionary = SaveManager.pending_run
        summary.onsite_proceeds = int(pr.get("onsite_proceeds", 0))
        summary.paid_price = int(pr.get("paid_price", 0))
        summary.entry_fee = int(pr.get("entry_fee", 0))
        summary.fuel_cost = int(pr.get("fuel_cost", 0))
        summary.cargo_count = int(pr.get("cargo_count", 0))
        SaveManager.pending_run = {}

    # Reset for next day.
    SaveManager.current_slot = 1
    SaveManager.storage_ap = 0
    SaveManager.selling_slots_today = 0
    SaveManager.available_locations.clear()

    SaveManager.save()
    return summary

# ══ Nightly customers ═════════════════════════════════════════════════════════


## Generates the nightly customer set scaled by [param selling_slots].
## 1 → 2–3 customers, 2 → 4–6, 3 → 7–10. 0 → no customers.
func _generate_nightly_customers(selling_slots: int) -> void:
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    var count := _selling_slots_to_count(rng, selling_slots)
    SaveManager.nightly_customers = Customer.generate_for_night(
        rng,
        SaveManager.storage_items,
        count,
    )


func _selling_slots_to_count(rng: RandomNumberGenerator, selling_slots: int) -> int:
    match selling_slots:
        1:
            return rng.randi_range(2, 3)
        2:
            return rng.randi_range(4, 6)
        3:
            return rng.randi_range(7, 10)
        _:
            return 0


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
        KnowledgeManager.add_category_points(
            entry.item_data.category_data,
            entry.item_data.rarity,
            KnowledgeManager.KnowledgeAction.SELL,
        )
    SaveManager.cash += sale_price

    SaveManager.customer_sales_today.append(
        {
            "day": SaveManager.current_day,
            "customer_id": customer.customer_id if customer != null else "",
            "customer_name": customer.display_name if customer != null else "",
            "strategy": strategy,
            "item_count": items.size(),
            "item_ids": sold_ids,
            "sale_price": sale_price,
        },
    )

    if customer != null:
        SaveManager.nightly_customers.erase(customer)

    SaveManager.save()

# ══ Storage AP actions ════════════════════════════════════════════════════════
#
# Each action follows guard → apply → charge → save. AP is charged only after
# the effect lands — a disabled or no-op call never costs AP.


## Applies one Repair action to [param entry] from the current storage AP pool.
## Guard: sufficient AP and condition < 0.5. Returns true when AP was spent.
func repair_item(entry: ItemEntry) -> bool:
    if entry == null:
        return false
    if SaveManager.storage_ap < Economy.REPAIR_AP_COST:
        return false
    if ResearchSlot.is_repair_complete(entry):
        return false
    ResearchSlot.apply_repair(entry)
    SaveManager.storage_ap -= Economy.REPAIR_AP_COST
    SaveManager.save()
    return true


## Applies one Restore action to [param entry] from the current storage AP pool.
## Guard: sufficient AP, condition >= 0.5, and condition < 1.0. Returns true
## when AP was spent.
func restore_item(entry: ItemEntry) -> bool:
    if entry == null:
        return false
    if SaveManager.storage_ap < Economy.RESTORE_AP_COST:
        return false
    if entry.condition < 0.5:
        return false
    if ResearchSlot.is_restore_complete(entry):
        return false
    ResearchSlot.apply_restore(entry)
    SaveManager.storage_ap -= Economy.RESTORE_AP_COST
    SaveManager.save()
    return true


## Applies one Research action to [param entry] from the current storage AP pool.
## Deterministic — never rolls. Adds (5 + investigation attribute) progress to
## the first unrevealed hidden clue; reveals it once progress >= clue.dc.
## Guard: sufficient AP and at least one unrevealed hidden clue. Returns true
## when AP was spent.
func research_item(entry: ItemEntry) -> bool:
    if entry == null:
        return false
    if SaveManager.storage_ap < Economy.RESEARCH_AP_COST:
        return false
    if entry.condition < 0.5:
        return false
    if not entry.has_unrevealed_hidden():
        return false
    var investigation_attr := KnowledgeManager.get_attribute_value("investigation")
    var progress_amount: int = 5 + investigation_attr
    entry.advance_research(progress_amount)
    SaveManager.storage_ap -= Economy.RESEARCH_AP_COST
    SaveManager.save()
    return true

# ══ Vehicle management ════════════════════════════════════════════════════════


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

# ══ Run resolution ════════════════════════════════════════════════════════════


## Resolves a completed run: applies cash, registers cargo, auto-reveals surface
## clues, stores run economics as pending for end_day(), sets current_slot to 3
## so the player returns to the hub for the evening slot, and clears run state.
##
## Navigation: the caller (run_review_scene) must call GameManager.go_to_hub()
## after this returns. The day summary fires when the player chooses Open Shop
## or all slots are exhausted from the hub.
func resolve_run(record: RunRecord) -> void:
    SaveManager.cash += record.onsite_proceeds - record.paid_price - record.entry_fee - record.fuel_cost

    # Auto-reveal all surface clues on hub return (Phase 7).
    for entry: ItemEntry in record.cargo_items:
        entry.auto_reveal_all_surface()

    register_storage_items(record.cargo_items)

    # Stash run economics so end_day can fold them into the day summary.
    # Persisted on SaveManager so a quit before end_day doesn't drop them.
    SaveManager.pending_run = {
        "onsite_proceeds": record.onsite_proceeds,
        "paid_price": record.paid_price,
        "entry_fee": record.entry_fee,
        "fuel_cost": record.fuel_cost,
        "cargo_count": record.cargo_items.size(),
    }

    # Auction consumed morning + afternoon; player returns for the evening slot.
    SaveManager.current_slot = 3
    SaveManager.save()

    RunManager.clear_run_state()
