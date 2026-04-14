# item_row.gd
# Generalised item row used by list_review, reveal, run_review, storage,
# and pawn_shop.
# Column visibility is driven by the columns array passed to setup().
# Hover: emits tooltip_requested for the parent scene to position and show.
class_name ItemRow
extends PanelContainer

signal tooltip_requested(entry: ItemEntry, ctx: ItemViewContext, anchor: Rect2)
signal tooltip_dismissed
signal row_pressed(entry: ItemEntry)

enum SelectionState {
    NONE, # no override applied
    SELECTED, # selected → white
    AVAILABLE, # can still be toggled → grey
    BLOCKED, # would exceed capacity → near-black
}

enum Column {
    NAME,
    CONDITION,
    PRICE,
    POTENTIAL,
    WEIGHT,
    GRID,
    MARKET_FACTOR,
}

# Header text shown for each column. PRICE is dynamic — see get_price_header().
const COLUMN_HEADERS: Dictionary = {
    Column.NAME: "Item",
    Column.CONDITION: "Condition",
    Column.PRICE: "",
    Column.POTENTIAL: "Potential",
    Column.WEIGHT: "Weight",
    Column.GRID: "Grid",
    Column.MARKET_FACTOR: "Market",
}

const COLUMN_MIN_WIDTH: Dictionary = {
    Column.NAME: 0,
    Column.CONDITION: 120,
    Column.PRICE: 160,
    Column.POTENTIAL: 160,
    Column.WEIGHT: 100,
    Column.GRID: 80,
    Column.MARKET_FACTOR: 100,
}


static func get_price_header(ctx: ItemViewContext) -> String:
    match ctx.price_mode:
        ItemViewContext.PriceMode.ESTIMATED_VALUE:
            return "Est. Value"
        ItemViewContext.PriceMode.APPRAISED_VALUE:
            return "Appraised Value"
        ItemViewContext.PriceMode.BASE_VALUE:
            return "Base Value"
        _:
            push_warning("Unknown PriceMode: %d" % ctx.price_mode)
            return "Price"

# ── State ─────────────────────────────────────────────────────────────────────

var _entry: ItemEntry = null
var _ctx: ItemViewContext = null
var _columns: Array = []
var _provider: RowDataProvider = null
var _selection_state: SelectionState = SelectionState.NONE

# Built once on demand and reused across all rows.
static var _style_selected: StyleBoxFlat = null
static var _style_available: StyleBoxFlat = null
static var _style_blocked: StyleBoxFlat = null


static func _ensure_styles() -> void:
    if _style_selected != null:
        return

    _style_selected = StyleBoxFlat.new()
    _style_selected.bg_color = Color(1.0, 1.0, 1.0, 0.15) # white tint

    _style_available = StyleBoxFlat.new()
    _style_available.bg_color = Color(0.5, 0.5, 0.5, 0.15) # grey tint

    _style_blocked = StyleBoxFlat.new()
    _style_blocked.bg_color = Color(0.08, 0.08, 0.08, 0.9) # near-black

# ── Node references ───────────────────────────────────────────────────────────

@onready var _name_label: Label = $HBoxContainer/NameLabel
@onready var _condition_label: Label = $HBoxContainer/ConditionLabel
@onready var _price_label: Label = $HBoxContainer/PriceLabel
@onready var _potential_label: Label = $HBoxContainer/PotentialLabel
@onready var _weight_label: Label = $HBoxContainer/WeightLabel
@onready var _grid_label: Label = $HBoxContainer/GridLabel
@onready var _market_factor_label: Label = $HBoxContainer/MarketFactorLabel

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)

    _refresh()

# ══ Common API ════════════════════════════════════════════════════════════════


func setup(entry: ItemEntry, ctx: ItemViewContext, columns: Array = []) -> void:
    _entry = entry
    _ctx = ctx
    _columns = columns

    if is_node_ready():
        _refresh()


func refresh() -> void:
    _refresh()


func set_provider(provider: RowDataProvider) -> void:
    _provider = provider


# Called by consuming scenes to apply row selection styling.
# Applies background colour and enables/disables click handling.
func set_selection_state(state: SelectionState) -> void:
    _selection_state = state
    _ensure_styles()

    match state:
        SelectionState.SELECTED:
            add_theme_stylebox_override(&"panel", _style_selected)
            mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        SelectionState.AVAILABLE:
            add_theme_stylebox_override(&"panel", _style_available)
            mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        SelectionState.BLOCKED:
            add_theme_stylebox_override(&"panel", _style_blocked)
            mouse_default_cursor_shape = Control.CURSOR_ARROW
        SelectionState.NONE:
            remove_theme_stylebox_override(&"panel")
            mouse_default_cursor_shape = Control.CURSOR_ARROW

# ══ Input ═════════════════════════════════════════════════════════════════════


func _gui_input(event: InputEvent) -> void:
    if _selection_state == SelectionState.NONE or _selection_state == SelectionState.BLOCKED:
        return
    if event is InputEventMouseButton \
    and event.button_index == MOUSE_BUTTON_LEFT \
    and event.pressed:
        row_pressed.emit(_entry)
        accept_event()

# ══ Refresh ═══════════════════════════════════════════════════════════════════


func _refresh() -> void:
    if _entry == null:
        return

    # ── Column visibility ─────────────────────────────────────────────────────
    _name_label.visible = Column.NAME in _columns
    _condition_label.visible = Column.CONDITION in _columns
    _price_label.visible = Column.PRICE in _columns
    _potential_label.visible = Column.POTENTIAL in _columns
    _weight_label.visible = Column.WEIGHT in _columns
    _grid_label.visible = Column.GRID in _columns
    _market_factor_label.visible = Column.MARKET_FACTOR in _columns

    # ── NAME ──────────────────────────────────────────────────────────────────
    _name_label.text = _entry.display_name

    # ── CONDITION ─────────────────────────────────────────────────────────────
    _condition_label.text = _entry.condition_label_for(_ctx)
    _condition_label.modulate = _entry.condition_color_for(_ctx)

    # ── PRICE ─────────────────────────────────────────────────────────────────
    if _provider != null:
        _price_label.text = _provider.price_label_for(_entry)
    else:
        _price_label.text = _entry.price_label_for(_ctx)
    _price_label.add_theme_color_override(&"font_color", _entry.price_color)

    # ── POTENTIAL ─────────────────────────────────────────────────────────────
    _potential_label.text = _entry.potential_price_label if not _entry.is_veiled() else "???"
    _potential_label.add_theme_color_override(&"font_color", _entry.price_color)

    # ── WEIGHT / GRID ─────────────────────────────────────────────────────────
    if _entry.item_data != null and _entry.item_data.category_data != null:
        var cat := _entry.item_data.category_data
        _weight_label.text = "%.1f kg" % cat.weight
        _grid_label.text = "%d  %s" % [cat.get_cells().size(), cat.shape_id]

    # ── MARKET FACTOR ─────────────────────────────────────────────────────────
    if _provider != null:
        _market_factor_label.text = _provider.market_factor_label_for(_entry)
    else:
        _market_factor_label.text = "0%"

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_mouse_entered() -> void:
    tooltip_requested.emit(_entry, _ctx, get_global_rect())


func _on_mouse_exited() -> void:
    tooltip_dismissed.emit()
