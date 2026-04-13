# location_select.gd
# Location Select screen. Fetches all LocationData from LocationRegistry,
# builds a LocationCard per entry, and — when a card is chosen — constructs
# the active RunRecord and advances to the Location Entry scene.
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────

const LocationCardScene := preload("res://game/meta/location_select/location_card/location_card.tscn")

# ── Node references ───────────────────────────────────────────────────────────

@onready var _cards_container: HBoxContainer = $RootVBox/CardsScroll/CardsContainer
@onready var _back_button: Button = $RootVBox/BackButton

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _back_button.pressed.connect(_on_back_pressed)
    _populate_cards()

# ══ Population ════════════════════════════════════════════════════════════════


func _populate_cards() -> void:
    if SaveManager.available_location_ids.is_empty():
        SaveManager.roll_available_locations()
    for loc_id: String in SaveManager.available_location_ids:
        var location := LocationRegistry.get_location(loc_id)
        if location == null:
            push_warning("LocationSelect: unknown location id '%s'" % loc_id)
            continue
        var card: LocationCard = LocationCardScene.instantiate()
        card.setup(location)
        card.pressed.connect(_on_card_pressed)
        _cards_container.add_child(card)

# ══ Signal handlers ═══════════════════════════════════════════════════════════


func _on_card_pressed(card: LocationCard) -> void:
    var location := card.get_location_data()
    RunManager.run_record = RunRecord.create(
        location,
        SaveManager.active_car,
    )
    GameManager.go_to_location_entry()


func _on_back_pressed() -> void:
    GameManager.go_to_hub()
