# lot_browse_scene.gd
# Lot browse loop — player cycles through sampled lots and chooses to
# Enter (inspect + auction) or Pass each one.
#
# State persists across scene transitions via RunRecord.browse_lots / browse_index.
#
# First load  : browse_lots is empty → sample lots → show index 0.
# Return visit: browse_lots already populated → resume at current browse_index.
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────

const LotCardScene := preload("res://game/run/lot_browse/lot_card/lot_card.tscn")

# ── Node references ───────────────────────────────────────────────────────────

@onready var _lot_card_container: HBoxContainer = $RootVBox/ScrollContainer/LotCardContainer
@onready var _cargo_panel: VBoxContainer = $RootVBox/CargoPanel
@onready var _cargo_button: Button = $RootVBox/CargoPanel/CargoButton
@onready var _skip_button: Button = $RootVBox/SkipButton
@onready var _skip_confirm_popup: ConfirmationDialog = $SkipConfirmPopup

# ── State ─────────────────────────────────────────────────────────────────────

# var _lot_card: LotCard = null
var _lot_cards: Array[LotCard] = []

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _skip_button.pressed.connect(_on_skip_pressed)
    _cargo_button.pressed.connect(_on_cargo_pressed)
    _skip_confirm_popup.confirmed.connect(_on_skip_confirmed)

    var record: RunRecord = RunManager.run_record
    if record.browse_lots.is_empty():
        record.browse_lots = _sample_lots(record.location_data)
        record.browse_index = 0

    _build_all_cards()
    _refresh_view()

# ══ View helpers ══════════════════════════════════════════════════════════════


func _build_all_cards() -> void:
    var record: RunRecord = RunManager.run_record
    var total: int = record.browse_lots.size()

    for i in total:
        var card := LotCardScene.instantiate() as LotCard
        _lot_card_container.add_child(card)
        card.setup(record.browse_lots[i], i, total)

        card.enter_pressed.connect(_on_enter_pressed)
        card.pass_pressed.connect(_on_pass_pressed)
        _lot_cards.append(card)


func _refresh_view() -> void:
    var record: RunRecord = RunManager.run_record

    if record.browse_index >= record.browse_lots.size():
        _show_cargo_state()
        return

    _cargo_panel.visible = false
    _lot_card_container.visible = true

    for i in _lot_cards.size():
        _lot_cards[i].set_active(i == record.browse_index)


func _show_cargo_state() -> void:
    _lot_card_container.visible = false
    _cargo_panel.visible = true
    _skip_button.visible = false

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_enter_pressed() -> void:
    var record: RunRecord = RunManager.run_record
    var lot_data: LotData = record.browse_lots[record.browse_index]
    var entry := LotEntry.create(lot_data)
    record.set_lot(entry)
    record.browse_index += 1
    GameManager.go_to_inspection()


func _on_pass_pressed() -> void:
    RunManager.run_record.browse_index += 1
    _refresh_view()


func _on_skip_pressed() -> void:
    var record: RunRecord = RunManager.run_record
    var remaining: int = record.browse_lots.size() - record.browse_index
    _skip_confirm_popup.dialog_text = (
        "Skip the remaining %d lot(s) and go straight to cargo?" % remaining
    )
    _skip_confirm_popup.popup_centered()


func _on_skip_confirmed() -> void:
    GameManager.go_to_cargo()


func _on_cargo_pressed() -> void:
    GameManager.go_to_cargo()

# ══ Sampling ══════════════════════════════════════════════════════════════════


func _sample_lots(location_data: LocationData) -> Array[LotData]:
    var pool: Array[LotData] = location_data.lot_pool.duplicate()
    pool.shuffle()
    var count := mini(location_data.lot_number, pool.size())
    return pool.slice(0, count)
