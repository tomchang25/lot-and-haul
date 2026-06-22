# clue_chunk.gd
# Spoiler-safe clue display block. Takes an ItemEntry and renders every clue
# slot through a masking helper. Unknown rows render as "???" only — no clue
# text, DC, attribute, price effect, or hidden outcome is leaked.
class_name ClueChunk
extends VBoxContainer

# ── Display constants ──────────────────────────────────────────────────────────

const HEADER_COLOR := Color(0.55, 0.58, 0.63)

const ClueTagScene: PackedScene = preload("res://game/shared/item_display/clue_tag/clue_tag.tscn")

# ── State ──────────────────────────────────────────────────────────────────────

var _entry: ItemEntry = null

# ══ Common API ════════════════════════════════════════════════════════════════


func setup(entry: ItemEntry) -> void:
    _entry = entry
    if is_node_ready():
        _apply()


func refresh() -> void:
    _apply()

# ══ Internal ══════════════════════════════════════════════════════════════════


func _apply() -> void:
    if _entry == null:
        _clear_children()
        return

    var idx := 0
    idx = _build_anchor(idx)
    idx = _build_surface(idx)
    idx = _build_hidden(idx)

    while get_child_count() > idx:
        var child := get_child(get_child_count() - 1)
        remove_child(child)
        child.queue_free()


func _clear_children() -> void:
    for child in get_children():
        remove_child(child)
        child.queue_free()


func _ensure_child(index: int, type: Variant) -> Node:
    if index < get_child_count():
        var existing := get_child(index)
        if is_instance_of(existing, type):
            return existing
        remove_child(existing)
        existing.queue_free()

    var child: Node
    if type == ClueTag:
        child = ClueTagScene.instantiate()
    elif type is PackedScene:
        child = type.instantiate()
    else:
        child = type.new()
    # node-src: ephemeral — rebuilt per _apply()
    add_child(child)
    move_child(child, index)
    return child


func _build_anchor(idx: int) -> int:
    if _entry.anchor == null or not _entry.unveiled:
        return idx

    _ensure_child(idx, HSeparator)
    idx += 1

    var header := _ensure_child(idx, Label) as Label
    header.text = TranslationServer.translate("UI_CLUE_IDENTITY")
    header.add_theme_font_size_override(&"font_size", 10)
    header.add_theme_color_override(&"font_color", HEADER_COLOR)
    idx += 1

    var anchor := _entry.anchor
    var text: String
    if _entry.unveiled:
        text = TranslationServer.translate(anchor.known_text_key)
    else:
        text = ItemEntryDisplayHelper.unknown_text()
    var color := ClueColors.UNREVEALED_COLOR if not _entry.unveiled else ClueColors.ANCHOR_REVEALED_COLOR
    var row := _ensure_child(idx, Label) as Label
    row.text = "\u25a0  %s" % text
    row.add_theme_font_size_override(&"font_size", 11)
    row.add_theme_color_override(&"font_color", color)
    row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    idx += 1

    return idx


func _build_surface(idx: int) -> int:
    var clues: Array[ClueData] = _entry.surface_clues
    if clues.is_empty():
        return idx

    _ensure_child(idx, HSeparator)
    idx += 1

    var header := _ensure_child(idx, Label) as Label
    header.text = TranslationServer.translate("UI_CLUE_SURFACE")
    header.add_theme_font_size_override(&"font_size", 10)
    header.add_theme_color_override(&"font_color", HEADER_COLOR)
    idx += 1

    for clue: ClueData in clues:
        var tag := _ensure_child(idx, ClueTag) as ClueTag
        var revealed := _entry.revealed_clue_ids.has(clue.clue_id)
        tag.setup(clue, revealed, false)
        idx += 1

    return idx


func _build_hidden(idx: int) -> int:
    var clues: Array[ClueData] = _entry.hidden_clues
    if clues.is_empty():
        return idx

    _ensure_child(idx, HSeparator)
    idx += 1

    var header := _ensure_child(idx, Label) as Label
    header.text = TranslationServer.translate("UI_CLUE_HIDDEN")
    header.add_theme_font_size_override(&"font_size", 10)
    header.add_theme_color_override(&"font_color", HEADER_COLOR)
    idx += 1

    for clue: ClueData in clues:
        var tag := _ensure_child(idx, ClueTag) as ClueTag
        var revealed := _entry.revealed_clue_ids.has(clue.clue_id)
        tag.setup(clue, revealed, false)
        idx += 1

    return idx
