# item_detail_panel.gd
# Shared item detail panel used by Inspection, Storage, and CustomerSell
# sidebars. Renders display name, auth badge, category, rarity, condition,
# estimated value, convergence ratio, verification status, and clue breakdown.
# Reads:  ItemEntry fields, ItemEntryDisplayHelper
# Writes: nothing
class_name ItemDetailPanel
extends VBoxContainer

# ── Node references ───────────────────────────────────────────────────────────

@onready var _name_label: Label = %NameLabel
@onready var _auth_tag_label: Label = %AuthTagLabel
@onready var _category_label: Label = %CategoryLabel
@onready var _rarity_label: Label = %RarityLabel
@onready var _condition_section: PanelContainer = %ConditionPanel
@onready var _condition_value: Label = %CondValueLabel
@onready var _value_section: PanelContainer = %ValuePanel
@onready var _value_title_label: Label = %ValueTitleLabel
@onready var _value_label: Label = %ValueValueLabel
@onready var _convergence_section: VBoxContainer = %ConvergenceSection
@onready var _conv_label: Label = %ConvRatioLabel
@onready var _verified_label: Label = %VerifiedLabel
@onready var _breakdown_panel: ItemValueBreakdownPanel = %BreakdownPanel

# ══ Common API ════════════════════════════════════════════════════════════════


func setup(entry: ItemEntry, show_convergence: bool = true, show_verification: bool = false) -> void:
    if entry == null:
        clear()
        return

    # ── Name + Auth tag ────────────────────────────
    _name_label.text = ItemEntryDisplayHelper.display_name(entry)
    _name_label.add_theme_color_override(&"font_color", ItemEntryDisplayHelper.display_name_color(entry))
    _auth_tag_label.visible = entry.verified

    # ── Category ────────────────────────────────────
    var cat := ""
    if not entry.is_veiled() and entry.category_data != null:
        cat = "%s \u00b7 #%d" % [TranslationServer.translate(entry.category_data.display_name_key), entry.id]
    _category_label.text = cat
    _category_label.visible = cat != ""

    # ── Rarity ──────────────────────────────────────
    var rarity := ItemEntryDisplayHelper.rarity_text(entry)
    _rarity_label.text = rarity
    _rarity_label.visible = rarity != ItemEntryDisplayHelper.unknown_text()

    # ── Condition panel ─────────────────────────────
    var cond := ItemEntryDisplayHelper.condition_text(entry)
    var known := cond != ItemEntryDisplayHelper.unknown_text()
    _condition_section.visible = known
    _condition_value.text = cond
    _condition_value.modulate = ItemEntryDisplayHelper.condition_color(entry) if known else Color(0.55, 0.58, 0.63)

    # ── Value panel ─────────────────────────────────
    var price := ItemEntryDisplayHelper.estimated_value_text(entry)
    var price_known := price != ItemEntryDisplayHelper.unknown_text()
    _value_section.visible = price_known
    _value_label.text = price
    _value_label.add_theme_color_override(&"font_color", ItemEntryDisplayHelper.price_color(entry))

    # ── Value title label (default) ─────────────────
    _value_title_label.text = TranslationServer.translate("UI_EST_VALUE_LABEL")

    # ── Convergence ─────────────────────────────────
    _convergence_section.visible = show_convergence
    if show_convergence:
        if entry.verified:
            _conv_label.text = TranslationServer.translate("UI_VERIFIED_BADGE")
            _conv_label.modulate = ItemEntryDisplayHelper.PRICE_COLOR
            _value_title_label.text = TranslationServer.translate("UI_TRUE_VALUE")
        elif entry.is_veiled():
            _conv_label.text = "..."
            _conv_label.modulate = Color(0.5, 0.5, 0.5)
        elif entry.is_price_converged():
            _conv_label.text = TranslationServer.translate("UI_CONVERGED")
            _conv_label.modulate = ItemEntryDisplayHelper.PRICE_COLOR
        else:
            var lo := entry.estimated_value_min
            var hi := entry.estimated_value_max
            var ratio := float(lo) / float(hi) * 100.0 if hi > 0 else 0.0
            _conv_label.text = "%d%%" % int(ratio)
            _conv_label.modulate = Color(0.95, 0.75, 0.3) if ratio < 60.0 else Color.WHITE

    # ── Verification status ─────────────────────────
    _verified_label.visible = show_verification
    if show_verification:
        var verified := entry.verified
        _verified_label.text = TranslationServer.translate(
            "UI_VERIFICATION_LABEL",
        ) % (TranslationServer.translate("UI_VERIFIED_BADGE") if verified else TranslationServer.translate("UI_UNVERIFIED"))
        _verified_label.modulate = Color(0.4, 1.0, 0.5) if verified else Color(1.0, 0.7, 0.3)

    # ── Value breakdown ─────────────────────────────
    _breakdown_panel.setup(entry)


func clear() -> void:
    _name_label.text = TranslationServer.translate("UI_NO_ITEM_SELECTED")
    _name_label.remove_theme_color_override(&"font_color")
    _auth_tag_label.visible = false
    _category_label.text = ""
    _category_label.visible = false
    _rarity_label.text = ""
    _rarity_label.visible = false
    _condition_section.visible = false
    _condition_value.text = ""
    _value_section.visible = false
    _value_label.text = ""
    _value_label.remove_theme_color_override(&"font_color")
    _value_title_label.text = TranslationServer.translate("UI_EST_VALUE_LABEL")
    _convergence_section.visible = false
    _verified_label.text = ""
    _verified_label.visible = false
    _breakdown_panel.setup(null)
