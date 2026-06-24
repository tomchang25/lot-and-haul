# item_card_popup.gd
# Floating popup that displays an ItemCard for hover previews.
# Place one instance in the scene's .tscn; call show_for() / hide_popup()
# from the parent scene.
class_name ItemCardPopup
extends PanelContainer

const HIDE_GRACE_SEC := 0.25

const ItemCardScene: PackedScene = preload("res://game/shared/item_display/item_card.tscn")

var _source_hovered := false
var _popup_hovered := false
var _hide_generation := 0

@onready var _card: ItemCard = %ItemCard


func _ready() -> void:
    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)


func show_for(entry: ItemEntry, anchor: Rect2) -> void:
    if entry == null:
        return

    _source_hovered = true
    _hide_generation += 1

    _card.setup(entry)
    size = get_combined_minimum_size()
    _position_near(anchor)
    show()


func request_hide() -> void:
    _source_hovered = false
    _queue_hide_if_unowned()


func hide_popup() -> void:
    _source_hovered = false
    _popup_hovered = false
    _hide_generation += 1
    hide()


func _position_near(anchor: Rect2) -> void:
    var vp_size := get_viewport_rect().size
    var target_x := anchor.position.x
    var target_y := anchor.position.y + anchor.size.y + 4.0

    if target_y + size.y > vp_size.y:
        target_y = anchor.position.y - size.y - 4.0
    if target_x + size.x > vp_size.x:
        target_x = vp_size.x - size.x - 4.0

    global_position = Vector2(maxf(4.0, target_x), maxf(4.0, target_y))


func _on_mouse_entered() -> void:
    _popup_hovered = true
    _hide_generation += 1


func _on_mouse_exited() -> void:
    _popup_hovered = false
    _queue_hide_if_unowned()


func _queue_hide_if_unowned() -> void:
    if _source_hovered or _popup_hovered:
        return

    _hide_generation += 1
    var generation := _hide_generation

    await get_tree().create_timer(HIDE_GRACE_SEC).timeout

    if generation != _hide_generation:
        return
    if _source_hovered or _popup_hovered:
        return
    if ClueTooltipManager.is_tooltip_visible():
        return
    hide()
