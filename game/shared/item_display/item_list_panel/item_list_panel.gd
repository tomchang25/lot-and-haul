# item_list_panel.gd
# Reusable header + scrollable rows panel for displaying lot objects.
# Consumers choose which columns to show via the columns array passed to setup().
# Header buttons are built at runtime (count depends on columns) and support
# click-to-sort with an ascending/descending toggle per column.
class_name ItemListPanel
extends PanelContainer

signal row_pressed(entry)
signal tooltip_requested(entry, anchor: Rect2)
signal tooltip_dismissed

# ── Constants ─────────────────────────────────────────────────────────────────

const ItemRowScene: PackedScene = preload("uid://brx8agwvlpi3f")
const ColumnHeaderButtonScene := preload("res://game/shared/item_display/item_list_panel/column_header_button/column_header_button.tscn")

# ── State ─────────────────────────────────────────────────────────────────────

var _columns: Array = [] # Array of ItemRow.Column
var _sort_column: ItemRow.Column = ItemRow.Column.NAME
var _sort_ascending: bool = true
var _rows: Dictionary = { } # lot object -> ItemRow

# ── Node references ───────────────────────────────────────────────────────────

@onready var _column_header: HBoxContainer = $PanelVBox/ColumnHeader
@onready var _row_container: VBoxContainer = $PanelVBox/ScrollContainer/RowContainer

# ══ Common API ════════════════════════════════════════════════════════════════


func setup(
        columns: Array,
        default_sort_column: ItemRow.Column = ItemRow.Column.NAME,
        default_ascending: bool = true,
) -> void:
    _columns = columns
    if _columns.size() > 0 and not (_sort_column in _columns):
        _sort_column = default_sort_column if default_sort_column in _columns else _columns[0]
    _sort_ascending = default_ascending
    if is_node_ready():
        _build_header()


func populate(entries: Array) -> void:
    clear()

    for entry in entries:
        var row: ItemRow = ItemRowScene.instantiate()
        row.setup(entry, _columns)
        row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

        row.row_pressed.connect(_on_row_pressed)
        row.tooltip_requested.connect(_on_row_tooltip_requested)
        row.tooltip_dismissed.connect(_on_row_tooltip_dismissed)

        _row_container.add_child(row)
        _rows[entry] = row

    apply_sort()


func get_row(entry) -> ItemRow:
    return _rows.get(entry, null)


func get_all_rows() -> Dictionary:
    return _rows


func clear() -> void:
    for child in _row_container.get_children():
        child.queue_free()
    _rows.clear()


func refresh_row(entry) -> void:
    if _rows.has(entry):
        _rows[entry].refresh()


# Public wrapper — rebuilds all column header buttons.
func rebuild_header() -> void:
    _build_header()

# ══ Sorting ═══════════════════════════════════════════════════════════════════


func apply_sort() -> void:
    if _rows.is_empty():
        return

    var entries: Array = _rows.keys()
    var col: ItemRow.Column = _sort_column
    var ascending: bool = _sort_ascending

    entries.sort_custom(
        func(a, b) -> bool:
            var va: Variant = get_sort_value(a, col)
            var vb: Variant = get_sort_value(b, col)
            if ascending:
                return va < vb
            return va > vb
    )

    for i in range(entries.size()):
        var row: ItemRow = _rows[entries[i]]
        _row_container.move_child(row, i)


static func get_sort_value(entry: ItemEntry, col: ItemRow.Column) -> Variant:
    if entry == null:
        return 0
    return entry.sort_value(col)

# ══ Header ════════════════════════════════════════════════════════════════════


func _build_header() -> void:
    for child in _column_header.get_children():
        child.queue_free()

    for col: ItemRow.Column in _columns:
        var btn: ColumnHeaderButton = ColumnHeaderButtonScene.instantiate()
        btn.setup(
            col,
            ItemRow.COLUMN_HEADERS[col],
            col == _sort_column,
            _sort_ascending,
            col == ItemRow.Column.NAME,
            ItemRow.COLUMN_MIN_WIDTH[col],
        )
        btn.header_pressed.connect(_on_header_pressed)
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


func _on_row_pressed(entry) -> void:
    row_pressed.emit(entry)


func _on_row_tooltip_requested(
        entry,
        anchor: Rect2,
) -> void:
    tooltip_requested.emit(entry, anchor)


func _on_row_tooltip_dismissed() -> void:
    tooltip_dismissed.emit()
