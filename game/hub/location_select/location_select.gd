# location_select.gd
# Location Select screen. Scans the locations directory for LocationData .tres
# files, builds a LocationCard per entry, and — when a card is chosen —
# constructs the active RunRecord and advances to the Location Entry scene.
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────

const LOCATIONS_DIR: String = "res://data/tres/locations"
const LocationCardScene := preload("res://game/hub/location_select/location_card/location_card.tscn")

# ── Node references ───────────────────────────────────────────────────────────

@onready var _cards_container: HBoxContainer = $RootVBox/CardsContainer
@onready var _back_button: Button = $RootVBox/BackButton

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _back_button.pressed.connect(_on_back_pressed)
    _populate_cards()

# ══ Population ════════════════════════════════════════════════════════════════


func _populate_cards() -> void:
    var locations := _load_all_locations()
    for location: LocationData in locations:
        var card: LocationCard = LocationCardScene.instantiate()
        _cards_container.add_child(card)
        card.setup(location)
        card.pressed.connect(_on_card_pressed)


func _load_all_locations() -> Array[LocationData]:
    var result: Array[LocationData] = []
    var dir := DirAccess.open(LOCATIONS_DIR)
    if dir == null:
        push_error("LocationSelect: could not open " + LOCATIONS_DIR)
        return result

    dir.list_dir_begin()
    var file_name := dir.get_next()
    while file_name != "":
        if not dir.current_is_dir() and file_name.ends_with(".tres"):
            var path := LOCATIONS_DIR + "/" + file_name
            var resource := load(path)
            if resource is LocationData:
                result.append(resource as LocationData)
        file_name = dir.get_next()
    dir.list_dir_end()
    return result

# ══ Signal handlers ═══════════════════════════════════════════════════════════


func _on_card_pressed(card: LocationCard) -> void:
    var location := card.get_location_data()
    RunManager.run_record = RunRecord.create(
        location,
        SaveManager.load_active_car(),
    )
    GameManager.go_to_location_entry()


func _on_back_pressed() -> void:
    GameManager.go_to_hub()
