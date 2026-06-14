# storage_scene.gd
# Storage — Displays stored items and lets the player spend AP on Repair,
# Restore, and Research actions immediately. No slot-assignment UI.
# V2 layout: dense table (left) + detail rail (right) with AP bar + action buttons.
# Reads:  MetaManager.storage.storage_items, MetaManager.slot.storage_ap
# Writes: MetaManager.repair_item, MetaManager.restore_item, MetaManager.research_item
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────

const ItemRowTooltipScene: PackedScene = preload("res://game/shared/item_display/item_row_tooltip.tscn")
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

var _tooltip: ItemRowTooltip = null
var _selected_entry: ItemEntry = null

# ── Node references ───────────────────────────────────────────────────────────

# Left — table
@onready var _item_list_panel: ItemListPanel = %ItemListPanel
@onready var _empty_label: Label = %EmptyLabel

# Left — footer
@onready var _footer_status_label: Label = %FooterStatusLabel
@onready var _back_btn: Button = %BackButton

# Right — AP bar and detail
@onready var _ap_label: Label = %APLabel
@onready var _detail_section: VBoxContainer = %DetailSection
@onready var _detail_name_label: Label = %DetailNameLabel
@onready var _auth_tag_label: Label = %AuthTagLabel
@onready var _detail_category_label: Label = %DetailCategoryLabel
@onready var _detail_rarity_label: Label = %DetailRarityLabel
@onready var _detail_rarity_hbox: HBoxContainer = %DetailRarityHBox
@onready var _detail_stats_hbox: HBoxContainer = %DetailStatsHBox
@onready var _convergence_panel: PanelContainer = %ConvergencePanel
@onready var _detail_cond_value: Label = %CondValueLabel
@onready var _detail_est_value: Label = %ValueValueLabel
@onready var _detail_conv_ratio: Label = %ConvRatioLabel
@onready var _progress_label: Label = %ProgressLabel
@onready var _no_selection_label: Label = %NoSelectionLabel

# Right — action buttons
@onready var _action_grid: GridContainer = %ActionGrid
@onready var _repair_btn: Button = %RepairButton
@onready var _research_btn: Button = %ResearchButton
@onready var _restore_btn: Button = %RestoreButton
@onready var _value_title_label: Label = %ValueTitleLabel

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _tooltip = ItemRowTooltipScene.instantiate()
    add_child(_tooltip)

    _back_btn.pressed.connect(_on_back_pressed)
    _back_btn.press_event = CANCEL
    _repair_btn.pressed.connect(_on_repair_pressed)
    _research_btn.pressed.connect(_on_research_pressed)
    _restore_btn.pressed.connect(_on_restore_pressed)

    _item_list_panel.row_pressed.connect(_on_row_pressed)
    _item_list_panel.tooltip_requested.connect(_on_row_tooltip_requested)
    _item_list_panel.tooltip_dismissed.connect(_tooltip.hide_tooltip)

    _refresh_ap_label()
    _populate_rows()
    _refresh_detail()

    Director.register_scene(
        "storage",
        {
            "item_table": _item_list_panel,
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
    # Slot already committed on entry — leaving returns to hub for the next slot.
    SceneRouter.go_to_hub()


func _on_row_pressed(entry: ItemEntry) -> void:
    _select_entry(entry)


func _on_row_tooltip_requested(
        entry: ItemEntry,
        anchor: Rect2,
) -> void:
    _tooltip.show_for(entry, anchor)


func _on_repair_pressed() -> void:
    if _selected_entry == null:
        return
    if MetaManager.repair_item(_selected_entry):
        AudioManager.play_event(STORAGE_REPAIR_RESTORE)
        _refresh_row(_selected_entry)
        _refresh_ap_label()
        _refresh_detail()


func _on_research_pressed() -> void:
    if _selected_entry == null:
        return
    if MetaManager.research_item(_selected_entry):
        AudioManager.play_event(STORAGE_RESEARCH)
        _refresh_row(_selected_entry)
        _refresh_ap_label()
        _refresh_detail()


func _on_restore_pressed() -> void:
    if _selected_entry == null:
        return
    if MetaManager.restore_item(_selected_entry):
        AudioManager.play_event(STORAGE_REPAIR_RESTORE)
        _refresh_row(_selected_entry)
        _refresh_ap_label()
        _refresh_detail()

# ══ AP label ══════════════════════════════════════════════════════════════════


func _refresh_ap_label() -> void:
    var ap: int = MetaManager.slot.storage_ap
    var max_ap: int = Economy.STORAGE_AP_MAX
    _ap_label.text = "AP:  %d / %d" % [ap, max_ap]
    if ap == 0:
        _ap_label.add_theme_color_override("font_color", Color(0.6, 0.4, 0.4))
    elif ap <= 4:
        _ap_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.3))
    else:
        _ap_label.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))

# ══ Rows ══════════════════════════════════════════════════════════════════════


func _populate_rows() -> void:
    if MetaManager.storage.storage_items.is_empty():
        _empty_label.visible = true
        _item_list_panel.visible = false
        _footer_status_label.text = "0 items"
        return

    _empty_label.visible = false
    _item_list_panel.visible = true

    _item_list_panel.setup(STORAGE_COLUMNS)
    _item_list_panel.populate(MetaManager.storage.storage_items)

    for entry: ItemEntry in MetaManager.storage.storage_items:
        var row: ItemRow = _item_list_panel.get_row(entry)
        if row != null:
            row.set_selection_state(ItemRow.SelectionState.AVAILABLE)

    var count: int = MetaManager.storage.storage_items.size()
    _footer_status_label.text = "%d item%s" % [count, "" if count == 1 else "s"]


func _refresh_row(entry: ItemEntry) -> void:
    _item_list_panel.refresh_row(entry)

# ══ Detail panel ══════════════════════════════════════════════════════════════


func _select_entry(entry: ItemEntry) -> void:
    if _selected_entry != null:
        var prev_row: ItemRow = _item_list_panel.get_row(_selected_entry)
        if prev_row != null:
            prev_row.set_selection_state(ItemRow.SelectionState.AVAILABLE)

    _selected_entry = entry

    var new_row: ItemRow = _item_list_panel.get_row(entry)
    if new_row != null:
        new_row.set_selection_state(ItemRow.SelectionState.SELECTED)

    _refresh_detail()


func _refresh_detail() -> void:
    var has_selection: bool = _selected_entry != null
    _no_selection_label.visible = not has_selection

    _detail_name_label.visible = has_selection
    _auth_tag_label.visible = false
    _detail_category_label.visible = has_selection
    _detail_rarity_hbox.visible = has_selection
    _detail_stats_hbox.visible = has_selection
    _convergence_panel.visible = has_selection
    _action_grid.visible = has_selection
    _progress_label.visible = false

    if not has_selection:
        return

    var entry: ItemEntry = _selected_entry

    # ── Name and category ─────────────────────────────────────────────────────
    _detail_name_label.text = ItemEntryDisplayHelper.display_name(entry)
    _auth_tag_label.visible = entry.verified
    if entry.category_data != null:
        _detail_category_label.text = "%s · #%d" % [
            entry.category_data.display_name,
            entry.id,
        ]
    else:
        _detail_category_label.text = "#%d" % entry.id

    # ── Rarity ────────────────────────────────────────────────────────────────
    if entry.verified:
        _detail_rarity_label.text = "%s ✓" % ItemEntryDisplayHelper.rarity_text(entry)
    else:
        _detail_rarity_label.text = ItemEntryDisplayHelper.rarity_text(entry)

    # ── Condition ─────────────────────────────────────────────────────────────
    _detail_cond_value.text = ItemEntryDisplayHelper.condition_text(entry)
    _detail_cond_value.modulate = ItemEntryDisplayHelper.condition_color(entry)

    # ── Estimated value ───────────────────────────────────────────────────────
    _detail_est_value.text = ItemEntryDisplayHelper.estimated_value_text(entry)
    _detail_est_value.add_theme_color_override(&"font_color", ItemEntryDisplayHelper.price_color(entry))

    # ── Price convergence / verified value title ──────────────────────────────
    if entry.verified:
        _detail_conv_ratio.text = "Verified"
        _detail_conv_ratio.modulate = ItemEntryDisplayHelper.PRICE_COLOR
        _value_title_label.text = "True Value"
    elif entry.is_veiled():
        _detail_conv_ratio.text = ItemEntryDisplayHelper.UNKNOWN_TEXT
        _detail_conv_ratio.modulate = Color(0.5, 0.5, 0.5)
        _value_title_label.text = "Est. Value"
    elif entry.is_price_converged():
        _detail_conv_ratio.text = "Converged"
        _detail_conv_ratio.modulate = ItemEntryDisplayHelper.PRICE_COLOR
        _value_title_label.text = "Est. Value"
    else:
        var lo: int = entry.estimated_value_min
        var hi: int = entry.estimated_value_max
        var ratio: float = float(lo) / float(hi) * 100.0 if hi > 0 else 0.0
        _detail_conv_ratio.text = "%d%%" % int(ratio)
        _detail_conv_ratio.modulate = Color(0.95, 0.75, 0.3) if ratio < 60.0 else Color.WHITE
        _value_title_label.text = "Est. Value"

    # ── Research progress ─────────────────────────────────────────────────────
    if entry.has_unrevealed_hidden() and not entry.research_progress.is_empty():
        for clue: ClueData in entry.hidden_clues:
            if entry.revealed_clue_ids.has(clue.clue_id):
                continue
            var progress: int = int(entry.research_progress.get(clue.clue_id, 0))
            if progress > 0:
                _progress_label.text = "Research: %d / %d" % [progress, clue.dc]
                _progress_label.visible = true
            break

    # ── Action buttons ────────────────────────────────────────────────────────
    _configure_action_buttons(entry)


func _configure_action_buttons(entry: ItemEntry) -> void:
    var ap: int = MetaManager.slot.storage_ap

    # ── Repair ──────────────────────────────────────────────────────────────
    var repair_done: bool = ResearchSlot.is_repair_complete(entry)
    var can_repair: bool = ap >= Economy.REPAIR_AP_COST and not repair_done
    _repair_btn.disabled = not can_repair
    _repair_btn.text = "Repair  [%d AP]" % Economy.REPAIR_AP_COST
    if repair_done:
        _repair_btn.tooltip_text = "Condition already at 50% — use Restore to continue"
    elif ap < Economy.REPAIR_AP_COST:
        _repair_btn.tooltip_text = "Not enough AP (need %d)" % Economy.REPAIR_AP_COST
    else:
        _repair_btn.tooltip_text = ""

    # ── Restore ──────────────────────────────────────────────────────────────
    var restore_done: bool = ResearchSlot.is_restore_complete(entry)
    var not_ready: bool = entry.condition < 0.5
    var can_restore: bool = ap >= Economy.RESTORE_AP_COST and not not_ready and not restore_done
    _restore_btn.disabled = not can_restore
    _restore_btn.text = "Restore  [%d AP]" % Economy.RESTORE_AP_COST
    if not_ready:
        _restore_btn.tooltip_text = "Repair to 50%% before restoring"
    elif restore_done:
        _restore_btn.tooltip_text = "Condition already fully restored"
    elif ap < Economy.RESTORE_AP_COST:
        _restore_btn.tooltip_text = "Not enough AP (need %d)" % Economy.RESTORE_AP_COST
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
        # Condition maxed — show Restore disabled as status indicator.
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
    _research_btn.text = "Research  [%d AP]" % Economy.RESEARCH_AP_COST
    if not has_hidden:
        _research_btn.tooltip_text = "No hidden clues remaining"
    elif research_needs_repair:
        _research_btn.tooltip_text = "Repair to 50%% condition before researching"
    elif ap < Economy.RESEARCH_AP_COST:
        _research_btn.tooltip_text = "Not enough AP (need %d)" % Economy.RESEARCH_AP_COST
    else:
        _research_btn.tooltip_text = ""
