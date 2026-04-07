# item_row_tooltip.gd
# Floating tooltip shown on ItemRow hover.
# Add one instance to the scene root (not to the row).
# Call show_for() / hide_tooltip() from the parent scene.
#
# Always-shown rows: Super-category, Category, Weight, Grid.
# Conditional rows:  Potential rating, Potential price, Condition detail
#                    (hidden until inspected).
class_name ItemRowTooltip
extends PanelContainer

@onready var _super_category_label: Label = $VBox/SuperCategoryLabel
@onready var _category_label: Label = $VBox/CategoryLabel
@onready var _potential_label: Label = $VBox/PotentialLabel
@onready var _potential_price_label: Label = $VBox/PotentialPriceLabel
@onready var _condition_label: Label = $VBox/ConditionLabel
@onready var _cargo_separator: HSeparator = $VBox/CargoSeparator
@onready var _weight_label: Label = $VBox/WeightLabel
@onready var _grid_label: Label = $VBox/GridLabel


func show_for(entry: ItemEntry, ctx: ItemViewContext, anchor: Rect2) -> void:
    # ── Always-visible: category identity ────────────────────────────────────
    if entry.item_data != null and entry.item_data.category_data != null:
        var cat := entry.item_data.category_data
        _super_category_label.text = cat.super_category.display_name \
        if cat.super_category != null else ""
        _super_category_label.visible = cat.super_category != null
        _category_label.text = cat.display_name
        _category_label.visible = true
    else:
        _super_category_label.hide()
        _category_label.hide()

    # ── Conditional: potential rating ────────────────────────────────────────
    if not entry.is_veiled() and entry.potential_inspect_level >= 1:
        _potential_label.text = entry.potential_label_for(ctx)
        _potential_label.show()
    else:
        _potential_label.hide()

    # ── Conditional: potential price range ───────────────────────────────────
    if not entry.is_veiled() and entry.should_show_potential_price_for(ctx):
        _potential_price_label.text = "Potential Range: %s" % entry.potential_price_label
        _potential_price_label.show()
    else:
        _potential_price_label.hide()

    # ── Conditional: condition detail ────────────────────────────────────────
    var cond_text := entry.condition_label_for(ctx)
    var cond_mult_text := entry.condition_mult_label_for(ctx)
    if not entry.is_veiled() and cond_text != "???":
        _condition_label.text = "%s (%s)" % [cond_text, cond_mult_text]
        _condition_label.modulate = entry.condition_color_for(ctx)
        _condition_label.show()
    else:
        _condition_label.hide()

    # ── Always-visible: cargo stats ──────────────────────────────────────────
    var has_inspect_data: bool = _potential_label.visible \
    or _potential_price_label.visible \
    or _condition_label.visible

    _cargo_separator.visible = has_inspect_data # only show divider when above rows exist

    if entry.item_data != null and entry.item_data.category_data != null:
        var cat := entry.item_data.category_data
        _weight_label.text = "Weight:  %.1f kg" % cat.weight
        _grid_label.text = "Grid:  %d slot%s" % [
            cat.grid_size,
            "s" if cat.grid_size != 1 else "",
        ]
        _weight_label.show()
        _grid_label.show()
    else:
        _weight_label.hide()
        _grid_label.hide()

    # ── Position ─────────────────────────────────────────────────────────────
    var vp_height := get_viewport_rect().size.y
    var target_y := anchor.position.y + anchor.size.y + 4.0
    if target_y + size.y > vp_height:
        target_y = anchor.position.y - size.y - 4.0
    global_position = Vector2(anchor.position.x, target_y)
    show()


func hide_tooltip() -> void:
    hide()
