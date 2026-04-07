extends Node

const SAVE_PATH := "user://save.json"

# Per-category points store. Keys are category IDs (String), values are int.
var category_points: Dictionary = { }
var cash: int = 0
var active_car_id: String = "van_basic"

# Array of Dictionary on disk; deserialized to Array[ItemEntry] on load.
var storage_items: Array = []


func save() -> void:
    var serialized_items: Array = []
    for entry: ItemEntry in storage_items:
        serialized_items.append(_serialize_item(entry))

    var data := {
        "category_points": category_points,
        "cash": cash,
        "active_car_id": active_car_id,
        "storage_items": serialized_items,
    }
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        push_error("SaveManager: failed to open %s for writing" % SAVE_PATH)
        return
    file.store_string(JSON.stringify(data))


func load() -> void:
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
    if parsed.has("storage_items") and parsed["storage_items"] is Array:
        storage_items = []
        for d: Variant in parsed["storage_items"]:
            if not d is Dictionary:
                continue
            var entry: ItemEntry = _deserialize_item(d)
            if entry != null:
                storage_items.append(entry)


func load_active_car() -> CarConfig:
    var path := "res://data/cars/%s.tres" % active_car_id
    if not ResourceLoader.exists(path):
        push_error("SaveManager: car resource not found at %s" % path)
        return null
    return ResourceLoader.load(path) as CarConfig


func _serialize_item(entry: ItemEntry) -> Dictionary:
    var km: Array = []
    for v: float in entry.knowledge_min:
        km.append(v)
    var kmax: Array = []
    for v: float in entry.knowledge_max:
        kmax.append(v)
    return {
        "item_id": entry.item_data.item_id,
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
    return entry
