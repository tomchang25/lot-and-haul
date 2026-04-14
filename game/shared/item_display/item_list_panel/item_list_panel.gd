# item_list_panel.gd
# Reusable header + scrollable rows panel for displaying a list of ItemEntries.
# Consumers choose which columns to show via the columns array passed to setup().
# Header buttons are built at runtime (count depends on columns) and support
# click-to-sort with an ascending/descending toggle per column.
class_name ItemListPanel
extends PanelContainer

signal row_pressed(entry: ItemEntry)
signal tooltip_requested(entry: ItemEntry, ctx: ItemViewContext, anchor: Rect2)
signal tooltip_dismissed

# ── Constants ─────────────────────────────────────────────────────────────────

const ItemRowScene: PackedScene = preload("uid://brx8agwvlpi3f")

# ── State ─────────────────────────────────────────────────────────────────────

var _ctx: ItemViewContext = null
var _columns: Array = [] # Array of ItemRow.Column
var _sort_column: ItemRow.Column = ItemRow.Column.NAME
var _sort_ascending: bool = true
var _rows: Dictionary = { } # ItemEntry → ItemRow

# ── Node references ───────────────────────────────────────────────────────────

@onready var _column_header: HBoxContainer = $PanelVBox/ColumnHeader
@onready var _row_container: VBoxContainer = $PanelVBox/ScrollContainer/RowContainer

# ══ Common API ════════════════════════════════════════════════════════════════


func setup(ctx: ItemViewContext, columns: Array) -> void:
    _ctx = ctx
    _columns = columns
    if _columns.size() > 0 and not (_sort_column in _columns):
        _sort_column = _columns[0]
    if is_node_ready():
        _build_header()


func populate(entries: Array) -> void:
    clear()

    for entry: ItemEntry in entries:
        var row: ItemRow = ItemRowScene.instantiate()
        row.setup(entry, _ctx, _columns)
        row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

        row.row_pressed.connect(_on_row_pressed)
        row.tooltip_requested.connect(_on_row_tooltip_requested)
        row.tooltip_dismissed.connect(_on_row_tooltip_dismissed)

        _row_container.add_child(row)
        _rows[entry] = row

    apply_sort()


func get_row(entry: ItemEntry) -> ItemRow:
    return _rows.get(entry, null)


func get_all_rows() -> Dictionary:
    return _rows


func clear() -> void:
    for child in _row_container.get_children():
        child.queue_free()
    _rows.clear()


func refresh_row(entry: ItemEntry) -> void:
    if _rows.has(entry):
        _rows[entry].refresh()


# Public wrapper — call after changing ctx.price_mode to update PRICE header.
func rebuild_header() -> void:
    _build_header()

# ══ Sorting ═══════════════════════════════════════════════════════════════════


func apply_sort() -> void:
    if _rows.is_empty():
        return

    var entries: Array = _rows.keys()
    var col: ItemRow.Column = _sort_column
    var ctx: ItemViewContext = _ctx
    var ascending: bool = _sort_ascending

    entries.sort_custom(
        func(a: ItemEntry, b: ItemEntry) -> bool:
            var va: Variant = get_sort_value(a, col, ctx)
            var vb: Variant = get_sort_value(b, col, ctx)
            if ascending:
                return va < vb
            return va > vb
    )

    for i in range(entries.size()):
        var row: ItemRow = _rows[entries[i]]
        _row_container.move_child(row, i)


static func get_sort_value(entry: ItemEntry, col: ItemRow.Column, ctx: ItemViewContext) -> Variant:
    match col:
        ItemRow.Column.NAME:
            return entry.display_name
        ItemRow.Column.CONDITION:
            return entry.condition
        ItemRow.Column.PRICE:
            return entry.price_value_for(ctx)
        ItemRow.Column.POTENTIAL:
            return 0 if entry.is_veiled() else entry.potential_price_max
        ItemRow.Column.WEIGHT:
            if entry.item_data == null or entry.item_data.category_data == null:
                return 0.0
            return entry.item_data.category_data.weight
        ItemRow.Column.GRID:
            if entry.item_data == null or entry.item_data.category_data == null:
                return 0
            return entry.item_data.category_data.get_cells().size()
        ItemRow.Column.MARKET_FACTOR:
            return entry.market_factor_delta
        _:
            push_warning("Unknown Column: %d" % col)
            return 0

# ══ Header ════════════════════════════════════════════════════════════════════


func _build_header() -> void:
    for child in _column_header.get_children():
        child.queue_free()

    for col: ItemRow.Column in _columns:
        var btn := Button.new()
        btn.flat = true
        btn.focus_mode = Control.FOCUS_NONE
        btn.add_theme_font_size_override(&"font_size", 14)
        btn.add_theme_color_override(&"font_color", Color(0.7, 0.7, 0.7, 1))

        var label_text: String
        if col == ItemRow.Column.PRICE:
            label_text = ItemRow.get_price_header(_ctx)
        elif col == ItemRow.Column.MARKET_FACTOR:
            label_text = ItemRow.COLUMN_HEADERS[col]
        else:
            label_text = ItemRow.COLUMN_HEADERS[col]

        if col == _sort_column:
            label_text += " ▲" if _sort_ascending else " ▼"

        btn.text = label_text

        if col == ItemRow.Column.NAME:
            btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
        else:
            btn.custom_minimum_size = Vector2(ItemRow.COLUMN_MIN_WIDTH[col], 0)
            btn.alignment = HORIZONTAL_ALIGNMENT_CENTER

        var captured_col: ItemRow.Column = col
        btn.pressed.connect(func() -> void: _on_header_pressed(captured_col))

        _column_header.add_child(btn)


func _on_header_pressed(column: ItemRow.Column) -> void:
    if column == _sort_column:
        _sort_ascending = not _sort_ascending
    else:
        _sort_column = column
        _sort_ascending = true

    _build_header()
    apply_sort()

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_row_pressed(entry: ItemEntry) -> void:
    row_pressed.emit(entry)


func _on_row_tooltip_requested(
        entry: ItemEntry,
        ctx: ItemViewContext,
        anchor: Rect2,
) -> void:
    tooltip_requested.emit(entry, ctx, anchor)


func _on_row_tooltip_dismissed() -> void:
    tooltip_dismissed.emit()
