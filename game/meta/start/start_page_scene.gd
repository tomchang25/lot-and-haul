# start_page_scene.gd
# Start Page — Title screen with New Game / Continue, Settings, and Quit.
extends Control

# ── Node references ───────────────────────────────────────────────────────────

@onready var _continue_btn: Button = %ContinueButton
@onready var _new_game_btn: Button = %NewGameButton
@onready var _settings_btn: Button = %SettingsButton
@onready var _quit_btn: Button = %QuitButton
@onready var _confirm_dialog: ConfirmationDialog = %NewGameConfirmDialog

# ── State ─────────────────────────────────────────────────────────────────────

var _has_save: bool = false

# ══ Lifecycle ══════════════════════════════════════════════════════════════════


func _ready() -> void:
    _continue_btn.pressed.connect(_on_continue_pressed)
    _new_game_btn.pressed.connect(_on_new_game_pressed)
    _settings_btn.pressed.connect(_on_settings_pressed)
    _quit_btn.pressed.connect(_on_quit_pressed)
    _confirm_dialog.confirmed.connect(_on_new_game_confirmed)

    _has_save = SaveManager.has_save()
    _apply()

# ══ Signal handlers ════════════════════════════════════════════════════════════


## Continue: load existing save (already loaded at boot) and navigate to hub.
func _on_continue_pressed() -> void:
    SceneRouter.go_to_hub()


## New Game: show confirmation dialog if save data exists, otherwise proceed
## directly.
func _on_new_game_pressed() -> void:
    if _has_save:
        _confirm_dialog.popup_centered()
    else:
        _execute_new_game()


## Confirmation accepted: wipe, reset, and start fresh.
func _on_new_game_confirmed() -> void:
    _execute_new_game()


## Settings: toggle the settings overlay (defined in SettingsStore).
func _on_settings_pressed() -> void:
    SettingsStore.toggle_overlay()


func _on_quit_pressed() -> void:
    get_tree().quit()

# ══ New Game flow ══════════════════════════════════════════════════════════════


## Wipes all save data, resets all persistent stores to defaults, clears session
## state, writes a fresh save, and navigates to hub.
func _execute_new_game() -> void:
    SaveManager.wipe_all()
    SaveManager.reset_providers()
    RunManager.clear_run_state()
    SaveManager.save()
    SceneRouter.go_to_hub()

# ══ View ═══════════════════════════════════════════════════════════════════════


func _apply() -> void:
    _continue_btn.visible = _has_save
