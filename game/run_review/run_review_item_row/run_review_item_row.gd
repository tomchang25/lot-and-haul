# run_review_item_row.gd
# One cargo item row in the Block 06 Run Review list.
# Call setup() once after instantiation.
class_name RunReviewItemRow
extends HBoxContainer

# ── Node references ───────────────────────────────────────────────────────────

@onready var _name_lbl: Label = $NameLabel
@onready var _value_lbl: Label = $ValueLabel

# ══ API ═══════════════════════════════════════════════════════════════════════


func setup(entry: ItemEntry) -> void:
	_name_lbl.text = entry.display_name
	var value: int = entry.active_layer().base_value
	_value_lbl.text = "$%d" % value
	_value_lbl.add_theme_color_override(&"font_color", Color(0.4, 1.0, 0.5))
