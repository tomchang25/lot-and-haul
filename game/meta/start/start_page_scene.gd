# start_page_scene.gd
# Start Page — Title screen with New Game / Continue, Settings, and Quit.
extends Control

# ── Node references ───────────────────────────────────────────────────────────

@onready var _play_btn: Button = %PlayButton
@onready var _settings_btn: Button = %SettingsButton
@onready var _quit_btn: Button = %QuitButton

# ── State ─────────────────────────────────────────────────────────────────────

var _has_save: bool = false


# ══ Lifecycle ══════════════════════════════════════════════════════════════════

func _ready() -> void:
    _play_btn.pressed.connect(_on_play_pressed)
    _settings_btn.pressed.connect(_on_settings_pressed)
    _quit_btn.pressed.connect(_on_quit_pressed)

    _has_save = SaveManager.has_save()
    _apply()


# ══ Signal handlers ════════════════════════════════════════════════════════════

func _on_play_pressed() -> void:
    SceneRouter.go_to_hub()


func _on_settings_pressed() -> void:
    SettingsStore.toggle_overlay()


func _on_quit_pressed() -> void:
    get_tree().quit()


# ══ View ═══════════════════════════════════════════════════════════════════════

func _apply() -> void:
    _play_btn.text = "Continue" if _has_save else "New Game"
