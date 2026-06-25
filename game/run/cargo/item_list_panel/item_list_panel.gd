# item_list_panel.gd
# Scrollable grid of CargoItemCards for selecting won items to load onto the vehicle.
class_name CargoItemListPanel
extends PanelContainer

signal item_selected(entry: ItemEntry)
signal item_pick_requested(entry: ItemEntry)
signal tooltip_requested(entry: ItemEntry, anchor: Rect2)
signal tooltip_dismissed

const GRID_COLUMNS := 2
const CargoItemCardScene: PackedScene = preload("res://game/run/cargo/cargo_item_card.tscn")

var _item_cards: Dictionary = { }
var _selected_entry: ItemEntry = null

@onready var _scroll_container: ScrollContainer = %ScrollContainer
@onready var _item_grid: GridContainer = %ItemGrid
@onready var _empty_label: Label = %ListEmptyLabel


## Clears any existing cards and builds a fresh grid from the given ItemEntry array.
func rebuild(items: Array) -> void:
    _clear_cards()
    _item_cards.clear()

    if items.is_empty():
        _empty_label.show()
        _scroll_container.hide()
        return

    _empty_label.hide()
    _scroll_container.show()

    for item in items:
        var entry := item as ItemEntry
        if entry == null:
            ToastManager.show_dev_error("CargoItemListPanel.rebuild: item is not ItemEntry")
            continue
        var card: CargoItemCard = CargoItemCardScene.instantiate()
        card.setup(entry)
        card.row_pressed.connect(_on_card_pressed.bind(card))
        card.tooltip_requested.connect(_on_tooltip_requested)
        card.tooltip_dismissed.connect(_on_tooltip_dismissed)
        _item_grid.add_child(card)
        _item_cards[entry] = card


## Syncs each card's loaded/held visual state with the packing grid and trailer contents.
func update_row_states(grid: PackingGrid, extra_items: Array = []) -> void:
    for entry in _item_cards.keys():
        var card := _item_cards[entry] as CargoItemCard
        if entry == null or card == null:
            continue
        var is_loaded: bool = grid.is_item_placed(entry) or entry in extra_items
        var is_held: bool = grid.active_item == entry and grid.phase == PackingGrid.Phase.ITEM_HELD
        card.set_loaded(is_loaded)
        card.set_holding(is_held)


## Toggles the highlight on a card when its grid cell or trailer slot is hovered.
func set_external_highlight(entry: ItemEntry, highlighted: bool) -> void:
    if entry == null or not _item_cards.has(entry):
        return
    var card := _item_cards[entry] as CargoItemCard
    if card != null:
        card.set_external_highlight(highlighted)


## Returns the card for a given entry, or null if not found.
func get_row(entry: ItemEntry) -> CargoItemCard:
    return _item_cards.get(entry) as CargoItemCard


## Plays the loaded-pulse animation on the card for the given entry.
func play_card_pulse(entry: ItemEntry) -> void:
    var card := get_row(entry)
    if card != null:
        card.play_loaded_pulse()


## Plays the reject-shake animation on the card for the given entry.
func play_card_reject(entry: ItemEntry) -> void:
    var card := get_row(entry)
    if card != null:
        card.play_invalid_reject()


## Clears all cards and resets to the empty state.
func clear() -> void:
    _clear_cards()
    _item_cards.clear()
    _empty_label.show()
    _scroll_container.hide()


func _clear_cards() -> void:
    for child: Node in _item_grid.get_children():
        _item_grid.remove_child(child)
        child.queue_free()


func _on_card_pressed(entry: ItemEntry, _card: CargoItemCard) -> void:
    if entry == null:
        return
    _set_selected_entry(entry)
    item_selected.emit(entry)
    item_pick_requested.emit(entry)


func _set_selected_entry(entry: ItemEntry) -> void:
    if _selected_entry == entry:
        return
    var prev_card := _item_cards.get(_selected_entry) as CargoItemCard
    if prev_card != null:
        prev_card.set_selected(false)
    _selected_entry = entry
    var new_card := _item_cards.get(entry) as CargoItemCard
    if new_card != null:
        new_card.set_selected(true)


func _on_tooltip_requested(entry: ItemEntry, anchor: Rect2) -> void:
    tooltip_requested.emit(entry, anchor)


func _on_tooltip_dismissed() -> void:
    tooltip_dismissed.emit()
