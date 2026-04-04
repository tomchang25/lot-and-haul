# location_browse_scene.gd
# Location browse loop — player cycles through sampled lots and chooses to
# Enter (inspect + auction) or Pass each one.
#
# State persists across scene transitions via RunRecord.browse_lots / browse_index.
#
# First load  : browse_lots is empty → sample lots → show index 0.
# Return visit: browse_lots already populated → resume at current browse_index.
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────

const LotCardScene := preload("res://game/location_browse/lot_card/lot_card.tscn")

# ── Node references ───────────────────────────────────────────────────────────

@onready var _lot_card_container: Control = $RootVBox/LotCardContainer
@onready var _cargo_panel: VBoxContainer = $RootVBox/CargoPanel
@onready var _cargo_button: Button = $RootVBox/CargoPanel/CargoButton
@onready var _skip_button: Button = $RootVBox/SkipButton

# ── State ─────────────────────────────────────────────────────────────────────

var _lot_card: LotCard = null

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
	_skip_button.pressed.connect(_on_skip_pressed)
	_cargo_button.pressed.connect(_on_cargo_pressed)

	var record: RunRecord = GameManager.run_record
	if record.browse_lots.is_empty():
		record.browse_lots = _sample_lots(record.location_data)
		record.browse_index = 0

	_refresh_view()

# ══ View helpers ══════════════════════════════════════════════════════════════


func _refresh_view() -> void:
	var record: RunRecord = GameManager.run_record
	if record.browse_index >= record.browse_lots.size():
		_show_cargo_state()
	else:
		_show_lot_card(record.browse_index, record.browse_lots.size())


func _show_lot_card(index: int, total: int) -> void:
	_cargo_panel.visible = false
	_lot_card_container.visible = true

	if _lot_card != null:
		_lot_card.queue_free()

	_lot_card = LotCardScene.instantiate() as LotCard
	_lot_card_container.add_child(_lot_card)
	_lot_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)

	var lot_data: LotData = GameManager.run_record.browse_lots[index]
	_lot_card.setup(lot_data, index, total)
	_lot_card.enter_pressed.connect(_on_enter_pressed)
	_lot_card.pass_pressed.connect(_on_pass_pressed)


func _show_cargo_state() -> void:
	_lot_card_container.visible = false
	if _lot_card != null:
		_lot_card.queue_free()
		_lot_card = null
	_cargo_panel.visible = true

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_enter_pressed() -> void:
	var record: RunRecord = GameManager.run_record
	var lot_data: LotData = record.browse_lots[record.browse_index]
	var entry := LotEntry.create(lot_data)
	record.set_lot(entry)
	record.browse_index += 1
	GameManager.go_to_inspection()


func _on_pass_pressed() -> void:
	GameManager.run_record.browse_index += 1
	_refresh_view()


func _on_skip_pressed() -> void:
	GameManager.go_to_cargo()


func _on_cargo_pressed() -> void:
	GameManager.go_to_cargo()

# ══ Sampling ══════════════════════════════════════════════════════════════════


func _sample_lots(location_data: LocationData) -> Array[LotData]:
	var pool: Array[LotData] = location_data.lot_pool.duplicate()
	pool.shuffle()
	var count := mini(location_data.lot_number, pool.size())
	return pool.slice(0, count)
