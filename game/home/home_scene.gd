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

# ── State ─────────────────────────────────────────────────────────────────────

var _ctx: ItemViewContext = null
var _tooltip: ItemRowTooltip = null
var _rows: Dictionary = { } # ItemEntry → ItemRow
var _selected_entry: ItemEntry = null

# ── Node references ───────────────────────────────────────────────────────────

@onready var _row_container: VBoxContainer = $RootVBox/ListCenter/OuterVBox/ItemPanel/PanelVBox/ScrollContainer/RowContainer
@onready var _back_btn: Button = $RootVBox/Header/BackButton
@onready var _empty_label: Label = $RootVBox/ListCenter/OuterVBox/EmptyLabel

@onready var _action_popup: Window = $ActionPopup
@onready var _action_item_label: Label = $ActionPopup/MarginContainer/VBoxContainer/ItemLabel
@onready var _unlock_btn: Button = $ActionPopup/MarginContainer/VBoxContainer/UnlockButton
@onready var _research_btn: Button = $ActionPopup/MarginContainer/VBoxContainer/MarketResearchButton
@onready var _popup_close_btn: Button = $ActionPopup/MarginContainer/VBoxContainer/CloseButton

@onready var _unlock_confirm: ConfirmationDialog = $UnlockConfirm
@onready var _research_confirm: ConfirmationDialog = $ResearchConfirm

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
    entry.layer_index += 1
    var cat_id: String = entry.item_data.category_data.category_id
    KnowledgeManager.add_category_points(cat_id, entry.item_data.rarity, KnowledgeManager.KnowledgeAction.APPRAISE)
    _refresh_row(entry)
    SaveManager.save()


func _on_research_confirmed() -> void:
    var entry: ItemEntry = _selected_entry
    if entry == null:
        return
    var cost: int = RESEARCH_COST.get(entry.item_data.rarity, 500)
    if SaveManager.cash < cost:
        return
    _do_market_research(entry)

# ══ Rows ══════════════════════════════════════════════════════════════════════


func _populate_rows() -> void:
    if SaveManager.storage_items.is_empty():
        _empty_label.visible = true
        return
    _empty_label.visible = false
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


func _show_action_popup(entry: ItemEntry) -> void:
    _action_item_label.text = entry.display_name

    # Unlock button: visible when HOME unlock action is available.
    var action: LayerUnlockAction = entry.current_unlock_action()
    var can_unlock: bool = (
        action != null
        and action.context == LayerUnlockAction.ActionContext.HOME
        and KnowledgeManager.can_advance(entry, LayerUnlockAction.ActionContext.HOME)
    )
    _unlock_btn.visible = can_unlock

    # Market Research: available on any non-veiled item.
    if not entry.is_veiled():
        var cost: int = RESEARCH_COST.get(entry.item_data.rarity, 500)
        _research_btn.visible = true
        _research_btn.text = "Market Research — $%d" % cost
        _research_btn.disabled = SaveManager.cash < cost
    else:
        _research_btn.visible = false

    _action_popup.popup_centered()

# ══ Market research ═══════════════════════════════════════════════════════════


func _do_market_research(entry: ItemEntry) -> void:
    var super_cat_id: String = entry.item_data.category_data.super_category.super_category_id
    var layers_count: int = entry.item_data.identity_layers.size()

    var old_range: float = 0.0
    for i in range(layers_count):
        old_range += entry.knowledge_max[i] - entry.knowledge_min[i]

    var new_min: Array[float] = []
    var new_max: Array[float] = []
    new_min.resize(layers_count)
    new_max.resize(layers_count)
    for i in range(layers_count):
        var depth: int = maxi(0, i - entry.layer_index)
        var price_range: Vector2 = KnowledgeManager.get_price_range(
            super_cat_id,
            entry.item_data.rarity,
            depth,
        )
        new_min[i] = price_range.x
        new_max[i] = price_range.y

    var new_range: float = 0.0
    for i in range(layers_count):
        new_range += new_max[i] - new_min[i]

    var cost: int = RESEARCH_COST.get(entry.item_data.rarity, 500)
    SaveManager.cash -= cost

    if new_range < old_range:
        entry.knowledge_min = new_min
        entry.knowledge_max = new_max

    SaveManager.save()
    _refresh_row(entry)

# ══ Refresh ════════════════════════════════════════════════════════════════════


func _refresh_row(entry: ItemEntry) -> void:
    if _rows.has(entry):
        _rows[entry].refresh()
