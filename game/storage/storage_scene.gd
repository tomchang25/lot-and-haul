# home_scene.gd
# Home — Displays storage items and allows HOME-context actions.
# Reads:  SaveManager.storage_items, SaveManager.cash
# Writes: SaveManager.storage_items (layer_index), SaveManager.cash, SaveManager.category_points
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────

const ItemRowScene: PackedScene = preload("uid://brx8agwvlpi3f")
const ItemRowTooltipScene: PackedScene = preload("uid://3kvnpn7pek5i")

# Market Research cost per rarity.
const RESEARCH_COST: Dictionary = {
    ItemData.Rarity.COMMON: 500,
    ItemData.Rarity.UNCOMMON: 1000,
    ItemData.Rarity.RARE: 2000,
    ItemData.Rarity.EPIC: 4000,
    ItemData.Rarity.LEGENDARY: 8000,
}

const RESEARCH_DAYS: Dictionary = {
    ItemData.Rarity.COMMON: 1,
    ItemData.Rarity.UNCOMMON: 2,
    ItemData.Rarity.RARE: 3,
    ItemData.Rarity.EPIC: 4,
    ItemData.Rarity.LEGENDARY: 5,
}

# ── State ─────────────────────────────────────────────────────────────────────

var _ctx: ItemViewContext = null
var _tooltip: ItemRowTooltip = null
var _rows: Dictionary = { } # ItemEntry → ItemRow
var _selected_entry: ItemEntry = null

# ── Node references ───────────────────────────────────────────────────────────

@onready var _row_container: VBoxContainer = $RootVBox/ListCenter/OuterVBox/ItemPanel/PanelVBox/ScrollContainer/RowContainer
@onready var _back_btn: Button = $RootVBox/Footer/BackButton
@onready var _empty_label: Label = $RootVBox/ListCenter/OuterVBox/EmptyLabel

@onready var _action_popup: Window = $ActionPopup
@onready var _action_item_label: Label = $ActionPopup/MarginContainer/VBoxContainer/ItemLabel
@onready var _status_label: Label = $ActionPopup/MarginContainer/VBoxContainer/StatusLabel
@onready var _unlock_btn: Button = $ActionPopup/MarginContainer/VBoxContainer/UnlockButton
@onready var _research_btn: Button = $ActionPopup/MarginContainer/VBoxContainer/MarketResearchButton
@onready var _popup_close_btn: Button = $ActionPopup/MarginContainer/VBoxContainer/CloseButton

@onready var _unlock_confirm: ConfirmationDialog = $UnlockConfirm
@onready var _research_confirm: ConfirmationDialog = $ResearchConfirm

@onready var _scroll_container: ScrollContainer = $RootVBox/ListCenter/OuterVBox/ItemPanel/PanelVBox/ScrollContainer

@onready var _action_slot_hud: Label = $ActionSlotHUD

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _ctx = ItemViewContext.for_storage()
    _tooltip = ItemRowTooltipScene.instantiate()
    add_child(_tooltip)

    _back_btn.pressed.connect(_on_back_pressed)
    _popup_close_btn.pressed.connect(_action_popup.hide)
    _unlock_btn.pressed.connect(_on_unlock_pressed)
    _research_btn.pressed.connect(_on_research_pressed)
    _unlock_confirm.confirmed.connect(_on_unlock_confirmed)
    _research_confirm.confirmed.connect(_on_research_confirmed)

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


func _on_research_pressed() -> void:
    if _selected_entry == null:
        return
    _action_popup.hide()
    _research_confirm.popup_centered()


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


func _on_research_confirmed() -> void:
    var entry: ItemEntry = _selected_entry
    if entry == null:
        return
    var cost: int = RESEARCH_COST.get(entry.item_data.rarity, 500)
    if SaveManager.cash < cost:
        return
    var days: int = RESEARCH_DAYS.get(entry.item_data.rarity, 1)
    var action := ActiveActionEntry.create(
        ActiveActionEntry.ActionType.MARKET_RESEARCH,
        entry.id,
        days,
    )
    SaveManager.active_actions.append(action.to_dict())
    SaveManager.cash -= cost
    SaveManager.save()
    _refresh_row(entry)
    _refresh_action_slot_hud()

# ══ Rows ══════════════════════════════════════════════════════════════════════


func _populate_rows() -> void:
    if SaveManager.storage_items.is_empty():
        _empty_label.visible = true
        _scroll_container.visible = false
        return

    _empty_label.visible = false
    _scroll_container.visible = true

    for entry: ItemEntry in SaveManager.storage_items:
        var row: ItemRow = ItemRowScene.instantiate()
        row.setup(entry, _ctx)
        row.set_cargo_state(ItemRow.CargoState.AVAILABLE)
        row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

        row.row_pressed.connect(_on_row_pressed)
        row.tooltip_requested.connect(_on_row_tooltip_requested)
        row.tooltip_dismissed.connect(_tooltip.hide_tooltip)

        _row_container.add_child(row)
        _rows[entry] = row
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
        "market_research":
            return "Market Research"
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

    # Market Research button — hidden only for veiled items
    if not entry.is_veiled():
        var cost: int = RESEARCH_COST.get(entry.item_data.rarity, 500)
        _research_btn.visible = true
        _research_btn.text = "Market Research — $%d" % cost
        if block != "":
            _research_btn.disabled = true
            _research_btn.tooltip_text = block
        elif SaveManager.cash < cost:
            _research_btn.disabled = true
            _research_btn.tooltip_text = "Not enough cash ($%d needed, $%d available)" % [cost, SaveManager.cash]
        else:
            _research_btn.disabled = false
            _research_btn.tooltip_text = ""
    else:
        _research_btn.visible = false

    _action_popup.popup_centered()

# ══ Refresh ════════════════════════════════════════════════════════════════════


func _refresh_row(entry: ItemEntry) -> void:
    if _rows.has(entry):
        _rows[entry].refresh()


func _refresh_action_slot_hud() -> void:
    var used: int = SaveManager.active_actions.size()
    var maximum: int = SaveManager.max_concurrent_actions
    _action_slot_hud.text = "Slots  %d / %d" % [used, maximum]
