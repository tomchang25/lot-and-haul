# home_scene.gd
# Home — Displays storage items and allows HOME-context actions.
# Reads:  SaveManager.storage_items, SaveManager.cash
# Writes: SaveManager.storage_items (layer_index), SaveManager.cash, SaveManager.category_points
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────

const ItemRowTooltipScene: PackedScene = preload("uid://3kvnpn7pek5i")

const STORAGE_COLUMNS: Array = [
    ItemRow.Column.NAME,
    ItemRow.Column.CONDITION,
    ItemRow.Column.ESTIMATED_VALUE,
    ItemRow.Column.RARITY,
]

# ── State ─────────────────────────────────────────────────────────────────────

var _ctx: ItemViewContext = null
var _tooltip: ItemRowTooltip = null
var _selected_entry: ItemEntry = null

# ── Node references ───────────────────────────────────────────────────────────

@onready var _item_list_panel: ItemListPanel = $RootVBox/ListCenter/OuterVBox/ItemListPanel
@onready var _back_btn: Button = $RootVBox/Footer/BackButton
@onready var _empty_label: Label = $RootVBox/ListCenter/OuterVBox/EmptyLabel

@onready var _action_popup: Window = $ActionPopup
@onready var _action_item_label: Label = $ActionPopup/MarginContainer/VBoxContainer/ItemLabel
@onready var _status_label: Label = $ActionPopup/MarginContainer/VBoxContainer/StatusLabel
@onready var _unlock_btn: Button = $ActionPopup/MarginContainer/VBoxContainer/UnlockButton
@onready var _popup_close_btn: Button = $ActionPopup/MarginContainer/VBoxContainer/CloseButton

@onready var _unlock_confirm: ConfirmationDialog = $UnlockConfirm

@onready var _action_slot_hud: Label = $ActionSlotHUD

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _ctx = ItemViewContext.for_storage()
    _tooltip = ItemRowTooltipScene.instantiate()
    add_child(_tooltip)

    _back_btn.pressed.connect(_on_back_pressed)
    _popup_close_btn.pressed.connect(_action_popup.hide)
    _unlock_btn.pressed.connect(_on_unlock_pressed)
    _unlock_confirm.confirmed.connect(_on_unlock_confirmed)

    _item_list_panel.row_pressed.connect(_on_row_pressed)
    _item_list_panel.tooltip_requested.connect(_on_row_tooltip_requested)
    _item_list_panel.tooltip_dismissed.connect(_tooltip.hide_tooltip)

    _populate_rows()
    _refresh_action_slot_hud()

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_back_pressed() -> void:
    GameManager.go_to_hub()


func _on_row_pressed(entry: ItemEntry) -> void:
    _selected_entry = entry
    _show_action_popup(entry)


func _on_row_tooltip_requested(
        entry: ItemEntry,
        ctx: ItemViewContext,
        anchor: Rect2,
) -> void:
    _tooltip.show_for(entry, ctx, anchor)


func _on_unlock_pressed() -> void:
    if _selected_entry == null:
        return
    _action_popup.hide()
    _unlock_confirm.popup_centered()


func _on_unlock_confirmed() -> void:
    var entry: ItemEntry = _selected_entry
    if entry == null:
        return
    if KnowledgeManager.can_advance(entry, LayerUnlockAction.ActionContext.HOME) != KnowledgeManager.AdvanceCheck.OK:
        return
    var action_def: LayerUnlockAction = entry.current_unlock_action()
    var days: int = action_def.unlock_days if action_def != null else 1
    var action := ActiveActionEntry.create(
        ActiveActionEntry.ActionType.UNLOCK,
        entry.id,
        days,
    )
    SaveManager.active_actions.append(action.to_dict())
    SaveManager.save()
    _refresh_row(entry)
    _refresh_action_slot_hud()

# ══ Rows ══════════════════════════════════════════════════════════════════════


func _populate_rows() -> void:
    if SaveManager.storage_items.is_empty():
        _empty_label.visible = true
        _item_list_panel.visible = false
        return

    _empty_label.visible = false
    _item_list_panel.visible = true

    _item_list_panel.setup(_ctx, STORAGE_COLUMNS)
    _item_list_panel.populate(SaveManager.storage_items)

    for entry: ItemEntry in SaveManager.storage_items:
        var row: ItemRow = _item_list_panel.get_row(entry)
        if row != null:
            row.set_selection_state(ItemRow.SelectionState.AVAILABLE)

# ══ Action popup ══════════════════════════════════════════════════════════════


func _get_action_block_reason(entry: ItemEntry) -> String:
    if SaveManager.active_actions.size() >= SaveManager.max_concurrent_actions:
        return "No action slots available"
    for d: Dictionary in SaveManager.active_actions:
        if int(d.get("item_id", -1)) == entry.id:
            return "Already in progress"
    return ""


func _get_unlock_block_reason(entry: ItemEntry) -> String:
    var action_def: LayerUnlockAction = entry.current_unlock_action()
    if action_def == null:
        return "No further layers to unlock"
    var check: KnowledgeManager.AdvanceCheck = KnowledgeManager.can_advance(
        entry,
        LayerUnlockAction.ActionContext.HOME,
    )
    if check == KnowledgeManager.AdvanceCheck.OK:
        return ""
    return AdvanceCheckLabel.describe(check, action_def, entry)


func _get_in_progress_action(entry: ItemEntry) -> Dictionary:
    for d: Dictionary in SaveManager.active_actions:
        if int(d.get("item_id", -1)) == entry.id:
            return d
    return { }


func _action_type_label(action_type_string: String) -> String:
    match action_type_string:
        "unlock":
            return "Unlock"
        _:
            return action_type_string


func _show_action_popup(entry: ItemEntry) -> void:
    _action_item_label.text = entry.display_name
    var block: String = _get_action_block_reason(entry)
    var in_progress: Dictionary = _get_in_progress_action(entry)

    # Status label
    if not in_progress.is_empty():
        _status_label.text = "⏳ %s in progress" % _action_type_label(in_progress["action_type"])
        _status_label.visible = true
    elif block != "":
        _status_label.text = block
        _status_label.visible = true
    else:
        _status_label.visible = false

    # Unlock button — always visible, disabled with tooltip when blocked
    var unlock_reason: String = _get_unlock_block_reason(entry)
    _unlock_btn.visible = true
    if block != "":
        _unlock_btn.disabled = true
        _unlock_btn.tooltip_text = block
    elif unlock_reason != "":
        _unlock_btn.disabled = true
        _unlock_btn.tooltip_text = unlock_reason
    else:
        _unlock_btn.disabled = false
        _unlock_btn.tooltip_text = ""

    _action_popup.popup_centered()

# ══ Refresh ════════════════════════════════════════════════════════════════════


func _refresh_row(entry: ItemEntry) -> void:
    _item_list_panel.refresh_row(entry)


func _refresh_action_slot_hud() -> void:
    var used: int = SaveManager.active_actions.size()
    var maximum: int = SaveManager.max_concurrent_actions
    _action_slot_hud.text = "Slots  %d / %d" % [used, maximum]
