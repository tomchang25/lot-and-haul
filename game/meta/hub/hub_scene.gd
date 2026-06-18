# hub_scene.gd
# Hub — Entry point between runs. Manages the two-slot (Day/Night) activity
# model. Each _ready() checks the slot state and either presents the activity
# chooser or auto-ends the day when all slots are spent.
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────

const SLOT_NAMES: Array[String] = ["", "Day", "Night"]

# ── Node references — display ─────────────────────────────────────────────────

@onready var _mastery_rank_label: Label = $RootVBox/MasteryRankLabel
@onready var _balance_label: Label = $RootVBox/InfoContainer/BalanceLabel
@onready var _storage_count_label: Label = $RootVBox/InfoContainer/StorageCountLabel
@onready var _slot_label: Label = $RootVBox/SlotLabel

# ── Node references — utility buttons ─────────────────────────────────────────

@onready var _vehicle_btn: Button = $RootVBox/ButtonsVBox/VehicleButton
@onready var _knowledge_btn: Button = $RootVBox/ButtonsVBox/KnowledgeButton
@onready var _debug_container: DebugButtonContainer = $DebugButtonContainer

# ── Node references — activity chooser ────────────────────────────────────────

@onready var _activity_btn: Button = $RootVBox/ButtonsVBox/ActivityButton
@onready var _chooser: PanelContainer = $ActivityChooser
@onready var _auction_btn: Button = $ActivityChooser/ChooserMargin/PopupVBox/AuctionButton
@onready var _storage_btn: Button = $ActivityChooser/ChooserMargin/PopupVBox/StorageButton
@onready var _sell_btn: Button = $ActivityChooser/ChooserMargin/PopupVBox/SellingButton
@onready var _cancel_btn: Button = $ActivityChooser/ChooserMargin/PopupVBox/CancelButton

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _activity_btn.pressed.connect(_on_activity_pressed)
    _vehicle_btn.pressed.connect(_on_vehicle_pressed)
    _knowledge_btn.pressed.connect(_on_knowledge_pressed)

    _auction_btn.pressed.connect(_on_auction_chosen)
    _storage_btn.pressed.connect(_on_storage_chosen)
    _sell_btn.pressed.connect(_on_sell_chosen)
    _cancel_btn.pressed.connect(_on_chooser_cancelled)

    if MetaManager.slot.current_slot > SlotStore.SLOT_NIGHT:
        _end_day_and_navigate.call_deferred()
        return

    _refresh_display()
    _debug_container.storage_changed.connect(_refresh_display)

    Director.register_scene(
        "hub",
        {
            "slot_label": _slot_label,
            "activity_btn": _activity_btn,
            "auction_btn": _auction_btn,
            "storage_btn": _storage_btn,
            "sell_btn": _sell_btn,
        },
    )

# ══ Signal handlers — activity chooser ════════════════════════════════════════


func _on_activity_pressed() -> void:
    _show_chooser()


func _on_auction_chosen() -> void:
    _close_chooser()
    SceneRouter.go_to_location_select()


func _on_storage_chosen() -> void:
    _close_chooser()
    MetaManager.begin_storage_slot()
    SceneRouter.go_to_storage()


func _on_sell_chosen() -> void:
    _close_chooser()
    MetaManager.begin_open_shop()
    SceneRouter.go_to_customer_sell()


func _on_chooser_cancelled() -> void:
    _close_chooser()

# ══ Signal handlers — utility navigation ══════════════════════════════════════


func _on_vehicle_pressed() -> void:
    SceneRouter.go_to_vehicle_hub()


func _on_knowledge_pressed() -> void:
    SceneRouter.go_to_knowledge_hub()

# ══ Day ending ════════════════════════════════════════════════════════════════


func _end_day_and_navigate() -> void:
    var summary := MetaManager.end_day()
    SceneRouter.go_to_day_summary(summary)

# ══ Chooser ═══════════════════════════════════════════════════════════════════


func _show_chooser() -> void:
    var is_day: bool = MetaManager.slot.current_slot == SlotStore.SLOT_DAY
    _auction_btn.visible = is_day
    _chooser.show()

    Director.register_anchor("auction_btn", _auction_btn)
    Director.register_anchor("storage_btn", _storage_btn)
    Director.register_anchor("sell_btn", _sell_btn)


func _close_chooser() -> void:
    _chooser.hide()

    Director.unregister_anchor("auction_btn")
    Director.unregister_anchor("storage_btn")
    Director.unregister_anchor("sell_btn")

# ══ Display ═══════════════════════════════════════════════════════════════════


func _refresh_display() -> void:
    _mastery_rank_label.text = "Mastery Rank:   %d" % KnowledgeManager.get_mastery_rank()
    _balance_label.text = "Balance:   $%d" % MetaManager.economy.cash
    _storage_count_label.text = "Storage:   %d items" % MetaManager.storage.storage_items.size()

    _refresh_slot_label()
    _refresh_activity_button()


func _refresh_slot_label() -> void:
    var slot: int = MetaManager.slot.current_slot
    var tray: String = ""
    for i: int in SLOT_NAMES.size():
        if i == 0:
            continue
        if i < slot:
            tray += "* %s  " % SLOT_NAMES[i]
        elif i == slot:
            tray += "> %s  " % SLOT_NAMES[i]
        else:
            tray += "- %s  " % SLOT_NAMES[i]
    _slot_label.text = "Day %d   |   %s" % [MetaManager.progress.current_day, tray.strip_edges()]


func _refresh_activity_button() -> void:
    var slot: int = MetaManager.slot.current_slot
    # day-ending (>= SLOT_DAY_ENDING) is not a displayable slot name; the hub
    # auto-ends the day on entry, so this branch is normally unreachable. The
    # guard is defensive in case a future code path calls _refresh_display()
    # after the slot has been advanced past Night.
    var slot_name: String = ""
    if slot >= 1 and slot < SLOT_NAMES.size():
        slot_name = SLOT_NAMES[slot]
    else:
        ToastManager.show_warning("Invalid slot: %d" % slot)

    _activity_btn.text = "Activity  (%s)" % slot_name
