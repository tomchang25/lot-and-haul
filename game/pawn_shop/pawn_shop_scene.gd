# pawn_shop_scene.gd
# Pawn Shop — Sell selected storage items to the merchant.
# Reads:  SaveManager.storage_items, SaveManager.cash
# Writes: SaveManager.storage_items, SaveManager.cash
extends Control

const ItemRowScene: PackedScene = preload("uid://brx8agwvlpi3f")
const ItemRowTooltipScene: PackedScene = preload("uid://3kvnpn7pek5i")

const ASK_PRICE_MIN_FACTOR := 0.50
const ASK_PRICE_MAX_FACTOR := 1.50

# ── State ─────────────────────────────────────────────────────────────────────

var _ctx: ItemViewContext = null
var _tooltip: ItemRowTooltip = null
var _selected: Dictionary = {}      # ItemEntry → bool
var _ask_prices: Dictionary = {}    # ItemEntry → int
var _price_labels: Dictionary = {}  # ItemEntry → Label
var _price_rows: Dictionary = {}    # ItemEntry → Control (the slider row)
var _rows: Dictionary = {}          # ItemEntry → ItemRow

# ── Node references ───────────────────────────────────────────────────────────

@onready var _row_container: VBoxContainer = $RootVBox/ListCenter/OuterVBox/ItemPanel/PanelVBox/ScrollContainer/RowContainer
@onready var _sell_btn: Button = $RootVBox/Footer/SellButton
@onready var _back_btn: Button = $RootVBox/Footer/BackButton
@onready var _empty_label: Label = $RootVBox/ListCenter/OuterVBox/EmptyLabel
@onready var _sell_confirm: ConfirmationDialog = $SellConfirm

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
	_ctx = ItemViewContext.for_run_review()
	_tooltip = ItemRowTooltipScene.instantiate()
	add_child(_tooltip)

	_back_btn.pressed.connect(_on_back_pressed)
	_sell_btn.pressed.connect(_on_sell_pressed)
	_sell_confirm.confirmed.connect(_on_sell_confirmed)

	_populate_rows()
	_refresh_sell_button()

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_back_pressed() -> void:
	GameManager.go_to_hub()


func _on_row_pressed(entry: ItemEntry) -> void:
	_selected[entry] = not _selected.get(entry, false)
	_refresh_row_state(entry)
	_refresh_sell_button()


func _on_row_tooltip_requested(
		entry: ItemEntry,
		ctx: ItemViewContext,
		anchor: Rect2,
) -> void:
	_tooltip.show_for(entry, ctx, anchor)


func _on_sell_pressed() -> void:
	_sell_confirm.dialog_text = _build_sell_summary()
	_sell_confirm.popup_centered()


func _on_sell_confirmed() -> void:
	var total: int = 0
	var sold: Array[ItemEntry] = []
	for entry: ItemEntry in SaveManager.storage_items:
		if _selected.get(entry, false):
			total += _ask_prices.get(entry, entry.sell_price)
			sold.append(entry)

	SaveManager.cash += total
	for entry: ItemEntry in sold:
		SaveManager.storage_items.erase(entry)
	SaveManager.save()

	_rebuild_after_sale()


func _on_slider_changed(entry: ItemEntry, normalized: float) -> void:
	# normalized ∈ [0,1] → factor ∈ [50%, 150%]
	var factor: float = lerp(ASK_PRICE_MIN_FACTOR, ASK_PRICE_MAX_FACTOR, normalized)
	var ask: int = int(entry.sell_price * factor)
	_ask_prices[entry] = ask
	if _price_labels.has(entry):
		_price_labels[entry].text = "$%d" % ask

# ══ Rows ══════════════════════════════════════════════════════════════════════


func _populate_rows() -> void:
	if SaveManager.storage_items.is_empty():
		_empty_label.visible = true
		_sell_btn.disabled = true
		return
	_empty_label.visible = false

	for entry: ItemEntry in SaveManager.storage_items:
		_selected[entry] = false
		_ask_prices[entry] = entry.sell_price

		var row: ItemRow = ItemRowScene.instantiate()
		row.setup(entry, _ctx)
		row.set_cargo_state(ItemRow.CargoState.AVAILABLE)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		row.row_pressed.connect(_on_row_pressed)
		row.tooltip_requested.connect(_on_row_tooltip_requested)
		row.tooltip_dismissed.connect(_tooltip.hide_tooltip)

		_rows[entry] = row

		var price_row: HBoxContainer = _make_price_row(entry)
		_price_rows[entry] = price_row

		var wrapper := VBoxContainer.new()
		wrapper.theme_override_constants/separation = 0
		wrapper.add_child(row)
		wrapper.add_child(price_row)
		_row_container.add_child(wrapper)


func _refresh_row_state(entry: ItemEntry) -> void:
	var sel: bool = _selected.get(entry, false)
	if _rows.has(entry):
		_rows[entry].set_cargo_state(
			ItemRow.CargoState.SELECTED if sel else ItemRow.CargoState.AVAILABLE
		)
	if _price_rows.has(entry):
		_price_rows[entry].visible = sel


func _rebuild_after_sale() -> void:
	_selected.clear()
	_ask_prices.clear()
	_price_labels.clear()
	_price_rows.clear()
	_rows.clear()

	for child in _row_container.get_children():
		child.queue_free()

	_populate_rows()
	_refresh_sell_button()

# ══ UI state ══════════════════════════════════════════════════════════════════


func _refresh_sell_button() -> void:
	var any_selected: bool = false
	for entry: ItemEntry in SaveManager.storage_items:
		if _selected.get(entry, false):
			any_selected = true
			break
	_sell_btn.disabled = not any_selected


func _build_sell_summary() -> String:
	var lines: Array[String] = []
	var total: int = 0
	for entry: ItemEntry in SaveManager.storage_items:
		if _selected.get(entry, false):
			var ask: int = _ask_prices.get(entry, entry.sell_price)
			total += ask
			lines.append("  %s — $%d" % [entry.display_name, ask])
	lines.append("")
	lines.append("Total:  $%d" % total)
	return "\n".join(lines)

# ══ UI builder ════════════════════════════════════════════════════════════════


func _make_price_row(entry: ItemEntry) -> HBoxContainer:
	var price_row := HBoxContainer.new()
	price_row.visible = false
	price_row.theme_override_constants/separation = 12

	var ask_lbl := Label.new()
	ask_lbl.text = "Ask: "
	ask_lbl.theme_override_font_sizes/font_size = 14
	price_row.add_child(ask_lbl)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = 0.5  # 100% → midpoint of [50%, 150%] → 0.5 in [0,1]
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(200, 0)
	price_row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.custom_minimum_size = Vector2(100, 0)
	val_lbl.theme_override_font_sizes/font_size = 14
	val_lbl.text = "$%d" % entry.sell_price
	price_row.add_child(val_lbl)

	_price_labels[entry] = val_lbl

	var captured_entry: ItemEntry = entry
	slider.value_changed.connect(func(v: float) -> void:
		_on_slider_changed(captured_entry, v)
	)

	return price_row
