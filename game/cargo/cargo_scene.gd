# cargo_scene_v2.gd
# Block 05 — Cargo Loading (v2: 2-D grid packing)
# Reads:  RunManager.run_record.won_items, RunManager.run_record.car_config
# Writes: RunManager.run_record.cargo_items, RunManager.run_record.onsite_proceeds
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────

const ONSITE_SELL_PRICE := 50
const CELL_SIZE := 56 # px per grid cell
const CELL_GAP := 3 # px between cells

# ── Enums ─────────────────────────────────────────────────────────────────────

enum Phase {
    IDLE, # nothing held; normal state
    ITEM_HELD, # player is holding an item, tracking mouse
}

# ── State ─────────────────────────────────────────────────────────────────────

# All items from this run.
var _won_items: Array[ItemEntry] = []

# Items currently sitting in temp storage (not yet placed in cargo).
var _temp_items: Array[ItemEntry] = []

# Maps cargo grid position → ItemEntry.
# Only occupied cells appear as keys.
var _cargo_placement: Dictionary = { } # Vector2i → ItemEntry

# Currently held item and where it came from ("temp" | "cargo").
var _active_item: ItemEntry = null
var _active_origin: String = ""

# Current hover position in cargo grid coords (invalid when not hovering).
var _hover_cell: Vector2i = Vector2i(-1, -1)

var _phase: Phase = Phase.IDLE

# Runtime cell controls built in _build_cargo_grid().
# Maps grid position → the Panel node representing that cell.
var _cargo_cells: Dictionary = { } # Vector2i → Panel

# Maps ItemEntry → the Panel node in temp storage.
var _temp_item_nodes: Dictionary = { } # ItemEntry → Panel

var _slots_used: int = 0
var _weight_used: float = 0.0

# ── Node references ───────────────────────────────────────────────────────────

@onready var _slots_label: Label = $RootVBox/StatsBar/SlotsLabel
@onready var _weight_label: Label = $RootVBox/StatsBar/WeightLabel
@onready var _cargo_grid: GridContainer = $RootVBox/CargoSection/CargoGrid
@onready var _temp_grid: GridContainer = $RootVBox/TempSection/TempGrid
@onready var _reset_btn: Button = $RootVBox/Footer/ResetButton
@onready var _continue_btn: Button = $RootVBox/Footer/ContinueButton

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _reset_btn.pressed.connect(_on_reset_pressed)
    _continue_btn.pressed.connect(_on_continue_pressed)

    _won_items = RunManager.run_record.won_items
    _temp_items = _won_items.duplicate()

    _build_cargo_grid()
    _populate_temp_storage()
    _recalc_totals()
    _refresh_ui()

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_reset_pressed() -> void:
    var unique_entries: Array[ItemEntry] = []
    for pos: Vector2i in _cargo_placement:
        var entry: ItemEntry = _cargo_placement[pos]
        if entry not in unique_entries:
            unique_entries.append(entry)
    for entry: ItemEntry in unique_entries:
        _temp_items.append(entry)
    _cargo_placement.clear()

    _active_item = null
    _active_origin = ""
    _phase = Phase.IDLE
    _populate_temp_storage()
    _recalc_totals()
    _refresh_ui()


func _on_continue_pressed() -> void:
    var cargo: Array[ItemEntry] = []
    for pos: Vector2i in _cargo_placement:
        var entry: ItemEntry = _cargo_placement[pos]
        if entry not in cargo:
            cargo.append(entry)
    RunManager.run_record.cargo_items = cargo
    RunManager.run_record.onsite_proceeds = _temp_items.size() * ONSITE_SELL_PRICE
    GameManager.go_to_run_review()


func _on_cargo_cell_pressed(cell_pos: Vector2i) -> void:
    if _phase == Phase.IDLE:
        if _cargo_placement.has(cell_pos):
            _lift_from_cargo(_cargo_placement[cell_pos])
    elif _phase == Phase.ITEM_HELD:
        if _can_place_at(_active_item, cell_pos):
            _place_item(_active_item, cell_pos)


func _on_temp_item_pressed(entry: ItemEntry) -> void:
    if _phase == Phase.ITEM_HELD and _active_item == entry:
        _active_item = null
        _active_origin = ""
        _phase = Phase.IDLE
        _refresh_ui()
    else:
        _active_item = entry
        _active_origin = "temp"
        _phase = Phase.ITEM_HELD
        _refresh_ui()

# ══ Grid construction ══════════════════════════════════════════════════════════


func _build_cargo_grid() -> void:
    # Hardcoded 8×4 for now; wire to CarConfig.grid_columns/grid_rows later.
    const COLS := 8
    const ROWS := 4
    _cargo_grid.columns = COLS

    for row in ROWS:
        for col in COLS:
            var pos := Vector2i(col, row)
            var cell := _make_cell(pos)
            _cargo_grid.add_child(cell)
            _cargo_cells[pos] = cell


func _populate_temp_storage() -> void:
    for child in _temp_grid.get_children():
        child.queue_free()
    _temp_item_nodes.clear()

    for entry: ItemEntry in _temp_items:
        var node := _make_temp_item_node(entry)
        _temp_grid.add_child(node)
        _temp_item_nodes[entry] = node

# ══ Placement logic ════════════════════════════════════════════════════════════


func _can_place_at(entry: ItemEntry, origin: Vector2i) -> bool:
    var cells: Array[Vector2i] = entry.item_data.category_data.get_cells()
    for c: Vector2i in cells:
        var world := origin + c
        if world.x < 0 or world.x >= 8 or world.y < 0 or world.y >= 4:
            return false
        if _cargo_placement.has(world) and _cargo_placement[world] != entry:
            return false
    return true


func _place_item(entry: ItemEntry, origin: Vector2i) -> void:
    # Remove entry's existing cells if being moved within cargo.
    var keys_to_erase: Array[Vector2i] = []
    for pos: Vector2i in _cargo_placement:
        if _cargo_placement[pos] == entry:
            keys_to_erase.append(pos)
    for pos: Vector2i in keys_to_erase:
        _cargo_placement.erase(pos)

    # Write new cells.
    var cells: Array[Vector2i] = entry.item_data.category_data.get_cells()
    for c: Vector2i in cells:
        _cargo_placement[origin + c] = entry

    # Remove from temp if applicable.
    if entry in _temp_items:
        _temp_items.erase(entry)
        _temp_item_nodes[entry].queue_free()
        _temp_item_nodes.erase(entry)

    _active_item = null
    _active_origin = ""
    _phase = Phase.IDLE
    _recalc_totals()
    _refresh_ui()


func _lift_from_cargo(entry: ItemEntry) -> void:
    var keys_to_erase: Array[Vector2i] = []
    for pos: Vector2i in _cargo_placement:
        if _cargo_placement[pos] == entry:
            keys_to_erase.append(pos)
    for pos: Vector2i in keys_to_erase:
        _cargo_placement.erase(pos)

    _temp_items.append(entry)
    var node := _make_temp_item_node(entry)
    _temp_grid.add_child(node)
    _temp_item_nodes[entry] = node

    _active_item = entry
    _active_origin = "cargo"
    _phase = Phase.ITEM_HELD
    _recalc_totals()
    _refresh_ui()

# ══ UI helpers ════════════════════════════════════════════════════════════════


func _recalc_totals() -> void:
    _slots_used = 0
    _weight_used = 0.0
    var seen: Array[ItemEntry] = []
    for pos: Vector2i in _cargo_placement:
        var entry: ItemEntry = _cargo_placement[pos]
        if entry not in seen:
            seen.append(entry)
            _slots_used += entry.item_data.category_data.get_cells().size()
            _weight_used += entry.item_data.category_data.weight


func _refresh_ui() -> void:
    # Hardcoded limits matching _build_cargo_grid(); swap to CarConfig later.
    const MAX_SLOTS := 8 * 4
    const MAX_WEIGHT := 20.0
    _slots_label.text = "Slots: %d / %d" % [_slots_used, MAX_SLOTS]
    _weight_label.text = "Weight: %.1f / %.1f kg" % [_weight_used, MAX_WEIGHT]
    _refresh_cargo_cell_visuals()
    _refresh_temp_visuals()


func _refresh_cargo_cell_visuals() -> void:
    var preview_cells: Array[Vector2i] = []
    var preview_valid := false
    if _phase == Phase.ITEM_HELD and _hover_cell != Vector2i(-1, -1) and _active_item != null:
        preview_valid = _can_place_at(_active_item, _hover_cell)
        for c: Vector2i in _active_item.item_data.category_data.get_cells():
            preview_cells.append(_hover_cell + c)

    for pos: Vector2i in _cargo_cells:
        var cell: Panel = _cargo_cells[pos]
        var style: StyleBoxFlat
        if pos in preview_cells:
            if preview_valid:
                style = _make_stylebox(
                    Color(0.20, 0.45, 0.22, 1.0),
                    Color(0.35, 0.75, 0.40, 1.0))
            else:
                style = _make_stylebox(
                    Color(0.45, 0.18, 0.18, 1.0),
                    Color(0.75, 0.30, 0.30, 1.0))
        elif _cargo_placement.has(pos):
            style = _make_stylebox(
                Color(0.22, 0.30, 0.42, 1.0),
                Color(0.40, 0.55, 0.75, 1.0))
        else:
            style = _make_stylebox(
                Color(0.18, 0.18, 0.20, 1.0),
                Color(0.35, 0.35, 0.38, 1.0))
        cell.add_theme_stylebox_override("panel", style)


func _refresh_temp_visuals() -> void:
    for entry: ItemEntry in _temp_item_nodes:
        var node: Panel = _temp_item_nodes[entry]
        if entry == _active_item:
            node.modulate = Color(1, 1, 1, 0.45)
        else:
            node.modulate = Color(1, 1, 1, 1.0)

# ══ Cell factory ══════════════════════════════════════════════════════════════


func _make_stylebox(bg: Color, border: Color) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_width_left = 1
    s.border_width_right = 1
    s.border_width_top = 1
    s.border_width_bottom = 1
    s.border_color = border
    return s


func _make_cell(pos: Vector2i) -> Panel:
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

    cell.mouse_entered.connect(func() -> void:
        _hover_cell = pos
        _refresh_cargo_cell_visuals()
    )
    cell.mouse_exited.connect(func() -> void:
        if _hover_cell == pos:
            _hover_cell = Vector2i(-1, -1)
        _refresh_cargo_cell_visuals()
    )

    cell.gui_input.connect(
        func(event: InputEvent) -> void:
            if event is InputEventMouseButton \
            and event.button_index == MOUSE_BUTTON_LEFT \
            and event.pressed:
                _on_cargo_cell_pressed(pos)
    )
    return cell


func _make_temp_item_node(entry: ItemEntry) -> Panel:
    # Build a Panel that represents one item in temp storage.
    # Size = bounding box of entry's shape × CELL_SIZE.
    # TODO: implement visual content
    var cells: Array[Vector2i] = entry.item_data.category_data.get_cells()
    var max_col := 0
    var max_row := 0
    for c: Vector2i in cells:
        if c.x > max_col:
            max_col = c.x
        if c.y > max_row:
            max_row = c.y
    var w := (max_col + 1) * CELL_SIZE + max_col * CELL_GAP
    var h := (max_row + 1) * CELL_SIZE + max_row * CELL_GAP

    var node := Panel.new()
    node.custom_minimum_size = Vector2(w, h)
    node.set_meta("item_entry", entry)

    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.22, 0.30, 0.42, 1.0)
    style.border_width_left = 1
    style.border_width_right = 1
    style.border_width_top = 1
    style.border_width_bottom = 1
    style.border_color = Color(0.40, 0.55, 0.75, 1.0)
    node.add_theme_stylebox_override("panel", style)

    node.gui_input.connect(
        func(event: InputEvent) -> void:
            if event is InputEventMouseButton \
            and event.button_index == MOUSE_BUTTON_LEFT \
            and event.pressed:
                _on_temp_item_pressed(entry)
    )
    return node
