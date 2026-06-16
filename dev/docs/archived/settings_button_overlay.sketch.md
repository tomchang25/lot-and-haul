# Settings Button Overlay

## Goal

Add a visible settings entry point across gameplay screens so players can open the existing settings menu without knowing the keyboard shortcut. The feature should reuse the current settings overlay behavior and keep the button as a static scene component rather than constructing it from scene scripts.

## Requirements

1. Gameplay screens show a consistent settings/config button overlay that is easy to reach with mouse or touch.
2. Pressing the button opens the existing settings menu and preserves the current pause/resume behavior of that menu.
3. The button is authored as a reusable static component so each owning screen places it in the scene tree directly, matching the project's persistent-node source rule.
4. The button does not duplicate settings UI, settings storage, audio/display logic, or keyboard shortcut handling.
5. The first pass covers player-facing gameplay screens, not shared subcomponents or transient popups, so the overlay is present at screen level only.

## Design

The settings button is global-feeling chrome, but it is still a fixed piece of each gameplay screen's UI shell. Treat it as a reusable scene component that each screen owns for its full lifetime. The component should sit above normal screen content, use a consistent top-right placement, and leave the existing modal settings overlay responsible for pausing, editing settings, saving settings, and closing.

## Sketch (non-normative)

Proposed component shape:

```text
game/shared/settings_button_overlay/
  settings_button_overlay.tscn
  settings_button_overlay.gd
```

The scene can use a `CanvasLayer` root so the button consistently floats above each screen's layout. A child full-rect `Control` can ignore mouse input outside the button, and the button itself can be anchored to the top-right with a touch-friendly size such as 44x44.

Illustrative script shape:

```gdscript
# settings_button_overlay.gd
# Static scene overlay that opens the project settings menu from gameplay screens.
extends CanvasLayer

@onready var _settings_button: Button = %SettingsButton

func _ready() -> void:
    _settings_button.pressed.connect(_on_settings_pressed)

func _on_settings_pressed() -> void:
    SettingsStore.toggle_overlay()
```

The component scene should define all persistent nodes in `.tscn`; the script should only connect the button signal and call the existing settings entry point. If the project already uses a shared audio button script, the settings button can use it the same way as other static buttons.

Proposed placement list for the first pass:

1. Run-phase screen scenes under `game/run/`: location entry, lot browse, inspection, auction, reveal, cargo, and run review.
2. Meta gameplay screen scenes under `game/meta/`: hub, storage, knowledge, vehicle/car selection/shop, location select, customer sell, and day summary.
3. Exclude start/menu screens unless they already behave like gameplay screens.
4. Exclude reusable child components, popups, item cards, rows, and panels; they should inherit the screen-level overlay from their owner.

Each owning screen should instance the component in its `.tscn`, for example:

```text
[ext_resource type="PackedScene" path="res://game/shared/settings_button_overlay/settings_button_overlay.tscn" id="..."]

[node name="SettingsButtonOverlay" parent="." instance=ExtResource("...")]
```

Use a high enough layer to stay above normal screen content but below the actual settings modal. If the current settings modal uses a much higher layer, the button overlay can safely stay at a lower layer so it disappears behind the modal when settings are open.

## Non-Goals

1. Do not redesign the settings menu.
2. Do not create a new global HUD/navigation system.
3. Do not replace the existing keyboard shortcut.
4. Do not dynamically add the button from scene scripts or an autoload in this pass.

## Acceptance Criteria

1. Every covered gameplay screen has a visible settings/config button in the same screen position.
2. Pressing the button opens the existing settings menu.
3. Closing the settings menu returns to the same screen and resumes gameplay behavior as before.
4. Screens do not create the settings button at runtime from their own scripts.
5. Shared child components and popups do not each add their own duplicate settings button.
