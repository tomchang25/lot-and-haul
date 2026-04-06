# item_row_tooltip.gd
# Floating tooltip shown on ItemRow hover.
# Add one instance to the scene root (not to the row).
# Call show_for() / hide_tooltip() from the parent scene.
class_name ItemRowTooltip
extends PanelContainer

@onready var _potential_label: Label = $VBox/PotentialLabel
@onready var _potential_price_label: Label = $VBox/PotentialPriceLabel
@onready var _condition_label: Label = $VBox/ConditionLabel


func show_for(entry: ItemEntry, ctx: ItemViewContext, anchor: Rect2) -> void:
    var has_content := false

    # Potential rating
    if not entry.is_veiled() and entry.potential_inspect_level >= 1:
        _potential_label.text = entry.potential_label_for(ctx)
        _potential_label.show()
        has_content = true
    else:
        _potential_label.hide()

    # Potential price range
    if entry.should_show_potential_price_for(ctx):
        _potential_price_label.text = "Range: %s" % entry.potential_price_label
        _potential_price_label.show()
        has_content = true
    else:
        _potential_price_label.hide()

    # Condition detail
    var cond_text := entry.condition_label_for(ctx)
    if cond_text != "???":
        _condition_label.text = cond_text
        _condition_label.modulate = entry.condition_color_for(ctx)
        _condition_label.show()
        has_content = true
    else:
        _condition_label.hide()

    if not has_content:
        return

    # Position below the row; flip above if clipped by viewport bottom
    var vp_height := get_viewport_rect().size.y
    var target_y := anchor.position.y + anchor.size.y + 4.0
    if target_y + size.y > vp_height:
        target_y = anchor.position.y - size.y - 4.0
    global_position = Vector2(anchor.position.x, target_y)
    show()


func hide_tooltip() -> void:
    hide()
