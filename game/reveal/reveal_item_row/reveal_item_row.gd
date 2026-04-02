# reveal_item_row.gd
# One item row in the Block 05a Reveal list.
# Call setup() once after instantiation.
# Call reveal() to show the item's layer 1 identity and value.
class_name RevealItemRow
extends HBoxContainer

# ── State ─────────────────────────────────────────────────────────────────────

var _entry: ItemEntry = null

# ── Node references ───────────────────────────────────────────────────────────

@onready var _name_lbl: Label = $NameLabel
@onready var _value_lbl: Label = $ValueLabel
@onready var _cond_lbl: Label = $ConditionLabel

# ══ Common API ════════════════════════════════════════════════════════════════


# Bind entry and populate the name. Call once after add_child().
func setup(entry: ItemEntry) -> void:
    _entry = entry
    _name_lbl.text = entry.display_name

    _cond_lbl.text = "---"
    _cond_lbl.modulate = Color(0.5, 0.5, 0.5)

    _value_lbl.text = "???" if entry.is_veiled() else "$%d" % entry.active_layer().base_value
    _value_lbl.add_theme_color_override(&"font_color", Color(0.6, 0.6, 0.6))


# Reveal the item's final-layer identity and true value.
func reveal() -> void:
    if _entry == null:
        return

    if _entry.is_veiled():
        _entry.layer_index = 1

    _name_lbl.text = _entry.display_name

    _cond_lbl.text = _entry.condition_label

    if _entry.condition >= 0.8:
        _cond_lbl.modulate = Color.GOLD
    elif _entry.condition >= 0.6:
        _cond_lbl.modulate = Color.GREEN_YELLOW
    else:
        _cond_lbl.modulate = Color.LIGHT_CORAL

    _value_lbl.text = "$%d" % _entry.price_estimate
    _value_lbl.add_theme_color_override(&"font_color", Color(0.4, 1.0, 0.5))
