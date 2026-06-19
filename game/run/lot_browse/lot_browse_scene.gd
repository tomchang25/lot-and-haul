# lot_browse_scene.gd
# Lot browse loop — player cycles through sampled lots and chooses to
# Enter (inspect + auction) or Pass each one.
#
# State persists across scene transitions via RunStore.browse_lots / browse_index.
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
    if RunManager.run == null:
        ToastManager.show_error("Lot browse failed to load. Returning to hub.")
        SceneRouter.go_to_hub.call_deferred()
        return

    _skip_button.pressed.connect(_on_skip_pressed)
    _cargo_button.pressed.connect(_on_cargo_pressed)
    _skip_confirm_popup.confirmed.connect(_on_skip_confirmed)

    if RunManager.run.browse_lots.is_empty():
        RunManager.init_browse_lots(_sample_lots(RunManager.run.location_data))
        RunManager.set_resume_target(RunStore.RESUME_LOT_BROWSE)
        SaveManager.save()

    _build_all_cards()
    _refresh_view()
    Director.register_scene(
        "lot_browse",
        {
            "lot_cards": _lot_card_container,
            "cargo_btn": _cargo_button,
            "skip_btn": _skip_button,
        },
    )

# ══ View helpers ══════════════════════════════════════════════════════════════


func _build_all_cards() -> void:
    var lots: Array[LotData] = RunManager.run.browse_lots
    var total: int = lots.size()

    for i in total:
        var card := LotCardScene.instantiate() as LotCard
        _lot_card_container.add_child(card)
        card.setup(lots[i], i, total)

        card.enter_pressed.connect(_on_enter_pressed)
        card.pass_pressed.connect(_on_pass_pressed)
        _lot_cards.append(card)


func _refresh_view() -> void:
    var idx: int = RunManager.run.browse_index
    var lock_pass := Director.should_disable_pass_in_lot_browse()
    _skip_button.disabled = lock_pass

    if idx >= RunManager.run.browse_lots.size():
        _show_cargo_state()
        return

    _cargo_panel.visible = false
    _lot_card_container.visible = true

    for i in _lot_cards.size():
        _lot_cards[i].set_active(i == idx)
        _lot_cards[i].set_pass_disabled(lock_pass)


func _show_cargo_state() -> void:
    _lot_card_container.visible = false
    _cargo_panel.visible = true
    _skip_button.visible = false

# ══ Signal handlers ════════════════════════════════════════════════════════════


func _on_enter_pressed() -> void:
    var lot_data: LotData = RunManager.run.browse_lots[RunManager.run.browse_index]
    var entry := LotEntry.create(lot_data)
    RunManager.set_lot(entry)
    RunManager.advance_browse_index()
    RunManager.set_resume_target(RunStore.RESUME_INSPECTION)
    SaveManager.save()
    EventBus.tutorial_event.emit(TutorialEvents.LOT_SELECTED, { })
    SceneRouter.go_to_inspection()


func _on_pass_pressed() -> void:
    if Director.should_disable_pass_in_lot_browse():
        return
    RunManager.advance_browse_index()
    RunManager.set_resume_target(RunStore.RESUME_LOT_BROWSE)
    SaveManager.save()
    _refresh_view()


func _on_skip_pressed() -> void:
    if Director.should_disable_pass_in_lot_browse():
        return
    var remaining: int = RunManager.run.browse_lots.size() - RunManager.run.browse_index
    _skip_confirm_popup.dialog_text = (
        "Skip the remaining %d lot(s) and go straight to cargo?" % remaining
    )
    _skip_confirm_popup.popup_centered()


func _on_skip_confirmed() -> void:
    RunManager.set_resume_target(RunStore.RESUME_CARGO)
    SaveManager.save()
    SceneRouter.go_to_cargo()


func _on_cargo_pressed() -> void:
    RunManager.set_resume_target(RunStore.RESUME_CARGO)
    SaveManager.save()
    EventBus.tutorial_event.emit(TutorialEvents.CARGO_OPENED, { })
    SceneRouter.go_to_cargo()

# ══ Sampling ══════════════════════════════════════════════════════════════════


func _sample_lots(location_data: LocationData) -> Array[LotData]:
    var pool: Array[LotData] = location_data.lot_pool.duplicate()
    RandomUtils.shuffle(pool)
    var count := mini(location_data.lot_number, pool.size())
    return pool.slice(0, count)
