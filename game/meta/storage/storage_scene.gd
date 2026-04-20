# storage_scene.gd
# Storage — Displays stored items and assigns them to research slots.
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
    ItemRow.Column.RESEARCH_STATUS,
]

# ── State ─────────────────────────────────────────────────────────────────────

var _ctx: ItemViewContext = null
var _tooltip: ItemRowTooltip = null
var _selected_entry: ItemEntry = null

# ── Node references ───────────────────────────────────────────────────────────

@onready var _item_list_panel: ItemListPanel = $RootVBox/ListCenter/OuterVBox/ItemListPanel
@onready var _back_btn: Button = $RootVBox/Footer/BackButton
@onready var _empty_label: Label = $RootVBox/ListCenter/OuterVBox/EmptyLabel
@onready var _slot_count_label: Label = $RootVBox/SlotsHUD/SlotCountLabel
@onready var _active_actions_label: Label = $RootVBox/SlotsHUD/ActiveActionsLabel

@onready var _action_popup: Window = $ActionPopup
@onready var _action_item_label: Label = $ActionPopup/MarginContainer/VBoxContainer/ItemLabel
@onready var _status_label: Label = $ActionPopup/MarginContainer/VBoxContainer/StatusLabel
@onready var _progress_label: Label = $ActionPopup/MarginContainer/VBoxContainer/ProgressLabel
@onready var _action_buttons: VBoxContainer = $ActionPopup/MarginContainer/VBoxContainer/ActionButtons
@onready var _study_btn: Button = $ActionPopup/MarginContainer/VBoxContainer/ActionButtons/StudyButton
@onready var _repair_btn: Button = $ActionPopup/MarginContainer/VBoxContainer/ActionButtons/RepairButton
@onready var _unlock_btn: Button = $ActionPopup/MarginContainer/VBoxContainer/ActionButtons/UnlockButton
@onready var _remove_btn: Button = $ActionPopup/MarginContainer/VBoxContainer/FooterRow/RemoveButton
@onready var _cancel_btn: Button = $ActionPopup/MarginContainer/VBoxContainer/FooterRow/CancelButton

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _ctx = ItemViewContext.for_storage()
    _tooltip = ItemRowTooltipScene.instantiate()
    add_child(_tooltip)

    _back_btn.pressed.connect(_on_back_pressed)
    _cancel_btn.pressed.connect(_action_popup.hide)
    _study_btn.pressed.connect(_on_study_pressed)
    _repair_btn.pressed.connect(_on_repair_pressed)
    _unlock_btn.pressed.connect(_on_unlock_pressed)
    _remove_btn.pressed.connect(_on_remove_pressed)

    _item_list_panel.row_pressed.connect(_on_row_pressed)
    _item_list_panel.tooltip_requested.connect(_on_row_tooltip_requested)
    _item_list_panel.tooltip_dismissed.connect(_tooltip.hide_tooltip)

    _populate_rows()
    _refresh_slots_hud()

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
    _action_popup.hide()
    _refresh_slots_hud()

# ══ Rows ══════════════════════════════════════════════════════════════════════


func _populate_rows() -> void:
    if SaveManager.storage_items.is_empty():
        _empty_label.visible = true
        _item_list_panel.visible = false
        return

    _empty_label.visible = false
    _item_list_panel.visible = true

    _item_list_panel.setup(_ctx, STORAGE_COLUMNS)
    _item_list_panel.populate(SaveManager.storage_items)

    for entry: ItemEntry in SaveManager.storage_items:
        var row: ItemRow = _item_list_panel.get_row(entry)
        if row != null:
            row.set_selection_state(ItemRow.SelectionState.AVAILABLE)


func _refresh_row(entry: ItemEntry) -> void:
    _item_list_panel.refresh_row(entry)

# ══ Action popup ══════════════════════════════════════════════════════════════


func _show_action_popup(entry: ItemEntry) -> void:
    _action_item_label.text = entry.display_name

    var slot_index: int = _find_slot_index(entry)
    var in_slot: bool = slot_index >= 0
    var current_slot: ResearchSlot = null
    if in_slot:
        current_slot = ResearchSlot.from_dict(SaveManager.research_slots[slot_index])

    var slots_available: bool = in_slot \
    or _empty_slot_index() >= 0 \
    or SaveManager.research_slots.size() < SaveManager.max_research_slots

    if not slots_available:
        _status_label.text = "No research slots available"
        _status_label.visible = true
        _progress_label.visible = false
        _action_buttons.visible = false
        _remove_btn.visible = false
        _action_popup.popup_centered()
        return

    _status_label.visible = false
    _action_buttons.visible = true

    if in_slot:
        _progress_label.text = _progress_text(entry, current_slot)
        _progress_label.visible = true
        _remove_btn.visible = true
    else:
        _progress_label.visible = false
        _remove_btn.visible = false

    _configure_action_btn(_study_btn, "Study", entry, ResearchSlot.SlotAction.STUDY, current_slot)
    _configure_action_btn(_repair_btn, "Repair", entry, ResearchSlot.SlotAction.REPAIR, current_slot)
    _configure_action_btn(_unlock_btn, "Unlock", entry, ResearchSlot.SlotAction.UNLOCK, current_slot)

    _action_popup.popup_centered()


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
        btn.text = "✓ %s (current)" % label
    else:
        btn.text = label


func _disabled_reason(entry: ItemEntry, action: ResearchSlot.SlotAction) -> String:
    match action:
        ResearchSlot.SlotAction.STUDY:
            if entry.is_fully_inspected():
                return "Fully inspected"
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
            return "Rarity: %s   Condition: %s" % [entry.get_potential_rating(), entry.condition_label]
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

# ══ Assignment ═════════════════════════════════════════════════════════════════


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
    _action_popup.hide()
    _refresh_slots_hud()

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

# ══ HUD ═══════════════════════════════════════════════════════════════════════


func _refresh_slots_hud() -> void:
    var total: int = SaveManager.max_research_slots
    var used: int = 0
    for d: Dictionary in SaveManager.research_slots:
        if int(d.get("item_id", -1)) != -1:
            used += 1
    var remaining: int = total - used
    _slot_count_label.text = "Slots: %d / %d  (remaining: %d)" % [used, total, remaining]

    var lines: PackedStringArray = []
    for d: Dictionary in SaveManager.research_slots:
        var item_id: int = int(d.get("item_id", -1))
        if item_id == -1:
            continue
        var slot: ResearchSlot = ResearchSlot.from_dict(d)
        var entry: ItemEntry = _find_entry_by_id(item_id)
        var item_name: String = entry.display_name if entry != null else "Unknown (#%d)" % item_id
        var action_name: String = ResearchSlot.action_to_string(slot.action).capitalize()
        var line: String = "%s: %s" % [action_name, item_name]
        if slot.completed:
            line += " ✓"
        lines.append(line)

    if lines.is_empty():
        _active_actions_label.text = "No active research"
    else:
        _active_actions_label.text = "\n".join(lines)


func _find_entry_by_id(item_id: int) -> ItemEntry:
    for entry: ItemEntry in SaveManager.storage_items:
        if entry.id == item_id:
            return entry
    return null
