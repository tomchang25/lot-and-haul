# selected_item_panel.gd
# Shows the currently selected item as persistent decision information.
# Reads:  ItemEntry fields, ItemEntryDisplayHelper
# Writes: nothing
class_name SelectedItemPanel
extends PanelContainer

# ── State ─────────────────────────────────────────────────────────────────────

var _entry: ItemEntry = null

# ── Node references ───────────────────────────────────────────────────────────

@onready var _name_label: Label = %NameLabel
@onready var _value_label: Label = %ValueLabel
@onready var _condition_label: Label = %ConditionLabel
@onready var _rarity_label: Label = %RarityLabel
@onready var _verified_label: Label = %VerifiedLabel

# ══ Lifecycle ═════════════════════════════════════════════════════════════════


func _ready() -> void:
    if _entry != null:
        _apply()

# ══ Common API ════════════════════════════════════════════════════════════════


func setup(entry: ItemEntry) -> void:
    _entry = entry
    if is_node_ready():
        _apply()


func set_item(entry: ItemEntry) -> void:
    setup(entry)


func clear_display() -> void:
    _entry = null
    if is_node_ready():
        _apply()

# ══ Internal ══════════════════════════════════════════════════════════════════


func _apply() -> void:
    if _entry == null:
        _name_label.text = "No item selected"
        _name_label.remove_theme_color_override(&"font_color")
        _value_label.text = "Value: -"
        _value_label.remove_theme_color_override(&"font_color")
        _condition_label.text = "Condition: -"
        _condition_label.modulate = Color.WHITE
        _rarity_label.text = "Rarity: -"
        _verified_label.text = "Verification: -"
        _verified_label.modulate = Color.WHITE
        return

    _name_label.text = ItemEntryDisplayHelper.display_name(_entry)
    _name_label.add_theme_color_override(&"font_color", ItemEntryDisplayHelper.display_name_color(_entry))

    _value_label.text = "Value: %s" % ItemEntryDisplayHelper.estimated_value_text(_entry)
    _value_label.add_theme_color_override(&"font_color", ItemEntryDisplayHelper.price_display_color(_entry))

    _condition_label.text = "Condition: %s (x%.2f)" % [
        ItemEntryDisplayHelper.condition_text(_entry),
        _entry.get_condition_multiplier(),
    ]
    _condition_label.modulate = ItemEntryDisplayHelper.condition_display_color(_entry)

    _rarity_label.text = "Rarity: %s" % ItemEntryDisplayHelper.rarity_text(_entry)

    var verified := SellMath.is_item_verified(_entry) if _entry.has_method("fit_tags") else _entry.verified
    _verified_label.text = "Verification: %s" % ("Verified" if verified else "Unverified")
    _verified_label.modulate = Color(0.3, 1.0, 0.3) if verified else Color(1.0, 0.7, 0.3)
