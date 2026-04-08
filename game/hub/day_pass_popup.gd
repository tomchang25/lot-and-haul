class_name DayPassPopup
extends Window

signal dismissed

@onready var _day_label:        Label         = $MarginContainer/VBoxContainer/DayLabel
@onready var _cash_label:       Label         = $MarginContainer/VBoxContainer/CashLabel
@onready var _completed_header: Label         = $MarginContainer/VBoxContainer/CompletedHeader
@onready var _completed_list:   VBoxContainer = $MarginContainer/VBoxContainer/CompletedList
@onready var _ok_btn:           Button        = $MarginContainer/VBoxContainer/OkButton


func _ready() -> void:
    _ok_btn.pressed.connect(_on_ok_pressed)
    close_requested.connect(_on_ok_pressed)


func populate(summary: Dictionary) -> void:
    _day_label.text  = "Day %d" % summary.get("new_day", 0)
    _cash_label.text = "Cash:  -$%d  (daily upkeep)" % summary.get("cash_spent", 0)

    for child in _completed_list.get_children():
        child.queue_free()

    var completed: Array = summary.get("completed", [])
    _completed_header.visible = not completed.is_empty()
    for c: Dictionary in completed:
        var lbl := Label.new()
        lbl.text = "  · %s — %s" % [c.get("name", "?"), c.get("effect", "?")]
        lbl.add_theme_font_size_override("font_size", 16)
        _completed_list.add_child(lbl)


func _on_ok_pressed() -> void:
    dismissed.emit()
    hide()
