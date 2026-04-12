# car_row.gd
# Displays a single owned car in the Garage (Car Select) screen.
# Shows icon, name, stats, and either an ACTIVE label or a Select button.
class_name CarRow
extends PanelContainer

signal select_pressed(car: CarData)

# ── State ──────────────────────────────────────────────────────────────────────

var _car: CarData = null
var _is_active: bool = false

# ── Node references ───────────────────────────────────────────────────────────

@onready var _icon_rect: TextureRect = $HBoxContainer/IconRect
@onready var _name_label: Label = $HBoxContainer/Stats/NameLabel
@onready var _stats_label: Label = $HBoxContainer/Stats/StatsLabel
@onready var _active_label: Label = $HBoxContainer/ActiveLabel
@onready var _select_button: Button = $HBoxContainer/SelectButton

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _select_button.pressed.connect(func() -> void: select_pressed.emit(_car))
    if _car != null:
        _apply()

# ══ Common API ════════════════════════════════════════════════════════════════


func setup(car: CarData, is_active: bool) -> void:
    _car = car
    _is_active = is_active
    if is_node_ready():
        _apply()


func refresh() -> void:
    if is_node_ready():
        _apply()


func get_car() -> CarData:
    return _car

# ══ View ══════════════════════════════════════════════════════════════════════


func _apply() -> void:
    _icon_rect.texture = _car.icon
    _name_label.text = _car.display_name
    _stats_label.text = _car.stats_line()
    _active_label.visible = _is_active
    _select_button.visible = not _is_active
