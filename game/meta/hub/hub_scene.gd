# hub_scene.gd
# Hub — Entry point between runs. Manages the 3-slot day structure.
# Each _ready() call checks the current slot state and either presents the next
# activity chooser or auto-ends the day when all slots are spent.
extends Control

# ── Slot labels ───────────────────────────────────────────────────────────────

const SLOT_NAMES: Array[String] = ["", "Morning", "Afternoon", "Evening"]

# ── Node references ───────────────────────────────────────────────────────────

@onready var _mastery_rank_label: Label = $RootVBox/MasteryRankLabel
@onready var _balance_label: Label = $RootVBox/InfoContainer/BalanceLabel
@onready var _storage_count_label: Label = $RootVBox/InfoContainer/StorageCountLabel
@onready var _slot_label: Label = $RootVBox/SlotLabel

# Activity buttons — repurposed from the original layout.
# NextRunButton → Auction (slot 1 only)
# StorageButton → Storage (any slot)
# MerchantButton → Open Shop (any slot)
@onready var _next_run_btn: Button = $RootVBox/ButtonsVBox/NextRunButton
@onready var _storage_btn: Button = $RootVBox/ButtonsVBox/StorageButton
@onready var _sell_btn: Button = $RootVBox/ButtonsVBox/MerchantButton
@onready var _vehicle_btn: Button = $RootVBox/ButtonsVBox/VehicleButton
@onready var _knowledge_btn: Button = $RootVBox/ButtonsVBox/KnowledgeButton

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _next_run_btn.pressed.connect(_on_auction_pressed)
    _storage_btn.pressed.connect(_on_storage_pressed)
    _sell_btn.pressed.connect(_on_open_shop_pressed)
    _vehicle_btn.pressed.connect(_on_vehicle_pressed)
    _knowledge_btn.pressed.connect(_on_knowledge_pressed)

    # If all slots are spent, end the day immediately instead of showing the hub.
    if SaveManager.current_slot > 3:
        _end_day_and_navigate()
        return

    _refresh_display()

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_auction_pressed() -> void:
    if SaveManager.current_slot != 1:
        return
    GameManager.go_to_location_select()


func _on_storage_pressed() -> void:
    MetaManager.begin_storage_slot()
    GameManager.go_to_storage()


func _on_open_shop_pressed() -> void:
    var selling_slots: int = 4 - SaveManager.current_slot
    MetaManager.begin_open_shop(selling_slots)
    GameManager.go_to_customer_sell()


func _on_vehicle_pressed() -> void:
    GameManager.go_to_vehicle_hub()


func _on_knowledge_pressed() -> void:
    GameManager.go_to_knowledge_hub()

# ══ Day ending ════════════════════════════════════════════════════════════════


func _end_day_and_navigate() -> void:
    var summary := MetaManager.end_day()
    GameManager.go_to_day_summary(summary)

# ══ Display ═══════════════════════════════════════════════════════════════════


func _refresh_display() -> void:
    _mastery_rank_label.text = "Mastery Rank:   %d" % KnowledgeManager.get_mastery_rank()
    _balance_label.text = "Balance:   $%d" % SaveManager.cash
    _storage_count_label.text = "Storage:   %d items" % SaveManager.storage_items.size()

    _refresh_slot_label()
    _refresh_activity_buttons()


func _refresh_slot_label() -> void:
    var slot: int = SaveManager.current_slot
    var tray: String = ""
    for i: int in range(1, 4):
        var sname: String = SLOT_NAMES[i]
        if i < slot:
            tray += "● %s  " % sname
        elif i == slot:
            tray += "► %s  " % sname
        else:
            tray += "○ %s  " % sname
    _slot_label.text = "Day %d   |   %s" % [SaveManager.current_day, tray.strip_edges()]


func _refresh_activity_buttons() -> void:
    var slot: int = SaveManager.current_slot

    # Auction: Morning (slot 1) only.
    _next_run_btn.disabled = (slot != 1)
    _next_run_btn.tooltip_text = "" if slot == 1 else "Auction is only available in the Morning slot"

    # Storage: any slot, no restriction.
    _storage_btn.text = "Storage  (work items, %d AP)" % Economy.STORAGE_AP_MAX

    # Open Shop: label shows how many selling slots the commitment covers.
    var selling_slots: int = 4 - slot
    _sell_btn.text = "Open Shop  (%d-slot window)" % selling_slots
