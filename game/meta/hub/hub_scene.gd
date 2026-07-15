# hub_scene.gd
# Hub — Entry point between runs. Manages the two-slot (Day/Night) activity
# model. Each _ready() checks the slot state and either presents the activity
# chooser or auto-ends the day when all slots are spent.
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────

const SLOT_NAMES: Array[String] = ["", "Day", "Night"]


static func _slot_name(i: int) -> String:
    match i:
        1:
            return TranslationServer.translate("UI_DAY_SLOT_NAME")
        2:
            return TranslationServer.translate("UI_NIGHT_SLOT_NAME")
    return ""

# ── Node references — display ─────────────────────────────────────────────────

@onready var _mastery_rank_label: Label = $RootVBox/MasteryRankLabel
@onready var _balance_label: Label = $RootVBox/InfoContainer/BalanceLabel
@onready var _storage_count_label: Label = $RootVBox/InfoContainer/StorageCountLabel
@onready var _slot_label: Label = $RootVBox/SlotLabel

# ── Node references — utility buttons ─────────────────────────────────────────

@onready var _vehicle_btn: Button = $RootVBox/ButtonsVBox/VehicleButton
@onready var _knowledge_btn: Button = $RootVBox/ButtonsVBox/KnowledgeButton
@onready var _debug_panel: DebugPanel = %DebugPanel

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
    GameplayOverride.override_changed.connect(_on_gameplay_override_changed)

    # Register anchors before the slot check so tutorials that wait for
    # hub (SCENE_ENTERED) can advance even when this visit immediately
    # ends the day.
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

    if MetaSystem.slot.current_slot > SlotStore.SLOT_NIGHT:
        _end_day_and_navigate.call_deferred()
        return

    _refresh_display()
    _wire_debug_panel()

# ══ Signal handlers — activity chooser ════════════════════════════════════════


func _on_activity_pressed() -> void:
    _show_chooser()


func _on_auction_chosen() -> void:
    _close_chooser()
    EventBus.tutorial_event.emit(TutorialEvents.ACTIVITY_CHOSEN, { })
    SceneRouter.go_to_location_select()


func _on_storage_chosen() -> void:
    _close_chooser()
    EventBus.tutorial_event.emit(TutorialEvents.ACTIVITY_CHOSEN, { })
    MetaSystem.begin_storage_slot()
    SceneRouter.go_to_storage()


func _on_sell_chosen() -> void:
    _close_chooser()
    EventBus.tutorial_event.emit(TutorialEvents.ACTIVITY_CHOSEN, { })
    MetaSystem.begin_open_shop()
    SceneRouter.go_to_customer_sell()


func _on_chooser_cancelled() -> void:
    _close_chooser()


func _on_gameplay_override_changed(id: StringName, _active: bool, _payload: Variant) -> void:
    if id != GameplayOverride.FORCED_ACTIVITY:
        return
    _refresh_activity_choice_locks()

# ══ Signal handlers — utility navigation ══════════════════════════════════════


func _on_vehicle_pressed() -> void:
    SceneRouter.go_to_vehicle_hub()


func _on_knowledge_pressed() -> void:
    SceneRouter.go_to_knowledge_hub()

# ══ Day ending ════════════════════════════════════════════════════════════════


func _end_day_and_navigate() -> void:
    var summary := MetaSystem.end_day()
    SceneRouter.go_to_day_summary(summary)

# ══ Chooser ═══════════════════════════════════════════════════════════════════


func _show_chooser() -> void:
    var is_day: bool = MetaSystem.slot.current_slot == SlotStore.SLOT_DAY
    _auction_btn.visible = is_day
    _storage_btn.visible = true
    _sell_btn.visible = true
    _cancel_btn.visible = true
    _refresh_activity_choice_locks()

    _chooser.show()

    Director.register_anchor("auction_btn", _auction_btn)
    Director.register_anchor("storage_btn", _storage_btn)
    Director.register_anchor("sell_btn", _sell_btn)

    EventBus.tutorial_event.emit(TutorialEvents.CHOOSER_OPENED, { })


func _close_chooser() -> void:
    _chooser.hide()

    Director.unregister_anchor("auction_btn")
    Director.unregister_anchor("storage_btn")
    Director.unregister_anchor("sell_btn")


func _refresh_activity_choice_locks() -> void:
    # Onboarding gating: disable non-target activity options.
    _auction_btn.disabled = false
    _storage_btn.disabled = false
    _sell_btn.disabled = false
    var target := GameplayOverride.payload(GameplayOverride.FORCED_ACTIVITY)
    if target == &"auction":
        _storage_btn.disabled = true
        _sell_btn.disabled = true
    elif target == &"storage":
        _auction_btn.disabled = true
        _sell_btn.disabled = true
    elif target == &"selling":
        _auction_btn.disabled = true
        _storage_btn.disabled = true

# ══ Display ═══════════════════════════════════════════════════════════════════


func _refresh_display() -> void:
    _mastery_rank_label.text = TranslationServer.translate("UI_MASTERY_RANK_LABEL") % KnowledgeSystem.get_mastery_rank()
    _balance_label.text = TranslationServer.translate("UI_BALANCE_LABEL") % MetaSystem.economy.cash
    _storage_count_label.text = TranslationServer.translate("UI_STORAGE_COUNT_LABEL") % MetaSystem.storage.storage_items.size()

    _refresh_slot_label()
    _refresh_activity_button()


func _refresh_slot_label() -> void:
    var slot: int = MetaSystem.slot.current_slot
    var tray: String = ""
    for i: int in SLOT_NAMES.size():
        if i == 0:
            continue
        var slot_label := _slot_name(i)
        if i < slot:
            tray += "* %s  " % slot_label
        elif i == slot:
            tray += "> %s  " % slot_label
        else:
            tray += "- %s  " % slot_label
    _slot_label.text = "%s   |   %s" % [TranslationServer.translate("UI_DAY_LABEL") % MetaSystem.progress.current_day, tray.strip_edges()]


func _refresh_activity_button() -> void:
    var slot: int = MetaSystem.slot.current_slot
    # day-ending (>= SLOT_DAY_ENDING) is not a displayable slot name; the hub
    # auto-ends the day on entry, so this branch is normally unreachable. The
    # guard is defensive in case a future code path calls _refresh_display()
    # after the slot has been advanced past Night.
    var slot_name: String = ""
    if slot >= 1 and slot < SLOT_NAMES.size():
        slot_name = _slot_name(slot)
    else:
        ToastManager.show_warning("Invalid slot: %d" % slot)

    _activity_btn.text = TranslationServer.translate("UI_ACTIVITY_BTN") % slot_name

# ══ Debug (see dev/standards/debug_standard.md §4a/§5) ═════════════════════════


func _wire_debug_panel() -> void:
    _debug_panel.add_action(TranslationServer.translate("UI_DEBUG_ADD_RANDOM"), _on_debug_add_item)
    _debug_panel.add_action(TranslationServer.translate("UI_DEBUG_CLEAR_STORAGE"), _on_debug_clear_storage)


func _on_debug_add_item() -> void:
    if not Debug.enabled:
        return
    var categories: Array[CategoryData] = CategoryRegistry.get_all_categories()
    if categories.is_empty():
        return
    var cat: CategoryData = categories[randi() % categories.size()]
    var rarity: Array[Economy.Rarity] = [Economy.Rarity.COMMON, Economy.Rarity.RARE, Economy.Rarity.LEGENDARY]
    var entry: ItemEntry = ItemGenerator.draw(cat, { }, rarity[randi() % rarity.size()])
    if entry == null:
        return
    entry.unveil()
    entry.auto_reveal_all_surface()
    MetaSystem.register_storage_items([entry])
    _refresh_display()


func _on_debug_clear_storage() -> void:
    if not Debug.enabled:
        return
    MetaSystem.clear_all_storage()
    _refresh_display()
