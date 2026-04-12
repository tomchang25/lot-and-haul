# car_card.gd
# Presents a single CarData in the Car Shop as a purchasable card.
# Displays icon, name, stats, price, and a Buy button.
class_name CarCard
extends PanelContainer

signal buy_pressed(car: CarData)

# ── State ──────────────────────────────────────────────────────────────────────

var _car: CarData = null
var _affordable: bool = false

# ── Node references ───────────────────────────────────────────────────────────

@onready var _icon_rect: TextureRect = $HBoxContainer/IconRect
@onready var _name_label: Label = $HBoxContainer/Stats/NameLabel
@onready var _stats_label: Label = $HBoxContainer/Stats/StatsLabel
@onready var _price_label: Label = $HBoxContainer/Stats/PriceLabel
@onready var _buy_button: Button = $HBoxContainer/BuyButton

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _buy_button.pressed.connect(func() -> void: buy_pressed.emit(_car))
    if _car != null:
        _apply()

# ══ Common API ════════════════════════════════════════════════════════════════


func setup(car: CarData, affordable: bool) -> void:
    _car = car
    _affordable = affordable
    if is_node_ready():
        _apply()


func refresh() -> void:
    if is_node_ready():
        _apply()

# ══ View ══════════════════════════════════════════════════════════════════════


func _apply() -> void:
    _icon_rect.texture = _car.icon
    _name_label.text = _car.display_name
    _stats_label.text = _car.stats_line()
    _price_label.text = "Price:   $%d" % _car.price
    _buy_button.disabled = not _affordable
