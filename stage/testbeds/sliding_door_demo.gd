# sliding_door_demo.gd
# Sliding-door transition testbed — cycles location backgrounds through the wipe.
#
# Run this scene to test the transition in isolation.
# Press Space / Enter or click to trigger a door wipe and swap to the next
# background. Edit the BACKGROUNDS list to add more placeholder locations.
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────

const BACKGROUNDS: Array[String] = [
    "res://assets/backgrounds/suburban_storage.png",
    "res://assets/backgrounds/midtown_warehouse.png",
]

# ── State ─────────────────────────────────────────────────────────────────────

var _index: int = 0

# ── Node references ───────────────────────────────────────────────────────────

@onready var _background: TextureRect = %Background
@onready var _transition: SlidingDoorTransition = %SlidingDoorTransition


# ══ Lifecycle ══════════════════════════════════════════════════════════════════

func _ready() -> void:
    _apply_background(_index)


func _unhandled_input(event: InputEvent) -> void:
    var advance := event.is_action_pressed("ui_accept")
    if event is InputEventMouseButton and event.pressed:
        advance = true
    if advance:
        _advance()


# ══ Transition ═════════════════════════════════════════════════════════════════

## Wipe to the next background in the list, looping back to the first.
func _advance() -> void:
    var next := (_index + 1) % BACKGROUNDS.size()
    _transition.play(func() -> void: _apply_background(next))


func _apply_background(index: int) -> void:
    _index = index
    _background.texture = load(BACKGROUNDS[index])
