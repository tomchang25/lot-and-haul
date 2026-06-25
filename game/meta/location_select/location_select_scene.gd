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
    Director.register_scene(
        "location_select",
        {
            "cards_container": _cards_container,
            "back_btn": _back_button,
        },
    )
    _populate_cards()
    GameplayOverride.override_changed.connect(_on_location_override_changed)

# ══ Population ════════════════════════════════════════════════════════════════


func _populate_cards() -> void:
    var locations: Array[LocationData] = []

    # During the first onboarding run, show ONLY the tutorial location.
    # Never fall through to normal pool — tutorial must gate to the intended path.
    if GameplayOverride.is_active(GameplayOverride.FORCED_TUTORIAL_LOCATION):
        var tutorial_loc := LocationRegistry.get_tutorial_location()
        if tutorial_loc == null:
            ToastManager.show_dev_error("LocationSelectScene: no tutorial location found for onboarding")
            return
        locations = [tutorial_loc]
    else:
        # Normal path: roll and sample available locations.
        if MetaSystem.progress.available_locations.is_empty():
            MetaSystem.roll_available_locations()
        locations = MetaSystem.progress.available_locations

    for location: LocationData in locations:
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
    RunSystem.create_run_store(location, MetaSystem.garage.active_car)
    RunSystem.set_resume_target(RunStore.RESUME_LOCATION_ENTRY)
    MetaSystem.begin_auction()
    EventBus.tutorial_event.emit(TutorialEvents.LOCATION_SELECTED, { })
    SceneRouter.go_to_location_entry()


func _on_location_override_changed(id: StringName, active: bool, _payload: Variant) -> void:
    if id == GameplayOverride.FORCED_TUTORIAL_LOCATION and not active:
        # Clear and repopulate cards when the forced tutorial location override drops.
        for child in _cards_container.get_children():
            child.queue_free()
        _populate_cards()


func _on_back_pressed() -> void:
    SceneRouter.go_to_hub()
