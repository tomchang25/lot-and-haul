extends Node

const SAVE_PATH := "user://save.json"

# Per-category mastery store. Keys are category IDs (String), values are int.
var mastery: Dictionary = {}
var gold: int = 0
var active_car_id: String = "van_basic"


func save() -> void:
    var data := {
        "mastery": mastery,
        "gold": gold,
        "active_car_id": active_car_id,
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
    if parsed.has("mastery") and parsed["mastery"] is Dictionary:
        mastery = parsed["mastery"]
    if parsed.has("gold") and parsed["gold"] is float:
        gold = int(parsed["gold"])
    if parsed.has("active_car_id") and parsed["active_car_id"] is String:
        active_car_id = parsed["active_car_id"]


func load_active_car() -> CarConfig:
    var path := "res://data/cars/%s.tres" % active_car_id
    if not ResourceLoader.exists(path):
        push_error("SaveManager: car resource not found at %s" % path)
        return null
    return ResourceLoader.load(path) as CarConfig
