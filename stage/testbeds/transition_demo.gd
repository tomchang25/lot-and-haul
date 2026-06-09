# transition_demo.gd
# Transition testbed — cycles location backgrounds through different wipe effects.
#
# Run this scene to test transitions in isolation.
# Press Space / Enter or click to trigger a wipe and swap to the next background.
# Press Tab or the number keys (1, 2) to switch transition effect.
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────

const BACKGROUNDS: Array[String] = [
    "res://assets/backgrounds/suburban_storage.png",
    "res://assets/backgrounds/midtown_warehouse.png",
]

const TRANSITION_SCENES: Dictionary = {
    "sliding_door": preload("res://game/shared/transition/sliding_door_transition.tscn"),
    "fade": preload("res://game/shared/transition/fade_transition.tscn"),
}

## Ordered list of transition keys for cycling with Tab.
const TRANSITION_ORDER: Array[String] = ["sliding_door", "fade"]

# ── State ─────────────────────────────────────────────────────────────────────

var _bg_index: int = 0
var _transition_key: String = "sliding_door"
var _transition_node: Node = null

# ── Node references ───────────────────────────────────────────────────────────

@onready var _background: TextureRect = %Background
@onready var _effect_label: Label = %EffectLabel
@onready var _hint_label: Label = %HintLabel


# ══ Lifecycle ═════════════════════════════════════════════════════════════════

func _ready() -> void:
    _apply_background(_bg_index)
    _set_transition("sliding_door")


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_TAB:
                _cycle_transition()
                return
            KEY_1:
                _set_transition("sliding_door")
                return
            KEY_2:
                _set_transition("fade")
                return

    var advance := event.is_action_pressed("ui_accept")
    if event is InputEventMouseButton and event.pressed:
        advance = true
    if advance:
        _advance()


# ══ Transition ════════════════════════════════════════════════════════════════

## Wipe to the next background in the list, looping back to the first.
func _advance() -> void:
    if _transition_node == null:
        return
    var next := (_bg_index + 1) % BACKGROUNDS.size()
    _transition_node.play(func() -> void: _apply_background(next))


func _apply_background(index: int) -> void:
    _bg_index = index
    _background.texture = load(BACKGROUNDS[index])


# ══ Effect switching ══════════════════════════════════════════════════════════

## Cycle to the next transition effect in the ordered list.
func _cycle_transition() -> void:
    var idx := TRANSITION_ORDER.find(_transition_key)
    var next_idx := (idx + 1) % TRANSITION_ORDER.size()
    _set_transition(TRANSITION_ORDER[next_idx])


## Switch to a specific transition effect by key.
func _set_transition(key: String) -> void:
    if not TRANSITION_SCENES.has(key):
        return
    if key == _transition_key and _transition_node != null:
        return

    # Remove old transition node.
    if _transition_node != null:
        _transition_node.queue_free()
        _transition_node = null

    _transition_key = key
    _transition_node = TRANSITION_SCENES[key].instantiate()
    add_child(_transition_node)
    _update_labels()


func _update_labels() -> void:
    _effect_label.text = "Effect: %s  [Tab to cycle, 1–%d to pick]" % [
        _transition_key, TRANSITION_ORDER.size()
    ]
    # Build the full list with a marker on the active one.
    var parts: PackedStringArray = []
    for i in TRANSITION_ORDER.size():
        var k := TRANSITION_ORDER[i]
        var marker := " <" if k == _transition_key else ""
        parts.append("  %d. %s%s" % [i + 1, k, marker])
    _hint_label.text = "Space / click = wipe | Tab = cycle effect\n" + "\n".join(parts)
