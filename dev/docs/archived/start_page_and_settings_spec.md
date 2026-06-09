# Start Page & Settings Overlay — Implementation Spec

Parent plan: `dev/docs/plans/start_page_and_settings.md`

---

## 1. SettingsStore Autoload

**File:** `global/autoloads/settings_store.gd`

**Not a gameplay Store** — this is project-wide persistent config, not runtime game state. It lives in `global/autoloads/` alongside `save_manager.gd`, self-persists to its own JSON file, and is not registered with SaveManager.

### Fields

```gdscript
const SETTINGS_PATH := "user://settings.json"

const SettingsOverlayScene := preload("res://game/shared/settings_overlay/settings_overlay.tscn")

var master_volume: float = 1.0   # 0.0–1.0
var sfx_volume: float = 1.0
var music_volume: float = 1.0
var fullscreen: bool = false
var debug_mode: bool = false

var _overlay_instance: CanvasLayer = null
```

### Persistence Format

`user://settings.json`:

```json
{
    "master_volume": 1.0,
    "sfx_volume": 1.0,
    "music_volume": 1.0,
    "fullscreen": false,
    "debug_mode": false
}
```

### Methods

```gdscript
func _ready() -> void:
    load_settings()
    apply_audio()
    apply_display()


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_settings"):
        toggle_overlay()
        get_viewport().set_input_as_handled()


## Write current field values to user://settings.json.
func save_settings() -> void:
    var data := {
        "master_volume": master_volume,
        "sfx_volume": sfx_volume,
        "music_volume": music_volume,
        "fullscreen": fullscreen,
        "debug_mode": debug_mode,
    }
    var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
    if file == null:
        push_error("SettingsStore: cannot write %s" % SETTINGS_PATH)
        return
    file.store_string(JSON.stringify(data))


## Read settings from disk. Missing keys keep their defaults.
func load_settings() -> void:
    if not FileAccess.file_exists(SETTINGS_PATH):
        return
    var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
    if file == null:
        push_error("SettingsStore: cannot read %s" % SETTINGS_PATH)
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if parsed == null or not parsed is Dictionary:
        push_error("SettingsStore: invalid settings data")
        return
    var d: Dictionary = parsed
    master_volume = d.get("master_volume", 1.0)
    sfx_volume = d.get("sfx_volume", 1.0)
    music_volume = d.get("music_volume", 1.0)
    fullscreen = d.get("fullscreen", false)
    debug_mode = d.get("debug_mode", false)


## Apply volume fields to AudioServer buses by name.
func apply_audio() -> void:
    _set_bus_volume("Master", master_volume)
    _set_bus_volume("SFX", sfx_volume)
    _set_bus_volume("Music", music_volume)


## Apply display settings (fullscreen).
func apply_display() -> void:
    if fullscreen:
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
    else:
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


## Open or close the settings overlay.
func toggle_overlay() -> void:
    if _overlay_instance != null:
        _close_overlay()
    else:
        _open_overlay()


func _open_overlay() -> void:
    if _overlay_instance != null:
        return
    _overlay_instance = SettingsOverlayScene.instantiate()
    _overlay_instance.closed.connect(_close_overlay)
    get_tree().root.add_child(_overlay_instance)
    get_tree().paused = true


func _close_overlay() -> void:
    if _overlay_instance == null:
        return
    _overlay_instance.queue_free()
    _overlay_instance = null
    get_tree().paused = false


func _set_bus_volume(bus_name: String, linear: float) -> void:
    var idx := AudioServer.get_bus_index(bus_name)
    if idx == -1:
        push_error("SettingsStore: bus '%s' not found" % bus_name)
        return
    AudioServer.set_bus_volume_db(idx, linear_to_db(linear))
    AudioServer.set_bus_mute(idx, linear <= 0.0)
```

### Autoload Registration

In `project.godot`, insert SettingsStore **before** AudioManager:

```ini
[autoload]

EventBus="*uid://d2nkmaq8dlf5g"
SettingsStore="*res://global/autoloads/settings_store.gd"
AudioManager="*uid://bhhaho37wph5e"
...
```

### Input Action

Add to `project.godot` under `[input]` (create section if absent):

```ini
[input]

ui_settings={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194305,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
```

Keycode `4194305` = `KEY_ESCAPE`. Alternatively, add via Editor → Project Settings → Input Map — this is the recommended path since the serialized form is fragile.

---

## 2. SettingsOverlay Component

**Files:** `game/shared/settings_overlay/settings_overlay.gd`, `game/shared/settings_overlay/settings_overlay.tscn`

### Node Tree

```
SettingsOverlay (CanvasLayer)                    ← layer = 100, process_mode = ALWAYS
  Background (ColorRect)                         ← full rect, Color(0, 0, 0, 0.6), mouse_filter = STOP
  CenterContainer (CenterContainer)              ← full rect
    Panel (PanelContainer)                       ← min_size (480, 0)
      MarginContainer (MarginContainer)          ← margins 24 all sides
        RootVBox (VBoxContainer)                 ← separation = 20
          TitleLabel (Label)                     ← "Settings", font_size = 28, h_align = CENTER
          HSeparator

          AudioLabel (Label)                     ← "Audio", font_size = 20
          MasterRow (HBoxContainer)              ← separation = 12
            MasterLabel (Label)                  ← "Master", min_size.x = 80
            MasterSlider (HSlider)               ← min_value = 0, max_value = 100, step = 1, size_flags_h = EXPAND_FILL
            MasterValueLabel (Label)             ← "100%", min_size.x = 48, h_align = RIGHT
          SfxRow (HBoxContainer)
            SfxLabel (Label)                     ← "SFX"
            SfxSlider (HSlider)
            SfxValueLabel (Label)                ← "100%"
          MusicRow (HBoxContainer)
            MusicLabel (Label)                   ← "Music"
            MusicSlider (HSlider)
            MusicValueLabel (Label)              ← "100%"

          HSeparator2

          DisplayLabel (Label)                   ← "Display", font_size = 20
          FullscreenRow (HBoxContainer)
            FullscreenLabel (Label)              ← "Fullscreen"
            FullscreenCheck (CheckBox)

          HSeparator3

          GameplayLabel (Label)                  ← "Gameplay", font_size = 20
          DebugRow (HBoxContainer)
            DebugLabel (Label)                   ← "Debug Mode"
            DebugCheck (CheckBox)

          HSeparator4

          CloseButton (Button)                   ← "Close", min_size = (120, 40), size_flags_h = SHRINK_CENTER
```

All HSlider rows share the same structure: Label (fixed width 80) + HSlider (expand fill, 0–100 step 1) + value Label (fixed width 48, right-aligned). The three rows are identical in layout — only the node names and labels differ.

### Script

```gdscript
# settings_overlay.gd
# Settings overlay — modal CanvasLayer for audio, display, and gameplay settings.
extends CanvasLayer

signal closed

# ── Node references ───────────────────────────────────────────────────────────

@onready var _master_slider: HSlider = $CenterContainer/Panel/MarginContainer/RootVBox/MasterRow/MasterSlider
@onready var _master_value_label: Label = $CenterContainer/Panel/MarginContainer/RootVBox/MasterRow/MasterValueLabel
@onready var _sfx_slider: HSlider = $CenterContainer/Panel/MarginContainer/RootVBox/SfxRow/SfxSlider
@onready var _sfx_value_label: Label = $CenterContainer/Panel/MarginContainer/RootVBox/SfxRow/SfxValueLabel
@onready var _music_slider: HSlider = $CenterContainer/Panel/MarginContainer/RootVBox/MusicRow/MusicSlider
@onready var _music_value_label: Label = $CenterContainer/Panel/MarginContainer/RootVBox/MusicRow/MusicValueLabel
@onready var _fullscreen_check: CheckBox = $CenterContainer/Panel/MarginContainer/RootVBox/FullscreenRow/FullscreenCheck
@onready var _debug_check: CheckBox = $CenterContainer/Panel/MarginContainer/RootVBox/DebugRow/DebugCheck
@onready var _close_btn: Button = $CenterContainer/Panel/MarginContainer/RootVBox/CloseButton


# ══ Lifecycle ═════════════════════════════════════════════════════════════════

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS

    _master_slider.value_changed.connect(_on_master_changed)
    _sfx_slider.value_changed.connect(_on_sfx_changed)
    _music_slider.value_changed.connect(_on_music_changed)
    _fullscreen_check.toggled.connect(_on_fullscreen_toggled)
    _debug_check.toggled.connect(_on_debug_toggled)
    _close_btn.pressed.connect(_on_close_pressed)

    _apply()


# ══ Signal handlers ════════════════════════════════════════════════════════════

func _on_master_changed(value: float) -> void:
    SettingsStore.master_volume = value / 100.0
    _master_value_label.text = "%d%%" % int(value)
    SettingsStore.apply_audio()
    SettingsStore.save_settings()


func _on_sfx_changed(value: float) -> void:
    SettingsStore.sfx_volume = value / 100.0
    _sfx_value_label.text = "%d%%" % int(value)
    SettingsStore.apply_audio()
    SettingsStore.save_settings()


func _on_music_changed(value: float) -> void:
    SettingsStore.music_volume = value / 100.0
    _music_value_label.text = "%d%%" % int(value)
    SettingsStore.apply_audio()
    SettingsStore.save_settings()


func _on_fullscreen_toggled(pressed: bool) -> void:
    SettingsStore.fullscreen = pressed
    SettingsStore.apply_display()
    SettingsStore.save_settings()


func _on_debug_toggled(pressed: bool) -> void:
    SettingsStore.debug_mode = pressed
    SettingsStore.save_settings()


func _on_close_pressed() -> void:
    closed.emit()


# ══ View ══════════════════════════════════════════════════════════════════════

func _apply() -> void:
    _master_slider.set_value_no_signal(SettingsStore.master_volume * 100.0)
    _master_value_label.text = "%d%%" % int(SettingsStore.master_volume * 100.0)
    _sfx_slider.set_value_no_signal(SettingsStore.sfx_volume * 100.0)
    _sfx_value_label.text = "%d%%" % int(SettingsStore.sfx_volume * 100.0)
    _music_slider.set_value_no_signal(SettingsStore.music_volume * 100.0)
    _music_value_label.text = "%d%%" % int(SettingsStore.music_volume * 100.0)
    _fullscreen_check.set_pressed_no_signal(SettingsStore.fullscreen)
    _debug_check.set_pressed_no_signal(SettingsStore.debug_mode)
```

### Key Behavior Notes

- `process_mode = PROCESS_MODE_ALWAYS` is set in `_ready()` so the overlay responds to input while the tree is paused.
- Sliders use `set_value_no_signal()` in `_apply()` to avoid triggering `value_changed` during initialization.
- `FullscreenCheck` and `DebugCheck` use `set_pressed_no_signal()` for the same reason.
- The `closed` signal is how SettingsStore knows to free the overlay and unpause. The overlay does not free itself.
- The Background ColorRect with `mouse_filter = STOP` blocks clicks from reaching the scene behind the overlay.

---

## 3. Start Page Scene

**Files:** `game/meta/start/start_page_scene.gd`, `game/meta/start/start_page_scene.tscn`

### Node Tree

```
StartPageScene (Control)                         ← full rect
  Background (ColorRect)                         ← full rect, Color(0.08, 0.08, 0.1, 1), mouse_filter = IGNORE
  RootVBox (VBoxContainer)                       ← full rect, separation = 32, alignment = CENTER
    TitleLabel (Label)                           ← "Lot & Haul", font_size = 48, h_align = CENTER
    ButtonsVBox (VBoxContainer)                  ← size_flags_h = SHRINK_CENTER, separation = 16
      PlayButton (Button)                        ← " - ", min_size = (280, 56), font_size = 20
      SettingsButton (Button)                    ← "Settings", min_size = (280, 56), font_size = 20
      QuitButton (Button)                        ← "Quit", min_size = (280, 56), font_size = 20
```

PlayButton text is `" - "` placeholder per the block scene architecture standard — `_apply()` sets it to "New Game" or "Continue" at runtime.

### Script

```gdscript
# start_page_scene.gd
# Start Page — Title screen with New Game / Continue, Settings, and Quit.
extends Control

# ── Node references ───────────────────────────────────────────────────────────

@onready var _play_btn: Button = $RootVBox/ButtonsVBox/PlayButton
@onready var _settings_btn: Button = $RootVBox/ButtonsVBox/SettingsButton
@onready var _quit_btn: Button = $RootVBox/ButtonsVBox/QuitButton

# ── State ─────────────────────────────────────────────────────────────────────

var _has_save: bool = false


# ══ Lifecycle ═════════════════════════════════════════════════════════════════

func _ready() -> void:
    _play_btn.pressed.connect(_on_play_pressed)
    _settings_btn.pressed.connect(_on_settings_pressed)
    _quit_btn.pressed.connect(_on_quit_pressed)

    _has_save = FileAccess.file_exists(SaveManager.SAVE_PATH)
    _apply()


# ══ Signal handlers ════════════════════════════════════════════════════════════

func _on_play_pressed() -> void:
    SceneRouter.go_to_hub()


func _on_settings_pressed() -> void:
    SettingsStore.toggle_overlay()


func _on_quit_pressed() -> void:
    get_tree().quit()


# ══ View ══════════════════════════════════════════════════════════════════════

func _apply() -> void:
    _play_btn.text = "Continue" if _has_save else "New Game"
```

### Behavior Notes

- `_on_play_pressed()` always calls `go_to_hub()`. GameManager has already run `SaveManager.load()` in its `_ready()` (autoloads fire before the main scene). If a save existed, state is populated; if not, managers hold defaults.
- Settings button delegates to `SettingsStore.toggle_overlay()` — the same path as the Escape key. This avoids duplicating overlay management logic.
- No `_unhandled_input` for Escape here — SettingsStore already handles that globally.

---

## 4. SceneRegistry Change

**File:** `global/autoloads/game_manager/scene_registry.gd`

Add one line at the end of the exports:

```gdscript
@export var start_page: PackedScene
```

Full file after change:

```gdscript
class_name SceneRegistry
extends Resource

@export var location_select: PackedScene
@export var location_entry: PackedScene
@export var lot_browse: PackedScene
@export var inspection: PackedScene
@export var auction: PackedScene
@export var reveal: PackedScene
@export var cargo: PackedScene
@export var run_review: PackedScene
@export var hub: PackedScene
@export var storage: PackedScene
@export var day_summary: PackedScene
@export var attribute_panel: PackedScene
@export var knowledge_hub: PackedScene
@export var mastery_panel: PackedScene
@export var perk_panel: PackedScene
@export var vehicle_hub: PackedScene
@export var car_select: PackedScene
@export var car_shop: PackedScene
@export var customer_sell: PackedScene
@export var start_page: PackedScene
```

### Manual Editor Step

After the `.tscn` files exist, open the SceneRegistry `.tres` resource in the Godot inspector and drag `start_page_scene.tscn` into the `start_page` slot. RegistryAudit will flag it as null until this is done.

---

## 5. SceneRouter Change

**File:** `global/autoloads/scene_router/scene_router.gd`

Add at the bottom of the scene transition section:

```gdscript
func go_to_start_page() -> void:
    get_tree().change_scene_to_packed(scenes.start_page)
```

---

## 6. project.godot Changes

Three changes:

### 6a. main_scene

Change the `main_scene` line to point to `start_page_scene.tscn`. The uid will be assigned by Godot when the `.tscn` is created — use the uid Godot generates:

```ini
run/main_scene="uid://<start_page_uid>"
```

If creating the `.tscn` by hand (not via the editor), use the path form:

```ini
run/main_scene="res://game/meta/start/start_page_scene.tscn"
```

### 6b. Autoload insertion

Insert SettingsStore between EventBus and AudioManager:

```ini
[autoload]

EventBus="*uid://d2nkmaq8dlf5g"
SettingsStore="*res://global/autoloads/settings_store.gd"
AudioManager="*uid://bhhaho37wph5e"
... (rest unchanged)
```

### 6c. Input action

Add an `[input]` section (does not currently exist in the file). The safest way is via Editor → Project Settings → Input Map: add action `ui_settings`, bind to Escape key. Alternatively, append to project.godot — but the serialized InputEventKey is fragile across Godot versions, so the editor path is preferred.

---

## 7. Implementation Order

| Step | What | Depends on |
| --- | --- | --- |
| 1 | Create `settings_store.gd`, register autoload in `project.godot` | — |
| 2 | Add `ui_settings` input action (via editor or project.godot) | — |
| 3 | Create `settings_overlay.tscn` + `.gd` | Step 1 (reads SettingsStore) |
| 4 | Create `start_page_scene.tscn` + `.gd` | Step 1, Step 3 |
| 5 | Add `start_page` to SceneRegistry + SceneRouter | — |
| 6 | Change `main_scene` in project.godot | Step 4 |
| 7 | Wire `start_page_scene.tscn` into SceneRegistry `.tres` in editor | Step 4, Step 5 |
| 8 | Run linter on all new/changed `.gd` files | All above |
| 9 | Boot test: verify start page → continue/new game → hub, settings overlay from both start page and in-game Escape, audio sliders, fullscreen toggle, debug checkbox, quit | All above |

Steps 1–2 can be done in parallel. Step 7 is a manual editor step. Step 8 per `dev/agent_rules/lint_before_finish.md`.

---

## 8. What This Spec Does Not Cover

- Downstream debug_mode wiring into gameplay systems — the checkbox and persistence are in scope; actual dev features (auto-pack cargo, instant auction, etc.) are separate work tracked under `TODO.md ## Draft → Debug Mode`.
- Resolution selection dropdown — deferred; Godot's stretch mode handles scaling.
- Main menu music/background art — not in v1.
- "New Game" confirmation dialog when a save already exists — currently the start page shows only "Continue" when a save exists. A future iteration could show both buttons with a confirm prompt for "New Game" to overwrite.
