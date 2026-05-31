# packing_grid.gd
# Shared grid-packing component. Manages a grid of cells with item placement,
# rotation, and occupancy tracking. Extends GridContainer for direct insertion
# into block scenes. Used by run-phase cargo and hub-phase customer scenes.
class_name PackingGrid
extends GridContainer

# ── Signals ────────────────────────────────────────────────────────────────────

## Emitted when a placed item is left-clicked while in IDLE phase.
signal item_clicked(item)

## Emitted when a grid cell is left-clicked while in ITEM_HELD phase.
signal cell_clicked(cell_pos: Vector2i)

## Emitted after any place / erase / reset that changes placement state.
signal placement_changed

## Emitted when a placement is cancelled while holding (right-click or cancel).
signal placement_cancelled(item)

## Emitted when the mouse enters a grid cell.
signal hover_started(cell_pos: Vector2i)

## Emitted when the mouse exits the grid entirely.
signal hover_ended

# ── Constants ──────────────────────────────────────────────────────────────────

const CELL_SIZE := 56
const DEFAULT_BG := Color(0.18, 0.18, 0.20, 1.0)
const DEFAULT_BORDER := Color(0.35, 0.35, 0.38, 1.0)
const PREVIEW_VALID_BG := Color(0.20, 0.45, 0.22, 1.0)
const PREVIEW_VALID_BORDER := Color(0.35, 0.75, 0.40, 1.0)
const PREVIEW_INVALID_BG := Color(0.45, 0.18, 0.18, 1.0)
const PREVIEW_INVALID_BORDER := Color(0.75, 0.30, 0.30, 1.0)

# ── Enums ──────────────────────────────────────────────────────────────────────

enum Phase {
    IDLE,
    ITEM_HELD,
}

# ── Callbacks ──────────────────────────────────────────────────────────────────

## func(item) -> Array[Vector2i] — returns normalised shape cells for an item.
var get_shape_cells: Callable

## func(item) -> Color — returns the base colour for a placed item.
var get_item_color: Callable

## func(item) -> Color — returns the border colour for a placed item.
var get_item_border_color: Callable

## func(item, origin: Vector2i) -> bool — extra validation beyond
## bounds+occupancy (e.g. weight check). Only called when bounds+occupancy pass.
var additional_validator: Callable

# ── State (public read) ────────────────────────────────────────────────────────

var placement: Dictionary = {}  # Vector2i → Variant (the item)
var item_rotations: Dictionary = {}  # Variant → int (rotation 0-3)

var phase: Phase = Phase.IDLE
var active_item = null
var active_rotation: int = 0
var hover_cell: Vector2i = Vector2i(-1, -1)

# ── Internal ───────────────────────────────────────────────────────────────────

var _cell_nodes: Dictionary = {}  # Vector2i → Panel
var _grid_cols: int = 0
var _grid_rows: int = 0
var _hover_item = null         # placed item under cursor in IDLE phase
var _lift_offset: Vector2i = Vector2i(0, 0)  # offset from item origin to clicked cell

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _unhandled_input(event: InputEvent) -> void:
    if phase != Phase.ITEM_HELD or active_item == null:
        return
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_Q:
                active_rotation = (active_rotation + 3) % 4
                refresh_visuals()
                get_viewport().set_input_as_handled()
            KEY_E:
                active_rotation = (active_rotation + 1) % 4
                refresh_visuals()
                get_viewport().set_input_as_handled()

# ══ Public API ════════════════════════════════════════════════════════════════


## Initialises the grid with the given dimensions. Safe to call multiple times;
## existing cells are freed and state is reset before rebuilding. Callbacks
## should be set before calling this so cell construction can use them.
func setup(cols: int, rows: int) -> void:
    for cell: Panel in _cell_nodes.values():
        cell.queue_free()
    _cell_nodes.clear()
    placement.clear()
    item_rotations.clear()
    active_item = null
    active_rotation = 0
    phase = Phase.IDLE
    hover_cell = Vector2i(-1, -1)

    _hover_item = null
    _lift_offset = Vector2i(0, 0)

    _grid_cols = cols
    _grid_rows = rows
    columns = cols
    _build_grid()


## Returns the rotated shape cells for the given item using active_rotation.
func get_active_cells(item) -> Array[Vector2i]:
    var base: Array[Vector2i]
    if get_shape_cells.is_valid():
        base = get_shape_cells.call(item)
    else:
        base = []
    return CargoShapes.rotate_cells(base, active_rotation)


## Returns the shape cells for the given item at its stored rotation.
func get_rotated_cells(item) -> Array[Vector2i]:
    var base: Array[Vector2i]
    if get_shape_cells.is_valid():
        base = get_shape_cells.call(item)
    else:
        base = []
    var rot: int = item_rotations.get(item, 0)
    return CargoShapes.rotate_cells(base, rot)


## True if item can be placed at origin (bounds + occupancy + external check).
func can_place(item, origin: Vector2i) -> bool:
    var cells: Array[Vector2i] = get_active_cells(item)

    for c: Vector2i in cells:
        var world := origin + c
        if world.x < 0 or world.x >= _grid_cols or world.y < 0 or world.y >= _grid_rows:
            return false
        if placement.has(world) and placement[world] != item:
            return false

    if additional_validator.is_valid() and not additional_validator.call(item, origin):
        return false

    return true


## Places item at origin. Erases any previous placement first.
func place(item, origin: Vector2i) -> void:
    erase(item)

    var cells: Array[Vector2i] = get_active_cells(item)
    for c: Vector2i in cells:
        placement[origin + c] = item

    item_rotations[item] = active_rotation
    active_item = null
    active_rotation = 0
    _lift_offset = Vector2i(0, 0)
    phase = Phase.IDLE

    placement_changed.emit()
    refresh_visuals()


## Removes item from the placement dictionary.
func erase(item) -> void:
    var keys_to_erase: Array[Vector2i] = []
    for pos: Vector2i in placement:
        if placement[pos] == item:
            keys_to_erase.append(pos)
    for pos: Vector2i in keys_to_erase:
        placement.erase(pos)


## Starts holding a placed item. Sets phase to ITEM_HELD.
func lift(item) -> void:
    active_item = item
    active_rotation = item_rotations.get(item, 0)
    phase = Phase.ITEM_HELD
    refresh_visuals()


## Sets the held item without erasing any placement (used for list/extra lifts).
## Always clears the lift offset — items picked from a list have no grid origin.
func set_held_item(item, rotation: int) -> void:
    active_item = item
    active_rotation = rotation
    _lift_offset = Vector2i(0, 0)
    phase = Phase.ITEM_HELD
    refresh_visuals()


## Cancels current placement and returns to IDLE.
func cancel_placement() -> void:
    if phase != Phase.ITEM_HELD or active_item == null:
        return
    var item = active_item
    active_item = null
    active_rotation = 0
    _lift_offset = Vector2i(0, 0)
    phase = Phase.IDLE
    placement_cancelled.emit(item)
    placement_changed.emit()
    refresh_visuals()


## Clears all placement and rotation state.
func reset() -> void:
    placement.clear()
    item_rotations.clear()
    active_item = null
    active_rotation = 0
    phase = Phase.IDLE
    placement_changed.emit()
    refresh_visuals()


## Returns the top-left origin of a placed item, or Vector2i(-1, -1).
func get_item_origin(item) -> Vector2i:
    var origin := Vector2i(999, 999)
    for pos: Vector2i in placement:
        if placement[pos] == item:
            if pos.y < origin.y or (pos.y == origin.y and pos.x < origin.x):
                origin = pos
    if origin == Vector2i(999, 999):
        return Vector2i(-1, -1)
    return origin


## Returns true if the item occupies any cells in the grid.
func is_item_placed(item) -> bool:
    for pos: Vector2i in placement:
        if placement[pos] == item:
            return true
    return false


## Redraws all cell styleboxes based on current state.
func refresh_visuals() -> void:
    # Preview: where the held item would land, offset by where the user grabbed it.
    var preview_origin := hover_cell - _lift_offset
    var preview_cells: Array[Vector2i] = []
    var preview_valid := false
    if phase == Phase.ITEM_HELD and hover_cell != Vector2i(-1, -1) and active_item != null:
        preview_valid = can_place(active_item, preview_origin)
        for c: Vector2i in get_active_cells(active_item):
            preview_cells.append(preview_origin + c)

    # Hover highlight: all cells of the item under the cursor (IDLE only).
    var hover_item_cells: Array[Vector2i] = []
    if phase == Phase.IDLE and _hover_item != null:
        for pos: Vector2i in placement:
            if placement[pos] == _hover_item:
                hover_item_cells.append(pos)

    for pos: Vector2i in _cell_nodes:
        var cell: Panel = _cell_nodes[pos]
        var style: StyleBoxFlat

        if pos in preview_cells:
            if preview_valid:
                style = _make_stylebox(PREVIEW_VALID_BG, PREVIEW_VALID_BORDER)
            else:
                style = _make_stylebox(PREVIEW_INVALID_BG, PREVIEW_INVALID_BORDER)
        elif placement.has(pos):
            var entry = placement[pos]
            var base_color := _resolve_color(entry)
            var base_border := _resolve_border_color(entry)
            if phase == Phase.ITEM_HELD and active_item == entry:
                # Ghost of the held item — dimmed with a cyan border to signal "moving".
                style = _make_stylebox(
                    base_color.lightened(0.10),
                    Color(0.35, 0.78, 0.90, 1.0),
                )
            elif pos in hover_item_cells:
                # Hovered item in IDLE — noticeably brighter than the held ghost.
                style = _make_stylebox(
                    base_color.lightened(0.42),
                    base_border.lightened(0.35),
                )
            else:
                style = _make_stylebox(base_color, base_border)
        else:
            style = _make_stylebox(DEFAULT_BG, DEFAULT_BORDER)

        cell.add_theme_stylebox_override("panel", style)

# ══ Internal ═════════════════════════════════════════════════════════════════


func _build_grid() -> void:
    for row in _grid_rows:
        for col in _grid_cols:
            var pos := Vector2i(col, row)
            var cell := _make_cell(pos)
            add_child(cell)
            _cell_nodes[pos] = cell


func _make_cell(pos: Vector2i) -> Panel:
    var cell := Panel.new()
    cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
    cell.set_meta("cell_pos", pos)

    var style := StyleBoxFlat.new()
    style.bg_color = DEFAULT_BG
    style.border_width_left = 1
    style.border_width_right = 1
    style.border_width_top = 1
    style.border_width_bottom = 1
    style.border_color = DEFAULT_BORDER
    cell.add_theme_stylebox_override("panel", style)

    cell.mouse_entered.connect(_on_cell_mouse_entered.bind(pos))
    cell.mouse_exited.connect(_on_cell_mouse_exited.bind(pos))
    cell.gui_input.connect(_on_cell_gui_input.bind(pos))

    return cell


func _resolve_color(item) -> Color:
    if get_item_color.is_valid():
        return get_item_color.call(item)
    return Color(0.22, 0.30, 0.42, 1.0)


func _resolve_border_color(item) -> Color:
    if get_item_border_color.is_valid():
        return get_item_border_color.call(item)
    return Color(0.40, 0.55, 0.75, 1.0)


func _make_stylebox(bg: Color, border: Color) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_width_left = 1
    s.border_width_right = 1
    s.border_width_top = 1
    s.border_width_bottom = 1
    s.border_color = border
    return s


func _on_cell_mouse_entered(pos: Vector2i) -> void:
    hover_cell = pos
    _hover_item = placement.get(pos) if placement.has(pos) else null
    refresh_visuals()
    hover_started.emit(pos)


func _on_cell_mouse_exited(pos: Vector2i) -> void:
    if hover_cell == pos:
        hover_cell = Vector2i(-1, -1)
        _hover_item = null
    refresh_visuals()
    hover_ended.emit()


func _on_cell_gui_input(event: InputEvent, pos: Vector2i) -> void:
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if phase == Phase.IDLE:
                if placement.has(pos):
                    # Record where in the item the user clicked so the preview
                    # stays anchored under the cursor instead of teleporting.
                    _lift_offset = pos - get_item_origin(placement[pos])
                    item_clicked.emit(placement[pos])
            elif phase == Phase.ITEM_HELD:
                # Emit the adjusted origin so callers place at the correct position.
                cell_clicked.emit(pos - _lift_offset)
        elif event.button_index == MOUSE_BUTTON_RIGHT:
            if phase == Phase.ITEM_HELD:
                cancel_placement()
            elif phase == Phase.IDLE and placement.has(pos):
                var item = placement[pos]
                erase(item)
                placement_changed.emit()
