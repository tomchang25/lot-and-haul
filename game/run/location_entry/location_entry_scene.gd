# location_entry_scene.gd
# Run entry point — Location Entry.
# Assumes RunManager.run_store has already been built by the Location Select
# screen. Shows the location's exterior background, plays the configured
# transition wipe, reveals the interior background, then advances to lot browse.
# No player input required.
extends Control

const SLIDING_DOOR_SCENE := preload("res://game/shared/transition/sliding_door_transition.tscn")
const FADE_SCENE := preload("res://game/shared/transition/fade_transition.tscn")

const ARRIVAL_BEAT := 0.5 ## Seconds held on exterior before the wipe begins.
const INTERIOR_BEAT := 0.5 ## Seconds held on interior after the wipe before advancing.

# ── Node references ───────────────────────────────────────────────────────────

@onready var _texture_rect: TextureRect = $TextureRect

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    assert(RunManager.is_run_active(), "LocationEntry: run is null — Location Select must build it before entering.")
    assert(RunManager.run.location_data != null, "LocationEntry: location_data is null — Location Select must assign a LocationData before entering.")
    _play_arrival.call_deferred()

# ══ Arrival sequence ══════════════════════════════════════════════════════════


## Show exterior → wipe → interior → advance to lot browse.
## Falls back to a plain tween fade when the location has no background textures.
func _play_arrival() -> void:
    var loc: LocationData = RunManager.run.location_data

    if loc.bg_exterior == null and loc.bg_interior == null:
        _play_fallback_fade()
        return

    # Show exterior.
    _texture_rect.texture = loc.bg_exterior
    _texture_rect.modulate.a = 1.0

    # Arrival beat — let the player see the exterior.
    await get_tree().create_timer(ARRIVAL_BEAT).timeout

    # Instantiate the transition.
    var transition: CanvasLayer
    match loc.transition_type:
        "fade":
            transition = FADE_SCENE.instantiate()
        "sliding_door":
            transition = SLIDING_DOOR_SCENE.instantiate()

    add_child(transition)

    # Swap to interior while covered.
    var swap := func() -> void:
        if loc.bg_interior != null:
            _texture_rect.texture = loc.bg_interior

    await transition.play(swap)
    transition.queue_free()

    # Interior beat — hold briefly before advancing.
    await get_tree().create_timer(INTERIOR_BEAT).timeout
    SceneRouter.go_to_lot_browse()


## Legacy fallback: plain alpha tween when no background textures are assigned.
func _play_fallback_fade() -> void:
    var tween := create_tween()
    tween.tween_interval(0.2)
    tween.tween_property(_texture_rect, "modulate:a", 0.0, 0.4)
    tween.tween_property(_texture_rect, "modulate:a", 1.0, 0.4)
    tween.tween_interval(0.2)
    tween.tween_callback(SceneRouter.go_to_lot_browse)
