# cargo_scene_v2.gd
# Block 05 — Cargo Loading (v2: 2-D grid packing)
# Reads:  RunManager.run_record.won_items, RunManager.run_record.car_config
# Writes: RunManager.run_record.cargo_items, RunManager.run_record.onsite_proceeds
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────

const ONSITE_SELL_PRICE := 50
const CELL_SIZE := 56 # px per grid cell
const CELL_GAP := 3 # px between cells

# Temp grid dimensions (adjust as needed)
const TEMP_GRID_COLS := 10
const TEMP_GRID_ROWS := 4

const ItemRowTooltipScene: PackedScene = preload("uid://3kvnpn7pek5i")

# ── Enums ─────────────────────────────────────────────────────────────────────

enum Phase {
    IDLE, # nothing held; normal state
    ITEM_HELD, # player is holding an item, tracking mouse
}

# ── State ─────────────────────────────────────────────────────────────────────

# All items from this run.
var _won_items: Array[ItemEntry] = []

# Currently held item and where it came from ("temp" | "cargo" | "extra").
var _active_item: ItemEntry = null
var _active_origin: String = ""
var _active_origin_pos: Vector2i = Vector2i(-1, -1) # Original position for cancel

# Extra (trailer) slot state — parallel to _cargo_placement, never intersects it.
var _extra_slot_items: Array[ItemEntry] = [] # size = car_config.extra_slot_count; null = empty
var _active_origin_extra_index: int = -1 # set when _active_origin == "extra"

# Current hover position in cargo grid coords (invalid when not hovering).
var _hover_cell: Vector2i = Vector2i(-1, -1)

# Current hover position in temp grid coords (invalid when not hovering).
var _temp_hover_cell: Vector2i = Vector2i(-1, -1)

var _hover_extra_index: int = -1

var _phase: Phase = Phase.IDLE

# Rotation of the currently held item (0–3 = 0° / 90° / 180° / 270° CW).
# Loaded from _item_rotations on lift; written back to _item_rotations on place.
var _active_rotation: int = 0

# Per-item rotation memory for this session (ItemEntry → int).
# Populated when an item is placed; read when the same item is lifted again.
# Cleared on full reset. Never written outside this scene.
var _item_rotations: Dictionary = {}   # ItemEntry → int

# ── Cargo Grid State ──────────────────────────────────────────────────────────

# Maps cargo grid position → ItemEntry.
# Only occupied cells appear as keys.
var _cargo_placement: Dictionary = { } # Vector2i → ItemEntry

# Runtime cell controls built in _build_cargo_grid().
# Maps grid position → the Panel node representing that cell.
var _cargo_cells: Dictionary = { } # Vector2i → Panel

# ── Temp Grid State (refactored to be grid-based like cargo) ──────────────────

# Maps temp grid position → ItemEntry.
# Only occupied cells appear as keys.
var _temp_placement: Dictionary = { } # Vector2i → ItemEntry

# Runtime cell controls built in _build_temp_grid().
# Maps grid position → the Panel node representing that cell.
var _temp_cells: Dictionary = { } # Vector2i → Panel

# ── Extra Slot Grid State ─────────────────────────────────────────────────

# Runtime cell controls built in _build_extra_slots().
# Maps slot index → the Panel node representing that cell.
var _extra_slot_cells: Dictionary = { } # int → Panel

# ── Stats ─────────────────────────────────────────────────────────────────────

var _slots_used: int = 0
var _weight_used: float = 0.0

# Unique color for each item (assigned once, persists through session)
var _item_colors: Dictionary = { } # ItemEntry → Color

# Tooltip support
var _ctx: ItemViewContext = null
var _tooltip: ItemRowTooltip = null

# Track which item is currently being hovered for tooltip
var _hovered_item: ItemEntry = null

# ── Node references ───────────────────────────────────────────────────────────

@onready var _slots_label: Label = $RootVBox/StatsBar/SlotsLabel
@onready var _weight_label: Label = $RootVBox/StatsBar/WeightLabel
@onready var _error_label: Label = $RootVBox/ErrorLabel
@onready var _cargo_grid: GridContainer = $RootVBox/CargoSection/CargoGrid
@onready var _temp_grid: GridContainer = $RootVBox/TempSection/TempGrid
@onready var _reset_btn: Button = $RootVBox/Footer/ResetButton
@onready var _continue_btn: Button = $RootVBox/Footer/ContinueButton
@onready var _confirm_popup: ConfirmationDialog = $ConfirmPopup
@onready var _extra_slot_section: VBoxContainer = $RootVBox/ExtraSlotSection
@onready var _extra_slot_container: HBoxContainer = $RootVBox/ExtraSlotSection/ExtraSlotContainer

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _ctx = ItemViewContext.for_cargo()
    _tooltip = ItemRowTooltipScene.instantiate()
    add_child(_tooltip)

    _reset_btn.pressed.connect(_on_reset_pressed)
    _continue_btn.pressed.connect(_on_continue_pressed)
    _confirm_popup.confirmed.connect(_on_confirm_popup_confirmed)

    _won_items = RunManager.run_record.won_items

    # Initialise extra slot state
    _extra_slot_items.resize(RunManager.run_record.car_config.extra_slot_count)
    _extra_slot_items.fill(null)

    # Assign unique colors to each item
    _assign_item_colors()

    _build_cargo_grid()
    _build_temp_grid()
    _build_extra_slots()
    _populate_temp_storage()
    _recalc_totals()
    _refresh_ui()


func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
            if _phase == Phase.ITEM_HELD:
                # Cancel placement - return item to temp storage
                _cancel_placement()
                accept_event()


func _unhandled_input(event: InputEvent) -> void:
    if _phase != Phase.ITEM_HELD or _active_item == null:
        return
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_Q:
                _active_rotation = (_active_rotation + 3) % 4  # one step CCW
                _refresh_ui()
                get_viewport().set_input_as_handled()
            KEY_E:
                _active_rotation = (_active_rotation + 1) % 4  # one step CW
                _refresh_ui()
                get_viewport().set_input_as_handled()

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_reset_pressed() -> void:
    # Move all cargo items back to temp
    var unique_entries: Array[ItemEntry] = []
    for pos: Vector2i in _cargo_placement:
        var entry: ItemEntry = _cargo_placement[pos]
        if entry not in unique_entries:
            unique_entries.append(entry)
    _cargo_placement.clear()

    # Clear extra slots
    _extra_slot_items.fill(null)

    _active_item = null
    _active_origin = ""
    _active_origin_pos = Vector2i(-1, -1)
    _active_origin_extra_index = -1
    _phase = Phase.IDLE

    # Re-populate temp with all won items
    _temp_placement.clear()
    _item_rotations.clear()
    _populate_temp_storage()
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

    for entry: ItemEntry in _extra_slot_items:
        if entry != null:
            cargo.append(entry)

    RunManager.run_record.cargo_items = cargo

    # Count items left in temp storage
    var temp_items: Array[ItemEntry] = []
    for pos: Vector2i in _temp_placement:
        var entry: ItemEntry = _temp_placement[pos]
        if entry not in temp_items:
            temp_items.append(entry)
    RunManager.run_record.onsite_proceeds = temp_items.size() * ONSITE_SELL_PRICE
    GameManager.go_to_run_review()


func _on_cargo_cell_pressed(cell_pos: Vector2i) -> void:
    _hide_tooltip()
    if _phase == Phase.IDLE:
        if _cargo_placement.has(cell_pos):
            _lift_from_cargo(_cargo_placement[cell_pos])
    elif _phase == Phase.ITEM_HELD:
        if _can_place_at_cargo(_active_item, cell_pos):
            _place_item_in_cargo(_active_item, cell_pos)


func _on_temp_cell_pressed(cell_pos: Vector2i) -> void:
    _hide_tooltip()
    if _phase == Phase.IDLE:
        if _temp_placement.has(cell_pos):
            _lift_from_temp(_temp_placement[cell_pos])
    elif _phase == Phase.ITEM_HELD:
        if _can_place_at_temp(_active_item, cell_pos):
            _place_item_in_temp(_active_item, cell_pos)


func _on_extra_slot_pressed(slot_index: int) -> void:
    _hide_tooltip()
    if _phase == Phase.IDLE:
        if _extra_slot_items[slot_index] != null:
            _lift_from_extra(slot_index)
    elif _phase == Phase.ITEM_HELD:
        _place_item_in_extra(slot_index)

# ══ Color assignment ═══════════════════════════════════════════════════════════


func _assign_item_colors() -> void:
    # Generate visually distinct colors for each item using golden ratio hue spacing
    var golden_ratio := 0.618033988749895
    var hue := randf() # Random starting hue for variety between sessions

    for entry: ItemEntry in _won_items:
        hue = fmod(hue + golden_ratio, 1.0)
        # Use moderate saturation and value for pleasant, distinguishable colors
        var color := Color.from_hsv(hue, 0.55, 0.50)
        _item_colors[entry] = color


func _get_item_color(entry: ItemEntry) -> Color:
    if _item_colors.has(entry):
        return _item_colors[entry]
    return Color(0.22, 0.30, 0.42, 1.0) # Fallback


func _get_item_border_color(entry: ItemEntry) -> Color:
    if _item_colors.has(entry):
        var base: Color = _item_colors[entry]
        # Lighter border
        return base.lightened(0.35)
    return Color(0.40, 0.55, 0.75, 1.0) # Fallback

# ══ Grid construction ══════════════════════════════════════════════════════════


func _build_cargo_grid() -> void:
    var cols := RunManager.run_record.car_config.grid_columns
    var rows := RunManager.run_record.car_config.grid_rows

    _cargo_grid.columns = cols

    for row in rows:
        for col in cols:
            var pos := Vector2i(col, row)
            var cell := _make_cargo_cell(pos)
            _cargo_grid.add_child(cell)
            _cargo_cells[pos] = cell


func _build_temp_grid() -> void:
    _temp_grid.columns = TEMP_GRID_COLS

    for row in TEMP_GRID_ROWS:
        for col in TEMP_GRID_COLS:
            var pos := Vector2i(col, row)
            var cell := _make_temp_cell(pos)
            _temp_grid.add_child(cell)
            _temp_cells[pos] = cell


func _build_extra_slots() -> void:
    var count := RunManager.run_record.car_config.extra_slot_count
    _extra_slot_section.visible = count > 0
    for i in count:
        var cell := _make_extra_slot_cell(i)
        _extra_slot_container.add_child(cell)
        _extra_slot_cells[i] = cell


func _populate_temp_storage() -> void:
    # Clear existing placement
    _temp_placement.clear()

    # Place each won item in temp grid using first-fit algorithm
    for entry: ItemEntry in _won_items:
        var placed := false
        for row in TEMP_GRID_ROWS:
            if placed:
                break
            for col in TEMP_GRID_COLS:
                var pos := Vector2i(col, row)
                if _can_place_at_temp(entry, pos):
                    _place_item_in_temp_silent(entry, pos)
                    placed = true
                    break
        if not placed:
            push_warning("Could not place item in temp grid: ", entry)

# ══ Placement logic ════════════════════════════════════════════════════════════


func _get_active_cells(entry: ItemEntry) -> Array[Vector2i]:
    var base: Array[Vector2i] = entry.item_data.category_data.get_cells()
    return CargoShapes.rotate_cells(base, _active_rotation)


func _can_place_at_cargo(entry: ItemEntry, origin: Vector2i) -> bool:
    var cols := RunManager.run_record.car_config.grid_columns
    var rows := RunManager.run_record.car_config.grid_rows
    var cells: Array[Vector2i] = _get_active_cells(entry)

    # Check grid bounds and collision
    for c: Vector2i in cells:
        var world := origin + c
        if world.x < 0 or world.x >= cols or world.y < 0 or world.y >= rows:
            return false
        if _cargo_placement.has(world) and _cargo_placement[world] != entry:
            return false

    # Check weight limit
    if _would_exceed_weight(entry):
        return false

    return true


func _would_exceed_weight(entry: ItemEntry) -> bool:
    # Check if placing this entry would exceed max weight
    # If item is already in cargo, don't double count
    var max_weight: float = RunManager.run_record.car_config.max_weight
    var entry_weight: float = entry.item_data.category_data.weight

    # Check if entry is already in cargo
    var already_in_cargo := false
    for pos: Vector2i in _cargo_placement:
        if _cargo_placement[pos] == entry:
            already_in_cargo = true
            break

    if already_in_cargo:
        # Item already counted in _weight_used, so no additional weight
        return false
    else:
        return (_weight_used + entry_weight) > max_weight


func _get_pending_weight(entry: ItemEntry) -> float:
    # Get the weight that would be added if this entry is placed in cargo
    # Returns 0 if already in cargo
    for pos: Vector2i in _cargo_placement:
        if _cargo_placement[pos] == entry:
            return 0.0
    return entry.item_data.category_data.weight


func _get_pending_slots(entry: ItemEntry) -> int:
    # Get the slots that would be added if this entry is placed in cargo
    # Returns 0 if already in cargo
    for pos: Vector2i in _cargo_placement:
        if _cargo_placement[pos] == entry:
            return 0
    return _get_active_cells(entry).size()


func _can_place_at_temp(entry: ItemEntry, origin: Vector2i) -> bool:
    var cells: Array[Vector2i] = _get_active_cells(entry)
    for c: Vector2i in cells:
        var world := origin + c
        if world.x < 0 or world.x >= TEMP_GRID_COLS or world.y < 0 or world.y >= TEMP_GRID_ROWS:
            return false
        if _temp_placement.has(world) and _temp_placement[world] != entry:
            return false
    return true


func _place_item_in_cargo(entry: ItemEntry, origin: Vector2i) -> void:
    # Remove entry's existing cells from cargo if being moved within cargo.
    _erase_from_cargo(entry)

    # Remove from temp or extra if applicable.
    _erase_from_temp(entry)
    _erase_from_extra(entry)

    # Write new cells.
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


func _place_item_in_temp(entry: ItemEntry, origin: Vector2i) -> void:
    # Remove entry's existing cells from temp if being moved within temp.
    _erase_from_temp(entry)

    # Remove from cargo or extra if applicable.
    _erase_from_cargo(entry)
    _erase_from_extra(entry)

    # Write new cells.
    var cells: Array[Vector2i] = _get_active_cells(entry)
    for c: Vector2i in cells:
        _temp_placement[origin + c] = entry

    _item_rotations[_active_item] = _active_rotation
    _active_item = null
    _active_origin = ""
    _active_origin_pos = Vector2i(-1, -1)
    _phase = Phase.IDLE
    _recalc_totals()
    _refresh_ui()


func _place_item_in_temp_silent(entry: ItemEntry, origin: Vector2i) -> void:
    # Place without changing phase or refreshing UI (used during initial population)
    var cells: Array[Vector2i] = _get_active_cells(entry)
    for c: Vector2i in cells:
        _temp_placement[origin + c] = entry


func _erase_from_cargo(entry: ItemEntry) -> void:
    var keys_to_erase: Array[Vector2i] = []
    for pos: Vector2i in _cargo_placement:
        if _cargo_placement[pos] == entry:
            keys_to_erase.append(pos)
    for pos: Vector2i in keys_to_erase:
        _cargo_placement.erase(pos)


func _erase_from_temp(entry: ItemEntry) -> void:
    var keys_to_erase: Array[Vector2i] = []
    for pos: Vector2i in _temp_placement:
        if _temp_placement[pos] == entry:
            keys_to_erase.append(pos)
    for pos: Vector2i in keys_to_erase:
        _temp_placement.erase(pos)


func _erase_from_extra(entry: ItemEntry) -> void:
    for i in _extra_slot_items.size():
        if _extra_slot_items[i] == entry:
            _extra_slot_items[i] = null


func _lift_from_cargo(entry: ItemEntry) -> void:
    # Find the origin cell (top-left of the item's bounding box)
    var origin_pos := Vector2i(999, 999)
    for pos: Vector2i in _cargo_placement:
        if _cargo_placement[pos] == entry:
            if pos.y < origin_pos.y or (pos.y == origin_pos.y and pos.x < origin_pos.x):
                origin_pos = pos

    # Don't erase from cargo yet - keep it there until placed elsewhere or cancelled
    _active_item = entry
    _active_rotation = _item_rotations.get(entry, 0)
    _active_origin = "cargo"
    _active_origin_pos = origin_pos
    _phase = Phase.ITEM_HELD
    _refresh_ui()


func _lift_from_temp(entry: ItemEntry) -> void:
    # Find the origin cell (top-left of the item's bounding box)
    var origin_pos := Vector2i(999, 999)
    for pos: Vector2i in _temp_placement:
        if _temp_placement[pos] == entry:
            if pos.y < origin_pos.y or (pos.y == origin_pos.y and pos.x < origin_pos.x):
                origin_pos = pos

    # Item stays in temp visually but we're now holding it
    _active_item = entry
    _active_rotation = _item_rotations.get(entry, 0)
    _active_origin = "temp"
    _active_origin_pos = origin_pos
    _phase = Phase.ITEM_HELD
    _refresh_ui()


func _cancel_placement() -> void:
    if _phase != Phase.ITEM_HELD or _active_item == null:
        return

    if _active_origin == "extra":
        _extra_slot_items[_active_origin_extra_index] = _active_item
        _active_origin_extra_index = -1

    # Item was never removed from its original grid (cargo/temp), so just deselect
    _active_item = null
    _active_rotation = 0
    _active_origin = ""
    _active_origin_pos = Vector2i(-1, -1)
    _phase = Phase.IDLE

    _refresh_ui()


func _lift_from_extra(slot_index: int) -> void:
    _active_item = _extra_slot_items[slot_index]
    _active_rotation = _item_rotations.get(_active_item, 0)
    _active_origin = "extra"
    _active_origin_extra_index = slot_index
    _extra_slot_items[slot_index] = null
    _phase = Phase.ITEM_HELD
    _refresh_ui()


func _place_item_in_extra(slot_index: int) -> void:
    if _extra_slot_items[slot_index] != null:
        return # occupied — reject

    # Remove from previous grid if applicable.
    if _active_origin == "cargo":
        _erase_from_cargo(_active_item)
    elif _active_origin == "temp":
        _erase_from_temp(_active_item)

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
    var seen: Array[ItemEntry] = []
    for pos: Vector2i in _cargo_placement:
        var entry: ItemEntry = _cargo_placement[pos]
        if entry not in seen:
            seen.append(entry)
            _slots_used += entry.item_data.category_data.get_cells().size()
            _weight_used += entry.item_data.category_data.weight


func _refresh_ui() -> void:
    var cols := RunManager.run_record.car_config.grid_columns
    var rows := RunManager.run_record.car_config.grid_rows
    var max_slots := cols * rows
    var max_weight: float = RunManager.run_record.car_config.max_weight

    # Check if we're holding an item and calculate pending changes
    var pending_slots := 0
    var pending_weight := 0.0
    var weight_exceeded := false

    if _phase == Phase.ITEM_HELD and _active_item != null:
        pending_slots = _get_pending_slots(_active_item)
        pending_weight = _get_pending_weight(_active_item)
        weight_exceeded = (_weight_used + pending_weight) > max_weight

    # Format slots label
    if pending_slots > 0:
        _slots_label.text = "Slots: %d + %d / %d" % [_slots_used, pending_slots, max_slots]
    else:
        _slots_label.text = "Slots: %d / %d" % [_slots_used, max_slots]

    # Format weight label
    if pending_weight > 0.0:
        _weight_label.text = "Weight: %.1f + %.1f / %.1f kg" % [_weight_used, pending_weight, max_weight]
        if weight_exceeded:
            _weight_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3, 1.0))
        else:
            _weight_label.add_theme_color_override("font_color", Color(0.35, 0.75, 0.40, 1.0))
    else:
        _weight_label.text = "Weight: %.1f / %.1f kg" % [_weight_used, max_weight]
        _weight_label.remove_theme_color_override("font_color")

    # Show/hide error message
    if weight_exceeded:
        _error_label.text = "Weight limit exceeded! Cannot place item."
    else:
        _error_label.text = ""

    _refresh_cargo_cell_visuals()
    _refresh_temp_cell_visuals()
    _refresh_extra_slot_visuals()


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
                # Highlight the held item (slightly brighter)
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


func _refresh_temp_cell_visuals() -> void:
    var preview_cells: Array[Vector2i] = []
    var preview_valid := false
    if _phase == Phase.ITEM_HELD and _temp_hover_cell != Vector2i(-1, -1) and _active_item != null:
        preview_valid = _can_place_at_temp(_active_item, _temp_hover_cell)
        for c: Vector2i in _get_active_cells(_active_item):
            preview_cells.append(_temp_hover_cell + c)

    for pos: Vector2i in _temp_cells:
        var cell: Panel = _temp_cells[pos]
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
        elif _temp_placement.has(pos):
            var entry: ItemEntry = _temp_placement[pos]
            if _phase == Phase.ITEM_HELD and _active_item == entry:
                # Highlight the held item (slightly brighter)
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
                Color(0.14, 0.14, 0.16, 1.0),
                Color(0.28, 0.28, 0.30, 1.0),
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

        # Update the icon label
        var icon_label: Label = cell.get_node("IconLabel")
        if entry != null:
            var words = entry.active_layer().display_name.split(" ", false)
            icon_label.text = (words[0].left(1) if words.size() > 0 else "") + (words[1].left(1) if words.size() > 1 else "")
            icon_label.text = icon_label.text.to_upper()
        else:
            icon_label.text = ""


func _build_summary_text() -> String:
    var cargo_count := 0
    var cargo_seen: Array[ItemEntry] = []
    for pos: Vector2i in _cargo_placement:
        var entry: ItemEntry = _cargo_placement[pos]
        if entry not in cargo_seen:
            cargo_seen.append(entry)
            cargo_count += 1
    for entry: ItemEntry in _extra_slot_items:
        if entry != null:
            cargo_count += 1

    var temp_count := 0
    var temp_seen: Array[ItemEntry] = []
    for pos: Vector2i in _temp_placement:
        var entry: ItemEntry = _temp_placement[pos]
        if entry not in temp_seen:
            temp_seen.append(entry)
            temp_count += 1

    var left_proceeds := temp_count * ONSITE_SELL_PRICE

    return (
        "Loaded items: %d\n" % cargo_count +
        "Left behind: %d  (sold on-site for $%d)\n\n" % [temp_count, left_proceeds] +
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
            # Show tooltip for item in this cargo cell if not dragging
            if _phase != Phase.ITEM_HELD and _cargo_placement.has(pos):
                _show_tooltip_for_item(_cargo_placement[pos], cell.get_global_rect())
    )
    cell.mouse_exited.connect(
        func() -> void:
            if _hover_cell == pos:
                _hover_cell = Vector2i(-1, -1)
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


func _make_temp_cell(pos: Vector2i) -> Panel:
    var cell := Panel.new()
    cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
    cell.set_meta("cell_pos", pos)

    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.14, 0.14, 0.16, 1.0)
    style.border_width_left = 1
    style.border_width_right = 1
    style.border_width_top = 1
    style.border_width_bottom = 1
    style.border_color = Color(0.28, 0.28, 0.30, 1.0)
    cell.add_theme_stylebox_override("panel", style)

    cell.mouse_entered.connect(
        func() -> void:
            _temp_hover_cell = pos
            _refresh_temp_cell_visuals()
            # Show tooltip for item in this temp cell if not dragging
            if _phase != Phase.ITEM_HELD and _temp_placement.has(pos):
                _show_tooltip_for_item(_temp_placement[pos], cell.get_global_rect())
    )
    cell.mouse_exited.connect(
        func() -> void:
            if _temp_hover_cell == pos:
                _temp_hover_cell = Vector2i(-1, -1)
            _refresh_temp_cell_visuals()
            _hide_tooltip()
    )

    cell.gui_input.connect(
        func(event: InputEvent) -> void:
            if event is InputEventMouseButton and event.pressed:
                if event.button_index == MOUSE_BUTTON_LEFT:
                    _on_temp_cell_pressed(pos)
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

    # 1×1 icon label centered in the cell
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
                _show_tooltip_for_item(_extra_slot_items[slot_index], cell.get_global_rect())
    )
    cell.mouse_exited.connect(
        func() -> void:
            if _hover_extra_index == slot_index:
                _hover_extra_index = -1
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
        # Don't show tooltips while dragging
        return
    _hovered_item = entry
    _tooltip.show_for(entry, _ctx, anchor)


func _hide_tooltip() -> void:
    _hovered_item = null
    _tooltip.hide_tooltip()
