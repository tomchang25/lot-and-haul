# selected_item_panel.gd
# Shows the currently selected or hovered item as persistent decision information.
# Reads:  ItemEntry fields, ItemEntryDisplayHelper, SellMath
# Writes: nothing
class_name SelectedItemPanel
extends PanelContainer

# ── State ─────────────────────────────────────────────────────────────────────

var _entry: ItemEntry = null

# ── Node references ───────────────────────────────────────────────────────────

@onready var _name_label: Label = %NameLabel
@onready var _category_label: Label = %CategoryLabel
@onready var _rarity_label: Label = %RarityLabel
@onready var _condition_value_label: Label = %ConditionValueLabel
@onready var _value_title_label: Label = %ValueTitleLabel
@onready var _value_value_label: Label = %ValueValueLabel
@onready var _verified_label: Label = %VerifiedLabel
@onready var _conv_ratio_label: Label = %ConvRatioLabel
@onready var _breakdown_panel: ItemValueBreakdownPanel = %BreakdownPanel

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
        _name_label.text = TranslationServer.translate("UI_NO_ITEM_SELECTED")
        _name_label.remove_theme_color_override(&"font_color")
        _category_label.text = ""
        _rarity_label.text = ""
        _condition_value_label.text = "-"
        _condition_value_label.modulate = Color.WHITE
        _value_value_label.text = "-"
        _value_value_label.remove_theme_color_override(&"font_color")
        _value_title_label.text = TranslationServer.translate("UI_EST_VALUE_LABEL")
        _verified_label.text = ""
        _conv_ratio_label.text = ""
        _breakdown_panel.setup(null)
        return

    _name_label.text = ItemEntryDisplayHelper.display_name(_entry)
    _name_label.add_theme_color_override(&"font_color", ItemEntryDisplayHelper.display_name_color(_entry))

    if _entry.category_data != null:
        _category_label.text = "%s  \u00b7  #%d" % [TranslationServer.translate(_entry.category_data.display_name_key), _entry.id]
    else:
        _category_label.text = "#%d" % _entry.id

    _rarity_label.text = ItemEntryDisplayHelper.rarity_text(_entry)

    _condition_value_label.text = ItemEntryDisplayHelper.condition_text(_entry)
    _condition_value_label.modulate = ItemEntryDisplayHelper.condition_color(_entry)

    _value_value_label.text = ItemEntryDisplayHelper.estimated_value_text(_entry)
    _value_value_label.add_theme_color_override(&"font_color", ItemEntryDisplayHelper.price_color(_entry))

    var verified: bool
    if _entry.has_method("fit_tags"):
        verified = SellMath.is_item_verified(_entry)
    else:
        verified = _entry.verified

    _verified_label.text = TranslationServer.translate(
        "UI_VERIFICATION_LABEL",
    ) % (TranslationServer.translate("UI_VERIFIED_BADGE") if verified else TranslationServer.translate("UI_UNVERIFIED"))

    _verified_label.modulate = Color(0.4, 1.0, 0.5) if verified else Color(1.0, 0.7, 0.3)

    if verified:
        _value_title_label.text = TranslationServer.translate("UI_TRUE_VALUE")
        _conv_ratio_label.text = TranslationServer.translate("UI_VERIFIED_BADGE")
        _conv_ratio_label.modulate = ItemEntryDisplayHelper.PRICE_COLOR
    elif _entry.is_veiled():
        _value_title_label.text = TranslationServer.translate("UI_EST_VALUE_LABEL")
        _conv_ratio_label.text = ItemEntryDisplayHelper.unknown_text()
        _conv_ratio_label.modulate = Color(0.55, 0.58, 0.63)
    elif _entry.is_price_converged():
        _value_title_label.text = TranslationServer.translate("UI_EST_VALUE_LABEL")
        _conv_ratio_label.text = TranslationServer.translate("UI_CONVERGED")
        _conv_ratio_label.modulate = ItemEntryDisplayHelper.PRICE_COLOR
    else:
        var lo: int = _entry.estimated_value_min
        var hi: int = _entry.estimated_value_max
        var ratio: float = float(lo) / float(hi) * 100.0 if hi > 0 else 0.0
        _value_title_label.text = TranslationServer.translate("UI_EST_VALUE_LABEL")
        _conv_ratio_label.text = "%d%%" % int(ratio)
        _conv_ratio_label.modulate = Color(0.95, 0.75, 0.3) if ratio < 60.0 else Color.WHITE

    _breakdown_panel.setup(_entry)
