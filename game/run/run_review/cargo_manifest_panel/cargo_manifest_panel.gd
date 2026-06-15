# cargo_manifest_panel.gd
# Collapsible panel displaying cargo items with expand/collapse toggle.
# Emits tooltip_requested / tooltip_dismissed for the parent scene to position an ItemCardPopup.
class_name CargoManifestPanel
extends PanelContainer

signal tooltip_requested(entry, anchor: Rect2)
signal tooltip_dismissed

@onready var _toggle_btn: Button = %ToggleButton
@onready var _content: VBoxContainer = %ContentPanel
@onready var _item_list_panel: ItemListPanel = %ItemListPanel
@onready var _damage_label: Label = %DamageLabel

var _expanded: bool = true


func _ready() -> void:
    _toggle_btn.pressed.connect(_on_toggle)
    gui_input.connect(_on_card_gui_input)

    _item_list_panel.tooltip_requested.connect(_on_tooltip_requested)
    _item_list_panel.tooltip_dismissed.connect(_on_tooltip_dismissed)


func setup(columns: Array, items: Array) -> void:
    _item_list_panel.setup(columns)
    _item_list_panel.populate(items)


func set_damage_count(count: int) -> void:
    if count > 0:
        _damage_label.text = "%d trailer item(s) cracked during transport" % count
        _damage_label.visible = true
    else:
        _damage_label.visible = false


func is_expanded() -> bool:
    return _expanded


func toggle() -> void:
    _on_toggle()


func set_expanded(v: bool) -> void:
    if v != _expanded:
        _on_toggle()


func _on_toggle() -> void:
    _expanded = not _expanded
    _content.visible = _expanded
    _toggle_btn.text = "▼ Cargo Manifest" if _expanded else "▶ Cargo Manifest"


func _on_card_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton \
    and event.button_index == MOUSE_BUTTON_LEFT \
    and event.pressed:
        var list_global: Rect2 = _item_list_panel.get_global_rect()
        if not list_global.has_point(get_global_mouse_position()):
            _on_toggle()


func _on_tooltip_requested(entry, anchor: Rect2) -> void:
    tooltip_requested.emit(entry, anchor)


func _on_tooltip_dismissed() -> void:
    tooltip_dismissed.emit()
