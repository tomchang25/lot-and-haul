# item_entry_display_helper.gd
# Presentation-only display helper for ItemEntry. All formatted text, color
# decisions, display-name composition, sort-key dispatch, and veiled-masking
# constants live here. Takes an ItemEntry as the first parameter of every
# static method; never mutates state.
class_name ItemEntryDisplayHelper
extends RefCounted

# ── Display constants ─────────────────────────────────────────────────────────

static func unknown_text() -> String:
    return TranslationServer.translate("SYS_UNKNOWN_PLACEHOLDER")


const PRICE_COLOR := Color(0.4, 1.0, 0.5)
const PRICE_UNKNOWN_COLOR := Color(0.6, 0.6, 0.6)

# ── Display name composition ──────────────────────────────────────────────────


static func display_name(entry: ItemEntry) -> String:
    var pool := entry.get_naming_clue_pool()
    var prefixes: Array[String] = []
    var body_text: String = ""
    var suffixes: Array[String] = []

    for pool_entry in pool:
        if pool_entry is AnchorData:
            body_text = TranslationServer.translate((pool_entry as AnchorData).known_text_key)
        elif pool_entry is AffixData:
            var affix := pool_entry as AffixData
            match affix.naming_slot:
                "prefix":
                    prefixes.append(TranslationServer.translate(affix.display_name_key))
                "suffix":
                    suffixes.append(TranslationServer.translate(affix.display_name_key))

    var parts: Array[String] = []
    parts.append_array(prefixes)
    if not body_text.is_empty():
        parts.append(body_text)
    parts.append_array(suffixes)

    if parts.is_empty():
        return TranslationServer.translate("SYS_UNKNOWN_ITEM")

    var has_qualifier := (not prefixes.is_empty() or not suffixes.is_empty())
    if not has_qualifier and not body_text.is_empty():
        ToastManager.show_info(
            "ItemEntryDisplayHelper.display_name: unveiled item has no affix; falling back to Unknown %s"
            % body_text,
        )
        return TranslationServer.translate("SYS_UNKNOWN_FORMAT") % body_text

    return " ".join(parts)


static func short_name(entry: ItemEntry) -> String:
    var words := display_name(entry).split(" ", false)
    var abbrev := ""
    for word in words:
        if not word.is_empty():
            abbrev += word[0].to_upper()
    return abbrev

# ── Formatted text methods ────────────────────────────────────────────────────


static func estimated_value_text(entry: ItemEntry) -> String:
    var v := entry.resolve_price()
    if not v.known:
        return unknown_text()
    if v.exact or v.max_value <= v.min_value:
        return "$%d" % v.min_value
    return "$%d - $%d" % [v.min_value, v.max_value]


static func condition_text(entry: ItemEntry) -> String:
    if entry.is_veiled():
        return unknown_text()
    return TranslationServer.translate("SYS_PERCENT_FORMAT") % int(entry.condition * 100)


static func condition_secondary_text(entry: ItemEntry) -> String:
    if entry.is_veiled():
        return ""
    return "x%.2f" % entry.get_condition_multiplier()


static func condition_detail_text(entry: ItemEntry) -> String:
    var text := condition_text(entry)
    if text == unknown_text():
        return ""
    return TranslationServer.translate("SYS_CONDITION_FORMAT") % [text, condition_secondary_text(entry)]


static func base_value_text(entry: ItemEntry) -> String:
    var v := entry.get_base_value()
    if v == 0:
        return unknown_text()
    return "$%d" % v


static func rarity_text(entry: ItemEntry) -> String:
    if entry.is_veiled():
        return unknown_text()

    return Economy.rarity_display_name(entry.rarity)


static func weight_text(entry: ItemEntry) -> String:
    if entry.is_veiled():
        return unknown_text()
    return TranslationServer.translate("SYS_WEIGHT_FORMAT") % entry.get_weight()


static func grid_text(entry: ItemEntry) -> String:
    if entry.is_veiled():
        return unknown_text()
    return TranslationServer.translate("SYS_GRID_FORMAT") % [entry.get_cells().size(), entry.get_shape_id()]


static func inspection_text(entry: ItemEntry) -> String:
    if entry.is_veiled():
        return unknown_text()
    return TranslationServer.translate("SYS_PERCENT_FORMAT") % int(entry.inspection_level * 100)

# ── Color methods ─────────────────────────────────────────────────────────────


static func condition_color(entry: ItemEntry) -> Color:
    if entry.is_veiled():
        return Color(0.5, 0.5, 0.5)
    if entry.condition >= 0.8:
        return Color.GOLD
    elif entry.condition >= 0.6:
        return Color.GREEN_YELLOW
    elif entry.condition >= 0.3:
        return Color.WHITE
    else:
        return Color.LIGHT_CORAL


static func price_color(entry: ItemEntry) -> Color:
    return PRICE_COLOR if entry.resolve_price().known else PRICE_UNKNOWN_COLOR


static func price_display_color(entry: ItemEntry) -> Color:
    return price_color(entry)


static func condition_display_color(entry: ItemEntry) -> Color:
    return condition_color(entry)


static func display_name_color(entry: ItemEntry) -> Color:
    if entry.is_veiled() or not entry.verified:
        return Color.WHITE
    match entry.rarity:
        Economy.Rarity.COMMON:
            return Color(0.85, 0.85, 0.85)
        Economy.Rarity.UNCOMMON:
            return Color(0.4, 0.8, 0.4)
        Economy.Rarity.RARE:
            return Color(0.3, 0.6, 1.0)
        Economy.Rarity.EPIC:
            return Color(0.7, 0.4, 1.0)
        Economy.Rarity.LEGENDARY:
            return Color(1.0, 0.75, 0.2)
        _:
            push_warning("Unknown rarity: %d" % entry.rarity)
    return Color(0.85, 0.85, 0.85)

# ── Sort value dispatch ───────────────────────────────────────────────────────


static func sort_value(entry: ItemEntry, column: int) -> Variant:
    match column:
        ItemRow.Column.NAME:
            return display_name(entry)
        ItemRow.Column.CONDITION:
            if entry.is_veiled():
                return 0.0
            return entry.get_condition_multiplier()
        ItemRow.Column.ESTIMATED_VALUE:
            return entry.resolve_price().min_value
        ItemRow.Column.BASE_VALUE:
            return entry.get_base_value()
        ItemRow.Column.RARITY:
            var verified_bonus := 10.0 if entry.verified else 0.0
            return verified_bonus + Economy.RARITY_SORT_WEIGHT[entry.rarity]
        ItemRow.Column.WEIGHT:
            return entry.get_weight()
        ItemRow.Column.GRID:
            return entry.get_cells().size()
        ItemRow.Column.INSPECTION:
            return entry.inspection_level
        _:
            push_warning("Unknown Column: %d" % column)
    if column == ItemRow.Column.CONDITION:
        return 0.0
    return 0
