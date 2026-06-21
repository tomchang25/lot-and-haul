# cargo_scene.gd
# Block 05 — Cargo Loading (v2: 2-D grid packing)
# Reads:  RunManager.run.won_items, RunManager.run.car_data
# Writes: RunManager.commit_cargo()
extends Control

# ── Constants ──────────────────────────────────────────────────────────────────

const BLOCKED_ERROR: UiAudioEvent = preload("res://data/tres/audio_events/blocked_error.tres")
const CONFIRM: UiAudioEvent = preload("res://data/tres/audio_events/confirm.tres")
const SELL_GRID_LIFT: UiAudioEvent = preload("res://data/tres/audio_events/sell_grid_lift.tres")
const SELL_GRID_PUT_DOWN: UiAudioEvent = preload("res://data/tres/audio_events/sell_grid_put_down.tres")

const CELL_SIZE := 56

const CargoItemRowScene: PackedScene = preload("res://game/run/cargo/cargo_item_row.tscn")
const ExtraSlotCellScene: PackedScene = preload("res://game/run/cargo/extra_slot_cell/extra_slot_cell.tscn")

# ── State ──────────────────────────────────────────────────────────────────────

var _won_items: Array[ItemEntry] = []

var _active_origin: String = ""
var _active_origin_extra_index: int = -1

var _extra_slot_items: Array[ItemEntry] = []
var _hover_extra_index: int = -1

# ── Extra Slot Grid State ──────────────────────────────────────────────────────

var _extra_slot_cells: Dictionary = { }
var _extra_slot_item_styles: Dictionary = { } # entry → StyleBoxFlat
var _extra_slot_hover_styles: Dictionary = { } # entry → StyleBoxFlat (hovered)

# ── Item List State ────────────────────────────────────────────────────────────

var _item_rows: Dictionary = { }
var _loaded_items: Array = []

# ── Stats ──────────────────────────────────────────────────────────────────────

var _slots_used: int = 0
var _weight_used: float = 0.0
# ── Tooltip Support ────────────────────────────────────────────────────────────

var _hovered_item: ItemEntry = null
var _last_highlighted_entry: ItemEntry = null

# Debug overlay buttons — created by _init_debug_overlay().
var _debug_auto_pack_btn: Button = null
var _debug_stuff_btn: Button = null

# ── Node references ────────────────────────────────────────────────────────────

@onready var _item_list_vbox: VBoxContainer = $MainHBox/ItemListPanel/ItemListScroll/ItemListVBox
@onready var _error_label: Label = $MainHBox/VehiclePanel/ErrorLabel
@onready var _cargo_grid: PackingGrid = $MainHBox/VehiclePanel/CargoSection/CargoGrid
@onready var _trailer_section: HBoxContainer = $MainHBox/VehiclePanel/TrailerSection
@onready var _extra_slot_container: HBoxContainer = $MainHBox/VehiclePanel/TrailerSection/TrailerSlotContainer
@onready var _reset_btn: Button = $ResetButton
@onready var _continue_btn: Button = $ContinueButton
@onready var _confirm_popup: ConfirmationDialog = $ConfirmPopup
@onready var _summary_loaded_count: Label = $MainHBox/VehiclePanel/RunSummary/SummaryVBox/LoadedLine/LoadedCountLabel
@onready var _summary_loaded_value: Label = $MainHBox/VehiclePanel/RunSummary/SummaryVBox/LoadedLine/LoadedValueLabel
@onready var _summary_unloaded_count: Label = $MainHBox/VehiclePanel/RunSummary/SummaryVBox/UnloadedLine/UnloadedCountLabel
@onready var _summary_unloaded_sell: Label = $MainHBox/VehiclePanel/RunSummary/SummaryVBox/UnloadedLine/UnloadedSellLabel
@onready var _summary_weight: Label = $MainHBox/VehiclePanel/RunSummary/SummaryVBox/WeightLabel
@onready var _summary_slots: Label = $MainHBox/VehiclePanel/RunSummary/SummaryVBox/SlotsLabel
@onready var _summary_trailer_line: HBoxContainer = $MainHBox/VehiclePanel/RunSummary/SummaryVBox/TrailerLine
@onready var _summary_trailer_value: Label = $MainHBox/VehiclePanel/RunSummary/SummaryVBox/TrailerLine/TrailerRiskValue
@onready var _run_summary: PanelContainer = $MainHBox/VehiclePanel/RunSummary
@onready var _tooltip: ItemCardPopup = %TooltipPopup

# ══ Lifecycle ══════════════════════════════════════════════════════════════════


func _ready() -> void:
    if RunManager.run == null:
        ToastManager.show_error("Cargo scene failed to load. Returning to hub.")
        SceneRouter.go_to_hub.call_deferred()
        return

    RunManager.set_resume_target(RunStore.RESUME_CARGO)
    SaveManager.save()

    _run_summary.add_theme_stylebox_override(
        &"panel",
        get_theme_stylebox(&"panel", &"RunSummary"),
    )

    _reset_btn.pressed.connect(_on_reset_pressed)
    _continue_btn.pressed.connect(_on_continue_pressed)
    _continue_btn.press_event = CONFIRM
    _confirm_popup.confirmed.connect(_on_confirm_popup_confirmed)

    _won_items = RunManager.run.won_items

    _extra_slot_items.resize(RunManager.run.car_data.extra_slot_count)
    _extra_slot_items.fill(null)

    # ── Configure PackingGrid ─────────────────────────────────────────────
    _cargo_grid.setup_default_callbacks(_won_items)
    _cargo_grid.additional_validator = _packing_weight_validator
    var cols: int = RunManager.run.car_data.grid_columns
    var rows: int = RunManager.run.car_data.grid_rows

    _cargo_grid.item_clicked.connect(_on_packing_grid_item_clicked)
    _cargo_grid.cell_clicked.connect(_on_packing_grid_cell_clicked)
    _cargo_grid.placement_cancelled.connect(_on_packing_grid_placement_cancelled)
    _cargo_grid.hover_started.connect(_on_packing_grid_hover_started)
    _cargo_grid.hover_ended.connect(_on_packing_grid_hover_ended)

    _cargo_grid.setup(cols, rows)

    _build_item_list()
    _build_extra_slots()
    _recalc_totals()
    _refresh_ui()
    Debug.toggled.connect(_on_debug_toggled)
    if Debug.enabled:
        _init_debug_overlay()
    Director.register_scene(
        "cargo",
        {
            "item_list": _item_list_vbox,
            "cargo_grid": _cargo_grid,
            "continue_btn": _continue_btn,
            "reset_btn": _reset_btn,
        },
    )


func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
        if _cargo_grid.phase == PackingGrid.Phase.ITEM_HELD:
            _cargo_grid.cancel_placement()
            accept_event()

# ══ PackingGrid callbacks ═══════════════════════════════════════════════════════


func _packing_weight_validator(item, _origin: Vector2i) -> bool:
    return not _would_exceed_weight(item)

# ══ PackingGrid signal handlers ════════════════════════════════════════════════


func _on_packing_grid_item_clicked(item) -> void:
    _hide_tooltip()
    if _last_highlighted_entry != null:
        if _item_rows.has(_last_highlighted_entry):
            _item_rows[_last_highlighted_entry].set_external_highlight(false)
        _last_highlighted_entry = null
    var entry: ItemEntry = item as ItemEntry
    AudioManager.play_event(SELL_GRID_LIFT)
    _lift_from_cargo(entry)


func _on_packing_grid_cell_clicked(pos: Vector2i) -> void:
    var item = _cargo_grid.active_item
    if item != null and _cargo_grid.can_place(item, pos):
        _cargo_grid.place(item, pos)
        AudioManager.play_event(SELL_GRID_PUT_DOWN)
        _active_origin = ""
        _recalc_totals()
        _refresh_ui()
        EventBus.tutorial_event.emit(TutorialEvents.CARGO_ITEM_PLACED, { })
    elif item != null:
        AudioManager.play_event(BLOCKED_ERROR)


func _on_packing_grid_placement_cancelled(item) -> void:
    if _active_origin == "extra" and _active_origin_extra_index >= 0:
        _extra_slot_items[_active_origin_extra_index] = item
        _active_origin_extra_index = -1
    _active_origin = ""
    _recalc_totals()
    _refresh_ui()


func _on_packing_grid_hover_started(pos: Vector2i) -> void:
    if _cargo_grid.phase != PackingGrid.Phase.ITEM_HELD and _cargo_grid.placement.has(pos):
        var entry: ItemEntry = _cargo_grid.placement[pos] as ItemEntry
        if _item_rows.has(entry):
            if _last_highlighted_entry != null and _last_highlighted_entry != entry:
                _item_rows[_last_highlighted_entry].set_external_highlight(false)
            _last_highlighted_entry = entry
            _item_rows[entry].set_external_highlight(true)
            _show_tooltip_for_item(entry, _item_rows[entry].get_global_rect())


func _on_packing_grid_hover_ended() -> void:
    _hide_tooltip()
    if _last_highlighted_entry != null:
        if _item_rows.has(_last_highlighted_entry):
            _item_rows[_last_highlighted_entry].set_external_highlight(false)
        _last_highlighted_entry = null

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_reset_pressed() -> void:
    _cargo_grid.reset()
    _extra_slot_items.fill(null)
    _extra_slot_item_styles.clear()
    _extra_slot_hover_styles.clear()

    _active_origin = ""
    _active_origin_extra_index = -1

    _recalc_totals()
    _refresh_ui()


func _on_continue_pressed() -> void:
    EventBus.tutorial_event.emit(TutorialEvents.CARGO_CONTINUE_REQUESTED, { })
    _confirm_popup.dialog_text = _build_summary_text()
    _confirm_popup.popup_centered()


func _on_confirm_popup_confirmed() -> void:
    var cargo: Array[ItemEntry] = []
    for entry: ItemEntry in _cargo_grid.get_placed_items():
        cargo.append(entry)
    var trailer: Array[ItemEntry] = []
    for entry: ItemEntry in _extra_slot_items:
        if entry != null:
            trailer.append(entry)

    var unplaced_count := 0
    for entry: ItemEntry in _won_items:
        if entry not in cargo and entry not in trailer:
            unplaced_count += 1

    RunManager.commit_cargo(cargo, trailer, unplaced_count * Economy.ONSITE_SELL_PRICE)
    RunManager.set_resume_target(RunStore.RESUME_RUN_REVIEW)
    SaveManager.save()
    EventBus.tutorial_event.emit(TutorialEvents.CARGO_LOADED, { })
    SceneRouter.go_to_run_review()


func _on_extra_slot_pressed(slot_index: int) -> void:
    if slot_index < 0 or slot_index >= _extra_slot_items.size():
        ToastManager.show_dev_error("extra_slot_pressed with index out of range: %d (size %d)" % [slot_index, _extra_slot_items.size()])
        return
    _hide_tooltip()
    if _cargo_grid.phase == PackingGrid.Phase.IDLE:
        if _extra_slot_items[slot_index] != null:
            var entry: ItemEntry = _extra_slot_items[slot_index]
            if _item_rows.has(entry):
                _item_rows[entry].set_external_highlight(false)
            _lift_from_extra(slot_index)
    elif _cargo_grid.phase == PackingGrid.Phase.ITEM_HELD:
        _place_item_in_extra(slot_index)


func _on_extra_slot_hovered(slot_index: int) -> void:
    if slot_index < 0 or slot_index >= _extra_slot_items.size() or not _extra_slot_cells.has(slot_index):
        ToastManager.show_dev_error(
            "extra_slot_hovered with index out of range: %d (items size %d, cells size %d)" % [
                slot_index,
                _extra_slot_items.size(),
                _extra_slot_cells.size(),
            ],
        )
        return

    _hover_extra_index = slot_index
    _refresh_extra_slot_visuals()

    if _cargo_grid.phase != PackingGrid.Phase.ITEM_HELD and _extra_slot_items[slot_index] != null:
        var entry: ItemEntry = _extra_slot_items[slot_index]
        if _item_rows.has(entry):
            if _last_highlighted_entry != null and _last_highlighted_entry != entry:
                _item_rows[_last_highlighted_entry].set_external_highlight(false)
            _last_highlighted_entry = entry
            _item_rows[entry].set_external_highlight(true)
            _show_tooltip_for_item(entry, _item_rows[entry].get_global_rect())
        else:
            _show_tooltip_for_item(entry, _extra_slot_cells[slot_index].get_global_rect())


func _on_extra_slot_unhovered(slot_index: int) -> void:
    if _hover_extra_index == slot_index:
        _hover_extra_index = -1
    if _last_highlighted_entry != null:
        if _item_rows.has(_last_highlighted_entry):
            _item_rows[_last_highlighted_entry].set_external_highlight(false)
        _last_highlighted_entry = null
    _refresh_extra_slot_visuals()
    _hide_tooltip()


func _on_extra_slot_cancel(_slot_index: int) -> void:
    if _cargo_grid.phase == PackingGrid.Phase.ITEM_HELD:
        _cargo_grid.cancel_placement()


func _on_item_row_pressed(entry: ItemEntry) -> void:
    _hide_tooltip()
    if _last_highlighted_entry != null:
        if _item_rows.has(_last_highlighted_entry):
            _item_rows[_last_highlighted_entry].set_external_highlight(false)
        _last_highlighted_entry = null
    if _item_rows.has(entry):
        _item_rows[entry].set_external_highlight(false)
    if _cargo_grid.phase == PackingGrid.Phase.ITEM_HELD:
        _cargo_grid.cancel_placement()
    _lift_item_entry(entry)
    EventBus.tutorial_event.emit(TutorialEvents.CARGO_ITEM_SELECTED, { })


func _on_row_tooltip_requested(entry: ItemEntry, anchor: Rect2) -> void:
    _show_tooltip_for_item(entry, anchor)


func _on_row_tooltip_dismissed() -> void:
    _hide_tooltip()

# ══ Item lift helpers ══════════════════════════════════════════════════════════


func _lift_item_entry(entry: ItemEntry) -> void:
    if _cargo_grid.is_item_placed(entry):
        _lift_from_cargo(entry)
    elif _is_item_in_extra(entry):
        var idx: int = _extra_slot_items.find(entry)
        _lift_from_extra(idx)
    else:
        _lift_from_list(entry)


func _is_item_in_extra(entry: ItemEntry) -> bool:
    return entry in _extra_slot_items


func _lift_from_list(entry: ItemEntry) -> void:
    AudioManager.play_event(SELL_GRID_LIFT)
    _active_origin = "list"
    _cargo_grid.set_held_item(entry, _cargo_grid.item_rotations.get(entry, 0))
    _refresh_ui()


func _lift_from_cargo(entry: ItemEntry) -> void:
    AudioManager.play_event(SELL_GRID_LIFT)
    _active_origin = "cargo"
    _cargo_grid.lift(entry)
    _refresh_ui()


func _lift_from_extra(slot_index: int) -> void:
    var entry: ItemEntry = _extra_slot_items[slot_index]
    AudioManager.play_event(SELL_GRID_LIFT)
    _active_origin = "extra"
    _active_origin_extra_index = slot_index
    _extra_slot_items[slot_index] = null
    _cargo_grid.set_held_item(entry, _cargo_grid.item_rotations.get(entry, 0))
    _recalc_totals()
    _refresh_ui()


func _place_item_in_extra(slot_index: int) -> void:
    if slot_index < 0 or slot_index >= _extra_slot_items.size():
        ToastManager.show_dev_error("place_item_in_extra with index out of range: %d (size %d)" % [slot_index, _extra_slot_items.size()])
        return

    if _extra_slot_items[slot_index] != null:
        return

    var item = _cargo_grid.active_item
    if item == null:
        return

    if _cargo_grid.is_item_placed(item):
        _cargo_grid.erase(item)

    AudioManager.play_event(SELL_GRID_PUT_DOWN)
    _extra_slot_items[slot_index] = item
    _active_origin = ""
    _active_origin_extra_index = -1
    _cargo_grid.cancel_placement()

# ══ Grid construction (PackingGrid delegates) ══════════════════════════════════


func _build_extra_slots() -> void:
    var count: int = RunManager.run.car_data.extra_slot_count
    _trailer_section.visible = count > 0
    for i in count:
        var cell: ExtraSlotCell = ExtraSlotCellScene.instantiate()
        cell.setup(i)
        cell.hovered.connect(_on_extra_slot_hovered)
        cell.unhovered.connect(_on_extra_slot_unhovered)
        cell.slot_pressed.connect(_on_extra_slot_pressed)
        cell.slot_cancel.connect(_on_extra_slot_cancel)
        _extra_slot_container.add_child(cell)
        _extra_slot_cells[i] = cell


func _build_item_list() -> void:
    for entry: ItemEntry in _won_items:
        var row: CargoItemRow = CargoItemRowScene.instantiate()
        row.setup(entry)
        row.row_pressed.connect(_on_item_row_pressed)
        row.tooltip_requested.connect(_on_row_tooltip_requested)
        row.tooltip_dismissed.connect(_on_row_tooltip_dismissed)
        _item_list_vbox.add_child(row)
        _item_rows[entry] = row

# ══ Placement helpers ══════════════════════════════════════════════════════════


func _would_exceed_weight(entry: ItemEntry) -> bool:
    if RunManager.run == null:
        ToastManager.show_dev_error("would_exceed_weight called with no active run")
        return true

    var max_weight: float = RunManager.run.car_data.max_weight
    var entry_weight: float = entry.get_weight()

    if _cargo_grid.is_item_placed(entry):
        return false
    return (_weight_used + entry_weight) > max_weight


func _get_pending_weight(entry: ItemEntry) -> float:
    if _cargo_grid.is_item_placed(entry):
        return 0.0
    return entry.get_weight()


func _get_pending_slots(entry: ItemEntry) -> int:
    if _cargo_grid.is_item_placed(entry):
        return 0
    return _cargo_grid.get_active_cells(entry).size()

# ══ UI helpers ═════════════════════════════════════════════════════════════════


func _recalc_totals() -> void:
    _slots_used = 0
    _weight_used = 0.0
    _loaded_items = _cargo_grid.get_placed_items()

    for entry: ItemEntry in _loaded_items:
        _slots_used += entry.get_cells().size()
        _weight_used += entry.get_weight()

    for entry: ItemEntry in _extra_slot_items:
        if entry != null and entry not in _loaded_items:
            _loaded_items.append(entry)


func _refresh_ui() -> void:
    var car: CarData = RunManager.run.car_data
    var cols: int = car.grid_columns
    var rows: int = car.grid_rows
    var max_slots: int = cols * rows
    var max_weight: float = car.max_weight

    var pending_slots := 0
    var pending_weight := 0.0
    var weight_exceeded := false

    var held_item = _cargo_grid.active_item
    if _cargo_grid.phase == PackingGrid.Phase.ITEM_HELD and held_item != null:
        pending_slots = _get_pending_slots(held_item)
        pending_weight = _get_pending_weight(held_item)
        weight_exceeded = (_weight_used + pending_weight) > max_weight

    _update_summary(pending_slots, pending_weight, weight_exceeded, max_slots, max_weight)

    if weight_exceeded:
        _error_label.text = TranslationServer.translate("UI_WEIGHT_EXCEEDED")
    else:
        _error_label.text = ""

    _cargo_grid.refresh_visuals()
    _refresh_extra_slot_visuals()
    _refresh_item_list_visuals()


func _update_summary(pending_slots: int, pending_weight: float, weight_exceeded: bool, max_slots: int, max_weight: float) -> void:
    # ── Loaded items count and value ─────────────────────────────────────────
    var loaded_count := _loaded_items.size()
    var loaded_value_min := 0
    var loaded_value_max := 0
    for entry: ItemEntry in _loaded_items:
        if not entry.is_veiled():
            loaded_value_min += entry.estimated_value_min
            loaded_value_max += entry.estimated_value_max

    _summary_loaded_count.text = "%d item%s" % [loaded_count, "s" if loaded_count != 1 else ""]

    if loaded_count > 0 and loaded_value_max > 0:
        _summary_loaded_value.text = "$%d – $%d" % [loaded_value_min, loaded_value_max]
    else:
        _summary_loaded_value.text = ""

    # ── Unloaded items count and on-site sell ───────────────────────────────
    var unplaced_count := _won_items.size() - loaded_count
    var unplaced_sell := unplaced_count * Economy.ONSITE_SELL_PRICE
    _summary_unloaded_count.text = "%d item%s" % [unplaced_count, "s" if unplaced_count != 1 else ""]
    _summary_unloaded_sell.text = TranslationServer.translate("UI_ONSITE_LABEL") % unplaced_sell

    # ── Weight ──────────────────────────────────────────────────────────────
    if pending_weight > 0.0:
        _summary_weight.text = "%.1f + %.1f / %.1f kg" % [_weight_used, pending_weight, max_weight]
        if weight_exceeded:
            _summary_weight.add_theme_color_override(&"font_color", ThemeColors.LOSS_RED)
        else:
            _summary_weight.add_theme_color_override(&"font_color", ThemeColors.PROFIT_GREEN)
    else:
        _summary_weight.text = "%.1f / %.1f kg" % [_weight_used, max_weight]
        _summary_weight.remove_theme_color_override(&"font_color")

    # ── Slots ───────────────────────────────────────────────────────────────
    if pending_slots > 0:
        _summary_slots.text = "%d + %d / %d" % [_slots_used, pending_slots, max_slots]
    else:
        _summary_slots.text = "%d / %d" % [_slots_used, max_slots]

    # ── Trailer damage risk ─────────────────────────────────────────────────
    var has_trailer_items := false
    for entry: ItemEntry in _extra_slot_items:
        if entry != null:
            has_trailer_items = true
            break

    var trailer_damage: float = RunManager.run.car_data.trailer_damage_chance
    if has_trailer_items and trailer_damage > 0.0:
        _summary_trailer_line.visible = true
        _summary_trailer_value.text = "%d%%" % int(trailer_damage * 100)
    else:
        _summary_trailer_line.visible = false


func _refresh_extra_slot_visuals() -> void:
    for i: int in _extra_slot_cells:
        var cell: ExtraSlotCell = _extra_slot_cells[i]
        var style: StyleBoxFlat
        var entry: ItemEntry = _extra_slot_items[i] if i < _extra_slot_items.size() else null
        if entry != null:
            if i == _hover_extra_index and _cargo_grid.phase != PackingGrid.Phase.ITEM_HELD:
                style = _get_extra_hover_style(entry)
            else:
                style = _get_extra_normal_style(entry)
        elif i == _hover_extra_index and _cargo_grid.phase == PackingGrid.Phase.ITEM_HELD:
            style = get_theme_stylebox(&"drop_target", &"ExtraSlotCell")
        else:
            style = get_theme_stylebox(&"default", &"ExtraSlotCell")
        var icon_text := ""
        if entry != null:
            var words = ItemEntryDisplayHelper.display_name(entry).split(" ", false)
            icon_text = (words[0].left(1) if words.size() > 0 else "") + (words[1].left(1) if words.size() > 1 else "")
            icon_text = icon_text.to_upper()

        cell.set_visuals(style, icon_text)


func _get_extra_normal_style(entry: ItemEntry) -> StyleBoxFlat:
    if not _extra_slot_item_styles.has(entry):
        _extra_slot_item_styles[entry] = PackingGrid.make_stylebox(
            _cargo_grid.resolve_color(entry),
            _cargo_grid.resolve_border_color(entry),
        )
    return _extra_slot_item_styles[entry]


func _get_extra_hover_style(entry: ItemEntry) -> StyleBoxFlat:
    if not _extra_slot_hover_styles.has(entry):
        _extra_slot_hover_styles[entry] = PackingGrid.make_stylebox(
            _cargo_grid.resolve_color(entry).lightened(0.2),
            _cargo_grid.resolve_border_color(entry).lightened(0.15),
        )
    return _extra_slot_hover_styles[entry]


func _refresh_item_list_visuals() -> void:
    for entry: ItemEntry in _item_rows:
        var row: CargoItemRow = _item_rows[entry]
        row.set_loaded(_is_item_loaded(entry))
        var held = _cargo_grid.active_item == entry and _cargo_grid.phase == PackingGrid.Phase.ITEM_HELD
        row.set_holding(held)


func _is_item_loaded(entry: ItemEntry) -> bool:
    return _cargo_grid.is_item_placed(entry) or entry in _extra_slot_items


func _build_summary_text() -> String:
    var loaded_count := _loaded_items.size()
    var unplaced_count := _won_items.size() - loaded_count
    var proceeds := unplaced_count * Economy.ONSITE_SELL_PRICE
    return (
        "Loaded items: %d\n" % loaded_count +
        "Left behind: %d  (sold on-site for $%d)\n\n" % [unplaced_count, proceeds] +
        "Continue to settlement?"
    )

# ══ Debug overlay ══════════════════════════════════════════════════════════════
# Gated by Debug.enabled (OS.is_debug_build() AND SettingsStore.debug_mode).


func _init_debug_overlay() -> void:
    if not Debug.enabled:
        return

    # ── Auto-pack button ──────────────────────────────────────────────────
    _debug_auto_pack_btn = Button.new()
    _debug_auto_pack_btn.text = "Auto-Pack Items"
    _debug_auto_pack_btn.pressed.connect(_debug_auto_pack)
    _debug_auto_pack_btn.anchor_left = 0.0
    _debug_auto_pack_btn.anchor_top = 1.0
    _debug_auto_pack_btn.anchor_right = 0.0
    _debug_auto_pack_btn.anchor_bottom = 1.0
    _debug_auto_pack_btn.offset_left = 152.0
    _debug_auto_pack_btn.offset_top = -56.0
    _debug_auto_pack_btn.offset_bottom = -16.0
    _debug_auto_pack_btn.custom_minimum_size = Vector2(150, 40)
    # node-src: debug
    add_child(_debug_auto_pack_btn)

    # ── Stuff-all & go button ─────────────────────────────────────────────
    _debug_stuff_btn = Button.new()
    _debug_stuff_btn.text = "Stuff All & Go"
    _debug_stuff_btn.pressed.connect(_debug_stuff_all)
    _debug_stuff_btn.anchor_left = 0.0
    _debug_stuff_btn.anchor_top = 1.0
    _debug_stuff_btn.anchor_right = 0.0
    _debug_stuff_btn.anchor_bottom = 1.0
    _debug_stuff_btn.offset_left = 310.0
    _debug_stuff_btn.offset_top = -56.0
    _debug_stuff_btn.offset_bottom = -16.0
    _debug_stuff_btn.custom_minimum_size = Vector2(150, 40)
    # node-src: debug
    add_child(_debug_stuff_btn)


func _on_debug_toggled(is_enabled: bool) -> void:
    if is_enabled:
        if _debug_auto_pack_btn == null:
            _init_debug_overlay()
        else:
            _debug_auto_pack_btn.visible = true
            _debug_stuff_btn.visible = true
    else:
        if _debug_auto_pack_btn != null:
            _debug_auto_pack_btn.visible = false
            _debug_stuff_btn.visible = false


## One-press legal auto-pack. Places every unplaced item into the grid using
## first-fit (left-to-right, top-to-bottom), then spills overflow into trailer
## slots. Items that fit nowhere stay unloaded. No rearrangement — only fills.
func _debug_auto_pack() -> void:
    if not Debug.enabled:
        return

    var cols: int = RunManager.run.car_data.grid_columns
    var rows: int = RunManager.run.car_data.grid_rows

    for entry: ItemEntry in _won_items:
        if _is_item_loaded(entry):
            continue

        var placed := false

        # First-fit: scan grid left-to-right, top-to-bottom.
        for y in rows:
            for x in cols:
                var origin := Vector2i(x, y)
                if _cargo_grid.can_place(entry, origin):
                    _cargo_grid.place(entry, origin)
                    placed = true
                    _recalc_totals()
                    break
            if placed:
                break

        if placed:
            continue

        # Spill overflow into the first free trailer slot.
        for i in _extra_slot_items.size():
            if _extra_slot_items[i] == null:
                _extra_slot_items[i] = entry
                placed = true
                break

    _recalc_totals()
    _refresh_ui()


## One-press stuff-all: commits every won item as main cargo regardless of
## grid/weight capacity, with empty trailer and zero on-site proceeds, and
## jumps straight to run review with no confirm popup.
func _debug_stuff_all() -> void:
    if not Debug.enabled:
        return

    var cargo: Array[ItemEntry] = []
    for entry: ItemEntry in _won_items:
        cargo.append(entry)

    RunManager.commit_cargo(cargo, [], 0)
    SceneRouter.go_to_run_review()

# ══ Tooltip helpers ════════════════════════════════════════════════════════════


func _show_tooltip_for_item(entry: ItemEntry, anchor: Rect2) -> void:
    if _cargo_grid.phase == PackingGrid.Phase.ITEM_HELD:
        return
    _hovered_item = entry
    if entry is ItemEntry:
        _tooltip.show_for(entry as ItemEntry, anchor)


func _hide_tooltip() -> void:
    _hovered_item = null
    _tooltip.hide_popup()
