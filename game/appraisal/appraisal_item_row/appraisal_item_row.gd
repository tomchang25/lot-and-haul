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

    if _entry.is_veiled():
        _name_lbl.text = entry.display_name
        _value_lbl.text = "???"
    else:
        _name_lbl.text = entry.display_name
        _value_lbl.text = "$%d" % entry.price_estimate

    _value_lbl.add_theme_color_override(&"font_color", Color(0.6, 0.6, 0.6))


# Reveal the item's final-layer identity and true value.
func reveal() -> void:
    if _entry == null:
        return

    if _entry.is_veiled():
        _entry.layer_index = 1

    _name_lbl.text = _entry.display_name
    _value_lbl.text = "$%d" % _entry.price_estimate
    _value_lbl.add_theme_color_override(&"font_color", Color(0.4, 1.0, 0.5))
