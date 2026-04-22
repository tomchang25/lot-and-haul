# car_select_scene.gd
# Car Select (Garage) — Lists every owned car and lets the player pick which
# one to drive on the next run.
# Reads:  SaveManager.owned_cars, SaveManager.active_car
# Writes: SaveManager.active_car
extends Control

# ── Constants ──────────────────────────────────────────────────────────────────

const CarRowScene := preload("res://game/meta/vehicle/car_select/car_row/car_row.tscn")

# ── State ──────────────────────────────────────────────────────────────────────

var _rows: Array[CarRow] = []

# ── Node references ───────────────────────────────────────────────────────────

@onready var _rows_container: VBoxContainer = $RootVBox/ScrollContainer/Rows
@onready var _back_btn: Button = $RootVBox/Footer/BackButton

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _back_btn.pressed.connect(_on_back_pressed)
    _populate_rows()

# ══ Signal handlers ═══════════════════════════════════════════════════════════


func _on_back_pressed() -> void:
    GameManager.go_to_vehicle_hub()


func _on_select_pressed(car: CarData) -> void:
    if car == SaveManager.active_car:
        return
    SaveManager.active_car = car
    SaveManager.save()
    _refresh_active_state()

# ══ Rows ══════════════════════════════════════════════════════════════════════


func _populate_rows() -> void:
    for child in _rows_container.get_children():
        child.queue_free()
    _rows.clear()

    for car: CarData in SaveManager.owned_cars:
        var row: CarRow = CarRowScene.instantiate()
        row.setup(car, car == SaveManager.active_car)
        row.select_pressed.connect(_on_select_pressed)
        _rows_container.add_child(row)
        _rows.append(row)


func _refresh_active_state() -> void:
    for row: CarRow in _rows:
        row.setup(row.get_car(), row.get_car() == SaveManager.active_car)
