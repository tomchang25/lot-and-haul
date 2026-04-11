# vehicle_hub.gd
# Vehicle Hub — Navigation menu for Garage (car select) and Car Shop.
extends Control

# ── Node references ───────────────────────────────────────────────────────────

@onready var _garage_btn: Button = $RootVBox/ButtonsVBox/GarageButton
@onready var _car_shop_btn: Button = $RootVBox/ButtonsVBox/CarShopButton
@onready var _back_btn: Button = $RootVBox/Footer/BackButton

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _garage_btn.pressed.connect(_on_garage_pressed)
    _car_shop_btn.pressed.connect(_on_car_shop_pressed)
    _back_btn.pressed.connect(_on_back_pressed)

# ══ Signal handlers ═══════════════════════════════════════════════════════════


func _on_garage_pressed() -> void:
    GameManager.go_to_car_select()


func _on_car_shop_pressed() -> void:
    GameManager.go_to_car_shop()


func _on_back_pressed() -> void:
    GameManager.go_to_hub()
