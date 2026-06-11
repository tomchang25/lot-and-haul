# item_entry_display_helper.gd
# Presentation-only display helper for ItemEntry. All formatted text, color
# decisions, display-name composition, sort-key dispatch, and veiled-masking
# constants live here. Takes an ItemEntry as the first parameter of every
# static method; never mutates state.
class_name ItemEntryDisplayHelper
extends RefCounted

# ── Display constants ─────────────────────────────────────────────────────────

const UNKNOWN_TEXT := "???"

const RARITY_NAMES: Array[String] = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]

const PRICE_COLOR := Color(0.4, 1.0, 0.5)
const PRICE_UNKNOWN_COLOR := Color(0.6, 0.6, 0.6)

# ── Display name composition ──────────────────────────────────────────────────


static func display_name(entry: ItemEntry) -> String:
    var pool := entry.get_naming_clue_pool()
    var best_prefix_text: String = ""
    var best_prefix_prio: int = -1
    var best_body_text: String = ""
    var best_body_prio: int = -1
    var best_suffix_text: String = ""
    var best_suffix_prio: int = -1

    for pool_entry in pool:
        var slot: String
        var priority: int
        var text: String
        if pool_entry is AnchorData:
            slot = "body"
            priority = (pool_entry as AnchorData).naming_priority
            text = (pool_entry as AnchorData).known_text
        elif pool_entry is ClueData:
            slot = (pool_entry as ClueData).naming_slot
            priority = (pool_entry as ClueData).naming_priority
            text = (pool_entry as ClueData).known_text
        else:
            continue
        if slot.is_empty():
            continue
        match slot:
            "prefix":
                if priority > best_prefix_prio:
                    best_prefix_prio = priority
                    best_prefix_text = text
            "body":
                if priority > best_body_prio:
                    best_body_prio = priority
                    best_body_text = text
            "suffix":
                if priority > best_suffix_prio:
                    best_suffix_prio = priority
                    best_suffix_text = text

    var parts: Array[String] = []
    if not best_prefix_text.is_empty():
        parts.append(best_prefix_text)
    if not best_body_text.is_empty():
        parts.append(best_body_text)
    if not best_suffix_text.is_empty():
        parts.append(best_suffix_text)

    if parts.is_empty():
        return "Unknown Item"

    var has_qualifier := (not best_prefix_text.is_empty() or not best_suffix_text.is_empty())
    if not has_qualifier and not best_body_text.is_empty():
        return "Unknown " + best_body_text

    return " ".join(parts)

# ── Formatted text methods ────────────────────────────────────────────────────


static func estimated_value_text(entry: ItemEntry) -> String:
    var v := entry.resolve_price()
    if not v.known:
        return UNKNOWN_TEXT
    if v.exact or v.max_value <= v.min_value:
        return "$%d" % v.min_value
    return "$%d - $%d" % [v.min_value, v.max_value]


static func condition_text(entry: ItemEntry) -> String:
    if entry.is_veiled():
        return UNKNOWN_TEXT
    return "%d%%" % int(entry.condition * 100)


static func condition_secondary_text(entry: ItemEntry) -> String:
    if entry.is_veiled():
        return ""
    return "x%.2f" % entry.get_condition_multiplier()


static func condition_detail_text(entry: ItemEntry) -> String:
    var text := condition_text(entry)
    if text == UNKNOWN_TEXT:
        return ""
    return "Condition:  %s (%s)" % [text, condition_secondary_text(entry)]


static func base_value_text(entry: ItemEntry) -> String:
    var v := entry.get_base_value()
    if v == 0:
        return UNKNOWN_TEXT
    return "$%d" % v


static func rarity_text(entry: ItemEntry) -> String:
    if entry.is_veiled():
        return UNKNOWN_TEXT

    var r: int = entry.rarity
    if r >= 0 and r < RARITY_NAMES.size():
        return RARITY_NAMES[r]

    return UNKNOWN_TEXT


static func weight_text(entry: ItemEntry) -> String:
    if entry.is_veiled():
        return UNKNOWN_TEXT
    return "%.1f kg" % entry.get_weight()


static func grid_text(entry: ItemEntry) -> String:
    if entry.is_veiled():
        return UNKNOWN_TEXT
    return "%d  %s" % [entry.get_cells().size(), entry.get_shape_id()]


static func inspection_text(entry: ItemEntry) -> String:
    return UNKNOWN_TEXT if entry.is_veiled() else "%d%%" % int(entry.inspection_level * 100)

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
            return verified_bonus + float(entry.rarity)
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
