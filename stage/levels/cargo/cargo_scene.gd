# cargo_scene.gd
# Block 05 — Cargo Loading
# Reads:  GameManager.lot_result.won_items, GameManager.inspection_results
# Writes: GameManager.cargo_items
extends Control

# ── Constants ──────────────────────────────────────────────────────────────────
const _MAX_GRID := 6
const _MAX_WEIGHT := 20.0

# ── State ──────────────────────────────────────────────────────────────────────
var _won_items: Array[ItemData] = []
var _selected: Dictionary = {}  # ItemData → bool
var _grid_used: int = 0
var _weight_used: float = 0.0

# ── UI references ──────────────────────────────────────────────────────────────
var _grid_label: Label = null
var _weight_label: Label = null
var _row_toggles: Dictionary = {}  # ItemData → CheckButton


# ══ Lifecycle ═════════════════════════════════════════════════════════════════
func _ready() -> void:
    _won_items = GameManager.lot_result.get(&"won_items", [])
    for item: ItemData in _won_items:
        _selected[item] = false
    _build_ui()
    _recalc_totals()
    _refresh_ui()


# ══ State helpers ══════════════════════════════════════════════════════════════
func _recalc_totals() -> void:
    _grid_used = 0
    _weight_used = 0.0
    for item: ItemData in _won_items:
        if _selected.get(item, false):
            _grid_used += item.grid_size
            _weight_used += item.weight


func _refresh_ui() -> void:
    _grid_label.text = "Grid: %d / %d" % [_grid_used, _MAX_GRID]
    _weight_label.text = "Weight: %.1f / %.1f kg" % [_weight_used, _MAX_WEIGHT]

    var remaining_grid: int = _MAX_GRID - _grid_used
    var remaining_weight: float = _MAX_WEIGHT - _weight_used

    for item: ItemData in _won_items:
        var toggle: CheckButton = _row_toggles[item]
        if _selected.get(item, false):
            # Selected items can always be toggled off.
            toggle.disabled = false
        else:
            # Disable if loading this item would exceed either limit.
            toggle.disabled = (item.grid_size > remaining_grid) or (item.weight > remaining_weight)


# ══ Signal handlers ════════════════════════════════════════════════════════════
func _on_item_toggled(pressed: bool, item: ItemData) -> void:
    _selected[item] = pressed
    _recalc_totals()
    _refresh_ui()


func _on_load_up_pressed() -> void:
    var cargo: Array[ItemData] = []
    for item: ItemData in _won_items:
        if _selected.get(item, false):
            cargo.append(item)
    GameManager.cargo_items = cargo
    GameManager.go_to_appraisal()


# ══ UI builder ════════════════════════════════════════════════════════════════
func _build_ui() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    # Background
    var bg := ColorRect.new()
    bg.color = Color(0.1, 0.1, 0.12, 1.0)
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(bg)

    # Root VBox fills the full screen
    var root_vbox := VBoxContainer.new()
    root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(root_vbox)

    # ── Title ──────────────────────────────────────────────────────────────────
    var title := Label.new()
    title.text = "Cargo Loading"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override(&"font_size", 28)
    title.custom_minimum_size = Vector2(0, 64)
    root_vbox.add_child(title)

    # ── Header row (live counters) ─────────────────────────────────────────────
    var header := HBoxContainer.new()
    header.alignment = BoxContainer.ALIGNMENT_CENTER
    header.add_theme_constant_override(&"separation", 48)
    header.custom_minimum_size = Vector2(0, 36)
    root_vbox.add_child(header)

    _grid_label = Label.new()
    _grid_label.add_theme_font_size_override(&"font_size", 18)
    header.add_child(_grid_label)

    _weight_label = Label.new()
    _weight_label.add_theme_font_size_override(&"font_size", 18)
    header.add_child(_weight_label)

    # ── Checklist panel (centred, fixed width) ─────────────────────────────────
    var list_center := CenterContainer.new()
    list_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root_vbox.add_child(list_center)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(760, 0)
    list_center.add_child(panel)

    var panel_vbox := VBoxContainer.new()
    panel_vbox.add_theme_constant_override(&"separation", 0)
    panel.add_child(panel_vbox)

    # Column header row
    panel_vbox.add_child(_make_column_header())

    var sep := HSeparator.new()
    panel_vbox.add_child(sep)

    # Item rows
    if _won_items.is_empty():
        var empty_lbl := Label.new()
        empty_lbl.text = "No items to load."
        empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        empty_lbl.add_theme_font_size_override(&"font_size", 16)
        empty_lbl.custom_minimum_size = Vector2(0, 60)
        panel_vbox.add_child(empty_lbl)
    else:
        for item: ItemData in _won_items:
            panel_vbox.add_child(_make_item_row(item))

    # ── Footer (confirm button) ────────────────────────────────────────────────
    var footer := HBoxContainer.new()
    footer.alignment = BoxContainer.ALIGNMENT_CENTER
    footer.custom_minimum_size = Vector2(0, 72)
    root_vbox.add_child(footer)

    var confirm_btn := Button.new()
    confirm_btn.text = "Load Up"
    confirm_btn.custom_minimum_size = Vector2(160, 44)
    confirm_btn.add_theme_font_size_override(&"font_size", 18)
    confirm_btn.pressed.connect(_on_load_up_pressed)
    footer.add_child(confirm_btn)


func _make_column_header() -> HBoxContainer:
    var row := HBoxContainer.new()
    row.custom_minimum_size = Vector2(0, 36)
    row.add_theme_constant_override(&"separation", 0)

    # Spacer aligned with toggle buttons
    var toggle_spacer := Control.new()
    toggle_spacer.custom_minimum_size = Vector2(80, 0)
    row.add_child(toggle_spacer)

    var name_hdr := Label.new()
    name_hdr.text = "Item"
    name_hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    name_hdr.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    name_hdr.add_theme_font_size_override(&"font_size", 14)
    name_hdr.add_theme_color_override(&"font_color", Color(0.7, 0.7, 0.7))
    row.add_child(name_hdr)

    var price_hdr := Label.new()
    price_hdr.text = "Est. Value"
    price_hdr.custom_minimum_size = Vector2(160, 0)
    price_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    price_hdr.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    price_hdr.add_theme_font_size_override(&"font_size", 14)
    price_hdr.add_theme_color_override(&"font_color", Color(0.7, 0.7, 0.7))
    row.add_child(price_hdr)

    var weight_hdr := Label.new()
    weight_hdr.text = "Weight"
    weight_hdr.custom_minimum_size = Vector2(100, 0)
    weight_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    weight_hdr.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    weight_hdr.add_theme_font_size_override(&"font_size", 14)
    weight_hdr.add_theme_color_override(&"font_color", Color(0.7, 0.7, 0.7))
    row.add_child(weight_hdr)

    var grid_hdr := Label.new()
    grid_hdr.text = "Size"
    grid_hdr.custom_minimum_size = Vector2(80, 0)
    grid_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    grid_hdr.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    grid_hdr.add_theme_font_size_override(&"font_size", 14)
    grid_hdr.add_theme_color_override(&"font_color", Color(0.7, 0.7, 0.7))
    row.add_child(grid_hdr)

    return row


func _make_item_row(item: ItemData) -> HBoxContainer:
    var result: Dictionary = GameManager.inspection_results.get(
        item,
        { &"level": 0, &"clues_revealed": 0 },
    )
    var level: int = result.get(&"level", 0)

    var row := HBoxContainer.new()
    row.custom_minimum_size = Vector2(0, 48)
    row.add_theme_constant_override(&"separation", 0)

    # Toggle (switch style)
    var toggle := CheckButton.new()
    toggle.custom_minimum_size = Vector2(80, 0)
    toggle.button_pressed = false
    toggle.toggled.connect(_on_item_toggled.bind(item))
    row.add_child(toggle)
    _row_toggles[item] = toggle

    # Item name
    var name_lbl := Label.new()
    name_lbl.text = item.item_name
    name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    name_lbl.add_theme_font_size_override(&"font_size", 17)
    row.add_child(name_lbl)

    # Estimate value range (no true values shown)
    var price_lbl := Label.new()
    price_lbl.text = ClueEvaluator.get_price_range_label(item, level)
    price_lbl.custom_minimum_size = Vector2(160, 0)
    price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    price_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    price_lbl.add_theme_font_size_override(&"font_size", 16)
    price_lbl.add_theme_color_override(&"font_color", Color(0.92, 0.72, 0.18))
    row.add_child(price_lbl)

    # Weight
    var weight_lbl := Label.new()
    weight_lbl.text = "%.1f kg" % item.weight
    weight_lbl.custom_minimum_size = Vector2(100, 0)
    weight_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    weight_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    weight_lbl.add_theme_font_size_override(&"font_size", 16)
    row.add_child(weight_lbl)

    # Grid size
    var grid_lbl := Label.new()
    grid_lbl.text = "%d" % item.grid_size
    grid_lbl.custom_minimum_size = Vector2(80, 0)
    grid_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    grid_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    grid_lbl.add_theme_font_size_override(&"font_size", 16)
    row.add_child(grid_lbl)

    return row
