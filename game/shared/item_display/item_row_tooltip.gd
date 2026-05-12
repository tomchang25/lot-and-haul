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


func show_for(entry, ctx: ItemViewContext, anchor: Rect2) -> void:
    var lot_object := entry as LotObjectEntry
    if lot_object == null:
        return
    _show_for_lot_object(lot_object, ctx, anchor)


func _show_for_lot_object(entry: LotObjectEntry, ctx: ItemViewContext, anchor: Rect2) -> void:
    # ── Display name (at the top) ────────────────────────────────────────────
    _display_name_label.text = entry.display_name_text()
    _display_name_label.show()

    # ── Always-visible: category identity ────────────────────────────────────
    var super_category := entry.super_category_text()
    var category := entry.category_text()
    if entry.is_known() and category != "":
        _super_category_label.text = super_category
        _super_category_label.visible = super_category != ""
        _category_label.text = category
        _category_label.visible = true
    else:
        _super_category_label.hide()
        _category_label.hide()

    # ── Conditional: condition detail ────────────────────────────────────────
    var cond_text := entry.condition_detail_text()
    if cond_text != "":
        _condition_label.text = cond_text
        _condition_label.modulate = entry.condition_display_color()
        _condition_label.show()
    else:
        _condition_label.hide()

    # ── Conditional: price ───────────────────────────────────────────────────
    var price_text := entry.estimated_value_text(ctx)
    if price_text != LotObjectEntry.UNKNOWN_TEXT:
        _price_label.text = "%s: %s" % [ItemRow.get_price_header(ctx), price_text]
        _price_label.add_theme_color_override(&"font_color", entry.price_display_color())
        _price_label.show()
    else:
        _price_label.hide()

    # ── Always-visible: cargo stats ──────────────────────────────────────────
    var has_inspect_data: bool = _condition_label.visible or _price_label.visible

    _cargo_separator.visible = has_inspect_data # only show divider when above rows exist

    var weight := entry.weight_text()
    var grid := entry.grid_text()
    if entry.is_known() and weight != LotObjectEntry.UNKNOWN_TEXT and grid != LotObjectEntry.UNKNOWN_TEXT:
        _weight_label.text = "Weight:  %s" % weight
        _grid_label.text = "Grid:  %s" % grid
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
