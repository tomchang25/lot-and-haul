extends Node

const SAVE_PATH := "user://save.json"

# Per-category points store. Keys are category IDs (String), values are int.
var category_points: Dictionary = { }
var cash: int = 0
var active_car_id: String = "van_basic"

# Ids of every car the player owns. The starter "van_basic" is appended on
# first load (and as a migration for saves that predate this field) via the
# logic at the end of `load()`. Follows the same id-string pattern as
# active_car_id; resolve to CarData through `owned_cars` below.
var owned_car_ids: Array[String] = []

# The CarData resource for the currently active car. Resolved lazily via
# CarRegistry so the save file only has to persist the id.
var active_car: CarData:
    get:
        return CarRegistry.get_car(active_car_id)

# Mirrors `active_car`: resolve each owned id via CarRegistry, skipping any
# that fail to resolve (e.g. if a car was removed from the data pipeline).
var owned_cars: Array[CarData]:
    get:
        var result: Array[CarData] = []
        for id: String in owned_car_ids:
            var car: CarData = CarRegistry.get_car(id)
            if car != null:
                result.append(car)
        return result

# Array of Dictionary on disk; deserialized to Array[ItemEntry] on load.
var storage_items: Array = []

var current_day: int = 0
var max_concurrent_actions: int = 2
var next_entry_id: int = 0 # monotonically increasing; never reset
var active_actions: Array = [] # Array of plain Dictionaries
var available_location_ids: Array[String] = []
var unlocked_perks: Array[String] = []
var skill_levels: Dictionary = { } # skill_id (String) → int


func save() -> void:
    var serialized_items: Array = []
    for entry: ItemEntry in storage_items:
        serialized_items.append(_serialize_item(entry))

    var data := {
        "category_points": category_points,
        "cash": cash,
        "active_car_id": active_car_id,
        "owned_car_ids": owned_car_ids,
        "storage_items": serialized_items,
        "current_day": current_day,
        "max_concurrent_actions": max_concurrent_actions,
        "next_entry_id": next_entry_id,
        "active_actions": active_actions,
        "available_location_ids": available_location_ids,
        "unlocked_perks": unlocked_perks,
        "skill_levels": skill_levels,
        "super_cat_means": MarketManager.super_cat_means,
        "category_factors_today": MarketManager.category_factors_today,
        "merchant_negotiations_used_today": _build_negotiation_dict(),
        "merchant_orders": _build_order_dict(),
        "next_order_id": MerchantRegistry._next_order_id,
    }
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        push_error("SaveManager: failed to open %s for writing" % SAVE_PATH)
        return
    file.store_string(JSON.stringify(data))


func load() -> void:
    _read_save_file()
    _migrate_owned_cars()


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
        active_car_id = parsed["active_car_id"]
    if parsed.has("owned_car_ids") and parsed["owned_car_ids"] is Array:
        owned_car_ids = []
        for id: Variant in parsed["owned_car_ids"]:
            if id is String:
                owned_car_ids.append(id)
    if parsed.has("storage_items") and parsed["storage_items"] is Array:
        storage_items = []
        for d: Variant in parsed["storage_items"]:
            if not d is Dictionary:
                continue
            var entry: ItemEntry = _deserialize_item(d)
            if entry != null:
                storage_items.append(entry)
    if parsed.has("current_day") and parsed["current_day"] is float:
        current_day = int(parsed["current_day"])
    if parsed.has("max_concurrent_actions") and parsed["max_concurrent_actions"] is float:
        max_concurrent_actions = int(parsed["max_concurrent_actions"])
    if parsed.has("next_entry_id") and parsed["next_entry_id"] is float:
        next_entry_id = int(parsed["next_entry_id"])
    if parsed.has("active_actions") and parsed["active_actions"] is Array:
        active_actions = []
        for d: Variant in parsed["active_actions"]:
            if d is Dictionary:
                active_actions.append(d)
    if parsed.has("available_location_ids") and parsed["available_location_ids"] is Array:
        available_location_ids = []
        for id: Variant in parsed["available_location_ids"]:
            if id is String:
                available_location_ids.append(id)
    if parsed.has("unlocked_perks") and parsed["unlocked_perks"] is Array:
        unlocked_perks = []
        for s: Variant in parsed["unlocked_perks"]:
            if s is String:
                unlocked_perks.append(s)
    if parsed.has("skill_levels") and parsed["skill_levels"] is Dictionary:
        skill_levels = { }
        for key: Variant in parsed["skill_levels"]:
            if key is String and parsed["skill_levels"][key] is float:
                skill_levels[key] = int(parsed["skill_levels"][key])
    else:
        skill_levels = { }

    if parsed.has("super_cat_means") and parsed["super_cat_means"] is Dictionary:
        MarketManager.super_cat_means = { }
        for key: Variant in parsed["super_cat_means"]:
            if key is String and parsed["super_cat_means"][key] is float:
                MarketManager.super_cat_means[key] = float(parsed["super_cat_means"][key])

    if parsed.has("category_factors_today") and parsed["category_factors_today"] is Dictionary:
        MarketManager.category_factors_today = { }
        for key: Variant in parsed["category_factors_today"]:
            if key is String and parsed["category_factors_today"][key] is float:
                MarketManager.category_factors_today[key] = float(parsed["category_factors_today"][key])

    if parsed.has("merchant_negotiations_used_today") and parsed["merchant_negotiations_used_today"] is Dictionary:
        var neg_dict: Dictionary = parsed["merchant_negotiations_used_today"]
        for key: Variant in neg_dict:
            if key is String and neg_dict[key] is float:
                var m: MerchantData = MerchantRegistry.get_merchant(key)
                if m != null:
                    m.negotiations_used_today = int(neg_dict[key])

    if parsed.has("next_order_id") and parsed["next_order_id"] is float:
        MerchantRegistry._next_order_id = int(parsed["next_order_id"])

    if parsed.has("merchant_orders") and parsed["merchant_orders"] is Dictionary:
        var orders_dict: Dictionary = parsed["merchant_orders"]
        for key: Variant in orders_dict:
            if not key is String:
                continue
            var m: MerchantData = MerchantRegistry.get_merchant(key)
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


# Idempotent migration: guarantees a fresh save gets the starter van, and
# repairs saves whose `active_car_id` no longer resolves against CarRegistry
# (e.g. the car was removed from the data pipeline). Safe to re-run.
func _migrate_owned_cars() -> void:
    if owned_car_ids.is_empty():
        owned_car_ids.append("van_basic")
    if active_car_id.is_empty() or CarRegistry.get_car(active_car_id) == null:
        active_car_id = owned_car_ids[0]


# Attempts to purchase `car` using `SaveManager.cash`.
# Returns false if the player cannot afford it or already owns it.
# On success, debits the price, appends the id, persists, and returns true.
func buy_car(car: CarData) -> bool:
    if car == null:
        return false
    if owned_car_ids.has(car.car_id):
        return false
    if cash < car.price:
        return false
    cash -= car.price
    owned_car_ids.append(car.car_id)
    save()
    return true


# Assigns a unique id to entry, appends it to storage_items, and saves.
# Always call this instead of appending to storage_items directly.
func register_storage_item(entry: ItemEntry) -> void:
    entry.id = next_entry_id
    next_entry_id += 1
    storage_items.append(entry)


func register_storage_items(entries: Array[ItemEntry]) -> void:
    for entry: ItemEntry in entries:
        register_storage_item(entry)

    save()

# ══ Location sampling ════════════════════════════════════════════════════════


func roll_available_locations() -> void:
    var all := LocationRegistry.get_all_locations()
    var ids: Array[String] = []
    for loc: LocationData in all:
        ids.append(loc.location_id)
    ids.shuffle()
    available_location_ids = ids.slice(0, mini(Economy.LOCATION_SAMPLE_SIZE, ids.size()))

# ══ Day advancement (sole chokepoint) ════════════════════════════════════════


func advance_days(days: int) -> DaySummary:
    var summary := DaySummary.new()
    if days <= 0:
        summary.start_day = current_day
        summary.end_day = current_day
        summary.days_elapsed = 0
        return summary

    summary.start_day = current_day
    summary.days_elapsed = days
    summary.living_cost = days * Economy.DAILY_BASE_COST

    current_day += days
    cash -= summary.living_cost

    summary.completed_actions = _tick_actions(days)
    summary.end_day = current_day

    MarketManager.advance_market(days)
    MerchantRegistry.advance_day()
    available_location_ids.clear()

    save()
    return summary


func _tick_actions(days: int) -> Array[Dictionary]:
    var completions: Array[Dictionary] = []
    var remaining: Array = []

    for d: Dictionary in active_actions:
        var action := ActiveActionEntry.from_dict(d)
        action.days_remaining -= days
        if action.days_remaining <= 0:
            _apply_action_effect(action)
            var entry: ItemEntry = _find_storage_entry(action.item_id)
            completions.append(
                {
                    "name": entry.display_name if entry != null else "Unknown",
                    "effect": _action_effect_label(action.action_type),
                    "action_type": action.action_type,
                },
            )
        else:
            remaining.append(action.to_dict())

    active_actions = remaining
    return completions


func _apply_action_effect(action: ActiveActionEntry) -> void:
    var entry: ItemEntry = _find_storage_entry(action.item_id)
    if entry == null:
        return
    match action.action_type:
        ActiveActionEntry.ActionType.MARKET_RESEARCH:
            KnowledgeManager.apply_market_research(entry)
        ActiveActionEntry.ActionType.UNLOCK:
            entry.layer_index += 1
            KnowledgeManager.add_category_points(
                entry.item_data.category_data.category_id,
                entry.item_data.rarity,
                KnowledgeManager.KnowledgeAction.REVEAL,
            )


func _find_storage_entry(item_id: int) -> ItemEntry:
    for entry: ItemEntry in storage_items:
        if entry.id == item_id:
            return entry
    return null


func _action_effect_label(type: ActiveActionEntry.ActionType) -> String:
    match type:
        ActiveActionEntry.ActionType.MARKET_RESEARCH:
            return "Market Research done"
        ActiveActionEntry.ActionType.UNLOCK:
            return "Layer unlocked"
    return "Done"


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


func _serialize_item(entry: ItemEntry) -> Dictionary:
    var km: Array = []
    for v: float in entry.knowledge_min:
        km.append(v)
    var kmax: Array = []
    for v: float in entry.knowledge_max:
        kmax.append(v)
    return {
        "item_id": entry.item_data.item_id,
        "id": entry.id,
        "layer_index": entry.layer_index,
        "condition": entry.condition,
        "potential_inspect_level": entry.potential_inspect_level,
        "condition_inspect_level": entry.condition_inspect_level,
        "knowledge_min": km,
        "knowledge_max": kmax,
    }


func _deserialize_item(d: Dictionary) -> ItemEntry:
    var item_data: ItemData = ItemRegistry.get_item(d["item_id"])
    if item_data == null:
        push_error("SaveManager: item not found for id '%s'" % d["item_id"])
        return null
    var entry := ItemEntry.new()
    entry.item_data = item_data
    entry.layer_index = int(d["layer_index"])
    entry.condition = float(d["condition"])
    entry.potential_inspect_level = int(d["potential_inspect_level"])
    entry.condition_inspect_level = int(d["condition_inspect_level"])
    var km: Array = d["knowledge_min"]
    var kmax: Array = d["knowledge_max"]
    entry.knowledge_min.resize(km.size())
    entry.knowledge_max.resize(kmax.size())
    for i in range(km.size()):
        entry.knowledge_min[i] = float(km[i])
    for i in range(kmax.size()):
        entry.knowledge_max[i] = float(kmax[i])
    if d.has("id"):
        entry.id = int(d["id"])
    return entry
