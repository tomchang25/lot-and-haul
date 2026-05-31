# item_row_tooltip.gd
# Floating tooltip shown on ItemRow hover.
# Add one instance to the scene root (not to the row).
# Call show_for() / hide_tooltip() from the parent scene.
#
# Always-shown rows: Display Name, Super-category, Category, Weight, Grid.
# Conditional rows:  Condition detail, Price (hidden until inspected).
# Inspection rows:   Clues (ItemEntry only, when known).
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
@onready var _clue_separator: HSeparator = $VBox/ClueSeparator
@onready var _clue_container: VBoxContainer = $VBox/ClueContainer


func show_for(entry: ItemEntry, anchor: Rect2) -> void:
    if entry == null:
        return

    # ── Display name ─────────────────────────────────────────────────────────
    _display_name_label.text = entry.display_name
    _display_name_label.show()

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
    var price_text := entry.estimated_value_text()
    if price_text != ItemEntry.UNKNOWN_TEXT:
        _price_label.text = "%s: %s" % [ItemRow.get_price_header(), price_text]
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


func _populate_clue_section(item: ItemEntry) -> void:
    for child in _clue_container.get_children():
        child.free()

    if item.item_data == null or item.item_data.clues.is_empty():
        _clue_separator.hide()
        _clue_container.hide()
        return

    _clue_separator.show()
    _clue_container.show()

    var header := Label.new()
    header.text = "Clues"
    header.add_theme_font_size_override(&"font_size", 11)
    header.add_theme_color_override(&"font_color", Color(0.65, 0.65, 0.65))

    # node-src: ephemeral — clue header, rebuilt per refresh
    _clue_container.add_child(header)

    for clue: ClueData in item.item_data.clues:
        var row := Label.new()
        row.add_theme_font_size_override(&"font_size", 11)
        row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        row.custom_minimum_size = Vector2(200.0, 0.0)

        if item.revealed_clue_ids.has(clue.clue_id):
            row.text = "● %s" % clue.known_text
            row.add_theme_color_override(&"font_color", Color.WHITE)
        else:
            row.text = "○ %s (DC %d, %s)" % [clue.known_text, clue.dc, clue.attribute.capitalize()]
            row.add_theme_color_override(&"font_color", Color(0.55, 0.55, 0.55))

        # node-src: ephemeral — per-clue row, rebuilt per refresh
        _clue_container.add_child(row)
