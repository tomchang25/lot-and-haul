# selling_item_list_panel.gd
# Scrollable item list for the sell screen — owns item row instances and selection signals.
# Reads:  ItemEntry, SellMath
# Writes: nothing
class_name SellingItemListPanel
extends PanelContainer

signal item_selected(entry: ItemEntry)
signal item_pick_requested(entry: ItemEntry)
signal tooltip_requested(entry: ItemEntry, anchor: Rect2)
signal tooltip_dismissed

# ── Constants ─────────────────────────────────────────────────────────────────

const SellingItemRowScene: PackedScene = preload("res://game/meta/customer_sell/components/selling_item_row.tscn")

# ── State ─────────────────────────────────────────────────────────────────────

var _item_rows: Dictionary = { } # ItemEntry -> SellingItemRow
var _selected_entry: ItemEntry = null

# ── Node references ───────────────────────────────────────────────────────────

@onready var _scroll_container: ScrollContainer = %ScrollContainer
@onready var _item_list_vbox: VBoxContainer = %ItemListVBox
@onready var _empty_label: Label = %ListEmptyLabel

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    pass

# ══ Common API ════════════════════════════════════════════════════════════════


## Rebuilds the item list from matched items, creating rows with fit data.
func rebuild(customer: CustomerEntry, storage_items: Array, grid_setup_callable: Callable) -> void:
    _clear_rows()
    _item_rows.clear()

    var matched: Array = SellMath.matched_items(customer, storage_items)
    if matched.is_empty():
        _empty_label.show()
        _scroll_container.hide()
        return

    _empty_label.hide()
    _scroll_container.show()
    grid_setup_callable.call(matched)

    for item in matched:
        var entry := item as ItemEntry
        if entry == null:
            ToastManager.show_dev_error("SellingItemListPanel.rebuild: matched item is not ItemEntry")
            continue
        var fit := SellMath.item_fit(customer, entry)
        var row: SellingItemRow = SellingItemRowScene.instantiate()
        row.setup(entry, fit)
        row.row_pressed.connect(_on_row_pressed.bind(row))
        row.tooltip_requested.connect(_on_tooltip_requested)
        row.tooltip_dismissed.connect(_on_tooltip_dismissed)
        _item_list_vbox.add_child(row)
        _item_rows[entry] = row


## Updates loaded/held/highlight state on all rows based on grid state.
func update_row_states(grid: PackingGrid) -> void:
    for entry in _item_rows.keys():
        var row := _item_rows[entry] as SellingItemRow
        if entry == null or row == null:
            continue
        var is_loaded := grid.is_item_placed(entry)
        var is_held: bool = grid.active_item == entry and grid.phase == PackingGrid.Phase.ITEM_HELD
        row.set_loaded(is_loaded)
        row.set_holding(is_held)


## Highlights a specific row from an external source (e.g. grid hover).
func set_external_highlight(entry: ItemEntry, highlighted: bool) -> void:
    if entry == null or not _item_rows.has(entry):
        return
    var row := _item_rows[entry] as SellingItemRow
    if row != null:
        row.set_external_highlight(highlighted)


## Returns the row for a given entry, or null.
func get_row(entry: ItemEntry) -> SellingItemRow:
    return _item_rows.get(entry) as SellingItemRow


## Clears all rows.
func clear() -> void:
    _clear_rows()
    _item_rows.clear()
    _empty_label.show()
    _scroll_container.hide()

# ══ Internal ══════════════════════════════════════════════════════════════════


func _clear_rows() -> void:
    for child: Node in _item_list_vbox.get_children():
        _item_list_vbox.remove_child(child)
        child.queue_free()

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_row_pressed(entry: ItemEntry, _row: SellingItemRow) -> void:
    if entry == null:
        return
    _set_selected_entry(entry)
    item_selected.emit(entry)
    item_pick_requested.emit(entry)


func _set_selected_entry(entry: ItemEntry) -> void:
    if _selected_entry == entry:
        return
    var prev_row := _item_rows.get(_selected_entry) as SellingItemRow
    if prev_row != null:
        prev_row.set_selected(false)
    _selected_entry = entry
    var new_row := _item_rows.get(entry) as SellingItemRow
    if new_row != null:
        new_row.set_selected(true)


func _on_tooltip_requested(entry: ItemEntry, anchor: Rect2) -> void:
    tooltip_requested.emit(entry, anchor)


func _on_tooltip_dismissed() -> void:
    tooltip_dismissed.emit()
