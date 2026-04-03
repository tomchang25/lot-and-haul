# reveal_item_row.gd
# One item row in the Block 05a Reveal list.
# Call setup() once after instantiation.
# Call reveal() to show the item's layer 1 identity and true value.
class_name RevealItemRow
extends HBoxContainer

# ── State ─────────────────────────────────────────────────────────────────────

var _entry: ItemEntry = null

# ── Node references ───────────────────────────────────────────────────────────

@onready var _name_label: Label = $NameLabel
@onready var _level_label: Label = $LevelLabel
@onready var _condition_label: Label = $ConditionLabel
@onready var _value_label: Label = $ValueLabel

# ══ Common API ════════════════════════════════════════════════════════════════


# Bind entry and populate placeholders. Call once after add_child().
func setup(entry: ItemEntry) -> void:
    _entry = entry
    _name_label.text = entry.display_name
    _level_label.text = entry.potential_inspect_label
    _condition_label.text = entry.condition_inspect_label
    _condition_label.modulate = _entry.condition_inspect_color
    _value_label.text = "???"
    _value_label.add_theme_color_override(&"font_color", _entry.price_color)


# Reveal the item's identity, condition, and estimate.
func reveal() -> void:
    if _entry == null:
        return

    if _entry.is_veiled():
        _entry.layer_index = 1

    # Force full condition visibility for the reveal stage.
    _entry.condition_inspect_level = 2
    _entry.potential_inspect_level = 2

    _name_label.text = _entry.display_name

    _level_label.text = _entry.potential_inspect_label

    _condition_label.text = _entry.condition_inspect_label
    _condition_label.modulate = _entry.condition_inspect_color

    _value_label.text = _entry.price_estimate_label
    _value_label.add_theme_color_override(&"font_color", ItemEntry.PRICE_COLOR)
