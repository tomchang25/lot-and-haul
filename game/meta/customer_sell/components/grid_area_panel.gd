# grid_area_panel.gd
# Wraps the PackingGrid with a shape-preview overlay that extends beyond
# the grid's cell bounds. When the player holds an item, the ghost preview
# remains visible when the cursor moves outside the grid but stays inside
# this panel's area (i.e. any region of the car panel above BottomActionRow).
# Reads:  PackingGrid.active_item, phase, lift_offset, get_active_cells(), can_place()
# Writes: nothing
class_name GridAreaPanel
extends Control

# ══ Inner classes ═════════════════════════════════════════════════════════════

## Preview overlay drawn on top of the PackingGrid cells.
## Renders the held item's shape ghost at the cursor position using
## linear (pixel-based) movement outside the grid bounds.
class _ShapePreviewOverlay extends Control:
    var _panel: GridAreaPanel = null


    func _init(panel: GridAreaPanel) -> void:
        _panel = panel


    func _draw() -> void:
        var g := _panel.get_grid()
        if g.phase != PackingGrid.Phase.ITEM_HELD:
            return
        if g.active_item == null:
            return

        var panel_rect := Rect2(Vector2.ZERO, _panel.size)
        var mouse_pos := _panel.get_local_mouse_position()
        if not panel_rect.has_point(mouse_pos):
            return

        var cell_step := g.get_cell_step()
        var grid_size := g.get_grid_size()

        # Suppress the overlay when the mouse is inside the grid's cell rectangle
        # (including gaps between cells) — the grid itself draws the preview there.
        var grid_rect := Rect2(
            g.position,
            Vector2(
                max(0, grid_size.x - 1) * cell_step.x + PackingGrid.CELL_SIZE,
                max(0, grid_size.y - 1) * cell_step.y + PackingGrid.CELL_SIZE,
            ),
        )
        if grid_rect.has_point(mouse_pos):
            return

        var lift_off := Vector2(g.get_lift_offset())

        # Linear draw: shape follows the mouse pixel-position continuously,
        # anchored at the lifted/centroid cell under the cursor.
        var draw_origin := mouse_pos - lift_off * cell_step

        # For validity colour, snap to the nearest virtual grid cell so the
        # same can_place() logic is consistent with the grid's own preview.
        var grid_rel := mouse_pos - g.position
        var virtual_cell := Vector2i(
            int(floor(grid_rel.x / cell_step.x)),
            int(floor(grid_rel.y / cell_step.y)),
        )
        var preview_origin := virtual_cell - g.get_lift_offset()
        var preview_valid := g.can_place(g.active_item, preview_origin)

        var bg := GridAreaPanel.PREVIEW_VALID_BG if preview_valid else GridAreaPanel.PREVIEW_INVALID_BG
        var border := GridAreaPanel.PREVIEW_VALID_BORDER if preview_valid else GridAreaPanel.PREVIEW_INVALID_BORDER
        var bw := GridAreaPanel.PREVIEW_BORDER_WIDTH

        var active_cells := g.get_active_cells(g.active_item)
        for c: Vector2i in active_cells:
            var rect := Rect2(
                draw_origin + Vector2(c) * cell_step,
                Vector2(PackingGrid.CELL_SIZE, PackingGrid.CELL_SIZE),
            )
            var clipped := rect.intersection(panel_rect)
            if clipped.size.x <= 0.0 or clipped.size.y <= 0.0:
                continue
            draw_rect(clipped, bg, true)
            draw_rect(clipped, border, false, bw)

# ── Signals ────────────────────────────────────────────────────────────────────

signal placement_changed
signal item_clicked(item)
signal cell_clicked(cell_pos: Vector2i)
signal hover_started(cell_pos: Vector2i)
signal hover_ended

# ── Constants ──────────────────────────────────────────────────────────────────

const PREVIEW_VALID_BG := Color(0.20, 0.45, 0.22, 0.70)
const PREVIEW_INVALID_BG := Color(0.45, 0.18, 0.18, 0.70)
const PREVIEW_VALID_BORDER := Color(0.35, 0.75, 0.40, 0.90)
const PREVIEW_INVALID_BORDER := Color(0.75, 0.30, 0.30, 0.90)
const PREVIEW_BORDER_WIDTH := 2.0

# ── State ──────────────────────────────────────────────────────────────────────

var _mouse_inside_panel: bool = false
var _last_mouse_pos: Vector2 = Vector2(-INF, -INF)

# ── Node references ────────────────────────────────────────────────────────────

@onready var _grid: PackingGrid = %PackingGrid
var _preview_overlay: Control

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_PASS

    _preview_overlay = _ShapePreviewOverlay.new(self)
    _preview_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
    _preview_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _preview_overlay.name = "PreviewOverlay"
    # node-src: drawn — runtime inner-class overlay for shape preview
    add_child(_preview_overlay)
    move_child(_preview_overlay, get_child_count() - 1)

    _grid.placement_changed.connect(placement_changed.emit)
    _grid.item_clicked.connect(item_clicked.emit)
    _grid.cell_clicked.connect(cell_clicked.emit)
    _grid.hover_started.connect(hover_started.emit)
    _grid.hover_ended.connect(hover_ended.emit)

    _grid.placement_changed.connect(_preview_overlay.queue_redraw)
    _grid.hover_started.connect(func(_cell): _preview_overlay.queue_redraw())
    _grid.hover_ended.connect(_preview_overlay.queue_redraw)

    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)


func _process(_delta: float) -> void:
    if not _mouse_inside_panel:
        return
    if _grid.phase != PackingGrid.Phase.ITEM_HELD:
        return
    var local := get_local_mouse_position()
    if local != _last_mouse_pos:
        _last_mouse_pos = local
        _preview_overlay.queue_redraw()

# ══ Input ════════════════════════════════════════════════════════════════════════


## Right-click in the margin area cancels a held placement.
func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton \
            and event.pressed \
            and event.button_index == MOUSE_BUTTON_RIGHT:
        if _grid.phase == PackingGrid.Phase.ITEM_HELD:
            _grid.cancel_placement()
            accept_event()


## Escape key cancels a held placement from anywhere in the panel.
func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey \
            and event.pressed \
            and not event.echo \
            and event.keycode == KEY_ESCAPE:
        if _grid.phase == PackingGrid.Phase.ITEM_HELD:
            _grid.cancel_placement()
            get_viewport().set_input_as_handled()


# ══ Common API ════════════════════════════════════════════════════════════════


## Returns the grid-internal size as the node's minimum, so the VBox
## allocates enough space for the full cell area without manual tweaks.
func _get_minimum_size() -> Vector2:
    if not is_inside_tree() or _grid == null:
        return Vector2.ZERO
    var gs := _grid.get_grid_size()
    if gs.x <= 0 or gs.y <= 0:
        return Vector2.ZERO
    var step := _grid.get_cell_step()
    return Vector2(
        max(0, gs.x - 1) * step.x + PackingGrid.CELL_SIZE,
        max(0, gs.y - 1) * step.y + PackingGrid.CELL_SIZE,
    )


func get_grid() -> PackingGrid:
    return _grid

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_mouse_entered() -> void:
    _mouse_inside_panel = true
    _preview_overlay.queue_redraw()


func _on_mouse_exited() -> void:
    _mouse_inside_panel = false
    _preview_overlay.queue_redraw()
