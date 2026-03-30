# appraisal_item_row.gd
# One item row in the Block 06 Home Appraisal list.
# Call setup() once after instantiation.
# Call reveal() to flip the value from "???" to the true value with colour.
class_name AppraisalItemRow
extends HBoxContainer

# ── State ─────────────────────────────────────────────────────────────────────

var _entry: ItemEntry = null

# ── Node references ───────────────────────────────────────────────────────────

@onready var _name_lbl: Label = $NameLabel
@onready var _value_lbl: Label = $ValueLabel

# ══ Common API ════════════════════════════════════════════════════════════════


# Bind entry and populate the name. Call once after add_child().
func setup(entry: ItemEntry) -> void:
    _entry = entry
    _name_lbl.text = entry.item_data.item_name
    _value_lbl.text = "???"
    _value_lbl.add_theme_color_override(&"font_color", Color(0.6, 0.6, 0.6))


# Flip the value label to the true value with a green tint.
func reveal() -> void:
    if _entry == null:
        return
    _value_lbl.text = "$%d" % _entry.item_data.true_value
    _value_lbl.add_theme_color_override(&"font_color", Color(0.4, 1.0, 0.5))
