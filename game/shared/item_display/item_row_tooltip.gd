# item_row_tooltip.gd
# Floating tooltip shown on ItemRow hover.
# Add one instance to the scene root (not to the row).
# Call show_for() / hide_tooltip() from the parent scene.
#
# Always-shown rows: Display Name, Super-category, Category, Weight, Grid.
# Conditional rows:  Condition detail, Price (hidden until inspected).
class_name ItemRowTooltip
extends PanelContainer

@onready var _display_name_label: Label = $VBox/DisplayNameLabel
@onready var _super_category_label: Label = $VBox/SuperCategoryLabel
@onready var _category_label: Label = $VBox/CategoryLabel
@onready var _condition_label: Label = $VBox/ConditionLabel
@onready var _price_label: Label = $VBox/PriceLabel
@onready var _cargo_separator: HSeparator = $VBox/CargoSeparator
@onready var _weight_label: Label = $VBox/WeightLabel
@onready var _grid_label: Label = $VBox/GridLabel


func show_for(entry: ItemEntry, ctx: ItemViewContext, anchor: Rect2) -> void:
    # ── Display name (at the top) ────────────────────────────────────────────
    _display_name_label.text = entry.display_name
    _display_name_label.show()

    # ── Always-visible: category identity ────────────────────────────────────
    var sc: SuperCategoryData = entry.super_category
    _super_category_label.text = sc.display_name if sc != null else ""
    _super_category_label.visible = sc != null

    if entry.category_data != null:
        _category_label.text = entry.category_display_name
        _category_label.visible = true
    else:
        _category_label.hide()

    # ── Conditional: condition detail ────────────────────────────────────────
    var cond_text := entry.condition_label
    if cond_text != "???":
        _condition_label.text = "Condition:  %s (%s)" % [cond_text, entry.condition_mult_label]
        _condition_label.modulate = entry.condition_color
        _condition_label.show()
    else:
        _condition_label.hide()

    # ── Conditional: price ───────────────────────────────────────────────────
    var price_text := entry.price_label_for(ctx)
    if price_text != "???":
        _price_label.text = "%s: %s" % [ItemRow.get_price_header(ctx), price_text]
        _price_label.add_theme_color_override(&"font_color", entry.price_color)
        _price_label.show()
    else:
        _price_label.hide()

    # ── Always-visible: cargo stats ──────────────────────────────────────────
    var has_inspect_data: bool = _condition_label.visible or _price_label.visible

    _cargo_separator.visible = has_inspect_data # only show divider when above rows exist

    if entry.category_data != null:
        var cell_count: int = entry.grid_cells.size()
        _weight_label.text = "Weight:  %.1f kg" % entry.weight
        _grid_label.text = "Grid:  %d slot%s  (%s)" % [
            cell_count,
            "s" if cell_count != 1 else "",
            entry.shape_id,
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
