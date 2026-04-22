# storage_scene.gd
# Storage — Displays stored items and assigns them to research slots.
# V1 layout: dense table (left) + detail rail (right) with task cards.
# Reads:  SaveManager.storage_items, SaveManager.research_slots
# Writes: SaveManager.research_slots
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────

const ItemRowTooltipScene: PackedScene = preload("uid://3kvnpn7pek5i")

const STORAGE_COLUMNS: Array = [
    ItemRow.Column.NAME,
    ItemRow.Column.CONDITION,
    ItemRow.Column.ESTIMATED_VALUE,
    ItemRow.Column.RARITY,
    ItemRow.Column.INSPECTION,
    ItemRow.Column.UNLOCK,
]

# ── State ─────────────────────────────────────────────────────────────────────

var _ctx: ItemViewContext = null
var _tooltip: ItemRowTooltip = null
var _selected_entry: ItemEntry = null

# ── Node references ───────────────────────────────────────────────────────────

# Left — table
@onready var _item_list_panel: ItemListPanel = $RootHBox/LeftVBox/TableMargin/TableVBox/ItemListPanel
@onready var _empty_label: Label = $RootHBox/LeftVBox/TableMargin/TableVBox/EmptyLabel

# Left — footer
@onready var _footer_status_label: Label = $RootHBox/LeftVBox/FooterHBox/FooterMargin/FooterInner/FooterStatusLabel
@onready var _back_btn: Button = $RootHBox/LeftVBox/FooterHBox/FooterMargin/FooterInner/BackButton

# Right — tasks
@onready var _task_ready_label: Label = $RootHBox/Sidebar/SidebarMargin/SidebarVBox/TaskSection/TaskHeaderHBox/TaskReadyLabel
@onready var _task_container: VBoxContainer = $RootHBox/Sidebar/SidebarMargin/SidebarVBox/TaskSection/TaskContainer

# Right — detail
@onready var _detail_section: VBoxContainer = $RootHBox/Sidebar/SidebarMargin/SidebarVBox/DetailSection
@onready var _detail_name_label: Label = $RootHBox/Sidebar/SidebarMargin/SidebarVBox/DetailSection/DetailNameLabel
@onready var _detail_category_label: Label = $RootHBox/Sidebar/SidebarMargin/SidebarVBox/DetailSection/DetailCategoryLabel
@onready var _detail_rarity_label: Label = $RootHBox/Sidebar/SidebarMargin/SidebarVBox/DetailSection/DetailRarityHBox/DetailRarityLabel
@onready var _detail_cond_value: Label = $RootHBox/Sidebar/SidebarMargin/SidebarVBox/DetailSection/DetailStatsHBox/ConditionPanel/CondMargin/CondVBox/CondValueLabel
@onready var _detail_est_value: Label = $RootHBox/Sidebar/SidebarMargin/SidebarVBox/DetailSection/DetailStatsHBox/ValuePanel/ValueMargin/ValueVBox/ValueValueLabel
@onready var _detail_conv_ratio: Label = $RootHBox/Sidebar/SidebarMargin/SidebarVBox/DetailSection/ConvergencePanel/ConvMargin/ConvVBox/ConvHBox/ConvRatioLabel
@onready var _progress_label: Label = $RootHBox/Sidebar/SidebarMargin/SidebarVBox/DetailSection/ProgressLabel
@onready var _no_selection_label: Label = $RootHBox/Sidebar/SidebarMargin/SidebarVBox/DetailSection/NoSelectionLabel

# Right — action buttons
@onready var _action_grid: GridContainer = $RootHBox/Sidebar/SidebarMargin/SidebarVBox/DetailSection/ActionGrid
@onready var _study_btn: Button = $RootHBox/Sidebar/SidebarMargin/SidebarVBox/DetailSection/ActionGrid/StudyButton
@onready var _repair_btn: Button = $RootHBox/Sidebar/SidebarMargin/SidebarVBox/DetailSection/ActionGrid/RepairButton
@onready var _unlock_btn: Button = $RootHBox/Sidebar/SidebarMargin/SidebarVBox/DetailSection/ActionGrid/UnlockButton
@onready var _remove_btn: Button = $RootHBox/Sidebar/SidebarMargin/SidebarVBox/DetailSection/ActionGrid/RemoveButton

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _ctx = ItemViewContext.for_storage()
    _tooltip = ItemRowTooltipScene.instantiate()
    add_child(_tooltip)

    _back_btn.pressed.connect(_on_back_pressed)
    _study_btn.pressed.connect(_on_study_pressed)
    _repair_btn.pressed.connect(_on_repair_pressed)
    _unlock_btn.pressed.connect(_on_unlock_pressed)
    _remove_btn.pressed.connect(_on_remove_pressed)

    _item_list_panel.row_pressed.connect(_on_row_pressed)
    _item_list_panel.tooltip_requested.connect(_on_row_tooltip_requested)
    _item_list_panel.tooltip_dismissed.connect(_tooltip.hide_tooltip)

    _populate_rows()
    _populate_tasks()
    _refresh_detail()

# ══ Signal handlers ═══════════════════════════════════════════════════════════


func _on_back_pressed() -> void:
    GameManager.go_to_hub()


func _on_row_pressed(entry: ItemEntry) -> void:
    _select_entry(entry)


func _on_row_tooltip_requested(
        entry: ItemEntry,
        ctx: ItemViewContext,
        anchor: Rect2,
) -> void:
    _tooltip.show_for(entry, ctx, anchor)


func _on_study_pressed() -> void:
    _assign_action(ResearchSlot.SlotAction.STUDY)


func _on_repair_pressed() -> void:
    _assign_action(ResearchSlot.SlotAction.REPAIR)


func _on_unlock_pressed() -> void:
    _assign_action(ResearchSlot.SlotAction.UNLOCK)


func _on_remove_pressed() -> void:
    if _selected_entry == null:
        return
    var idx: int = _find_slot_index(_selected_entry)
    if idx >= 0:
        var cleared := ResearchSlot.new()
        SaveManager.research_slots[idx] = cleared.to_dict()
        SaveManager.save()
    _refresh_row(_selected_entry)
    _populate_tasks()
    _refresh_detail()

# ══ Rows ══════════════════════════════════════════════════════════════════════


func _populate_rows() -> void:
    if SaveManager.storage_items.is_empty():
        _empty_label.visible = true
        _item_list_panel.visible = false
        _footer_status_label.text = "0 items"
        return

    _empty_label.visible = false
    _item_list_panel.visible = true

    _item_list_panel.setup(_ctx, STORAGE_COLUMNS)
    _item_list_panel.populate(SaveManager.storage_items)

    for entry: ItemEntry in SaveManager.storage_items:
        var row: ItemRow = _item_list_panel.get_row(entry)
        if row != null:
            row.set_selection_state(ItemRow.SelectionState.AVAILABLE)

    var count: int = SaveManager.storage_items.size()
    _footer_status_label.text = "%d item%s" % [count, "" if count == 1 else "s"]


func _refresh_row(entry: ItemEntry) -> void:
    _item_list_panel.refresh_row(entry)

# ══ Tasks ═════════════════════════════════════════════════════════════════════


func _populate_tasks() -> void:
    for child: Node in _task_container.get_children():
        child.queue_free()

    var active_count: int = 0

    for d: Dictionary in SaveManager.research_slots:
        var slot := ResearchSlot.from_dict(d)
        if slot.is_empty():
            continue

        active_count += 1

        var entry: ItemEntry = _find_entry_by_id(slot.item_id)
        var card := _build_task_card(slot, entry)
        _task_container.add_child(card)

    _task_ready_label.text = "%d/%d" % [active_count, SaveManager.max_research_slots]


func _build_task_card(slot: ResearchSlot, entry: ItemEntry) -> PanelContainer:
    var card := PanelContainer.new()

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 8)
    margin.add_theme_constant_override("margin_top", 6)
    margin.add_theme_constant_override("margin_right", 8)
    margin.add_theme_constant_override("margin_bottom", 6)
    card.add_child(margin)

    var hbox := HBoxContainer.new()
    hbox.add_theme_constant_override("separation", 8)
    margin.add_child(hbox)

    # ── Action type label ─────────────────────────────────────────────────────
    var kind_label := Label.new()
    kind_label.add_theme_font_size_override("font_size", 10)
    kind_label.text = ResearchSlot.action_to_string(slot.action).to_upper()
    if slot.action == ResearchSlot.SlotAction.UNLOCK:
        kind_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.3))
    else:
        kind_label.add_theme_color_override("font_color", Color(0.42, 0.75, 0.85))
    kind_label.custom_minimum_size.x = 52
    hbox.add_child(kind_label)

    # ── Target + status ───────────────────────────────────────────────────────
    var info_vbox := VBoxContainer.new()
    info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    info_vbox.add_theme_constant_override("separation", 2)
    hbox.add_child(info_vbox)

    var name_label := Label.new()
    name_label.add_theme_font_size_override("font_size", 12)
    name_label.text = entry.display_name if entry != null else "Unknown"
    name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    info_vbox.add_child(name_label)

    var status_label := Label.new()
    status_label.add_theme_font_size_override("font_size", 10)
    if slot.completed:
        status_label.text = "Completed"
        status_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
    else:
        status_label.text = _task_progress_text(entry, slot)
        status_label.add_theme_color_override("font_color", Color(0.55, 0.58, 0.63))
    info_vbox.add_child(status_label)

    # ── Click to select ───────────────────────────────────────────────────────
    if entry != null:
        card.gui_input.connect(
            func(event: InputEvent) -> void:
                if event is InputEventMouseButton and event.pressed:
                    _select_entry(entry)
        )
        card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

    return card


func _task_progress_text(entry: ItemEntry, slot: ResearchSlot) -> String:
    if entry == null:
        return ""
    match slot.action:
        ResearchSlot.SlotAction.STUDY:
            if entry.is_fully_inspected():
                return "Fully Inspected"
            return "In progress"
        ResearchSlot.SlotAction.REPAIR:
            if entry.is_repair_complete():
                return "Condition: 100%"
            return "Condition: %d%%" % int(entry.condition * 100)
        ResearchSlot.SlotAction.UNLOCK:
            var action_def: LayerUnlockAction = entry.current_unlock_action()
            var difficulty: float = action_def.difficulty if action_def != null else 0.0
            return "Progress: %.1f / %.1f" % [entry.unlock_progress, difficulty]
        _:
            return ""

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

    # Hide detail content when nothing selected
    _detail_name_label.visible = has_selection
    _detail_category_label.visible = has_selection
    _detail_section.get_node("DetailRarityHBox").visible = has_selection
    _detail_section.get_node("DetailStatsHBox").visible = has_selection
    _detail_section.get_node("ConvergencePanel").visible = has_selection
    _action_grid.visible = has_selection
    _progress_label.visible = false

    if not has_selection:
        return

    var entry: ItemEntry = _selected_entry

    # ── Name and category ─────────────────────────────────────────────────────
    _detail_name_label.text = entry.display_name
    if entry.item_data != null and entry.item_data.category_data != null:
        _detail_category_label.text = "%s · #%d" % [
            entry.item_data.category_data.display_name,
            entry.id,
        ]
    else:
        _detail_category_label.text = "#%d" % entry.id

    # ── Rarity ─────────────────────────────────────────────────────────────────
    _detail_rarity_label.text = entry.perceived_rarity_label

    # ── Condition ─────────────────────────────────────────────────────────────
    _detail_cond_value.text = entry.condition_label
    _detail_cond_value.modulate = entry.condition_color

    # ── Estimated value ───────────────────────────────────────────────────────
    _detail_est_value.text = entry.estimated_value_label
    _detail_est_value.add_theme_color_override(&"font_color", entry.price_color)

    # ── Price convergence ─────────────────────────────────────────────────────
    if entry.is_veiled():
        _detail_conv_ratio.text = "???"
        _detail_conv_ratio.modulate = Color(0.5, 0.5, 0.5)
    elif entry.is_price_converged():
        _detail_conv_ratio.text = "Converged"
        _detail_conv_ratio.modulate = Color(0.4, 1.0, 0.5)
    else:
        var lo: int = entry.estimated_value_min
        var hi: int = entry.estimated_value_max
        var ratio: float = float(lo) / float(hi) * 100.0 if hi > 0 else 0.0
        _detail_conv_ratio.text = "%d%%" % int(ratio)
        _detail_conv_ratio.modulate = Color(0.95, 0.75, 0.3) if ratio < 60.0 else Color.WHITE

    # ── Slot status ───────────────────────────────────────────────────────────
    var slot_index: int = _find_slot_index(entry)
    var in_slot: bool = slot_index >= 0
    var current_slot: ResearchSlot = null
    if in_slot:
        current_slot = ResearchSlot.from_dict(SaveManager.research_slots[slot_index])

    if in_slot:
        _progress_label.text = _progress_text(entry, current_slot)
        _progress_label.visible = true

    # ── Action buttons ────────────────────────────────────────────────────────
    var slots_available: bool = in_slot \
    or _empty_slot_index() >= 0 \
    or SaveManager.research_slots.size() < SaveManager.max_research_slots

    _configure_action_btn(_study_btn, "Study", entry, ResearchSlot.SlotAction.STUDY, current_slot)
    _configure_action_btn(_repair_btn, "Repair", entry, ResearchSlot.SlotAction.REPAIR, current_slot)
    _configure_action_btn(_unlock_btn, "Unlock", entry, ResearchSlot.SlotAction.UNLOCK, current_slot)

    if not slots_available:
        _study_btn.disabled = true
        _repair_btn.disabled = true
        _unlock_btn.disabled = true
        _study_btn.tooltip_text = "No research slots available"
        _repair_btn.tooltip_text = "No research slots available"
        _unlock_btn.tooltip_text = "No research slots available"

    _remove_btn.visible = in_slot
    _remove_btn.text = "Remove"


func _configure_action_btn(
        btn: Button,
        label: String,
        entry: ItemEntry,
        action: ResearchSlot.SlotAction,
        current_slot: ResearchSlot,
) -> void:
    var reason: String = _disabled_reason(entry, action)
    btn.disabled = reason != ""
    btn.tooltip_text = reason

    var is_current: bool = current_slot != null and current_slot.action == action
    if is_current:
        btn.text = "✓ %s" % label
    else:
        btn.text = label


func _disabled_reason(entry: ItemEntry, action: ResearchSlot.SlotAction) -> String:
    match action:
        ResearchSlot.SlotAction.STUDY:
            if entry.is_fully_inspected():
                return "Fully inspected"
            if not entry.is_condition_inspectable():
                return "Scrutiny already maxed"
            return ""
        ResearchSlot.SlotAction.REPAIR:
            if entry.is_repair_complete():
                return "Condition already maxed"
            return ""
        ResearchSlot.SlotAction.UNLOCK:
            if entry.is_at_final_layer():
                return "No further layers to unlock"
            var check: KnowledgeManager.AdvanceCheck = KnowledgeManager.can_advance(entry)
            if check != KnowledgeManager.AdvanceCheck.OK:
                return AdvanceCheckLabel.describe(check, entry.current_unlock_action(), entry)
            return ""
        _:
            push_warning("StorageScene: unknown SlotAction %d" % action)
            return ""


func _progress_text(entry: ItemEntry, slot: ResearchSlot) -> String:
    match slot.action:
        ResearchSlot.SlotAction.STUDY:
            if slot.completed or entry.is_fully_inspected():
                return "Fully Inspected"
            return "Rarity: %s   Condition: %s" % [entry.perceived_rarity_label, entry.condition_label]
        ResearchSlot.SlotAction.REPAIR:
            if slot.completed or entry.is_repair_complete():
                return "Condition: 100%"
            return "Condition: %d%%" % int(entry.condition * 100)
        ResearchSlot.SlotAction.UNLOCK:
            if slot.completed:
                return "Layer Unlocked"
            var action_def: LayerUnlockAction = entry.current_unlock_action()
            var difficulty: float = action_def.difficulty if action_def != null else 0.0
            return "Progress: %.1f / %.1f" % [entry.unlock_progress, difficulty]
        _:
            push_warning("StorageScene: unknown SlotAction %d" % slot.action)
            return ""

# ══ Assignment ════════════════════════════════════════════════════════════════


func _assign_action(action: ResearchSlot.SlotAction) -> void:
    if _selected_entry == null:
        return

    var new_slot := ResearchSlot.create(action, _selected_entry.id)
    var existing_idx: int = _find_slot_index(_selected_entry)
    if existing_idx >= 0:
        SaveManager.research_slots[existing_idx] = new_slot.to_dict()
    else:
        var empty_idx: int = _empty_slot_index()
        if empty_idx >= 0:
            SaveManager.research_slots[empty_idx] = new_slot.to_dict()
        elif SaveManager.research_slots.size() < SaveManager.max_research_slots:
            SaveManager.research_slots.append(new_slot.to_dict())
        else:
            return

    SaveManager.save()
    _refresh_row(_selected_entry)
    _populate_tasks()
    _refresh_detail()

# ══ Slot lookups ══════════════════════════════════════════════════════════════


func _find_slot_index(entry: ItemEntry) -> int:
    if entry == null or entry.id == -1:
        return -1
    for i: int in range(SaveManager.research_slots.size()):
        var d: Dictionary = SaveManager.research_slots[i]
        var slot_item_id: int = int(d.get("item_id", -1))
        if slot_item_id != -1 and slot_item_id == entry.id:
            return i
    return -1


func _empty_slot_index() -> int:
    for i: int in range(SaveManager.research_slots.size()):
        var d: Dictionary = SaveManager.research_slots[i]
        if int(d.get("item_id", -1)) == -1:
            return i
    return -1


func _find_entry_by_id(item_id: int) -> ItemEntry:
    for entry: ItemEntry in SaveManager.storage_items:
        if entry.id == item_id:
            return entry
    return null
