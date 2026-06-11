# meta_manager.gd
# Hub-phase transactional authority. Holds six domain stores (EconomyStore,
# GarageStore, StorageStore, SlotStore, ProgressStore, CustomersStore); each
# owns its domain's live fields, save payload, and the operations that mutate
# them. Store references are plain public fields — scenes read state directly
# via MetaManager.economy.cash, MetaManager.storage.storage_items, etc.
# Cross-domain transactions (day end, run resolution, customer sale) remain here
# as single coordinated methods that call store methods and save exactly once.
extends Node

# ── Domain stores ──────────────────────────────────────────────────────────────

var economy: EconomyStore
var garage: GarageStore
var storage: StorageStore
var slot: SlotStore
var progress: ProgressStore
var customers: CustomersStore


func _ready() -> void:
    economy = EconomyStore.new()
    garage = GarageStore.new()
    storage = StorageStore.new()
    slot = SlotStore.new()
    progress = ProgressStore.new()
    customers = CustomersStore.new()
    SaveManager.register_provider(self)

# ══ Save section interface ════════════════════════════════════════════════════


## Serializes all MetaManager stores into a flat multi-key dict. Each store's
## section_id() is used as the key, matching the on-disk layout.
func to_dict() -> Dictionary:
    var out: Dictionary = { }
    out[economy.section_id()] = economy.to_dict()
    out[garage.section_id()] = garage.to_dict()
    out[storage.section_id()] = storage.to_dict()
    out[slot.section_id()] = slot.to_dict()
    out[progress.section_id()] = progress.to_dict()
    out[customers.section_id()] = customers.to_dict()
    return out


## Restores all stores from the full sections dict. Each store reads its own key.
## Threads [param ctx] for diagnostics (warnings and migration notes).
func from_dict(data: Dictionary, ctx: SaveLoadContext) -> void:
    economy.from_dict(data.get(economy.section_id(), { }), ctx)
    garage.from_dict(data.get(garage.section_id(), { }), ctx)
    storage.from_dict(data.get(storage.section_id(), { }), ctx)
    slot.from_dict(data.get(slot.section_id(), { }), ctx)
    progress.from_dict(data.get(progress.section_id(), { }), ctx)
    customers.from_dict(data.get(customers.section_id(), { }), ctx)


## Aggregates validate() across all stores. Returns true when all pass.
func validate() -> bool:
    var ok := true
    ok = economy.validate() and ok
    ok = garage.validate() and ok
    ok = storage.validate() and ok
    ok = slot.validate() and ok
    ok = progress.validate() and ok
    ok = customers.validate() and ok
    return ok

# ══ Cross-autoload cash helper ════════════════════════════════════════════════


## Deducts [param amount] from cash. Does NOT save — this is a sub-operation for
## caller-managed transactions that save at their own commit point.
## Returns true when the spend succeeded, false when cash was insufficient.
func spend_cash(amount: int) -> bool:
    return economy.spend(amount)


## Cross-domain transaction: deducts the upgrade cost from cash and raises
## [param attr] one level in KnowledgeStore. Saves on success.
## Returns false when cash is insufficient.
func upgrade_attribute(attr: AttributeData) -> bool:
    if not economy.spend(KnowledgeManager.attribute_upgrade_cost()):
        return false
    KnowledgeManager.raise_attribute_level(attr)
    SaveManager.save()
    return true

# ══ Storage registration ══════════════════════════════════════════════════════


## Registers [param entries] into storage. Deferred save — only called standalone
## (resolve_run already transaction-saves when registering entries directly).
func register_storage_items(entries: Array[ItemEntry]) -> void:
    storage.register_entries(entries)
    SaveManager.mark_dirty()

# ══ Location sampling ═════════════════════════════════════════════════════════


func roll_available_locations() -> void:
    var all: Array[LocationData] = LocationRegistry.get_all_locations()
    all.shuffle()
    var sampled: Array[LocationData] = []
    sampled.assign(all.slice(0, mini(Economy.LOCATION_SAMPLE_SIZE, all.size())))
    progress.set_locations(sampled)

# ══ Slot economy — hub actions ════════════════════════════════════════════════


## Begins a Storage slot: increments current_slot (consuming it) and refreshes
## storage_ap to a full pool. Call before navigating to the storage scene.
## Deferred save — flushed on the subsequent scene transition.
func begin_storage_slot() -> void:
    slot.set_slot(slot.current_slot + 1)
    slot.set_storage_ap(Economy.STORAGE_AP_MAX)
    SaveManager.mark_dirty()


## Begins an Auction slot: consumes morning + afternoon (slots 1 + 2) by
## advancing current_slot to 3, returning the player to the evening slot.
## Call before navigating to location select.
func begin_auction() -> void:
    assert(slot.current_slot == 1, "Auction can only begin in slot 1 (Morning)")
    slot.set_slot(3)
    SaveManager.save()


## Begins an Open Shop session: generates nightly customers scaled to the slots
## committed, clears the nightly sales ledger, and marks current_slot > 3 so
## the hub ends the day on re-entry after customer_sell completes.
##
## [param selling_slots] — 1 (evening only), 2 (afternoon + evening), or
##   3 (full day). Pass 4 - current_slot at the moment Open Shop is chosen.
func begin_open_shop(selling_slots: int) -> void:
    slot.set_selling_slots_today(selling_slots)
    slot.set_slot(4) # hub sees > 3 → triggers end_day
    customers.clear_sales()
    _generate_nightly_customers(selling_slots)
    SaveManager.save()


## Closes out the current calendar day: advances current_day, deducts living
## cost, captures customer sales, folds pending run economics, resets slot
## state, saves, and returns a DaySummary for the day summary scene.
##
## The hub calls this automatically when current_slot > 3.
func end_day() -> DaySummary:
    var summary := DaySummary.new()
    summary.start_day = progress.current_day
    summary.days_elapsed = 1
    summary.living_cost = Economy.DAILY_BASE_COST

    progress.advance_day()
    economy.apply_delta(-Economy.DAILY_BASE_COST)
    summary.end_day = progress.current_day

    # Capture customer sales recorded during Open Shop.
    for sale in customers.customer_sales_today:
        summary.customer_sales_total += sale.sale_price
        summary.customer_sales_detail.append(sale.duplicate())

    # Fold pending run economics (set by resolve_run after the auction).
    if not slot.pending_run.is_empty():
        var pr: Dictionary = slot.pending_run
        summary.onsite_proceeds = int(pr.get("onsite_proceeds", 0))
        summary.paid_price = int(pr.get("paid_price", 0))
        summary.entry_fee = int(pr.get("entry_fee", 0))
        summary.fuel_cost = int(pr.get("fuel_cost", 0))
        summary.cargo_count = int(pr.get("cargo_count", 0))
        slot.clear_pending_run()

    # Reset for next day.
    slot.set_slot(1)
    slot.set_storage_ap(0)
    slot.set_selling_slots_today(0)
    progress.clear_locations()

    SaveManager.save()
    return summary

# ══ Nightly customers ═════════════════════════════════════════════════════════


## Generates the nightly customer set scaled by [param selling_slots].
## 1 → 2–3 customers, 2 → 4–6, 3 → 7–10. 0 → no customers.
func _generate_nightly_customers(selling_slots: int) -> void:
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    var count := _selling_slots_to_count(rng, selling_slots)
    customers.set_customers(
        CustomerEntry.generate_for_night(
            rng,
            storage.storage_items,
            count,
        ),
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
        customer: CustomerEntry = null,
        strategy: String = "",
) -> void:
    var sold_ids: Array = storage.remove_entries(items)
    economy.earn(sale_price)
    customers.record_sale(progress.current_day, customer, strategy, sold_ids, sale_price)
    if customer != null:
        customers.remove_customer(customer)
    for entry: ItemEntry in items:
        EventBus.sale_resolved.emit(entry)
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
    if slot.storage_ap < Economy.REPAIR_AP_COST:
        return false
    if ResearchSlot.is_repair_complete(entry):
        return false
    ResearchSlot.apply_repair(entry)
    EventBus.item_repaired.emit(entry)
    slot.charge_ap(Economy.REPAIR_AP_COST)
    SaveManager.mark_dirty()
    return true


## Applies one Restore action to [param entry] from the current storage AP pool.
## Guard: sufficient AP, condition >= 0.5, and condition < 1.0. Returns true
## when AP was spent.
func restore_item(entry: ItemEntry) -> bool:
    if entry == null:
        return false
    if slot.storage_ap < Economy.RESTORE_AP_COST:
        return false
    if entry.condition < 0.5:
        return false
    if ResearchSlot.is_restore_complete(entry):
        return false
    # One-way read: get_attribute_value has no reverse dependency on MetaManager.
    var restoration_attr: int = KnowledgeManager.get_attribute_value("restoration")
    ResearchSlot.apply_restore(entry, restoration_attr)
    EventBus.item_restored.emit(entry)
    slot.charge_ap(Economy.RESTORE_AP_COST)
    SaveManager.mark_dirty()
    return true


## Applies one Research action to [param entry] from the current storage AP pool.
## Deterministic — never rolls. Adds (5 + investigation attribute) progress to
## the first unrevealed hidden clue; reveals it once progress >= clue.dc.
## Guard: sufficient AP and at least one unrevealed hidden clue. Returns true
## when AP was spent.
func research_item(entry: ItemEntry) -> bool:
    if entry == null:
        return false
    if slot.storage_ap < Economy.RESEARCH_AP_COST:
        return false
    if entry.condition < 0.5:
        return false
    if not entry.has_unrevealed_hidden():
        return false
    var investigation_attr: int = KnowledgeManager.get_attribute_value("investigation")
    var progress_amount: int = 5 + investigation_attr
    var revealed := entry.advance_research(progress_amount)
    if revealed:
        EventBus.item_revealed.emit(entry)
    slot.charge_ap(Economy.RESEARCH_AP_COST)
    SaveManager.mark_dirty()
    return true

# ══ Vehicle management ════════════════════════════════════════════════════════


## Purchases [param car]: validates non-null, not already owned, and affordable
## deducts cash; appends to the owned roster. Saves on success.
func buy_car(car: CarData) -> bool:
    if car == null:
        return false
    if garage.owns_car(car):
        return false
    if not economy.spend(car.price):
        return false
    garage.add_car(car)
    SaveManager.save()
    return true


func set_active_car(car: CarData) -> void:
    if car == garage.active_car:
        return
    garage.set_active(car)
    SaveManager.mark_dirty()

# ══ Run resolution ════════════════════════════════════════════════════════════


## Resolves the currently active run. Calls RunManager.take_run_result() to
## snapshot economics and auto-reveal surface clues, delegates to resolve_run(),
## clears run state, and emits run_resolved.
##
## Navigation: the caller (run_review_scene) must call SceneRouter.go_to_hub()
## after this returns. The day summary fires when the player chooses Open Shop
## or all slots are exhausted from the hub.
func resolve_current_run() -> void:
    var result: RunResult = RunManager.take_run_result()
    resolve_run(result)
    RunManager.clear_run_state()
    EventBus.run_resolved.emit(result)


## Resolves a completed run from [param result]: applies cash delta, registers
## cargo into storage, stashes run economics as pending for end_day(), and sets
## current_slot to 3 so the player returns to the hub for the evening slot.
## Saves once at the end. Called only from resolve_current_run().
func resolve_run(result: RunResult) -> void:
    economy.apply_delta(
        result.onsite_proceeds - result.paid_price - result.entry_fee - result.fuel_cost,
    )

    # cargo_items already had auto_reveal_all_surface() applied by take_run_result().
    storage.register_entries(result.cargo_items) # no inner save

    # Stash run economics so end_day can fold them into the day summary.
    # Persisted so a quit before end_day doesn't drop them.
    slot.stash_pending_run(result) # no inner save

    # Auction consumed morning + afternoon; player returns for the evening slot.
    slot.set_slot(3) # no inner save

    SaveManager.save() # single commit
