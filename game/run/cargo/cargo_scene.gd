# cargo_scene.gd
# Block 05 — Cargo Loading (v2: 2-D grid packing)
# Reads:  RunManager.run_record.won_items, RunManager.run_record.car_data
# Writes: RunManager.run_record.cargo_items, RunManager.run_record.trailer_items,
#         RunManager.run_record.onsite_proceeds
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────

const ONSITE_SELL_PRICE := 50
const CELL_SIZE := 56
const CELL_GAP := 3

const ItemRowTooltipScene: PackedScene = preload("uid://3kvnpn7pek5i")
const CargoItemRowScene: PackedScene = preload("res://game/run/cargo/cargo_item_row.tscn")

# ── Enums ─────────────────────────────────────────────────────────────────────

enum Phase {
    IDLE,
    ITEM_HELD,
}

# ── State ─────────────────────────────────────────────────────────────────────

var _won_items: Array[ItemEntry] = []

var _active_item: ItemEntry = null
var _active_origin: String = ""
var _active_origin_pos: Vector2i = Vector2i(-1, -1)

var _extra_slot_items: Array[ItemEntry] = []
var _active_origin_extra_index: int = -1

var _hover_cell: Vector2i = Vector2i(-1, -1)
var _hover_extra_index: int = -1

var _phase: Phase = Phase.IDLE
var _active_rotation: int = 0
var _item_rotations: Dictionary = { }

# ── Cargo Grid State ──────────────────────────────────────────────────────────

var _cargo_placement: Dictionary = { }
var _cargo_cells: Dictionary = { }

# ── Extra Slot Grid State ─────────────────────────────────────────────────────

var _extra_slot_cells: Dictionary = { }

# ── Item List State ───────────────────────────────────────────────────────────

var _item_rows: Dictionary = { }
var _loaded_items: Array[ItemEntry] = []

# ── Stats ─────────────────────────────────────────────────────────────────────

var _slots_used: int = 0
var _weight_used: float = 0.0
var _item_colors: Dictionary = { }

# ── Tooltip Support ───────────────────────────────────────────────────────────

var _ctx: ItemViewContext = null
var _tooltip: ItemRowTooltip = null
var _hovered_item: ItemEntry = null

# ── Node references ───────────────────────────────────────────────────────────

@onready var _item_list_vbox: VBoxContainer = $MainHBox/ItemListPanel/ItemListScroll/ItemListVBox
@onready var _error_label: Label = $MainHBox/VehiclePanel/ErrorLabel
@onready var _cargo_grid: GridContainer = $MainHBox/VehiclePanel/CargoSection/CargoGrid
@onready var _trailer_section: HBoxContainer = $MainHBox/VehiclePanel/TrailerSection
@onready var _extra_slot_container: HBoxContainer = $MainHBox/VehiclePanel/TrailerSection/TrailerSlotContainer
@onready var _reset_btn: Button = $ResetButton
@onready var _continue_btn: Button = $ContinueButton
@onready var _confirm_popup: ConfirmationDialog = $ConfirmPopup
@onready var _summary_loaded_count: Label = $MainHBox/VehiclePanel/RunSummary/SummaryVBox/LoadedLine/LoadedCountLabel
@onready var _summary_loaded_value: Label = $MainHBox/VehiclePanel/RunSummary/SummaryVBox/LoadedLine/LoadedValueLabel
@onready var _summary_unloaded_count: Label = $MainHBox/VehiclePanel/RunSummary/SummaryVBox/UnloadedLine/UnloadedCountLabel
@onready var _summary_unloaded_sell: Label = $MainHBox/VehiclePanel/RunSummary/SummaryVBox/UnloadedLine/UnloadedSellLabel
@onready var _summary_weight: Label = $MainHBox/VehiclePanel/RunSummary/SummaryVBox/WeightLabel
@onready var _summary_slots: Label = $MainHBox/VehiclePanel/RunSummary/SummaryVBox/SlotsLabel
@onready var _summary_trailer_line: HBoxContainer = $MainHBox/VehiclePanel/RunSummary/SummaryVBox/TrailerLine
@onready var _summary_trailer_value: Label = $MainHBox/VehiclePanel/RunSummary/SummaryVBox/TrailerLine/TrailerRiskValue
@onready var _run_summary: PanelContainer = $MainHBox/VehiclePanel/RunSummary

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _ctx = ItemViewContext.for_cargo()
    _tooltip = ItemRowTooltipScene.instantiate()
    add_child(_tooltip)

    _run_summary.add_theme_stylebox_override(
        &"panel",
        _make_stylebox(
            Color(0.15, 0.15, 0.18, 1.0),
            Color(0.40, 0.40, 0.45, 1.0),
        ),
    )

    _reset_btn.pressed.connect(_on_reset_pressed)
    _continue_btn.pressed.connect(_on_continue_pressed)
    _confirm_popup.confirmed.connect(_on_confirm_popup_confirmed)

    _won_items = RunManager.run_record.won_items

    _extra_slot_items.resize(RunManager.run_record.car_data.extra_slot_count)
    _extra_slot_items.fill(null)

    _assign_item_colors()

    _build_cargo_grid()
    _build_item_list()
    _build_extra_slots()
    _recalc_totals()
    _refresh_ui()


func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
            if _phase == Phase.ITEM_HELD:
                _cancel_placement()
                accept_event()


func _unhandled_input(event: InputEvent) -> void:
    if _phase != Phase.ITEM_HELD or _active_item == null:
        return
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_Q:
                _active_rotation = (_active_rotation + 3) % 4
                _refresh_cargo_cell_visuals()
                get_viewport().set_input_as_handled()
            KEY_E:
                _active_rotation = (_active_rotation + 1) % 4
                _refresh_cargo_cell_visuals()
                get_viewport().set_input_as_handled()

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_reset_pressed() -> void:
    _cargo_placement.clear()
    _extra_slot_items.fill(null)

    _active_item = null
    _active_origin = ""
    _active_origin_pos = Vector2i(-1, -1)
    _active_origin_extra_index = -1
    _phase = Phase.IDLE
    _item_rotations.clear()

    _recalc_totals()
    _refresh_ui()


func _on_continue_pressed() -> void:
    _confirm_popup.dialog_text = _build_summary_text()
    _confirm_popup.popup_centered()


func _on_confirm_popup_confirmed() -> void:
    var cargo: Array[ItemEntry] = []
    for pos: Vector2i in _cargo_placement:
        var entry: ItemEntry = _cargo_placement[pos]
        if entry not in cargo:
            cargo.append(entry)
    RunManager.run_record.cargo_items = cargo

    var trailer: Array[ItemEntry] = []
    for entry: ItemEntry in _extra_slot_items:
        if entry != null:
            trailer.append(entry)
    RunManager.run_record.trailer_items = trailer

    var unplaced_count := 0
    for entry: ItemEntry in _won_items:
        if entry not in cargo and entry not in trailer:
            unplaced_count += 1
    RunManager.run_record.onsite_proceeds = unplaced_count * ONSITE_SELL_PRICE
    GameManager.go_to_run_review()


func _on_cargo_cell_pressed(cell_pos: Vector2i) -> void:
    _hide_tooltip()
    if _phase == Phase.IDLE:
        if _cargo_placement.has(cell_pos):
            var entry: ItemEntry = _cargo_placement[cell_pos]
            if _item_rows.has(entry):
                _item_rows[entry].set_external_highlight(false)
            _lift_from_cargo(entry)
    elif _phase == Phase.ITEM_HELD:
        if _can_place_at_cargo(_active_item, cell_pos):
            _place_item_in_cargo(_active_item, cell_pos)


func _on_extra_slot_pressed(slot_index: int) -> void:
    _hide_tooltip()
    if _phase == Phase.IDLE:
        if _extra_slot_items[slot_index] != null:
            var entry: ItemEntry = _extra_slot_items[slot_index]
            if _item_rows.has(entry):
                _item_rows[entry].set_external_highlight(false)
            _lift_from_extra(slot_index)
    elif _phase == Phase.ITEM_HELD:
        _place_item_in_extra(slot_index)


func _on_item_row_pressed(entry: ItemEntry) -> void:
    _hide_tooltip()
    if _item_rows.has(entry):
        _item_rows[entry].set_external_highlight(false)
    if _phase == Phase.ITEM_HELD:
        _cancel_placement()
    _lift_item_entry(entry)


func _on_row_tooltip_requested(entry: ItemEntry, anchor: Rect2) -> void:
    _show_tooltip_for_item(entry, anchor)


func _on_row_tooltip_dismissed() -> void:
    _hide_tooltip()

# ══ Item lift helpers ═════════════════════════════════════════════════════════


func _lift_item_entry(entry: ItemEntry) -> void:
    if _is_item_in_cargo(entry):
        _lift_from_cargo(entry)
    elif _is_item_in_extra(entry):
        var idx: int = _extra_slot_items.find(entry)
        _lift_from_extra(idx)
    else:
        _lift_from_list(entry)


func _is_item_in_cargo(entry: ItemEntry) -> bool:
    for pos: Vector2i in _cargo_placement:
        if _cargo_placement[pos] == entry:
            return true
    return false


func _is_item_in_extra(entry: ItemEntry) -> bool:
    return entry in _extra_slot_items


func _lift_from_list(entry: ItemEntry) -> void:
    _active_item = entry
    _active_rotation = _item_rotations.get(entry, 0)
    _active_origin = "list"
    _active_origin_pos = Vector2i(-1, -1)
    _phase = Phase.ITEM_HELD
    _refresh_ui()

# ══ Color assignment ═══════════════════════════════════════════════════════════


func _assign_item_colors() -> void:
    var golden_ratio := 0.618033988749895
    var hue := randf()

    for entry: ItemEntry in _won_items:
        hue = fmod(hue + golden_ratio, 1.0)
        var color := Color.from_hsv(hue, 0.55, 0.50)
        _item_colors[entry] = color


func _get_item_color(entry: ItemEntry) -> Color:
    if _item_colors.has(entry):
        return _item_colors[entry]
    return Color(0.22, 0.30, 0.42, 1.0)


func _get_item_border_color(entry: ItemEntry) -> Color:
    if _item_colors.has(entry):
        var base: Color = _item_colors[entry]
        return base.lightened(0.35)
    return Color(0.40, 0.55, 0.75, 1.0)

# ══ Grid construction ══════════════════════════════════════════════════════════


func _build_cargo_grid() -> void:
    var cols := RunManager.run_record.car_data.grid_columns
    var rows := RunManager.run_record.car_data.grid_rows

    _cargo_grid.columns = cols

    for row in rows:
        for col in cols:
            var pos := Vector2i(col, row)
            var cell := _make_cargo_cell(pos)
            _cargo_grid.add_child(cell)
            _cargo_cells[pos] = cell


func _build_extra_slots() -> void:
    var count := RunManager.run_record.car_data.extra_slot_count
    _trailer_section.visible = count > 0
    for i in count:
        var cell := _make_extra_slot_cell(i)
        _extra_slot_container.add_child(cell)
        _extra_slot_cells[i] = cell


func _build_item_list() -> void:
    for entry: ItemEntry in _won_items:
        var row: CargoItemRow = CargoItemRowScene.instantiate()
        row.setup(entry, _ctx)
        row.row_pressed.connect(_on_item_row_pressed)
        row.tooltip_requested.connect(_on_row_tooltip_requested)
        row.tooltip_dismissed.connect(_on_row_tooltip_dismissed)
        _item_list_vbox.add_child(row)
        _item_rows[entry] = row

# ══ Placement logic ════════════════════════════════════════════════════════════


func _get_active_cells(entry: ItemEntry) -> Array[Vector2i]:
    var base: Array[Vector2i] = entry.item_data.category_data.get_cells()
    return CargoShapes.rotate_cells(base, _active_rotation)


func _can_place_at_cargo(entry: ItemEntry, origin: Vector2i) -> bool:
    var cols := RunManager.run_record.car_data.grid_columns
    var rows := RunManager.run_record.car_data.grid_rows
    var cells: Array[Vector2i] = _get_active_cells(entry)

    for c: Vector2i in cells:
        var world := origin + c
        if world.x < 0 or world.x >= cols or world.y < 0 or world.y >= rows:
            return false
        if _cargo_placement.has(world) and _cargo_placement[world] != entry:
            return false

    if _would_exceed_weight(entry):
        return false

    return true


func _would_exceed_weight(entry: ItemEntry) -> bool:
    var max_weight: float = RunManager.run_record.car_data.max_weight
    var entry_weight: float = entry.item_data.category_data.weight

    var already_in_cargo := false
    for pos: Vector2i in _cargo_placement:
        if _cargo_placement[pos] == entry:
            already_in_cargo = true
            break

    if already_in_cargo:
        return false
    else:
        return (_weight_used + entry_weight) > max_weight


func _get_pending_weight(entry: ItemEntry) -> float:
    for pos: Vector2i in _cargo_placement:
        if _cargo_placement[pos] == entry:
            return 0.0
    return entry.item_data.category_data.weight


func _get_pending_slots(entry: ItemEntry) -> int:
    for pos: Vector2i in _cargo_placement:
        if _cargo_placement[pos] == entry:
            return 0
    return _get_active_cells(entry).size()


func _place_item_in_cargo(entry: ItemEntry, origin: Vector2i) -> void:
    _erase_from_cargo(entry)
    _erase_from_extra(entry)

    var cells: Array[Vector2i] = _get_active_cells(entry)
    for c: Vector2i in cells:
        _cargo_placement[origin + c] = entry

    _item_rotations[_active_item] = _active_rotation
    _active_item = null
    _active_origin = ""
    _active_origin_pos = Vector2i(-1, -1)
    _phase = Phase.IDLE
    _recalc_totals()
    _refresh_ui()


func _erase_from_cargo(entry: ItemEntry) -> void:
    var keys_to_erase: Array[Vector2i] = []
    for pos: Vector2i in _cargo_placement:
        if _cargo_placement[pos] == entry:
            keys_to_erase.append(pos)
    for pos: Vector2i in keys_to_erase:
        _cargo_placement.erase(pos)


func _erase_from_extra(entry: ItemEntry) -> void:
    for i in _extra_slot_items.size():
        if _extra_slot_items[i] == entry:
            _extra_slot_items[i] = null


func _lift_from_cargo(entry: ItemEntry) -> void:
    var origin_pos := Vector2i(999, 999)
    for pos: Vector2i in _cargo_placement:
        if _cargo_placement[pos] == entry:
            if pos.y < origin_pos.y or (pos.y == origin_pos.y and pos.x < origin_pos.x):
                origin_pos = pos

    _active_item = entry
    _active_rotation = _item_rotations.get(entry, 0)
    _active_origin = "cargo"
    _active_origin_pos = origin_pos
    _phase = Phase.ITEM_HELD
    _refresh_ui()


func _lift_from_extra(slot_index: int) -> void:
    _active_item = _extra_slot_items[slot_index]
    _active_rotation = _item_rotations.get(_active_item, 0)
    _active_origin = "extra"
    _active_origin_extra_index = slot_index
    _extra_slot_items[slot_index] = null
    _phase = Phase.ITEM_HELD
    _recalc_totals()
    _refresh_ui()


func _cancel_placement() -> void:
    if _phase != Phase.ITEM_HELD or _active_item == null:
        return

    if _active_origin == "extra":
        _extra_slot_items[_active_origin_extra_index] = _active_item
        _active_origin_extra_index = -1

    _active_item = null
    _active_rotation = 0
    _active_origin = ""
    _active_origin_pos = Vector2i(-1, -1)
    _phase = Phase.IDLE

    _recalc_totals()
    _refresh_ui()


func _place_item_in_extra(slot_index: int) -> void:
    if _extra_slot_items[slot_index] != null:
        return

    if _active_origin == "cargo":
        _erase_from_cargo(_active_item)

    _extra_slot_items[slot_index] = _active_item
    _active_item = null
    _active_origin = ""
    _active_origin_pos = Vector2i(-1, -1)
    _active_origin_extra_index = -1
    _phase = Phase.IDLE
    _recalc_totals()
    _refresh_ui()

# ══ UI helpers ════════════════════════════════════════════════════════════════


func _recalc_totals() -> void:
    _slots_used = 0
    _weight_used = 0.0
    _loaded_items.clear()

    var seen: Array[ItemEntry] = []
    for pos: Vector2i in _cargo_placement:
        var entry: ItemEntry = _cargo_placement[pos]
        if entry not in seen:
            seen.append(entry)
            _loaded_items.append(entry)
            _slots_used += entry.item_data.category_data.get_cells().size()
            _weight_used += entry.item_data.category_data.weight

    for entry: ItemEntry in _extra_slot_items:
        if entry != null and entry not in _loaded_items:
            _loaded_items.append(entry)


func _refresh_ui() -> void:
    var cols := RunManager.run_record.car_data.grid_columns
    var rows := RunManager.run_record.car_data.grid_rows
    var max_slots := cols * rows
    var max_weight: float = RunManager.run_record.car_data.max_weight

    var pending_slots := 0
    var pending_weight := 0.0
    var weight_exceeded := false

    if _phase == Phase.ITEM_HELD and _active_item != null:
        pending_slots = _get_pending_slots(_active_item)
        pending_weight = _get_pending_weight(_active_item)
        weight_exceeded = (_weight_used + pending_weight) > max_weight

    _update_summary(pending_slots, pending_weight, weight_exceeded, max_slots, max_weight)

    if weight_exceeded:
        _error_label.text = "Weight limit exceeded! Cannot place item."
    else:
        _error_label.text = ""

    _refresh_cargo_cell_visuals()
    _refresh_extra_slot_visuals()
    _refresh_item_list_visuals()


func _update_summary(pending_slots: int, pending_weight: float, weight_exceeded: bool, max_slots: int, max_weight: float) -> void:
    # ── Loaded items count and value ─────────────────────────────────────────
    var loaded_count := _loaded_items.size()
    var loaded_value_min := 0
    var loaded_value_max := 0
    for entry: ItemEntry in _loaded_items:
        if not entry.is_veiled():
            loaded_value_min += entry.estimated_value_min
            loaded_value_max += entry.estimated_value_max

    _summary_loaded_count.text = "%d item%s" % [loaded_count, "s" if loaded_count != 1 else ""]

    if loaded_count > 0 and loaded_value_max > 0:
        _summary_loaded_value.text = "$%d – $%d" % [loaded_value_min, loaded_value_max]
    else:
        _summary_loaded_value.text = ""

    # ── Unloaded items count and on-site sell ───────────────────────────────
    var unplaced_count := _won_items.size() - loaded_count
    var unplaced_sell := unplaced_count * ONSITE_SELL_PRICE
    _summary_unloaded_count.text = "%d item%s" % [unplaced_count, "s" if unplaced_count != 1 else ""]
    _summary_unloaded_sell.text = "On-site sell: $%d" % unplaced_sell

    # ── Weight ──────────────────────────────────────────────────────────────
    if pending_weight > 0.0:
        _summary_weight.text = "%.1f + %.1f / %.1f kg" % [_weight_used, pending_weight, max_weight]
        if weight_exceeded:
            _summary_weight.add_theme_color_override(&"font_color", Color(0.9, 0.3, 0.3, 1.0))
        else:
            _summary_weight.add_theme_color_override(&"font_color", Color(0.35, 0.75, 0.40, 1.0))
    else:
        _summary_weight.text = "%.1f / %.1f kg" % [_weight_used, max_weight]
        _summary_weight.remove_theme_color_override(&"font_color")

    # ── Slots ───────────────────────────────────────────────────────────────
    if pending_slots > 0:
        _summary_slots.text = "%d + %d / %d" % [_slots_used, pending_slots, max_slots]
    else:
        _summary_slots.text = "%d / %d" % [_slots_used, max_slots]

    # ── Trailer damage risk ─────────────────────────────────────────────────
    var has_trailer_items := false
    for entry: ItemEntry in _extra_slot_items:
        if entry != null:
            has_trailer_items = true
            break

    var trailer_damage: float = RunManager.run_record.car_data.trailer_damage_chance
    if has_trailer_items and trailer_damage > 0.0:
        _summary_trailer_line.visible = true
        _summary_trailer_value.text = "%d%%" % int(trailer_damage * 100)
    else:
        _summary_trailer_line.visible = false


func _refresh_cargo_cell_visuals() -> void:
    var preview_cells: Array[Vector2i] = []
    var preview_valid := false
    if _phase == Phase.ITEM_HELD and _hover_cell != Vector2i(-1, -1) and _active_item != null:
        preview_valid = _can_place_at_cargo(_active_item, _hover_cell)
        for c: Vector2i in _get_active_cells(_active_item):
            preview_cells.append(_hover_cell + c)

    for pos: Vector2i in _cargo_cells:
        var cell: Panel = _cargo_cells[pos]
        var style: StyleBoxFlat
        if pos in preview_cells:
            if preview_valid:
                style = _make_stylebox(
                    Color(0.20, 0.45, 0.22, 1.0),
                    Color(0.35, 0.75, 0.40, 1.0),
                )
            else:
                style = _make_stylebox(
                    Color(0.45, 0.18, 0.18, 1.0),
                    Color(0.75, 0.30, 0.30, 1.0),
                )
        elif _cargo_placement.has(pos):
            var entry: ItemEntry = _cargo_placement[pos]
            if _phase == Phase.ITEM_HELD and _active_item == entry:
                var base_color := _get_item_color(entry)
                style = _make_stylebox(
                    base_color.lightened(0.2),
                    _get_item_border_color(entry).lightened(0.15),
                )
            else:
                style = _make_stylebox(
                    _get_item_color(entry),
                    _get_item_border_color(entry),
                )
        else:
            style = _make_stylebox(
                Color(0.18, 0.18, 0.20, 1.0),
                Color(0.35, 0.35, 0.38, 1.0),
            )
        cell.add_theme_stylebox_override("panel", style)


func _refresh_extra_slot_visuals() -> void:
    for i: int in _extra_slot_cells:
        var cell: Panel = _extra_slot_cells[i]
        var style: StyleBoxFlat
        var entry: ItemEntry = _extra_slot_items[i] if i < _extra_slot_items.size() else null
        if entry != null:
            if i == _hover_extra_index and _phase != Phase.ITEM_HELD:
                style = _make_stylebox(
                    _get_item_color(entry).lightened(0.2),
                    _get_item_border_color(entry).lightened(0.15),
                )
            else:
                style = _make_stylebox(
                    _get_item_color(entry),
                    _get_item_border_color(entry),
                )
        elif i == _hover_extra_index and _phase == Phase.ITEM_HELD:
            style = _make_stylebox(
                Color(0.20, 0.45, 0.22, 1.0),
                Color(0.35, 0.75, 0.40, 1.0),
            )
        else:
            style = _make_stylebox(
                Color(0.18, 0.18, 0.20, 1.0),
                Color(0.35, 0.35, 0.38, 1.0),
            )
        cell.add_theme_stylebox_override("panel", style)

        var icon_label: Label = cell.get_node("IconLabel")
        if entry != null:
            var words = entry.active_layer().display_name.split(" ", false)
            icon_label.text = (words[0].left(1) if words.size() > 0 else "") + (words[1].left(1) if words.size() > 1 else "")
            icon_label.text = icon_label.text.to_upper()
        else:
            icon_label.text = ""


func _refresh_item_list_visuals() -> void:
    for entry: ItemEntry in _item_rows:
        var row: CargoItemRow = _item_rows[entry]
        row.set_loaded(_is_item_loaded(entry))
        row.set_holding(entry == _active_item and _phase == Phase.ITEM_HELD)


func _is_item_loaded(entry: ItemEntry) -> bool:
    for pos: Vector2i in _cargo_placement:
        if _cargo_placement[pos] == entry:
            return true
    return entry in _extra_slot_items


func _build_summary_text() -> String:
    var loaded_count := _loaded_items.size()
    var unplaced_count := _won_items.size() - loaded_count
    var proceeds := unplaced_count * ONSITE_SELL_PRICE
    return (
        "Loaded items: %d\n" % loaded_count +
        "Left behind: %d  (sold on-site for $%d)\n\n" % [unplaced_count, proceeds] +
        "Continue to settlement?"
    )

# ══ Cell builders ══════════════════════════════════════════════════════════════


func _make_stylebox(bg: Color, border: Color) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_width_left = 1
    s.border_width_right = 1
    s.border_width_top = 1
    s.border_width_bottom = 1
    s.border_color = border
    return s


func _make_cargo_cell(pos: Vector2i) -> Panel:
    var cell := Panel.new()
    cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
    cell.set_meta("cell_pos", pos)

    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.18, 0.18, 0.20, 1.0)
    style.border_width_left = 1
    style.border_width_right = 1
    style.border_width_top = 1
    style.border_width_bottom = 1
    style.border_color = Color(0.35, 0.35, 0.38, 1.0)
    cell.add_theme_stylebox_override("panel", style)

    cell.mouse_entered.connect(
        func() -> void:
            _hover_cell = pos
            _refresh_cargo_cell_visuals()
            if _phase != Phase.ITEM_HELD and _cargo_placement.has(pos):
                var entry: ItemEntry = _cargo_placement[pos]
                if _item_rows.has(entry):
                    _item_rows[entry].set_external_highlight(true)
                    _show_tooltip_for_item(entry, _item_rows[entry].get_global_rect())
                else:
                    _show_tooltip_for_item(entry, cell.get_global_rect())
    )
    cell.mouse_exited.connect(
        func() -> void:
            if _hover_cell == pos:
                _hover_cell = Vector2i(-1, -1)
            if _cargo_placement.has(pos) and _item_rows.has(_cargo_placement[pos]):
                _item_rows[_cargo_placement[pos]].set_external_highlight(false)
            _refresh_cargo_cell_visuals()
            _hide_tooltip()
    )

    cell.gui_input.connect(
        func(event: InputEvent) -> void:
            if event is InputEventMouseButton and event.pressed:
                if event.button_index == MOUSE_BUTTON_LEFT:
                    _on_cargo_cell_pressed(pos)
                elif event.button_index == MOUSE_BUTTON_RIGHT:
                    if _phase == Phase.ITEM_HELD:
                        _cancel_placement()
    )
    return cell


func _make_extra_slot_cell(slot_index: int) -> Panel:
    var cell := Panel.new()
    cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
    cell.set_meta("slot_index", slot_index)

    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.18, 0.18, 0.20, 1.0)
    style.border_width_left = 1
    style.border_width_right = 1
    style.border_width_top = 1
    style.border_width_bottom = 1
    style.border_color = Color(0.35, 0.35, 0.38, 1.0)
    cell.add_theme_stylebox_override("panel", style)

    var icon_label := Label.new()
    icon_label.name = "IconLabel"
    icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    icon_label.anchors_preset = Control.PRESET_FULL_RECT
    icon_label.add_theme_font_size_override("font_size", 14)
    cell.add_child(icon_label)

    cell.mouse_entered.connect(
        func() -> void:
            _hover_extra_index = slot_index
            _refresh_extra_slot_visuals()

            if _phase != Phase.ITEM_HELD and _extra_slot_items[slot_index] != null:
                var entry: ItemEntry = _extra_slot_items[slot_index]
                if _item_rows.has(entry):
                    _item_rows[entry].set_external_highlight(true)
                    _show_tooltip_for_item(entry, _item_rows[entry].get_global_rect())
                else:
                    _show_tooltip_for_item(entry, cell.get_global_rect())
    )
    cell.mouse_exited.connect(
        func() -> void:
            if _hover_extra_index == slot_index:
                _hover_extra_index = -1
            if slot_index < _extra_slot_items.size() and _extra_slot_items[slot_index] != null \
            and _item_rows.has(_extra_slot_items[slot_index]):
                _item_rows[_extra_slot_items[slot_index]].set_external_highlight(false)
            _refresh_extra_slot_visuals()
            _hide_tooltip()
    )

    cell.gui_input.connect(
        func(event: InputEvent) -> void:
            if event is InputEventMouseButton and event.pressed:
                if event.button_index == MOUSE_BUTTON_LEFT:
                    _on_extra_slot_pressed(slot_index)
                elif event.button_index == MOUSE_BUTTON_RIGHT:
                    if _phase == Phase.ITEM_HELD:
                        _cancel_placement()
    )
    return cell

# ══ Tooltip helpers ════════════════════════════════════════════════════════════


func _show_tooltip_for_item(entry: ItemEntry, anchor: Rect2) -> void:
    if _phase == Phase.ITEM_HELD:
        return
    _hovered_item = entry
    _tooltip.show_for(entry, _ctx, anchor)


func _hide_tooltip() -> void:
    _hovered_item = null
    _tooltip.hide_tooltip()
