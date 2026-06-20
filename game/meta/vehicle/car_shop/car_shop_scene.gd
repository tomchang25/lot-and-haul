# car_shop_scene.gd
# Car Shop — Lists every car the player does not yet own and lets them buy
# one with cash. Shop inventory is simply `CarRegistry.get_all_cars()` filtered
# against `MetaManager.garage.owned_cars`.
# Reads:  MetaManager.economy.cash, MetaManager.garage.owned_cars, CarRegistry
# Writes: MetaManager.economy.cash, MetaManager.garage.owned_cars
extends Control

# ── Constants ──────────────────────────────────────────────────────────────────

const CANCEL: UiAudioEvent = preload("res://data/tres/audio_events/cancel_dismiss.tres")
const CarCardScene := preload("res://game/meta/vehicle/car_shop/car_card/car_card.tscn")

# ── Node references ───────────────────────────────────────────────────────────

@onready var _balance_label: Label = $RootVBox/BalanceLabel
@onready var _rows_container: VBoxContainer = $RootVBox/ScrollContainer/Rows
@onready var _back_btn: Button = $RootVBox/Footer/BackButton

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _back_btn.pressed.connect(_on_back_pressed)
    _back_btn.press_event = CANCEL
    _refresh()

# ══ Signal handlers ═══════════════════════════════════════════════════════════


func _on_back_pressed() -> void:
    SceneRouter.go_to_vehicle_hub()


func _on_buy_pressed(car: CarData) -> void:
    if MetaManager.buy_car(car):
        _refresh()

# ══ Rows ══════════════════════════════════════════════════════════════════════


func _refresh() -> void:
    _balance_label.text = TranslationServer.translate("UI_BALANCE_LABEL") % MetaManager.economy.cash
    _populate_rows()


func _populate_rows() -> void:
    for child in _rows_container.get_children():
        child.queue_free()

    var inventory: Array[CarData] = []
    for car: CarData in CarRegistry.get_all_cars():
        if not MetaManager.garage.owned_cars.has(car):
            inventory.append(car)

    if inventory.is_empty():
        var empty_label := Label.new()
        empty_label.add_theme_font_size_override("font_size", 16)
        empty_label.text = TranslationServer.translate("UI_NO_CARS_AVAILABLE")
        empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

        # node-src: ephemeral — empty-state label
        _rows_container.add_child(empty_label)

        return

    for car: CarData in inventory:
        var card: CarCard = CarCardScene.instantiate()
        card.setup(car, MetaManager.economy.cash >= car.price)
        card.buy_pressed.connect(_on_buy_pressed)
        _rows_container.add_child(card)
