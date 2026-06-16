# customer_sell_scene.gd
# Phase 9 nightly customer sell screen — coordinates components for tag matching, car packing, sell strategy.
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

# ── State ─────────────────────────────────────────────────────────────────────

var _customers: Array[CustomerEntry] = []
var _selected_index: int = -1
var _pending_sale_price: int = 0
var _pending_strategy: String = ""
var _hovered_entry: ItemEntry = null

# ── Node references ───────────────────────────────────────────────────────────

@onready var _day_label: Label = %DayLabel
@onready var _back_button: SfxButton = %BackButton
@onready var _empty_label: Label = %EmptyLabel
@onready var _main_area: HBoxContainer = %MainArea
@onready var _customer_queue: CustomerQueuePanel = %CustomerQueuePanel
@onready var _item_list: SellingItemListPanel = %SellingItemListPanel
@onready var _car_panel: CustomerCarPanel = %CustomerCarPanel
@onready var _profile_panel: CustomerProfilePanel = %CustomerProfilePanel
@onready var _selected_item_panel: SelectedItemPanel = %SelectedItemPanel
@onready var _deal_panel: DealPanel = %DealPanel
@onready var _receipt: SaleReceiptDialog = %SaleReceiptDialog
@onready var _tooltip: ItemCardPopup = %TooltipPopup

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _back_button.pressed.connect(_on_back_pressed)
    _back_button.press_event = CANCEL

    _customer_queue.customer_selected.connect(_on_customer_selected)
    _item_list.item_pick_requested.connect(_on_item_pick_requested)
    _item_list.tooltip_requested.connect(_on_item_row_hovered)
    _item_list.tooltip_dismissed.connect(_on_item_row_hover_ended)

    _car_panel.placement_changed.connect(_on_car_placement_changed)
    _car_panel.item_clicked.connect(_on_grid_item_clicked)
    _car_panel.cell_clicked.connect(_on_grid_cell_clicked)
    _car_panel.hover_started.connect(_on_grid_hover_started)
    _car_panel.hover_ended.connect(_on_grid_hover_ended)
    _car_panel.car_clear_requested.connect(_on_car_clear_requested)

    _deal_panel.conservative_requested.connect(_on_conservative_requested)
    _deal_panel.aggressive_requested.connect(_on_aggressive_requested)
    _deal_panel.pitch_confirmed.connect(_on_pitch_confirmed)

    _receipt.receipt_confirmed.connect(_on_receipt_confirmed)
    _receipt.receipt_cancelled.connect(_on_receipt_cancelled)

    _customers = MetaManager.customers.nightly_customers.duplicate()

    if _customers.is_empty():
        _show_empty_state("No customers tonight.")
        return

    _day_label.text = "Day %d" % MetaManager.progress.current_day
    _customer_queue.setup(_customers)
    _customer_queue.set_selected(0)
    _select_customer(0)

# ══ Signal handlers ═══════════════════════════════════════════════════════════


func _on_customer_selected(index: int) -> void:
    _select_customer(index)


func _on_item_pick_requested(entry: ItemEntry) -> void:
    if entry == null:
        return
    _selected_item_panel.set_item(entry)
    var grid := _car_panel.get_grid()
    if grid.phase == PackingGrid.Phase.ITEM_HELD:
        grid.cancel_placement()
        _item_list.update_row_states(grid)
        return
    if grid.is_item_placed(entry):
        grid.lift(entry)
    else:
        grid.set_held_item(entry, grid.item_rotations.get(entry, 0))
    AudioManager.play_event(SELL_GRID_LIFT)
    _item_list.update_row_states(grid)


func _on_item_row_hovered(entry: ItemEntry, anchor: Rect2) -> void:
    if entry == null:
        return
    var grid := _car_panel.get_grid()
    grid.set_external_hover_item(entry)
    _selected_item_panel.set_item(entry)
    _tooltip.show_for(entry, anchor)


func _on_item_row_hover_ended() -> void:
    var grid := _car_panel.get_grid()
    grid.set_external_hover_item(null)
    _selected_item_panel.clear_display()
    _tooltip.hide_popup()


func _on_grid_hover_started(cell_pos: Vector2i) -> void:
    var grid := _car_panel.get_grid()
    if grid.phase == PackingGrid.Phase.ITEM_HELD:
        return
    var new_entry: ItemEntry = grid.placement.get(cell_pos) as ItemEntry
    if new_entry == _hovered_entry:
        return
    _item_list.set_external_highlight(_hovered_entry, false)
    _hovered_entry = new_entry
    _item_list.set_external_highlight(_hovered_entry, true)
    if _hovered_entry != null:
        _selected_item_panel.set_item(_hovered_entry)
        _tooltip.show_for(_hovered_entry, _car_panel.get_global_rect())


func _on_grid_hover_ended() -> void:
    _item_list.set_external_highlight(_hovered_entry, false)
    _hovered_entry = null
    _selected_item_panel.clear_display()
    _tooltip.hide_popup()


func _on_grid_item_clicked(item) -> void:
    var entry := item as ItemEntry
    if entry == null:
        return
    _selected_item_panel.set_item(entry)
    var grid := _car_panel.get_grid()
    grid.lift(entry)
    AudioManager.play_event(SELL_GRID_LIFT)
    _refresh_car_display()


func _on_grid_cell_clicked(pos: Vector2i) -> void:
    var grid := _car_panel.get_grid()
    if grid.active_item == null:
        return
    if not grid.can_place(grid.active_item, pos):
        AudioManager.play_event(BLOCKED_ERROR)
        return
    grid.place(grid.active_item, pos)
    AudioManager.play_event(SELL_GRID_PUT_DOWN)
    _item_list.update_row_states(grid)


func _on_car_clear_requested() -> void:
    _refresh_car_display()


func _on_car_placement_changed() -> void:
    _refresh_car_display()


func _on_conservative_requested(price: int) -> void:
    var placed := _car_panel.get_grid().get_placed_items()
    if placed.is_empty():
        return
    _pending_sale_price = price
    _pending_strategy = "conservative"
    _tooltip.hide_popup()
    _receipt.show_receipt(placed, price, "conservative")


func _on_aggressive_requested() -> void:
    var customer := _get_selected_customer()
    if customer == null:
        return
    var grid := _car_panel.get_grid()
    var placed := grid.get_placed_items()
    if placed.is_empty():
        AudioManager.play_event(CANCEL)
        return
    var pool := _get_dice_pool_size(customer, placed)
    var rolls := SellMath.roll_dice(pool)
    _deal_panel.show_dice(rolls, placed)


func _on_pitch_confirmed(price: int) -> void:
    var placed := _car_panel.get_grid().get_placed_items()
    _pending_sale_price = price
    _pending_strategy = "aggressive"
    _tooltip.hide_popup()
    _receipt.show_receipt(placed, price, "aggressive")


func _on_receipt_confirmed(price: int, strategy: String) -> void:
    var sold_customer := _get_selected_customer()
    if sold_customer == null:
        return
    var placed := _car_panel.get_grid().get_placed_items()
    if placed.is_empty():
        ToastManager.show_dev_error("CustomerSellScene._on_receipt_confirmed: no placed items")
        return
    if price <= 0 or strategy == "":
        ToastManager.show_dev_error("CustomerSellScene._on_receipt_confirmed: sale is missing price or strategy")
        return

    MetaManager.resolve_customer_sale(placed, price, sold_customer, strategy)
    AudioManager.play_event(CONFIRM)
    AudioManager.play_event(SALE_COMPLETED)
    AudioManager.play_event(CASH_CREDITED)
    _customers.remove_at(_selected_index)
    _pending_sale_price = 0
    _pending_strategy = ""

    if _customers.is_empty():
        _show_empty_state("All customers served! End of night.")
        _customer_queue.hide()
        return

    var auto_select := mini(_selected_index, _customers.size() - 1)
    _customer_queue.rebuild(_customers, auto_select)
    _select_customer(auto_select)


func _on_receipt_cancelled() -> void:
    AudioManager.play_event(CANCEL)
    _pending_sale_price = 0
    _pending_strategy = ""


func _on_back_pressed() -> void:
    SceneRouter.go_to_hub()

# ══ Customer selection ════════════════════════════════════════════════════════


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
    _tooltip.hide_popup()
    _hovered_entry = null
    _deal_panel.reset()
    _selected_item_panel.clear_display()

    var grid := _car_panel.get_grid()
    if customer.grid_columns <= 0 or customer.grid_rows <= 0:
        ToastManager.show_error("Customer sale scene failed to load a valid car grid. Returning to hub.")
        SceneRouter.go_to_hub.call_deferred()
        return

    grid.reset()
    grid.setup(customer.grid_columns, customer.grid_rows)

    _car_panel.setup(customer)
    _profile_panel.setup(customer)
    _item_list.rebuild(
        customer,
        MetaManager.storage.storage_items,
        func(matched: Array) -> void:
            grid.setup_default_callbacks(matched)
    )
    _deal_panel.set_placed_items(grid.get_placed_items())

    _empty_label.hide()


func _get_selected_customer() -> CustomerEntry:
    if _selected_index < 0 or _selected_index >= _customers.size():
        ToastManager.show_dev_error("CustomerSellScene._get_selected_customer: selected index is invalid")
        return null
    var customer := _customers[_selected_index]
    if customer == null:
        ToastManager.show_dev_error("CustomerSellScene._get_selected_customer: selected customer is null")
    return customer


func _show_empty_state(message: String) -> void:
    _empty_label.text = message
    _empty_label.show()
    _main_area.hide()
    _customer_queue.hide()

# ══ Car display ═══════════════════════════════════════════════════════════════


func _refresh_car_display() -> void:
    if _selected_index < 0:
        return
    var placed := _car_panel.get_grid().get_placed_items()
    _profile_panel.set_car_info(placed)
    _item_list.update_row_states(_car_panel.get_grid())
    _deal_panel.set_placed_items(placed)

# ══ Dice helpers ══════════════════════════════════════════════════════════════


func _get_dice_pool_size(customer: CustomerEntry, placed: Array) -> int:
    var depth := SellMath.best_item_fit_depth(customer, placed)
    var verified_count := _count_verified_items(placed)
    return SellMath.dice_pool_size(depth, verified_count)


func _count_verified_items(items: Array) -> int:
    var count := 0
    for item in items:
        if SellMath.is_item_verified(item):
            count += 1
    return count
