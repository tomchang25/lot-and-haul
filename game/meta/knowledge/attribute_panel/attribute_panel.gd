# attribute_panel.gd
# Attribute Panel — Upgrade player attributes with cash.
extends Control

const UPGRADE_COST := 1000
const AttributeRowScene := preload("res://game/meta/knowledge/attribute_panel/attribute_row/attribute_row.tscn")

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

        # node-src: ephemeral — empty-state label
        _content.add_child(empty)

        return

    for attr: AttributeData in attrs:
        _add_attribute_row(attr)


func _add_attribute_row(attr: AttributeData) -> void:
    var level := SaveManager.attribute_levels.get(attr.attribute_id, attr.starting_value)

    var row: AttributeRow = AttributeRowScene.instantiate()
    row.setup(attr, level, UPGRADE_COST, SaveManager.cash >= UPGRADE_COST)
    row.upgrade_pressed.connect(_on_upgrade_pressed)
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
