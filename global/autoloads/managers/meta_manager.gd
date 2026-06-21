# meta_manager.gd
# Hub-phase transactional authority. Holds eight domain stores (EconomyStore,
# GarageStore, StorageStore, SlotStore, ProgressStore, CustomersStore,
# ShopSessionStore, StorageSessionStore); each owns its domain's live fields,
# save payload, and the operations that mutate them. Store references are plain
# public fields — scenes read state directly via MetaManager.economy.cash,
# MetaManager.storage.storage_items, etc. Cross-domain transactions (day end,
# run resolution, customer sale, shop close) remain here as single coordinated
# methods that call store methods and save exactly once.
extends Node

# ── Domain stores ──────────────────────────────────────────────────────────────

var economy: EconomyStore
var garage: GarageStore
var storage: StorageStore
var slot: SlotStore
var progress: ProgressStore
var customers: CustomersStore
var shop_session: ShopSessionStore
var storage_session: StorageSessionStore


func _ready() -> void:
    economy = EconomyStore.new()
    garage = GarageStore.new()
    storage = StorageStore.new()
    slot = SlotStore.new()
    progress = ProgressStore.new()
    customers = CustomersStore.new()
    shop_session = ShopSessionStore.new()
    storage_session = StorageSessionStore.new()


## Re-instantiates all domain stores to their default state. Called by
## SaveManager.reset_providers() during the new-game flow.
func reset() -> void:
    economy = EconomyStore.new()
    economy.earn(Economy.STARTING_CASH)
    garage = GarageStore.new()
    _assign_starter_car()
    storage = StorageStore.new()
    slot = SlotStore.new()
    progress = ProgressStore.new()
    customers = CustomersStore.new()
    shop_session = ShopSessionStore.new()
    storage_session = StorageSessionStore.new()

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
    out[shop_session.section_id()] = shop_session.to_dict()
    out[storage_session.section_id()] = storage_session.to_dict()
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
    shop_session.from_dict(data.get(shop_session.section_id(), { }), ctx)
    storage_session.from_dict(data.get(storage_session.section_id(), { }), ctx)


## Aggregates validate() across all stores. Returns true when all pass.
func validate() -> bool:
    var ok := true
    ok = economy.validate() and ok
    ok = garage.validate() and ok
    ok = storage.validate() and ok
    ok = slot.validate() and ok
    ok = progress.validate() and ok
    ok = customers.validate() and ok
    ok = shop_session.validate() and ok
    ok = storage_session.validate() and ok
    return ok

# ══ Cross-autoload cash helper ════════════════════════════════════════════════


## Deducts [param amount] from cash. Does NOT save — this is a sub-operation for
## caller-managed transactions that save at their own commit point.
## Returns true when the spend succeeded, false when cash was insufficient.
func spend_cash(amount: int) -> bool:
    return economy.spend(amount)


## Marks a scene tutorial as seen and schedules a deferred save.
func mark_tutorial_seen(scene_id: String) -> void:
    progress.mark_tutorial_seen(scene_id)
    SaveManager.mark_dirty()


## Whether onboarding is still pending for this save.
func is_onboarding_pending() -> bool:
    return progress.onboarding_pending


## Marks onboarding as completed and saves. Also marks the basic hub and storage
## tutorials as seen so they do not trigger after onboarding finishes.
func complete_onboarding() -> void:
    progress.mark_onboarding_complete()
    progress.mark_tutorial_seen("hub")
    progress.mark_tutorial_seen("storage")
    SaveManager.mark_dirty()


## Marks onboarding as skipped and saves. Also marks the legacy hub/storage
## tutorials as seen so they do not appear after the onboarding flow ends.
func skip_onboarding() -> void:
    progress.mark_onboarding_complete()
    progress.mark_tutorial_seen("hub")
    progress.mark_tutorial_seen("storage")
    SaveManager.mark_dirty()


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


## Debug-only: clears all items from storage. Deferred save.
func clear_all_storage() -> void:
    storage.clear_all()
    SaveManager.mark_dirty()

# ══ Location sampling ═════════════════════════════════════════════════════════


func roll_available_locations() -> void:
    var all: Array[LocationData] = LocationRegistry.get_all_locations()
    RandomUtils.shuffle(all)
    var sampled: Array[LocationData] = []
    sampled.assign(all.slice(0, mini(Economy.LOCATION_SAMPLE_SIZE, all.size())))
    progress.set_locations(sampled)

# ══ Slot economy — hub actions ════════════════════════════════════════════════


## Advances the current slot by exactly one step: Day → Night → day-ending.
## Does not save — callers commit after their activity-specific setup.
func _advance_slot() -> void:
    slot.set_slot(slot.current_slot + 1)


## Begins a Storage slot: validates Day or Night, refreshes storage_ap to a
## full pool (Day grants the enlarged deep-storage AP budget; Night grants
## base AP), advances one slot, begins the storage session, and saves.
## Call before navigating to the storage scene.
func begin_storage_slot() -> void:
    if slot.current_slot != SlotStore.SLOT_DAY and slot.current_slot != SlotStore.SLOT_NIGHT:
        ToastManager.show_dev_error("Storage can only begin in slot Day or Night, got %d" % slot.current_slot)
        return

    var is_day: bool = slot.current_slot == SlotStore.SLOT_DAY
    var ap: int = roundi(Economy.STORAGE_AP_MAX * Economy.DEEP_STORAGE_AP_MULTIPLIER) if is_day else Economy.STORAGE_AP_MAX
    _advance_slot()
    slot.set_storage_ap(ap)
    var items := storage.storage_items
    var first_id: int = items[0].id if not items.is_empty() else -1
    storage_session.begin(first_id)
    SaveManager.save()


## Ends the active Storage session and clears the resume pointer. Saves
## immediately so boot routing will not re-enter the storage scene.
func close_storage_session() -> void:
    storage_session.clear()
    SaveManager.save()


## Begins an Auction slot: validates Day, advances one slot to Night, and saves.
## Call before navigating to location select.
func begin_auction() -> void:
    if slot.current_slot != SlotStore.SLOT_DAY:
        ToastManager.show_dev_error("Auction can only begin in slot Day, got %d" % slot.current_slot)
        return

    _advance_slot()
    SaveManager.save()


## Begins an Open Shop session: validates Day or Night, generates nightly
## customers scaled to the current slot (Day = larger volume, Night =
## smaller), clears the nightly sales ledger, advances one slot, initialises
## the shop session for the first customer, and saves.
func begin_open_shop() -> void:
    if slot.current_slot != SlotStore.SLOT_DAY and slot.current_slot != SlotStore.SLOT_NIGHT:
        ToastManager.show_dev_error("Open Shop can only begin in slot Day or Night, got %d" % slot.current_slot)
        return

    var is_day: bool = slot.current_slot == SlotStore.SLOT_DAY
    slot.set_selling_slots_today(0)
    customers.clear_sales()
    var count: int
    if is_day:
        count = RandomUtils.randi_range(Economy.DAY_SELLING_CUSTOMER_MIN, Economy.DAY_SELLING_CUSTOMER_MAX)
    else:
        count = RandomUtils.randi_range(Economy.NIGHT_SELLING_CUSTOMER_MIN, Economy.NIGHT_SELLING_CUSTOMER_MAX)
    var new_customers: Array[CustomerEntry] = CustomerGenerator.generate_for_night(storage.storage_items, count)
    customers.set_customers(new_customers)
    _advance_slot()
    if not new_customers.is_empty():
        open_shop_session(new_customers[0])
    else:
        shop_session.clear()
    SaveManager.save()


## Initialises a shop session for [param customer]: sets the active customer,
## clears the placement, and sets the boot-routing pointer to "customer_sell".
## Does not save — caller commits.
func open_shop_session(customer: CustomerEntry) -> void:
    shop_session.set_active_customer(customer.customer_id)
    shop_session.set_placement([])
    shop_session.set_pending_scene(ShopSessionStore.SCENE_CUSTOMER_SELL)


## Records the current [param placement] for [param customer] via the deferred
## save throttle. Called on every customer switch and every grid change.
func update_shop_session(customer: CustomerEntry, placement: Array) -> void:
    shop_session.set_active_customer(
        customer.customer_id if customer != null else "",
    )
    shop_session.set_placement(placement)
    SaveManager.mark_dirty()


## Closes out the current calendar day: advances current_day, deducts living
## cost, captures customer sales, folds pending run economics, resets slot
## state, saves, and returns a DaySummary for the day summary scene.
##
## The hub calls this automatically when current_slot > SlotStore.SLOT_NIGHT.
func end_day() -> DaySummary:
    var summary := DaySummary.new()
    summary.start_day = progress.current_day
    summary.days_elapsed = 1
    summary.living_cost = Economy.DAILY_BASE_COST

    progress.advance_day()
    economy.apply_delta(-Economy.DAILY_BASE_COST)
    summary.bailout_amount = economy.apply_bankruptcy_safety_net()
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
    slot.set_slot(SlotStore.SLOT_DAY)
    slot.set_storage_ap(0)
    slot.set_selling_slots_today(0)
    progress.clear_locations()

    SaveManager.save()
    return summary

# ══ Customer sale ═════════════════════════════════════════════════════════════


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
    EventBus.tutorial_event.emit(TutorialEvents.SALE_COMPLETED, { })
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
    storage_session.set_selected_entry(entry)
    SaveManager.save()
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
    storage_session.set_selected_entry(entry)
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
    storage_session.set_selected_entry(entry)
    SaveManager.save()
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


## Assigns the default starter car ("van_basic") to a fresh garage.
## Called during reset() for new games. This mirrors the doc comment in
## car_data.yaml that describes van_basic as the default active car.
func _assign_starter_car() -> void:
    var starter: CarData = CarRegistry.get_car_by_id(&"van_basic")
    if starter == null:
        ToastManager.show_dev_error("MetaManager: starter car 'van_basic' not found in CarRegistry")
        return
    garage.add_car(starter)
    garage.set_active(starter)

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
    SaveManager.save()
    EventBus.run_resolved.emit(result)


## Resolves a completed run from [param result]: applies cash delta, registers
## cargo into storage, stashes run economics as pending for end_day(), and sets
## current_slot to 3 so the player returns to the hub for the evening slot.
## Saves once at the end when called without an active run. resolve_current_run()
## clears RunManager state first, then saves so settled runs do not resume.
func resolve_run(result: RunResult) -> void:
    economy.apply_delta(
        result.onsite_proceeds - result.paid_price - result.entry_fee - result.fuel_cost,
    )

    # cargo_items already had auto_reveal_all_surface() applied by take_run_result().
    storage.register_entries(result.cargo_items) # no inner save

    # Stash run economics so end_day can fold them into the day summary.
    # Persisted so a quit before end_day doesn't drop them.
    slot.stash_pending_run(result) # no inner save

    # Auction consumed the Day slot; player returns for the Night slot.
    slot.set_slot(SlotStore.SLOT_NIGHT) # no inner save

    if not RunManager.is_run_active():
        SaveManager.save() # single commit for synthetic/direct callers
