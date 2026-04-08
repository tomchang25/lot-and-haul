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
    # Return all placed items back to temp storage; clear cargo.
    # TODO: implement
    pass


func _on_continue_pressed() -> void:
    # Commit cargo_placement → run_record.cargo_items.
    # Sell every item still in _temp_items at ONSITE_SELL_PRICE.
    # Advance to run review.
    # TODO: implement
    pass


func _on_cargo_cell_pressed(cell_pos: Vector2i) -> void:
    # Called when a cargo grid cell is clicked.
    # IDLE   + cell occupied → lift item back to temp (_lift_from_cargo)
    # IDLE   + cell empty    → nothing
    # ITEM_HELD + can place  → place item (_place_item)
    # ITEM_HELD + cannot     → cancel hold, return to origin
    # TODO: implement
    pass


func _on_temp_item_pressed(entry: ItemEntry) -> void:
    # Pick up an item from temp storage; switch to ITEM_HELD.
    # TODO: implement
    pass

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
    # Lay out all items in _temp_items as Panel nodes inside _temp_grid.
    # _temp_grid is hardcoded to 16 columns × 4 rows.
    # Each panel displays the item's shape footprint and name.
    # TODO: implement — call _make_temp_item_node(entry) per item
    for child in _temp_grid.get_children():
        child.queue_free()
    _temp_item_nodes.clear()

    for entry: ItemEntry in _temp_items:
        var node := _make_temp_item_node(entry)
        _temp_grid.add_child(node)
        _temp_item_nodes[entry] = node

# ══ Placement logic ════════════════════════════════════════════════════════════


func _can_place_at(entry: ItemEntry, origin: Vector2i) -> bool:
    # Returns true if entry's shape, offset to origin, fits within the cargo
    # grid and does not collide with any already-placed item (excluding entry
    # itself if it is being moved from cargo).
    # TODO: implement
    return false


func _place_item(entry: ItemEntry, origin: Vector2i) -> void:
    # Write entry into _cargo_placement at all cells covered by its shape.
    # Remove entry from _temp_items / _temp_item_nodes if coming from temp.
    # Update cell visuals.
    # TODO: implement
    pass


func _lift_from_cargo(entry: ItemEntry) -> void:
    # Remove entry from _cargo_placement.
    # Add back to _temp_items and rebuild its temp node.
    # Switch phase to ITEM_HELD with origin = "cargo".
    # TODO: implement
    pass

# ══ UI helpers ════════════════════════════════════════════════════════════════


func _recalc_totals() -> void:
    _slots_used = 0
    _weight_used = 0.0
    for pos: Vector2i in _cargo_placement:
        var entry: ItemEntry = _cargo_placement[pos]
        # Count each entry only once — use its anchor cell (top-left of shape).
        # TODO: deduplicate properly once placement is implemented
        pass


func _refresh_ui() -> void:
    # Hardcoded limits matching _build_cargo_grid(); swap to CarConfig later.
    const MAX_SLOTS := 8 * 4
    const MAX_WEIGHT := 20.0
    _slots_label.text = "Slots: %d / %d" % [_slots_used, MAX_SLOTS]
    _weight_label.text = "Weight: %.1f / %.1f kg" % [_weight_used, MAX_WEIGHT]
    _refresh_cargo_cell_visuals()
    _refresh_temp_visuals()


func _refresh_cargo_cell_visuals() -> void:
    # Update each cell Panel to show occupied / empty / preview state.
    # TODO: implement
    pass


func _refresh_temp_visuals() -> void:
    # Dim / hide items in temp that cannot currently be placed anywhere.
    # TODO: implement
    pass

# ══ Cell factory ══════════════════════════════════════════════════════════════


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
