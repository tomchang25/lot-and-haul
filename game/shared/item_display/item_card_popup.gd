# item_card_popup.gd
# Floating popup that displays an ItemCard for hover previews.
# Add one instance to the scene root; call show_for() / hide_popup()
# from the parent scene.
class_name ItemCardPopup
extends PanelContainer

const ItemCardScene: PackedScene = preload("res://game/shared/item_display/item_card.tscn")

@onready var _card: ItemCard = $VBox/ItemCard


func show_for(entry: ItemEntry, anchor: Rect2) -> void:
    if entry == null:
        return

    _card.setup(entry)

    var vp_size := get_viewport_rect().size
    var target_x := anchor.position.x
    var target_y := anchor.position.y + anchor.size.y + 4.0

    if target_y + size.y > vp_size.y:
        target_y = anchor.position.y - size.y - 4.0
    if target_x + size.x > vp_size.x:
        target_x = vp_size.x - size.x - 4.0

    global_position = Vector2(maxf(4.0, target_x), maxf(4.0, target_y))
    show()


func hide_popup() -> void:
    hide()
