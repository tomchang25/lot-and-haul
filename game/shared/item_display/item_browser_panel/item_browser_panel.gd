# item_browser_panel.gd
# Shared item browser supporting Card mode (scrollable grid) and Table mode
# (sortable rows via ItemListPanel). Handles entry population, mode toggle,
# selection, and hover/press signals.
class_name ItemBrowserPanel
extends VBoxContainer

signal entry_pressed(entry: ItemEntry)
signal entry_hovered(entry: ItemEntry, anchor: Rect2)
signal entry_unhovered

enum DisplayMode { CARD, TABLE }

const CARD_COLS := 4

const ItemCardScene: PackedScene = preload("res://game/shared/item_display/item_card.tscn")

# ── State ──────────────────────────────────────────────────────────────────────

var _mode: DisplayMode = DisplayMode.TABLE
var _entries: Array = []
var _selected_entry: ItemEntry = null
var _card_rows: Dictionary = { } # ItemEntry -> ItemCard
var _columns: Array = []

var _pending_columns: Array = []
var _pending_default_sort: int = -1
var _pending_ascending: bool = true

# ── Node references ────────────────────────────────────────────────────────────

@onready var _card_toggle: Button = %CardToggle
@onready var _table_toggle: Button = %TableToggle
@onready var _card_panel: PanelContainer = %CardPanel
@onready var _card_grid: GridContainer = %CardGrid
@onready var _table_panel: ItemListPanel = %TablePanel
@onready var _empty_label: Label = %EmptyLabel

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _card_toggle.pressed.connect(_switch_to_card)
    _table_toggle.pressed.connect(_switch_to_table)

    _table_panel.row_pressed.connect(_on_table_row_pressed)
    _table_panel.tooltip_requested.connect(_on_table_tooltip_requested)
    _table_panel.tooltip_dismissed.connect(_on_table_tooltip_dismissed)

    if not _pending_columns.is_empty():
        _table_panel.setup(_pending_columns, _pending_default_sort, _pending_ascending)
        _pending_columns.clear()

    if not _entries.is_empty():
        _apply()

    _refresh_mode()

# ══ Display mode API ══════════════════════════════════════════════════════════


func set_mode(mode: DisplayMode) -> void:
    if mode == _mode:
        return
    _mode = mode
    if is_node_ready():
        _refresh_mode()


func get_mode() -> DisplayMode:
    return _mode


func toggle_mode() -> void:
    match _mode:
        DisplayMode.CARD:
            set_mode(DisplayMode.TABLE)
        DisplayMode.TABLE:
            set_mode(DisplayMode.CARD)

# ══ Item API ══════════════════════════════════════════════════════════════════


func setup(columns: Array, default_sort_column = ItemRow.Column.NAME, default_ascending := true) -> void:
    _columns = columns
    if is_node_ready():
        _table_panel.setup(columns, default_sort_column, default_ascending)
    else:
        _pending_columns = columns.duplicate()


func populate(entries: Array) -> void:
    _entries = entries.duplicate()
    if is_node_ready():
        _apply()


func get_selected() -> ItemEntry:
    return _selected_entry


func set_selected(entry: ItemEntry) -> void:
    _deselect_current()
    _selected_entry = entry
    _apply_card_selection()
    _apply_table_selection()


func refresh() -> void:
    _rebuild_card_grid()
    _table_panel.populate(_entries)
    _apply_card_selection()
    _apply_table_selection()


func refresh_entry(entry: ItemEntry) -> void:
    if _card_rows.has(entry):
        _card_rows[entry].setup(entry)
    _table_panel.refresh_row(entry)

# ══ Internal ══════════════════════════════════════════════════════════════════


func _apply() -> void:
    _rebuild_card_grid()
    _table_panel.populate(_entries)
    _refresh_empty()


func _refresh_empty() -> void:
    var has_entries := not _entries.is_empty()
    _card_panel.visible = has_entries and _mode == DisplayMode.CARD
    _table_panel.visible = has_entries and _mode == DisplayMode.TABLE
    _empty_label.visible = not has_entries
    if _empty_label.visible:
        _empty_label.text = "No items."


func _rebuild_card_grid() -> void:
    for child in _card_grid.get_children():
        child.queue_free()
    _card_rows.clear()

    for entry: ItemEntry in _entries:
        var card: ItemCard = ItemCardScene.instantiate()
        card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        card.setup(entry)
        card.clicked.connect(_on_card_clicked)
        card.mouse_entered.connect(_on_card_mouse_entered.bind(card, entry))
        card.mouse_exited.connect(_on_card_mouse_exited)
        _card_grid.add_child(card)
        _card_rows[entry] = card


func _refresh_mode() -> void:
    _card_toggle.button_pressed = _mode == DisplayMode.CARD
    _table_toggle.button_pressed = _mode == DisplayMode.TABLE
    _card_panel.visible = _mode == DisplayMode.CARD and not _entries.is_empty()
    _table_panel.visible = _mode == DisplayMode.TABLE and not _entries.is_empty()
    _empty_label.visible = _entries.is_empty()
    if _empty_label.visible:
        _empty_label.text = "No items."


func _deselect_current() -> void:
    if _selected_entry != null and _card_rows.has(_selected_entry):
        _card_rows[_selected_entry].set_selected(false)
    _selected_entry = null


func _apply_card_selection() -> void:
    if _selected_entry != null and _card_rows.has(_selected_entry):
        _card_rows[_selected_entry].set_selected(true)


func _apply_table_selection() -> void:
    for entry: ItemEntry in _entries:
        var row := _table_panel.get_row(entry)
        if row != null:
            if entry == _selected_entry:
                row.set_selection_state(ItemRow.SelectionState.SELECTED)
            else:
                row.set_selection_state(ItemRow.SelectionState.NONE)

# ══ Mode switch handlers ═════════════════════════════════════════════════════


func _switch_to_card() -> void:
    set_mode(DisplayMode.CARD)


func _switch_to_table() -> void:
    set_mode(DisplayMode.TABLE)

# ══ Signal handlers — Card ═══════════════════════════════════════════════════


func _on_card_clicked(card: ItemCard) -> void:
    var entry := card.get_entry()
    if entry == null:
        return
    _deselect_current()
    _selected_entry = entry
    card.set_selected(true)
    entry_pressed.emit(entry)


func _on_card_mouse_entered(card: ItemCard, entry: ItemEntry) -> void:
    entry_hovered.emit(entry, card.get_global_rect())


func _on_card_mouse_exited() -> void:
    entry_unhovered.emit()

# ══ Signal handlers — Table ══════════════════════════════════════════════════


func _on_table_row_pressed(entry) -> void:
    if entry is ItemEntry:
        _deselect_current()
        _selected_entry = entry
        _apply_card_selection()
        entry_pressed.emit(entry)


func _on_table_tooltip_requested(entry, anchor: Rect2) -> void:
    entry_hovered.emit(entry, anchor)


func _on_table_tooltip_dismissed() -> void:
    entry_unhovered.emit()
