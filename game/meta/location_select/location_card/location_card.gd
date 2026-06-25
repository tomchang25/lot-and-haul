# location_card.gd
# Presents a single LocationData on the Location Select screen.
# Displays name, description, entry fee, travel days, and lot count.
# Re-emits its Select button's press as a `pressed` signal so the parent
# selection screen can route to the entry flow.
class_name LocationCard
extends PanelContainer

signal pressed(card: LocationCard)

var _location_data: LocationData = null

@onready var _name_label: Label = $VBox/NameLabel
@onready var _description_label: Label = $VBox/DescriptionLabel
@onready var _entry_fee_label: Label = $VBox/StatsGrid/EntryFeeLabel
@onready var _travel_days_label: Label = $VBox/StatsGrid/TravelDaysLabel
@onready var _lot_number_label: Label = $VBox/StatsGrid/LotNumberLabel
@onready var _fuel_cost_label: Label = $VBox/StatsGrid/FuelCostLabel
@onready var _total_cost_label: Label = $VBox/StatsGrid/TotalCostLabel
@onready var _select_button: Button = $VBox/SelectButton

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _select_button.pressed.connect(_on_select_button_pressed)
    if _location_data != null:
        _apply()

# ══ Public API ════════════════════════════════════════════════════════════════


func setup(data: LocationData) -> void:
    _location_data = data
    if is_node_ready():
        _apply()


func get_location_data() -> LocationData:
    return _location_data

# ══ Internal ══════════════════════════════════════════════════════════════════


func _apply() -> void:
    _name_label.text = TranslationServer.translate(_location_data.display_name_key)
    _description_label.text = TranslationServer.translate(_location_data.description_key)
    _entry_fee_label.text = TranslationServer.translate("UI_ENTRY_FEE_LABEL") % _location_data.entry_fee
    _travel_days_label.text = TranslationServer.translate("UI_TRAVEL_LABEL") % _location_data.travel_days
    _lot_number_label.text = TranslationServer.translate("UI_LOTS_LABEL") % _location_data.lot_number
    var car: CarData = MetaSystem.garage.active_car
    var fuel_cost := car.fuel_cost_per_day * _location_data.travel_days if car else 0
    _fuel_cost_label.text = TranslationServer.translate("UI_FUEL_LABEL") % fuel_cost
    var total_cost := _location_data.entry_fee + fuel_cost
    _total_cost_label.text = TranslationServer.translate("UI_EST_COST_LABEL") % total_cost


func _on_select_button_pressed() -> void:
    pressed.emit(self)
