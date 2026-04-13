# hub_scene.gd
# Hub — Entry point between runs.
# Reads: SaveManager.cash, SaveManager.storage_items
extends Control

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
@onready var _day_pass_confirm: ConfirmationDialog = $DayPassConfirm

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _next_run_btn.pressed.connect(_on_next_run_pressed)
    _storage_btn.pressed.connect(_on_storage_pressed)
    _merchant_btn.pressed.connect(_on_merchant_pressed)
    _vehicle_btn.pressed.connect(_on_vehicle_pressed)
    _knowledge_btn.pressed.connect(_on_knowledge_pressed)
    _day_pass_btn.pressed.connect(_on_day_pass_pressed)

    _day_pass_confirm.confirmed.connect(_on_day_pass_confirmed)

    SaveManager.load()

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
    _day_pass_confirm.popup_centered()


func _on_day_pass_confirmed() -> void:
    _do_day_pass()

# ══ Day Pass ══════════════════════════════════════════════════════════════════


func _do_day_pass() -> void:
    var summary := SaveManager.advance_days(1)
    GameManager.go_to_day_summary(summary)

# ══ Display ═══════════════════════════════════════════════════════════════════


func _refresh_display() -> void:
    _mastery_rank_label.text = "Mastery Rank:   %d" % KnowledgeManager.get_mastery_rank()
    _balance_label.text = "Balance:   $%d" % SaveManager.cash
    _storage_count_label.text = "Storage:   %d items" % SaveManager.storage_items.size()
