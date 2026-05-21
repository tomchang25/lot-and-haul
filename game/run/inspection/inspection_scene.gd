# inspection_scene.gd
# Block 02 — AP-limited Inspection phase; player searches unknown grid shapes before Auction.
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────

const GRID_COLS := 8
const GRID_ROWS := 8
const CELL_SIZE := Vector2(64.0, 64.0)

const SEARCH_BASE_SECONDS := 2.0
const SEARCH_MAX_SECONDS := 5.0

const SHAPE_COLORS: Array[Color] = [
    Color(0.20, 0.28, 0.40, 1.0),
    Color(0.30, 0.22, 0.38, 1.0),
    Color(0.22, 0.34, 0.27, 1.0),
    Color(0.40, 0.27, 0.18, 1.0),
    Color(0.34, 0.22, 0.24, 1.0),
    Color(0.20, 0.34, 0.36, 1.0),
    Color(0.36, 0.33, 0.20, 1.0),
    Color(0.27, 0.27, 0.40, 1.0),
]

enum ActionType { SEARCH, ADVANCE }

# ── State ─────────────────────────────────────────────────────────────────────

var _ctx: ItemViewContext = null

var _cell_buttons: Dictionary = { }
var _cell_entry: Dictionary = { }
var _entry_cells: Dictionary = { }
var _entry_origin: Dictionary = { }
var _entry_color_by_entry: Dictionary = { }
var _search_duration_by_entry: Dictionary = { }

var _active_entry: ItemEntry = null
var _active_action_type: int = -1
var _active_action_cost: int = 0
var _active_action_remaining: float = 0.0
var _inspection_finished: bool = false

var _hover_entry: ItemEntry = null

# ── Node references ───────────────────────────────────────────────────────────

@onready var _items_grid: GridContainer = $RootHBox/LeftVBox/GridMargin/ScrollContainer/ItemsGrid
@onready var _action_bar: LotActionBar = $LotActionBar
@onready var _footer: HBoxContainer = $RootHBox/LeftVBox/FooterHBox
@onready var _pass_button: Button = $RootHBox/LeftVBox/FooterHBox/FooterMargin/FooterInner/PassButton
@onready var _start_auction_button: Button = $RootHBox/LeftVBox/FooterHBox/FooterMargin/FooterInner/StartAuctionButton
@onready var _review_button: Button = $RootHBox/LeftVBox/FooterHBox/FooterMargin/FooterInner/ReviewButton
@onready var _list_review: ListReviewPopup = $ListReviewPopup
@onready var _stamina_hud: StaminaHUD = $RootHBox/LeftVBox/HeaderHBox/HeaderMargin/HeaderInner/StaminaHUD

# Sidebar — found list
@onready var _found_vbox: VBoxContainer = %FoundVBox
@onready var _empty_found_label: Label = %EmptyFoundLabel

# Sidebar — veiled list
@onready var _veiled_vbox: VBoxContainer = %VeiledVBox
@onready var _empty_veiled_label: Label = %EmptyVeiledLabel

# Sidebar — hover detail
@onready var _sidebar_hsep: HSeparator = %SidebarHSep
@onready var _hover_section: VBoxContainer = %HoverSection
@onready var _hover_name_label: Label = %HoverNameLabel
@onready var _hover_category_label: Label = %HoverCategoryLabel
@onready var _hover_cond_value_label: Label = %CondValueLabel
@onready var _hover_value_label: Label = %ValueValueLabel

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _ctx = ItemViewContext.for_inspection()

    _action_bar.hide()
    _footer.show()
    _pass_button.hide()
    _start_auction_button.hide()
    _review_button.show()
    _review_button.pressed.connect(_on_review_pressed)

    _list_review.back_requested.connect(_on_list_review_pass)
    _list_review.back_to_inspection_requested.connect(_on_back_to_inspection)
    _list_review.auction_entered.connect(_on_auction_entered)

    _build_grid_controls()
    _place_lot_objects()
    _refresh_grid_cells()
    _refresh_hud()
    _refresh_found_list()
    _refresh_veiled_list()
    _clear_hover_section()
    set_process(true)


func _process(delta: float) -> void:
    if _inspection_finished or _active_entry == null:
        return

    _active_action_remaining -= delta
    if _active_action_remaining <= 0.0:
        _complete_active_action()
        return

    _refresh_grid_cells()
    _refresh_hud()

# ══ Grid setup ════════════════════════════════════════════════════════════════


func _build_grid_controls() -> void:
    for child in _items_grid.get_children():
        child.queue_free()

    _items_grid.columns = GRID_COLS
    _items_grid.add_theme_constant_override(&"h_separation", 6)
    _items_grid.add_theme_constant_override(&"v_separation", 6)

    _cell_buttons.clear()
    for row in GRID_ROWS:
        for col in GRID_COLS:
            var coord := Vector2i(col, row)
            var button := Button.new()
            button.custom_minimum_size = CELL_SIZE
            button.focus_mode = Control.FOCUS_NONE
            button.text = ""
            button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
            button.add_theme_font_size_override(&"font_size", 12)
            button.clip_text = true
            button.pressed.connect(_on_grid_cell_pressed.bind(coord))
            button.gui_input.connect(_on_cell_gui_input.bind(coord))
            button.mouse_entered.connect(_on_grid_cell_mouse_entered.bind(coord))
            button.mouse_exited.connect(_on_grid_cell_mouse_exited)
            _items_grid.add_child(button)
            _cell_buttons[coord] = button


func _place_lot_objects() -> void:
    _cell_entry.clear()
    _entry_cells.clear()
    _entry_origin.clear()
    _entry_color_by_entry.clear()
    _search_duration_by_entry.clear()

    for entry: ItemEntry in RunManager.run_record.lot_items:
        _place_entry(entry)


func _place_entry(entry: ItemEntry) -> void:
    var shape_cells := _get_shape_cells(entry)
    var origins := _candidate_origins()
    origins.shuffle()

    for origin: Vector2i in origins:
        if _can_place_shape(shape_cells, origin):
            _commit_shape_placement(entry, shape_cells, origin)
            return

    push_warning("Inspection grid could not place lot object: %s" % entry.display_name)


func _candidate_origins() -> Array[Vector2i]:
    var origins: Array[Vector2i] = []
    for row in GRID_ROWS:
        for col in GRID_COLS:
            origins.append(Vector2i(col, row))
    return origins


func _get_shape_cells(entry: ItemEntry) -> Array[Vector2i]:
    var category := entry.category_data()
    var fallback: Array[Vector2i] = [Vector2i.ZERO]
    if category == null:
        return fallback

    var cells := category.get_cells()
    if cells.is_empty():
        return fallback
    return cells


func _can_place_shape(shape_cells: Array[Vector2i], origin: Vector2i) -> bool:
    for local_cell: Vector2i in shape_cells:
        var world := origin + local_cell
        if world.x < 0 or world.x >= GRID_COLS or world.y < 0 or world.y >= GRID_ROWS:
            return false
        if _cell_entry.has(world):
            return false
    return true


func _commit_shape_placement(
        entry: ItemEntry,
        shape_cells: Array[Vector2i],
        origin: Vector2i,
) -> void:
    var occupied_cells: Array[Vector2i] = []
    for local_cell: Vector2i in shape_cells:
        var world := origin + local_cell
        occupied_cells.append(world)
        _cell_entry[world] = entry

    _entry_cells[entry] = occupied_cells
    _entry_origin[entry] = origin
    _entry_color_by_entry[entry] = SHAPE_COLORS[_entry_color_by_entry.size() % SHAPE_COLORS.size()]
    _search_duration_by_entry[entry] = _compute_search_duration(occupied_cells.size())

# ══ Search interaction ════════════════════════════════════════════════════════


func _on_grid_cell_pressed(coord: Vector2i) -> void:
    if _inspection_finished:
        return
    if _active_entry != null:
        return

    var entry := _cell_entry.get(coord) as ItemEntry
    if entry == null:
        return

    if entry.is_veiled():
        var cost_seconds := _search_cost_for_entry(entry)
        if cost_seconds > RunManager.run_record.actions_remaining:
            return
        _start_action(entry, ActionType.SEARCH, cost_seconds)
        return

    var item := entry as ItemEntry
    if item != null and item.can_advance():
        var cost := _advance_cost_for_item(item)
        if RunManager.run_record.actions_remaining < cost:
            return
        _start_action(entry, ActionType.ADVANCE, cost)
        return


func _start_action(entry: ItemEntry, action_type: int, cost_seconds: int) -> void:
    _active_entry = entry
    _active_action_type = action_type
    _active_action_cost = cost_seconds
    _active_action_remaining = max(0.5, float(cost_seconds) * 0.25)
    _refresh_grid_cells()
    _refresh_hud()


func _complete_active_action() -> void:
    var completed_entry := _active_entry
    var action_type := _active_action_type
    var action_cost := _active_action_cost
    _clear_active_action()

    if completed_entry == null:
        return

    RunManager.run_record.actions_remaining -= action_cost

    match action_type:
        ActionType.SEARCH:
            if completed_entry.is_veiled():
                _reveal_lot_object(completed_entry)
        ActionType.ADVANCE:
            var item := completed_entry as ItemEntry
            if item != null and item.can_advance():
                item.advance_layer()
                item.reveal_passive_clues()

    _refresh_grid_cells()
    _refresh_hud()
    _refresh_found_list()
    _refresh_veiled_list()
    if _hover_entry == completed_entry:
        _update_hover_section(completed_entry)

    if RunManager.run_record.actions_remaining <= 0:
        _finish_inspection()


func _on_cell_gui_input(event: InputEvent, coord: Vector2i) -> void:
    var mouse_event := event as InputEventMouseButton
    if mouse_event == null or not mouse_event.pressed:
        return
    if mouse_event.button_index != MOUSE_BUTTON_RIGHT:
        return
    if _active_entry == null:
        return
    if (_cell_entry.get(coord) as ItemEntry) != _active_entry:
        return
    _cancel_active_action()


func _cancel_active_action() -> void:
    _clear_active_action()
    _refresh_grid_cells()
    _refresh_hud()


func _clear_active_action() -> void:
    _active_entry = null
    _active_action_type = -1
    _active_action_cost = 0
    _active_action_remaining = 0.0


func _advance_cost_for_item(item: ItemEntry) -> int:
    var cost := 1
    var layer := item.active_layer()
    if layer == null:
        return cost
    for clue: ClueData in layer.clues:
        if not item.revealed_clue_ids.has(clue.clue_id):
            cost += clue.ap_cost_penalty
    return cost


func _search_cost_for_entry(entry: ItemEntry) -> int:
    return ceili(float(_search_duration_by_entry.get(entry, SEARCH_BASE_SECONDS)))


func _compute_search_duration(cell_count: int) -> float:
    var size_factor: float = minf(maxi(cell_count - 1, 0) * 0.35, 1.4)
    var random_factor: float = randf_range(0.0, 1.2)
    return clampf(SEARCH_BASE_SECONDS + size_factor + random_factor, SEARCH_BASE_SECONDS, SEARCH_MAX_SECONDS)


func _reveal_lot_object(entry: ItemEntry) -> void:
    var item := entry as ItemEntry
    if item != null:
        _reveal_item_at_random_layer(item)
        return

    entry.perform_inspect()


func _reveal_item_at_random_layer(item: ItemEntry) -> void:
    if item.is_veiled():
        item.unveil()
        if item.item_data != null and item.item_data.category_data != null:
            KnowledgeManager.add_category_points(
                item.item_data.category_data,
                item.item_data.rarity,
                KnowledgeManager.KnowledgeAction.REVEAL,
            )

    item.layer_index = _roll_random_layer_index(item)
    item.reveal_passive_clues()


func _roll_random_layer_index(item: ItemEntry) -> int:
    if item.item_data == null or item.item_data.identity_layers.is_empty():
        return item.layer_index

    var max_index := item.item_data.identity_layers.size() - 1
    if max_index <= 0:
        return 0
    if max_index == 1:
        return 1

    var total_weight := 0.0
    for layer_index in range(1, max_index + 1):
        total_weight += 1.0 / float(layer_index * layer_index)

    var roll := randf_range(0.0, total_weight)
    var running := 0.0
    for layer_index in range(1, max_index + 1):
        running += 1.0 / float(layer_index * layer_index)
        if roll <= running:
            return layer_index

    return max_index

# ══ Display refresh ═══════════════════════════════════════════════════════════


func _refresh_grid_cells() -> void:
    for coord in _cell_buttons:
        var button := _cell_buttons[coord] as Button
        var entry := _cell_entry.get(coord) as ItemEntry
        _refresh_grid_cell(button, coord, entry)


func _refresh_grid_cell(button: Button, coord: Vector2i, entry: ItemEntry) -> void:
    button.disabled = _active_entry != null and entry != _active_entry

    if entry == null:
        button.text = ""
        button.mouse_default_cursor_shape = Control.CURSOR_ARROW
        _apply_cell_style(button, Color(0.18, 0.19, 0.18, 0.55))
        return

    button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    var is_origin: bool = coord == _entry_origin.get(entry, Vector2i(-1, -1))
    var base_color := _entry_grid_color(entry)

    if entry == _active_entry:
        if _active_action_type == ActionType.ADVANCE:
            _apply_cell_style(button, base_color.lerp(Color(1.0, 0.55, 0.26, 1.0), 0.45))
        else:
            _apply_cell_style(button, base_color.lerp(Color(1.0, 0.82, 0.35, 1.0), 0.45))
        button.text = _active_origin_text() if is_origin else ""
    elif not entry.is_veiled():
        var item := entry as ItemEntry
        var is_final_item: bool = item != null and not item.can_advance()
        _apply_cell_style(button, base_color.lightened(0.16 if is_final_item else 0.28))
        button.text = _origin_ap_text(entry) if is_origin else ""
    else:
        _apply_cell_style(button, base_color)
        button.text = _origin_ap_text(entry) if is_origin else ""


func _entry_grid_color(entry: ItemEntry) -> Color:
    return _entry_color_by_entry.get(entry, Color(0.08, 0.08, 0.10, 1.0))


func _origin_ap_text(entry: ItemEntry) -> String:
    if entry.is_veiled():
        return "%d AP" % _search_cost_for_entry(entry)

    var item := entry as ItemEntry
    if item != null and item.can_advance():
        return "%d AP" % _advance_cost_for_item(item)
    return "✓"


func _active_origin_text() -> String:
    return "%d AP\n%0.1fs" % [_active_action_cost, _active_action_remaining]


func _apply_cell_style(button: Button, color: Color) -> void:
    button.modulate = Color.WHITE
    button.add_theme_color_override(&"font_color", Color.WHITE)
    button.add_theme_color_override(&"font_hover_color", Color.WHITE)
    button.add_theme_color_override(&"font_pressed_color", Color.WHITE)
    button.add_theme_color_override(&"font_disabled_color", Color(0.74, 0.74, 0.74, 1.0))
    button.add_theme_stylebox_override(&"normal", _cell_style(color))
    button.add_theme_stylebox_override(&"hover", _cell_style(color.lightened(0.08)))
    button.add_theme_stylebox_override(&"pressed", _cell_style(color.darkened(0.08)))
    button.add_theme_stylebox_override(&"disabled", _cell_style(color.darkened(0.25)))


func _cell_style(color: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.corner_radius_top_left = 6
    style.corner_radius_top_right = 6
    style.corner_radius_bottom_left = 6
    style.corner_radius_bottom_right = 6
    style.border_width_top = 1
    style.border_width_right = 1
    style.border_width_bottom = 1
    style.border_width_left = 1
    style.border_color = color.lightened(0.16)
    return style


func _refresh_hud() -> void:
    var ap: int = RunManager.run_record.actions_remaining
    var quota: int = RunManager.run_record.lot_entry.lot_data.action_quota
    _stamina_hud.update_ap(ap, quota)

# ══ Sidebar — item list ═══════════════════════════════════════════════════════


func _refresh_found_list() -> void:
    for child in _found_vbox.get_children():
        child.free()

    var found_count := 0
    for entry: ItemEntry in _entry_cells.keys():
        if entry.is_veiled():
            continue
        found_count += 1

        var row := HBoxContainer.new()
        row.add_theme_constant_override(&"separation", 8)

        var name_lbl := Label.new()
        name_lbl.text = entry.display_name
        name_lbl.add_theme_font_size_override(&"font_size", 13)
        name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        name_lbl.clip_text = true
        row.add_child(name_lbl)

        var price_text := entry.price_text_for(_ctx)
        if price_text != ItemEntry.UNKNOWN_TEXT:
            var value_lbl := Label.new()
            value_lbl.text = price_text
            value_lbl.add_theme_font_size_override(&"font_size", 13)
            value_lbl.add_theme_color_override(&"font_color", entry.price_display_color())
            row.add_child(value_lbl)

        _found_vbox.add_child(row)

    _empty_found_label.visible = found_count == 0


func _refresh_veiled_list() -> void:
    for child in _veiled_vbox.get_children():
        child.free()

    var veiled_count := 0
    for entry: ItemEntry in _entry_cells.keys():
        if not entry.is_veiled():
            continue
        veiled_count += 1

        var row := HBoxContainer.new()
        row.add_theme_constant_override(&"separation", 8)

        var name_lbl := Label.new()
        name_lbl.text = entry.display_name
        name_lbl.add_theme_font_size_override(&"font_size", 13)
        name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        name_lbl.clip_text = true
        row.add_child(name_lbl)

        var ap_lbl := Label.new()
        ap_lbl.text = "%d AP" % _search_cost_for_entry(entry)
        ap_lbl.add_theme_font_size_override(&"font_size", 13)
        ap_lbl.add_theme_color_override(&"font_color", Color(0.55, 0.58, 0.63, 1))
        row.add_child(ap_lbl)

        _veiled_vbox.add_child(row)

    _empty_veiled_label.visible = veiled_count == 0

# ══ Sidebar — hover section ═══════════════════════════════════════════════════


func _on_grid_cell_mouse_entered(coord: Vector2i) -> void:
    var entry := _cell_entry.get(coord) as ItemEntry
    if entry == null:
        return
    _update_hover_section(entry)


func _on_grid_cell_mouse_exited() -> void:
    pass # keep last hovered item visible


func _update_hover_section(entry: ItemEntry) -> void:
    _hover_entry = entry
    _hover_name_label.text = entry.display_name

    var cat := entry.category_text() if not entry.is_veiled() else ""
    _hover_category_label.text = cat
    _hover_category_label.visible = cat != ""

    var cond := entry.condition_detail_text()
    _hover_cond_value_label.text = cond if cond != "" else "—"
    _hover_cond_value_label.add_theme_color_override(
        &"font_color",
        entry.condition_display_color() if cond != "" else Color(0.55, 0.58, 0.63, 1),
    )

    var price_text := entry.price_text_for(_ctx)
    if price_text != ItemEntry.UNKNOWN_TEXT:
        _hover_value_label.text = price_text
        _hover_value_label.add_theme_color_override(&"font_color", entry.price_display_color())
    else:
        _hover_value_label.text = "—"
        _hover_value_label.add_theme_color_override(&"font_color", Color(0.55, 0.58, 0.63, 1))

    _sidebar_hsep.show()
    _hover_section.show()


func _clear_hover_section() -> void:
    _hover_entry = null
    _sidebar_hsep.hide()
    _hover_section.hide()

# ══ Summary / exit ════════════════════════════════════════════════════════════


func _finish_inspection() -> void:
    if _inspection_finished:
        return

    _inspection_finished = true
    _clear_active_action()
    set_process(false)

    _clear_hover_section()
    _refresh_grid_cells()
    _refresh_hud()
    _refresh_found_list()
    _refresh_veiled_list()
    _list_review.populate()
    _list_review.show()


func _on_review_pressed() -> void:
    if _inspection_finished:
        return
    _cancel_active_action()
    set_process(false)
    _list_review.populate()
    _list_review.show()


func _on_back_to_inspection() -> void:
    _list_review.hide()
    if _inspection_finished:
        return
    set_process(true)
    _refresh_grid_cells()
    _refresh_hud()


func _on_list_review_pass() -> void:
    GameManager.go_to_lot_browse()


func _on_auction_entered() -> void:
    GameManager.go_to_auction()
