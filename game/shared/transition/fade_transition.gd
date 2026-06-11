# fade_transition.gd
# Reusable overlay — a full-screen fade-to-black-and-back wipe. Fades to black,
# runs an optional swap callback while fully covered, then fades back to reveal
# whatever changed underneath.
extends CanvasLayer

class_name FadeTransition

# ── Signals ───────────────────────────────────────────────────────────────────

## Emitted the instant the overlay is fully opaque (safe to swap content).
signal covered
## Emitted after the overlay finishes fading out and hides itself.
signal finished

# ── Exports ───────────────────────────────────────────────────────────────────

@export var fade_in_time: float = 0.4 ## Seconds to fade from clear to black.
@export var hold_time: float = 0.05 ## Seconds held fully black before fading out.
@export var fade_out_time: float = 0.4 ## Seconds to fade from black to clear.

# ── State ─────────────────────────────────────────────────────────────────────

var _playing: bool = false

# ── Node references ───────────────────────────────────────────────────────────

@onready var _overlay: ColorRect = %Overlay

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    visible = false
    _overlay.modulate.a = 0.0

# ══ Common API ════════════════════════════════════════════════════════════════


## Play a full darken → swap → brighten cycle. `on_covered`, if valid, is called
## once while the screen is fully black — swap the background/scene there.
## Awaitable: `await transition.play(...)` resumes after the fade completes.
## Re-entrant calls while already playing are ignored.
func play(on_covered: Callable = Callable()) -> void:
    if _playing:
        return
    _playing = true

    visible = true
    _overlay.modulate.a = 0.0

    # ── Darken ────────────────────────────────────────────────────────────────
    var darken := create_tween()
    darken.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
    darken.tween_property(_overlay, "modulate:a", 1.0, fade_in_time)
    await darken.finished

    # ── Covered: run the swap ─────────────────────────────────────────────────
    covered.emit()
    if on_covered.is_valid():
        on_covered.call()
    if hold_time > 0.0:
        await get_tree().create_timer(hold_time).timeout

    # ── Brighten ──────────────────────────────────────────────────────────────
    var brighten := create_tween()
    brighten.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
    brighten.tween_property(_overlay, "modulate:a", 0.0, fade_out_time)
    await brighten.finished

    visible = false
    _playing = false
    finished.emit()
