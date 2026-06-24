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
var _selected_entry: ItemEntry = null
var _preview_entry: ItemEntry = null
var _suppress_placement_update: bool = false

# ── Node references ───────────────────────────────────────────────────────────

@onready var _day_label: Label = %DayLabel
@onready var _back_button: SfxButton = %BackButton
@onready var _empty_state: VBoxContainer = %EmptyState
@onready var _empty_label: Label = %EmptyLabel
@onready var _empty_close_button: SfxButton = %EmptyCloseButton
@onready var _main_area: HBoxContainer = %MainArea
@onready var _customer_queue: CustomerQueuePanel = %CustomerQueuePanel
@onready var _item_list: SellingItemListPanel = %SellingItemListPanel
@onready var _car_panel: CustomerCarPanel = %CustomerCarPanel
@onready var _detail_panel: ItemDetailPanel = %DetailPanel
@onready var _receipt: SaleReceiptDialog = %SaleReceiptDialog

var _deal_panel: DealPanel

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _back_button.pressed.connect(_on_back_pressed)
    _back_button.press_event = CANCEL
    _empty_close_button.pressed.connect(_on_back_pressed)
    _empty_close_button.press_event = CANCEL

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

    _deal_panel = _car_panel.deal_panel
    _deal_panel.conservative_requested.connect(_on_conservative_requested)
    _deal_panel.aggressive_requested.connect(_on_aggressive_requested)
    _deal_panel.pitch_confirmed.connect(_on_pitch_confirmed)
    _deal_panel.dice_toggled.connect(_on_dice_toggled)

    _receipt.receipt_confirmed.connect(_on_receipt_confirmed)
    _receipt.receipt_cancelled.connect(_on_receipt_cancelled)

    _customers = MetaManager.customers.nightly_customers.duplicate()

    if _customers.is_empty():
        _show_empty_state(TranslationServer.translate("UI_NO_CUSTOMERS_TONIGHT"))
        return

    _day_label.text = TranslationServer.translate("UI_DAY_LABEL") % MetaManager.progress.current_day
    _customer_queue.setup(_customers)
    _customer_queue.set_selected(0)
    _suppress_placement_update = true
    _select_customer(0)
    _suppress_placement_update = false

    var saved_id: String = MetaManager.shop_session.active_customer_session_id
    if saved_id != "":
        var idx := _find_customer_index(saved_id)
        if idx >= 0 and idx != 0:
            _customer_queue.set_selected(idx)
            _suppress_placement_update = true
            _select_customer(idx)
            _suppress_placement_update = false
        _apply_saved_placement(MetaManager.shop_session.placement)

    Director.register_scene(
        "customer_sell",
        {
            "customer_queue": _customer_queue,
            "item_list": _item_list,
            "car_panel": _car_panel,
            "deal_panel": _deal_panel,
            "back_btn": _back_button,
        },
    )

    # During the onboarding_selling tutorial, lock conservative so the player
    # can't short-circuit the aggressive dice flow by closing the sale early.
    _apply_conservative_lock()
    GameplayOverride.override_changed.connect(_on_customer_sell_override_changed)

# ══ Signal handlers ═══════════════════════════════════════════════════════════


func _on_customer_selected(index: int) -> void:
    _suppress_placement_update = true
    _select_customer(index)
    _suppress_placement_update = false
    MetaManager.update_shop_session(
        _get_selected_customer(),
        _serialize_placement(),
    )


func _on_item_pick_requested(entry: ItemEntry) -> void:
    if entry == null:
        return
    _show_item_detail(entry, false)
    var grid := _car_panel.get_grid()
    if grid.phase == PackingGrid.Phase.ITEM_HELD:
        grid.cancel_placement()
        _item_list.update_row_states(grid)
    if grid.is_item_placed(entry):
        grid.lift(entry)
    else:
        grid.set_held_item(entry, grid.item_rotations.get(entry, 0))
    AudioManager.play_event(SELL_GRID_LIFT)
    _item_list.update_row_states(grid)


func _on_item_row_hovered(entry: ItemEntry, _anchor: Rect2) -> void:
    if entry == null:
        return
    var grid := _car_panel.get_grid()
    grid.set_external_hover_item(entry)
    _show_item_detail(entry, true)


func _on_item_row_hover_ended() -> void:
    var grid := _car_panel.get_grid()
    grid.set_external_hover_item(null)
    _clear_preview_detail()


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
        _show_item_detail(_hovered_entry, true)


func _on_grid_hover_ended() -> void:
    _item_list.set_external_highlight(_hovered_entry, false)
    _hovered_entry = null
    _clear_preview_detail()


func _on_grid_item_clicked(item) -> void:
    var entry := item as ItemEntry
    if entry == null:
        return
    _show_item_detail(entry, false)
    var grid := _car_panel.get_grid()
    grid.lift(entry)
    AudioManager.play_event(SELL_GRID_LIFT)
    _refresh_car_display()


func _on_grid_cell_clicked(pos: Vector2i) -> void:
    var grid := _car_panel.get_grid()
    var item := grid.active_item as ItemEntry
    if item == null:
        return
    if not grid.can_place(item, pos):
        AudioManager.play_event(BLOCKED_ERROR)
        _item_list.play_card_reject(item)
        return
    grid.place(item, pos)
    AudioManager.play_event(SELL_GRID_PUT_DOWN)
    _item_list.update_row_states(grid)
    _item_list.play_card_pulse(item)
    EventBus.tutorial_event.emit(TutorialEvents.SELL_ITEM_PLACED, { })


func _on_car_clear_requested() -> void:
    _refresh_car_display()


func _on_car_placement_changed() -> void:
    _refresh_car_display()
    if _suppress_placement_update:
        return
    MetaManager.update_shop_session(
        _get_selected_customer(),
        _serialize_placement(),
    )


func _on_conservative_requested(price: int) -> void:
    if GameplayOverride.is_active(GameplayOverride.CONSERVATIVE_SALE_LOCKED):
        return
    var placed := _car_panel.get_grid().get_placed_items()
    if placed.is_empty():
        return
    _pending_sale_price = price
    _pending_strategy = "conservative"
    _receipt.show_receipt(placed, price, "conservative")


func _on_dice_toggled() -> void:
    EventBus.tutorial_event.emit(TutorialEvents.DICE_TOGGLED, { })


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
    EventBus.tutorial_event.emit(TutorialEvents.SELL_AGGRESSIVE_REQUESTED, { })


func _on_pitch_confirmed(price: int) -> void:
    var placed := _car_panel.get_grid().get_placed_items()
    _pending_sale_price = price
    _pending_strategy = "aggressive"
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
    _selected_entry = null
    _preview_entry = null

    if _customers.is_empty():
        _show_empty_state(TranslationServer.translate("UI_ALL_CUSTOMERS_SERVED"))
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
    MetaManager.shop_session.clear()
    MetaManager.customers.clear_customers()
    SaveManager.save()
    SceneRouter.go_to_hub()


func _apply_conservative_lock() -> void:
    _deal_panel.set_conservative_sale_locked(GameplayOverride.is_active(GameplayOverride.CONSERVATIVE_SALE_LOCKED))


func _on_customer_sell_override_changed(id: StringName, active: bool, _payload: Variant) -> void:
    if id == GameplayOverride.CONSERVATIVE_SALE_LOCKED:
        _deal_panel.set_conservative_sale_locked(active)

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
    _selected_entry = null
    _preview_entry = null
    _hovered_entry = null
    _deal_panel.reset()
    _deal_panel.set_customer(customer)
    _receipt.set_customer(customer)
    _detail_panel.setup(null, true, true)

    var grid := _car_panel.get_grid()
    if customer.grid_columns <= 0 or customer.grid_rows <= 0:
        ToastManager.show_error("Customer sale scene failed to load a valid car grid. Returning to hub.")
        SceneRouter.go_to_hub.call_deferred()
        return

    grid.reset()
    grid.setup(customer.grid_columns, customer.grid_rows)

    _car_panel.setup(customer)
    _item_list.rebuild(
        customer,
        MetaManager.storage.storage_items,
        func(matched: Array) -> void:
            grid.setup_default_callbacks(matched)
    )
    _deal_panel.set_placed_items(grid.get_placed_items())

    _empty_state.hide()


func _get_selected_customer() -> CustomerEntry:
    if _selected_index < 0 or _selected_index >= _customers.size():
        ToastManager.show_dev_error("CustomerSellScene._get_selected_customer: selected index is invalid")
        return null
    var customer := _customers[_selected_index]
    if customer == null:
        ToastManager.show_dev_error("CustomerSellScene._get_selected_customer: selected customer is null")
    return customer


## Returns the index of the customer with [param customer_id], or -1.
func _find_customer_index(customer_id: String) -> int:
    for i: int in _customers.size():
        if _customers[i] != null and _customers[i].session_id == customer_id:
            return i
    return -1


## Serialises the current PackingGrid placement into an Array of
## {"item_id", "cell", "rotation"} dicts - one entry per unique item with the
## top-left origin and the stored rotation.
func _serialize_placement() -> Array:
    var grid := _car_panel.get_grid()
    var snapshot: Array = []
    for item in grid.get_placed_items():
        var entry := item as ItemEntry
        if entry == null:
            continue
        var origin := grid.get_item_origin(entry)
        snapshot.append(
            {
                "item_id": entry.id,
                "cell": { "x": origin.x, "y": origin.y },
                "rotation": int(grid.item_rotations.get(entry, 0)),
            },
        )
    return snapshot


## Replays a saved placement Array onto the live PackingGrid. Entries that
## fail can_place (grid changed, item missing) are silently dropped.
func _apply_saved_placement(placement: Array) -> void:
    var grid := _car_panel.get_grid()
    var by_id: Dictionary = { }
    for item in MetaManager.storage.storage_items:
        var entry := item as ItemEntry
        if entry != null:
            by_id[entry.id] = entry
    for p: Dictionary in placement:
        var entry: ItemEntry = by_id.get(int(p.get("item_id", -1)))
        if entry == null:
            continue
        var cell_dict: Dictionary = p.get("cell", { })
        var cell := Vector2i(
            int(cell_dict.get("x", 0)),
            int(cell_dict.get("y", 0)),
        )
        var rot: int = int(p.get("rotation", 0))
        # place() and can_place() both read active_rotation, so set it before
        # the can_place check; place() resets it to 0 after the call.
        grid.active_rotation = rot
        if grid.can_place(entry, cell):
            grid.place(entry, cell)
    _refresh_car_display()


func _show_empty_state(message: String) -> void:
    _empty_label.text = message
    _empty_state.show()
    _main_area.hide()
    _customer_queue.hide()

# ══ Item detail preview/selection ═════════════════════════════════════════════


func _show_item_detail(entry: ItemEntry, preview: bool) -> void:
    if preview:
        _preview_entry = entry
    else:
        _selected_entry = entry
    _detail_panel.setup(entry, true, true)


func _clear_preview_detail() -> void:
    _preview_entry = null
    if _selected_entry != null:
        _detail_panel.setup(_selected_entry, true, true)
    else:
        _detail_panel.setup(null, true, true)

# ══ Car display ═══════════════════════════════════════════════════════════════


func _refresh_car_display() -> void:
    if _selected_index < 0:
        return
    var placed := _car_panel.get_grid().get_placed_items()
    _car_panel.set_car_info(placed)
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
