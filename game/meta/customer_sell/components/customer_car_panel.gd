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
const ClueTagScene: PackedScene = preload("res://game/shared/item_display/clue_tag/clue_tag.tscn")

# ── State ─────────────────────────────────────────────────────────────────────

var _customer: CustomerEntry = null

# ── Node references ───────────────────────────────────────────────────────────

@onready var _customer_name_label: Label = %CustomerNameLabel
@onready var _capacity_label: Label = %CapacityLabel
@onready var _tags_flow: Container = %TagsFlow
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
        total += SellMath.item_contribution(entry, _customer)
        if SellMath.is_item_verified(entry):
            verified_count += 1
    _animate_car_total(total)
    _verified_count_label.text = TranslationServer.translate("UI_VERIFIED_LABEL") % [verified_count, placed_items.size()]

# ══ Internal ══════════════════════════════════════════════════════════════════


func _apply() -> void:
    if _customer == null:
        return
    _customer_name_label.text = _customer.display_name
    _capacity_label.text = TranslationServer.translate("UI_CAPACITY_LABEL") % [_customer.grid_columns, _customer.grid_rows]
    _car_total_label.text = TranslationServer.translate("UI_CAR_TOTAL_LABEL") % 0
    _verified_count_label.text = TranslationServer.translate("UI_VERIFIED_LABEL") % [0, 0]
    _rebuild_tags()


func _animate_car_total(target: int) -> void:
    var current: int = 0
    var raw := _car_total_label.text
    var prefix := TranslationServer.translate("UI_CAR_TOTAL_LABEL").split("$")[0]
    if raw.begins_with(prefix):
        current = int(raw.trim_prefix(prefix))
    if current == target:
        return
    var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
    tween.tween_method(
        func(val: float) -> void:
            _car_total_label.text = TranslationServer.translate("UI_CAR_TOTAL_LABEL") % int(val),
        float(current),
        float(target),
        0.3,
    )


func _rebuild_tags() -> void:
    _clear_tag_nodes()
    if _customer == null:
        return

    for tag: String in _customer.demand_tags:
        var clue := ClueRegistry.get_clue_by_id(tag)
        if clue == null:
            continue
        var valued: bool = tag in _customer.valued_negative_tags
        var tag_node: ClueTag = ClueTagScene.instantiate()
        tag_node.setup(clue, true, valued)
        _tags_flow.add_child(tag_node)


func _clear_tag_nodes() -> void:
    for child in _tags_flow.get_children():
        _tags_flow.remove_child(child)
        child.queue_free()


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
