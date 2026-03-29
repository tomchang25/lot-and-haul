# inspection_scene.gd
# Block 02 — Inspection phase; player spends stamina to browse or examine lot items.
# Reads:  GameManager.current_lot, GameManager.inspection_results
# Writes: GameManager.inspection_results
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────

const MAX_STAMINA := 8
const BROWSE_COST := 1
const EXAMINE_COST_BASE := 3

const ITEM_COLS := 2
const ITEM_SIZE := Vector2(200.0, 250.0)
const ITEM_GAP := Vector2(32.0, 28.0)

# Top-left corner of the grid — centred horizontally, leaving room for the HUD row
const GRID_ORIGIN := Vector2(376.0, 90.0)

const ItemDisplayScene := preload("uid://bitemdtscn001")

# ── State ─────────────────────────────────────────────────────────────────────

var _stamina := MAX_STAMINA
var _active_item: ItemDisplay = null
var _item_displays: Array[ItemDisplay] = []

# ── Timer / tween handles ─────────────────────────────────────────────────────

var _pulse_tween: Tween = null

# ── Node references ───────────────────────────────────────────────────────────

@onready var _items_root: Control = $ItemsRoot
@onready var _stamina_hud: StaminaHUD = $HUD/StaminaHUD
@onready var _action_popup: ActionPopup = $HUD/ActionPopup
@onready var _start_btn: Button = $HUD/StartAuctionButton
@onready var _list_review: ListReviewPopup = $ListReviewPopup

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _action_popup.browse_requested.connect(_on_browse)
    _action_popup.examine_requested.connect(_on_examine)
    _action_popup.cancelled.connect(_on_popup_cancelled)
    _start_btn.pressed.connect(_on_start_auction_pressed)
    _list_review.back_requested.connect(_on_list_review_back)
    _list_review.auction_entered.connect(_on_auction_entered)

    _stamina_hud.update_stamina(_stamina, MAX_STAMINA)
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


func _on_item_clicked(display: ItemDisplay) -> void:
    _open_popup(display)


func _on_popup_cancelled() -> void:
    _close_popup()


func _on_browse() -> void:
    if _active_item == null:
        return
    var result := _get_result(_active_item.item_data)
    if result[&"level"] >= 1:
        _close_popup()
        return
    _spend_stamina(_active_item, 1, BROWSE_COST)


func _on_examine() -> void:
    if _active_item == null:
        return
    var result := _get_result(_active_item.item_data)
    if result[&"level"] >= 2:
        _close_popup()
        return
    var cost := 2 if result[&"level"] == 1 else EXAMINE_COST_BASE
    _spend_stamina(_active_item, 2, cost)


func _on_start_auction_pressed() -> void:
    _close_popup()
    _list_review.populate()
    _list_review.show()


func _on_list_review_back() -> void:
    _list_review.hide()


func _on_auction_entered() -> void:
    GameManager.go_to_auction()

# ══ Item display ══════════════════════════════════════════════════════════════


func _populate_item_displays() -> void:
    for i in GameManager.current_lot.size():
        var item: ItemData = GameManager.current_lot[i]

        var display: ItemDisplay = ItemDisplayScene.instantiate()
        var col := i % ITEM_COLS
        var row := i / ITEM_COLS

        display.position = GRID_ORIGIN + Vector2(
            col * (ITEM_SIZE.x + ITEM_GAP.x),
            row * (ITEM_SIZE.y + ITEM_GAP.y),
        )
        display.custom_minimum_size = ITEM_SIZE
        _items_root.add_child(display)

        var result := _get_result(item)
        display.setup(item, result[&"level"])
        display.clicked.connect(_on_item_clicked)
        _item_displays.append(display)

# ══ Popup ═════════════════════════════════════════════════════════════════════


func _open_popup(display: ItemDisplay) -> void:
    _active_item = display
    var result := _get_result(display.item_data)
    _action_popup.refresh(result[&"level"], _stamina)

    # Position popup directly below the item card
    var rect := display.get_global_rect()
    _action_popup.position = Vector2(rect.position.x, rect.position.y + rect.size.y + 6.0)
    _action_popup.show()


func _close_popup() -> void:
    _action_popup.hide()
    _active_item = null

# ══ Stamina ═══════════════════════════════════════════════════════════════════


func _spend_stamina(display: ItemDisplay, target_level: int, cost: int) -> void:
    if _stamina < cost:
        return

    _stamina -= cost

    var item := display.item_data
    GameManager.inspection_results[item] = {
        &"level": target_level,
        &"clues_revealed": ClueEvaluator.get_clues_revealed(item, target_level),
    }
    display.set_level(target_level)
    _stamina_hud.update_stamina(_stamina, MAX_STAMINA)
    _close_popup()

    if _stamina <= 0:
        _begin_exit_pulse()

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

# ══ Inspection logic ══════════════════════════════════════════════════════════


func _get_result(item: ItemData) -> Dictionary:
    return GameManager.inspection_results.get(item, { &"level": 0, &"clues_revealed": 0 })
