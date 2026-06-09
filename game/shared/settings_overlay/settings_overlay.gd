# settings_overlay.gd
# Settings overlay — modal CanvasLayer for audio, display, and gameplay settings.
extends CanvasLayer

signal closed

# ── Node references ───────────────────────────────────────────────────────────

@onready var _master_slider: HSlider = %MasterSlider
@onready var _master_value_label: Label = %MasterValueLabel
@onready var _sfx_slider: HSlider = %SfxSlider
@onready var _sfx_value_label: Label = %SfxValueLabel
@onready var _music_slider: HSlider = %MusicSlider
@onready var _music_value_label: Label = %MusicValueLabel
@onready var _fullscreen_check: CheckBox = %FullscreenCheck
@onready var _debug_check: CheckBox = %DebugCheck
@onready var _close_btn: Button = %CloseButton


# ══ Lifecycle ══════════════════════════════════════════════════════════════════

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


# ══ View ═══════════════════════════════════════════════════════════════════════

func _apply() -> void:
    _master_slider.set_value_no_signal(SettingsStore.master_volume * 100.0)
    _master_value_label.text = "%d%%" % int(SettingsStore.master_volume * 100.0)
    _sfx_slider.set_value_no_signal(SettingsStore.sfx_volume * 100.0)
    _sfx_value_label.text = "%d%%" % int(SettingsStore.sfx_volume * 100.0)
    _music_slider.set_value_no_signal(SettingsStore.music_volume * 100.0)
    _music_value_label.text = "%d%%" % int(SettingsStore.music_volume * 100.0)
    _fullscreen_check.set_pressed_no_signal(SettingsStore.fullscreen)
    _debug_check.set_pressed_no_signal(SettingsStore.debug_mode)
