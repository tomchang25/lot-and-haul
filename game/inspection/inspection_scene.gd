# inspection_scene.gd
# Block 02 — Inspection phase; player spends stamina to advance item identity layers.
# Reads:  GameManager.item_entries
# Writes: ItemEntry.layer_index
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────

const ITEM_COLS := 2
const ITEM_SIZE := Vector2(200.0, 250.0)
const ITEM_GAP := Vector2(32.0, 28.0)

# Top-left corner of the grid — centred horizontally, leaving room for the HUD row
const GRID_ORIGIN := Vector2(376.0, 90.0)

const ItemCardScene := preload("uid://bw23cjkf40y5r")

# ── State ─────────────────────────────────────────────────────────────────────

var _active_item: ItemCard = null
var _item_displays: Array[ItemCard] = []

# Maps each ItemCard to its corresponding ItemEntry for popup refresh.
var _entry_for_display: Dictionary = { }

var _ctx: ItemViewContext = null

# ── Timer / tween handles ─────────────────────────────────────────────────────

var _pulse_tween: Tween = null

# ── Node references ───────────────────────────────────────────────────────────

@onready var _items_grid: GridContainer = $HUD/Panel/MarginContainer/ScrollContainer/ItemsGrid
@onready var _action_popup: ActionPopup = $ActionPopup
@onready var _start_btn: Button = $HUD/Footer/StartAuctionButton
@onready var _pass_btn: Button = $HUD/Footer/PassButton
@onready var _list_review: ListReviewPopup = $ListReviewPopup
@onready var _confirm_popup: AcceptDialog = $ConfirmPopup

@onready var _stamina_hud: StaminaHUD = $StaminaHUD

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _ctx = ItemViewContext.for_inspection()

    _action_popup.potential_inspect_requested.connect(_on_potential_inspect)
    _action_popup.condition_inspect_requested.connect(_on_condition_inspect)
    _action_popup.cancelled.connect(_on_popup_cancelled)
    _start_btn.pressed.connect(_on_start_auction_pressed)
    _pass_btn.pressed.connect(_on_pass_pressed)
    _list_review.back_requested.connect(_on_list_review_back)
    _list_review.auction_entered.connect(_on_auction_entered)
    _confirm_popup.confirmed.connect(_on_confirm_popup_confirmed)

    _stamina_hud.update_stamina(RunManager.run_record.stamina, RunManager.run_record.max_stamina)
    _stamina_hud.update_actions(RunManager.run_record.actions_remaining)

    _action_popup.hide()
    _populate_item_displays()


func _unhandled_input(event: InputEvent) -> void:
    if not _action_popup.visible:
        return
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        _close_popup()
        get_viewport().set_input_as_handled()
        return
    if event is InputEventMouseButton \
    and event.pressed \
    and event.button_index == MOUSE_BUTTON_LEFT:
        _close_popup()
        get_viewport().set_input_as_handled()

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_item_clicked(display: ItemCard) -> void:
    _open_popup(display)


func _on_popup_cancelled() -> void:
    _close_popup()


func _on_potential_inspect() -> void:
    if _active_item == null:
        return
    var entry: ItemEntry = _entry_for_display[_active_item]
    if RunManager.run_record.stamina < ActionPopup.POTENTIAL_COST:
        return
    if RunManager.run_record.actions_remaining < 0:
        return

    RunManager.run_record.stamina -= ActionPopup.POTENTIAL_COST
    RunManager.run_record.actions_remaining -= 1

    entry.potential_inspect_level += 1
    _active_item.refresh(&"potential")
    _stamina_hud.update_stamina(RunManager.run_record.stamina, RunManager.run_record.max_stamina)
    _stamina_hud.update_actions(RunManager.run_record.actions_remaining)
    _action_popup.refresh(entry)


func _on_condition_inspect() -> void:
    if _active_item == null:
        return
    var entry: ItemEntry = _entry_for_display[_active_item]
    if RunManager.run_record.stamina < ActionPopup.CONDITION_COST:
        return
    if RunManager.run_record.actions_remaining < 0:
        return

    RunManager.run_record.stamina -= ActionPopup.CONDITION_COST
    RunManager.run_record.actions_remaining -= 1

    entry.condition_inspect_level += 1
    _active_item.refresh(&"condition")
    _stamina_hud.update_stamina(RunManager.run_record.stamina, RunManager.run_record.max_stamina)
    _stamina_hud.update_actions(RunManager.run_record.actions_remaining)
    _action_popup.refresh(entry)


func _on_start_auction_pressed() -> void:
    _close_popup()
    _list_review.populate()
    _list_review.show()


func _on_pass_pressed() -> void:
    _confirm_popup.dialog_text = "Skip inspection and go to run review?\nAny remaining stamina will be lost."
    _confirm_popup.popup_centered()


func _on_list_review_back() -> void:
    _list_review.hide()


func _on_auction_entered() -> void:
    GameManager.go_to_auction()


func _on_confirm_popup_confirmed() -> void:
    _close_popup()
    if _pulse_tween:
        _pulse_tween.kill()
    GameManager.go_to_run_review()

# ══ Item display ══════════════════════════════════════════════════════════════


func _populate_item_displays() -> void:
    for child in _items_grid.get_children():
        child.queue_free()

    var item_entries: Array[ItemEntry] = RunManager.run_record.lot_items
    for i: int in item_entries.size():
        var entry: ItemEntry = item_entries[i]

        var display: ItemCard = ItemCardScene.instantiate()
        display.custom_minimum_size = ITEM_SIZE
        _items_grid.add_child(display)

        display.setup(entry, _ctx)
        display.clicked.connect(_on_item_clicked)
        _item_displays.append(display)
        _entry_for_display[display] = entry

# ══ Popup ═════════════════════════════════════════════════════════════════════


func _open_popup(display: ItemCard) -> void:
    _active_item = display
    var entry: ItemEntry = _entry_for_display[display]
    _action_popup.refresh(entry)

    # Position popup directly below the item card
    var rect := display.get_global_rect()
    _action_popup.position = Vector2(rect.position.x, rect.position.y + rect.size.y + 6.0)
    _action_popup.show()


func _close_popup() -> void:
    _action_popup.hide()
    _active_item = null

# ══ Exit pulse ════════════════════════════════════════════════════════════════


func _begin_exit_pulse() -> void:
    if _pulse_tween:
        _pulse_tween.kill()
    _pulse_tween = create_tween().set_loops()
    _pulse_tween.tween_property(
        _start_btn,
        "modulate",
        Color(1.5, 1.25, 0.3, 1.0),
        0.5,
    ).set_ease(Tween.EASE_IN_OUT)
    _pulse_tween.tween_property(
        _start_btn,
        "modulate",
        Color.WHITE,
        0.5,
    ).set_ease(Tween.EASE_IN_OUT)
