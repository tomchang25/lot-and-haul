# UI Button Hover & Press SFX

## Goal

Give every UI button default hover and press sound feedback through a sound-enabled button type that wires itself, replacing the implicit global click binder. This adds the missing hover layer and fixes the binder's known problems: undiscoverable string-meta opt-out, implicit tree-scanning side effects, and no coverage for dynamically created buttons.

## Requirements

1. Every standard UI button plays a default press sound and a default hover sound with zero per-scene wiring. Sound behavior travels with the button type itself rather than a global scene scan, so buttons instantiated at runtime behave identically to scene-authored ones.
2. Press feedback fires at the moment the button is pushed down, not on release — down-press feedback reads as snappier and matches physical-button expectations.
3. Hover feedback fires on both mouse entry and keyboard/controller focus, so non-mouse navigation gets the same audible feedback. Disabled buttons stay silent for both hover and press.
4. Each button's two sounds are individually replaceable or mutable in the editor inspector, replacing the current string-meta opt-out contract — the meta key has no editor surface and no compile-time check, so scene authors can't discover it.
5. Existing semantic sounds (bid confirm, reveal good/lost) keep playing at their action points rather than moving onto the buttons, because action-point playback stays silent when a press is rejected by validation. The affected buttons mute their default press sound. Exception: the reveal-scene continue button, silent today only as a side effect of the coarse opt-out, gains the default click.
6. The global click binder is removed in the same change as the full migration — no coexistence window, so double-binding between the old and new mechanisms never needs handling.
7. Overall UI loudness comes down via the three-layer mix model: the UI bus default level drops (one knob for "all HUD sounds are too loud"), per-event balance lives in the authored YAML data (hover clearly quieter than press), and generated source audio stays loudness-normalized — mix decisions are never baked into generated audio files, which would require regeneration to retune.

## Design

Trigger matrix:

| Trigger                                  | Sound                                    | Condition      |
| ---------------------------------------- | ---------------------------------------- | -------------- |
| Button pushed down                       | default click (per-button override/mute) | button enabled |
| Mouse enters button                      | default hover (per-button override/mute) | button enabled |
| Button gains focus (keyboard/controller) | default hover (same event)               | button enabled |
| Any trigger on disabled button           | none                                     | —              |

Hover spam control: the hover event gets its own rate-limit key with a tight window, so sweeping the cursor down a column of buttons or holding a navigation key produces a capped tick rate instead of a burst. The same window also swallows the mouse-then-focus double-fire when clicking a button focuses it. Starting values: at most 2 plays per 0.08 s window — tune by ear.

Loudness layering, one job per layer:

- Bus: UI bus default lowered from 0 dB to about -8 dB as the single fix for overall HUD loudness; this also remains the natural hook for a future player-facing UI volume slider.
- Event: hover authored around -8 dB relative to the default click so it reads as texture, not a click. Both values live in the authored YAML so they survive regeneration.
- Source: generated audio files stay normalized to a consistent loudness; they are never edited to fix mix balance.

Migration mapping for the three current opt-outs: the bid button and reveal button mute their default press sound (their semantic sounds remain at the action points); the continue button takes the default click. The hover sound asset already exists in the generated set (produced by the authoring phase, deliberately left unwired) and only needs its event-level volume and limiter settings applied through the authoring data.

## Sketch (non-normative)

Names, paths, and snippets below are illustrative — written from the design conversation, not verified against the codebase. The codebase wins every disagreement.

Proposed button class (proposed home: `game/shared/`, verify against `project_structure.md`):

```gdscript
# sfx_button.gd
# Button subclass that plays default press/hover UI audio events; per-button override or mute via exports.
class_name SfxButton
extends Button

const DEFAULT_PRESS: UiAudioEvent = preload("res://data/tres/audio_events/click.tres")
const DEFAULT_HOVER: UiAudioEvent = preload("res://data/tres/audio_events/button_hover.tres")

@export var press_event: UiAudioEvent = DEFAULT_PRESS
@export var hover_event: UiAudioEvent = DEFAULT_HOVER


func _ready() -> void:
    button_down.connect(_on_press)
    mouse_entered.connect(_on_hover)
    focus_entered.connect(_on_hover)


func _on_press() -> void:
    if disabled or press_event == null:
        return
    AudioManager.play_event(press_event)


func _on_hover() -> void:
    if disabled or hover_event == null:
        return
    AudioManager.play_event(hover_event)
```

Notes recalled, not verified: `button_down` should not fire on a disabled button, so that guard is belt-and-braces; the hover guard is load-bearing because `mouse_entered` does fire while disabled. The preloaded `.tres` are generated artifacts (gitignored) — same fresh-clone caveat as the existing click wiring; the build-automation draft owns that gap.

Authoring data deltas (YAML source of the audio events, regenerate after editing):

- `button_hover`: `volume_db` ≈ -8, `limiter_key: hover`, `max_per_window: 2`, `window_sec: 0.08`.
- `click`: unchanged.
- UI bus default → -8 dB, wherever bus volumes are defined (bus layout resource or audio manager init — verify).

Migration steps:

1. Add the button class.
2. Retype every `Button` node in `.tscn` files to the new class (editor Change Type, or attach the script in the scene source), and switch any runtime `Button.new()` construction to the new class. This is the full-project sweep — 10+ files, confirm before running per the model-tier gate.
3. The three current opt-outs: delete their `set_meta("sfx_click_ignore", true)` lines; bid and reveal buttons get `press_event = null` in the inspector (semantic sounds stay at their action points); the reveal continue button keeps the defaults.
4. Remove the click-binder autoload file and its `project.godot` registration. The scene-change signal it consumed stays if anything else uses it; recalled as sole consumer — verify, and remove the signal too if so.

## Non-Goals

1. No sound feedback for non-button controls (sliders, tab bars, line edits) — a future pass can extend the same pattern.
2. No player-facing volume settings UI changes.
3. No regeneration or editing of source audio files for loudness.
4. No semantic-sound redesign — bid confirm, reveal, sale, and error sounds keep their current call sites and triggers.

## Acceptance Criteria

1. Every button in every scene gives audible hover and press feedback with no per-scene wiring; a button instantiated at runtime behaves identically.
2. Press sound plays on push-down, before release.
3. Keyboard/controller focus produces the same hover feedback as mouse hover; disabled buttons are silent for both triggers.
4. The bid and reveal buttons play exactly their semantic sounds with no doubled default click; the reveal continue button now plays the default click.
5. Sweeping the cursor rapidly across a stack of buttons produces a capped tick burst, not a machine-gun.
6. With default settings, overall UI loudness is audibly lower than today and hover is clearly quieter than press.
7. The global click binder and its string-meta opt-out contract are fully removed; no scene references the old meta key.
