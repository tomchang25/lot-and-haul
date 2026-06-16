# customer_car_panel.gd
# Wraps the shared PackingGrid in a selling-specific shell — car title, capacity, clear action.
# Reads:  PackingGrid, CustomerEntry
# Writes: nothing
class_name CustomerCarPanel
extends PanelContainer

signal placement_changed
signal item_clicked(item)
signal cell_clicked(cell_pos: Vector2i)
signal hover_started(cell_pos: Vector2i)
signal hover_ended
signal car_clear_requested

# ── Constants ─────────────────────────────────────────────────────────────────

const CANCEL: UiAudioEvent = preload("res://data/tres/audio_events/cancel_dismiss.tres")

# ── State ─────────────────────────────────────────────────────────────────────

var _customer: CustomerEntry = null

# ── Node references ───────────────────────────────────────────────────────────

@onready var _car_title_label: Label = %CarTitleLabel
@onready var _capacity_label: Label = %CapacityLabel
@onready var _grid: PackingGrid = %PackingGrid
@onready var _clear_button: SfxButton = %ClearButton

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _clear_button.pressed.connect(_on_clear_pressed)
    _clear_button.press_event = CANCEL

    _grid.placement_changed.connect(_on_grid_placement_changed)
    _grid.item_clicked.connect(_on_grid_item_clicked)
    _grid.cell_clicked.connect(_on_grid_cell_clicked)
    _grid.hover_started.connect(hover_started.emit)
    _grid.hover_ended.connect(hover_ended.emit)

    if _customer != null:
        _apply()
    else:
        _show_placeholder_grid()

# ══ Common API ════════════════════════════════════════════════════════════════


func setup(customer: CustomerEntry) -> void:
    _customer = customer
    if is_node_ready():
        _apply()


func get_grid() -> PackingGrid:
    return _grid


func refresh() -> void:
    if is_node_ready():
        _apply()

# ══ Internal ══════════════════════════════════════════════════════════════════


func _apply() -> void:
    if _customer == null:
        return
    _car_title_label.text = "%s's Car" % _customer.display_name
    _capacity_label.text = "Capacity: %d\u00d7%d" % [_customer.grid_columns, _customer.grid_rows]


func _show_placeholder_grid() -> void:
    if _grid.get_child_count() == 0:
        _grid.setup(4, 3)

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_clear_pressed() -> void:
    _grid.reset()
    AudioManager.play_event(CANCEL)
    car_clear_requested.emit()


func _on_grid_placement_changed() -> void:
    placement_changed.emit()


func _on_grid_item_clicked(item) -> void:
    item_clicked.emit(item)


func _on_grid_cell_clicked(pos: Vector2i) -> void:
    cell_clicked.emit(pos)
