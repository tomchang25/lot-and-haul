# car_shop_scene.gd
# Car Shop — Lists every car the player does not yet own and lets them buy
# one with cash. Shop inventory is simply `CarRegistry.get_all_cars()` filtered
# against `SaveManager.owned_cars`.
# Reads:  SaveManager.cash, SaveManager.owned_cars, CarRegistry
# Writes: SaveManager.cash, SaveManager.owned_cars (via SaveManager.buy_car)
extends Control

# ── Constants ──────────────────────────────────────────────────────────────────

const CarCardScene := preload("res://game/meta/vehicle/car_shop/car_card/car_card.tscn")

# ── Node references ───────────────────────────────────────────────────────────

@onready var _balance_label: Label = $RootVBox/BalanceLabel
@onready var _rows_container: VBoxContainer = $RootVBox/ScrollContainer/Rows
@onready var _back_btn: Button = $RootVBox/Footer/BackButton

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _back_btn.pressed.connect(_on_back_pressed)
    _refresh()

# ══ Signal handlers ═══════════════════════════════════════════════════════════


func _on_back_pressed() -> void:
    GameManager.go_to_vehicle_hub()


func _on_buy_pressed(car: CarData) -> void:
    if SaveManager.buy_car(car):
        _refresh()

# ══ Rows ══════════════════════════════════════════════════════════════════════


func _refresh() -> void:
    _balance_label.text = "Balance:   $%d" % SaveManager.cash
    _populate_rows()


func _populate_rows() -> void:
    for child in _rows_container.get_children():
        child.queue_free()

    var inventory: Array[CarData] = []
    for car: CarData in CarRegistry.get_all_cars():
        if not SaveManager.owned_cars.has(car):
            inventory.append(car)

    if inventory.is_empty():
        var empty_label := Label.new()
        empty_label.add_theme_font_size_override("font_size", 16)
        empty_label.text = "No cars available — you own them all."
        empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        _rows_container.add_child(empty_label)
        return

    for car: CarData in inventory:
        var card: CarCard = CarCardScene.instantiate()
        card.setup(car, SaveManager.cash >= car.price)
        card.buy_pressed.connect(_on_buy_pressed)
        _rows_container.add_child(card)
