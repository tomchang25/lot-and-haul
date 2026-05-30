# save_manager.gd
# Persistence layer: serializes/deserializes all runtime game state to a JSON file.
extends Node

const SAVE_PATH := "user://save.json"

# Per-category points store. Keys are category IDs (String), values are int.
var category_points: Dictionary = { }
var cash: int = 0
var active_car: CarData = null
var owned_cars: Array[CarData] = []

# Array of Dictionary on disk; deserialized to Array[ItemEntry] on load.
var storage_items: Array = []

var current_day: int = 0
var next_entry_id: int = 0 # monotonically increasing; never reset
var available_locations: Array[LocationData] = []
var unlocked_perks: Array[String] = []
var attribute_levels: Dictionary = { } # attribute_id (String) → int

# ── Slot economy state ────────────────────────────────────────────────────────

## Current slot index within the active day (1 = Morning, 2 = Afternoon,
## 3 = Evening). > 3 means the day is ending — hub auto-calls end_day on entry.
var current_slot: int = 1

## AP remaining in the current storage slot. Refreshed to Economy.STORAGE_AP_MAX
## at the start of each Storage slot; leftover is discarded when the slot ends.
var storage_ap: int = 0

## Selling slots committed to Open Shop this day. Set by begin_open_shop(),
## consumed by end_day() to populate the DaySummary customer count.
var selling_slots_today: int = 0

## Run economics awaiting fold-in by end_day(). Populated by resolve_run() after
## an auction; consumed and cleared by end_day(). Persisted so quitting during
## the evening slot doesn't drop the run breakdown from the day summary. Empty
## when no run is pending. Keys (all int): onsite_proceeds, paid_price,
## entry_fee, fuel_cost, cargo_count.
var pending_run: Dictionary = {}

# ── Nightly customers ─────────────────────────────────────────────────────────

## Customers generated for the current night. Array of Customer dicts on disk.
var nightly_customers: Array[Customer] = []

## Customer sales resolved during the current night, in order. Each entry is a
## plain Dictionary (day, customer_id/name, strategy, item_count, item_ids,
## sale_price). Reset when Open Shop begins (before customer generation).
var customer_sales_today: Array[Dictionary] = []


func save() -> void:
    var serialized_items: Array = []
    for entry: ItemEntry in storage_items:
        serialized_items.append(entry.to_dict())

    var serialized_owned_car_ids: Array[String] = []
    for car: CarData in owned_cars:
        serialized_owned_car_ids.append(car.car_id)
    var serialized_available_location_ids: Array[String] = []
    for loc: LocationData in available_locations:
        serialized_available_location_ids.append(loc.location_id)

    var serialized_customers: Array = []
    for c: Customer in nightly_customers:
        serialized_customers.append(c.to_dict())

    var data := {
        "category_points": category_points,
        "cash": cash,
        "active_car_id": active_car.car_id if active_car != null else "",
        "owned_car_ids": serialized_owned_car_ids,
        "storage_items": serialized_items,
        "current_day": current_day,
        "next_entry_id": next_entry_id,
        "available_location_ids": serialized_available_location_ids,
        "unlocked_perks": unlocked_perks,
        "attribute_levels": attribute_levels,
        "nightly_customers": serialized_customers,
        "customer_sales_today": customer_sales_today,
        "current_slot": current_slot,
        "storage_ap": storage_ap,
        "selling_slots_today": selling_slots_today,
        "pending_run": pending_run,
    }
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        push_error("SaveManager: failed to open %s for writing" % SAVE_PATH)
        return
    file.store_string(JSON.stringify(data))


func load() -> void:
    _read_save_file()


func _read_save_file() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        push_error("SaveManager: failed to open %s for reading" % SAVE_PATH)
        return
    var text := file.get_as_text()
    var parsed: Variant = JSON.parse_string(text)
    if parsed == null or not parsed is Dictionary:
        push_error("SaveManager: invalid save data in %s" % SAVE_PATH)
        return
    if parsed.has("category_points") and parsed["category_points"] is Dictionary:
        category_points = parsed["category_points"]
    if parsed.has("cash") and parsed["cash"] is float:
        cash = int(parsed["cash"])
    if parsed.has("active_car_id") and parsed["active_car_id"] is String:
        active_car = CarRegistry.get_car_by_id(parsed["active_car_id"])
    if parsed.has("owned_car_ids") and parsed["owned_car_ids"] is Array:
        owned_cars = []
        for id: Variant in parsed["owned_car_ids"]:
            if not id is String:
                continue
            var car: CarData = CarRegistry.get_car_by_id(id)
            if car != null:
                owned_cars.append(car)
    if parsed.has("storage_items") and parsed["storage_items"] is Array:
        storage_items = []
        for d: Variant in parsed["storage_items"]:
            if not d is Dictionary:
                continue
            var entry: ItemEntry = ItemEntry.from_dict(d)
            if entry != null:
                entry.apply_storage_migration()
                storage_items.append(entry)
    if parsed.has("current_day") and parsed["current_day"] is float:
        current_day = int(parsed["current_day"])
    if parsed.has("next_entry_id") and parsed["next_entry_id"] is float:
        next_entry_id = int(parsed["next_entry_id"])
    if parsed.has("available_location_ids") and parsed["available_location_ids"] is Array:
        available_locations = []
        for id: Variant in parsed["available_location_ids"]:
            if not id is String:
                continue
            var loc: LocationData = LocationRegistry.get_location_by_id(id)
            if loc != null:
                available_locations.append(loc)
    if parsed.has("unlocked_perks") and parsed["unlocked_perks"] is Array:
        unlocked_perks = []
        for s: Variant in parsed["unlocked_perks"]:
            if s is String:
                unlocked_perks.append(s)
    if parsed.has("attribute_levels") and parsed["attribute_levels"] is Dictionary:
        attribute_levels = { }
        for key: Variant in parsed["attribute_levels"]:
            if key is String and parsed["attribute_levels"][key] is float:
                attribute_levels[key] = int(parsed["attribute_levels"][key])
    elif parsed.has("skill_levels"):
        # Migration: discard old skill_levels, start fresh with defaults.
        attribute_levels = { }
    else:
        attribute_levels = { }

    nightly_customers = []
    if parsed.has("nightly_customers") and parsed["nightly_customers"] is Array:
        for d: Variant in parsed["nightly_customers"]:
            if d is Dictionary:
                nightly_customers.append(Customer.from_dict(d))

    customer_sales_today = []
    if parsed.has("customer_sales_today") and parsed["customer_sales_today"] is Array:
        for rec: Variant in parsed["customer_sales_today"]:
            if rec is Dictionary:
                rec = rec.duplicate()
                if rec.has("item_ids") and rec["item_ids"] is Array:
                    rec["item_ids"] = _intify_array(rec["item_ids"])
                customer_sales_today.append(rec)

    # Slot economy fields (new in time-slot economy; default gracefully for old saves).
    if parsed.has("current_slot") and parsed["current_slot"] is float:
        current_slot = int(parsed["current_slot"])
    if parsed.has("storage_ap") and parsed["storage_ap"] is float:
        storage_ap = int(parsed["storage_ap"])
    if parsed.has("selling_slots_today") and parsed["selling_slots_today"] is float:
        selling_slots_today = int(parsed["selling_slots_today"])

    # Pending run economics: intify on load (JSON numbers parse as float) so
    # end_day() reads plain ints. Absent/empty for saves with no run pending.
    pending_run = {}
    if parsed.has("pending_run") and parsed["pending_run"] is Dictionary:
        for key: Variant in parsed["pending_run"]:
            if key is String and parsed["pending_run"][key] is float:
                pending_run[key] = int(parsed["pending_run"][key])

    # ── Migration: discard legacy research_slots ──────────────────────────────
    # Old saves carried a research_slots array (day-ticker lifecycle). Under the
    # time-slot economy that array is retired. Partial research state is seeded
    # into ItemEntry.research_progress so no player work is lost.
    if parsed.has("research_slots") and parsed["research_slots"] is Array:
        _migrate_research_slots(parsed["research_slots"])

    # Old saves may contain keys from now-removed systems (MarketManager,
    # MerchantRegistry, max_research_slots, etc.) — silently ignore them.


## Converts legacy research_slots entries to ItemEntry.research_progress so
## in-flight research survives the save format change.
##
## REPAIR/RESTORE slots are discarded — condition is already on ItemEntry and
## persists unchanged. For RESEARCH slots with days_spent > 0, each day's
## equivalent progress (5 base, ignoring attribute) is added to the first
## unrevealed hidden clue in order.
func _migrate_research_slots(slots: Array) -> void:
    for d: Variant in slots:
        if not d is Dictionary:
            continue
        var action: String = d.get("action", "")
        if action != "research" and action != "authenticate":
            continue
        var item_id: int = int(d.get("item_id", -1))
        if item_id == -1:
            continue
        var days_spent: int = int(d.get("research_days_spent",
            d.get("authenticate_days_spent", 0)))
        if days_spent <= 0:
            continue
        var entry: ItemEntry = null
        for e: ItemEntry in storage_items:
            if e.id == item_id:
                entry = e
                break
        if entry == null or entry.verified:
            continue
        # Each legacy research day converts to 5 progress points (base rate,
        # no attribute — the pre-slot system had no attribute bonus for research).
        var remaining: int = days_spent * 5
        for clue: ClueData in entry.item_data.clues:
            if clue.type != ClueData.ClueType.HIDDEN:
                continue
            if entry.revealed_clue_ids.has(clue.clue_id):
                continue
            var existing: int = int(entry.research_progress.get(clue.clue_id, 0))
            if existing >= clue.dc:
                continue
            var needed: int = clue.dc - existing
            var apply: int = mini(remaining, needed)
            entry.research_progress[clue.clue_id] = existing + apply
            remaining -= apply
            if remaining <= 0:
                break


static func _intify_array(arr: Array) -> Array:
    var result: Array = []
    for v: Variant in arr:
        if v is float:
            result.append(int(v))
        else:
            result.append(v)
    return result
