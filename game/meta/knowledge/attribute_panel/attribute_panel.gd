# attribute_panel.gd
# Attribute Panel — Upgrade player attributes with cash.
extends Control

const CANCEL: UiAudioEvent = preload("res://data/tres/audio_events/cancel_dismiss.tres")
const UPGRADE_COST := 1000
const AttributeRowScene := preload("res://game/meta/knowledge/attribute_panel/attribute_row/attribute_row.tscn")

@onready var _back_btn: Button = $RootVBox/Footer/BackButton
@onready var _content: VBoxContainer = $RootVBox/ScrollContainer/Content


func _ready() -> void:
    _back_btn.pressed.connect(_on_back_pressed)
    _back_btn.press_event = CANCEL
    _build_content()


func _on_back_pressed() -> void:
    SceneRouter.go_to_knowledge_hub()


func _build_content() -> void:
    var attrs: Array[AttributeData] = KnowledgeSystem.get_all_attributes()
    if attrs.is_empty():
        var empty := Label.new()
        empty.text = TranslationServer.translate("UI_NO_ATTRIBUTES")

        # node-src: ephemeral — empty-state label
        _content.add_child(empty)

        return

    for attr: AttributeData in attrs:
        _add_attribute_row(attr)


func _add_attribute_row(attr: AttributeData) -> void:
    var level: int = KnowledgeSystem.get_attribute_value(attr.attribute_id)

    var row: AttributeRow = AttributeRowScene.instantiate()
    row.setup(attr, level, UPGRADE_COST, MetaSystem.economy.cash >= UPGRADE_COST)
    row.upgrade_pressed.connect(_on_upgrade_pressed)
    _content.add_child(row)


func _on_upgrade_pressed(attr: AttributeData) -> void:
    var ok := MetaSystem.upgrade_attribute(attr)
    if not ok:
        return
    _rebuild_all()


func _rebuild_all() -> void:
    for child in _content.get_children():
        child.queue_free()
    await get_tree().process_frame
    _build_content()
