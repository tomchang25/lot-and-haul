# start_page_scene.gd
# Start Page — Title screen with New Game / Load Game, Settings, and Quit.
# Shows a slot picker overlay for selecting which save slot to use.
extends Control

enum PickerMode { NEW_GAME, LOAD }

const CONFIRM: UiAudioEvent = preload("res://data/tres/audio_events/confirm.tres")
const CANCEL: UiAudioEvent = preload("res://data/tres/audio_events/cancel_dismiss.tres")

# ── Node references ───────────────────────────────────────────────────────────

@onready var _new_game_btn: Button = %NewGameButton
@onready var _load_game_btn: Button = %LoadGameButton
@onready var _settings_btn: Button = %SettingsButton
@onready var _quit_btn: Button = %QuitButton
@onready var _confirm_dialog: ConfirmationDialog = %NewGameConfirmDialog
@onready var _overwrite_dialog: ConfirmationDialog = %OverwriteDialog

@onready var _buttons_vbox: VBoxContainer = %ButtonsVBox
@onready var _picker_panel: Panel = %SlotPickerPanel
@onready var _picker_title: Label = %PickerTitle
@onready var _picker_back_btn: Button = %PickerBackButton
@onready var _slot_btns: Array[Button] = [
    %Slot1Button,
    %Slot2Button,
    %Slot3Button,
]

# ── State ─────────────────────────────────────────────────────────────────────

var _picker_mode: PickerMode = PickerMode.NEW_GAME
var _summaries: Array = [] # 3 elements, null or dict
var _pending_slot: int = 0 # slot being confirmed for overwrite

# ══ Lifecycle ══════════════════════════════════════════════════════════════════


func _ready() -> void:
    _new_game_btn.pressed.connect(_on_new_game_pressed)
    _load_game_btn.pressed.connect(_on_load_game_pressed)
    _settings_btn.pressed.connect(_on_settings_pressed)
    _quit_btn.pressed.connect(_on_quit_pressed)
    _confirm_dialog.confirmed.connect(_on_new_game_confirmed)
    _overwrite_dialog.confirmed.connect(_on_overwrite_confirmed)
    _picker_back_btn.pressed.connect(_on_picker_back_pressed)
    _picker_back_btn.press_event = CANCEL

    for i: int in 3:
        _slot_btns[i].pressed.connect(_on_slot_pressed.bind(i + 1))

    _refresh()


## Refreshes UI state: checks for save data and applies visibility.
func _refresh() -> void:
    _summaries = SaveManager.get_slot_summaries()
    _load_game_btn.visible = _any_save_occupied()
    _apply()


func _any_save_occupied() -> bool:
    for s: Variant in _summaries:
        if s != null:
            return true
    return false

# ══ Signal handlers — Main menu ═══════════════════════════════════════════════


func _on_new_game_pressed() -> void:
    _picker_mode = PickerMode.NEW_GAME
    _show_picker()


func _on_load_game_pressed() -> void:
    _picker_mode = PickerMode.LOAD
    _show_picker()


func _on_settings_pressed() -> void:
    SettingsStore.toggle_overlay()


func _on_quit_pressed() -> void:
    get_tree().quit()

# ══ Signal handlers — Slot picker ═════════════════════════════════════════════


func _on_slot_pressed(slot: int) -> void:
    var summary: Variant = _summaries[slot - 1]
    var is_occupied: bool = summary != null

    match _picker_mode:
        PickerMode.NEW_GAME:
            AudioManager.play_event(CONFIRM)
            if is_occupied:
                _pending_slot = slot
                _overwrite_dialog.dialog_text = "Start a new game in Slot %d? All progress in this slot will be lost." % slot
                _overwrite_dialog.popup_centered()
            else:
                _execute_new_game(slot)
        PickerMode.LOAD:
            AudioManager.play_event(CONFIRM)
            if is_occupied:
                _execute_load_game(slot)


func _on_picker_back_pressed() -> void:
    _hide_picker()


## Overwrite confirmation accepted.
func _on_overwrite_confirmed() -> void:
    var slot: int = _pending_slot
    _pending_slot = 0
    _execute_new_game(slot)


## Old new-game confirmation (from Continue → New Game — kept for safety).
func _on_new_game_confirmed() -> void:
    _execute_new_game(1)

# ══ Slot picker visibility ═════════════════════════════════════════════════════


func _show_picker() -> void:
    _summaries = SaveManager.get_slot_summaries()
    _buttons_vbox.visible = false
    _picker_panel.visible = true

    match _picker_mode:
        PickerMode.NEW_GAME:
            _picker_title.text = "New Game — Select a Slot"
        PickerMode.LOAD:
            _picker_title.text = "Load Game — Select a Slot"

    for i: int in 3:
        var btn: Button = _slot_btns[i]
        var summary: Variant = _summaries[i]
        if summary != null:
            var day: int = summary.get("day", 0)
            var cash: int = summary.get("cash", 0)
            var last_played: String = _relative_time(summary.get("last_played", ""))
            btn.text = "Slot %d\nDay %d  ·  $%d  ·  %s" % [i + 1, day, cash, last_played]
            btn.disabled = false
        else:
            btn.text = "Slot %d\nEmpty" % [i + 1]
            btn.disabled = (_picker_mode == PickerMode.LOAD)


func _hide_picker() -> void:
    _picker_panel.visible = false
    _buttons_vbox.visible = true

# ══ Slot actions ═══════════════════════════════════════════════════════════════


## Starts a new game in the specified [param slot].
func _execute_new_game(slot: int) -> void:
    SaveManager.init_slot(slot)
    RunManager.clear_run_state()
    SceneRouter.go_to_hub()


## Loads a save from the specified [param slot].
func _execute_load_game(slot: int) -> void:
    SaveManager.switch_to_slot(slot)
    SceneRouter.go_to_hub()

# ══ View ═══════════════════════════════════════════════════════════════════════


func _apply() -> void:
    _load_game_btn.visible = _any_save_occupied()


## Returns a human-readable relative time string for the given ISO 8601
## [param iso_timestamp]. Returns "" when the timestamp is empty.
func _relative_time(iso_timestamp: String) -> String:
    if iso_timestamp.is_empty():
        return ""

    var parts := iso_timestamp.split("T")
    if parts.is_empty():
        return ""

    var date_str := parts[0]
    var date_parts := date_str.split("-")
    if date_parts.size() < 3:
        return date_str

    var then: Dictionary = {
        "year": date_parts[0].to_int(),
        "month": date_parts[1].to_int(),
        "day": date_parts[2].to_int(),
    }

    var now: Dictionary = Time.get_datetime_dict_from_system()
    var delta_days: int = now.get("year", 0) * 365 + now.get("day", 1) - (then.get("year", 0) * 365 + then.get("day", 1))
    # Crude month approximation for the delta.
    var month_offset: int = (now.get("year", 0) - then.get("year", 0)) * 12 + now.get("month", 1) - then.get("month", 1)
    delta_days += month_offset * 15 # rough halfway

    if delta_days <= 0:
        return "today"
    elif delta_days == 1:
        return "yesterday"
    elif delta_days < 7:
        return "%d days ago" % delta_days
    elif delta_days < 30:
        var weeks: int = delta_days / 7
        return "%dw ago" % weeks
    else:
        var months: int = delta_days / 30
        return "%dm ago" % months
