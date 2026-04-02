# run_review_item_row.gd
# One cargo item row in the Block 06 Run Review list.
# Call setup() once after instantiation.
class_name RunReviewItemRow
extends HBoxContainer

# ── Node references ───────────────────────────────────────────────────────────

@onready var _name_lbl: Label = $NameLabel
@onready var _value_lbl: Label = $ValueLabel
@onready var _cond_lbl: Label = $ConditionLabel

# ══ API ═══════════════════════════════════════════════════════════════════════


func setup(entry: ItemEntry) -> void:
    _name_lbl.text = entry.display_name

    _cond_lbl.text = entry.condition_label
    if entry.condition >= 0.8:
        _cond_lbl.modulate = Color.GOLD
    elif entry.condition >= 0.6:
        _cond_lbl.modulate = Color.GREEN_YELLOW
    else:
        _cond_lbl.modulate = Color.LIGHT_CORAL

    var value: int = entry.price_estimate
    _value_lbl.text = "$%d" % value
    _value_lbl.add_theme_color_override(&"font_color", Color(0.4, 1.0, 0.5))
