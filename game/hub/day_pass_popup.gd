class_name DayPassPopup
extends Window

signal dismissed

@onready var _summary_panel: DaySummaryPanel = $MarginContainer/VBoxContainer/DaySummaryPanel
@onready var _ok_btn: Button = $MarginContainer/VBoxContainer/OkButton


func _ready() -> void:
    _ok_btn.pressed.connect(_on_ok_pressed)
    close_requested.connect(_on_ok_pressed)


func show_summary(summary: DaySummary) -> void:
    _summary_panel.show_summary(summary)


func _on_ok_pressed() -> void:
    dismissed.emit()
    hide()
