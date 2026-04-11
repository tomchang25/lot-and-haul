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
    _name_label.text = _location_data.display_name
    _description_label.text = _location_data.description
    _entry_fee_label.text = "Entry Fee:   $%d" % _location_data.entry_fee
    _travel_days_label.text = "Travel:   %d day%s" % [
        _location_data.travel_days,
        "" if _location_data.travel_days == 1 else "s",
    ]
    _lot_number_label.text = "Lots:   %d" % _location_data.lot_number


func _on_select_button_pressed() -> void:
    pressed.emit(self)
