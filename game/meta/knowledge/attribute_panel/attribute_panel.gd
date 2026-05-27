# attribute_panel.gd
# Attribute Panel — Upgrade player attributes with cash.
extends Control

@onready var _back_btn: Button = $RootVBox/Footer/BackButton
@onready var _content: VBoxContainer = $RootVBox/ScrollContainer/Content

func _ready() -> void:
    _back_btn.pressed.connect(_on_back_pressed)
    _build_content()

func _on_back_pressed() -> void:
    GameManager.go_to_knowledge_hub()

func _build_content() -> void:
    var attrs: Array[AttributeData] = KnowledgeManager.get_all_attributes()
    if attrs.is_empty():
        var empty := Label.new()
        empty.text = "No attributes found"
        _content.add_child(empty)
        return

    for attr: AttributeData in attrs:
        _add_attribute_row(attr)

func _add_attribute_row(attr: AttributeData) -> void:
    var row := HBoxContainer.new()
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_theme_constant_override("separation", 12)

    var level := SaveManager.attribute_levels.get(attr.attribute_id, attr.starting_value)

    var name_label := Label.new()
    name_label.text = "%s  %d" % [attr.display_name, level]
    name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    name_label.add_theme_font_size_override("font_size", 18)
    row.add_child(name_label)

    var upgrade_btn := Button.new()
    if SaveManager.cash < 1000:
        upgrade_btn.text = "$1000"
        upgrade_btn.disabled = true
        upgrade_btn.tooltip_text = "Not enough cash"
    else:
        upgrade_btn.text = "Upgrade  $1000"
        upgrade_btn.pressed.connect(_on_upgrade_pressed.bind(attr))

    row.add_child(upgrade_btn)
    _content.add_child(row)

func _on_upgrade_pressed(attr: AttributeData) -> void:
    var ok := KnowledgeManager.upgrade_attribute(attr.attribute_id)
    if not ok:
        return
    _rebuild_all()

func _rebuild_all() -> void:
    for child in _content.get_children():
        child.queue_free()
    await get_tree().process_frame
    _build_content()
