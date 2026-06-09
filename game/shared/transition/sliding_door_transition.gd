# sliding_door_transition.gd
# Reusable overlay — a two-panel black "sliding door" wipe. Closes to cover the
# screen, runs an optional swap callback while fully covered, then opens to
# reveal whatever changed underneath. Resolution-independent (anchored halves).
extends CanvasLayer
class_name SlidingDoorTransition

# ── Signals ───────────────────────────────────────────────────────────────────

## Emitted the instant the doors fully cover the screen (safe to swap content).
signal covered
## Emitted after the doors finish opening and the overlay hides itself.
signal finished

# ── Exports ───────────────────────────────────────────────────────────────────

@export var close_time: float = 0.35  ## Seconds for the doors to slide shut.
@export var hold_time: float = 0.05   ## Seconds held fully covered before opening.
@export var open_time: float = 0.35   ## Seconds for the doors to slide open.

# ── State ─────────────────────────────────────────────────────────────────────

var _playing: bool = false

# ── Node references ───────────────────────────────────────────────────────────

@onready var _left_door: ColorRect = %LeftDoor
@onready var _right_door: ColorRect = %RightDoor


# ══ Lifecycle ══════════════════════════════════════════════════════════════════

func _ready() -> void:
    visible = false
    _snap_open()


# ══ Common API ═════════════════════════════════════════════════════════════════

## Play a full close → swap → open cycle. `on_covered`, if valid, is called once
## while the screen is fully black — swap the background/scene there. Awaitable:
## `await transition.play(...)` resumes after the doors have reopened. Re-entrant
## calls while already playing are ignored.
func play(on_covered: Callable = Callable()) -> void:
    if _playing:
        return
    _playing = true

    visible = true
    _snap_open()

    var hw := get_viewport().get_visible_rect().size.x / 2.0

    # ── Close (expand from edges toward center) ───────────────────────────────
    var close := create_tween().set_parallel(true)
    close.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
    close.tween_property(_left_door, "offset_right", hw, close_time)
    close.tween_property(_right_door, "offset_left", -hw, close_time)
    await close.finished

    # ── Covered: run the swap ────────────────────────────────────────────────────
    covered.emit()
    if on_covered.is_valid():
        on_covered.call()
    if hold_time > 0.0:
        await get_tree().create_timer(hold_time).timeout

    # ── Open (retract back to edges) ──────────────────────────────────────────
    var open := create_tween().set_parallel(true)
    open.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
    open.tween_property(_left_door, "offset_right", 0.0, open_time)
    open.tween_property(_right_door, "offset_left", 0.0, open_time)
    await open.finished

    visible = false
    _playing = false
    finished.emit()


# ══ Doors ══════════════════════════════════════════════════════════════════════

## Snap both doors to zero width (open) without animating.
func _snap_open() -> void:
    _left_door.offset_right = 0.0
    _right_door.offset_left = 0.0
