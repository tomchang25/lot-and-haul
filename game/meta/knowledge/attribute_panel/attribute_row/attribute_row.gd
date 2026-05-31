# attribute_row.gd
# One attribute line in the Attribute Panel: name + level and an upgrade button.
# Emits upgrade_pressed(attr) when the (enabled) button is clicked; the panel
# owns the actual upgrade logic.
class_name AttributeRow
extends HBoxContainer

signal upgrade_pressed(attr: AttributeData)

# ── State ─────────────────────────────────────────────────────────────────────

var _configured: bool = false
var _attr: AttributeData = null
var _level: int = 0
var _cost: int = 0
var _can_afford: bool = false

# ── Node references ───────────────────────────────────────────────────────────

@onready var _name_label: Label = $NameLabel
@onready var _upgrade_button: Button = $UpgradeButton

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    _upgrade_button.pressed.connect(func() -> void: upgrade_pressed.emit(_attr))
    if _configured:
        _apply()

# ══ Common API ════════════════════════════════════════════════════════════════


func setup(attr: AttributeData, level: int, cost: int, can_afford: bool) -> void:
    _attr = attr
    _level = level
    _cost = cost
    _can_afford = can_afford
    _configured = true
    if is_node_ready():
        _apply()

# ══ View ══════════════════════════════════════════════════════════════════════


func _apply() -> void:
    _name_label.text = "%s  %d" % [_attr.display_name, _level]

    if _can_afford:
        _upgrade_button.text = "Upgrade  $%d" % _cost
        _upgrade_button.disabled = false
        _upgrade_button.tooltip_text = ""
    else:
        _upgrade_button.text = "$%d" % _cost
        _upgrade_button.disabled = true
        _upgrade_button.tooltip_text = "Not enough cash"
