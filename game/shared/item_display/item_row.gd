# item_row.gd
# Generalised item row used by list_review, reveal, run_review, storage,
# and pawn_shop.
# Column visibility and order are driven by the columns array passed to setup().
# Hover: emits tooltip_requested for the parent scene to position and show.
class_name ItemRow
extends PanelContainer

signal tooltip_requested(entry: ItemEntry, ctx: ItemViewContext, anchor: Rect2)
signal tooltip_dismissed
signal row_pressed(entry: ItemEntry)

# ── Enums ─────────────────────────────────────────────────────────────────────

enum SelectionState {
    NONE, # no override applied
    SELECTED, # selected → white
    AVAILABLE, # can still be toggled → grey
    BLOCKED, # would exceed capacity → near-black
}

enum Column {
    NAME,
    CONDITION,
    ESTIMATED_VALUE,
    APPRAISED_VALUE,
    BASE_VALUE,
    MERCHANT_OFFER,
    SPECIAL_ORDER,
    RARITY,
    WEIGHT,
    GRID,
    MARKET_FACTOR,
}

# ── Constants ─────────────────────────────────────────────────────────────────

# Header text shown for each column. MERCHANT_OFFER is dynamic — see _build_header().
const COLUMN_HEADERS: Dictionary = {
    Column.NAME: "Item",
    Column.CONDITION: "Condition",
    Column.ESTIMATED_VALUE: "Est. Value",
    Column.APPRAISED_VALUE: "Appraised Value",
    Column.BASE_VALUE: "Base Value",
    Column.MERCHANT_OFFER: "",
    Column.SPECIAL_ORDER: "Order Price",
    Column.RARITY: "Rarity",
    Column.WEIGHT: "Weight",
    Column.GRID: "Grid",
    Column.MARKET_FACTOR: "Market",
}

const COLUMN_MIN_WIDTH: Dictionary = {
    Column.NAME: 0,
    Column.CONDITION: 120,
    Column.ESTIMATED_VALUE: 160,
    Column.APPRAISED_VALUE: 160,
    Column.BASE_VALUE: 160,
    Column.MERCHANT_OFFER: 160,
    Column.SPECIAL_ORDER: 160,
    Column.RARITY: 120,
    Column.WEIGHT: 100,
    Column.GRID: 80,
    Column.MARKET_FACTOR: 100,
}

# ── State ─────────────────────────────────────────────────────────────────────

var _entry: ItemEntry = null
var _ctx: ItemViewContext = null
var _columns: Array = []
var _selection_state: SelectionState = SelectionState.NONE

# ── Node references ───────────────────────────────────────────────────────────

@onready var _h_box_container: HBoxContainer = $HBoxContainer
@onready var _name_label: Label = $HBoxContainer/NameLabel
@onready var _condition_label: Label = $HBoxContainer/ConditionLabel
@onready var _estimated_value_label: Label = $HBoxContainer/EstimatedValueLabel
@onready var _appraised_value_label: Label = $HBoxContainer/AppraisedValueLabel
@onready var _base_value_label: Label = $HBoxContainer/BaseValueLabel
@onready var _merchant_offer_label: Label = $HBoxContainer/MerchantOfferLabel
@onready var _special_order_label: Label = $HBoxContainer/SpecialOrderLabel
@onready var _rarity_label: Label = $HBoxContainer/RarityLabel
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
        _:
            push_warning("Unknown SelectionState: %d" % state)


# Bridge method — kept for ItemRowTooltip which dispatches on stage.
static func get_price_header(ctx: ItemViewContext) -> String:
    match ctx.stage:
        ItemViewContext.Stage.INSPECTION, \
        ItemViewContext.Stage.LIST_REVIEW, \
        ItemViewContext.Stage.REVEAL, \
        ItemViewContext.Stage.CARGO:
            return "Est. Value"
        ItemViewContext.Stage.RUN_REVIEW, \
        ItemViewContext.Stage.STORAGE:
            return "Appraised Value"
        ItemViewContext.Stage.MERCHANT_SHOP:
            return "%s Offer" % ctx.merchant.display_name if ctx.merchant else "Offer"
        ItemViewContext.Stage.FULFILLMENT_PANEL:
            return "Order Price"
        _:
            push_warning("Unknown Stage for price header: %d" % ctx.stage)
            return "Price"

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
    _estimated_value_label.visible = Column.ESTIMATED_VALUE in _columns
    _appraised_value_label.visible = Column.APPRAISED_VALUE in _columns
    _base_value_label.visible = Column.BASE_VALUE in _columns
    _merchant_offer_label.visible = Column.MERCHANT_OFFER in _columns
    _special_order_label.visible = Column.SPECIAL_ORDER in _columns
    _rarity_label.visible = Column.RARITY in _columns
    _weight_label.visible = Column.WEIGHT in _columns
    _grid_label.visible = Column.GRID in _columns
    _market_factor_label.visible = Column.MARKET_FACTOR in _columns

    # ── Column order ──────────────────────────────────────────────────────────
    _apply_column_order()

    # ── NAME ──────────────────────────────────────────────────────────────────
    _name_label.text = _entry.display_name

    # ── CONDITION ─────────────────────────────────────────────────────────────
    _condition_label.text = _entry.condition_label_for(_ctx)
    _condition_label.modulate = _entry.condition_color_for(_ctx)

    # ── ESTIMATED_VALUE ────────────────────────────────────────────────────────
    _estimated_value_label.text = _entry.estimated_value_label
    _estimated_value_label.add_theme_color_override(&"font_color", _entry.price_color)

    # ── APPRAISED_VALUE ────────────────────────────────────────────────────────
    _appraised_value_label.text = _entry.appraised_value_label
    _appraised_value_label.add_theme_color_override(&"font_color", _entry.price_color)

    # ── BASE_VALUE ─────────────────────────────────────────────────────────────
    _base_value_label.text = _entry.base_value_label_text()
    _base_value_label.add_theme_color_override(&"font_color", _entry.price_color)

    # ── MERCHANT_OFFER ─────────────────────────────────────────────────────────
    _merchant_offer_label.text = _entry.merchant_offer_label(_ctx.merchant)
    _merchant_offer_label.add_theme_color_override(&"font_color", _entry.price_color)

    # ── SPECIAL_ORDER ──────────────────────────────────────────────────────────
    _special_order_label.text = _entry.special_order_label(_ctx.order)
    _special_order_label.add_theme_color_override(&"font_color", _entry.price_color)

    # ── RARITY ────────────────────────────────────────────────────────────────
    _rarity_label.text = "???" if _entry.is_veiled() else _entry.get_potential_rating()

    # ── WEIGHT / GRID ─────────────────────────────────────────────────────────
    if _entry.item_data != null and _entry.item_data.category_data != null:
        var category: CategoryData = _entry.item_data.category_data
        _weight_label.text = "%.1f kg" % category.weight
        _grid_label.text = "%d  %s" % [category.get_cells().size(), category.shape_id]

    # ── MARKET FACTOR ─────────────────────────────────────────────────────────
    _market_factor_label.text = "%+d%%" % int(round(_entry.market_factor_delta * 100))

# ══ Column ordering ═══════════════════════════════════════════════════════════


func _apply_column_order() -> void:
    if _columns.is_empty() or not is_node_ready():
        return

    var column_to_label: Dictionary = {
        Column.NAME: _name_label,
        Column.CONDITION: _condition_label,
        Column.ESTIMATED_VALUE: _estimated_value_label,
        Column.APPRAISED_VALUE: _appraised_value_label,
        Column.BASE_VALUE: _base_value_label,
        Column.MERCHANT_OFFER: _merchant_offer_label,
        Column.SPECIAL_ORDER: _special_order_label,
        Column.RARITY: _rarity_label,
        Column.WEIGHT: _weight_label,
        Column.GRID: _grid_label,
        Column.MARKET_FACTOR: _market_factor_label,
    }

    for i in _columns.size():
        var col: Column = _columns[i]
        if column_to_label.has(col):
            _h_box_container.move_child(column_to_label[col], i)

# ══ Selection styles ══════════════════════════════════════════════════════════

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

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_mouse_entered() -> void:
    tooltip_requested.emit(_entry, _ctx, get_global_rect())


func _on_mouse_exited() -> void:
    tooltip_dismissed.emit()
