# appraisal_item_row.gd
# One item row in the Block 06 Home Appraisal list.
# Call setup() once after instantiation.
# Call reveal() to flip the value from "???" to the true value with colour.
class_name AppraisalItemRow
extends HBoxContainer

# ── State ─────────────────────────────────────────────────────────────────────

var _item: ItemData = null

# ── Node references ───────────────────────────────────────────────────────────

@onready var _name_lbl: Label = $NameLabel
@onready var _value_lbl: Label = $ValueLabel

# ══ Common API ════════════════════════════════════════════════════════════════


# Bind item data and populate the name. Call once after add_child().
func setup(item: ItemData) -> void:
    _item = item
    _name_lbl.text = item.item_name
    _value_lbl.text = "???"
    _value_lbl.add_theme_color_override(&"font_color", Color(0.6, 0.6, 0.6))


# Flip the value label to the true value with a green tint.
func reveal() -> void:
    if _item == null:
        return
    _value_lbl.text = "$%d" % _item.true_value
    _value_lbl.add_theme_color_override(&"font_color", Color(0.4, 1.0, 0.5))
