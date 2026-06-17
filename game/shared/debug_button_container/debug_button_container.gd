# debug_button_container.gd
# Debug-only Hub control block. Self-gates visibility via Debug.enabled and reacts to Debug.toggled.
class_name DebugButtonContainer
extends PanelContainer

signal storage_changed

@onready var _add_item_btn: Button = %DebugAddItemBtn
@onready var _clear_storage_btn: Button = %DebugClearStorageBtn


func _ready() -> void:
    visible = Debug.enabled
    Debug.toggled.connect(_on_debug_toggled)
    _add_item_btn.pressed.connect(_on_add_item)
    _clear_storage_btn.pressed.connect(_on_clear_storage)


func _on_debug_toggled(is_enabled: bool) -> void:
    visible = is_enabled


func _on_add_item() -> void:
    if not Debug.enabled:
        return
    var categories: Array[CategoryData] = CategoryRegistry.get_all_categories()
    if categories.is_empty():
        return
    var cat: CategoryData = categories[randi() % categories.size()]
    var entry: ItemEntry = ItemGenerator.draw(cat, { })
    if entry == null:
        return
    MetaManager.register_storage_items([entry])
    storage_changed.emit()


func _on_clear_storage() -> void:
    if not Debug.enabled:
        return
    MetaManager.clear_all_storage()
    storage_changed.emit()
