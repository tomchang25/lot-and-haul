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
    ItemData.Rarity.COMMON:     1,
    ItemData.Rarity.UNCOMMON:   2,
    ItemData.Rarity.RARE:       3,
    ItemData.Rarity.EPIC:       4,
    ItemData.Rarity.LEGENDARY:  5,
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
@onready var _unlock_btn: Button = $ActionPopup/MarginContainer/VBoxContainer/UnlockButton
@onready var _research_btn: Button = $ActionPopup/MarginContainer/VBoxContainer/MarketResearchButton
@onready var _popup_close_btn: Button = $ActionPopup/MarginContainer/VBoxContainer/CloseButton

@onready var _unlock_confirm: ConfirmationDialog = $UnlockConfirm
@onready var _research_confirm: ConfirmationDialog = $ResearchConfirm

@onready var _scroll_container: ScrollContainer = $RootVBox/ListCenter/OuterVBox/ItemPanel/PanelVBox/ScrollContainer

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _ctx = ItemViewContext.for_cargo()
    _tooltip = ItemRowTooltipScene.instantiate()
    add_child(_tooltip)

    _back_btn.pressed.connect(_on_back_pressed)
    _popup_close_btn.pressed.connect(_action_popup.hide)
    _unlock_btn.pressed.connect(_on_unlock_pressed)
    _research_btn.pressed.connect(_on_research_pressed)
    _unlock_confirm.confirmed.connect(_on_unlock_confirmed)
    _research_confirm.confirmed.connect(_on_research_confirmed)

    _populate_rows()

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
    if not KnowledgeManager.can_advance(entry, LayerUnlockAction.ActionContext.HOME):
        return
    var action_def: LayerUnlockAction = entry.current_unlock_action()
    var days: int = action_def.unlock_days if action_def != null else 1
    var action := ActiveActionEntry.create(
        ActiveActionEntry.ActionType.UNLOCK, entry.id, days)
    SaveManager.active_actions.append(action.to_dict())
    SaveManager.save()
    _refresh_row(entry)


func _on_research_confirmed() -> void:
    var entry: ItemEntry = _selected_entry
    if entry == null:
        return
    var cost: int = RESEARCH_COST.get(entry.item_data.rarity, 500)
    if SaveManager.cash < cost:
        return
    var days: int = RESEARCH_DAYS.get(entry.item_data.rarity, 1)
    var action := ActiveActionEntry.create(
        ActiveActionEntry.ActionType.MARKET_RESEARCH, entry.id, days)
    SaveManager.active_actions.append(action.to_dict())
    SaveManager.cash -= cost
    SaveManager.save()
    _refresh_row(entry)

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


func _show_action_popup(entry: ItemEntry) -> void:
    _action_item_label.text = entry.display_name
    var block: String = _get_action_block_reason(entry)

    var action_def: LayerUnlockAction = entry.current_unlock_action()
    var can_unlock: bool = (
        action_def != null
        and action_def.context == LayerUnlockAction.ActionContext.HOME
        and KnowledgeManager.can_advance(entry, LayerUnlockAction.ActionContext.HOME)
    )
    _unlock_btn.visible = can_unlock
    if can_unlock:
        _unlock_btn.disabled     = block != ""
        _unlock_btn.tooltip_text = block

    if not entry.is_veiled():
        var cost: int = RESEARCH_COST.get(entry.item_data.rarity, 500)
        _research_btn.visible = true
        _research_btn.text    = "Market Research — $%d" % cost
        if block != "":
            _research_btn.disabled     = true
            _research_btn.tooltip_text = block
        elif SaveManager.cash < cost:
            _research_btn.disabled     = true
            _research_btn.tooltip_text = "Not enough cash"
        else:
            _research_btn.disabled     = false
            _research_btn.tooltip_text = ""
    else:
        _research_btn.visible = false

    _action_popup.popup_centered()

# ══ Refresh ════════════════════════════════════════════════════════════════════


func _refresh_row(entry: ItemEntry) -> void:
    if _rows.has(entry):
        _rows[entry].refresh()
