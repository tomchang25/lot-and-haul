# cargo_manifest_panel.gd
# Collapsible panel displaying cargo items with expand/collapse toggle.
# Emits tooltip_requested / tooltip_dismissed for the parent scene to position an ItemCardPopup.
class_name CargoManifestPanel
extends PanelContainer

signal tooltip_requested(entry, anchor: Rect2)
signal tooltip_dismissed

const ItemRowScene: PackedScene = preload("res://game/shared/item_display/item_row.tscn")

@onready var _toggle_btn: Button = %ToggleButton
@onready var _content: VBoxContainer = %ContentPanel
@onready var _row_container: VBoxContainer = %RowContainer
@onready var _damage_label: Label = %DamageLabel

var _expanded: bool = true
var _columns: Array = []


func _ready() -> void:
    _toggle_btn.pressed.connect(_on_toggle)
    gui_input.connect(_on_card_gui_input)


func setup(columns: Array, items: Array) -> void:
    _columns = columns
    _rebuild_rows(items)


func set_damage_count(count: int) -> void:
    if count > 0:
        _damage_label.text = TranslationServer.translate("UI_DAMAGE_LABEL") % count
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


func _rebuild_rows(items: Array) -> void:
    for child in _row_container.get_children():
        child.queue_free()
    for entry in items:
        var row: ItemRow = ItemRowScene.instantiate()
        row.setup(entry, _columns)
        row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.custom_minimum_size = Vector2(0, 28)
        for label in row.find_children("*", "Label", true, false):
            label.add_theme_font_size_override(&"font_size", 14)
        row.tooltip_requested.connect(_on_row_tooltip_requested)
        row.tooltip_dismissed.connect(_on_row_tooltip_dismissed)
        _row_container.add_child(row)


func _on_toggle() -> void:
    _expanded = not _expanded
    _content.visible = _expanded
    var manifest: String = TranslationServer.translate("UI_CARGO_MANIFEST")
    if _expanded:
        _toggle_btn.text = manifest
    else:
        _toggle_btn.text = manifest.replace("▼", "▶")


func _on_card_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton \
    and event.button_index == MOUSE_BUTTON_LEFT \
    and event.pressed:
        var list_global: Rect2 = _row_container.get_global_rect()
        if not list_global.has_point(get_global_mouse_position()):
            _on_toggle()


func _on_row_tooltip_requested(entry, anchor: Rect2) -> void:
    tooltip_requested.emit(entry, anchor)


func _on_row_tooltip_dismissed() -> void:
    tooltip_dismissed.emit()
