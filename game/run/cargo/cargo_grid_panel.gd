# cargo_grid_panel.gd
# PanelContainer wrapper for the cargo PackingGrid — relays signals and
# handles margin-area input (right-click / Escape cancel).
# Reads:  PackingGrid phase, active_item
# Writes: nothing
class_name CargoGridPanel
extends PanelContainer

# ── Signals ────────────────────────────────────────────────────────────────────

signal placement_changed
signal item_clicked(item)
signal cell_clicked(cell_pos: Vector2i)
signal hover_started(cell_pos: Vector2i)
signal hover_ended
signal placement_cancelled(item)

# ── Node references ────────────────────────────────────────────────────────────

@onready var _grid: PackingGrid = %CargoGrid

# ══ Lifecycle ══════════════════════════════════════════════════════════════════


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_PASS

    _grid.placement_changed.connect(placement_changed.emit)
    _grid.item_clicked.connect(item_clicked.emit)
    _grid.cell_clicked.connect(cell_clicked.emit)
    _grid.hover_started.connect(hover_started.emit)
    _grid.hover_ended.connect(hover_ended.emit)
    _grid.placement_cancelled.connect(placement_cancelled.emit)


# ══ Input ════════════════════════════════════════════════════════════════════════


func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton \
            and event.pressed \
            and event.button_index == MOUSE_BUTTON_RIGHT:
        if _grid.phase == PackingGrid.Phase.ITEM_HELD:
            _grid.cancel_placement()
            accept_event()


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey \
            and event.pressed \
            and not event.echo \
            and event.keycode == KEY_ESCAPE:
        if _grid.phase == PackingGrid.Phase.ITEM_HELD:
            _grid.cancel_placement()
            get_viewport().set_input_as_handled()

# ══ Common API ════════════════════════════════════════════════════════════════


func get_grid() -> PackingGrid:
    return _grid
