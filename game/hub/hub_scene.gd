# hub_scene.gd
# Hub — Entry point between runs.
# Reads: SaveManager.cash, SaveManager.storage_items
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────

const DayPassPopupScene: PackedScene = preload("res://game/hub/day_pass_popup.tscn")
const DAILY_BASE_COST: int = 100

# ── Node references ───────────────────────────────────────────────────────────

@onready var _balance_label: Label = $RootVBox/InfoContainer/BalanceLabel
@onready var _storage_count_label: Label = $RootVBox/InfoContainer/StorageCountLabel
@onready var _next_run_popup: ConfirmationDialog = $NextRunPopup
@onready var _van_popup: AcceptDialog = $VanPopup
@onready var _knowledge_popup: AcceptDialog = $KnowledgePopup
@onready var _next_run_btn: Button = $RootVBox/ButtonsVBox/NextRunButton
@onready var _storage_btn: Button = $RootVBox/ButtonsVBox/StorageButton
@onready var _pawn_shop_btn: Button = $RootVBox/ButtonsVBox/PawnShopButton
@onready var _van_btn: Button = $RootVBox/ButtonsVBox/VanButton
@onready var _knowledge_btn: Button = $RootVBox/ButtonsVBox/KnowledgeButton
@onready var _day_pass_btn: Button = $RootVBox/ButtonsVBox/DayPassButton
@onready var _day_pass_confirm: ConfirmationDialog = $DayPassConfirm

# ── State ─────────────────────────────────────────────────────────────────────

var _day_pass_popup: DayPassPopup = null

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _next_run_btn.pressed.connect(_on_next_run_pressed)
    _storage_btn.pressed.connect(_on_storage_pressed)
    _pawn_shop_btn.pressed.connect(_on_pawn_shop_pressed)
    _van_btn.pressed.connect(_on_van_pressed)
    _knowledge_btn.pressed.connect(_on_knowledge_pressed)
    _day_pass_btn.pressed.connect(_on_day_pass_pressed)

    _next_run_popup.confirmed.connect(_on_next_run_confirmed)
    _day_pass_confirm.confirmed.connect(_on_day_pass_confirmed)

    _day_pass_popup = DayPassPopupScene.instantiate()
    add_child(_day_pass_popup)
    _day_pass_popup.dismissed.connect(_refresh_display)

    SaveManager.load()

    _refresh_display()

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_next_run_pressed() -> void:
    _next_run_popup.popup_centered()


func _on_next_run_confirmed() -> void:
    GameManager.go_to_warehouse_entry()


func _on_storage_pressed() -> void:
    GameManager.go_to_storage()


func _on_pawn_shop_pressed() -> void:
    GameManager.go_to_pawn_shop()


func _on_van_pressed() -> void:
    _van_popup.popup_centered()


func _on_knowledge_pressed() -> void:
    _knowledge_popup.popup_centered()


func _on_day_pass_pressed() -> void:
    _day_pass_confirm.popup_centered()


func _on_day_pass_confirmed() -> void:
    _do_day_pass()

# ══ Day Pass ══════════════════════════════════════════════════════════════════


func _do_day_pass() -> void:
    var completed: Array[Dictionary] = []
    var remaining: Array = []

    for d: Dictionary in SaveManager.active_actions:
        var action := ActiveActionEntry.from_dict(d)
        action.days_remaining -= 1
        if action.days_remaining <= 0:
            _apply_effect(action)
            var entry: ItemEntry = _find_storage_entry(action.item_id)
            completed.append(
                {
                    "name": entry.display_name if entry != null else "Unknown",
                    "effect": _effect_label(action.action_type),
                },
            )
        else:
            remaining.append(action.to_dict())

    SaveManager.active_actions = remaining
    SaveManager.cash -= DAILY_BASE_COST
    SaveManager.current_day += 1
    SaveManager.save()

    _day_pass_popup.populate(
        {
            "new_day": SaveManager.current_day,
            "cash_spent": DAILY_BASE_COST,
            "completed": completed,
        },
    )
    _day_pass_popup.popup_centered()


func _apply_effect(action: ActiveActionEntry) -> void:
    var entry: ItemEntry = _find_storage_entry(action.item_id)
    if entry == null:
        return
    match action.action_type:
        ActiveActionEntry.ActionType.MARKET_RESEARCH:
            KnowledgeManager.apply_market_research(entry)
        ActiveActionEntry.ActionType.UNLOCK:
            entry.layer_index += 1
            KnowledgeManager.add_category_points(
                entry.item_data.category_data.category_id,
                entry.item_data.rarity,
                KnowledgeManager.KnowledgeAction.REVEAL,
            )


func _find_storage_entry(item_id: int) -> ItemEntry:
    for entry: ItemEntry in SaveManager.storage_items:
        if entry.id == item_id:
            return entry
    return null


func _effect_label(type: ActiveActionEntry.ActionType) -> String:
    match type:
        ActiveActionEntry.ActionType.MARKET_RESEARCH:
            return "Market Research done"
        ActiveActionEntry.ActionType.UNLOCK:
            return "Layer unlocked"
    return "Done"

# ══ Display ═══════════════════════════════════════════════════════════════════


func _refresh_display() -> void:
    _balance_label.text = "Balance:   $%d" % SaveManager.cash
    _storage_count_label.text = "Storage:   %d items" % SaveManager.storage_items.size()
