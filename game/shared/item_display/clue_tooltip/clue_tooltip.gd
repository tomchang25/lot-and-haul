# clue_tooltip.gd
# Floating tooltip that displays clue details on hover over a ClueTag.
# Place one instance in the scene root; call show_for() / hide_tooltip().
# Reads:  ClueData fields (known_text_key, type, attribute, dc, effect_op, effect_amount)
# Writes: nothing
class_name ClueTooltip
extends PanelContainer

# ── Node references ───────────────────────────────────────────────────────────

@onready var _name_label: Label = %NameLabel
@onready var _type_label: Label = %TypeLabel
@onready var _attr_label: Label = %AttrLabel
@onready var _effect_label: RichTextLabel = %EffectLabel
@onready var _valued_label: Label = %ValuedLabel
@onready var _effect_sep: HSeparator = %EffectSep

# ══ Common API ════════════════════════════════════════════════════════════════


func show_for(data: ClueData, anchor: Rect2, revealed: bool = true, valued: bool = false) -> void:
    if data == null:
        return

    _name_label.text = TranslationServer.translate(data.known_text_key)

    var color := ClueColors.for_clue(data, revealed, valued)
    _name_label.add_theme_color_override(&"font_color", color)

    var type_key := "UI_CLUE_SURFACE" if data.type == ClueData.ClueType.SURFACE else "UI_CLUE_HIDDEN"
    _type_label.text = TranslationServer.translate(type_key)
    _type_label.add_theme_color_override(&"font_color", color)

    if revealed and data.attribute != "" and data.dc > 0:
        _attr_label.text = TranslationServer.translate("UI_CLUE_ATTR_DC_FORMAT") % [
            TranslationServer.translate(_attribute_key(data.attribute)),
            data.dc,
        ]
        _attr_label.show()
    else:
        _attr_label.hide()

    if revealed:
        _populate_effect(data, valued)
        _effect_label.show()
        _effect_sep.show()
    else:
        _effect_label.hide()
        _effect_sep.hide()

    if valued:
        _valued_label.text = TranslationServer.translate("UI_CLUE_VALUED_FORMAT") % Economy.VALUED_NEGATIVE_SURFACE_BONUS
        _valued_label.show()
    else:
        _valued_label.hide()

    _position_near(anchor)
    show()


func hide_tooltip() -> void:
    hide()

# ══ Internal ══════════════════════════════════════════════════════════════════


func _populate_effect(data: ClueData, valued: bool) -> void:
    var effect_color := ClueColors.for_effect(data)
    var color_bb := "#%s" % effect_color.to_html(false)

    var text := ""
    match data.effect_op:
        "add":
            var prefix := "+" if data.effect_amount >= 0.0 else ""
            text = prefix + "$%d" % int(data.effect_amount)
        "mul":
            text = "x%.2f" % data.effect_amount
        "override":
            text = TranslationServer.translate("UI_CLUE_OVERRIDE_FORMAT") % int(data.effect_amount)

    var bbcode := "[color=%s]%s[/color]" % [color_bb, text]
    if valued and text != "":
        bbcode = "[s]" + bbcode + "[/s]"

    _effect_label.text = bbcode


func _attribute_key(attr: String) -> String:
    match attr:
        "appraisal":
            return "SYS_ATTR_APPRAISAL"
        "perception":
            return "SYS_ATTR_PERCEPTION"
        "restoration":
            return "SYS_ATTR_RESTORATION"
        "negotiation":
            return "SYS_ATTR_NEGOTIATION"
        "investigation":
            return "SYS_ATTR_INVESTIGATION"
    ToastManager.show_dev_error("ClueTooltip._attribute_key: unknown attribute %s" % attr)
    return attr


func _position_near(anchor: Rect2) -> void:
    var vp_size := get_viewport_rect().size
    var target_x := anchor.position.x + anchor.size.x + 6.0
    var target_y := anchor.position.y

    if target_x + size.x > vp_size.x:
        target_x = anchor.position.x - size.x - 6.0

    if target_y + size.y > vp_size.y:
        target_y = vp_size.y - size.y - 4.0

    global_position = Vector2(maxf(4.0, target_x), maxf(4.0, target_y))
