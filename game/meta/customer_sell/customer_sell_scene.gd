# customer_sell_scene.gd
# Phase 9 nightly customer sell scene — tag matching, car packing, sell strategy.
# Reads:  MetaManager.customers.nightly_customers, MetaManager.storage.storage_items
# Writes: MetaManager.resolve_customer_sale()
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────

const SALE_COMPLETED: UiAudioEvent = preload("res://data/tres/audio_events/sale_completed.tres")
const CASH_CREDITED: UiAudioEvent = preload("res://data/tres/audio_events/cash_credited.tres")
const CONFIRM: UiAudioEvent = preload("res://data/tres/audio_events/confirm.tres")
const CANCEL: UiAudioEvent = preload("res://data/tres/audio_events/cancel_dismiss.tres")
const BLOCKED_ERROR: UiAudioEvent = preload("res://data/tres/audio_events/blocked_error.tres")
const SELL_GRID_LIFT: UiAudioEvent = preload("res://data/tres/audio_events/sell_grid_lift.tres")
const SELL_GRID_PUT_DOWN: UiAudioEvent = preload("res://data/tres/audio_events/sell_grid_put_down.tres")

const CargoItemRowScene: PackedScene = preload("res://game/run/cargo/cargo_item_row.tscn")

const MAX_SELECTED_DICE := 2
const STRATEGY_CONSERVATIVE := "conservative"
const STRATEGY_AGGRESSIVE := "aggressive"

# ── State ─────────────────────────────────────────────────────────────────────

var _customers: Array[CustomerEntry] = []
var _selected_index: int = -1
var _item_rows: Dictionary = { }
var _dice_rolls: Array[int] = []
var _selected_dice_indices: Array[int] = []
var _dice_buttons: Array[Button] = []
var _pending_sale_price: int = 0
var _pending_strategy: String = ""
var _hovered_entry: ItemEntry = null

# ── Node references ───────────────────────────────────────────────────────────

@onready var _grid: PackingGrid = %CustomerGrid
@onready var _day_label: Label = %DayLabel
@onready var _back_button: SfxButton = %BackButton
@onready var _customer_tabs_row: HBoxContainer = %CustomerTabsRow
@onready var _main_area: HBoxContainer = %MainArea
@onready var _item_list_vbox: VBoxContainer = %ItemListVBox
@onready var _customer_name_label: Label = %CustomerNameLabel
@onready var _grid_size_label: Label = %GridSizeLabel
@onready var _demand_tags_label: Label = %DemandTagsLabel
@onready var _car_total_label: Label = %CarTotalLabel
@onready var _verified_count_label: Label = %VerifiedCountLabel
@onready var _empty_label: Label = %EmptyLabel
@onready var _sell_result_popup: ConfirmationDialog = %SellResultPopup
@onready var _tooltip: ItemCardPopup = %TooltipPopup
@onready var _car_clear_button: SfxButton = %CarClearButton
@onready var _conservative_button: SfxButton = %ConservativeButton
@onready var _aggressive_button: SfxButton = %AggressiveButton
@onready var _dice_section: VBoxContainer = %DiceSection
@onready var _dice_hint_label: Label = %DiceHint
@onready var _dice_row: HBoxContainer = %DiceRow
@onready var _dice_sum_label: Label = %DiceSumLabel
@onready var _dice_total_label: Label = %DiceTotalLabel
@onready var _confirm_dice_button: SfxButton = %ConfirmDiceButton
@onready var _cancel_dice_button: SfxButton = %CancelDiceButton

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _back_button.pressed.connect(_on_back_pressed)
    _sell_result_popup.confirmed.connect(_on_sell_confirmed)
    _sell_result_popup.canceled.connect(_on_sell_cancelled)
    _car_clear_button.pressed.connect(_on_clear_car_pressed)
    _conservative_button.pressed.connect(_on_conservative_pressed)
    _aggressive_button.pressed.connect(_on_aggressive_pressed)
    _confirm_dice_button.pressed.connect(_on_confirm_dice_pressed)
    _cancel_dice_button.pressed.connect(_on_cancel_dice_pressed)

    _grid.item_clicked.connect(_on_grid_item_clicked)
    _grid.cell_clicked.connect(_on_grid_cell_clicked)
    _grid.placement_changed.connect(_refresh_display)
    _grid.hover_started.connect(_on_grid_hover_started)
    _grid.hover_ended.connect(_on_grid_hover_ended)

    _back_button.press_event = CANCEL
    _conservative_button.text = "Sell Conservative (×%.1f)" % SellMath.CONSERVATIVE_MULTIPLIER
    _customers = MetaManager.customers.nightly_customers.duplicate()

    if _customers.is_empty():
        _show_empty_state("No customers tonight.")
        return

    _day_label.text = "Day %d" % MetaManager.progress.current_day
    _build_customer_tabs()
    _select_customer(0)

# ══ Signal handlers ═══════════════════════════════════════════════════════════


func _on_item_row_pressed(entry: ItemEntry) -> void:
    if entry == null:
        ToastManager.show_dev_error("CustomerSellScene._on_item_row_pressed: entry is null")
        return
    if _grid.phase == PackingGrid.Phase.ITEM_HELD:
        _grid.cancel_placement()
        _update_item_row_states()
        return
    if _grid.is_item_placed(entry):
        _grid.lift(entry)
    else:
        _grid.set_held_item(entry, _grid.item_rotations.get(entry, 0))
    AudioManager.play_event(SELL_GRID_LIFT)
    _update_item_row_states()


## Hovering a list row lights up that item's cells in the grid (the mirror of
## _on_grid_hover_started, which lights up the row when the grid is hovered).
## Also shows the shared item-card popup so the player can inspect item details.
func _on_item_row_hovered(entry: ItemEntry, anchor: Rect2) -> void:
    if entry == null:
        ToastManager.show_dev_error("CustomerSellScene._on_item_row_hovered: entry is null")
        return
    _grid.set_external_hover_item(entry)
    _tooltip.show_for(entry, anchor)


func _on_item_row_hover_ended() -> void:
    _grid.set_external_hover_item(null)
    _tooltip.hide_popup()


func _on_grid_hover_started(cell_pos: Vector2i) -> void:
    if _grid.phase == PackingGrid.Phase.ITEM_HELD:
        return
    var new_entry: ItemEntry = _grid.placement.get(cell_pos) as ItemEntry
    if new_entry == _hovered_entry:
        return
    _set_row_external_highlight(_hovered_entry, false)
    _hovered_entry = new_entry
    _set_row_external_highlight(_hovered_entry, true)
    if _hovered_entry != null:
        _tooltip.show_for(_hovered_entry, _grid.get_global_rect())


func _on_grid_hover_ended() -> void:
    _set_row_external_highlight(_hovered_entry, false)
    _hovered_entry = null
    _tooltip.hide_popup()


func _on_grid_item_clicked(item) -> void:
    var entry := item as ItemEntry
    if entry == null:
        ToastManager.show_dev_error("CustomerSellScene._on_grid_item_clicked: item is not ItemEntry")
        return
    _grid.lift(entry)
    AudioManager.play_event(SELL_GRID_LIFT)
    _refresh_display()


func _on_grid_cell_clicked(pos: Vector2i) -> void:
    if _grid.active_item == null:
        return
    if not _grid.can_place(_grid.active_item, pos):
        AudioManager.play_event(BLOCKED_ERROR)
        return
    _grid.place(_grid.active_item, pos)
    AudioManager.play_event(SELL_GRID_PUT_DOWN)
    _update_item_row_states()


func _on_clear_car_pressed() -> void:
    _grid.reset()
    _refresh_display()


func _on_conservative_pressed() -> void:
    var placed := _get_placed_items()
    if placed.is_empty():
        AudioManager.play_event(CANCEL)
        return
    var price := SellMath.conservative_total(placed)
    _pending_sale_price = price
    _pending_strategy = STRATEGY_CONSERVATIVE
    _tooltip.hide_popup()
    _sell_result_popup.dialog_text = _build_result_text(placed, price, STRATEGY_CONSERVATIVE)
    _sell_result_popup.popup_centered()


func _on_aggressive_pressed() -> void:
    var customer := _get_selected_customer()
    if customer == null:
        return
    var placed := _get_placed_items()
    if placed.is_empty():
        AudioManager.play_event(CANCEL)
        return

    var pool := _get_dice_pool_size(customer, placed)
    var rolls := SellMath.roll_dice(pool)
    if rolls.size() < MAX_SELECTED_DICE:
        ToastManager.show_dev_error(
            "CustomerSellScene._on_aggressive_pressed: expected at least %d dice, got %d" % [MAX_SELECTED_DICE, rolls.size()],
        )
        return

    _reset_dice_selection()
    for index: int in rolls.size():
        _add_dice_button(index, rolls[index])

    _dice_hint_label.text = "Select %d dice to keep" % MAX_SELECTED_DICE
    _dice_sum_label.text = "Sum: —"
    _dice_total_label.text = "Total: —"
    _confirm_dice_button.disabled = true
    _dice_section.visible = true


func _on_dice_toggled(index: int, toggled: bool) -> void:
    if index < 0 or index >= _dice_rolls.size() or index >= _dice_buttons.size():
        ToastManager.show_dev_error("CustomerSellScene._on_dice_toggled: invalid dice index %d" % index)
        return

    if toggled:
        if _selected_dice_indices.size() >= MAX_SELECTED_DICE:
            _dice_buttons[index].button_pressed = false
            return
        _selected_dice_indices.append(index)
    else:
        _selected_dice_indices.erase(index)

    _refresh_dice_totals()


func _on_confirm_dice_pressed() -> void:
    if _selected_dice_indices.size() != MAX_SELECTED_DICE:
        ToastManager.show_dev_error("CustomerSellScene._on_confirm_dice_pressed: dice selection is incomplete")
        return
    var placed := _get_placed_items()
    if placed.is_empty():
        ToastManager.show_dev_error("CustomerSellScene._on_confirm_dice_pressed: no placed items")
        return

    AudioManager.play_event(CONFIRM)
    _dice_section.visible = false
    _pending_strategy = STRATEGY_AGGRESSIVE
    _tooltip.hide_popup()
    _sell_result_popup.dialog_text = _build_result_text(placed, _pending_sale_price, STRATEGY_AGGRESSIVE)
    _sell_result_popup.popup_centered()


func _on_cancel_dice_pressed() -> void:
    AudioManager.play_event(CANCEL)
    _dice_section.visible = false
    _pending_sale_price = 0
    _pending_strategy = ""


func _on_sell_confirmed() -> void:
    var sold_customer := _get_selected_customer()
    if sold_customer == null:
        return
    var placed := _get_placed_items()
    if placed.is_empty():
        ToastManager.show_dev_error("CustomerSellScene._on_sell_confirmed: no placed items")
        return
    if _pending_sale_price <= 0 or _pending_strategy == "":
        ToastManager.show_dev_error("CustomerSellScene._on_sell_confirmed: sale is missing price or strategy")
        return

    # MetaManager owns the transaction: it commits cash/storage, records the
    # sale for the daily summary, and removes the served customer from the
    # persisted nightly set. The scene only drops it from its local view.
    MetaManager.resolve_customer_sale(placed, _pending_sale_price, sold_customer, _pending_strategy)
    AudioManager.play_event(CONFIRM)
    AudioManager.play_event(SALE_COMPLETED)
    AudioManager.play_event(CASH_CREDITED)
    _customers.remove_at(_selected_index)
    _pending_sale_price = 0
    _pending_strategy = ""

    if _customers.is_empty():
        _show_empty_state("All customers served! End of night.")
        _customer_tabs_row.hide()
        return

    _build_customer_tabs()
    _select_customer(mini(_selected_index, _customers.size() - 1))


func _on_sell_cancelled() -> void:
    AudioManager.play_event(CANCEL)
    _pending_sale_price = 0
    _pending_strategy = ""


func _on_back_pressed() -> void:
    SceneRouter.go_to_hub()

# ══ Customers ═════════════════════════════════════════════════════════════════


## Rebuilds the customer tabs from current nightly customers.
func _build_customer_tabs() -> void:
    _clear_children(_customer_tabs_row)

    for index: int in _customers.size():
        var customer := _customers[index]
        if customer == null:
            ToastManager.show_dev_error("CustomerSellScene._build_customer_tabs: customer %d is null" % index)
            continue
        var button := SfxButton.new()
        button.custom_minimum_size = Vector2(140, 36)
        button.add_theme_font_size_override("font_size", 14)
        button.text = customer.display_name
        button.toggle_mode = true
        var selected_index := index
        button.pressed.connect(func() -> void: _select_customer(selected_index))

        # node-src: ephemeral — per-customer tab, dynamic count
        _customer_tabs_row.add_child(button)


## Selects a customer and rebuilds all customer-specific UI.
func _select_customer(index: int) -> void:
    if index < 0 or index >= _customers.size():
        ToastManager.show_dev_error("CustomerSellScene._select_customer: invalid index %d" % index)
        return
    var customer := _customers[index]
    if customer == null:
        ToastManager.show_dev_error("CustomerSellScene._select_customer: customer %d is null" % index)
        return

    _selected_index = index
    _pending_sale_price = 0
    _pending_strategy = ""
    _update_tab_states()
    _apply_customer(customer)


func _update_tab_states() -> void:
    var children := _customer_tabs_row.get_children()
    for index: int in children.size():
        var button := children[index] as Button
        if button == null:
            continue
        button.button_pressed = (index == _selected_index)
        button.disabled = index >= _customers.size() or _customers[index] == null


func _get_selected_customer() -> CustomerEntry:
    if _selected_index < 0 or _selected_index >= _customers.size():
        ToastManager.show_dev_error("CustomerSellScene._get_selected_customer: selected index is invalid")
        return null
    var customer := _customers[_selected_index]
    if customer == null:
        ToastManager.show_dev_error("CustomerSellScene._get_selected_customer: selected customer is null")
    return customer


func _apply_customer(customer: CustomerEntry) -> void:
    _customer_name_label.text = customer.display_name
    _grid_size_label.text = "Car: %dx%d" % [customer.grid_columns, customer.grid_rows]
    _demand_tags_label.text = "Wants: %s" % _format_demand_tags(customer)

    _tooltip.hide_popup()
    _hovered_entry = null
    _dice_section.visible = false
    if not _rebuild_grid(customer):
        return
    _rebuild_item_list(customer)
    _refresh_display()


func _format_demand_tags(customer: CustomerEntry) -> String:
    var tag_names: Array[String] = []
    for tag: String in customer.demand_tags:
        var clue := ClueRegistry.get_clue_by_id(tag)
        tag_names.append(clue.known_text if clue != null and clue.known_text != "" else tag)
    return ", ".join(tag_names)


func _show_empty_state(message: String) -> void:
    _empty_label.text = message
    _empty_label.visible = true
    _main_area.visible = false

# ══ Packing ═══════════════════════════════════════════════════════════════════


func _rebuild_grid(customer: CustomerEntry) -> bool:
    if customer.grid_columns <= 0 or customer.grid_rows <= 0:
        ToastManager.show_error("Customer sale scene failed to load a valid car grid. Returning to hub.")
        SceneRouter.go_to_hub.call_deferred()
        return false
    _grid.setup(customer.grid_columns, customer.grid_rows)
    _main_area.visible = true
    return true


## Rebuilds the sellable item rows for the selected customer.
func _rebuild_item_list(customer: CustomerEntry) -> void:
    _clear_children(_item_list_vbox)
    _item_rows.clear()

    var matched: Array = SellMath.matched_items(customer, MetaManager.storage.storage_items)
    if matched.is_empty():
        var label := Label.new()
        label.text = "No matching items in storage."
        label.add_theme_font_size_override("font_size", 14)
        label.modulate = Color(0.6, 0.6, 0.6)
        # node-src: ephemeral — empty-state label
        _item_list_vbox.add_child(label)
        return

    _grid.setup_default_callbacks(matched)
    for item in matched:
        var entry := item as ItemEntry
        if entry == null:
            ToastManager.show_dev_error("CustomerSellScene._rebuild_item_list: matched item is not ItemEntry")
            continue
        var row: CargoItemRow = CargoItemRowScene.instantiate()
        row.setup(entry)
        row.row_pressed.connect(_on_item_row_pressed)
        row.tooltip_requested.connect(_on_item_row_hovered)
        row.tooltip_dismissed.connect(_on_item_row_hover_ended)
        _item_list_vbox.add_child(row)
        _item_rows[entry] = row


func _refresh_display() -> void:
    if _selected_index < 0:
        return

    var placed := _get_placed_items()
    var total := SellMath.car_total(placed, 1.0)
    var verified_count := _count_verified_items(placed)

    _car_total_label.text = "Car total: $%d" % total
    _verified_count_label.text = "Verified: %d / %d" % [verified_count, placed.size()]
    _update_item_row_states()


func _update_item_row_states() -> void:
    for item in _item_rows.keys():
        var entry := item as ItemEntry
        var row := _item_rows[item] as CargoItemRow
        if entry == null or row == null:
            continue
        var is_loaded := _grid.is_item_placed(entry)
        var is_held: bool = _grid.active_item == entry and _grid.phase == PackingGrid.Phase.ITEM_HELD
        row.set_loaded(is_loaded)
        row.set_holding(is_held)


func _set_row_external_highlight(entry: ItemEntry, highlighted: bool) -> void:
    if entry == null or not _item_rows.has(entry):
        return
    var row := _item_rows[entry] as CargoItemRow
    if row != null:
        row.set_external_highlight(highlighted)


func _get_placed_items() -> Array:
    return _grid.get_placed_items()

# ══ Dice ══════════════════════════════════════════════════════════════════════


func _get_dice_pool_size(customer: CustomerEntry, placed: Array) -> int:
    var depth := SellMath.best_item_fit_depth(customer, placed)
    var verified_count := _count_verified_items(placed)
    return SellMath.dice_pool_size(depth, verified_count)


func _reset_dice_selection() -> void:
    _dice_rolls.clear()
    _selected_dice_indices.clear()
    _dice_buttons.clear()
    _clear_children(_dice_row)


func _add_dice_button(index: int, value: int) -> void:
    _dice_rolls.append(value)
    var button := SfxButton.new()
    button.custom_minimum_size = Vector2(44, 44)
    button.text = str(value)
    button.toggle_mode = true
    button.add_theme_font_size_override("font_size", 16)
    button.toggled.connect(func(toggled: bool) -> void: _on_dice_toggled(index, toggled))
    # node-src: ephemeral — per-die toggle, dynamic count
    _dice_row.add_child(button)
    _dice_buttons.append(button)


func _refresh_dice_totals() -> void:
    if _selected_dice_indices.size() != MAX_SELECTED_DICE:
        _dice_hint_label.text = "Select %d dice to keep" % MAX_SELECTED_DICE
        _dice_sum_label.text = "Sum: —"
        _dice_total_label.text = "Total: —"
        _confirm_dice_button.disabled = true
        return

    var sum := 0
    for index: int in _selected_dice_indices:
        sum += _dice_rolls[index]
    var multiplier := SellMath.dice_multiplier(sum)
    var placed := _get_placed_items()
    var total := SellMath.aggressive_total(placed, sum)
    _pending_sale_price = total

    _dice_hint_label.text = ""
    _dice_sum_label.text = "Sum: %d (×%.1f)" % [sum, multiplier]
    _dice_total_label.text = "Total: $%d" % total
    _confirm_dice_button.disabled = false

# ══ Results ═══════════════════════════════════════════════════════════════════


func _build_result_text(items: Array, price: int, strategy: String) -> String:
    var lines: PackedStringArray = []
    lines.append("Sell Strategy: %s" % strategy.capitalize())
    lines.append("Items: %d" % items.size())
    lines.append("")
    for item in items:
        var entry := item as ItemEntry
        if entry == null:
            ToastManager.show_dev_error("CustomerSellScene._build_result_text: item is not ItemEntry")
            continue
        var contribution := SellMath.item_contribution(entry)
        var verified_label := " (verified)" if SellMath.is_item_verified(entry) else ""
        lines.append("• %s — $%d%s" % [ItemEntryDisplayHelper.display_name(entry), contribution, verified_label])
    lines.append("")
    lines.append("Sell Price: $%d" % price)
    return "\n".join(lines)


func _count_verified_items(items: Array) -> int:
    var verified_count := 0
    for item in items:
        if SellMath.is_item_verified(item):
            verified_count += 1
    return verified_count

# ══ UI helpers ════════════════════════════════════════════════════════════════


func _clear_children(container: Node) -> void:
    for child: Node in container.get_children():
        container.remove_child(child)
        child.queue_free()
