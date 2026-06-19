# location_select_scene.gd
# Location Select screen. Fetches all LocationData from LocationRegistry,
# builds a LocationCard per entry, and — when a card is chosen — constructs
# the active RunStore and advances to the Location Entry scene.
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────

const CANCEL: UiAudioEvent = preload("res://data/tres/audio_events/cancel_dismiss.tres")
const LocationCardScene := preload("res://game/meta/location_select/location_card/location_card.tscn")

# ── Node references ───────────────────────────────────────────────────────────

@onready var _cards_container: HBoxContainer = $RootVBox/CardsScroll/CardsContainer
@onready var _back_button: Button = $RootVBox/BackButton

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _back_button.pressed.connect(_on_back_pressed)
    _back_button.press_event = CANCEL
    _populate_cards()
    Director.register_scene(
        "location_select",
        {
            "cards_container": _cards_container,
            "back_btn": _back_button,
        },
    )

# ══ Population ════════════════════════════════════════════════════════════════


func _populate_cards() -> void:
    if MetaManager.progress.available_locations.is_empty():
        MetaManager.roll_available_locations()
    for location: LocationData in MetaManager.progress.available_locations:
        var card: LocationCard = LocationCardScene.instantiate()
        card.setup(location)
        card.pressed.connect(_on_card_pressed)
        _cards_container.add_child(card)

# ══ Signal handlers ═══════════════════════════════════════════════════════════


func _on_card_pressed(card: LocationCard) -> void:
    var location := card.get_location_data()

    # Create the run store first, then advance the slot + save.
    # This ensures the run snapshot is included in the save so a mid-run quit
    # does not leave the day slot consumed without a restorable run.
    RunManager.create_run_store(location, MetaManager.garage.active_car)
    RunManager.set_resume_target(RunStore.RESUME_LOCATION_ENTRY)
    MetaManager.begin_auction()
    EventBus.tutorial_event.emit(TutorialEvents.LOCATION_SELECTED, { })
    SceneRouter.go_to_location_entry()


func _on_back_pressed() -> void:
    SceneRouter.go_to_hub()
