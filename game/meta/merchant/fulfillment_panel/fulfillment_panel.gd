# fulfillment_panel.gd
# Fulfillment Panel — View and fulfill special orders for a merchant.
# Reads:  SaveManager.storage_items, MerchantRegistry, GameManager (merchant hand-off)
# Writes: SaveManager.storage_items, SaveManager.cash
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────

const ItemRowTooltipScene: PackedScene = preload("uid://3kvnpn7pek5i")

const PANEL_COLUMNS: Array = [
    ItemRow.Column.NAME,
    ItemRow.Column.CONDITION,
    ItemRow.Column.APPRAISED_VALUE,
    ItemRow.Column.SPECIAL_ORDER,
]

# ── State ─────────────────────────────────────────────────────────────────────

var _merchant: MerchantData = null
var _selected_order: SpecialOrder = null
var _selected_slot_index: int = -1
var _session_assignments: Dictionary = { } # slot_index (int) → Array[ItemEntry]
var _tooltip: ItemRowTooltip = null
var _ctx: ItemViewContext = null

# ── Node references ───────────────────────────────────────────────────────────

@onready var _title_label: Label = $RootVBox/TitleLabel
@onready var _order_list_vbox: VBoxContainer = $RootVBox/ContentHBox/LeftVBox/OrderListVBox
@onready var _order_info_vbox: VBoxContainer = $RootVBox/ContentHBox/LeftVBox/OrderInfoVBox
@onready var _slots_vbox: VBoxContainer = $RootVBox/ContentHBox/LeftVBox/SlotsVBox
@onready var _item_list_panel: ItemListPanel = $RootVBox/ContentHBox/RightVBox/ItemListPanel
@onready var _session_payout_label: Label = $RootVBox/ContentHBox/RightVBox/SummaryVBox/SessionPayoutLabel
@onready var _completion_bonus_label: Label = $RootVBox/ContentHBox/RightVBox/SummaryVBox/CompletionBonusLabel
@onready var _confirm_btn: Button = $RootVBox/Footer/ConfirmButton
@onready var _back_btn: Button = $RootVBox/Footer/BackButton

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _merchant = GameManager.consume_pending_merchant()
    _tooltip = ItemRowTooltipScene.instantiate()
    add_child(_tooltip)

    _title_label.text = "%s — Orders" % (_merchant.display_name if _merchant else "Merchant")

    _back_btn.pressed.connect(_on_back_pressed)
    _confirm_btn.pressed.connect(_on_confirm_pressed)

    _item_list_panel.row_pressed.connect(_on_item_row_pressed)
    _item_list_panel.tooltip_requested.connect(_on_row_tooltip_requested)
    _item_list_panel.tooltip_dismissed.connect(_tooltip.hide_tooltip)

    _populate_order_list()
    _refresh_confirm_button()

# ══ Signal handlers ═══════════════════════════════════════════════════════════


func _on_back_pressed() -> void:
    GameManager.go_to_merchant_hub()


func _on_order_selected(order: SpecialOrder) -> void:
    _select_order(order)


func _on_slot_selected(index: int) -> void:
    _select_slot(index)


func _on_item_row_pressed(entry: ItemEntry) -> void:
    if _selected_order == null or _selected_slot_index < 0:
        return

    var slot_idx: int = _selected_slot_index
    if not _session_assignments.has(slot_idx):
        _session_assignments[slot_idx] = []

    var assigned: Array = _session_assignments[slot_idx]
    if assigned.has(entry):
        # Unassign
        assigned.erase(entry)
    else:
        # Check capacity
        var slot: OrderSlot = _selected_order.slots[slot_idx]
        var session_count: int = assigned.size()
        if session_count >= slot.remaining():
            return
        assigned.append(entry)

    _refresh_slot_display()
    _refresh_item_rows()
    _refresh_payout_labels()
    _refresh_confirm_button()


func _on_row_tooltip_requested(
        entry: ItemEntry,
        ctx: ItemViewContext,
        anchor: Rect2,
) -> void:
    _tooltip.show_for(entry, ctx, anchor)


func _on_confirm_pressed() -> void:
    if _selected_order == null:
        return

    var total_payout: int = 0
    var consumed: Array[ItemEntry] = []

    for slot_idx: Variant in _session_assignments:
        var assigned: Array = _session_assignments[slot_idx]
        var slot: OrderSlot = _selected_order.slots[int(slot_idx)]
        for entry: ItemEntry in assigned:
            total_payout += _selected_order.compute_item_price(entry)
            consumed.append(entry)
            slot.filled_count += 1

    # Remove consumed items from storage and award knowledge
    for entry: ItemEntry in consumed:
        SaveManager.storage_items.erase(entry)
        KnowledgeManager.add_category_points(
            entry.item_data.category_data.category_id,
            entry.item_data.rarity,
            KnowledgeManager.KnowledgeAction.SELL,
        )

    # Check completion
    if _selected_order.is_complete():
        total_payout += _selected_order.completion_bonus
        _merchant.completed_order_ids.append(_selected_order.id)
        _merchant.active_orders.erase(_selected_order)

    SaveManager.cash += total_payout
    SaveManager.save()
    GameManager.go_to_merchant_hub()

# ══ Order list ═══════════════════════════════════════════════════════════════


func _populate_order_list() -> void:
    for child in _order_list_vbox.get_children():
        child.queue_free()

    if _merchant == null:
        return

    for order: SpecialOrder in _merchant.active_orders:
        var btn := Button.new()
        btn.custom_minimum_size = Vector2(200, 36)
        btn.add_theme_font_size_override("font_size", 14)
        btn.text = order.special_order_id.replace("_", " ").capitalize()

        var eligibility := order.check_eligibility(SaveManager.storage_items)
        btn.text += _eligibility_suffix(eligibility)
        btn.add_theme_color_override(&"font_color", _eligibility_color(eligibility))

        var captured: SpecialOrder = order
        btn.pressed.connect(func() -> void: _on_order_selected(captured))
        _order_list_vbox.add_child(btn)

    if _merchant.active_orders.size() > 0:
        _select_order(_merchant.active_orders[0])


static func _eligibility_color(eligibility: SpecialOrder.Eligibility) -> Color:
    match eligibility:
        SpecialOrder.Eligibility.FULL:
            return Color(0.4, 1.0, 0.5)
        SpecialOrder.Eligibility.PARTIAL:
            return Color(0.92, 0.72, 0.18)
        SpecialOrder.Eligibility.NONE:
            return Color(1.0, 0.4, 0.4)
        _:
            push_warning("Unknown Eligibility: %d" % eligibility)
            return Color(1.0, 0.4, 0.4)


static func _eligibility_suffix(eligibility: SpecialOrder.Eligibility) -> String:
    match eligibility:
        SpecialOrder.Eligibility.FULL:
            return " [Ready]"
        SpecialOrder.Eligibility.PARTIAL:
            return " [Partial]"
        SpecialOrder.Eligibility.NONE:
            return " [No Match]"
        _:
            push_warning("Unknown Eligibility: %d" % eligibility)
            return " [No Match]"

# ══ Order detail ═════════════════════════════════════════════════════════════


func _select_order(order: SpecialOrder) -> void:
    _selected_order = order
    _selected_slot_index = -1
    _session_assignments.clear()
    _ctx = ItemViewContext.for_fulfillment(order)

    _refresh_order_info()
    _refresh_slot_display()
    _item_list_panel.clear()
    _refresh_payout_labels()
    _refresh_confirm_button()


func _refresh_order_info() -> void:
    for child in _order_info_vbox.get_children():
        child.queue_free()

    if _selected_order == null:
        return

    var days_left: int = maxi(0, _selected_order.deadline_day - SaveManager.current_day)
    var info_lines: Array[String] = [
        "Buff: x%.1f" % _selected_order.buff,
        "Bonus: $%d" % _selected_order.completion_bonus,
        "Deadline: %d day(s) left" % days_left,
    ]
    if _selected_order.allow_partial_delivery:
        info_lines.append("Partial delivery allowed")
    if _selected_order.uses_condition:
        info_lines.append("Condition affects price")

    for line: String in info_lines:
        var lbl := Label.new()
        lbl.add_theme_font_size_override("font_size", 14)
        lbl.text = line
        _order_info_vbox.add_child(lbl)


func _refresh_slot_display() -> void:
    for child in _slots_vbox.get_children():
        child.queue_free()

    if _selected_order == null:
        return

    for i in range(_selected_order.slots.size()):
        var slot: OrderSlot = _selected_order.slots[i]
        var session_count: int = 0
        if _session_assignments.has(i):
            session_count = _session_assignments[i].size()

        var total_filled: int = slot.filled_count + session_count
        var cat_name: String = slot.category.display_name if slot.category else "???"

        var slot_text: String = "%s: %d / %d" % [cat_name, total_filled, slot.required_count]
        if slot.min_rarity >= 0:
            slot_text += " [Uncommon+]"
        if slot.min_condition > 0.0:
            slot_text += " [Cond >= %d%%]" % int(slot.min_condition * 100)

        var completed: bool = slot.is_full()
        var slot_elig: SpecialOrder.Eligibility = SpecialOrder.Eligibility.NONE
        if not completed:
            var result: Dictionary = slot.check_eligibility(SaveManager.storage_items)
            slot_elig = result["eligibility"]
            slot_text += _eligibility_suffix(slot_elig)

        var btn := Button.new()
        btn.custom_minimum_size = Vector2(200, 32)
        btn.add_theme_font_size_override("font_size", 13)
        btn.text = slot_text
        btn.disabled = completed

        if not completed:
            btn.add_theme_color_override(&"font_color", _eligibility_color(slot_elig))

        if i == _selected_slot_index:
            var style := StyleBoxFlat.new()
            style.bg_color = Color(1.0, 1.0, 1.0, 0.15)
            btn.add_theme_stylebox_override("normal", style)

        var captured_idx: int = i
        btn.pressed.connect(func() -> void: _on_slot_selected(captured_idx))
        _slots_vbox.add_child(btn)


func _select_slot(index: int) -> void:
    _selected_slot_index = index
    _refresh_slot_display()
    _populate_inventory_for_slot()

# ══ Inventory display ════════════════════════════════════════════════════════


func _populate_inventory_for_slot() -> void:
    _item_list_panel.clear()
    if _selected_order == null or _selected_slot_index < 0:
        return

    var slot: OrderSlot = _selected_order.slots[_selected_slot_index]
    _item_list_panel.setup(_ctx, PANEL_COLUMNS)

    # Filter storage items by slot.accepts()
    var eligible: Array[ItemEntry] = []
    for entry: ItemEntry in SaveManager.storage_items:
        if slot.accepts(entry):
            eligible.append(entry)

    _item_list_panel.populate(eligible)

    # Set initial selection state
    _refresh_item_rows()


func _refresh_item_rows() -> void:
    if _selected_order == null or _selected_slot_index < 0:
        return

    var slot_idx: int = _selected_slot_index
    var assigned: Array = _session_assignments.get(slot_idx, [])
    var slot: OrderSlot = _selected_order.slots[slot_idx]
    var at_capacity: bool = assigned.size() >= slot.remaining()

    # Also gather all items assigned in other slots for this order
    var assigned_elsewhere: Dictionary = { } # ItemEntry → true
    for other_idx: Variant in _session_assignments:
        if int(other_idx) == slot_idx:
            continue
        for entry: ItemEntry in _session_assignments[other_idx]:
            assigned_elsewhere[entry] = true

    for entry_key: Variant in _item_list_panel.get_all_rows():
        var entry: ItemEntry = entry_key
        var row: ItemRow = _item_list_panel.get_row(entry)
        if row == null:
            continue

        if assigned_elsewhere.has(entry):
            row.set_selection_state(ItemRow.SelectionState.BLOCKED)
        elif assigned.has(entry):
            row.set_selection_state(ItemRow.SelectionState.SELECTED)
        elif at_capacity:
            row.set_selection_state(ItemRow.SelectionState.BLOCKED)
        else:
            row.set_selection_state(ItemRow.SelectionState.AVAILABLE)

# ══ Payout ═══════════════════════════════════════════════════════════════════


func _refresh_payout_labels() -> void:
    var total: int = 0
    for slot_idx: Variant in _session_assignments:
        for entry: ItemEntry in _session_assignments[slot_idx]:
            total += _selected_order.compute_item_price(entry) if _selected_order else 0
    _session_payout_label.text = "Session Payout: $%d" % total

    # Show completion bonus if this session would complete the order
    if _selected_order != null and _would_complete_order():
        _completion_bonus_label.text = "Completion Bonus: $%d" % _selected_order.completion_bonus
        _completion_bonus_label.visible = true
    else:
        _completion_bonus_label.visible = false

# ══ Confirm logic ════════════════════════════════════════════════════════════


func _refresh_confirm_button() -> void:
    if _selected_order == null:
        _confirm_btn.disabled = true
        return

    var any_assigned: bool = _has_any_assignments()
    if _selected_order.allow_partial_delivery:
        _confirm_btn.disabled = not any_assigned
    else:
        _confirm_btn.disabled = not _would_complete_order()


func _has_any_assignments() -> bool:
    for slot_idx: Variant in _session_assignments:
        if not _session_assignments[slot_idx].is_empty():
            return true
    return false


func _would_complete_order() -> bool:
    if _selected_order == null:
        return false
    for i in range(_selected_order.slots.size()):
        var slot: OrderSlot = _selected_order.slots[i]
        var session_count: int = 0
        if _session_assignments.has(i):
            session_count = _session_assignments[i].size()
        if slot.filled_count + session_count < slot.required_count:
            return false
    return true
