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
var max_research_slots: int = 4
var next_entry_id: int = 0 # monotonically increasing; never reset
var research_slots: Array = [] # Array of plain Dictionaries (ResearchSlot)
var available_locations: Array[LocationData] = []
var unlocked_perks: Array[String] = []
var attribute_levels: Dictionary = { } # attribute_id (String) → int

## Customers generated for the current night. Array of Customer dicts on disk.
var nightly_customers: Array[Customer] = []


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
        "max_research_slots": max_research_slots,
        "next_entry_id": next_entry_id,
        "research_slots": research_slots,
        "available_location_ids": serialized_available_location_ids,
        "unlocked_perks": unlocked_perks,
        "attribute_levels": attribute_levels,
        "nightly_customers": serialized_customers,
        "merchant_negotiations_used_today": _build_negotiation_dict(),
        "merchant_orders": _build_order_dict(),
        "next_order_id": MerchantRegistry.next_order_id,
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
    if parsed.has("max_research_slots") and parsed["max_research_slots"] is float:
        max_research_slots = int(parsed["max_research_slots"])
    if parsed.has("next_entry_id") and parsed["next_entry_id"] is float:
        next_entry_id = int(parsed["next_entry_id"])
    if parsed.has("research_slots") and parsed["research_slots"] is Array:
        research_slots = []
        for d: Variant in parsed["research_slots"]:
            if d is Dictionary:
                research_slots.append(d)
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

    if parsed.has("nightly_customers") and parsed["nightly_customers"] is Array:
        nightly_customers = []
        for d: Variant in parsed["nightly_customers"]:
            if d is Dictionary:
                nightly_customers.append(Customer.from_dict(d))

    # Old saves may contain "super_cat_means" and "category_factors_today" keys
    # from the removed MarketManager system — silently ignore them.

    if parsed.has("merchant_negotiations_used_today") and parsed["merchant_negotiations_used_today"] is Dictionary:
        var neg_dict: Dictionary = parsed["merchant_negotiations_used_today"]
        for key: Variant in neg_dict:
            if key is String and neg_dict[key] is float:
                var m: MerchantData = MerchantRegistry.get_merchant_by_id(key)
                if m != null:
                    m.negotiations_used_today = int(neg_dict[key])

    if parsed.has("next_order_id") and parsed["next_order_id"] is float:
        MerchantRegistry.next_order_id = int(parsed["next_order_id"])

    if parsed.has("merchant_orders") and parsed["merchant_orders"] is Dictionary:
        var orders_dict: Dictionary = parsed["merchant_orders"]
        for key: Variant in orders_dict:
            if not key is String:
                continue
            var m: MerchantData = MerchantRegistry.get_merchant_by_id(key)
            if m == null:
                continue
            var entry: Variant = orders_dict[key]
            if not entry is Dictionary:
                continue
            if entry.has("last_roll_day") and entry["last_roll_day"] is float:
                m.last_order_roll_day = int(entry["last_roll_day"])
            if entry.has("active_orders") and entry["active_orders"] is Array:
                m.active_orders = []
                for od: Variant in entry["active_orders"]:
                    if od is Dictionary:
                        m.active_orders.append(SpecialOrder.from_dict(od))
            if entry.has("completed_order_ids") and entry["completed_order_ids"] is Array:
                m.completed_order_ids = []
                for cid: Variant in entry["completed_order_ids"]:
                    if cid is String:
                        m.completed_order_ids.append(cid)

    var valid_ids: Array = []
    for entry: ItemEntry in storage_items:
        valid_ids.append(entry.id)

    # Clear orphaned UNLOCK slots (Phase 5 migration, no longer relevant).
    for i: int in range(research_slots.size()):
        var d: Dictionary = research_slots[i]
        if d.get("action", "") != "unlock":
            continue
        research_slots[i] = ResearchSlot.new().to_dict()

    ResearchSlot.purge_orphaned(research_slots, valid_ids)


func _build_negotiation_dict() -> Dictionary:
    var result: Dictionary = { }
    for m: MerchantData in MerchantRegistry.get_all_merchants():
        if m.negotiations_used_today > 0:
            result[m.merchant_id] = m.negotiations_used_today
    return result


func _build_order_dict() -> Dictionary:
    var result: Dictionary = { }
    for m: MerchantData in MerchantRegistry.get_all_merchants():
        if m.active_orders.is_empty() and m.completed_order_ids.is_empty() and m.last_order_roll_day < 0:
            continue
        var order_dicts: Array = []
        for order: SpecialOrder in m.active_orders:
            order_dicts.append(order.to_dict())
        result[m.merchant_id] = {
            "last_roll_day": m.last_order_roll_day,
            "active_orders": order_dicts,
            "completed_order_ids": m.completed_order_ids,
        }
    return result
