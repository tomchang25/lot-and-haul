extends Control

const MAX_STAMINA := 8
const _BROWSE_COST := 1
const _EXAMINE_COST_BASE := 3

const _ItemDisplayScene := preload("res://ui/inspection/item_display/item_display.tscn")

# 2×2 grid layout constants (screen-space, assumes ~1152×648 default viewport)
const _ITEM_COLS := 2
const _ITEM_SIZE := Vector2(200.0, 250.0)
const _ITEM_GAP := Vector2(32.0, 28.0)
# Top-left corner of the grid — centred horizontally, leaving room for the HUD row
const _GRID_ORIGIN := Vector2(376.0, 90.0)

var _stamina := MAX_STAMINA
var _active_item: ItemDisplay = null
var _item_displays: Array[ItemDisplay] = []
var _pulse_tween: Tween = null

@onready var _items_root: Control = $ItemsRoot
@onready var _stamina_hud: StaminaHUD = $HUD/StaminaHUD
@onready var _action_popup: ActionPopup = $HUD/ActionPopup
@onready var _start_btn: Button = $HUD/StartAuctionButton


func _ready() -> void:
	_stamina_hud.update_stamina(_stamina, MAX_STAMINA)
	_action_popup.hide()

	_action_popup.browse_requested.connect(_on_browse)
	_action_popup.examine_requested.connect(_on_examine)
	_action_popup.cancelled.connect(_close_popup)
	_start_btn.pressed.connect(_on_start_auction_pressed)

	_build_item_displays()


func _build_item_displays() -> void:
	for i in GameManager.current_lot.size():
		var item: ItemData = GameManager.current_lot[i]

		var display: ItemDisplay = _ItemDisplayScene.instantiate()
		var col := i % _ITEM_COLS
		var row := i / _ITEM_COLS
		display.position = _GRID_ORIGIN + Vector2(
			col * (_ITEM_SIZE.x + _ITEM_GAP.x),
			row * (_ITEM_SIZE.y + _ITEM_GAP.y)
		)
		display.custom_minimum_size = _ITEM_SIZE
		_items_root.add_child(display)

		var result: Dictionary = GameManager.inspection_results.get(
			item, {&"level": 0, &"clues_revealed": 0}
		)
		display.setup(item, result[&"level"])
		display.clicked.connect(_on_item_clicked.bind(display))
		_item_displays.append(display)


# ── Input ─────────────────────────────────────────────────────────────────────

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


# ── Item click ─────────────────────────────────────────────────────────────────

func _on_item_clicked(display: ItemDisplay) -> void:
	if _stamina <= 0:
		return
	_open_popup(display)


func _open_popup(display: ItemDisplay) -> void:
	_active_item = display
	var item := display.item_data
	var result: Dictionary = GameManager.inspection_results.get(
		item, {&"level": 0, &"clues_revealed": 0}
	)
	_action_popup.refresh(result[&"level"], _stamina)

	# Position popup directly below the item card
	var rect := display.get_global_rect()
	_action_popup.position = Vector2(rect.position.x, rect.position.y + rect.size.y + 6.0)
	_action_popup.show()


func _close_popup() -> void:
	_action_popup.hide()
	_active_item = null


# ── Actions ────────────────────────────────────────────────────────────────────

func _on_browse() -> void:
	if _active_item == null:
		return
	var result: Dictionary = _get_result(_active_item.item_data)
	if result[&"level"] >= 1:
		_close_popup()
		return
	_spend_stamina(_active_item, 1, _BROWSE_COST)


func _on_examine() -> void:
	if _active_item == null:
		return
	var result: Dictionary = _get_result(_active_item.item_data)
	if result[&"level"] >= 2:
		_close_popup()
		return
	var cost := 2 if result[&"level"] == 1 else _EXAMINE_COST_BASE
	_spend_stamina(_active_item, 2, cost)


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


# ── Exit pulse ─────────────────────────────────────────────────────────────────

func _begin_exit_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(
		_start_btn, "modulate", Color(1.5, 1.25, 0.3, 1.0), 0.5
	).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(
		_start_btn, "modulate", Color.WHITE, 0.5
	).set_ease(Tween.EASE_IN_OUT)


func _on_start_auction_pressed() -> void:
	pass  # TODO: transition to Block 03 (List Review)


# ── Helpers ────────────────────────────────────────────────────────────────────

func _get_result(item: ItemData) -> Dictionary:
	return GameManager.inspection_results.get(item, {&"level": 0, &"clues_revealed": 0})
