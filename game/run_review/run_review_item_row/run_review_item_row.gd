# run_review_item_row.gd
# One cargo item row in the Block 06 Run Review list.
# Call setup() once after instantiation.
class_name RunReviewItemRow
extends HBoxContainer

# ── Node references ───────────────────────────────────────────────────────────

@onready var _name_label: Label = $NameLabel
@onready var _level_label: Label = $LevelLabel
@onready var _condition_label: Label = $ConditionLabel
@onready var _value_label: Label = $ValueLabel

# ══ API ═══════════════════════════════════════════════════════════════════════


func setup(entry: ItemEntry) -> void:
    _name_label.text = entry.display_name

    _level_label.text = entry.potential_inspect_label

    # Run review always shows full condition detail regardless of inspect level.
    _condition_label.text = entry.condition_label
    if entry.condition >= 0.8:
        _condition_label.modulate = Color.GOLD
    elif entry.condition >= 0.6:
        _condition_label.modulate = Color.GREEN_YELLOW
    elif entry.condition >= 0.3:
        _condition_label.modulate = Color.WHITE
    else:
        _condition_label.modulate = Color.LIGHT_CORAL

    _value_label.text = "%d" % [entry.active_layer().base_value * entry.get_condition_multiplier()]
    _value_label.add_theme_color_override(&"font_color", Color(0.4, 1.0, 0.5))
