# selling_item_list_panel.gd
# Scrollable 3-column card grid for the sell screen — owns card instances and selection signals.
# Reads:  ItemEntry, SellMath
# Writes: nothing
class_name SellingItemListPanel
extends PanelContainer

signal item_selected(entry: ItemEntry)
signal item_pick_requested(entry: ItemEntry)
signal tooltip_requested(entry: ItemEntry, anchor: Rect2)
signal tooltip_dismissed

# ── Constants ─────────────────────────────────────────────────────────────────

const GRID_COLUMNS := 3
const SellingItemCardScene: PackedScene = preload("res://game/meta/customer_sell/components/selling_item_card.tscn")

# ── State ─────────────────────────────────────────────────────────────────────

var _item_cards: Dictionary = { } # ItemEntry -> SellingItemCard
var _selected_entry: ItemEntry = null

# ── Node references ───────────────────────────────────────────────────────────

@onready var _scroll_container: ScrollContainer = %ScrollContainer
@onready var _item_grid: GridContainer = %ItemGrid
@onready var _empty_label: Label = %ListEmptyLabel

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    pass

# ══ Common API ════════════════════════════════════════════════════════════════


## Rebuilds the item card grid from matched items.
func rebuild(customer: CustomerEntry, storage_items: Array, grid_setup_callable: Callable) -> void:
    _clear_cards()
    _item_cards.clear()

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
        var card: SellingItemCard = SellingItemCardScene.instantiate()
        card.setup(entry, fit)
        card.row_pressed.connect(_on_card_pressed.bind(card))
        card.tooltip_requested.connect(_on_tooltip_requested)
        card.tooltip_dismissed.connect(_on_tooltip_dismissed)
        _item_grid.add_child(card)
        _item_cards[entry] = card


## Updates loaded/held/highlight state on all cards based on grid state.
func update_row_states(grid: PackingGrid) -> void:
    for entry in _item_cards.keys():
        var card := _item_cards[entry] as SellingItemCard
        if entry == null or card == null:
            continue
        var is_loaded := grid.is_item_placed(entry)
        var is_held: bool = grid.active_item == entry and grid.phase == PackingGrid.Phase.ITEM_HELD
        card.set_loaded(is_loaded)
        card.set_holding(is_held)


## Highlights a specific card from an external source (e.g. grid hover).
func set_external_highlight(entry: ItemEntry, highlighted: bool) -> void:
    if entry == null or not _item_cards.has(entry):
        return
    var card := _item_cards[entry] as SellingItemCard
    if card != null:
        card.set_external_highlight(highlighted)


## Returns the card for a given entry, or null.
func get_row(entry: ItemEntry) -> SellingItemCard:
    return _item_cards.get(entry) as SellingItemCard


## Triggers a pulse animation on the card for the given entry.
func play_card_pulse(entry: ItemEntry) -> void:
    var card := get_row(entry)
    if card != null:
        card.play_loaded_pulse()


## Triggers a reject animation on the card for the given entry.
func play_card_reject(entry: ItemEntry) -> void:
    var card := get_row(entry)
    if card != null:
        card.play_invalid_reject()


## Clears all cards.
func clear() -> void:
    _clear_cards()
    _item_cards.clear()
    _empty_label.show()
    _scroll_container.hide()

# ══ Internal ══════════════════════════════════════════════════════════════════


func _clear_cards() -> void:
    for child: Node in _item_grid.get_children():
        _item_grid.remove_child(child)
        child.queue_free()

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_card_pressed(entry: ItemEntry, _card: SellingItemCard) -> void:
    if entry == null:
        return
    _set_selected_entry(entry)
    item_selected.emit(entry)
    item_pick_requested.emit(entry)


func _set_selected_entry(entry: ItemEntry) -> void:
    if _selected_entry == entry:
        return
    var prev_card := _item_cards.get(_selected_entry) as SellingItemCard
    if prev_card != null:
        prev_card.set_selected(false)
    _selected_entry = entry
    var new_card := _item_cards.get(entry) as SellingItemCard
    if new_card != null:
        new_card.set_selected(true)


func _on_tooltip_requested(entry: ItemEntry, anchor: Rect2) -> void:
    tooltip_requested.emit(entry, anchor)


func _on_tooltip_dismissed() -> void:
    tooltip_dismissed.emit()
