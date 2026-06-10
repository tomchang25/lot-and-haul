# Start Page & Settings Overlay

## Goal

Add a title screen (Start Page) as the game's boot scene, and a settings overlay accessible from both the Start Page and any in-game scene via Escape key.

## Context

The game currently boots directly into the Hub scene. There is no title screen, no way to quit gracefully, and no settings UI for audio/display/gameplay. Adding these is prerequisite to any demo or playtest build.

## Design Decisions

- **Start Page** is a full scene routed through SceneRouter. It becomes the new `main_scene` in `project.godot`.
- **Settings Overlay** is a modal CanvasLayer panel, not a routed scene. It pauses the tree and renders on top of whatever scene is active. No scene transition needed.
- **SettingsStore** is a new autoload that self-persists to `user://settings.json` (not through SaveManager — settings are cross-session, not tied to a game save). It loads before AudioManager in the autoload order so audio bus volumes are applied on boot.
- **In-game toggle**: SettingsStore listens for `ui_settings` input action (mapped to Escape). When pressed, it instantiates the overlay into the scene tree root (or removes it if already open). The overlay's `process_mode` is `PROCESS_MODE_ALWAYS` so it works while the tree is paused.

## Start Page Layout

```
[Title: "Lot & Haul"]

[New Game]     ← shown when no save exists
   — or —
[Continue]     ← shown when save exists (FileAccess.file_exists(SaveManager.SAVE_PATH))

[Settings]     ← opens SettingsOverlay
[Quit]         ← get_tree().quit()
```

"New Game" goes to Hub with default (empty) state. "Continue" loads the existing save (already loaded by GameManager._ready()) and goes to Hub.

## Settings Overlay Sections

### Audio
- Master Volume — HSlider (0–100), controls `AudioServer` bus index 0
- SFX Volume — HSlider, controls the "SFX" bus
- Music Volume — HSlider, controls the "Music" bus

### Display
- Fullscreen toggle — CheckBox, sets `DisplayServer.window_set_mode()`
- (Resolution dropdown deferred — Godot stretch mode handles scaling)

### Gameplay
- Debug Mode — CheckBox, toggles a `debug_mode` bool on SettingsStore. Persisted. Scenes and systems read `SettingsStore.debug_mode` to gate dev-only features (auto-pack cargo, instant auction, reveal overlays, etc.). The checkbox is always visible but has no downstream effects until individual systems wire into it.

### Footer
- Close button — removes overlay, unpauses tree

All slider/toggle changes apply immediately and auto-save to `user://settings.json` on change.

## New Files

| File | Type | Purpose |
| --- | --- | --- |
| `global/autoloads/settings_store.gd` | Autoload | Persists settings to `user://settings.json`. Applies audio bus volumes on `_ready()`. Owns the Escape-key toggle for the overlay. |
| `game/shared/settings_overlay/settings_overlay.gd` | Component script | CanvasLayer modal with Audio/Display/Gameplay sections. Reads/writes SettingsStore. Emits `closed` signal. |
| `game/shared/settings_overlay/settings_overlay.tscn` | Component scene | Node tree for the overlay UI. |
| `game/meta/start/start_page_scene.gd` | Scene script | Title screen: detects save, shows New Game or Continue, Settings, Quit. |
| `game/meta/start/start_page_scene.tscn` | Scene | Node tree for the start page. |

## Modified Files

| File | Change |
| --- | --- |
| `global/autoloads/game_manager/scene_registry.gd` | Add `@export var start_page: PackedScene` |
| `global/autoloads/scene_router/scene_router.gd` | Add `func go_to_start_page()` |
| `project.godot` | Change `main_scene` to start_page_scene. Add SettingsStore autoload before AudioManager. Add `ui_settings` input action mapped to Escape. |
| Scene registry `.tres` (Inspector) | Wire start_page_scene.tscn into the new slot — must be done manually in Godot editor. |

## Autoload Order (updated)

```
EventBus → SettingsStore → AudioManager → ClueRegistry → ItemRegistry → RunManager → CarRegistry → LocationRegistry → CategoryRegistry → SuperCategoryRegistry → SaveManager → KnowledgeManager → MetaManager → SceneRouter → GameManager
```

SettingsStore before AudioManager so bus volumes are set before any audio plays.

## Phases

### Phase 1 — SettingsStore autoload + persistence

Create `settings_store.gd`. Fields: `master_volume` (float 0–1, default 1.0), `sfx_volume`, `music_volume`, `fullscreen` (bool, default false), `debug_mode` (bool, default false). Methods: `save_settings()`, `load_settings()`, `apply_audio()`, `apply_display()`. `_ready()` calls `load_settings()` then `apply_audio()` and `apply_display()`. `_unhandled_input()` toggles the settings overlay on `ui_settings` action.

### Phase 2 — SettingsOverlay component

Create `settings_overlay.tscn/.gd` in `game/shared/settings_overlay/`. CanvasLayer with a centered PanelContainer. Slider per audio bus, fullscreen checkbox, gameplay placeholder, close button. All controls read initial values from SettingsStore on `_ready()` and write back on `value_changed`. `process_mode = PROCESS_MODE_ALWAYS`.

### Phase 3 — Start Page scene

Create `start_page_scene.tscn/.gd` in `game/meta/start/`. Detect save via `FileAccess.file_exists(SaveManager.SAVE_PATH)`. Show appropriate button. Wire Settings button to instantiate SettingsOverlay. Wire Quit to `get_tree().quit()`.

### Phase 4 — Wiring

Add `start_page` to SceneRegistry and SceneRouter. Update `project.godot`: new main_scene, new autoload, new input action. Register the scene in the `.tres` resource (manual step).

## Acceptance Criteria

- Game boots to the Start Page, not Hub.
- With no save: "New Game" button visible, clicking it lands on Hub with default state.
- With a save: "Continue" button visible, clicking it lands on Hub with loaded state.
- Settings overlay opens from Start Page Settings button and from Escape key in any scene.
- Audio sliders change bus volumes in real time; changes persist across restarts.
- Fullscreen toggle works and persists.
- Quit button closes the application.
- RegistryAudit passes (no null scene slots).
