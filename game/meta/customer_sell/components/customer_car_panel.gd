# customer_car_panel.gd
# Wraps the shared PackingGrid in a selling-specific shell — customer info, car title, capacity,
# car summary stats, clear action.
# Reads:  CustomerEntry, ClueRegistry, SellMath
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

@onready var _customer_name_label: Label = %CustomerNameLabel
@onready var _capacity_label: Label = %CapacityLabel
@onready var _demand_tags_label: Label = %DemandTagsLabel
@onready var _car_total_label: Label = %CarTotalLabel
@onready var _verified_count_label: Label = %VerifiedCountLabel
@onready var _grid: PackingGrid = %PackingGrid
@onready var _clear_button: SfxButton = %ClearButton
@onready var deal_panel: DealPanel = %DealPanel

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


func set_car_info(placed_items: Array) -> void:
    if not is_node_ready():
        return
    var total := 0
    var verified_count := 0
    for item in placed_items:
        var entry := item as ItemEntry
        if entry == null:
            continue
        total += entry.item_price
        if SellMath.is_item_verified(entry):
            verified_count += 1
    _animate_car_total(total)
    _verified_count_label.text = "Verified: %d / %d" % [verified_count, placed_items.size()]


func _animate_car_total(target: int) -> void:
    var current: int = 0
    var raw := _car_total_label.text
    if raw.begins_with("Car total: $"):
        current = int(raw.trim_prefix("Car total: $"))
    if current == target:
        return
    var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
    tween.tween_method(
        func(val: float) -> void:
            _car_total_label.text = "Car total: $%d" % int(val),
        float(current),
        float(target),
        0.3,
    )

# ══ Internal ══════════════════════════════════════════════════════════════════


func _apply() -> void:
    if _customer == null:
        return
    _customer_name_label.text = _customer.display_name
    _capacity_label.text = "Capacity: %d\u00d7%d" % [_customer.grid_columns, _customer.grid_rows]
    _demand_tags_label.text = "Wants: %s" % _format_demand_tags()
    _car_total_label.text = "Car total: $0"
    _verified_count_label.text = "Verified: 0 / 0"


func _format_demand_tags() -> String:
    var tag_names: Array[String] = []
    for tag: String in _customer.demand_tags:
        var clue := ClueRegistry.get_clue_by_id(tag)
        tag_names.append(clue.known_text if clue != null and clue.known_text != "" else tag)
    return ", ".join(tag_names)


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
