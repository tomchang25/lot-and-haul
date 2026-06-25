# storage_scene.gd
# Storage — Displays stored items and lets the player spend AP on Repair,
# Restore, and Research actions immediately. No slot-assignment UI.
# V2 layout: shared ItemBrowserPanel (Card/Table modes) + detail rail (right).
# Reads:  MetaSystem.storage.storage_items, MetaSystem.slot.storage_ap
# Writes: MetaSystem.repair_item, MetaSystem.restore_item, MetaSystem.research_item
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────

const STORAGE_RESEARCH: UiAudioEvent = preload("res://data/tres/audio_events/storage_research.tres")
const STORAGE_REPAIR_RESTORE: UiAudioEvent = preload("res://data/tres/audio_events/storage_repair_restore.tres")
const CANCEL: UiAudioEvent = preload("res://data/tres/audio_events/cancel_dismiss.tres")

const STORAGE_COLUMNS: Array = [
    ItemRow.Column.NAME,
    ItemRow.Column.CONDITION,
    ItemRow.Column.ESTIMATED_VALUE,
    ItemRow.Column.RARITY,
]

# ── State ─────────────────────────────────────────────────────────────────────

# ── Node references ───────────────────────────────────────────────────────────

# Left — browser
@onready var _item_browser: ItemBrowserPanel = %ItemBrowser

# Left — footer
@onready var _footer_status_label: Label = %FooterStatusLabel
@onready var _back_btn: Button = %BackButton

# Right — AP bar and detail
@onready var _ap_label: Label = %APLabel
@onready var _detail_section: VBoxContainer = %DetailSection
@onready var _detail_panel: ItemDetailPanel = %DetailPanel
@onready var _progress_label: Label = %ProgressLabel
@onready var _no_selection_label: Label = %NoSelectionLabel

# Right — action buttons
@onready var _action_grid: GridContainer = %ActionGrid
@onready var _repair_btn: Button = %RepairButton
@onready var _research_btn: Button = %ResearchButton
@onready var _restore_btn: Button = %RestoreButton

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _back_btn.pressed.connect(_on_back_pressed)
    _back_btn.press_event = CANCEL
    _repair_btn.pressed.connect(_on_repair_pressed)
    _research_btn.pressed.connect(_on_research_pressed)
    _restore_btn.pressed.connect(_on_restore_pressed)

    _item_browser.entry_pressed.connect(_on_entry_pressed)

    _refresh_ap_label()
    _populate_browser()
    _refresh_detail()

    # Auto-select: restore saved session selection, then fall back to first item.
    var _storage_items := MetaSystem.storage.storage_items
    if not _storage_items.is_empty():
        var selected: ItemEntry = _storage_items[0]
        var saved_id := MetaSystem.storage_session.selected_entry_id
        if saved_id >= 0:
            for e in _storage_items:
                if e.id == saved_id:
                    selected = e
                    break
        _item_browser.set_selected(selected)
        _refresh_detail()

    Director.register_scene(
        "storage",
        {
            "item_browser": _item_browser,
            "detail_rail": _detail_section,
            "repair_btn": _repair_btn,
            "restore_btn": _restore_btn,
            "research_btn": _research_btn,
            "ap_label": _ap_label,
            "leave_btn": _back_btn,
        },
    )

# ══ Signal handlers ═══════════════════════════════════════════════════════════


func _on_back_pressed() -> void:
    MetaSystem.close_storage_session()
    SceneRouter.go_to_hub()


func _on_entry_pressed(_entry: ItemEntry) -> void:
    _refresh_detail()


func _on_repair_pressed() -> void:
    var entry := _item_browser.get_selected()
    if entry == null:
        return
    if MetaSystem.repair_item(entry):
        AudioManager.play_event(STORAGE_REPAIR_RESTORE)
        _item_browser.refresh_entry(entry)
        _refresh_ap_label()
        _refresh_detail()
        EventBus.tutorial_event.emit(TutorialEvents.STORAGE_CONDITION_IMPROVED, { })


func _on_research_pressed() -> void:
    var entry := _item_browser.get_selected()
    if entry == null:
        return
    if MetaSystem.research_item(entry):
        AudioManager.play_event(STORAGE_RESEARCH)
        _item_browser.refresh_entry(entry)
        _refresh_ap_label()
        _refresh_detail()
        EventBus.tutorial_event.emit(TutorialEvents.STORAGE_RESEARCH_PERFORMED, { })


func _on_restore_pressed() -> void:
    var entry := _item_browser.get_selected()
    if entry == null:
        return
    if MetaSystem.restore_item(entry):
        AudioManager.play_event(STORAGE_REPAIR_RESTORE)
        _item_browser.refresh_entry(entry)
        _refresh_ap_label()
        _refresh_detail()
        EventBus.tutorial_event.emit(TutorialEvents.STORAGE_CONDITION_IMPROVED, { })

# ══ AP label ══════════════════════════════════════════════════════════════════


func _refresh_ap_label() -> void:
    var ap: int = MetaSystem.slot.storage_ap
    var max_ap: int = MetaSystem.slot.storage_ap_max
    _ap_label.text = TranslationServer.translate("UI_AP_LABEL") % [ap, max_ap]
    if ap == 0:
        _ap_label.add_theme_color_override("font_color", Color(0.6, 0.4, 0.4))
    elif ap <= 4:
        _ap_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.3))
    else:
        _ap_label.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))

# ══ Browser ═══════════════════════════════════════════════════════════════════


func _populate_browser() -> void:
    var items: Array = MetaSystem.storage.storage_items
    _item_browser.setup(STORAGE_COLUMNS)
    _item_browser.populate(items)

    var count: int = items.size()
    _footer_status_label.text = TranslationServer.translate("UI_ITEM_COUNT") % count

# ══ Detail panel ══════════════════════════════════════════════════════════════


func _refresh_detail() -> void:
    var entry := _item_browser.get_selected()
    var has_selection: bool = entry != null
    _no_selection_label.visible = not has_selection
    _action_grid.visible = has_selection
    _progress_label.visible = false

    if not has_selection:
        _detail_panel.setup(null)
        return

    _detail_panel.setup(entry, true)

    # ── Research progress ─────────────────────────────────────────────────────
    if entry.has_unrevealed_hidden() and not entry.research_progress.is_empty():
        for clue: ClueData in entry.hidden_clues:
            if entry.revealed_clue_ids.has(clue.clue_id):
                continue
            var progress: int = int(entry.research_progress.get(clue.clue_id, 0))
            if progress > 0:
                _progress_label.text = TranslationServer.translate("UI_RESEARCH_PROGRESS") % [progress, clue.dc]
                _progress_label.visible = true
            break

    # ── Action buttons ────────────────────────────────────────────────────────
    _configure_action_buttons(entry)


func _configure_action_buttons(entry: ItemEntry) -> void:
    var ap: int = MetaSystem.slot.storage_ap

    # ── Repair ──────────────────────────────────────────────────────────────
    var repair_done: bool = ResearchSlot.is_repair_complete(entry)
    var can_repair: bool = ap >= Economy.REPAIR_AP_COST and not repair_done
    _repair_btn.disabled = not can_repair
    _repair_btn.text = TranslationServer.translate("UI_REPAIR_ACTION_LABEL") % Economy.REPAIR_AP_COST
    if repair_done:
        _repair_btn.tooltip_text = TranslationServer.translate("UI_REPAIR_DONE_TOOLTIP")
    elif ap < Economy.REPAIR_AP_COST:
        _repair_btn.tooltip_text = TranslationServer.translate("UI_REPAIR_AP_TOOLTIP") % Economy.REPAIR_AP_COST
    else:
        _repair_btn.tooltip_text = ""

    # ── Restore ──────────────────────────────────────────────────────────────
    var restore_done: bool = ResearchSlot.is_restore_complete(entry)
    var not_ready: bool = entry.condition < 0.5
    var can_restore: bool = ap >= Economy.RESTORE_AP_COST and not not_ready and not restore_done
    _restore_btn.disabled = not can_restore
    _restore_btn.text = TranslationServer.translate("UI_RESTORE_ACTION_LABEL") % Economy.RESTORE_AP_COST
    if not_ready:
        _restore_btn.tooltip_text = TranslationServer.translate("UI_RESTORE_REPAIR_TOOLTIP")
    elif restore_done:
        _restore_btn.tooltip_text = TranslationServer.translate("UI_RESTORE_DONE_TOOLTIP")
    elif ap < Economy.RESTORE_AP_COST:
        _restore_btn.tooltip_text = TranslationServer.translate("UI_RESTORE_AP_TOOLTIP") % Economy.RESTORE_AP_COST
    else:
        _restore_btn.tooltip_text = ""

    # Show only Repair or Restore (whichever applies), never both.
    if not repair_done:
        _repair_btn.visible = true
        _restore_btn.visible = false
    elif not restore_done:
        _repair_btn.visible = false
        _restore_btn.visible = true
    else:
        _repair_btn.visible = false
        _restore_btn.visible = true

    # ── Research ─────────────────────────────────────────────────────────────
    var has_hidden: bool = entry.has_unrevealed_hidden()
    var research_needs_repair: bool = entry.condition < 0.5
    var can_research: bool = (
        ap >= Economy.RESEARCH_AP_COST
        and has_hidden
        and not research_needs_repair
    )
    _research_btn.disabled = not can_research
    _research_btn.text = TranslationServer.translate("UI_RESEARCH_ACTION_LABEL") % Economy.RESEARCH_AP_COST
    if not has_hidden:
        _research_btn.tooltip_text = TranslationServer.translate("UI_RESEARCH_DONE_TOOLTIP")
    elif research_needs_repair:
        _research_btn.tooltip_text = TranslationServer.translate("UI_RESEARCH_REPAIR_TOOLTIP")
    elif ap < Economy.RESEARCH_AP_COST:
        _research_btn.tooltip_text = TranslationServer.translate("UI_RESEARCH_AP_TOOLTIP") % Economy.RESEARCH_AP_COST
    else:
        _research_btn.tooltip_text = ""
