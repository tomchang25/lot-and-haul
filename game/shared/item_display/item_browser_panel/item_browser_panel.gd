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

const SORT_CLICK: UiAudioEvent = preload("res://data/tres/audio_events/click.tres")
const SORT_HOVER: UiAudioEvent = preload("res://data/tres/audio_events/button_hover.tres")
# ── State ──────────────────────────────────────────────────────────────────────

var _mode: DisplayMode = DisplayMode.CARD
var _entries: Array = []
var _selected_entry: ItemEntry = null
var _card_rows: Dictionary = { } # ItemEntry -> ItemCard
var _columns: Array = []

var _sort_column: ItemRow.Column = ItemRow.Column.NAME
var _sort_ascending: bool = true
var _last_sort_popup_focus: int = -1

var _pending_columns: Array = []
var _pending_default_sort: int = -1
var _pending_ascending: bool = true

# ── Node references ────────────────────────────────────────────────────────────

@onready var _card_toggle: Button = %CardToggle
@onready var _table_toggle: Button = %TableToggle
@onready var _card_panel: PanelContainer = %CardPanel
@onready var _card_grid: GridContainer = %CardGrid
@onready var _table_panel: ItemListPanel = %TablePanel
@onready var _mode_toggle_hbox: HBoxContainer = $ModeToggleHBox
@onready var _empty_label: Label = %EmptyLabel
@onready var _sort_hbox: HBoxContainer = %SortHBox
@onready var _sort_option_button: OptionButton = %SortOptionButton
@onready var _sort_dir_button: Button = %SortDirButton

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    set_process(false)
    _card_toggle.pressed.connect(_switch_to_card)
    _table_toggle.pressed.connect(_switch_to_table)

    _table_panel.row_pressed.connect(_on_table_row_pressed)
    _table_panel.tooltip_requested.connect(_on_table_tooltip_requested)
    _table_panel.tooltip_dismissed.connect(_on_table_tooltip_dismissed)
    _table_panel.sort_changed.connect(_on_table_sort_changed)

    _sort_dir_button.pressed.connect(_on_sort_dir_pressed)
    _sort_option_button.pressed.connect(_on_sort_option_pressed)
    _sort_option_button.item_selected.connect(_on_sort_column_selected)
    _sort_option_button.mouse_entered.connect(_on_sort_option_hovered)
    _sort_option_button.get_popup().popup_hide.connect(_on_sort_popup_hide)

    if not _pending_columns.is_empty():
        _table_panel.setup(_pending_columns, _pending_default_sort, _pending_ascending)
        _pending_columns.clear()
        _rebuild_sort_options()

    if not _entries.is_empty():
        _apply()

    _refresh_visibility()


func _process(_delta: float) -> void:
    var popup := _sort_option_button.get_popup()
    if not popup.visible:
        return

    var focused := popup.get_focused_item()
    if focused < 0 or focused == _last_sort_popup_focus:
        return
    _last_sort_popup_focus = focused
    AudioManager.play_event(SORT_HOVER)


func set_mode_toggle_visible(shown: bool) -> void:
    _mode_toggle_hbox.visible = shown

# ══ Display mode API ══════════════════════════════════════════════════════════


func set_mode(mode: DisplayMode) -> void:
    if mode == _mode:
        return
    _mode = mode
    if is_node_ready():
        _refresh_visibility()


func get_mode() -> DisplayMode:
    return _mode


func toggle_mode() -> void:
    match _mode:
        DisplayMode.CARD:
            set_mode(DisplayMode.TABLE)
        DisplayMode.TABLE:
            set_mode(DisplayMode.CARD)

# ══ Item API ══════════════════════════════════════════════════════════════════


func setup(
        columns: Array,
        default_sort_column = ItemRow.Column.NAME,
        default_ascending := true,
) -> void:
    _columns = columns
    _sort_column = default_sort_column
    _sort_ascending = default_ascending
    if is_node_ready():
        _table_panel.setup(columns, default_sort_column, default_ascending)
        _rebuild_sort_options()
    else:
        _pending_columns = columns.duplicate()
        _pending_default_sort = default_sort_column
        _pending_ascending = default_ascending


func populate(entries: Array) -> void:
    _entries = entries.duplicate()
    if _selected_entry != null and not _selected_entry in _entries:
        _selected_entry = null
    if is_node_ready():
        _apply()


func get_selected() -> ItemEntry:
    return _selected_entry


func set_selected(entry: ItemEntry) -> void:
    _select_entry(entry, false)


func refresh() -> void:
    _sort_entries()
    _rebuild_card_grid()
    _table_panel.populate(_entries)
    _apply_selection()
    _refresh_visibility()


func refresh_entry(entry: ItemEntry) -> void:
    if _card_rows.has(entry):
        _card_rows[entry].setup(entry)
    _table_panel.refresh_row(entry)
    if _selected_entry == entry and _card_rows.has(entry):
        _card_rows[entry].set_selected(true)

# ══ Internal ══════════════════════════════════════════════════════════════════


func _apply() -> void:
    _sort_entries()
    _rebuild_card_grid()
    _table_panel.populate(_entries)
    _apply_selection()
    _refresh_visibility()
    _sync_sort_ui()


## Routes every selection change through a single path so both display modes
## stay in sync. Called by set_selected(), card clicks, and table row clicks.
func _select_entry(entry: ItemEntry, emit_pressed: bool) -> void:
    if entry == _selected_entry:
        return
    _clear_card_selection()
    _selected_entry = entry
    _apply_card_selection()
    _apply_table_selection()
    if emit_pressed:
        AudioManager.play_event(SORT_CLICK)
        entry_pressed.emit(entry)


func _clear_card_selection() -> void:
    if _selected_entry != null and _card_rows.has(_selected_entry):
        _card_rows[_selected_entry].set_selected(false)


func _apply_card_selection() -> void:
    if _selected_entry != null and _card_rows.has(_selected_entry):
        _card_rows[_selected_entry].set_selected(true)


func _apply_table_selection() -> void:
    for row_entry in _table_panel.get_all_rows().keys():
        var row := _table_panel.get_row(row_entry)
        if row != null:
            row.set_selection_state(ItemRow.SelectionState.AVAILABLE)

    if _selected_entry != null:
        var row := _table_panel.get_row(_selected_entry)
        if row != null:
            row.set_selection_state(ItemRow.SelectionState.SELECTED)


func _apply_selection() -> void:
    _apply_card_selection()
    _apply_table_selection()


func _refresh_visibility() -> void:
    var has_entries := not _entries.is_empty()
    var in_card := _mode == DisplayMode.CARD
    var in_table := _mode == DisplayMode.TABLE

    _card_toggle.button_pressed = in_card
    _table_toggle.button_pressed = in_table
    _card_panel.visible = has_entries and in_card
    _table_panel.visible = has_entries and in_table
    _empty_label.visible = not has_entries
    if not has_entries:
        _empty_label.text = TranslationServer.translate("UI_NO_ITEMS")
    _sort_hbox.visible = has_entries and in_card and not _columns.is_empty()


func _rebuild_card_grid() -> void:
    # Remove cards for entries no longer in the list
    for entry in _card_rows.keys():
        if not entry in _entries:
            _card_rows[entry].queue_free()
            _card_rows.erase(entry)

    # Reuse existing cards, create new ones, and maintain correct order
    var index := 0
    for entry: ItemEntry in _entries:
        var card: ItemCard
        if _card_rows.has(entry):
            card = _card_rows[entry] as ItemCard
        else:
            card = ItemCardScene.instantiate()
            card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            card.clicked.connect(_on_card_clicked)
            card.mouse_entered.connect(_on_card_mouse_entered.bind(card, entry))
            card.mouse_exited.connect(_on_card_mouse_exited)
            _card_grid.add_child(card)
            _card_rows[entry] = card
        card.setup(entry)
        _card_grid.move_child(card, index)
        index += 1

# ══ Sorting ═════════════════════════════════════════════════════════════════════


func _sort_entries() -> void:
    if _entries.size() < 2 or _columns.is_empty():
        return
    var col := _sort_column
    var asc := _sort_ascending
    _entries.sort_custom(
        func(a, b) -> bool:
            var va := ItemEntryDisplayHelper.sort_value(a, col)
            var vb := ItemEntryDisplayHelper.sort_value(b, col)
            if asc:
                return va < vb
            return va > vb
    )


func _rebuild_sort_options() -> void:
    _sort_option_button.clear()
    for col in _columns:
        var key: String = ItemRow.COLUMN_HEADERS.get(col, "?")
        var text: String
        if key != "?":
            text = TranslationServer.translate(key)
        else:
            text = "?"
        _sort_option_button.add_item(text, col)
    _sync_sort_ui()


func _sync_sort_ui() -> void:
    var idx := _sort_option_button.get_item_index(_sort_column)
    if idx >= 0:
        _sort_option_button.select(idx)
    _sort_dir_button.text = "▲" if _sort_ascending else "▼"


func _on_sort_dir_pressed() -> void:
    AudioManager.play_event(SORT_CLICK)
    _sort_ascending = not _sort_ascending
    _sync_sort_ui()
    _sort_entries()
    _rebuild_card_grid()
    _table_panel.set_sort(_sort_column, _sort_ascending)
    _apply_selection()


func _on_sort_column_selected(index: int) -> void:
    AudioManager.play_event(SORT_CLICK)
    _sort_column = _sort_option_button.get_item_id(index) as ItemRow.Column
    _sort_ascending = true
    _sync_sort_ui()
    _sort_entries()
    _rebuild_card_grid()
    _table_panel.set_sort(_sort_column, _sort_ascending)
    _apply_selection()


func _on_sort_option_hovered() -> void:
    AudioManager.play_event(SORT_HOVER)


func _on_sort_option_pressed() -> void:
    _last_sort_popup_focus = -1
    set_process(true)


func _on_sort_popup_hide() -> void:
    _last_sort_popup_focus = -1
    set_process(false)


func _on_table_sort_changed(column: int, ascending: bool) -> void:
    _sort_column = column as ItemRow.Column
    _sort_ascending = ascending
    _sync_sort_ui()
    _sort_entries()
    _rebuild_card_grid()
    _apply_selection()

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
    _select_entry(entry, true)


func _on_card_mouse_entered(card: ItemCard, entry: ItemEntry) -> void:
    AudioManager.play_event(SORT_HOVER)
    entry_hovered.emit(entry, card.get_global_rect())


func _on_card_mouse_exited() -> void:
    entry_unhovered.emit()

# ══ Signal handlers — Table ══════════════════════════════════════════════════


func _on_table_row_pressed(entry) -> void:
    if entry is ItemEntry:
        _select_entry(entry, true)


func _on_table_tooltip_requested(entry, anchor: Rect2) -> void:
    AudioManager.play_event(SORT_HOVER)
    entry_hovered.emit(entry, anchor)


func _on_table_tooltip_dismissed() -> void:
    entry_unhovered.emit()
