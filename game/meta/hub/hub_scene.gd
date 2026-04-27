# hub_scene.gd
# Hub — Entry point between runs.
# Reads: SaveManager.cash, SaveManager.storage_items
extends Control

const DayPassDialogGd = preload("res://game/meta/hub/day_pass_dialog/day_pass_dialog.gd")

# ── Node references ───────────────────────────────────────────────────────────

@onready var _mastery_rank_label: Label = $RootVBox/MasteryRankLabel
@onready var _balance_label: Label = $RootVBox/InfoContainer/BalanceLabel
@onready var _storage_count_label: Label = $RootVBox/InfoContainer/StorageCountLabel
@onready var _next_run_btn: Button = $RootVBox/ButtonsVBox/NextRunButton
@onready var _storage_btn: Button = $RootVBox/ButtonsVBox/StorageButton
@onready var _merchant_btn: Button = $RootVBox/ButtonsVBox/MerchantButton
@onready var _vehicle_btn: Button = $RootVBox/ButtonsVBox/VehicleButton
@onready var _knowledge_btn: Button = $RootVBox/ButtonsVBox/KnowledgeButton
@onready var _day_pass_btn: Button = $RootVBox/ButtonsVBox/DayPassButton
@onready var _day_pass_dialog: DayPassDialogGd = $DayPassDialog

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _next_run_btn.pressed.connect(_on_next_run_pressed)
    _storage_btn.pressed.connect(_on_storage_pressed)
    _merchant_btn.pressed.connect(_on_merchant_pressed)
    _vehicle_btn.pressed.connect(_on_vehicle_pressed)
    _knowledge_btn.pressed.connect(_on_knowledge_pressed)
    _day_pass_btn.pressed.connect(_on_day_pass_pressed)

    _day_pass_dialog.confirmed.connect(_on_day_pass_confirmed)

    _refresh_display()

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_next_run_pressed() -> void:
    GameManager.go_to_location_select()


func _on_storage_pressed() -> void:
    GameManager.go_to_storage()


func _on_merchant_pressed() -> void:
    GameManager.go_to_merchant_hub()


func _on_vehicle_pressed() -> void:
    GameManager.go_to_vehicle_hub()


func _on_knowledge_pressed() -> void:
    GameManager.go_to_knowledge_hub()


func _on_day_pass_pressed() -> void:
    _day_pass_dialog.open()


func _on_day_pass_confirmed(days: int) -> void:
    var summary := MetaManager.advance_days(days)
    GameManager.go_to_day_summary(summary)

# ══ Display ═══════════════════════════════════════════════════════════════════


func _refresh_display() -> void:
    _mastery_rank_label.text = "Mastery Rank:   %d" % KnowledgeManager.get_mastery_rank()
    _balance_label.text = "Balance:   $%d" % SaveManager.cash
    _storage_count_label.text = "Storage:   %d items" % SaveManager.storage_items.size()

    var done_count: int = _completed_research_count()
    if done_count > 0:
        _storage_btn.text = "Storage (%d done)" % done_count
    else:
        _storage_btn.text = "Storage"


func _completed_research_count() -> int:
    var count: int = 0
    for d: Dictionary in SaveManager.research_slots:
        if bool(d.get("completed", false)) and int(d.get("item_id", -1)) != -1:
            count += 1
    return count
