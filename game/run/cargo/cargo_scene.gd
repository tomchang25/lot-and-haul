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

# ── State ──────────────────────────────────────────────────────────────────────

var _won_items: Array[ItemEntry] = []

var _active_origin: String = ""
var _active_origin_extra_index: int = -1

var _extra_slot_items: Array[ItemEntry] = []
var _hover_extra_index: int = -1

# ── Item List State ────────────────────────────────────────────────────────────

var _loaded_items: Array = []

# ── Stats ──────────────────────────────────────────────────────────────────────

var _slots_used: int = 0
var _weight_used: float = 0.0

# ── Detail Panel State ─────────────────────────────────────────────────────────

var _selected_entry: ItemEntry = null
var _preview_entry: ItemEntry = null
var _last_highlighted_entry: ItemEntry = null

# Debug overlay buttons — created by _init_debug_overlay().
var _debug_auto_pack_btn: Button = null
var _debug_stuff_btn: Button = null

# ── Node references ────────────────────────────────────────────────────────────

@onready var _item_list: CargoItemListPanel = %ItemListPanel
@onready var _vehicle_panel: CargoVehiclePanel = %VehiclePanel
@onready var _detail_panel: ItemDetailPanel = %DetailPanel
@onready var _confirm_popup: ConfirmationDialog = %ConfirmPopup

var _cargo_grid: PackingGrid:
    get:
        return _vehicle_panel.get_grid()

var _summary_panel: RunSummaryPanel:
    get:
        return _vehicle_panel.get_run_summary_panel()

# ══ Lifecycle ══════════════════════════════════════════════════════════════════


func _ready() -> void:
    if RunManager.run == null:
        ToastManager.show_error("Cargo scene failed to load. Returning to hub.")
        SceneRouter.go_to_hub.call_deferred()
        return

    RunManager.set_resume_target(RunStore.RESUME_CARGO)
    SaveManager.save()

    _vehicle_panel.reset_pressed.connect(_on_reset_pressed)
    _vehicle_panel.continue_pressed.connect(_on_continue_pressed)
    _vehicle_panel.continue_button.press_event = CONFIRM
    _confirm_popup.confirmed.connect(_on_confirm_popup_confirmed)

    _vehicle_panel.extra_slot_pressed.connect(_on_extra_slot_pressed)
    _vehicle_panel.extra_slot_hovered.connect(_on_extra_slot_hovered)
    _vehicle_panel.extra_slot_unhovered.connect(_on_extra_slot_unhovered)
    _vehicle_panel.extra_slot_cancel.connect(_on_extra_slot_cancel)

    _won_items = RunManager.run.won_items

    _extra_slot_items.resize(RunManager.run.car_data.extra_slot_count)
    _extra_slot_items.fill(null)

    # ── Configure PackingGrid ─────────────────────────────────────────────
    _cargo_grid.setup_default_callbacks(_won_items)
    _cargo_grid.additional_validator = _packing_weight_validator
    var cols: int = RunManager.run.car_data.grid_columns
    var rows: int = RunManager.run.car_data.grid_rows

    _vehicle_panel.item_clicked.connect(_on_packing_grid_item_clicked)
    _vehicle_panel.cell_clicked.connect(_on_packing_grid_cell_clicked)
    _vehicle_panel.placement_cancelled.connect(_on_packing_grid_placement_cancelled)
    _vehicle_panel.hover_started.connect(_on_packing_grid_hover_started)
    _vehicle_panel.hover_ended.connect(_on_packing_grid_hover_ended)

    _cargo_grid.setup(cols, rows)

    _build_item_list()
    _vehicle_panel.build_extra_slots(RunManager.run.car_data.extra_slot_count)

    _recalc_totals()
    _refresh_ui()
    Debug.toggled.connect(_on_debug_toggled)
    if Debug.enabled:
        _init_debug_overlay()
    Director.register_scene(
        "cargo",
        {
            "item_list": _item_list,
            "cargo_grid": _cargo_grid,
            "continue_btn": _vehicle_panel.continue_button,
            "reset_btn": _vehicle_panel.reset_button,
            "detail_panel": _detail_panel,
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
    _hide_detail()
    if _last_highlighted_entry != null:
        _item_list.set_external_highlight(_last_highlighted_entry, false)
        _last_highlighted_entry = null
    var entry: ItemEntry = item as ItemEntry
    AudioManager.play_event(SELL_GRID_LIFT)
    _show_item_detail(entry, false)
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
        _item_list.set_external_highlight(entry, true)
        if _last_highlighted_entry != null and _last_highlighted_entry != entry:
            _item_list.set_external_highlight(_last_highlighted_entry, false)
        _last_highlighted_entry = entry
        _show_item_detail(entry, true)


func _on_packing_grid_hover_ended() -> void:
    _clear_preview_detail()
    if _last_highlighted_entry != null:
        _item_list.set_external_highlight(_last_highlighted_entry, false)
        _last_highlighted_entry = null

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_reset_pressed() -> void:
    _cargo_grid.reset()
    _extra_slot_items.fill(null)
    _vehicle_panel.clear_extra_slot_styles()

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
    _hide_detail()
    if _cargo_grid.phase == PackingGrid.Phase.IDLE:
        if _extra_slot_items[slot_index] != null:
            var entry: ItemEntry = _extra_slot_items[slot_index]
            _item_list.set_external_highlight(entry, false)
            _lift_from_extra(slot_index)
    elif _cargo_grid.phase == PackingGrid.Phase.ITEM_HELD:
        _place_item_in_extra(slot_index)


func _on_extra_slot_hovered(slot_index: int) -> void:
    if slot_index < 0 or slot_index >= _extra_slot_items.size():
        ToastManager.show_dev_error(
            "extra_slot_hovered with index out of range: %d (items size %d)" % [
                slot_index,
                _extra_slot_items.size(),
            ],
        )
        return

    _hover_extra_index = slot_index
    _vehicle_panel.refresh_extra_slot_visuals(_extra_slot_items, _cargo_grid, _hover_extra_index)

    if _cargo_grid.phase != PackingGrid.Phase.ITEM_HELD and _extra_slot_items[slot_index] != null:
        var entry: ItemEntry = _extra_slot_items[slot_index]
        _item_list.set_external_highlight(entry, true)
        _last_highlighted_entry = entry
        _show_item_detail(entry, true)


func _on_extra_slot_unhovered(slot_index: int) -> void:
    if _hover_extra_index == slot_index:
        _hover_extra_index = -1
    if _last_highlighted_entry != null:
        _item_list.set_external_highlight(_last_highlighted_entry, false)
        _last_highlighted_entry = null
    _vehicle_panel.refresh_extra_slot_visuals(_extra_slot_items, _cargo_grid, _hover_extra_index)
    _clear_preview_detail()


func _on_extra_slot_cancel(_slot_index: int) -> void:
    if _cargo_grid.phase == PackingGrid.Phase.ITEM_HELD:
        _cargo_grid.cancel_placement()

# ══ Item list signal handlers ══════════════════════════════════════════════════


func _on_item_row_pressed(entry: ItemEntry) -> void:
    _hide_detail()
    if _last_highlighted_entry != null:
        _item_list.set_external_highlight(_last_highlighted_entry, false)
        _last_highlighted_entry = null
    if _cargo_grid.phase == PackingGrid.Phase.ITEM_HELD:
        _cargo_grid.cancel_placement()
    _show_item_detail(entry, false)
    _lift_item_entry(entry)
    EventBus.tutorial_event.emit(TutorialEvents.CARGO_ITEM_SELECTED, { })


func _on_row_hovered(entry: ItemEntry, _anchor: Rect2) -> void:
    _show_item_detail(entry, true)


func _on_row_hover_ended() -> void:
    _clear_preview_detail()

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

# ══ Grid construction (delegated to components) ═══════════════════════════════


func _build_item_list() -> void:
    _item_list.rebuild(_won_items)
    _item_list.item_pick_requested.connect(_on_item_row_pressed)
    _item_list.tooltip_requested.connect(_on_row_hovered)
    _item_list.tooltip_dismissed.connect(_on_row_hover_ended)

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
    var max_weight: float = car.max_weight

    var held_item = _cargo_grid.active_item
    var weight_exceeded := false
    if _cargo_grid.phase == PackingGrid.Phase.ITEM_HELD and held_item != null and not _cargo_grid.is_item_placed(held_item):
        weight_exceeded = (_weight_used + held_item.get_weight()) > max_weight

    if weight_exceeded:
        _vehicle_panel.set_error(TranslationServer.translate("UI_WEIGHT_EXCEEDED"))
    else:
        _vehicle_panel.set_error("")

    _summary_panel.refresh(
        _loaded_items,
        _won_items,
        _extra_slot_items,
        _slots_used,
        _weight_used,
        car,
        _cargo_grid,
    )

    _cargo_grid.refresh_visuals()
    _vehicle_panel.refresh_extra_slot_visuals(_extra_slot_items, _cargo_grid, _hover_extra_index)
    _item_list.update_row_states(_cargo_grid, _extra_slot_items)


func _build_summary_text() -> String:
    var loaded_count := _loaded_items.size()
    var unplaced_count := _won_items.size() - loaded_count
    var proceeds := unplaced_count * Economy.ONSITE_SELL_PRICE
    return (
        "Loaded items: %d\n" % loaded_count +
        "Left behind: %d  (sold on-site for $%d)\n\n" % [unplaced_count, proceeds] +
        "Continue to settlement?"
    )

# ══ Detail panel helpers ═══════════════════════════════════════════════════════


func _show_item_detail(entry: ItemEntry, preview: bool) -> void:
    if preview:
        _preview_entry = entry
    else:
        _selected_entry = entry
    _detail_panel.setup(entry, true, true)


func _hide_detail() -> void:
    _preview_entry = null


func _clear_preview_detail() -> void:
    _preview_entry = null
    if _selected_entry != null:
        _detail_panel.setup(_selected_entry, true, true)
    else:
        _detail_panel.setup(null, true, true)

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


func _debug_auto_pack() -> void:
    if not Debug.enabled:
        return

    var cols: int = RunManager.run.car_data.grid_columns
    var rows: int = RunManager.run.car_data.grid_rows

    for entry: ItemEntry in _won_items:
        if _cargo_grid.is_item_placed(entry) or entry in _extra_slot_items:
            continue

        var placed := false

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

        for i in _extra_slot_items.size():
            if _extra_slot_items[i] == null:
                _extra_slot_items[i] = entry
                placed = true
                break

    _recalc_totals()
    _refresh_ui()


func _debug_stuff_all() -> void:
    if not Debug.enabled:
        return

    var cargo: Array[ItemEntry] = []
    for entry: ItemEntry in _won_items:
        cargo.append(entry)

    RunManager.commit_cargo(cargo, [], 0)
    SceneRouter.go_to_run_review()
