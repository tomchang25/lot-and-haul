# item_row_tooltip.gd
# Floating tooltip shown on ItemRow hover.
# Add one instance to the scene root (not to the row).
# Call show_for() / hide_tooltip() from the parent scene.
#
# Always-shown rows: Display Name, Super-category, Category, Weight, Grid.
# Conditional rows:  Condition detail, Price (hidden until inspected).
# Inspection rows:   Layer depth, Clues (ItemEntry only, when known).
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

# Dynamically created nodes — inserted into VBox in _ready().
var _layer_depth_label: Label = null
var _clue_separator: HSeparator = null
var _clue_container: VBoxContainer = null


func _ready() -> void:
    # Layer depth subtitle — inserted right after the display name label.
    _layer_depth_label = Label.new()
    _layer_depth_label.add_theme_font_size_override(&"font_size", 11)
    _layer_depth_label.add_theme_color_override(&"font_color", Color(0.55, 0.55, 0.55))
    $VBox.add_child(_layer_depth_label)
    $VBox.move_child(_layer_depth_label, _display_name_label.get_index() + 1)

    # Clue separator — inserted just before the cargo separator.
    _clue_separator = HSeparator.new()
    $VBox.add_child(_clue_separator)
    $VBox.move_child(_clue_separator, _cargo_separator.get_index())

    # Clue container — inserted right after the clue separator, still before cargo separator.
    _clue_container = VBoxContainer.new()
    _clue_container.add_theme_constant_override(&"separation", 2)
    $VBox.add_child(_clue_container)
    $VBox.move_child(_clue_container, _clue_separator.get_index() + 1)


func show_for(entry: ItemEntry, ctx: ItemViewContext, anchor: Rect2) -> void:
    if entry == null:
        return

    # ── Display name ─────────────────────────────────────────────────────────
    _display_name_label.text = entry.display_name
    _display_name_label.show()

    # ── Layer depth (when known) ──────────────────────────────────────────────
    if not entry.is_veiled() and entry.item_data != null:
        _layer_depth_label.text = _layer_depth_text(entry)
        _layer_depth_label.show()
    else:
        _layer_depth_label.hide()

    # ── Always-visible: category identity ────────────────────────────────────
    var super_category := entry.super_category_text()
    var category := entry.category_text()
    if not entry.is_veiled() and category != "":
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
    var price_text := entry.price_text_for(ctx)
    if price_text != ItemEntry.UNKNOWN_TEXT:
        _price_label.text = "%s: %s" % [ItemRow.get_price_header(ctx), price_text]
        _price_label.add_theme_color_override(&"font_color", entry.price_display_color())
        _price_label.show()
    else:
        _price_label.hide()

    # ── Clue section ─────────────────────────────────────────────────────────
    if not entry.is_veiled():
        _populate_clue_section(entry)
    else:
        _clue_separator.hide()
        _clue_container.hide()

    # ── Always-visible: cargo stats ──────────────────────────────────────────
    var has_inspect_data: bool = (
        _condition_label.visible or _price_label.visible or _clue_container.visible
    )
    _cargo_separator.visible = has_inspect_data

    var weight := entry.weight_text()
    var grid := entry.grid_text()
    if not entry.is_veiled() and weight != ItemEntry.UNKNOWN_TEXT and grid != ItemEntry.UNKNOWN_TEXT:
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

# ── Private helpers ──────────────────────────────────────────────────────────


func _layer_depth_text(item: ItemEntry) -> String:
    var current: int = clampi(item.layer_index, 1, item.item_data.identity_layers.size() - 1)
    if item.is_at_final_layer():
        var total: int = item.item_data.identity_layers.size() - 1
        return "Layer %d / %d" % [current, total]
    return "Layer %d / ?" % current


func _populate_clue_section(item: ItemEntry) -> void:
    for child in _clue_container.get_children():
        child.free()

    var layer := item.active_layer()
    if layer == null or layer.clues.is_empty():
        _clue_separator.hide()
        _clue_container.hide()
        return

    _clue_separator.show()
    _clue_container.show()

    var header := Label.new()
    header.text = "Clues"
    header.add_theme_font_size_override(&"font_size", 11)
    header.add_theme_color_override(&"font_color", Color(0.65, 0.65, 0.65))
    _clue_container.add_child(header)

    for clue: ClueData in layer.clues:
        var row := Label.new()
        row.add_theme_font_size_override(&"font_size", 11)
        row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        row.custom_minimum_size = Vector2(200.0, 0.0)

        if item.revealed_clue_ids.has(clue.clue_id):
            row.text = "● %s" % clue.known_text
            row.add_theme_color_override(&"font_color", Color.WHITE)
        else:
            var hint: String = (
                clue.unknown_hint_text if clue.unknown_hint_text != "" else _auto_hint(clue)
            )
            var penalty: String = (
                " (+%d AP)" % clue.ap_cost_penalty if clue.ap_cost_penalty > 0 else ""
            )
            row.text = "○ %s%s" % [hint, penalty]
            row.add_theme_color_override(&"font_color", Color(0.55, 0.55, 0.55))

        _clue_container.add_child(row)


func _auto_hint(clue: ClueData) -> String:
    if clue.required_skill != null and clue.required_level > 0:
        return "Requires %s (Lv.%d)" % [clue.required_skill.display_name, clue.required_level]
    if clue.required_category_rank > 0:
        return "Requires category rank %d" % clue.required_category_rank
    if clue.required_perk != null:
        return "Requires %s perk" % clue.required_perk.display_name
    return "Further examination needed"
                                                                                                                                                          