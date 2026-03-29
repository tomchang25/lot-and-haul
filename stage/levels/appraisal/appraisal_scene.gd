# appraisal_scene.gd
# Block 06 — Home Appraisal
# Reads:  GameManager.cargo_items, GameManager.lot_result.paid_price
# Writes: GameManager.run_result
extends Control

# ── State ──────────────────────────────────────────────────────────────────────
var _cargo_items: Array[ItemData] = []
var _paid_price: int = 0
var _reveal_index: int = 0

# ── UI references ──────────────────────────────────────────────────────────────
var _value_labels: Array[Label] = []
var _reveal_btn: Button = null
var _summary_container: VBoxContainer = null
var _sell_value_label: Label = null
var _paid_label: Label = null
var _net_label: Label = null
var _continue_btn: Button = null


# ══ Lifecycle ═════════════════════════════════════════════════════════════════
func _ready() -> void:
    _cargo_items = GameManager.cargo_items
    _paid_price = GameManager.lot_result.get(&"paid_price", 0)
    _build_ui()
    if _cargo_items.is_empty():
        _commit_result()
        _show_summary()


# ══ Logic ══════════════════════════════════════════════════════════════════════
func _commit_result() -> void:
    var sell_value: int = 0
    for item: ItemData in _cargo_items:
        sell_value += item.true_value
    GameManager.run_result = {
        &"sell_value": sell_value,
        &"paid_price": _paid_price,
        &"net": sell_value - _paid_price,
    }


func _show_summary() -> void:
    var r: Dictionary = GameManager.run_result
    var sell_value: int = r.get(&"sell_value", 0)
    var paid_price: int = r.get(&"paid_price", 0)
    var net: int = r.get(&"net", 0)

    _sell_value_label.text = "Total Sell Value:   $%d" % sell_value
    _paid_label.text = "Amount Paid:   $%d" % paid_price

    if net >= 0:
        _net_label.text = "Profit:   +$%d" % net
        _net_label.add_theme_color_override(&"font_color", Color(0.4, 1.0, 0.5))
    else:
        _net_label.text = "Loss:   -$%d" % (-net)
        _net_label.add_theme_color_override(&"font_color", Color(1.0, 0.4, 0.4))

    _summary_container.show()
    _continue_btn.show()
    if _reveal_btn != null:
        _reveal_btn.hide()


# ══ Signal handlers ════════════════════════════════════════════════════════════
func _on_reveal_pressed() -> void:
    if _reveal_index >= _cargo_items.size():
        return

    var item: ItemData = _cargo_items[_reveal_index]
    var lbl: Label = _value_labels[_reveal_index]
    lbl.text = "$%d" % item.true_value
    lbl.add_theme_color_override(&"font_color", Color(0.4, 1.0, 0.5))
    _reveal_index += 1

    if _reveal_index >= _cargo_items.size():
        _commit_result()
        _show_summary()


func _on_continue_pressed() -> void:
    GameManager.restart_run()


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
    title.text = "Home Appraisal"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override(&"font_size", 28)
    title.custom_minimum_size = Vector2(0, 64)
    root_vbox.add_child(title)

    # ── Items panel (centred, fixed width) ─────────────────────────────────────
    var list_center := CenterContainer.new()
    list_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root_vbox.add_child(list_center)

    var outer_vbox := VBoxContainer.new()
    outer_vbox.custom_minimum_size = Vector2(760, 0)
    outer_vbox.add_theme_constant_override(&"separation", 16)
    list_center.add_child(outer_vbox)

    var panel := PanelContainer.new()
    outer_vbox.add_child(panel)

    var panel_vbox := VBoxContainer.new()
    panel_vbox.add_theme_constant_override(&"separation", 0)
    panel.add_child(panel_vbox)

    panel_vbox.add_child(_make_column_header())
    panel_vbox.add_child(HSeparator.new())

    if _cargo_items.is_empty():
        var empty_lbl := Label.new()
        empty_lbl.text = "You walked away empty-handed."
        empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        empty_lbl.add_theme_font_size_override(&"font_size", 16)
        empty_lbl.custom_minimum_size = Vector2(0, 60)
        panel_vbox.add_child(empty_lbl)
    else:
        for item: ItemData in _cargo_items:
            panel_vbox.add_child(HSeparator.new())
            panel_vbox.add_child(_make_item_row(item))

    # ── Summary container (hidden until all items revealed) ────────────────────
    _summary_container = VBoxContainer.new()
    _summary_container.add_theme_constant_override(&"separation", 8)
    outer_vbox.add_child(_summary_container)

    _summary_container.add_child(HSeparator.new())

    _sell_value_label = Label.new()
    _sell_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _sell_value_label.add_theme_font_size_override(&"font_size", 18)
    _summary_container.add_child(_sell_value_label)

    _paid_label = Label.new()
    _paid_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _paid_label.add_theme_font_size_override(&"font_size", 18)
    _summary_container.add_child(_paid_label)

    _net_label = Label.new()
    _net_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _net_label.add_theme_font_size_override(&"font_size", 22)
    _summary_container.add_child(_net_label)

    _summary_container.hide()

    # ── Footer ─────────────────────────────────────────────────────────────────
    var footer := HBoxContainer.new()
    footer.alignment = BoxContainer.ALIGNMENT_CENTER
    footer.add_theme_constant_override(&"separation", 24)
    footer.custom_minimum_size = Vector2(0, 72)
    root_vbox.add_child(footer)

    if not _cargo_items.is_empty():
        _reveal_btn = Button.new()
        _reveal_btn.text = "Reveal Next"
        _reveal_btn.custom_minimum_size = Vector2(160, 44)
        _reveal_btn.add_theme_font_size_override(&"font_size", 18)
        _reveal_btn.pressed.connect(_on_reveal_pressed)
        footer.add_child(_reveal_btn)

    _continue_btn = Button.new()
    _continue_btn.text = "Continue"
    _continue_btn.custom_minimum_size = Vector2(160, 44)
    _continue_btn.add_theme_font_size_override(&"font_size", 18)
    _continue_btn.pressed.connect(_on_continue_pressed)
    _continue_btn.hide()
    footer.add_child(_continue_btn)


func _make_column_header() -> HBoxContainer:
    var row := HBoxContainer.new()
    row.custom_minimum_size = Vector2(0, 36)
    row.add_theme_constant_override(&"separation", 0)

    var name_hdr := Label.new()
    name_hdr.text = "Item"
    name_hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    name_hdr.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    name_hdr.add_theme_font_size_override(&"font_size", 14)
    name_hdr.add_theme_color_override(&"font_color", Color(0.7, 0.7, 0.7))
    row.add_child(name_hdr)

    var value_hdr := Label.new()
    value_hdr.text = "True Value"
    value_hdr.custom_minimum_size = Vector2(160, 0)
    value_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    value_hdr.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    value_hdr.add_theme_font_size_override(&"font_size", 14)
    value_hdr.add_theme_color_override(&"font_color", Color(0.7, 0.7, 0.7))
    row.add_child(value_hdr)

    return row


func _make_item_row(item: ItemData) -> HBoxContainer:
    var row := HBoxContainer.new()
    row.custom_minimum_size = Vector2(0, 48)
    row.add_theme_constant_override(&"separation", 0)

    var name_lbl := Label.new()
    name_lbl.text = item.item_name
    name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    name_lbl.add_theme_font_size_override(&"font_size", 16)
    row.add_child(name_lbl)

    var value_lbl := Label.new()
    value_lbl.text = "???"
    value_lbl.custom_minimum_size = Vector2(160, 0)
    value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    value_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    value_lbl.add_theme_font_size_override(&"font_size", 16)
    value_lbl.add_theme_color_override(&"font_color", Color(0.6, 0.6, 0.6))
    row.add_child(value_lbl)

    _value_labels.append(value_lbl)
    return row
