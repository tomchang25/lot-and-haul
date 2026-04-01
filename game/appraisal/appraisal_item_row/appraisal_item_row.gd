# appraisal_item_row.gd
# One item row in the Block 06 Home Appraisal list.
# Call setup() once after instantiation.
# Call reveal() to show the item's final-layer identity and value.
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
    _name_lbl.text = InspectionRules.get_display_name(entry)
    _value_lbl.text = "???"
    _value_lbl.add_theme_color_override(&"font_color", Color(0.6, 0.6, 0.6))


# Reveal the item's final-layer identity and true value.
func reveal() -> void:
    if _entry == null:
        return
    var final_layer := _entry.item_data.identity_layers.back()
    _name_lbl.text = final_layer.display_label
    _value_lbl.text = "$%d" % final_layer.base_value
    _value_lbl.add_theme_color_override(&"font_color", Color(0.4, 1.0, 0.5))
