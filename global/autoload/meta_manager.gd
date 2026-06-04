# meta_manager.gd
# Hub-phase transactional authority. Holds six domain owners (EconomyOwner,
# GarageOwner, StorageOwner, SlotOwner, ProgressOwner, CustomersOwner); each
# owns its domain's live fields, save payload, and the operations that mutate
# them. Exposes getter-only proxy properties so scenes need no call-site changes.
# Cross-domain transactions (day end, run resolution, customer sale) remain here
# as single coordinated methods that call owner methods and save exactly once.
extends Node

# ── Domain owners ──────────────────────────────────────────────────────────────

var _economy: EconomyOwner
var _garage: GarageOwner
var _storage: StorageOwner
var _slot: SlotOwner
var _progress: ProgressOwner
var _customers: CustomersOwner

# ── Proxy properties ──────────────────────────────────────────────────────────
# Read-only delegates — no setter means no external write path.
# Value-type fields: getter returns the scalar directly (harmless to read).
# Reference-type collections: getter returns a shallow duplicate so callers
# cannot mutate live storage through the returned array.

var cash: int:
    get:
        return _economy.cash

var active_car: CarData:
    get:
        return _garage.active_car

## Returns a shallow duplicate of the owned-car roster (ItemEntry refs shared).
var owned_cars: Array[CarData]:
    get:
        return _garage.owned_cars.duplicate()

## Returns a shallow duplicate of storage (ItemEntry refs shared — read-only).
var storage_items: Array:
    get:
        return _storage.storage_items.duplicate()

var next_entry_id: int:
    get:
        return _storage.next_entry_id

## Returns a shallow duplicate of available locations (LocationData refs shared).
var available_locations: Array[LocationData]:
    get:
        return _progress.available_locations.duplicate()

var current_slot: int:
    get:
        return _slot.current_slot

var storage_ap: int:
    get:
        return _slot.storage_ap

var selling_slots_today: int:
    get:
        return _slot.selling_slots_today

var pending_run: Dictionary:
    get:
        return _slot.pending_run

## Returns a shallow duplicate of the nightly customer list.
var nightly_customers: Array[Customer]:
    get:
        return _customers.nightly_customers.duplicate()

## Returns a shallow duplicate of today's sales ledger.
var customer_sales_today: Array[Dictionary]:
    get:
        return _customers.customer_sales_today.duplicate()

var current_day: int:
    get:
        return _progress.current_day


func _ready() -> void:
    _economy = EconomyOwner.new()
    _garage = GarageOwner.new()
    _storage = StorageOwner.new()
    _slot = SlotOwner.new()
    _progress = ProgressOwner.new()
    _customers = CustomersOwner.new()
    SaveManager.register_sections([_economy, _garage, _storage, _progress, _slot, _customers])

# ══ Cross-autoload cash helper ════════════════════════════════════════════════


## Deducts [param amount] from cash via EconomyOwner.spend(). Does NOT save —
## this is a sub-operation for caller-managed transactions (e.g.
## KnowledgeManager.upgrade_attribute) that save at their own commit point.
## Returns true when the spend succeeded, false when cash was insufficient.
func spend_cash(amount: int) -> bool:
    return _economy.spend(amount)

# ══ Storage registration ══════════════════════════════════════════════════════


## Registers [param entries] into storage and saves. Single-domain transaction.
func register_storage_items(entries: Array[ItemEntry]) -> void:
    _storage.register_entries(entries)
    SaveManager.save()

# ══ Location sampling ═════════════════════════════════════════════════════════


func roll_available_locations() -> void:
    var all := LocationRegistry.get_all_locations()
    all.shuffle()
    var sampled: Array[LocationData] = []
    sampled.assign(all.slice(0, mini(Economy.LOCATION_SAMPLE_SIZE, all.size())))
    _progress.set_locations(sampled)

# ══ Slot economy — hub actions ════════════════════════════════════════════════


## Begins a Storage slot: increments current_slot (consuming it) and refreshes
## storage_ap to a full pool. Call before navigating to the storage scene.
func begin_storage_slot() -> void:
    _slot.set_slot(_slot.current_slot + 1)
    _slot.storage_ap = Economy.STORAGE_AP_MAX
    SaveManager.save()


## Begins an Auction slot: consumes morning + afternoon (slots 1 + 2) by
## advancing current_slot to 3, returning the player to the evening slot.
## Call before navigating to location select.
func begin_auction() -> void:
    assert(_slot.current_slot == 1, "Auction can only begin in slot 1 (Morning)")
    _slot.set_slot(3)
    SaveManager.save()


## Begins an Open Shop session: generates nightly customers scaled to the slots
## committed, clears the nightly sales ledger, and marks current_slot > 3 so
## the hub ends the day on re-entry after customer_sell completes.
##
## [param selling_slots] — 1 (evening only), 2 (afternoon + evening), or
##   3 (full day). Pass 4 - current_slot at the moment Open Shop is chosen.
func begin_open_shop(selling_slots: int) -> void:
    _slot.selling_slots_today = selling_slots
    _slot.set_slot(4) # hub sees > 3 → triggers end_day
    _customers.clear_sales()
    _generate_nightly_customers(selling_slots)
    SaveManager.save()


## Closes out the current calendar day: advances current_day, deducts living
## cost, captures customer sales, folds pending run economics, resets slot
## state, saves, and returns a DaySummary for the day summary scene.
##
## The hub calls this automatically when current_slot > 3.
func end_day() -> DaySummary:
    var summary := DaySummary.new()
    summary.start_day = _progress.current_day
    summary.days_elapsed = 1
    summary.living_cost = Economy.DAILY_BASE_COST

    _progress.advance_day()
    _economy.apply_delta(-Economy.DAILY_BASE_COST)
    summary.end_day = _progress.current_day

    # Capture customer sales recorded during Open Shop.
    for sale in _customers.customer_sales_today:
        summary.customer_sales_total += sale.sale_price
        summary.customer_sales_detail.append(sale.duplicate())

    # Fold pending run economics (set by resolve_run after the auction).
    if not _slot.pending_run.is_empty():
        var pr: Dictionary = _slot.pending_run
        summary.onsite_proceeds = int(pr.get("onsite_proceeds", 0))
        summary.paid_price = int(pr.get("paid_price", 0))
        summary.entry_fee = int(pr.get("entry_fee", 0))
        summary.fuel_cost = int(pr.get("fuel_cost", 0))
        summary.cargo_count = int(pr.get("cargo_count", 0))
        _slot.clear_pending_run()

    # Reset for next day.
    _slot.set_slot(1)
    _slot.storage_ap = 0
    _slot.selling_slots_today = 0
    _progress.clear_locations()

    SaveManager.save()
    return summary

# ══ Nightly customers ═════════════════════════════════════════════════════════


## Generates the nightly customer set scaled by [param selling_slots].
## 1 → 2–3 customers, 2 → 4–6, 3 → 7–10. 0 → no customers.
func _generate_nightly_customers(selling_slots: int) -> void:
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    var count := _selling_slots_to_count(rng, selling_slots)
    _customers.set_customers(
        Customer.generate_for_night(
            rng,
            _storage.storage_items,
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
        customer: Customer = null,
        strategy: String = "",
) -> void:
    var sold_ids: Array = _storage.remove_entries(items)
    for entry: ItemEntry in items:
        KnowledgeManager.add_category_points(
            entry.item_data.category_data,
            entry.item_data.rarity,
            KnowledgeManager.KnowledgeAction.SELL,
        )
    _economy.earn(sale_price)
    _customers.record_sale(_progress.current_day, customer, strategy, sold_ids, sale_price)
    if customer != null:
        _customers.remove_customer(customer)
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
    if _slot.storage_ap < Economy.REPAIR_AP_COST:
        return false
    if ResearchSlot.is_repair_complete(entry):
        return false
    ResearchSlot.apply_repair(entry)
    _slot.charge_ap(Economy.REPAIR_AP_COST)
    SaveManager.save()
    return true


## Applies one Restore action to [param entry] from the current storage AP pool.
## Guard: sufficient AP, condition >= 0.5, and condition < 1.0. Returns true
## when AP was spent.
func restore_item(entry: ItemEntry) -> bool:
    if entry == null:
        return false
    if _slot.storage_ap < Economy.RESTORE_AP_COST:
        return false
    if entry.condition < 0.5:
        return false
    if ResearchSlot.is_restore_complete(entry):
        return false
    ResearchSlot.apply_restore(entry)
    _slot.charge_ap(Economy.RESTORE_AP_COST)
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
    if _slot.storage_ap < Economy.RESEARCH_AP_COST:
        return false
    if entry.condition < 0.5:
        return false
    if not entry.has_unrevealed_hidden():
        return false
    var investigation_attr := KnowledgeManager.get_attribute_value("investigation")
    var progress_amount: int = 5 + investigation_attr
    entry.advance_research(progress_amount)
    _slot.charge_ap(Economy.RESEARCH_AP_COST)
    SaveManager.save()
    return true

# ══ Vehicle management ════════════════════════════════════════════════════════


## Purchases [param car]: validates non-null, not already owned, and affordable;
## deducts cash; appends to the owned roster. Saves on success.
func buy_car(car: CarData) -> bool:
    if car == null:
        return false
    if _garage.owns_car(car):
        return false
    if not _economy.spend(car.price):
        return false
    _garage.add_car(car)
    SaveManager.save()
    return true


func set_active_car(car: CarData) -> void:
    if car == _garage.active_car:
        return
    _garage.set_active(car)
    SaveManager.save()

# ══ Run resolution ════════════════════════════════════════════════════════════


## Resolves a completed run: applies cash, registers cargo, auto-reveals surface
## clues, stores run economics as pending for end_day(), sets current_slot to 3
## so the player returns to the hub for the evening slot, and clears run state.
##
## Navigation: the caller (run_review_scene) must call SceneRouter.go_to_hub()
## after this returns. The day summary fires when the player chooses Open Shop
## or all slots are exhausted from the hub.
func resolve_run(record: RunRecord) -> void:
    _economy.apply_delta(
        record.onsite_proceeds - record.paid_price - record.entry_fee - record.fuel_cost,
    )

    # Auto-reveal all surface clues on hub return (Phase 7).
    for entry: ItemEntry in record.cargo_items:
        entry.auto_reveal_all_surface()

    _storage.register_entries(record.cargo_items) # no inner save

    # Stash run economics so end_day can fold them into the day summary.
    # Persisted so a quit before end_day doesn't drop them.
    _slot.stash_pending_run(record) # no inner save

    # Auction consumed morning + afternoon; player returns for the evening slot.
    _slot.set_slot(3) # no inner save

    RunManager.clear_run_state()
    SaveManager.save() # single commit
